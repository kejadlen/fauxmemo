// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FauxmemoKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "FauxmemoKit", targets: ["FauxmemoKit"])
    ],
    targets: [
        .target(name: "FauxmemoKit"),
        .testTarget(name: "FauxmemoKitTests", dependencies: ["FauxmemoKit"])
    ]
)
