`timescale 1ns / 1ps

`include "constants.vh"

module testbench_routing_table();

logic clk, rst;

logic [`IPV4_WIDTH-1:0] lookup_insert_addr;
logic lookup_valid;

logic insert_valid;
logic [`IPV4_WIDTH-1:0] insert_nexthop;
logic [`MASK_WIDTH-1:0] insert_mask_len;

wire lookup_insert_ready;
wire insert_output_valid;
wire insert_output_error;
wire lookup_output_valid;
wire [`IPV4_WIDTH-1:0] lookup_nexthop;

initial begin
    clk = 0;
    rst = 1;
    lookup_valid = 0;
    insert_valid = 0;
    lookup_insert_addr = 0;
    insert_nexthop = 0;
    insert_mask_len = 0;
    #100
    rst = 0;

    /* Insert 10.0.0.1/16, n=1.1.1.1 */
    repeat (2) @ (posedge clk);
    insert_valid <= 1;
    lookup_insert_addr <= 32'h0a000001;
    insert_nexthop <= 32'h01010101;
    insert_mask_len <= 16;
    repeat (1) @ (posedge clk);
    insert_valid <= 0;
    repeat (70) @ (posedge clk);

    /* Insert 10.0.0.1/32, n=2.2.2.2 */
    repeat (2) @ (posedge clk);
    insert_valid <= 1;
    lookup_insert_addr <= 32'h0a000001;
    insert_nexthop <= 32'h02020202;
    insert_mask_len <= 32;
    repeat (1) @ (posedge clk);
    insert_valid <= 0;
    repeat (70) @ (posedge clk);

    /* Lookup 10.0.1.1 */
    repeat (2) @ (posedge clk);
    lookup_valid <= 1;
    lookup_insert_addr <= 32'h0a000101;
    repeat (1) @ (posedge clk);
    lookup_valid <= 0;
    repeat (40) @ (posedge clk);

    /* Lookup 10.0.0.1 */
    repeat (2) @ (posedge clk);
    lookup_valid <= 1;
    lookup_insert_addr <= 32'h0a000001;
    repeat (1) @ (posedge clk);
    lookup_valid <= 0;
    repeat (40) @ (posedge clk);

    /* Lookup 17.2.1.1 */
    repeat (2) @ (posedge clk);
    lookup_valid <= 1;
    lookup_insert_addr <= 32'h11020101;
    repeat (1) @ (posedge clk);
    lookup_valid <= 0;
    repeat (40) @ (posedge clk);

end

always clk = #10 ~clk;

routing_table_trie routing_table_inst(
    .clk(clk),
    .rst(rst),

    .lookup_insert_addr(lookup_insert_addr),
    .lookup_valid(lookup_valid),

    .insert_valid(insert_valid),
    .insert_nexthop(insert_nexthop),
    .insert_mask_len(insert_mask_len),

    .lookup_insert_ready(lookup_insert_ready),
    .insert_output_valid(insert_output_valid),
    .insert_output_error(insert_output_error),
    .lookup_output_valid(lookup_output_valid),
    .lookup_nexthop(lookup_nexthop)
);

endmodule