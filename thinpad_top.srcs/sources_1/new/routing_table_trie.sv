`timescale 1ns / 1ps

`define IPV4_WIDTH 32
`define MASK_WIDTH 8
`define BYTE_WIDTH 8
`define INDEX_WIDTH 16
`define ENTRY_WIDTH 128 // `INDEX_WIDTH*2+IPV4_WIDTH+1 rounded up to 2's pow
`define ENTRY_COUNT 1024

module routing_table_trie(
    input wire clk,
    input wire rst,

    input wire [`IPV4_WIDTH-1:0] lookup_addr,
    input wire lookup_valid,

    input wire [`IPV4_WIDTH-1:0] insert_addr,
    input wire [`MASK_WIDTH-1:0] insert_mask_len,
    input wire insert_valid,

    output logic lookup_insert_ready,
    output logic insert_valid,
    output logic insert_error,
    output logic lookup_valid,
    output logic lookup_not_found,
    output logic [`IPV4_WIDTH-1:0] lookup_nexthop
);

logic proc_state; /* O for insert, 1 for lookup */
logic [`INDEX_WIDTH-1:0] index;
logic [`ENTRY_WIDTH-1:0] entry_data;
logic [`IPV4_WIDTH-1:0] addr_saved;

xpm_memory_spram #(
    .ADDR_WIDTH_A(`INDEX_WIDTH),
    .WRITE_DATA_WIDTH_A(`ENTRY_WIDTH),
    .BYTE_WRITE_WIDTH_A(`BYTE_WIDTH),
    .READ_DATA_WIDTH_A(`ENTRY_WIDTH),
    .READ_LATENCY_A(0),
    .MEMORY_SIZE(`ENTRY_COUNT * `ENTRY_WIDTH),
) xpm_memory_spram_data (
    .dina(0),
    .addra(index),
    .wea(1'b0),
    .douta(entry_data),
    .clka(clk),
    .rsta(rst),
    .ena(1'b1)
);

localparam  NEW_INSERT = 4'b11?0,
            NEW_LOOKUP = 4'b1010,
            PROC_INSERT = 4'b0??0,
            PROC_LOOKUP = 4'b0??1;

always_ff @(posedge clk) begin
    if (rst) begin
        lookup_insert_ready <= 1;
        insert_valid <= 0;
        insert_error <= 0;
        lookup_valid <= 0;
        lookup_not_found <= 0;
        lookup_nexthop <= 0;
        index <= 0;
        proc_state <= 0;
    end else begin
        casez ({lookup_insert_ready, insert_valid, lookup_valid, proc_state})
            NEW_INSERT: begin

            end

            NEW_LOOKUP: begin
            end

            PROC_INSERT: begin
            end

            PROC_LOOKUP: begin
            end

            default: begin
                /* Nothing */
            end
        endcase
    end
end

endmodule