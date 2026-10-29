"""HyperBus delay calibration.

- Supply a cocotb or PC UART transactor and the expected 32-bit ID.
- Call calibrate(tx_is_divider=True) after startup with other masters stopped.
- Divider mode: sweep RX only; TX phase stays fixed.
- Other mode: try TX settings until an RX window passes, then sweep TX.
- Sweep taps 0..31; program the longest consecutive passing window's midpoint.
- RX checks ID0 eight times; TX writes and reads eight scratch-memory words.
- Finish with ID and memory assertions; return rx_tap and tx_tap (None for fixed TX).
- Leave selected taps programmed and memory space selected; scratch data is lost.
- Access errors stop calibration; caller resets. No recovery or saved context.
"""

import logging

# UART register addresses
RX_DELAY = 0x10
TX_DELAY = 0x14
ADDRESS_SPACE = 0x1C

# HyperRAM addresses
ID_ADDRESS = 0x00000000
SCRATCH_ADDRESS = 0x00000000

MEM_PATTERN = [0x00000000, 0xFFFFFFFF, 0xAAAAAAAA, 0x55555555]
MEM_PATTERN += MEM_PATTERN[::-1]


class HyperBusCalibration:
    def __init__(self, uart, expected_id):
        """Set the UART transport, expected ID, and ID read count."""
        self.uart = uart
        self.log = logging.getLogger("HyperBus calibration")


        # id pattern
        self.expected_id = expected_id
        self.repeats = len(MEM_PATTERN) # num of correct ID reads

    async def _check(self, chk):
        """Check the ID or memory pattern depending on the register."""
        self.log.debug(f"Calibration check: {chk}")
        try:
            if chk == 'id':
                return await self._check_id()
            if chk == 'mem':
                return await self._check_memory()
        except TimeoutError:
            self.log.error(f"Calibration timeout: check={chk}")
            raise

    async def _check_id(self):
        """Repeated ID reads must match the expected ID"""
        await self.uart.wr32(ADDRESS_SPACE, 1)
        for _ in range(self.repeats):
            data = await self.uart.axi_read(ID_ADDRESS)
            if data != self.expected_id.to_bytes(4, "little"):
                return False
        return True

    async def _check_memory(self):
        """Write and read back pattern from scratch memory"""
        await self.uart.wr32(ADDRESS_SPACE, 0)
        for i, word in enumerate(MEM_PATTERN): # Write all words before readback
            await self.uart.axi_write(SCRATCH_ADDRESS + 4*i, word)
        for i, word in enumerate(MEM_PATTERN):
            data = await self.uart.axi_read(SCRATCH_ADDRESS + 4*i)
            if data != word.to_bytes(4, "little"):
                return False
        return True

    async def _sweep(self, register):
        """Select the midpoint of the longest passing window, or return None."""
        window = []
        for tap in range(32):
            await self.uart.wr32(register, tap)
            if await self._check('id' if register == RX_DELAY else 'mem'):
                window.append(tap)
        if not window:
            return None
        
        longest, current = [], []
        for tap in window: # Split passing taps into consecutive windows
            if current and tap != current[-1] + 1:
                current = []
            current.append(tap)
            if len(current) > len(longest):
                longest = current.copy()
        tap = (longest[0] + longest[-1]) // 2
        await self.uart.wr32(register, tap)
        return tap

    async def calibrate(self, tx_is_divider=True):
        """Calibrate RX and optionally TX, verify memory, and return the results."""
        self.log.info(f"Starting calibration: tx_is_divider={tx_is_divider}")
        tx_tap = None # Divider supplies TX phase
        if tx_is_divider:
            rx_tap = await self._sweep(RX_DELAY)
        else:
            for tx_tap in range(32): # Find a TX setting with a usable RX window
                await self.uart.wr32(TX_DELAY, tx_tap)
                rx_tap = await self._sweep(RX_DELAY)
                if rx_tap is not None:
                    break
        assert rx_tap is not None, "No passing RX window"
        if not tx_is_divider:
            tx_tap = await self._sweep(TX_DELAY)
            assert tx_tap is not None, "No passing TX window"
        assert await self._check('id'), "Final ID check failed"
        assert await self._check('mem'), "Final memory check failed"
        self.log.info(f"Calibration passed: RX={rx_tap} TX={tx_tap}")
        return {"rx_tap": rx_tap, "tx_tap": tx_tap}
