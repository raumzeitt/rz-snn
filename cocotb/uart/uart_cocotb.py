"""Cocotb UART transport for the shared register/AXI access protocol."""

import logging
import os
import cocotb
from cocotb.triggers import with_timeout
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
        uart_level = logging.DEBUG if log_level == "DEBUG" else logging.WARNING
        self.uart_source.log.setLevel(uart_level)
        self.uart_sink.log.setLevel(uart_level)

    async def uart_write(self, address, data):
        self.log.debug(f"UART WRITE: ADDRESS=0x{address:02x} DATA={data.hex()}")
        await self.uart_source.write(bytearray([((len(data)-1) << 4) | 0x1, address]) + data)
        await self.uart_source.wait()

    async def uart_read(self, address, length=1):
        t = cocotb.start_soon(self.uart_source.write(bytearray([((length-1) << 4) | 0x2, address])))
        data = bytearray()
        while len(data) < length:
            r = await with_timeout(self.uart_sink.read(), self.timeout_us, "us")
            data.extend(r)
        self.log.debug(f"UART READ:  ADDRESS=0x{address:02x} DATA={data.hex()}")
        return data
