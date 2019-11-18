`default_nettype none
`timescale 1ns / 1ps
`include "debug.vh"

module testbench_packet_processor();

bit  clk = 1;
bit  rst_n = 0;
bit  reset_process = 0;
bit  add_arp = 0;
bit  add_routing = 0;
bit  process_arp = 0;
bit  process_ip = 0;

bit  [31:0] ip_input;
bit  [7:0]  mask_input;
bit  [31:0] nexthop_input;
bit  [47:0] mac_input;
bit  [2:0]  vlan_input;

wire done;
wire bad;
wire [47:0] mac_output;
wire [2:0]  vlan_output;

packet_processor inst(.*);

// 125M clock
always clk = #4 !clk;

task waitTillComplete; begin
    do @(posedge clk); while (!done);
end endtask

task addArp;
input wire [31:0] ip;
input wire [47:0] mac;
input wire [2:0]  vlan;
begin
    $display("Add ARP entry:");
    $write("\tIP:\t");
    `DISPLAY_IP(ip);
    $write("\tMAC:\t");
    `DISPLAY_MAC(mac);
    $display("\tVLAN:\t%d\n", vlan);
    @(posedge clk);
    add_arp = 1;

    ip_input = ip;
    mac_input = mac;
    vlan_input = vlan;

    @(posedge clk);
    add_arp = 0;
    
    waitTillComplete();
end endtask

task addRouting;
input wire [31:0] ip;
input wire [7:0]  mask;
input wire [31:0] nexthop;
begin
    $display("Add routing entry:");
    $write("\tIP:\t");
    `DISPLAY_IP(ip);
    $write("\tNexthop:\t");
    `DISPLAY_IP(nexthop);
    $display("\tMask:\t%0d\n", mask);
    @(posedge clk);
    add_routing = 1;

    ip_input = ip;
    nexthop_input = nexthop;
    mask_input = mask;

    @(posedge clk);
    add_routing = 0;
    
    waitTillComplete();
end endtask

task queryArp;
input wire [31:0] ip;
begin
    $write("Query ARP:\t");
    `DISPLAY_IP(ip);
    $display("");
    @(posedge clk);
    process_arp = 1;

    ip_input = ip;

    @(posedge clk);
    process_arp = 0;
    
    waitTillComplete();

    if (bad) begin
        $display("ARP not found\n");
    end else begin
        $display("ARP result:");
        $write("\tMAC:\t");
        `DISPLAY_MAC(mac_output);
        $display("\tVLAN:\t%d\n", vlan_output);
    end
end endtask

task queryIp;
input wire [31:0] ip;
begin
    $write("Query IP:\t");
    `DISPLAY_IP(ip);
    $display("");
    @(posedge clk);
    process_ip = 1;

    ip_input = ip;

    @(posedge clk);
    process_ip = 0;
    
    waitTillComplete();

    if (bad) begin
        $display("Routing not found\n");
    end else begin
        $display("Routing result:");
        $write("\tMAC:\t");
        `DISPLAY_MAC(mac_output);
        $display("\tVLAN:\t%d\n", vlan_output);
    end
end endtask

initial begin
    #200;
    rst_n = 1;

    queryArp(32'h0a_04_01_a0);
    addArp(32'h0a_04_01_a0, 48'h11_11_11_11_11_11, 1);
    queryArp(32'h0a_04_01_a0);
    addRouting(32'h08_08_08_08, 24, 32'h0a_04_01_a0);
    queryArp(32'h0a_04_01_a1);
    queryArp(32'h0a_04_01_a0);
    addArp(32'h0a_04_02_a0, 48'h22_22_22_22_22_22, 2);
    addArp(32'h0a_04_03_a0, 48'h33_33_33_33_33_33, 3);
    addArp(32'h0a_04_04_a0, 48'h44_44_44_44_44_44, 4);
    queryArp(32'h0a_04_02_a0);
    queryArp(32'h0a_04_01_a0);
    queryIp(32'h08_08_08_00);
end

endmodule