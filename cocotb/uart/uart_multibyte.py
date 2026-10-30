"""UART bursts with APB wait states and address wrap; run with UART_DIVISOR=4."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, Timer
from uart_cocotb import UartTransactor


@cocotb.test()
async def multibyte(dut):
    memory = bytearray(256)
    transfers = []

    async def apb():
        request = None
        delay = 0
        while True:
            await FallingEdge(dut.clk)
            dut.PREADY.value = 0
            if not dut.PSEL.value:
                assert not dut.PENABLE.value
            elif not dut.PENABLE.value:
                request = (int(dut.PWRITE.value), int(dut.PADDR.value), int(dut.PWDATA.value))
                delay = (0, 1, 4, 12)[len(transfers) % 4]
            else:
                assert (int(dut.PWRITE.value), int(dut.PADDR.value), int(dut.PWDATA.value)) == request
                if delay:
                    delay -= 1
                else:
                    write, address, data = request
                    if write:
                        memory[address] = data
                    dut.PRDATA.value = memory[address]
                    dut.PREADY.value = 1
                    transfers.append(request)

    dut.rst_n.value = 0
    dut.uart_rx.value = 1
    dut.PRDATA.value = 0
    dut.PREADY.value = 0
    cocotb.start_soon(Clock(dut.clk, 5, units="ns").start())
    cocotb.start_soon(apb())
    await Timer(100, "ns")
    dut.rst_n.value = 1
    u = UartTransactor(dut, baud=50_000_000)
    await Timer(2, "us")
    for length in range(1, 17):
        address = 0xFC
        data = bytes((length * 17 + i * 29) & 255 for i in range(length))
        start = len(transfers)
        await u.uart_write(address, data)
        result = await u.uart_read(address, length)
        assert result == data
        actual = transfers[start:]
        assert len(actual) == 2 * length
        assert [x[1] for x in actual] == [(address+i) & 255 for i in range(length)] * 2
        assert [x[0] for x in actual] == [1] * length + [0] * length
    await u.wr32(0x90, 0x89ABCDEF)
    assert await u.rd32(0x90) == 0x89ABCDEF
    assert memory[0x90:0x94] == bytes.fromhex("efcdab89")
    await u.uart_write(0x40, bytearray([0xA5]))
    assert await u.uart_read(0x40) == bytes([0xA5])
