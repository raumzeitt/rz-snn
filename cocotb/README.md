# Simulation

Run these commands from the repository root.

## Tested tools

| Tool | Version | Notes |
| --- | --- | --- |
| Python | 3.12.15 |   |
| Vivado | 2026.1 | Simulation sources  |
| Verilator | 5.053 devel (`v5.052-256-g9637c62df`) | UART and HyperBus ID/memory readback tests passed |
| Questa Altera Starter FPGA Edition | 2025.2 | Slow |
| Icarus Verilog | 12.0 | HyperBus has unsupported SystemVerilog features  |

Python dependencies are listed in `cocotb/requirements.txt`.

## Vivado setup

Set `XILINX_VIVADO` to your Vivado installation directory so simulations can
find the Xilinx simulation sources. Add this to `~/.bashrc`, adjusting the
path for your installation:

```bash
export XILINX_VIVADO=/mnt/c/AMDDesignTools/2026.1/Vivado
```

Reload the shell configuration once, or open a new terminal:

```bash
source ~/.bashrc
```

## Create the Python environment

```bash
conda create -n rz-snn-sim python=3.12 pip
conda activate rz-snn-sim
python -m pip install -r cocotb/requirements.txt
```

The requirements currently pin cocotb to version 1.9.2.

Activate the environment each time you open a new terminal:

```bash
conda activate rz-snn-sim
```

## Run snnTorch notebooks

The Python requirements also include the SNN training and notebook dependencies.
Install FFmpeg through Conda so Matplotlib can render notebook animations:

```bash
conda activate rz-snn-sim
conda install -c conda-forge ffmpeg
```

FFmpeg is an external executable and is not installed by the pip requirements.
In VS Code, select `rz-snn-sim` as the notebook kernel. Restart the kernel after
installing FFmpeg, then rerun the animation cells.

## Run the UART test

Ensure Questa is on your PATH, then run:

```bash
make -C cocotb/uart SIM=questa
```

To use Verilator instead:

```bash
make -C cocotb/uart SIM=verilator
```

## Run the HyperBus test

Activate the simulation environment and run:

```bash
conda activate rz-snn-sim
make -C cocotb/hyperbus SIM=verilator WAVES=0
```

- `SPEEDUP=1`: UART divisor 4 (25 Mbaud at 100 MHz); default is normal speed.
- `WAVES=1`: generate `cocotb/hyperbus/dump.fst`.
- Use `-B` when changing speedup or tracing settings to force recompilation.
- `LOG_LEVEL=INFO` is exported by both Makefiles; override it on the command line.
- HyperBus test covers ID reads and five random memory words; calibration is
  separate. See `doc/hyperbus.md` for `HyperBusCalibration.calibrate()`.


## Shared Python helpers

`cocotb/uart` contains the UART transports and register/AXI access helpers.
Both simulation Makefiles add it to `PYTHONPATH`. HyperBus calibration stays
in `cocotb/hyperbus`.

For PC use, run from the repository root:

```bash
python -m pip install -r cocotb/requirements.txt
export PYTHONPATH="$PWD/cocotb/uart${PYTHONPATH:+:$PYTHONPATH}"
```

- `UartTransactor(dut, baud, timeout_us=1000)`: simulated UART.
- `PcUartTransactor(port, baud=115200, timeout=1.0)`: PC serial UART.
- Both inherit `UartAccess`: `wr32`/`rd32` use little-endian APB byte accesses;
  `axi_write` transfers one word, and `axi_read` returns bytes (length in bytes,
  multiple of four). Multiple words use separate AXI transactions, not a burst.
- `uart_access.py` defines the AXI-access base/offsets and status poll limit.
- Calibration accepts either transactor. Run after startup/configuration;
  scratch memory is overwritten and access failures require a caller reset.
