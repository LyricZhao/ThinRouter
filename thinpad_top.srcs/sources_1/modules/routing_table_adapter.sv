/*
目前的路由表无法在 125M 时钟工作，因此加入一个中间层
*/

`timescale 1ns / 1ps
`default_nettype none
`include "debug.vh"

module routing_table_adapter(
    input   wire    clk,
    input   wire    rst,

    input   wire    lookup_valid,
    input   wire    insert_valid,
    input   wire    [31:0] lookup_insert_addr,
    input   wire    [31:0] insert_nexthop,
    input   wire    [7:0]  insert_mask_len,

    output  reg     lookup_insert_ready,
    output  wire    lookup_output_valid,
    output  wire    [31:0] lookup_output_nexthop
);

assign lookup_output_valid = lookup_insert_ready;

enum reg [2:0] {
    Idle,
    PrepareLookup,
    PrepareInsert,
    Lookup,
    Insert,
    Done
} state;
reg  preparing;

reg  lookup;
reg  insert;
wire table_ready;
routing_table routing_table_inst (
    .clk,
    .rst(rst),

    .lookup_valid(lookup),
    .insert_valid(insert),

    .lookup_insert_addr,
    .insert_nexthop,
    .insert_mask_len,

    .lookup_insert_ready(table_ready),
    .lookup_output_nexthop
);

/*
时序：
对于 lookup insert 信号异步进入 Prepare 状态
Prepare 状态需要等一拍之后再置 valid 信号给路由表模块
路由表模块在下沿返回处理完成后，上沿时置 lookup_insert_ready
*/
always_ff @(posedge clk or posedge lookup_valid or posedge insert_valid) begin
    if (rst) begin
        state <= Idle;
        preparing <= 0;
        lookup <= 0;
        insert <= 0;
        lookup_insert_ready <= 1;
    end else begin
        case (state)
            Idle: begin
                lookup <= 0;
                insert <= 0;
                if (lookup_valid) begin
                    lookup_insert_ready <= 0;
                    preparing <= 1;
                    state <= PrepareLookup;
                end else if (insert_valid) begin
                    lookup_insert_ready <= 0;
                    preparing <= 1;
                    state <= PrepareInsert;
                end else begin
                    lookup_insert_ready <= 1;
                    preparing <= 0;
                    state <= Idle;
                end
            end
            PrepareLookup: begin
                if (preparing == 0) begin
                    lookup <= 1;
                    state <= Lookup;
                end else begin
                    state <= PrepareLookup;
                end
                lookup_insert_ready <= 0;
                insert <= 0;
                preparing <= 0;
            end
            PrepareInsert: begin
                if (preparing == 0) begin
                    insert <= 1;
                    state <= Insert;
                end else begin
                    state <= PrepareInsert;
                end
                lookup_insert_ready <= 0;
                lookup <= 0;
                preparing <= 0;
            end
            Lookup: begin
                lookup_insert_ready <= table_ready;
                insert <= 0;
                lookup <= 0;
                preparing <= 0;
                state <= table_ready ? Idle : Lookup;
            end
            Insert: begin
                lookup_insert_ready <= table_ready;
                insert <= 0;
                lookup <= 0;
                preparing <= 0;
                state <= table_ready ? Idle : Insert;
            end
            default: begin
                state <= Idle;
                preparing <= 0;
                lookup <= 0;
                insert <= 0;
                lookup_insert_ready <= 1;
            end
        endcase
    end
end

endmodule