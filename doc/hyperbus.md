# HyperBus programming interface

Describes the checked-out HyperBus RTL at revision `fe4059f`, with the
`rz-snn` integration configured for 32-bit registers, two chips and one PHY.
Offsets below are byte offsets relative to the controller configuration base.
They describe controller registers, not the HyperRAM device registers.

## Interfaces and register access

The IP exposes two independent software-facing interfaces:

- The register request/response bus configures timing, address mapping and
  memory/device-register selection.
- The AXI slave performs reads and writes through the configured HyperBus
  address space. Controller configuration registers are not accessed through
  this AXI slave.

All registers below are read/write. Each occupies one 32-bit word. Reads
zero-extend the implemented field; writes retain only the implemented bits.
Byte write strobes preserve unselected bytes. There are no write-one-to-clear
fields, commands or read side effects in this register file.

The register bus deasserts `ready` while an AXI transaction is active, for
both reads and writes. Stop issuing AXI transfers and wait for outstanding
responses before changing configuration. The write logic is qualified by
`valid`, `write` and a mapped index, not by `ready`, so do not use this stall
as protection against presenting configuration writes during a transfer.

For this configuration, the register index is address bits `[5:2]`.
Low address bits do not select a lane inside the IP; `wstrb` does that.
Higher address bits are ignored by the register file, so the surrounding bus
must decode the configuration aperture. The generic register file signals
`error` for an index outside `12 + 2*NumChips`; with two chips all 16 indices
are occupied. No software-visible busy, interrupt or status register exists.

## Register map

Reset values assume the default `RstCfg`, `MinFreqMHz=100`,
`RstChipBase=0` and `RstChipSpace=0x10000` inherited by the current wrapper.
Integrations can override these parameters.

| Offset | Register | Bits | Reset | Meaning |
| --- | --- | --- | --- | --- |
| `0x00` | `T_LATENCY_ACCESS` | `[3:0]` | `6` | Base access-latency countdown loaded after command/address transmission. |
| `0x04` | `EN_LATENCY_ADDITIONAL` | `[0]` | `0` | Force the additional latency interval. Zero still permits extra latency requested through sampled RWDS. |
| `0x08` | `T_BURST_MAX` | `[15:0]` | `350` (`0x15e`) | Data-phase countdown limit; long transfers are split and continued with another command. Default is `(MinFreqMHz*35)/10`. |
| `0x0c` | `T_READ_WRITE_RECOVERY` | `[3:0]` | `6` | Recovery countdown used between physical transfers. |
| `0x10` | `T_RX_CLK_DELAY` | `[7:0]` | `0x10` | Receive RWDS clock-delay selection. The supplied delay primitive uses only `[4:0]`. |
| `0x14` | `T_TX_CLK_DELAY` | `[7:0]` | `0x10` | Transmit clock-delay selection when `UsePhyClkDivider=0`. |
| `0x18` | `ADDRESS_MASK_MSB` | `[4:0]` | `25` | Keep the lowest N AXI address bits before converting the byte address to a device word address. |
| `0x1c` | `ADDRESS_SPACE` | `[0]` | `0` | `0`: HyperRAM memory; `1`: HyperRAM device-register space. Applies to subsequent AXI transfers. |
| `0x20` | `PHYS_IN_USE` | `[0]` | `0` | Number of active PHYs minus one. With `NumPhys=1`, writes force zero. |
| `0x24` | `WHICH_PHY` | `[0]` | `0` | Select PHY 0 or 1 when using one of two instantiated PHYs. With `NumPhys=1`, writes force zero. |
| `0x28` | `T_CSH_CYCLES` | `[3:0]` | `1` | Chip-select-high countdown between physical transfer segments. |
| `0x2c` | `CSN_TO_CK_CYCLES` | `[3:0]` | `0` | Additional PHY cycles between asserting chip select and starting the command clock; zero bypasses this delay. |
| `0x30` | `CRANGE0_START` | `[31:0]` | `0x00000000` | Chip 0 AXI range start, inclusive. |
| `0x34` | `CRANGE0_END` | `[31:0]` | `0x00010000` | Chip 0 AXI range end, exclusive. |
| `0x38` | `CRANGE1_START` | `[31:0]` | `0x00010000` | Chip 1 AXI range start, inclusive. |
| `0x3c` | `CRANGE1_END` | `[31:0]` | `0x00020000` | Chip 1 AXI range end, exclusive. |

