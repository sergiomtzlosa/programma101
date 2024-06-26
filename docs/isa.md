# Programma 101 emulator — instruction-set reference

This document describes the instruction model implemented by the engine
(`Sources/Engine`). It is deliberately close to the University of Amsterdam
`.prg` notation so that historical listings can be loaded without translation.

## 1. Listing notation

Each program line is three characters:

```
column 1    column 2    column 3
register    / or space  operator
```

Examples:

| Text | Meaning |
| --- | --- |
| `A +` | add A to the accumulator |
| `B/$` | copy the left/lower half of B (`b`) into A |
| `  :` | divide A by M; the omitted register means M |
| ` /V` | conditional jump (test A > 0) to `A/V` |
| `A/V` | conditional-jump reference point |
| `A/^` | start of an encoded numeric constant |
| `R/S` | swap R and D |

Lines beginning with `#` are comments. The parser also understands a few
directives in comments (see §9). Blank lines are ignored.

The emulator accepts the de-facto UvA substitutions:

| ASCII | P101 key |
| --- | --- |
| `^` | ↑ |
| `$` | ↓ |
| `&` | ↕ |
| `%` | ♢ |
| `!` | ✱ (clear) |
| `*` | × |
| `:` | ÷ |
| `#` | √ |

## 2. Registers

The machine has the operating registers `M`, `A`, `R`, the storage registers
`B`–`F`, and two program registers modelled by the program store rather than by
visible cells.

| Register | Role | Capacity |
| --- | --- | --- |
| `M` | median/distributive register; all keyboard entries land here | 22 digits |
| `A` | accumulator | 22 digits |
| `R` | complete result, product, division remainder | 22 digits |
| `B`, `C` | data | 22 digits |
| `D`, `E`, `F` | data and/or card constants | 22 digits |
| `b`, `c`, `d`, `e`, `f` | left/half cells addressed with `X/` | 11 digits |

`M`, `A` and `R` are never split; only `B`–`F` have `X/` halves.

Numbers are exact decimals: sign, digit string, and decimal scale. The engine
never uses floating point.

**Simplification:** like the UvA emulator, each uppercase/lowercase pair is an
independent cell. On real hardware they are two halves of one 22-digit register.
Programs that use the halves independently behave identically. Only programs
that rely on the physical sharing/carry between the two halves can observe the
difference.

When an instruction selects an uppercase storage register, the value is copied
to `M` during phase 1 while the source is retained. The source register is not
destroyed by arithmetic.

## 3. Arithmetic

Arithmetic is performed in two phases:

1. The selected register is copied to `M`.
2. The operation is performed using `A` and `M`.

For `+`, `-`, and `*`:

- `A` receives the result truncated toward zero at the decimal-wheel setting.
- `R` receives the complete, untruncated result.
- The source register is unchanged.

For division `:`:

- `A` receives the quotient truncated toward zero at the decimal-wheel setting.
- `R` receives the remainder `A_original - quotient * divisor`.
- Division by zero puts the machine in the error state.

For square root `#`:

- `A` receives the root truncated at the decimal-wheel setting.
- `M` receives twice the root.
- `R` is left unchanged (the manual calls its content a non-functional
  remainder).

For the special forms:

- `A &` takes the absolute value of `A`.
- ` /&` copies the fractional part of `A` into `M`.
- `X &` (for any addressable register other than A) exchanges `A` and `X`.

The decimal wheel is 0–15. Truncation is always toward zero; the engine does not
round.

## 4. Transfers, clear, print

| Listing | Effect |
| --- | --- |
| `X ^` | copy `M` into `X` |
| `X $` | copy `X` into `A` |
| `X &` | exchange `A` and `X` |
| `A !` | clear the selected register (use `B !`, `C !`, …) |
| `X %` | print `X` on the paper |
| ` /%` | print a blank line |
| `  S` | stop and wait for keyboard input |
| `R/S` | swap `R` and `D` (multi-card data transfer) |

For printing, the decimal wheel controls the number of decimal places. The `R`
register is printed with its own stored scale so that a full product or remainder
is not silently truncated by the paper formatting.

## 5. Jumps

A jump instruction has an **origin** and a **reference point**. The reference
point is a no-op line.

