`ifndef UART_CONFIG_VH
`define UART_CONFIG_VH

`ifndef CLK_FREQ
`define CLK_FREQ 200_000_000
`endif

`define BAUD_RATE 115200

`ifndef UART_DIVISOR
// 1736 or 868
`define UART_DIVISOR (`CLK_FREQ / `BAUD_RATE)
`endif

`endif
