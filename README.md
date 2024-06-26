# Programma 101 Emulator

A native macOS emulator of the Olivetti **Programma 101** (1965), written in
Objective-C with AppKit. The engine executes original P101 program listings at
the register/instruction level; it is not a calculator skin.

## Build and run

Requirements: macOS 13+, Xcode 15+ (the checked-in project was built with
Xcode 27).

```bash
xcodebuild -project Programma101.xcodeproj -scheme Programma101 \
  -configuration Debug build
open Programma101.xcodeproj
```

Or build and launch from Xcode with the `Programma101` scheme. The
`EngineTests` scheme runs the engine-only XCTest suite.

## Using the machine

- **Examples** → `test1`–`test5`: load one of the original UvA listings.
- **Run / Continue** starts at the selected routine (`V`, `W`, `Y`, or `Z`).
  The routine is auto-selected from the program's `A V`…`A Z` labels.
- **Step** executes one instruction; **Stop** halts the timer; **Reset** clears
  registers and the program.
- Type a number and press **Enter M** (or Enter) to put it in `M`.
- The keyboard follows the P101: select a register, then an operator. `/` splits
  B–F (`B/`) or, with no register, means fractional part/blank line.
- **Decimal wheel** is 0–15. Arithmetic truncates toward zero; the complete
  result goes to `R`.
- **Record Program** turns keyboard keys and operators into listing lines.
- **Load Program…** reads a `.prg` or card file and clears data registers.
- **Insert Next Card…** reads the next program while preserving M/A/R/B–F, for
  multi-card programs that use `R/S`.
- **Save Card…** writes the current program and, for programs of up to 48
  instructions, a snapshot of the D/d, E/e and F/f constants to a two-stripe
  virtual card text file.
- A magnetic-card file can hold two programs under `# stripe 1` and
  `# stripe 2`; a plain `.prg` file is accepted as one stripe.

When a program stops for input, enter a number and press **Run / Continue**.
Press **Print Program** to print the loaded listing on the paper pane.

## Program format

Programs use the UvA `.prg` format: three characters per instruction
(`register`, `/` or space, operator), comments with `#`. Optional directives set
the decimal wheel and card constants:

```text
# decimal wheel: 10
# constant F = -1
# constant D/ = 12.5
```

See [`docs/isa.md`](docs/isa.md) for the full instruction reference, jump table,
constant encoding, and card format.

## Tests

```bash
xcodebuild -project Programma101.xcodeproj -scheme EngineTests \
  -destination 'platform=macOS' test
```

The suite covers exact decimal arithmetic, M/A/R semantics, truncation,
division remainder, transfers, jumps, all four self-contained example programs,
constants, card round-trip, two-stripe cards, learn mode, keyboard entry, and
multi-card `R/S`.

`test5.prg` (piston velocity) is a 106-instruction library program whose original
card constants/initial register data are not present in the distributed listing.
The emulator loads and starts it, but no golden-output assertion is possible
without that data. If you have its initialization values, add `# constant C = …`
directives or use the CLI's `--set C=… M=…` options. This limitation is also
documented in [`docs/provenance.md`](docs/provenance.md).

## Layout

```text
Sources/Engine/   exact decimal number, program/card parser, P101 machine
Sources/App/      AppKit window, register inspector, keyboard, menus
Resources/examples/  test1.prg … test5.prg
Tests/            XCTest engine suite
Tools/            project generator and CLI runner
docs/             ISA reference and source provenance
```

The engine depends only on Foundation and is used by both the app and the test
target. `Tools/p101run.m` is a small CLI harness for running a `.prg` outside
Xcode.

## Status

- Debug app build: succeeds with no warnings.
- Engine tests: 18 tests, 0 failures.
- App bundle launch: verified.
- Known modelling simplifications and the `test5` caveat are listed in
  [`docs/provenance.md`](docs/provenance.md).
