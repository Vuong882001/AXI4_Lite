# Questa/ModelSim simulation

This directory keeps the SPI simulation layout (`rtl.f`, `tb.f`,
`compile.f`, and `Makefile`) but points it at the AXI4-Lite RTL and direct
self-checking testbench. The simulation top is `tb_axi4_lite_regs`; no UVM
packages or SPI sources are needed.

From this directory, run:

```sh
make run
```

Useful targets are `make compile`, `make run_wave`, `make exec_wave`, and
`make clean`. The default Questa installation is `/home/thanhvuong/questasim`;
override `QUESTA_HOME`, `QUESTA_BIN`, or `QUESTA_LICENSE` if needed. Compile
output is written to `compile.log`; run output is written to
`axi4_lite_regs_direct.log`. The testbench prints each channel handshake and
response and reports `TEST PASS` at completion.
