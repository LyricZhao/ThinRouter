`ifndef _DEBUG_VH_
`define _DEBUG_VH_

`define DISPLAY_IP(x) $display("%0d.%0d.%0d.%0d", x[31:24], x[23:16], x[15:8], x[7:0])
`define DISPLAY_MAC(x) $display("%x:%x:%x:%x:%x:%x", x[47:40], x[39:32], x[31:24], x[23:16], x[15:8], x[7:0])
`define DISPLAY_DATA(data, length) \
    for (int _i = 0; _i < length; _i++) \
        $write("%x ", data[_i]); \
    $display("")
`define DISPLAY_BITS(data, hi, lo) \
    for (int _i = hi; _i > lo; _i = _i - 8) \
        $write("%x ", data[_i -: 8]); \
    $display("")
`define WRITE_BITS(data, hi, lo) \
    for (int _i = hi; _i > lo; _i = _i - 8) \
        $write("%x ", data[_i -: 8]);

`endif