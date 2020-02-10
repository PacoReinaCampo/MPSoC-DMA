# DMA-MPSoC WIKI

A Direct memory access (DMA) is a feature of computer systems that allows hardware subsystems to access main system memory (random-access memory), independent of the Processing Unit (PU). A PU inside a SoC can transfer data to and from its local memory without occupying its processor time, allowing computation and data transfer to proceed in parallel.


## Instruction INPUTS/OUTPUTS AMBA3 AHB-Lite Bus

| Port         |  Size  | Direction | Description                                           |
| -------------| ------ | --------- | ----------------------------------------------------- |
| `HRESETn`    |    1   |   Input   | Asynchronous active low reset                         |
| `HCLK`       |    1   |   Input   | System clock input                                    |
|              |        |           |                                                       |
| `IHSEL`      |    1   |   Output  | Provided for AHB-Lite compatibility – tied high ('1') |
| `IHADDR`     | `PLEN` |   Output  | Instruction address                                   |
| `IHRDATA`    | `XLEN` |   Input   | Instruction read data                                 |
| `IHWDATA`    | `XLEN` |   Output  | Instruction write data                                |
| `IHWRITE`    |    1   |   Output  | Instruction write                                     |
| `IHSIZE`     |    3   |   Output  | Transfer size                                         |
| `IHBURST`    |    3   |   Output  | Transfer burst size                                   |
| `IHPROT`     |    4   |   Output  | Transfer protection level                             |
| `IHTRANS`    |    2   |   Output  | Transfer type                                         |
| `IHMASTLOCK` |    1   |   Output  | Transfer master lock                                  |
| `IHREADY`    |    1   |   Input   | Slave Ready Indicator                                 |
| `IHRESP`     |    1   |   Input   | Instruction Transfer Response                         |


## Instruction INPUTS/OUTPUTS Wishbone Bus

| Port    |  Size  | Direction | Description                     |
| --------| ------ | --------- | ------------------------------- |
| `rst`   |    1   |   Input   | Synchronous, active high        |
| `clk`   |    1   |   Input   | Master clock                    |
|         |        |           |                                 |
| `iadr`  | `PLEN` |   Input   | Lower address bits              |
| `idati` | `XLEN` |   Input   | Data towards the core           |
| `idato` | `XLEN` |   Output  | Data from the core              |
| `isel`  |    4   |   Input   | Byte select signals             |
| `iwe`   |    1   |   Input   | Write enable input              |
| `istb`  |    1   |   Input   | Strobe signal/Core select input |
| `icyc`  |    1   |   Input   | Valid bus cycle input           |
| `iack`  |    1   |   Output  | Bus cycle acknowledge output    |
| `ierr`  |    1   |   Output  | Bus cycle error output          |
| `iint`  |    1   |   Output  | Interrupt signal output         |


## Data INPUTS/OUTPUTS AMBA3 AHB-Lite Bus

| Port         |  Size  | Direction | Description                                           |
| -------------| ------ | --------- | ----------------------------------------------------- |
| `HRESETn`    |    1   |   Input   | Asynchronous active low reset                         |
| `HCLK`       |    1   |   Input   | System clock input                                    |
|              |        |           |                                                       |
| `DHSEL`      |    1   |   Output  | Provided for AHB-Lite compatibility – tied high ('1') |
| `DHADDR`     | `PLEN` |   Output  | Data address                                          |
| `DHRDATA`    | `XLEN` |   Input   | Data read data                                        |
| `DHWDATA`    | `XLEN` |   Output  | Data write data                                       |
| `DHWRITE`    |    1   |   Output  | Data write                                            |
| `DHSIZE`     |    3   |   Output  | Transfer size                                         |
| `DHBURST`    |    3   |   Output  | Transfer burst size                                   |
| `DHPROT`     |    4   |   Output  | Transfer protection level                             |
| `DHTRANS`    |    2   |   Output  | Transfer type                                         |
| `DHMASTLOCK` |    1   |   Output  | Transfer master lock                                  |
| `DHREADY`    |    1   |   Input   | Slave Ready Indicator                                 |
| `DHRESP`     |    1   |   Input   | Data Transfer Response                                |


## Data INPUTS/OUTPUTS Wishbone Bus

| Port    |  Size  | Direction | Description                     |
| --------| ------ | --------- | ------------------------------- |
| `rst`   |    1   |   Input   | Synchronous, active high        |
| `clk`   |    1   |   Input   | Master clock                    |
|         |        |           |                                 |
| `dadr`  | `PLEN` |   Input   | Lower address bits              |
| `ddati` | `XLEN` |   Input   | Data towards the core           |
| `ddato` | `XLEN` |   Output  | Data from the core              |
| `dsel`  |    4   |   Input   | Byte select signals             |
| `dwe`   |    1   |   Input   | Write enable input              |
| `dstb`  |    1   |   Input   | Strobe signal/Core select input |
| `dcyc`  |    1   |   Input   | Valid bus cycle input           |
| `dack`  |    1   |   Output  | Bus cycle acknowledge output    |
| `derr`  |    1   |   Output  | Bus cycle error output          |
| `dint`  |    1   |   Output  | Interrupt signal output         |


