`timescale 1ns / 1ps

`include "constants.vh"

module routing_table_trie(
    input wire clk,
    input wire rst,

    input wire [`IPV4_WIDTH-1:0] lookup_insert_addr,
    input wire lookup_valid,

    input wire insert_valid,
    input wire [`IPV4_WIDTH-1:0] insert_nexthop,
    input wire [`MASK_WIDTH-1:0] insert_mask_len,
    
    output logic lookup_insert_ready,
    output logic insert_output_valid,
    output logic insert_output_error,
    output logic lookup_output_valid,
    output logic [`IPV4_WIDTH-1:0] lookup_output_nexthop
);

/* States */
logic [2:0] state;
enum logic [2:0] {READY, LOOKUP, INSERT} StateType;

/* Variables */
logic [`NODE_INDEX_WIDTH-1:0] index, num_nodes;
logic [`IPV4_WIDTH-1:0] addr_saved, nexthop_saved;
logic [`MASK_WIDTH-1:0] shift;
logic [`LOG_BITS_PER_STEP-1:0] bits_left;

/* Memory control */
logic en_write;
logic [`BLCK_ENTRY_WIDTH-1:0] write_data, entry_data;

/* Assign */
wire [`BITS_PER_STEP-1:0] current_bits;
wire [`BLCK_INDEX_WIDTH-1:0] entry_index;
wire [`BLCK_COVER_WIDTH-1:0] entry_cover;
wire [`IPV4_WIDTH-1:0] entry_index_nexthop;
wire entry_state;

assign current_bits = addr_saved[`IPV4_WIDTH-1:`IPV4_WIDTH-`BITS_PER_STEP];
assign entry_index = index * `NODE_ENTRY_WIDTH + `BLCK_ENTRY_WIDTH * current_bits;
assign entry_cover = entry_data[`BLCK_ENTRY_WIDTH-1:`BLCK_ENTRY_WIDTH-`BLCK_COVER_WIDTH];
assign entry_index_nexthop = entry_data[`IPV4_WIDTH-1:0];
assign entry_state = entry_data[`IPV4_WIDTH];

/* XPM Ram */
xpm_memory_spram #(
    // .MEMORY_PRIMITIVE("auto"),
    .ADDR_WIDTH_A(`BLCK_INDEX_WIDTH),
    .WRITE_DATA_WIDTH_A(`BLCK_ENTRY_WIDTH), // Controlled by one enwrite
    .BYTE_WRITE_WIDTH_A(`BLCK_ENTRY_WIDTH),
    .READ_DATA_WIDTH_A(`BLCK_ENTRY_WIDTH),
    .READ_LATENCY_A(0),
    .MEMORY_SIZE(`NUM_NODES * `NODE_ENTRY_WIDTH)
) trie_memory (
    .addra(entry_index),
    .wea(en_write),
    .dina(write_data),
    .douta(entry_data),
    .clka(clk),
    .rsta(rst),
    .ena(1'b1)
);

always_ff @(posedge clk) begin
    if (rst) begin
        /* Ports */
        lookup_insert_ready <= 1;
        insert_output_valid <= 0;
        insert_output_error <= 0;
        lookup_output_valid <= 0;
        lookup_output_nexthop <= 0;

        /* State */
        state <= READY;

        /* Control */
        index <= 0;
        num_nodes <= 0;
        en_write <= 0;
    end else begin
        case (state)
            READY: begin
                if (insert_valid) begin
                    /* New insertion, TODO */
                    lookup_insert_ready <= 0;
                    addr_saved <= lookup_insert_addr;
                    nexthop_saved <= insert_nexthop;
                    shift <= (insert_mask_len + `BITS_PER_STEP - 1) >> `LOG_BITS_PER_STEP;
                    bits_left <= `BITS_PER_STEP - (insert_mask_len & (`BITS_PER_STEP - 1));
                    state <= INSERT;
                end else if (lookup_valid) begin
                    /* New lookup */
                    addr_saved <= lookup_insert_addr;
                    lookup_insert_ready <= 0;
                    lookup_output_nexthop <= 0;
                    state <= LOOKUP;
                end
                index <= 0;
                insert_output_valid <= 0;
                insert_output_error <= 0;
                lookup_output_valid <= 0;
            end

            LOOKUP: begin
                if (entry_state) begin
                    lookup_output_nexthop <= entry_index_nexthop;
                    state <= READY;
                    lookup_output_valid <= 1;
                    lookup_insert_ready <= 1;
                end else begin
                    index <= entry_index_nexthop;
                    addr_saved <= addr_saved << BITS_PER_STEP;
                end
            end

            INSERT: begin

            end

            default: begin
            end
        endcase
    end
end

endmodule