For chip i, START is at `0x30 + 8*i` and END at `0x34 + 8*i`.
Reset START is `RstChipBase + RstChipSpace*i`; reset END is
`RstChipBase + RstChipSpace*(i+1)`.

Timing registers contain PHY state-machine counter settings, not nanoseconds
or system-clock delays. Account for the configured PHY clock generation and
state transitions when selecting values. Register-space writes bypass access
latency in the PHY. The behavioral receive delay is `tap*78 ps + 10 ps`;
that simulation formula is not a calibration guarantee for hardware.

## AXI address mapping and device registers

Chip selection uses the unmasked AXI byte address and the programmed START/END
ranges. Avoid overlapping ranges. Unmatched addresses fall back to chip 0;
this decoder does not reject an unmapped access with DECERR.

Range START selects the chip; it is not subtracted from the AXI address.
With one PHY, the transmitted device word address is:

```text
(axi_byte_address & ((1 << ADDRESS_MASK_MSB) - 1)) >> 1
```

Choose chip windows and the mask together so the intended chip-local byte
address survives masking. The reset 64 KiB windows are defaults, not an
assertion that the attached RAM has that capacity.

To access a HyperRAM identification or configuration register, set
`ADDRESS_SPACE=1` and issue an AXI transfer to its device address using the
same chip-selection and address-conversion rules. Set `ADDRESS_SPACE=0`
before returning to memory access. The device's own register definitions,
latency mode and reset values come from its datasheet/model; they are not
controller configuration registers.

Use AXI INCR transfers; the PHY emits linear HyperBus bursts and explicitly
does not implement wrapping bursts. Writes use AXI byte strobes for data
masking. PHY-reported errors become SLVERR; otherwise responses are OKAY.
An OKAY response does not by itself validate returned data.

## Programming sequence

1. Apply system and PHY reset. Allow the device power-up interval and the
   configured PHY startup interval (`PhyStartupCycles`, default 60000 PHY
   cycles); startup completion has no software status bit.
2. Keep AXI traffic stopped while configuring the controller.
3. Program nonoverlapping chip ranges, the address mask, and timing settings
   appropriate to the actual clock and memory device.
4. If needed, select device-register space, access the device through AXI,
   and wait for its responses before changing controller configuration again.
5. Select memory space and perform AXI memory transfers.

## Current UART wrapper and test discrepancies

`rtl/top/hyperbus_fpga_top.sv` exposes configuration through an 8-bit UART/APB
bridge. Byte address `offset+b` selects byte lane b of a register; writes
replicate the data byte and select one lane with `wstrb`. Send a 32-bit value
as four writes, least significant byte first. These four writes are not atomic.

UART commands in `rtl/modules/uart_apb_top.sv` are:

```text
Write byte: 01 address data    (no acknowledgement byte)
Read byte:  02 address         (returns one data byte)
```

The UART divider is hardcoded to 868, giving approximately 115200 baud at
100 MHz. Controller configuration occupies `0x00` through `0x3f`; the decoder
uses 12 base registers plus two range registers per chip.

The AXI access block occupies `0x80` through `0x8f`: address at `0x80..0x83`,
data at `0x84..0x87`, command at `0x88`, and status at `0x89`.
It does not expose an APB slave-error signal to the host.

`cocotb/hyperbus/hyperbus.py` uses the current chip-range offsets and asserts
the device-register read result. It does not test memory write/readback.
Its direct AXI master must be adapted to the UART access path now that RTL
drives the AXI interface.

## RTL sources

- `lib/hyperbus/src/hyperbus_cfg_regs.sv`: register indexing, writes and chip ranges.
- `lib/hyperbus/src/hyperbus_pkg.sv`: field widths and reset configuration.
- `lib/hyperbus/src/hyperbus_axi.sv`: chip selection, address conversion and AXI responses.
- `lib/hyperbus/src/hyperbus_phy.sv`: timing counters and device-register transfers.
- `lib/hyperbus/src/hyperbus_delay.sv`: receive delay selection.
