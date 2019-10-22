`define DISPLAY_IP(x) $display("%0d.%0d.%0d.%0d", x[31:24], x[23:16], x[15:8], x[7:0])
`define DISPLAY_MAC(x) $display("%x:%x:%x:%x:%x:%x", x[47:40], x[39:32], x[31:24], x[23:16], x[15:8], x[7:0])
`define DISPLAY_DATA(data, length) \
    for(int _i = 0; _i < length; _i++) \
        $write("%x ", data[_i]); \
    $display("")