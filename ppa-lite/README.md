# PPA-Lite SV Verification Project

This directory contains the formal PPA-Lite design and SystemVerilog verification
project for the 2026 autumn simulation-verification track.

## Directory Layout

Two projects share this directory. The PPA-Lite files (`rtl/`, `tb/`, `cov/`,
`Makefile`) sit at the top level; the four MCDT course labs live beside them:

```
ppa-lite/
├── rtl/  tb/  cov/  Makefile        PPA-Lite APB DUT + verification
├── mcdt/                            MCDT DUT RTL (arbiter.v, mcdt.v, slave_fifo.v)
├── lab0/                            smoke test, plain Verilog
├── lab1/                            mcdt_pkg.sv, three directed tests
├── lab2/                            constrained-random + coverage regression
├── lab3/                            analysis-port / TLM refactor
├── lab4/                            virtual sequence refactor
├── 实验报告_mcdt.md                  MCDT lab report
└── 实验报告.md / 仿真方式.md / testplan.md   PPA-Lite report, manual, plan
```

Every lab Makefile references the DUT as `$(SIMDIR)/../mcdt`, so the four lab
folders must stay exactly one level below `mcdt/`. Do not move a lab folder out
on its own.

```bash
cd lab1 && make comp && make reg      # MCDT labs are driven the same way
cd lab2 && make comp && make reg && make report
```

## Design

- `rtl/apb_slave_if.sv`: APB 3.0 slave, CSR block, PKT_MEM window, IRQ and
  PSLVERR behavior.
- `rtl/packet_sram.sv`: 8 x 32-bit one-write/two-read synchronous SRAM.
- `rtl/packet_proc_core.sv`: three-state packet processing FSM.
- `rtl/ppa_top.sv`: top-level connection of M1, M2 and M3.

## Verification

- `tb/ppa_if.sv`: APB and standalone-M3 interfaces.
- `tb/ppa_pkg.sv`: packet model, reference results, coverage model and all tests.
- `tb/tb.sv`: DUT, standalone M3 model, clock/reset and test dispatch.

The test names in the package are the formal regression names. The complete
checkpoint mapping is in `testplan.md`.

Step-by-step Windows simulation instructions are in `仿真方式.md`.

## Required Commands

```bash
make smoke
make regress
make cov
make mergecov
make filtercov     # apply cov_exclude.do -> cov/dut_filtered.ucdb
make report
```

Run one test or change the seed:

```bash
make run TESTNAME=lab3_e2e_test SEED=7
make regress SEEDS="1 2 3"
```

14 testcases, 3 seeds, 42 simulations. Every run must print
`[TEST PASS] <test>` and `Errors: 0, Warnings: 0`.

Waveforms for the review are produced per lab. Each target writes into the
matching `labN/wave_ppa/` (the `lab3_irq_test` inside `wave1` goes to `lab3/`
because the file name prefix decides the directory):

```bash
make wave1   # lab1/wave_ppa: defaults / pkt_mem / pslverr  +  lab3/wave_ppa: irq
make wave2   # lab2/wave_ppa: valid / errors
make wave3   # lab3/wave_ppa: e2e / two_frames / busy_protect / irq / reset_recovery
make wave4   # lab4/wave_ppa: random / error_mix / closure / code_cov

vsim -view lab1/wave_ppa/lab1_pkt_mem_test.wlf -do wave/ppa_wave.do
```

`vsim -view` blocks the terminal until its window is closed, so these commands
cannot be chained in one shell. Double-click the per-lab script instead — it
uses `start` and opens every trace of that lab at once:

```text
打开实验1波形.bat   3 windows
打开实验2波形.bat   2 windows
打开实验3波形.bat   5 windows
打开实验4波形.bat   4 windows
```

Three trace scripts, each for one hierarchy — mixing them gives flat traces:

| Script | Scope | Use for |
|---|---|---|
| `wave/ppa_wave_lab1.do` | `/tb/u_lab1_m1` | `lab1_defaults_test`, `lab1_pslverr_test` |
| `wave/ppa_wave_m3.do` | `/tb/u_m3_standalone` | `lab2_valid_test`, `lab2_errors_test` |
| `wave/ppa_wave.do` | `/tb/dut` (`ppa_top`) | `lab1_pkt_mem_test`, all Lab3/Lab4 tests |

The merged database is `cov/merged.ucdb`, the DUT-only code coverage database
is `cov/dut_merged.ucdb`, the filtered one is `cov/dut_filtered.ucdb`, and the
two HTML reports are written to `cov/html_dut/index.html` and
`cov/html_functional/index.html`.

Code coverage before filtering is 98.73%; the remaining 13 bins are
structurally unreachable and listed in `coverage_filter_register.xlsx` /
`.csv`, applied through `cov_exclude.do`, which brings all five classes to
100.00%.

Review checklists, one per lab directory. Every scoring item is also tagged in
the source as `[评分 N-必做X.Y | points]` / `[评分 N-选做X.Y | points]`, so
searching that tag in `tb/ppa_pkg.sv` (or the `#` comments in `Makefile`) jumps
straight to the code:

- `lab1/实验1_验收对照.md`
- `lab2/实验2_验收对照.md`
- `lab3/实验3_验收对照.md`
- `lab4/实验4_验收对照.md`

Each `labN/` directory holds a whole experiment: the checklist, a read-only copy
of that lab's test classes (`labN/实验N_代码.svh`, sliced out of `tb/ppa_pkg.sv`),
`wave_ppa/*.wlf` written by `make waveN`, and `logs/` written by `make labN` /
`make regress`. The `.svh` copies are for reading only — compilation still uses
`tb/ppa_pkg.sv`, so edit there and re-slice if the tests change.

## Windows Path Note

QuestaSim does not open libraries reliably when the project path contains
non-ASCII characters. This project now lives at `C:\rkv_v1pro_labs\ppa-lite`,
which is pure ASCII, so `make` runs directly with no copying step.

The failure shows up at compile time, not at run time:

```
init_dbInfo() DATABASE ERROR: (sqlite3_open .../work/_lib.qdb): unable to open database file
mtiLibWrite(): INTERNAL ERROR: Unexpected null object encountered
** Fatal: (vlog-9) Problem while writing internal ...
```

`vlib` manages to create the `work` folder and its `_info` file, but the
sqlite library database `work/_lib.qdb` cannot be created, so every `vlog`
call dies. Source files are *not* the problem: `vlog` compiles fine from a
Chinese path as long as `-work` points at an ASCII directory.

If you ever move this project back under a non-ASCII path, either copy it to
an English path first or point `-work` at one. A half-built `work/` directory
also has to be removed, otherwise `comp` sees it and skips `vlib`.

Note that `make clean` deletes both `work/` and `cov/`. Do not run it if you
want to keep the saved coverage databases.
