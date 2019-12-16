`timescale 1ns / 1ps

module unittest_tx_manager();

bit clk_125M = 0;
bit rst_n = 0;
bit [47:0] input_dst_mac;
bit [2:0] input_vlan_id;
bit input_is_ip;
bit input_ip_checksum_ff;
bit input_bad = 0;
bit start = 0;
wire [8:0] fifo_data;
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
    start = 1;

    #8;
    start = 0;

    #320;

    // ARP
    input_dst_mac = 48'hdd_dd_dd_dd_dd_dd;
    input_vlan_id = 1;
    input_is_ip = 0;
    input_ip_checksum_ff = 0;
    start = 1;
    
    #8;
    start = 0;
end

bit [8:0] test_data [0:71] = '{
    9'h080, 9'h000, 9'h000, 9'h002, 9'h008, 9'h000, 9'h045, 9'h000,
    9'h000, 9'h02c, 9'h0ab, 9'h0cd, 9'h000, 9'h000, 9'h03f, 9'h001,
    9'h0ff, 9'h0ff, 9'h00a, 9'h004, 9'h002, 9'h0a0, 9'h008, 9'h008,
    9'h008, 9'h008, 9'h000, 9'h000, 9'h000, 9'h000, 9'h000, 9'h000,
    9'h000, 9'h000, 9'h000, 9'h000, 9'h000, 9'h000, 9'h000, 9'h000,
    9'h000, 9'h000, 9'h000, 9'h000, 9'h000, 9'h000, 9'h000, 9'h100,

    9'h000, 9'h001, 9'h002, 9'h003, 9'h004, 9'h005, 9'h006, 9'h007,
    9'h008, 9'h009, 9'h00a, 9'h00b, 9'h00c, 9'h00d, 9'h00e, 9'h00f,
    9'h010, 9'h011, 9'h012, 9'h013, 9'h014, 9'h015, 9'h016, 9'h117
};
int data_count = 0;

assign fifo_data = test_data[data_count];

always_ff @ (posedge clk_125M) begin
    if (fifo_rd_en) begin
        data_count <= data_count + 1;
    end
end

endmodule