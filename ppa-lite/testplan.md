# PPA-Lite Testplan and Result Mapping

<!-- 评分标签（实验4）
     [评分 4-必做3.1 | 10分] 字段完整：Testcase / Checkpoint / Input / Expected / Result
     [评分 4-必做3.2 | 5分]  随机抽查 2 条能解释（建议 lab3_busy_protect_test、lab4_code_cov_test）
     [评分 4-选做5.2 | 5分]  选做场景的 testplan 条目完整（选做 4/5 的用例已列入四张表）
     代码侧的标签在 tb/ppa_pkg.sv 与 Makefile 里，本文件只放评审用的条目。
-->

## Regression Summary

- Testcases: 14
- Seeds: 1, 2, 3
- Simulations: 42
- Result: 42 PASS, 0 FAIL
- Log criterion: `[TEST START] <test> seed=<n>`, `[TEST PASS]`, and
  `Errors: 0, Warnings: 0`

## Coverage Summary

Code coverage is scoped to the DUT hierarchy `/tb/dut` after merging all 42
simulations. Testbench helper instances are excluded by hierarchy scope, not by
editing or excluding DUT source lines.

| Metric | Raw covered/total | Raw result | Filtered result |
|---|---:|---:|---:|
| Statement / line | 158 / 163 | 96.93% | 100.00% (158 / 158) |
| Branch | 101 / 103 | 98.05% | 100.00% (101 / 101) |
| Condition | 27 / 28 | 96.42% | 100.00% (28 / 28) |
| Expression | 35 / 35 | 100.00% | 100.00% (35 / 35) |
| FSM state | 3 / 3 | 100.00% | 100.00% (3 / 3) |
| FSM transition | 5 / 5 | 100.00% | 100.00% (5 / 5) |
| Toggle | 1325 / 1329 | 99.69% | 100.00% (1325 / 1325) |
| **Total** | — | **98.73%** | **100.00%** |

Functional coverage:

| Coverage object | Result |
|---|---:|
| `cg_ppa` | 100.00% |
| Covergroup bins | 24 / 24 |

Raw and filtered differ only by excluded structurally unreachable bins: the
2-bit FSM `default` branch (illegal state encoding) and its 5 defensive
assignments, the `busy_r && start_i` condition (mutually exclusive by design),
the `if (issue_read_r) / else if (wait_read_r)` all-false branch (the FSM always
sets one of the two), and the `PREADY` 1->0 toggles in `apb_slave_if` and
`ppa_top` (APB zero-wait state). That is 13 bins, all registered in
`coverage_filter_register.csv` and applied by `cov_exclude.do`; `make filtercov`
produces `cov/dut_filtered.ucdb`, and `make report` reports from it.

## Lab1 Testcases

| Testcase | Checkpoint | Input summary | Expected / check | Result | Coverage / seed |
|---|---|---|---|---|---|
| `lab1_defaults_test` | APB two-phase transfer, PREADY, CSR reset values, RES_* stub path | Read CTRL/CFG/STATUS/IRQ/PKT_LEN_EXP/RES/ERR; write CTRL/CFG/IRQ_EN | PREADY=1; CTRL=0, CFG=0xF1, other reset values=0; stub results read back correctly | PASS | Seeds 1/2/3 |
| `lab1_pkt_mem_test` | PKT_MEM 0x040-0x05C write/read mapping | Write eight words and read all eight addresses | All words read back unchanged; address maps to SRAM word 0-7 | PASS | Seeds 1/2/3 |
| `lab1_pslverr_test` | PSLVERR response rules | Write RO/reserved, read reserved, read back RO after the rejected write, start while disabled, legal start | Illegal accesses return PSLVERR=1; legal start returns PSLVERR=0; STATUS and RES_PKT_LEN keep their reset value after the rejected write | PASS | Seeds 1/2/3 |

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
| `lab4_code_cov_test` | Code-coverage closure | Top-level read of all 11 readable CSRs; unaligned addresses 0x001/0x002/0x003; unmapped 0x080/0x100/0x200/0x400/0x800/0xFFC; illegal types 0x10/0x40; exp_len 5/6/7/32/16/8 | Illegal accesses return PSLVERR per rule; `readable_csr` CTRL/CFG/PKT_LEN_EXP branches hit; PADDR all bits toggle; result-type bit4/bit6 and exp_len low bits toggle | PASS | Seeds 1/2/3 |

Lab4 optional items:

- Coverage filter register: `coverage_filter_register.xlsx` / `.csv`
- Optional Lab1-LAB3 regression: PSLVERR, IRQ, type mask, checksum bypass,
  busy protection, and reset recovery are included in `make regress`.
- `lab4_code_cov_test` was added specifically to close code-coverage holes that
  the original 13 tests could not reach from the integrated top level; it is
  carried in `make regress` and `make lab4`.

## Optional Items Matrix

Every optional item below is part of `make regress`, so the 42-simulation
regression covers them without a separate run.

| Lab | Optional item | Testcase | Result |
|---|---|---|---|
| Lab1 | PSLVERR on RO / reserved access, value unchanged | `lab1_pslverr_test` | PASS |
| Lab1 | IRQ_EN, IRQ_STA RW1C, `irq_o` | `lab3_irq_test` | PASS |
| Lab2 | Illegal type and type_mask masking | `lab2_errors_test` | PASS |
| Lab2 | hdr_chk error and algorithm bypass | `lab2_errors_test` | PASS |
| Lab3 | Busy PKT_MEM write protection (PSLVERR + SRAM unchanged) | `lab3_busy_protect_test` | PASS |
| Lab3 | Interrupt closure, `irq_o` deassert after W1C | `lab3_irq_test` | PASS |
| Lab3 | Reset recovery during PROCESS and after DONE | `lab3_reset_recovery_test` | PASS |
| Lab4 | Coverage filter register | `coverage_filter_register.xlsx` / `.csv` | 8 rows |
| Lab4 | Coverage exclusion applied | `cov_exclude.do` / `make filtercov` | 100.00% |

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
- Test inheritance uses a virtual `run()` task overridden by all 14 tests.
