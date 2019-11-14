`timescale 1ns / 1ps

module unittest_tx_manager();

bit clk_125M = 0;
bit rst_n = 0;
bit [47:0] input_dst_mac;
bit [2:0] input_vlan_id;
bit input_is_ip;
bit input_ip_checksum_ff;
bit [15:0] input_packet_size;
bit start = 0;
bit [7:0] fifo_data = 0;
wire fifo_rd_en;
bit abort = 0;
wire [7:0] tx_data;
wire tx_valid;
wire tx_last;
wire tx_ready;

tx_manager inst (.*);

always clk_125M = #4 !clk_125M;

initial begin
    #1000;
    rst_n = 1;
    #100;

    // ARP
    input_dst_mac = 48'hdd_dd_dd_dd_dd_dd;
    input_vlan_id = 1;
    input_is_ip = 0;
    input_ip_checksum_ff = 0;
    input_packet_size = 46;
    start = 1;

    #8;
    start = 0;

    #1000;
    
    // IP
    input_dst_mac = 48'hdd_dd_dd_dd_dd_dd;
    input_vlan_id = 2;
    input_is_ip = 1;
    input_ip_checksum_ff = 0;
    input_packet_size = 60;
    start = 1;

    #8;
    start = 0;
end

always_ff @ (posedge clk_125M) begin
    if (fifo_rd_en) begin
        fifo_data <= fifo_data + 1;
    end
end

endmodule