## Count Lines of Code

|Language              | files | blank | comment | code |
| ---------------------| ----- | ----- | ------- | ---- |
|VHDL                  |    18 |   652 |    1482 | 3869 |
|Verilog-SystemVerilog |    18 |   515 |    1356 | 3048 |


## Hardware Description Language

dma
├── bench
│   ├── verilog
│   │   └── regression
│   │       └── mpsoc_dma_testbench.sv
│   └── vhdl
│       └── regression
│           └── mpsoc_dma_testbench.vhd
├── doc
│ └── WIKI-DMA-MPSoC.md
├── rtl
│   ├── verilog
│   │   ├── ahb3
│   │   │   ├── mpsoc_dma_ahb3_initiator_nocres.sv
│   │   │   ├── mpsoc_dma_ahb3_initiator_req.sv
│   │   │   ├── mpsoc_dma_ahb3_initiator.sv
│   │   │   ├── mpsoc_dma_ahb3_interface.sv
│   │   │   ├── mpsoc_dma_ahb3_target.sv
│   │   │   └── mpsoc_dma_ahb3_top.sv
│   │   ├── core
│   │   │   ├── mpsoc_dma_arb_rr.sv
│   │   │   ├── mpsoc_dma_initiator_nocreq.sv
│   │   │   ├── mpsoc_dma_packet_buffer.sv
│   │   │   └── mpsoc_dma_request_table.sv
│   │   ├── pkg
│   │   │   └── mpsoc_dma_pkg.sv
│   │   └── wb
│   │       ├── mpsoc_dma_wb_initiator_nocres.sv
│   │       ├── mpsoc_dma_wb_initiator_req.sv
│   │       ├── mpsoc_dma_wb_initiator.sv
│   │       ├── mpsoc_dma_wb_interface.sv
│   │       ├── mpsoc_dma_wb_target.sv
│   │       └── mpsoc_dma_wb_top.sv
│   └── vhdl
│       ├── ahb3
│       │   ├── mpsoc_dma_ahb3_initiator_nocres.vhd
│       │   ├── mpsoc_dma_ahb3_initiator_req.vhd
│       │   ├── mpsoc_dma_ahb3_initiator.vhd
│       │   ├── mpsoc_dma_ahb3_interface.vhd
│       │   ├── mpsoc_dma_ahb3_target.vhd
│       │   └── mpsoc_dma_ahb3_top.vhd
│       ├── core
│       │   ├── mpsoc_dma_arb_rr.vhd
│       │   ├── mpsoc_dma_initiator_nocreq.vhd
│       │   ├── mpsoc_dma_packet_buffer.vhd
│       │   └── mpsoc_dma_request_table.vhd
│       ├── pkg
│       │   └── mpsoc_dma_pkg.vhd
│       └── wb
│           ├── mpsoc_dma_wb_initiator_nocres.vhd
│           ├── mpsoc_dma_wb_initiator_req.vhd
│           ├── mpsoc_dma_wb_initiator.vhd
│           ├── mpsoc_dma_wb_interface.vhd
│           ├── mpsoc_dma_wb_target.vhd
│           └── mpsoc_dma_wb_top.vhd
├── sim
│   ├── mixed
│   │   └── regression
│   │       └── bin
│   │           ├── mpsoc_dma_verilog.vc
│   │           ├── mpsoc_dma_vhdl.vc
│   │           ├── Makefile
│   │           ├── run.do
│   │           └── transcript
│   ├── verilog
│   │   └── regression
│   │       └── bin
│   │           ├── mpsoc_dma.vc
│   │           ├── Makefile
│   │           ├── run.do
│   │           └── transcript
│   └── vhdl
│       └── regression
│           └── bin
│               ├── mpsoc_dma.vc
│               ├── Makefile
│               ├── run.do
│               └── transcript
├── system.vtor
├── system.qf
├── system.ys
├── README.md
├── CLEAN-IT
├── DELETE-IT
├── EXECUTE-IT
├── SIMULATE-MIXED-MS-IT
├── SIMULATE-VHDL-GHDL-IT
├── SIMULATE-VHDL-MS-IT
├── SIMULATE-VLOG-IV-IT
├── SIMULATE-VLOG-MS-IT
├── SIMULATE-VLOG-VTOR-DMA-IT
├── SYNTHESIZE-VLOG-YS-IT
├── TRANSLATE-IT
└── UPLOAD-IT
