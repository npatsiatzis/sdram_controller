![example workflow](https://github.com/npatsiatzis/sdram_controller/actions/workflows/regression_pyuvm.yml/badge.svg)
![example workflow](https://github.com/npatsiatzis/sdram_controller/actions/workflows/coverage_pyuvm.yml/badge.svg)

### SDR SDRAM controller (mt48lc64m4a2) RTL implementation

- includes the modules that constitute the controller namely, the **FSM** (sdram_FSM.vhd), the **command bus** (sdram_control_bus.vhd), the **data bus** (sdram_data_bus.vhd), a **package** with all necessary details, like timings, sdram commands etc.. (sdram_controller_pkg.vhd), a **wrapper** for the controller (sdram_top.vhd)  and a simple **simulation model** for mt48lc64m4a2, adapted from other simulation models available for similar sdram models
- pyuvm testbench for functional verification
    - $ make
    - 1 test with a series of write bursts in random (w.r.t. to bank,row,col address) locations with random data and then a similar series of read bursts on the same locations
    - 1 test with successive random data written in random (w.r.t. to bank,row,col address) locations 
    and after that a read transaction on that location (interleaved write-read bursts)


