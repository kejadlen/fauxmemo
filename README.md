# Fauxmemo

Print photos and Phosphor icon sheets to a Phomemo T02 from iOS.

Fork of [jeffrafter/phomemo](https://github.com/jeffrafter/phomemo), which builds on [vivier/phomemo-tools](https://github.com/vivier/phomemo-tools).

## Building

The Xcode project is generated from `project.yml`:

```sh
brew install xcodegen
xcodegen
open Fauxmemo.xcodeproj
```

Image processing and the printer protocol live in `FauxmemoKit`, a plain Swift package with tests:

```sh
cd FauxmemoKit && swift test
```

## Layout

- `App/`: the app (home, photo print, icon sheet)
- `Share/`: share extension for printing a photo from any app
- `Shared/`: printer connection, imaging glue and views used by both
- `FauxmemoKit/`: dithering, the T02 byte format and icon sheet layout

## Troubleshooting

**Printer not detected:** Hold the button 3 seconds to enter pairing mode, or 20 seconds to hard reset.

**Already connected elsewhere:** The printer connects to one device at a time. Close other apps.

**USB not working:** The USB port only charges. Print over Bluetooth.

## How printing works

Everything ends up as a `Bitmap` 384 dots wide, which `PhomemoPrinter` encodes and sends. A new kind of print, such as text, only needs to produce a bitmap.
