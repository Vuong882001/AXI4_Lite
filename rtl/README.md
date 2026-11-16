# AXI4-Lite register block

`axi4_lite_regs.sv` implements a single-outstanding AXI4-Lite slave with a
small memory-mapped register bank. It is intended as a clean integration
starting point for a peripheral; replace or extend the register decode when
connecting project-specific control and status signals.

## Register map

| Offset | Name | Access | Reset / behavior |
| --- | --- | --- | --- |
| `0x00` | `CONTROL` | RW | Reset to zero; exposed as `control_reg` |
| `0x04` | `STATUS` | RO | Read from `status_reg`; writes return `SLVERR` |
| `0x08` | `SCRATCH0` | RW | Reset to zero |
| `0x0C` | `SCRATCH1` | RW | Reset to zero |

Unaligned and unmapped accesses return `SLVERR` (`2'b10`). Invalid reads return
zero. Writes to RW registers honor each byte lane's `WSTRB` bit.

## Integration notes

- `aresetn` is an active-low, synchronous reset.
- The default bus is 32-bit data with an 8-bit address. `DATA_WIDTH` supports
  32- or 64-bit data; the register offsets then advance by `DATA_WIDTH/8`
  bytes. `ADDR_WIDTH` must be wide enough to represent the four register
  words and their byte lanes.
- AW and W are buffered independently, so either write channel may arrive
  first. A write is committed when both beats have been accepted.
- The block allows one outstanding write response and one outstanding read
  response. `B*` and `R*` response payloads remain stable while their VALID is
  asserted and READY is low. Read and write paths can proceed independently.
- `status_reg` is sampled when its read address is accepted. `control_reg` is
  the software-controlled output.

Instantiate this module directly in the peripheral top level and connect all
five AXI4-Lite channels (`AW`, `W`, `B`, `AR`, `R`) to the interconnect.
