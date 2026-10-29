"""Cocotb UART transport for the shared register/AXI access protocol."""

import logging
import os
import cocotb
from cocotb.triggers import First, Timer
from cocotbext.uart import UartSource, UartSink
from uart_access import UartAccess


class UartTransactor(UartAccess):
    def __init__(self, dut, baud, timeout_us=1000):
        self.dut = dut
        self.timeout_us = timeout_us # UART response timeout, including request transmission
        log_level = os.environ["LOG_LEVEL"]
        self.log = logging.getLogger("UART")
        self.log.setLevel(log_level)

        self.uart_source = UartSource(dut.uart_rx, baud=baud, bits=8, stop_bits=1)
        self.uart_sink = UartSink(dut.uart_tx, baud=baud, bits=8, stop_bits=1)

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
        timer = Timer(self.timeout_us, "us")
        completed = await First(r, timer)
        if completed is timer:
            raise TimeoutError("UART read timeout")
        data = r.result()[0]
        self.log.info(f"UART READ:  ADDRESS=0x{address:02x} DATA=0x{data:02x}")
        return data

