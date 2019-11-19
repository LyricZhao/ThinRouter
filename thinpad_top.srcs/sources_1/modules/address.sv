/*
获取路由器内置地址的模块
*/
`timescale 1ns / 1ps
`include "address.vh"

module address (
    input   logic   [2:0]   vlan_id,
    output  logic   [47:0]  mac,
    output  logic   [31:0]  ip
);

always_comb
    case (vlan_id)
        1: {mac, ip} = {`ROUTER_MAC_1, `ROUTER_IP_1};
        2: {mac, ip} = {`ROUTER_MAC_2, `ROUTER_IP_2};
        3: {mac, ip} = {`ROUTER_MAC_3, `ROUTER_IP_3};
        4: {mac, ip} = {`ROUTER_MAC_4, `ROUTER_IP_4};
        default: {mac, ip} = 'x;
    endcase

endmodule