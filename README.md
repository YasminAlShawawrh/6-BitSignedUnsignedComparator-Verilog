# 6-Bit Signed/Unsigned Comparator — Verilog

A 6-bit digital comparator implemented in Verilog using both structural and behavioral modeling approaches. The design supports signed (two's complement) and unsigned comparison modes, selected via a control bit. Both implementations are verified against each other using a comprehensive testbench covering all 8192 input combinations.

---

## Table of contents

- [Design overview](#design-overview)
- [Module descriptions](#module-descriptions)
- [Timing analysis](#timing-analysis)
- [Testbench & verification](#testbench--verification)
- [Simulation results](#simulation-results)
- [How to run](#how-to-run)

---

## Design overview

The comparator takes two 6-bit inputs A and B and a selection bit S, and outputs three flags:

| Output | Meaning |
|---|---|
| `EQ` | A equals B |
| `GT` | A is greater than B |
| `LT` | A is less than B |

The selection bit `S` controls the comparison mode:

| S | Mode | Description |
|---|---|---|
| `0` | Unsigned | All 6 bits represent a positive magnitude |
| `1` | Signed | MSB (bit 5) is the sign bit — two's complement representation |

The design is **synchronous**: inputs are latched on the **falling edge** of the clock, and outputs are driven on the **rising edge**, preventing glitches and ensuring stability.

---

## Module descriptions

### `comparatorStructural`
A purely structural combinational comparator built from basic logic gates with explicit propagation delays:

| Gate | Delay |
|---|---|
| `NOT` | 4 time units |
| `AND` | 9 time units |
| `NOR` | 6 time units |
| `OR`  | 9 time units |

**How it works:**
- For each bit `i`, three signals are computed:
  - `and1out[i]` = `~A[i] & B[i]` — A's bit is less than B's bit
  - `and2out[i]` = `A[i] & ~B[i]` — A's bit is greater than B's bit
  - `norout[i]`  = `~(and1out[i] | and2out[i])` — bits are equal
- Carry-based logic propagates from the MSB down to resolve the final GT/LT/EQ comparison:
  - `LT` = bit 5 less, OR (bit 5 equal AND bit 4 less), OR ...
  - `GT` = symmetric carry chain for greater-than
  - `EQ` = all six `norout` bits ANDed together

Uses `generate`/`genvar` for the per-bit logic, with flat gate instances for the carry chains.

---

### `signedOrUnsignedStructural`
A synchronous wrapper around `comparatorStructural` that adds signed comparison support.

- Instantiates **two** `comparatorStructural` modules: one operating on raw inputs (unsigned), one on their two's complement magnitudes (signed)
- Inputs `A`, `B`, `S` are registered on the **negedge** of clock
- Two's complement conversion: `(reg[5] == 1) ? (~reg + 1) : reg`
- Output selection on **posedge** of clock:
  - `S=0` → forwards unsigned comparator outputs
  - `S=1` → handles sign-mismatch cases explicitly, then selects signed comparator outputs, inverting GT/LT for negative-vs-negative comparisons

**Signed edge cases handled:**
- A positive, B negative → GT=1 immediately
- A negative, B positive → LT=1 immediately  
- Both negative → magnitude comparison with GT/LT inverted
- Both `111111` (−1 vs −1) → EQ=1, GT=0, LT=0

---

### `comparatorBehavioral`
A high-level behavioral implementation of the same interface, used as the reference model.

- Inputs registered on **negedge** of clock
- Comparison logic on **posedge** of clock using `if/else` constructs
- Signed path checks MSB first, then compares magnitudes using `~reg + 1` for two's complement
- Outputs reset to 0 at the start of each rising edge before being set

---

### `tb_comparator` — Testbench
Exhaustive verification testbench that instantiates both `signedOrUnsignedStructural` and `comparatorBehavioral` and compares their outputs on every test vector.

**Coverage:** iterates `{A, B, S}` across all **8192 combinations** (6-bit A × 6-bit B × 1-bit S)

**Pass/fail check:**
```verilog
(EQ_structural == EQ_behavioral &&
 GT_structural == GT_behavioral &&
 LT_structural == LT_behavioral) ? "PASS" : "FAIL"
```

**Output format per cycle:**
```
Time:655280 | A:111111 B:111110 S:1 |
  Structural [EQ:0 GT:1 LT:0] |
  Behavioral [EQ:0 GT:1 LT:0] |
  Test Result: PASS
```


## Timing analysis

The critical path in the structural design runs through:

```
NOT (4) → AND (9) → NOR (6) → AND (9) → OR (9) = 37 time units
```

The clock period is therefore set to **74 time units** (2× the critical path) to safely accommodate the full combinational delay before outputs are latched.

Maximum clock frequency: `1 / 74 time units`

---

## Simulation results

Both testbenches confirmed that the structural and behavioral comparators produce identical outputs across all test vectors.

**Example verified output:**
```
Time:655280 | A:111111 B:111110 S:1 |
  Structural [EQ:0 GT:1 LT:0] | Behavioral [EQ:0 GT:1 LT:0] | PASS
```

**Bug discovered during development:**  
A bug was intentionally introduced at line 44 of the structural comparator — an `OR` gate was used instead of an `AND` gate for the `EQ` output. This caused the structural and behavioral results to mismatch, producing `FAIL` results across many test cases. Replacing `or` with `and` restored correct operation. This demonstrates the effectiveness of the cross-verification testbench approach.

---

## How to run

### Active-HDL

1. Create a new workspace and design in Active-HDL
2. Add all `.v` source files to the design
3. Compile:
   - Right-click the design → **Compile All**
4. Simulate:
   - Set `tb_comparator` as the top-level module
   - Click **Initialize Simulation**
   - In the console: `run 700000` (covers all 8192 × 74-unit cycles)
5. View results in the console log — each line shows PASS or FAIL

### ModelSim / QuestaSim

```bash
vlog comparatorStructural.v signedOrUnsignedStructural.v \
     comparatorBehavioral.v tb_comparator.v

vsim tb_comparator -do "run 700000; quit"
```
