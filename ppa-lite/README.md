# PPA-Lite SV Verification Project

This directory contains the formal PPA-Lite design and SystemVerilog verification
project for the 2026 autumn simulation-verification track.

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
make report
```

Run one test or change the seed:

```bash
make run TESTNAME=lab3_e2e_test SEED=7
make regress SEEDS="1 2 3"
```

The merged database is `cov/merged.ucdb`, the DUT-only code coverage database
is `cov/dut_merged.ucdb`, and the two HTML reports are written to
`cov/html_dut/index.html` and `cov/html_functional/index.html`.

## Windows Path Note

QuestaSim does not open libraries reliably when the project path contains
non-ASCII characters. If this directory is under a Chinese path, copy
`ppa-lite/` to a pure English path (for example `C:/ppa_lite_run/`) before
running the Makefile.
