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
    output logic lookup_output_valid,
    output logic [`IPV4_WIDTH-1:0] lookup_output_nexthop
);

/* States */
logic [2:0] state;
enum logic [2:0] {READY, LOOKUP, INSERT, NEW, EXPAND} StateType;

/* Variables */
logic [`NODE_INDEX_WIDTH-1:0] index, num_nodes;
logic [`IPV4_WIDTH-1:0] addr_saved, nexthop_saved;
logic [`MASK_WIDTH-1:0] shift;
logic [`LOG_BITS_PER_STEP-1:0] bits_left;
logic [`BITS_PER_STEP-1:0] bits_start, bits_end;
logic [`BITS_PER_STEP] expand_counter;

/* Memory control */
logic en_write;
logic [`BLCK_ENTRY_WIDTH-1:0] write_data, entry_data;

/* Assign */
wire [`BITS_PER_STEP-1:0] current_bits, bits_helper;
wire [`BLCK_INDEX_WIDTH-1:0] entry_index;
wire [`IPV4_WIDTH-1:0] entry_nexthop;
wire [`NODE_INDEX_WIDTH-1:0] entry_next_index;
wire entry_state;

assign current_bits = addr_saved[`IPV4_WIDTH-1:`IPV4_WIDTH-`BITS_PER_STEP];
assign bits_helper = (`BITS_PER_STEP'b1 << bits_left) - 1;
assign entry_index = index * `NODE_ENTRY_WIDTH + `BLCK_ENTRY_WIDTH * current_bits;
assign entry_cover = entry_data[`BLCK_ENTRY_WIDTH-1:`BLCK_ENTRY_WIDTH-`BLCK_COVER_WIDTH];
assign entry_nexthop = entry_data[`IPV4_WIDTH+`NODE_INDEX_WIDTH-1:`NODE_INDEX_WIDTH]
assign entry_next_index = entry_data[`NODE_INDEX_WIDTH-1:0];

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
                    lookup_insert_ready <= 0;
                    addr_saved <= lookup_insert_addr;
                    nexthop_saved <= insert_nexthop;
                    shift <= (insert_mask_len + `BITS_PER_STEP - 1) >> `LOG_BITS_PER_STEP;
                    bits_left <= `BITS_PER_STEP - (insert_mask_len & (`BITS_PER_STEP - 1));
                    state <= INSERT;
                end else if (lookup_valid) begin
                    lookup_insert_ready <= 0;
                    lookup_output_nexthop <= 0;
                    addr_saved <= lookup_insert_addr;
                    state <= LOOKUP;
                end
                index <= 0;
                lookup_output_valid <= 0;
            end

            LOOKUP: begin
                lookup_output_nexthop <= entry_nexthop;
                if (!entry_next_index) begin    
                    state <= READY;
                    lookup_output_valid <= 1;
                    lookup_insert_ready <= 1;
                end else begin
                    index <= entry_next_index;
                    addr_saved <= addr_saved << BITS_PER_STEP;
                end
            end
            
            WAIT_I: begin
                en_write <= 0;
                index <= num_nodes + 1;
                num_nodes <= num_nodes + 1;
                shift <= shift - 1;
                addr_saved <= addr_saved << BITS_PER_STEP;
                state <= INSERT;
            end

            WAIT_E: begin
                en_write <= 0;
                expand_counter <= expand_counter + 1;
                addr_saved <= addr_saved + 32'h01000000;
                state <= EXPAND;
            end

            EXPAND: begin
                if (expand_counter > bits_end) begin
                    state <= READY;
                    en_write <= 0;
                    lookup_insert_ready <= 1;
                end else begin
                    if (entry_cover > (~ bits_left)) begin
                        en_write <= 0;
                        expand_counter <= expand_counter + 1;
                        addr_saved <= addr_saved + 32'h01000000;
                    end else begin
                        en_write <= 1;
                        write_data <= {~ bits_left, nexthop_saved, entry_next_index};
                        state <= WAIT_E;
                    end
                end
            end

            INSERT: begin
                if (shift == 0) begin
                    bits_start <= current_bits & (~ bits_helper);
                    bits_end <= current_bits | bits_helper;
                    expand_counter <= bits_start;
                    addr_saved <= {bits_start, 24'b0};
                    state <= EXPAND;
                end else begin
                    if (entry_next_index) begin
                        index <= entry_next_index;
                        shift <= shift - 1;
                        addr_saved <= addr_saved << BITS_PER_STEP;
                    end else begin
                        en_write <= 1;
                        write_data <= {entry_cover, entry_nexthop, num_nodes + 1};
                        state <= WAIT_I;
                    end
                end
            end

            default: begin
                /* Nothing */
            end
        endcase
    end
end

endmodule