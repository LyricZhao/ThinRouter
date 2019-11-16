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
wire [7:0] fifo_data;
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

    // IP
    input_dst_mac = 48'hdd_dd_dd_dd_dd_dd;
    input_vlan_id = 2;
    input_is_ip = 1;
    input_ip_checksum_ff = 1;
    input_packet_size = 60;
    start = 1;

    #8;
    start = 0;

    #320;

    // ARP
    input_dst_mac = 48'hdd_dd_dd_dd_dd_dd;
    input_vlan_id = 1;
    input_is_ip = 0;
    input_ip_checksum_ff = 0;
    input_packet_size = 46;
    start = 1;
    
    #8;
    start = 0;
end

bit [7:0] test_data [0:71] = '{
    8'h80, 8'h00, 8'h00, 8'h02, 8'h08, 8'h00, 8'h45, 8'h00,
    8'h00, 8'h2c, 8'hab, 8'hcd, 8'h00, 8'h00, 8'h3f, 8'h01,
    8'hff, 8'hff, 8'h0a, 8'h04, 8'h02, 8'ha0, 8'h08, 8'h08,
    8'h08, 8'h08, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,

    8'h00, 8'h01, 8'h02, 8'h03, 8'h04, 8'h05, 8'h06, 8'h07,
    8'h08, 8'h09, 8'h0a, 8'h0b, 8'h0c, 8'h0d, 8'h0e, 8'h0f,
    8'h10, 8'h11, 8'h12, 8'h13, 8'h14, 8'h15, 8'h16, 8'h17
};
int data_count = 0;

assign fifo_data = test_data[data_count];

always_ff @ (posedge clk_125M) begin
    if (fifo_rd_en) begin
        data_count <= data_count + 1;
    end
end

endmodule