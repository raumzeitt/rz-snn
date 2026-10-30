import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, Timer,  First, Edge, Combine

from uart_cocotb import UartTransactor
from calibration import HyperBusCalibration
from cocotbext.apb import ApbBus, ApbRam, ApbMaster
from cocotbext.axi import AxiBus, AxiMaster

import sys, os, time, random, logging
from struct import unpack
from math import ceil

# Match the RTL clock and baud defaults; account for integer baud division.
CLK_FREQ = int(os.environ.get("CLK_FREQ", 200_000_000))
BAUD_RATE = int(os.environ.get("BAUD_RATE", 115200))
UART_DIVISOR = int(os.environ.get("UART_DIVISOR", CLK_FREQ / BAUD_RATE))
UART_BAUD = CLK_FREQ / UART_DIVISOR

# pip install cocotbext-uart
# 2.0  - pip install cocotbext-axi
# 1.9 - pip install cocotbext-apb

async def clock_n_reset(c, r, f=0, t=10):
    if r is not None:
        r.value = 0
    if c is not None:
        period = round(1e9/f, 2) # in ns
        #print (f"p={period}ns, f={f}Hz")
        #raise  
        cocotb.start_soon(Clock(c, period, units="ns").start())
        await Timer(t, 'us')
    else:
        await Timer(t, 'us')
    if r is not None:
        r.value = 1


class ApbTransactor:
    def __init__(self, dut):
        self.dut = dut
        # alias signals
        signals = {s: s.upper() for s in ["paddr", "psel", "penable", "pwrite", "pwdata", "pready", "prdata"]}
        apb_bus = ApbBus(
            dut,
            "",   # no prefix
            signals=signals
        )
        self.apb_master = ApbMaster(apb_bus, dut.clk)
        #apb_ram = ApbRam(
        #    apb_bus,
        #    dut.clk,
        #    dut.rst_n,
        #    reset_active_level=False,  # if active-low
        #)


class AxiTransactor:
    def __init__(self, dut):
        self.axi_master = AxiMaster(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n, reset_active_level=False)

    
