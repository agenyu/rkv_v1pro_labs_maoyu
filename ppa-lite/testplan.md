# PPA-Lite Testplan and Result Mapping

## Regression Summary

- Testcases: 13
- Seeds: 1, 2, 3
- Simulations: 39
- Result: 39 PASS, 0 FAIL
- Log criterion: `[TEST START] <test> seed=<n>`, `[TEST PASS]`, and
  `Errors: 0, Warnings: 0`

## Coverage Summary

Code coverage is scoped to the DUT hierarchy `/tb/dut` after merging all 39
simulations. Testbench helper instances are excluded by hierarchy scope, not by
editing or excluding DUT source lines.

| Metric | Covered | Total | Result |
|---|---:|---:|---:|
| Statement / line | 158 | 163 | 96.93% |
| Branch | 98 | 103 | 95.14% |
| Condition | 27 | 28 | 96.42% |
| FSM state | 3 | 3 | 100.00% |
| FSM transition | 5 | 5 | 100.00% |
| Toggle | 1290 | 1393 | 92.60% |

Functional coverage:

| Coverage object | Result |
|---|---:|
| `cg_ppa` | 100.00% |
| Covergroup bins | 24 / 24 |

## Lab1 Testcases

| Testcase | Checkpoint | Input summary | Expected / check | Result | Coverage / seed |
|---|---|---|---|---|---|
| `lab1_defaults_test` | APB two-phase transfer, PREADY, CSR reset values, RES_* stub path | Read CTRL/CFG/STATUS/IRQ/PKT_LEN_EXP/RES/ERR; write CTRL/CFG/IRQ_EN | PREADY=1; CTRL=0, CFG=0xF1, other reset values=0; stub results read back correctly | PASS | Seeds 1/2/3 |
| `lab1_pkt_mem_test` | PKT_MEM 0x040-0x05C write/read mapping | Write eight words and read all eight addresses | All words read back unchanged; address maps to SRAM word 0-7 | PASS | Seeds 1/2/3 |
| `lab1_pslverr_test` | PSLVERR response rules | Write RO/reserved, read reserved, start while disabled, legal start | Illegal accesses return PSLVERR=1; legal start returns PSLVERR=0 | PASS | Seeds 1/2/3 |

Optional Lab1 items:

- PSLVERR RO/reserved/start rejection: implemented and covered.
- IRQ_EN, IRQ_STA RW1C, `irq_o`, done/error paths: implemented and covered by
  `lab3_irq_test`.

## Lab2 Testcases

| Testcase | Checkpoint | Input summary | Expected / check | Result | Function bins |
|---|---|---|---|---|---|
| `lab2_valid_test` | M3 legal packet processing | Lengths 4/8/16/32; types 0x01/0x02/0x04/0x08 | FSM completes; result length/type/sum/xor correct; no error | PASS | length min/short/mid/max; type1/type2/type4/type8; result ok |
| `lab2_errors_test` | Length, type, checksum and mask checks | len=3/33, type=0x03, masked type, bad checksum, checksum bypass, exp-length mismatch, multi-error | Correct ERR_FLAG bits; done still asserted; no hang | PASS | under/over length, bad type, checksum, bypass, multi |

The M3 test driver uses a separate `uvm`-free SV array model, not M1 RTL.
`busy_o` is checked high after start, `done_o` is checked high in DONE, and the
next accepted start clears `done_o`.

## Lab3 Testcases

| Testcase | Checkpoint | Input summary | Expected / check | Result | Method evidence |
|---|---|---|---|---|---|
| `lab3_e2e_test` | End-to-end APB packet path | Write 8-byte packet, enable and start, poll done, read results | Result matches reference; STATUS.done=1 | PASS | class inheritance, virtual test task |
| `lab3_two_frames_test` | Consecutive frame processing | Minimum packet followed by maximum packet | done clears on second start; both result sets correct | PASS | task reuse, status polling |
| `lab3_busy_protect_test` | Busy PKT_MEM write protection and STATUS encoding | Start 32-byte packet, read STATUS, then attempt write 0x044 | busy STATUS=2'b01; PSLVERR=1; SRAM unchanged; done STATUS=2'b10 | PASS | directed concurrent access |
| `lab3_irq_test` | done_irq and err_irq closure | Enable interrupts; valid frame; W1C; invalid checksum frame | IRQ set/clear and `irq_o` follow RW1C behavior | PASS | `fork...join_any`, timeout branch |
| `lab3_reset_recovery_test` | Reset safety | Reset during PROCESS and after DONE | busy/done/results return to reset values; no hang | PASS | reset recovery |

## Lab4 Testcases

| Testcase | Checkpoint | Input summary | Expected / check | Result | Coverage / seed |
|---|---|---|---|---|---|
| `lab4_random_test` | Constrained-random regression | 12 randomized packets per seed | All scoreboard checks pass | PASS | Seeds 1/2/3 |
| `lab4_error_mix_test` | Error cross coverage | Valid, length, type, checksum, bypass, multi-error, max packet | Exact ERR_FLAG and result checks | PASS | result x configuration and length/type bins |
| `lab4_closure_test` | Coverage closure | CSR/data masks, all PKT_MEM patterns, boundary addresses, busy start rejection, len=33, IRQ combinations | No functional mismatch; all closure bins hit | PASS | Seeds 1/2/3 |

Lab4 optional items:

- Coverage filter register: `coverage_filter_register.xlsx`
- Optional Lab1-LAB3 regression: PSLVERR, IRQ, type mask, checksum bypass,
  busy protection, and reset recovery are included in `make regress`.

## Reproducible Commands

```bash
make smoke
make regress
make cov
make mergecov
make report
```

Expected final evidence:

- `cov/merged.ucdb`: merged functional and DUT coverage database.
- `cov/dut_merged.ucdb`: code coverage scoped to `/tb/dut`.
- `cov/html_dut/index.html`: DUT code coverage report.
- `cov/html_functional/index.html`: functional coverage report.
- `cov/dut_summary.txt`: five code coverage classes.
- `cov/functional.txt`: covergroup and cross-bin details.

## Verification Structure

- `packet_item`: fixed array, dynamic payload array, byte queue, constrained-random
  packet shape, and reference calculations.
- `apb_monitor` and `apb_scoreboard`: independent APB transaction collection and
  consumption through a mailbox.
- `base_test`: APB/M3 driver tasks, transaction history queue, event/timeout
  handling, APB semaphore, and PASS/FAIL accounting.
- Test inheritance uses a virtual `run()` task overridden by all 13 tests.
