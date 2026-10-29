"""PC UART transport. Install cocotb/requirements.txt; use from an asyncio loop.

Example:
    bus = PcUartTransactor("/dev/ttyUSB0", baud=115200)
    try:
        value = await bus.rd32(0x10)
    finally:
        await bus.close()

Use the hardware UART baud, not the simulation speedup baud.
"""

import asyncio
from uart_access import UartAccess


class PcUartTransactor(UartAccess):
    def __init__(self, port, baud=115200, timeout=1.0):
        import serial
        self.serial = serial.Serial(port, baudrate=baud, timeout=timeout,
                                    write_timeout=timeout)

    async def _io(self, operation):
        # Finish any bounded serial operation before recovery can reuse the port.
        task = asyncio.create_task(asyncio.to_thread(operation))
        try:
            return await asyncio.shield(task)
        except asyncio.CancelledError:
            try:
                await asyncio.shield(task)
            except Exception:
                pass
            raise

    def _send(self, packet):
        if self.serial.write(packet) != len(packet):
            raise TimeoutError("Incomplete UART write")
        self.serial.flush()

    async def uart_write(self, address, data):
        await self._io(lambda: self._send(bytes([0x01, address, data])))

    async def uart_read(self, address):
        def read():
            self._send(bytes([0x02, address]))
            data = self.serial.read(1)
            if len(data) != 1:
                raise TimeoutError("UART read timeout")
            return data[0]
        return await self._io(read)

    async def clear(self):
        """Flush host buffers after external hardware recovery; does not reset RTL."""
        def clear():
            self.serial.reset_input_buffer()
            self.serial.reset_output_buffer()
        await self._io(clear)

    async def close(self):
        await self._io(self.serial.close)
