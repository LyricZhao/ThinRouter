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

/* Memory control logic */
logic [`INDEX_WIDTH-1:0] index, child_index, num_nodes;

logic trie_en_write;
logic [`TRIE_ENTRY_WIDTH-1:0] trie_write_data, trie_entry_data;

xpm_memory_spram #(
    // .MEMORY_PRIMITIVE("auto"),
    .ADDR_WIDTH_A(`NODE_INDEX_WIDTH),
    .WRITE_DATA_WIDTH_A(`NODE_ENTRY_WIDTH), // Controlled by one enwrite
    .BYTE_WRITE_WIDTH_A(`NODE_ENTRY_WIDTH),
    .READ_DATA_WIDTH_A(`NODE_ENTRY_WIDTH),
    .READ_LATENCY_A(0),
    .MEMORY_SIZE(`NUM_NODES * `TRIE_ENTRY_WIDTH)
) trie_memory (
    .addra(child_mem_index),
    .wea(trie_en_write),
    .dina(trie_write_data),
    .douta(trie_entry_data),
    .clka(clk),
    .rsta(rst),
    .ena(1'b1)
);

logic [`INFO_ENTRY_BYTES-1:0] info_en_write;
logic [`INFO_ENTRY_WIDTH-1:0] info_write_data, info_entry_data;

xpm_memory_spram #(
    // .MEMORY_PRIMITIVE("auto"),
    .ADDR_WIDTH_A(`INFO_INDEX_WIDTH),
    .WRITE_DATA_WIDTH_A(`INFO_ENTRY_WIDTH), // Controlled by one enwrite
    .BYTE_WRITE_WIDTH_A(`INFO_ENTRY_WIDTH),
    .READ_DATA_WIDTH_A(`INFO_ENTRY_WIDTH),
    .READ_LATENCY_A(0),
    .MEMORY_SIZE(`NUM_NODES * `INFO_ENTRY_WIDTH)
) info_memory (
    .addra(index),
    .wea(info_en_write),
    .dina(info_write_data),
    .douta(info_entry_data),
    .clka(clk),
    .rsta(rst),
    .ena(1'b1)
);

/* States */
logic [2:0] state;
enum logic [2:0] {READY, LOOKUP} StateType;

/* Variables */
logic [`IPV4_WIDTH-1:0] addr_saved;
logic [`MASK_WIDTH-1:0] shift;

/* Assign */
wire [`BITS_PER_STEP-1:0] current_bits;
wire [`IPV4_WIDTH-1:0] node_nexthop;
wire [`NODE_INDEX_WIDTH-1:0] child_mem_index;
wire [`TRIE_INDEX_WIDTH-1:0] child_index;
wire [`TRIE_COVER_WIDTH-1:0] child_cover;

assign current_bits = addr_saved[`IPV4_WIDTH-1:`IPV4_WIDTH-`BITS_PER_STEP];
assign node_nexthop = info_entry_data[`IPV4_WIDTH-1:0];
assign child_mem_index = index * `TRIE_ENTRY_WIDTH + `TRIE_SINGLE_ENTRY_WIDTH * current_bits;
assign child_index = trie_entry_data[`NODE_ENTRY_WIDTH-1:`NODE_ENTRY_WIDTH-TRIE_INDEX_WIDTH];
assign child_cover = trie_entry_data[`TRIE_COVER_WIDTH-1:0];

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
        trie_en_write <= 0;
        info_en_write <= 0;
    end else begin
        case (state)
            READY: begin
                if (insert_valid) begin
                    /* New insertion */
                    lookup_insert_ready <= 0;
                end else if (lookup_valid) begin
                    /* New lookup */
                    addr_saved <= lookup_insert_addr;
                    lookup_insert_ready <= 0;
                    lookup_output_nexthop <= 0;
                    shift <= `MAX_STEPS;
                    state <= LOOKUP;
                end
                index <= 0;
                insert_output_valid <= 0;
                insert_output_error <= 0;
                lookup_output_valid <= 0;
            end

            LOOKUP: begin
                lookup_output_nexthop <= node_nexthop;
                if (shift == 0 || (shift == 0 && shift != `MAX_STEPS)) begin
                    state <= READY;
                    lookup_output_valid <= 1;
                    lookup_insert_ready <= 1;
                end else begin
                    index <= child_index;
                    shift <= shift - 1;
                    addr_saved <= addr_saved << BITS_PER_STEP;
                end
            end

            default: begin
            end
        endcase
    end
end

endmodule