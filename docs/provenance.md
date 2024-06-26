# Sources, verification, and accepted deviations

This file records where the emulator's behaviour comes from and which claims were
actually checked against the implementation. The project plan itself lives in
`AGENTS.md`.

## 1. Primary and secondary sources

- **Olivetti, Programma 101 General Reference Manual** — register roles,
  two-phase arithmetic, decimal wheel, jump pairs, start keys, card recording.
  <https://www.claudiovianini.com/P101/P101GeneralManual.pdf>
- **Olivetti, Programming Manual and program-library listings** — instruction
  notation, constants encoded as instruction sequences, multi-card operation.
  Cited through the manual extracts and the UvA emulator documentation.
- **University of Amsterdam, Olivetti Programma 101 emulator (E.H. Dooijes,
  1995)** — `.prg` text format, keyboard/register conventions, the five test
  programs, and the independent-halves simplification.
  <https://ub.fnwi.uva.nl/computermuseum/p101emul.html>
- **Wikipedia, Olivetti Programma 101** — historical context and hardware
  summary (delay-line memory, printer, card reader, production figures).
  <https://en.wikipedia.org/wiki/Olivetti_Programma_101>
- **Olivetti, Biblioteca programmi, Volume 1** — example library structure and
  application categories; consulted for provenance of the test corpus.
  <https://archive.org/details/programma101bibliotecaprogrammi1>
- **silab.it Programma 101 jump documentation** — jump origin/reference pairing
  and start-key behaviour.

Where the plan says **[verify]**, the item was checked against the manuals and
the UvA implementation. The text `.prg` format, not the binary card encoding, is
the supported v1 interchange format.

## 2. Facts verified in the implementation

| Fact | Implementation | Test/evidence |
| --- | --- | --- |
| 10 visible registers, M/A/R operating + B–F storage | `PCS101Machine` register table | `testTransfersAndClear`, register inspector |
| B–F have left/right halves; M/A/R do not | `b,c,d,e,f` cells; `X/` notation | `testAbsoluteValueAndFractionalPart`, `testOnlyBFHaveSplittableHalves` |
| Keyboard entries go to M | `entryDigit:` etc. | `testKeyboardEntry` |
| Two-phase arithmetic copies source to M | `performArithmeticOperation:source:` | `testDecimalArithmetic` |
| A gets wheel-truncated result; R gets complete result | `truncatedToDecimalPlaces:` / full value | `testDecimalArithmetic`, `testDivisionRemainder` |
| Division remainder is in R | `A - quotient*divisor` | `testDivisionRemainder` |
| Square root leaves R undefined and puts 2√ in M | `#` branch | `testManualExampleTest1` |
| `A &` absolute; ` /&` fractional part | special cases | `testAbsoluteValueAndFractionalPart` |
| 16 unconditional + 16 conditional jump pairs | `jumpTargetText`, `isConditionalJump` | factorial and arccos examples |
| Conditional jumps require A > 0 | `A.isPositive` | factorial loop |
| Reference scan resumes after the label | `indexOfLabelText + 1` | factorial and cubic-root examples |
| Start keys V/W/Y/Z use A V … A Z | `startAtRoutine:` | all example tests |
| `A/^` constant sequences | `executeConstantLoader` | `testFactorialTest4` |
| Constants can be declared in listings | `constantRegex` | `testConstantsAreLoadedFromListing` |
| Two-stripe cards | `PCSCard` with `# stripe 1/2` | `testTwoStripeCard` |
| Card round-trip | `textRepresentation` + parser | `testCardRoundTrip` |
| Card round-trip with declared constants | directives survive write/clear/reload | `testCardRoundTripPreservesConstants` |
| Card records current D/E/F constants | `cardWithProgram:constants:` | `testCardRecordsRegisterSnapshot` |
| Multi-card R/S and register preservation | `loadProgram:preserveRegisters:error:`; `R/S` | `testMultiCardProgramPreservesRegistersAndRS` |

## 3. Reference outputs

The following are asserted by the XCTest suite (`Tests/PCS101EngineTests.m`):

| Program | Inputs | Wheel | Output |
| --- | --- | --- | --- |
| `test1.prg` | 3, 4 | 4 | `7.0000`, `-1.0000`, `12.0000`, `18.0000`, `4.2426` |
| `test2.prg` (cube root) | 2, 3, -85 | 4 | `3.3466`, blank line |
| `test3.prg` (arccos 0.8) | 0.8 | 10 (from listing) | `0.6435011083` |
| `test4.prg` (5!) | 5 | 0 | `120` |

`test5.prg` (piston velocity, application code 35) is a 106-instruction program
that expects its original card constants and/or preloaded register data. The
listing in the UvA distribution contains no initialization values and no recorded
result. The emulator loads it and resolves its `A V` start label, but a
meaning-for-meaning expected-output test cannot be written from the distributed
artifacts alone. See §5.

## 4. Arithmetic-model discrepancy with the UvA emulator

The UvA page describes its arithmetic as applying “round-off” at the decimal
indicator setting. The Olivetti manual and this project's acceptance criteria
specify **truncation toward zero**. The emulator therefore truncates. This is the
main reason a result can differ in the last decimal place from PROG101, and it is
intentional.

The UvA page also notes that its own `test3` result is more accurate than a real
P101. Our test uses the UvA-listed 10-digit value `0.6435011083`, which is
reproduced by the exact-decimal implementation.

## 5. Accepted deviations and open items

1. **Independent register halves.** `B` and `b` are separate cells, as in the UvA
   emulator. Real hardware shares one 22-digit register. Only “foul tricks” that
   depend on the physical halves observe this.
2. **Program overflow.** Instructions live in a 120-entry list. Real hardware
   overflows beyond 48 instructions into F/f/E/e/D/d. Visible program execution
   is preserved, but a card recorded from a >48-instruction program does not
   reconstruct the physical register/instruction overlap.
3. **Card encoding.** The card is a text serialisation with two program stripes,
   comments, and constant directives. Binary stripe encoding is a stretch goal.
4. **`test5`.** The distributed listing is not self-contained. It must be run
   with the original program's register initialization (or its card constants);
   without that data it reaches a division-by-zero condition. It is covered by a
   load/start test but not by a golden-output test.
5. **Interactive UvA directives.** `q`, `?`, `r`, and `d` typed at a stop prompt
   are not implemented; the AppKit controls provide the same operations.
6. **UI timing.** The UI executes roughly 20 instructions per second via a timer.
   Tests use the synchronous engine loop, so results are timing-independent.

## 6. Reproduction

```bash
python3 Tools/generate_xcodeproj.py

xcodebuild -project Programma101.xcodeproj -scheme Programma101 \
  -configuration Debug -derivedDataPath /tmp/p101dd build

xcodebuild -project Programma101.xcodeproj -scheme EngineTests \
  -destination 'platform=macOS' -derivedDataPath /tmp/p101dd test
```

Expected last line: `** TEST SUCCEEDED **` with 18 tests and 0 failures.

The app bundle is self-contained apart from the usual AppKit/XCTest runtime; the
five example programs are copied into `Contents/Resources/examples`.
