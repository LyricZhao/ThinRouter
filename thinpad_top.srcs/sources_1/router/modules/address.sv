/*
获取路由器内置地址的模块
*/
`timescale 1ns / 1ps

package Address;

    typedef enum logic [31:0] {
        RouterIP1 = 32'hc0_a8_00_01,
        RouterIP2 = 32'hc0_a8_01_01,
        RouterIP3 = 32'hc0_a8_02_01,
        RouterIP4 = 32'hc0_a8_03_01,
        McastIP = 32'he0_00_00_09
    } _ip_constants;

    typedef enum logic [47:0] {
        RouterMAC1 = 48'ha8_88_08_18_88_88,
        RouterMAC2 = 48'ha8_88_08_28_88_88,
        RouterMAC3 = 48'ha8_88_08_38_88_88,
        RouterMAC4 = 48'ha8_88_08_48_88_88,
        McastMAC = 48'h01_00_5e_00_00_09,
        BcastMAC = 48'hff_ff_ff_ff_ff_ff
    } _mac_constants;

    function logic [2:0] port;
        input logic [31:0] ip;
    begin
        case (ip[31:8])
            RouterIP1[31:8]: port = 1;
            RouterIP2[31:8]: port = 2;
            RouterIP3[31:8]: port = 3;
            RouterIP4[31:8]: port = 4;
            default: port = 0;
        endcase
    end
    endfunction

    function logic match;
        input logic [31:0] ip;
        input logic [2:0]  vlan;
    begin
        match = (vlan == port(ip));
    end
    endfunction

    function logic [31:0] ip;
        input logic [2:0] port;
    begin
        case (port)
            1: ip = RouterIP1;
            2: ip = RouterIP2;
            3: ip = RouterIP3;
            4: ip = RouterIP4;
            default: ip = 'x;
        endcase
    end
    endfunction

    function logic [47:0] mac;
        input logic [2:0] port;
    begin
        case (port)
            1: mac = RouterMAC1;
            2: mac = RouterMAC2;
            3: mac = RouterMAC3;
            4: mac = RouterMAC4;
            default: mac = 'x;
        endcase
    end
    endfunction
    
endpackage