"""Shared UART register/AXI protocol; subclasses supply uart_read/uart_write.

Use one caller at a time: register assembly and AXI commands are not atomic.
"""


AXI_BASE = 0x80 # APB base of the AXI access block
AXI_ADDRESS = 0x00
AXI_DATA = 0x04
AXI_COMMAND = 0x08
AXI_STATUS = 0x09
AXI_POLL_LIMIT = 16 # Maximum status reads before reporting a timeout


class UartAccess:
    async def wr32(self, address, data):
        await self.uart_write(address, data.to_bytes(4, "little"))

    async def rd32(self, address):
        return int.from_bytes(await self.uart_read(address, 4), "little")

    async def axi_write(self, address, data):
        assert address % 4 == 0
        await self.wr32(AXI_BASE + AXI_ADDRESS, address) # AXI byte address
        await self.wr32(AXI_BASE + AXI_DATA, data) # AXI write data
        await self.uart_write(AXI_BASE + AXI_COMMAND, bytearray([0x02])) # Write all four bytes
        for _ in range(AXI_POLL_LIMIT):
            status_reg = await self.uart_read(AXI_BASE + AXI_STATUS)
            if not status_reg[0] & 1:  # check busy bit 0
                assert not status_reg[0] & 2, "AXI write error" # check error bit 1
                return
        raise TimeoutError("AXI write timeout")

    async def axi_read(self, address, length=4):
        assert address % 4 == 0 and length % 4 == 0
        data = bytearray()
        for offset in range(0, length, 4):
            await self.wr32(AXI_BASE + AXI_ADDRESS, address + offset) # AXI byte address
            await self.uart_write(AXI_BASE + AXI_COMMAND, bytearray([1])) # Start single-word read
            for _ in range(AXI_POLL_LIMIT):
                status_reg = await self.uart_read(AXI_BASE + AXI_STATUS)
                if not status_reg[0] & 1:   # check busy bit 0
                    break
            if status_reg[0] & 1:  # check busy bit 0
                raise TimeoutError("AXI read timeout")  # timout if still busy
            assert not status_reg[0] & 2, "AXI read error"  # check error bit 1
            data.extend(await self.uart_read(AXI_BASE + AXI_DATA, 4))
        return bytes(data)

