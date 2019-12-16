`timescale 1ns / 1ps
module testbench_packer ();

bit      clk_125M = 0;
logic    rst;

logic    valid;
logic    last;
logic    [31:0] prefix;
logic    [5:0]  mask;
logic    [31:0] src_ip;
logic    [31:0] dst_ip;
logic    [31:0] nexthop;
logic    [3:0]  metric;

logic    outer_fifo_read_valid;

logic    outer_fifo_empty;
logic    [7:0]  outer_fifo_out;
logic    [7:0]  outer_fifo_in;
logic    finished; // 打包完成
rip_packer dut (
    .clk(clk_125M),
    .rst(rst),
    .valid(valid),
    .last(last),
    .prefix(prefix),
    .mask(mask),
    .src_ip(src_ip),
    .dst_ip(dst_ip),
    .nexthop(nexthop),
    .metric(metric),
    .outer_fifo_read_valid(outer_fifo_read_valid),
    .outer_fifo_empty(outer_fifo_empty),
    .outer_fifo_out(outer_fifo_out),
    .outer_fifo_in_debug(outer_fifo_in),
    .finished(finished)
);

always #4 clk_125M = ~clk_125M;

initial begin
    src_ip = 32'hc0a80101; // protocal_input1.pcap
    dst_ip = 32'he0000009;
    rst = 1;
    rst = #100 0;

    prefix = 32'hc0a80500;
    mask = 6'b011000;
    nexthop = 0;
    metric = 4'b0001;
    # 120
    valid = 1;
    # 8
    valid = 0;
    # 100
    last = 1;
    # 20
    valid = 0;
    last = 0;

    # 1000
    outer_fifo_read_valid = 1;
    # 1000
    src_ip = 32'hc0a80101; // protocal_input3.pcap
    dst_ip = 32'he0000009;

    prefix = 32'hc0a80500;
    mask = 6'b011000;
    nexthop = 0;
    metric = 4'b0001;
    valid = 1;
    # 8
    //valid = 0;
    //# 8
    prefix = 32'hc0a80600;
    mask = 6'b011000;
    nexthop = 0;
    metric = 4'b0001;
    valid = 1;
   // # 8
    //valid = 0;
    # 8
    prefix = 32'hc0a80700;
    mask = 6'b011000;
    nexthop = 0;
    metric = 4'b0001;
    //valid = 1;
    last = 1;
    # 8
    valid = 0;
    last = 0;
end

endmodule