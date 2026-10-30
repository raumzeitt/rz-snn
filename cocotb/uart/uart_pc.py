"""PC UART transport. Install cocotb/requirements.txt; use from an asyncio loop.

Example:
    bus = PcUartTransactor("/dev/ttyUSB0", baud=115200)
    try:
        value = await bus.rd32(0x10)
    finally:
        await bus.close()

Use the hardware UART baud, not the simulation speedup baud.
"""

import logging
from uart_access import UartAccess
import serial


class PcUartTransactor(UartAccess):
    def __init__(self, port, baud=115200, timeout=1.0):
        self.log = logging.getLogger("UART")
        # pySerial UART port (e.g. /dev/ttyUSB0 or COM3), often USB-to-UART; defaults to 8N1.
        self.serial = serial.Serial(port, baudrate=baud, timeout=timeout, write_timeout=timeout)

    async def uart_write(self, address, data):
        self.log.debug(f"UART WRITE: ADDRESS=0x{address:02x} DATA={data.hex()}")
        # UART wr packet: command byte, address byte, then write data.
        self.serial.write(bytearray([((len(data)-1) << 4) | 0x01, address]) + data)
        self.serial.flush()  # waits until the outgoing bytes have been transmitted.

    async def uart_read(self, address, length=1):
        # UART rd packet: command byte, address byte
        self.serial.write(bytearray([((length-1) << 4) | 0x02, address]))
        self.serial.flush()  # waits until the outgoing bytes have been transmitted.
        data = bytearray()
        while len(data) < length:
            r = self.serial.read(length - len(data))
            if not r:
                raise TimeoutError("UART read timeout")
            data.extend(r)
        self.log.debug(f"UART READ:  ADDRESS=0x{address:02x} DATA={data.hex()}")
        return data

    async def clear(self):
        """Flush host buffers after external hardware recovery; does not reset RTL."""
        self.serial.reset_input_buffer()
        self.serial.reset_output_buffer()

    async def close(self):
        self.serial.close()
