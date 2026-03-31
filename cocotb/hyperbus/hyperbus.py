import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, Timer,  First, Edge, Combine

from cocotbext.uart import UartSource, UartSink
from cocotbext.apb import ApbBus, ApbRam, ApbMaster
from cocotbext.axi import AxiBus, AxiMaster

import sys, os, time, random, logging

# pip install cocotbext-uart
# 2.0  - pip install cocotbext-axi
# 1.9 - pip install cocotbext-apb

async def clock_n_reset(c, r, f=0, n=5, t=10):
    if r is not None:
        r.value = 0
    if c is not None:
        period = round(1e9/f, 2) # in ns
        #print (f"p={period}ns, f={f}Hz")
        #raise  
        cocotb.start_soon(Clock(c, period, units="ns").start())
        await ClockCycles(c, n)
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

    
class UartTransactor:
    def __init__(self, dut):
        self.dut = dut
        self.log = logging.getLogger("UART Transactor")
        self.log.setLevel(self.dut._log.level)

        self.uart_source = UartSource(dut.uart_rx, baud=115200, bits=8, stop_bits=1)
        self.uart_sink = UartSink(dut.uart_tx, baud=115200, bits=8, stop_bits=1)

    async def uart_write(self, address, data):
        self.log.info(f"UART WRITE: ADDRESS=0x{address:02x} DATA=0x{data:02x}")
        await self.uart_source.write(bytes([0x1, address, data]))
        await self.uart_source.wait()

    async def uart_cmd(self, cmd):
        assert cmd != 1
        assert cmd != 2
        self.log.info(f"UART COMMAND: COMMAND=0x{cmd:02x} ")
        await self.uart_source.write(bytes([cmd]))
        await self.uart_source.wait()

    async def uart_read(self, address):
        t = cocotb.start_soon(self.uart_source.write(bytes([0x2, address])))  
        r = cocotb.start_soon(self.uart_sink.read())  
        await Combine(t, r)
        data = r.result()
        data = data[0] #bytearray
        self.log.info(f"UART READ:  ADDRESS=0x{address:02x} DATA=0x{data:02x}")
        return data

    async def wr32(self, address, data):
        for i in range(4):
            await self.uart_write(address + i, (data>>(8*i)) & 0xff)

@cocotb.test()
async def uart_test(dut):
    log_level = os.environ.get('LOG_LEVEL', 'INFO') # NOTSET=0 DEBUG=10 INFO=20 WARN=30 ERROR=40 CRITICAL=50
    dut._log.setLevel(log_level)

    # Hack/Fix for missing "negedge reset" in verilator
    dut.rst_n.value = 1
    await Timer(1, 'ps')

    # Transactors
    u = UartTransactor(dut)
    p = ApbTransactor(dut.hyperbus_fpga_top)
    x = AxiTransactor(dut.hyperbus_fpga_top)

    # 100MHz clock + 5 us reset
    cr = cocotb.start_soon(clock_n_reset(dut.clk, dut.rst_n, f=100e6, t=5))       
    await RisingEdge(dut.rst_n)

    # wait n=16 periods of baud clock (UART needs that)
    await Timer(17 * 8680, 'ns')
    
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
    await u.wr32(0x00, 0x00000008)   # 0x0 *4  T_LATENCY_ACCESS
    await u.wr32(0x04, 0x00000001)   # 0x1 *4  EN_LATENCY_ADDITIONAL
    #await u.wr32(0x10, 0x00000006)   # 0x4 *4  T_RX_CLK_DELAY
    #await u.wr32(0x14, 0x00000000)   # 0x5 *4  T_TX_CLK_DELAY
    # --- CRANGE ---
    await u.wr32(0x2c, 0x00000000)   # 0xB *4  CRANGE0_START
    await u.wr32(0x30, 0x00FFFFFF)   # 0xC *4  CRANGE0_END
    #await u.wr32(0x34, 0x01000000)   # 0xD *4  CRANGE1_START
    #await u.wr32(0x38, 0x01FFFFFF)   # 0xE *4  CRANGE1_END

    # --- REGISTER SPACE ---
    await u.wr32(0x1C, 0x00000001)   # 0x7 *4  ADDRESS_SPACE = 1

    #data = await x.axi_master.read(0x00000000, length=1, size=1 , prot=0)
    r = cocotb.start_soon(x.axi_master.read(0x00000000, length=1, size=1 , prot=0))
    t = Timer(25, 'us')
    res = await First(t, r)
    if res is t:
        raise TimeoutError("AXI read timeout")
    data = r.result()





    # --- READ MR0 ---
    #mr0_chip0 = await axi_read(dut, 0x00000000)
    #mr0_chip1 = await axi_read(dut, 0x01000000)

    #print("MR0 CHIP0 =", hex(mr0_chip0))
    #print("MR0 CHIP1 =", hex(mr0_chip1))

    # --- BACK TO MEMORY ---
    #await apb_write(dut, 0x0000001C, 0x00000000)


    #await apb_write(dut, 0x00, 0x00000000)   # CRANGE0_START
    #await apb_write(dut, 0x04, 0x00FFFFFF)   # CRANGE0_END

    #await apb_write(dut, 0x38, 0x6)          # T_LATENCY_ACCESS = 6
    #await apb_write(dut, 0x34, 0x0)          # EN_LATENCY_ADDITIONAL = 0

    #await apb_write(dut, 0x24, 0x0)          # T_TX_CLK_DELAY
    #await apb_write(dut, 0x28, 0x6)          # T_RX_CLK_DELAY (start)

    #await apb_write(dut, 0x2C, 0x8)          # T_RW_RECOVERY
    #await apb_write(dut, 0x30, 0x10)         # T_BURST_MAX

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
