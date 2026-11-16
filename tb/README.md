# Direct testbench

`tb_axi4_lite_regs.sv` is a directed, self-checking testbench for the basic
register block behavior. It prints each accepted channel beat and response,
and ends with `TEST PASS` or stops at the first mismatch with `$fatal`.

Run with Icarus Verilog from the project root:

```sh
iverilog -g2012 -s tb_axi4_lite_regs -o /tmp/tb_axi4_lite_regs.vvp \
  rtl/axi4_lite_regs.sv tb/tb_axi4_lite_regs.sv
vvp /tmp/tb_axi4_lite_regs.vvp
```

The directed cases cover reset values, full and partial writes, both AW/W
arrival orders plus simultaneous arrival, read-only and unmapped writes,
unaligned reads, and B/R response stability while the master applies
backpressure.
