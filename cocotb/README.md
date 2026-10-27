# Simulation

Run these commands from the repository root.

## Tested tools

| Tool | Version | Notes |
| --- | --- | --- |
| Python | 3.12.15 |   |
| Vivado | 2026.1 | Simulation sources  |
| Verilator | 5.053 devel (`v5.052-256-g9637c62df`) | UART and HyperBus register-read tests passed |
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
