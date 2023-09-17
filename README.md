![example workflow](https://github.com/npatsiatzis/sdram_controller/actions/workflows/regression.yml/badge.svg)
![example workflow](https://github.com/npatsiatzis/sdram_controller/actions/workflows/coverage.yml/badge.svg)

### SDR SDRAM controller (mt48lc64m4a2) RTL implementation

- includes the modules that constitute the controller namely, the **FSM** (sdram_FSM.vhd), the **command bus** (sdram_control_bus.vhd), the **data bus** (sdram_data_bus.vhd), a **package** with all necessary details, like timings, sdram commands etc.. (sdram_controller_pkg.vhd), a **wrapper** for the controller (sdram_top.vhd)  and a simple **simulation model** for mt48lc64m4a2, adapted from other simulation models available for similar sdram models
- CoCoTB testbench for functional verification
    - $ make
    - 1 test with a series of write bursts in random (w.r.t. to bank,row,col address) locations with random data and then a similar series of read bursts on the same locations
    - 1 test with successive random data written in random (w.r.t. to bank,row,col address) locations 
    and after that a read transaction on that location (interleaved write-read bursts)


### Repo Structure

This is a short tabular description of the contents of each folder in the repo.

| Folder | Description |
| ------ | ------ |
| [rtl](https://github.com/npatsiatzis/sdram_controller/tree/main/rtl/VHDL) | VHDL RTL implementation files |
| [cocotb_sim](https://github.com/npatsiatzis/sdram_controller/tree/main/cocotb_sim) | Functional Verification with CoCoTB (Python-based) |
| [pyuvm_sim](https://github.com/npatsiatzis/sdram_controller/tree/main/pyuvm_sim) | Functional Verification with pyUVM (Python impl. of UVM standard) |


This is the tree view of the strcture of the repo.
<pre>
<font size = "2">
.
├── <font size = "4"><b><a href="https://github.com/npatsiatzis/sdram_controller/tree/main/rtl">rtl</a></b> </font>
│   └── VHD files
├── <font size = "4"><b><a href="https://github.com/npatsiatzis/sdram_controller/tree/main/cocotb_sim">cocotb_sim</a></b></font>
│   ├── Makefile
│   └── python files
└── <font size = "4"><b><a 
 href="https://github.com/npatsiatzis/sdram_controller/tree/main/pyuvm_sim">pyuvm_sim</a></b></font>
    ├── Makefile
    └── python files
</pre>