@cocotb.test()
async def hyperram_test(dut):
    log_level = os.environ["LOG_LEVEL"] # NOTSET=0 DEBUG=10 INFO=20 WARN=30 ERROR=40 CRITICAL=50
    dut._log.setLevel(log_level)
    logging.getLogger("HyperBus calibration").setLevel(log_level)

    # Hack/Fix for missing "negedge reset" in verilator
    dut.rst_n.value = 1
    await Timer(1, 'ps')

    # Transactors
    u = UartTransactor(dut, baud=UART_BAUD)
    #p = ApbTransactor(dut.hyperbus_fpga_top)
    #x = AxiTransactor(dut.hyperbus_fpga_top)

    tRP = 0.2  # Minimum RESET# low pulse width: 200 ns
    cr = cocotb.start_soon(clock_n_reset(dut.clk, dut.rst_n, f=CLK_FREQ, t=tRP))       
    await RisingEdge(dut.rst_n)
    await ClockCycles(dut.clk, 2 * 60000)  # PHY startup; covers divider enabled or disabled

    # wait n=16 periods of baud clock (UART needs that)
    await Timer(17 * 1e9 / UART_BAUD, 'ns')
    
    # Basic test
    if 0:
        # 1. read all addresses
        for a in range(64):
            r = await u.uart_read(a)

        # 2. write all addresses
        for a in range(64):
            await u.uart_write(a, 255)

        # 3. read all addresses
        for a in range(64):
            r = await u.uart_read(a)

        await Timer(1, 'ms')

    # Basic test from ETH
    # --- RESET / WAIT ---
    # --- CONFIG (APB) ---
    await u.wr32(0x00, 0x00000007)   # 0x0 *4  T_LATENCY_ACCESS - 7 @ 200MHz
    tCSS = 4e-9  # Minimum CS#-to-CK setup time: 4 ns
    await u.wr32(0x2C, ceil(tCSS * CLK_FREQ))  # CSN_TO_CK_CYCLES: 1 extra cycle = 5 ns at 200 MHz
    #await u.wr32(0x04, 0x00000000)   # 0x1 *4  EN_LATENCY_ADDITIONAL - no need
    #await u.wr32(0x10, 0x00000006)   # 0x4 *4  T_RX_CLK_DELAY
    #await u.wr32(0x14, 0x00000000)   # 0x5 *4  T_TX_CLK_DELAY
    # --- CRANGE ---
    await u.wr32(0x30, 0x00000000)   # 0xC *4  CRANGE0_START
    await u.wr32(0x34, 0x00FFFFFF)   # 0xD *4  CRANGE0_END
    #await u.wr32(0x38, 0x01000000)   # 0xE *4  CRANGE1_START
    #await u.wr32(0x3C, 0x01FFFFFF)   # 0xF *4  CRANGE1_END

    # Calibrate RX and TX before the ID and memory tests.
    HB_EXPECTED_ID = int(os.environ.get("HB_EXPECTED_ID", "0x0E860E86"), 0)
    HB_TX_IS_DIVIDER = int(os.environ.get("HB_TX_IS_DIVIDER", 0))
    await HyperBusCalibration(u, expected_id=HB_EXPECTED_ID).calibrate(tx_is_divider=HB_TX_IS_DIVIDER)

    # --- REGISTER SPACE ---
    await u.wr32(0x1C, 0x00000001)   # 0x7 *4  ADDRESS_SPACE = 1


    # size=2 -> bytes in word = 2^size = 4
    # length = 4 = 4 bytes -> words = length in bytes / bytes per word = 4/4 = 1 words

    #r = cocotb.start_soon(x.axi_master.read(0x00000000, length=8, size=2 , prot=0))
    #t = Timer(25, 'us')
    #res = await First(t, r)
    #if res is t:
    #   raise TimeoutError("AXI read timeout")
    #data = res.data
    #assert res.resp == 0  # AXI response status 0 = OK
    #await Timer(1, 'us')

    data = await u.axi_read(0x00000000)
    data += await u.axi_read(0x00000000)

    data_lst = list(unpack(f'<{len(data)//4}I', data))  # < = little endian, I = uint32, len(data)//4 =number of words  - list of 32 bit integers
    assert data_lst == [HB_EXPECTED_ID] * (len(data)//4)
    data_str = [f'0x{i:08x}' for i in data_lst]

    dut._log.info(f"AXI read: RDATA={data_lst}")
    dut._log.info(f"AXI read: RDATA={' '.join(data_str)}")

    # Write five random words to sequential addresses, then check all five.
    await u.wr32(0x1C, 0x00000000) # ADDRESS_SPACE = memory
    memory_words = [random.getrandbits(32) for _ in range(5)]

    for i, value in enumerate(memory_words):
        addr = 0 + 4*i
        await u.axi_write(addr, value)
        dut._log.info(f"Memory write: A=0x{addr:08x} D=0x{value:08x}")

    for i, expected in enumerate(memory_words):
        addr = 0 + 4*i
        memory_data = int.from_bytes(await u.axi_read(addr), "little")
        assert memory_data == expected
        dut._log.info(f"Memory readback: A=0x{addr:08x} D=0x{memory_data:08x}")

    await Timer(5, 'us')
    # assert False, "Forced failure"
    raise cocotb.result.TestSuccess("Passed")  # End test immediately with PASS




    # --- READ MR0 ---
    #mr0_chip0 = await axi_read(dut, 0x00000000)
    #mr0_chip1 = await axi_read(dut, 0x01000000)

    #print("MR0 CHIP0 =", hex(mr0_chip0))
    #print("MR0 CHIP1 =", hex(mr0_chip1))

    # --- BACK TO MEMORY ---
    #await apb_write(dut, 0x0000001C, 0x00000000)


    #await apb_write(dut, 0x30, 0x00000000)   # CRANGE0_START
    #await apb_write(dut, 0x34, 0x00FFFFFF)   # CRANGE0_END

    #await apb_write(dut, 0x00, 0x6)          # T_LATENCY_ACCESS = 6
    #await apb_write(dut, 0x04, 0x0)          # EN_LATENCY_ADDITIONAL = 0

    #await apb_write(dut, 0x14, 0x0)          # T_TX_CLK_DELAY
    #await apb_write(dut, 0x10, 0x6)          # T_RX_CLK_DELAY (start)

    #await apb_write(dut, 0x0C, 0x8)          # T_RW_RECOVERY
    #await apb_write(dut, 0x08, 0x10)         # T_BURST_MAX

    # --- READ MR0 ---
    #await apb_write(dut, 0x1C, 0x1)          # ADDRESS_SPACE = register
    #mr0 = await axi_read(dut, 0x0)           # MR0
    #print("MR0 =", hex(mr0))
    #await apb_write(dut, 0x1C, 0x0)          # ADDRESS_SPACE = memory

    # --- FIRST MEMORY TEST ---
    #await axi_write(dut, 0x0, 0xA5A5A5A5)
    #r = await axi_read(dut, 0x0)
    #print("READ0 =", hex(r))
    #assert r == 0xA5A5A5A5

    # --- SECOND ADDRESS TEST ---
    #await axi_write(dut, 0x4, 0x12345678)
    #r = await axi_read(dut, 0x4)
    #print("READ4 =", hex(r))
    #assert r == 0x12345678
