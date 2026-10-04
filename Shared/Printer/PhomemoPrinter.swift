import CoreBluetooth
import FauxmemoKit
import Foundation
import Observation
import os

private let logger = Logger(subsystem: "com.fauxmemo.Fauxmemo", category: "BLE")

struct NotReadyReason: OptionSet, Equatable {
    let rawValue: Int
    static let noPaper    = NotReadyReason(rawValue: 1 << 0)
    static let coverOpen  = NotReadyReason(rawValue: 1 << 1)
    static let overheated = NotReadyReason(rawValue: 1 << 2)
}

enum PrinterState {
    case disconnected
    case scanning
    case connecting
    case ready(ReadyPrinter)
    case printing
    case notReady(NotReadyReason)
    case error(String)
}

struct ReadyPrinter {
    private let printer: PhomemoPrinter

    fileprivate init(printer: PhomemoPrinter) {
        self.printer = printer
    }

    func print(_ bitmap: Bitmap) {
        printer.printBitmap(bitmap)
    }
}

@Observable
final class PhomemoPrinter: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private(set) var state: PrinterState = .disconnected

    @ObservationIgnored private var central: CBCentralManager!
    @ObservationIgnored private var targetPeripheral: CBPeripheral?
    @ObservationIgnored private var writeChar: CBCharacteristic?
    private let targetServiceUUID = CBUUID(string: "00001812-0000-1000-8000-00805F9B34FB")

    @ObservationIgnored private var statusFlags: NotReadyReason = []
    @ObservationIgnored private var connected = false
    @ObservationIgnored private var pollTask: Task<Void, Never>?

    /// Encoded print job bytes not yet handed to CoreBluetooth.
    @ObservationIgnored private var pending = Data()

    override init() {
        super.init()
        self.central = CBCentralManager(delegate: self, queue: .main)
    }

    /// Starts looking for the printer again after a disconnect or error.
    func reconnect() {
        guard central.state == .poweredOn, !connected else { return }
        if let peripheral = targetPeripheral {
            central.cancelPeripheralConnection(peripheral)
        }
        startScan()
    }

    private func transition(to newState: PrinterState) {
        logger.info("State: \(String(describing: newState))")
        state = newState
    }

    private func startScan() {
        transition(to: .scanning)
        central.scanForPeripherals(withServices: [targetServiceUUID], options: nil)
    }

    private func updateReadyState() {
        guard connected else { return }
        if statusFlags.isEmpty {
            transition(to: .ready(ReadyPrinter(printer: self)))
        } else {
            transition(to: .notReady(statusFlags))
        }
    }

    fileprivate func printBitmap(_ bitmap: Bitmap) {
        guard targetPeripheral != nil, writeChar != nil else {
            logger.error("Cannot print: peripheral or characteristic missing")
            return
        }

        transition(to: .printing)
        pending = PhomemoEncoder.encode(bitmap)
        logger.info("Printing \(self.pending.count) bytes")
        sendPending()
    }

    /// Writes as much of the job as the link will take; the rest goes out from
    /// `peripheralIsReady(toSendWriteWithoutResponse:)`.
    private func sendPending() {
        guard let peripheral = targetPeripheral, let characteristic = writeChar else { return }
        let chunkSize = peripheral.maximumWriteValueLength(for: .withoutResponse)
        while !pending.isEmpty, peripheral.canSendWriteWithoutResponse {
            let chunk = Data(pending.prefix(chunkSize))
            peripheral.writeValue(chunk, for: characteristic, type: .withoutResponse)
            pending.removeFirst(chunk.count)
        }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger.debug("Central state: \(String(describing: central.state.rawValue))")
        switch central.state {
        case .poweredOn:
            startScan()
        case .poweredOff:
            transition(to: .error("Bluetooth is off"))
        case .unauthorized:
            transition(to: .error("Bluetooth access is off for Fauxmemo"))
        case .unsupported:
            transition(to: .error("Bluetooth unsupported"))
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        logger.info("Discovered: \(peripheral.name ?? "unknown") RSSI: \(RSSI)")
        self.targetPeripheral = peripheral
        self.central.stopScan()
        self.central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        transition(to: .connecting)
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        transition(to: .error("Failed to connect: \(error?.localizedDescription ?? "unknown")"))
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connected = false
        pending = Data()
        pollTask?.cancel()
        transition(to: .disconnected)
        // Try to reconnect
        startScan()
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            transition(to: .error("Service discovery failed: \(error.localizedDescription)"))
            return
        }
        guard let service = peripheral.services?.first else {
            transition(to: .error("No services found"))
            return
        }
        peripheral.discoverCharacteristics(nil, for: service)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error {
            transition(to: .error("Characteristic discovery failed: \(error.localizedDescription)"))
            return
        }
        guard let chars = service.characteristics, chars.count > 1 else {
            transition(to: .error("No characteristics found"))
            return
        }

        for char in chars where char.properties.contains(.notify) {
            peripheral.setNotifyValue(true, for: char)
        }

        // FF02 is the write characteristic
        let writeChar = chars[1]
        self.writeChar = writeChar

        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            await self?.pollUntilReady(peripheral: peripheral, characteristic: writeChar)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error, error.localizedDescription.contains("Encryption is insufficient") {
            transition(to: .error("Pair the printer in Bluetooth settings first"))
        }
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        sendPending()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        let bytes = [UInt8](data)
        logger.debug("Received: \(bytes.map { String(format: "%02x", $0) }.joined(separator: " "))")

        guard bytes.count > 2 else { return }

        switch (bytes[1], bytes[2]) {
        case (0x03, 0xa9): // Too hot
            statusFlags.insert(.overheated)
            updateReadyState()

        case (0x03, 0xa8): // Temperature normal
            statusFlags.remove(.overheated)
            updateReadyState()

        case (0x05, 0x99): // Cover open
            statusFlags.insert(.coverOpen)
            updateReadyState()

        case (0x05, 0x98): // Cover closed
            statusFlags.remove(.coverOpen)
            updateReadyState()

        case (0x06, 0x88): // No paper
            statusFlags.insert(.noPaper)
            updateReadyState()

        case (0x06, 0x89): // Have paper
            statusFlags.remove(.noPaper)
            updateReadyState()

        case (0x0b, 0xb8): // Cancel
            updateReadyState()

        case (0x0f, 0x0c): // Print complete
            updateReadyState()

        default:
            if !connected {
                connected = true
                updateReadyState()
            }
        }
    }

    @MainActor
    private func pollUntilReady(peripheral: CBPeripheral, characteristic: CBCharacteristic) async {
        while !connected, !Task.isCancelled {
            // Query serial number: "SSSGETSN\r\n"
            let sn = Data([0x53, 0x53, 0x53, 0x47, 0x45, 0x54, 0x53, 0x4e, 0x0d, 0x0a])
            peripheral.writeValue(sn, for: characteristic, type: .withResponse)

            // Query compress mode: "SSSGETBMAPMODE\r\n"
            let compressMode = Data([
                0x53, 0x53, 0x53, 0x47, 0x45, 0x54,
                0x42, 0x4d, 0x41, 0x50, 0x4d, 0x4f, 0x44, 0x45,
                0x0d, 0x0a
            ])
            peripheral.writeValue(compressMode, for: characteristic, type: .withResponse)

            // Ask paper status
            let askPaper = Data([0x1f, 0x11, 0x11])
            peripheral.writeValue(askPaper, for: characteristic, type: .withoutResponse)

            // Ask cover status
            let askCover = Data([0x1f, 0x11, 0x12])
            peripheral.writeValue(askCover, for: characteristic, type: .withoutResponse)

            try? await Task.sleep(for: .milliseconds(500))
        }
    }
}

extension PrinterState {
    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    var summary: String {
        switch self {
        case .disconnected: "Disconnected"
        case .scanning: "Looking for printer"
        case .connecting: "Connecting"
        case .ready: "Ready"
        case .printing: "Printing"
        case .notReady(let reason):
            if reason.contains(.noPaper) { "Out of paper" }
            else if reason.contains(.coverOpen) { "Cover open" }
            else { "Too hot" }
        case .error(let message): message
        }
    }
}