| Origin | Reference (unconditional) | Reference (conditional) |
| --- | --- | --- |
| `  V` | `A V` | `A/V` |
| `  W` | `A W` | `A/W` |
| `  Y` | `A Y` | `A/Y` |
| `  Z` | `A Z` | `A/Z` |
| `C V` | `B V` | `B/V` |
| `C W` | `B W` | `B/W` |
| `C Y` | `B Y` | `B/Y` |
| `C Z` | `B Z` | `B/Z` |
| `D V` | `E V` | `E/V` |
| `D W` | `E W` | `E/W` |
| `D Y` | `E Y` | `E/Y` |
| `D Z` | `E Z` | `E/Z` |
| `R V` | `F V` | `F/V` |
| `R W` | `F W` | `F/W` |
| `R Y` | `F Y` | `F/Y` |
| `R Z` | `F Z` | `F/Z` |

When an origin is executed, the engine scans the program from the beginning for
the matching reference and resumes **after** that reference. There is no relative
offset and no hidden return stack.

A conditional origin (second character `/`) jumps only when `A > 0`; zero and
negative values fall through to the next instruction.

Start keys (`V`, `W`, `Y`, `Z` in the UI) begin at the corresponding `A V`,
`A W`, `A Y`, or `A Z` reference and execute the instruction after it. A program
that has no such label cannot be started with that key.

A jump reference must be unique. If it is missing, the machine stops with an
error.

## 6. Stop and input

`S` enters the waiting-for-input state. The UI accepts a number and continues
with `Run / Continue`. The entered value is placed in `M`.

`R/S` is a normal swap of `R` and `D`, not an input prompt. This is the mechanism
used by programs split across multiple magnetic cards: the first card leaves a
value in `R`, the next card is inserted with the **Insert Next Card…** command
(which preserves data registers), and the program uses `R/S` to move that value
to `D`.

## 7. Encoded constants

`A/^` is not a normal transfer. It starts a run of pseudo-instructions that encode
one number. Each following line contributes one digit:

| Operator | Digit |
| --- | --- |
| `S` | 0 |
| `$` | 1 |
| `^` | 2 |
| `&` | 3 |
| `+` | 4 |
| `-` | 5 |
| `*` | 6 |
| `:` | 7 |
| `%` | 8 |
| `!` | 9 |

The register column gives the sign and terminator:

- `D` or `R` — positive
- `E` or `F` — negative
- `D` or `E` — final digit; execution resumes after it
- `R` or `F` — continue with the next digit

A `/` in column 2 marks a decimal point for that digit. Digits are assembled from
right to left, then placed in `M`. Example:

```
A/^
D/$
```

encodes `1.` (the `$` is digit 1, `D/` marks the decimal point and terminates).
This is the constant used by the factorial example in `test4.prg`.

## 8. Program capacity

The engine stores up to 120 instructions in a separate instruction list. Real
hardware stores 24 instructions in each of p1 and p2 (48 total), then overflows
into F, f, E, e, D, d. The visible behaviour of the instruction stream is the
same, but the engine does not consume D/E/F cells for program overflow. This is
the same simplification made by the UvA emulator and is documented so that card
constant snapshots are not mistaken for a full hardware overflow model.

## 9. Comment directives and cards

The `.prg` parser recognizes these optional comments:

```
# decimal wheel: 10
# constant F = -1
# constant D/ = 12.5
```

`constant on card: D = …`, `decimal indicator setting 10`, and similar variants
are also accepted (the regexes are case-insensitive). Constants are applied after
the program is loaded; the canonical names are uppercase for the right half and
lowercase for the left half.

A virtual magnetic card is text with up to two stripes:

```
# Programma 101 magnetic card
# stripe 1
<program text>
# stripe 2
<program text>
```

A plain `.prg` file is accepted as a one-stripe card. Reading a card loads the
selected stripe's program and its D/E/F constants. Normal loading clears all data
registers; “Insert Next Card…” preserves them for multi-card/`R/S` programs.
If the same two-stripe card file is chosen again for insertion, the loader
advances to its second stripe.

When **Save Card…** records a program of at most 48 instructions, it snapshots
the current D/d, E/e and F/f values into constant directives. This matches the
part of the card that is available for numeric constants. Longer programs use the
engine's separate instruction buffer rather than physical register overflow, so
the UI records only constants already declared in the listing.

## 10. Deliberate limitations

- Binary/BCD card images are not implemented; the text `.prg`/card format is the
  interchange format.
- Program overflow does not consume visible D/E/F cells (§8).
- The UvA emulator's interactive `q`, `?`, `r`, and `d` directives are not
  implemented. Use the UI's Stop/Reset/decimal-wheel controls instead.
- A full gate-level or delay-line timing simulation is out of scope.
