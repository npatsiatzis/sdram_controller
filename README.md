![example workflow](https://github.com/npatsiatzis/sdram_controller/actions/workflows/regression.yml/badge.svg)
![example workflow](https://github.com/npatsiatzis/sdram_controller/actions/workflows/coverage.yml/badge.svg)

### SDR SDRAM controller (mt48lc64m4a2) RTL implementation

- includes the modules that constitute the controller namely, the **FSM** (sdram_FSM.vhd), the **command bus** (sdram_control_bus.vhd), the **data bus** (sdram_data_bus.vhd), a **package** with all necessary details, like timings, sdram commands etc.. (sdram_controller_pkg.vhd), a **wrapper** for the controller (sdram_top.vhd)  and a simple **simulation model** for mt48lc64m4a2, adapted from other simulation models available for similar sdram models
- CoCoTB testbench for functional verification
    - $ make
    - the test for now covers only a mixture of read/write burst commands. needs to be expanded


