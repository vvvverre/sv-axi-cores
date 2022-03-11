# sv-axi-cores

This repository contains a collection of IP cores with AXI4 and AXI4-Stream interfaces, written in (System)Verilog.
The cores in this repository have been verified using Icarus verilog and cocotb, and formal proofs are under development for some of the cores (see the `formal` branch for more details). 



## Contents

# axis\_bram\_writer
This core facilitates writing AXI4-Stream packets to FPGA block RAM; it contains an AXI4-Stream slave interface and a BRAM write-only interface.
The BRAM is not included inside this core, and has to be instantiated seperately. 

Packet contents are written to successive memory addresses starting at address 0.
The `TLAST` signal indicates the end of a packet, at which point the data will be written to address 0 again.
An interrupt output is provided which indicates the end of a packet.
An optional trigger input can be enabled, to indicate that the next packet should be written to BRAM.
When the trigger input is disabled the core is in continuous mode, where all packets are recorded and packet data will immediately be overwritten by the next packet.

# axis\_bram\_reader
This core faciliates reading AXI4-Stream packets from FPGA block RAM; it contains an AXI4-Stream master interface and a BRAM read-only interface.
The BRAM is not included inside this core and must be instantiated separately.

Packet contents are read from successive memory addresses starting at address 0.
The input signal `limit` controls the size of the packet (if limit is 0 the packet is considered to fill the whole BRAM).
The `TLAST` signal is used to indicate the end of a packet.

# axi\_bram\_interface
This core provides a translation between an AXI4-Lite interface and a BRAM memory block; it contains an AXI4-Lite (memory-mapped) slave interface and one BRAM (read and write) interface.
The BRAM is not included inside this core, and has to be instantiated seperately.

# axi\_axis\_recorder
This core records data from an AXI4-Stream, buffers it in Block RAM and allows it to be read via an AXI4-Lite interface.


