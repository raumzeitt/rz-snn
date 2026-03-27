import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, Timer,  First, Edge, Combine

from cocotbext.uart import UartSource, UartSink
from cocotbext.apb import ApbBus, ApbRam

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


class ApbRamTransactor:
    def __init__(self, dut):
        self.dut = dut
        # alias signals
        signals = {s: s.upper() for s in ["paddr", "psel", "penable", "pwrite", "pwdata", "pready", "prdata"]}
        apb_bus = ApbBus(
            dut,
            "",   # no prefix
            signals=signals
        )
        apb = ApbRam(
            apb_bus,
            dut.clk,
            dut.rst_n,
            reset_active_level=False,  # if active-low
        )
        apb.log.setLevel(self.dut._log.level)

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


@cocotb.test()
async def uart_test(dut):
    log_level = os.environ.get('LOG_LEVEL', 'INFO') # NOTSET=0 DEBUG=10 INFO=20 WARN=30 ERROR=40 CRITICAL=50
    dut._log.setLevel(log_level)

    # Hack/Fix for missing "negedge reset" in verilator
    dut.rst_n.value = 1
    await Timer(1, 'ps')

    # Transactor
    u = UartTransactor(dut)
    p = ApbRamTransactor(dut)

    # 5 us reset
    cr = cocotb.start_soon(clock_n_reset(dut.clk, dut.rst_n, f=100e6, t=5))       
    await RisingEdge(dut.rst_n)
    # wait n=16 periods of baud clock
    await Timer(17 * 8680, 'ns')
    
    # test Command
    if 1:
        await u.uart_cmd(0x55) # 01010101 LSB first = 0_10101010_1
        await u.uart_cmd(0x00)
        await u.uart_cmd(0x3)
        await Timer(25, 'us')

    # test single byte write followed by byte read
    if 2:
        data = [(0x3, 53), (0, 255), (0x33, 0x44), (0x11, 0xcc), (0xdd, 0xa5)]
        random.shuffle(data)
        for d in data:
            await u.uart_write(d[0], d[1])
        random.shuffle(data)
        for d in data:
            read_bytes = await u.uart_read(d[0])
            assert read_bytes == d[1]
        await Timer(25, 'us')

