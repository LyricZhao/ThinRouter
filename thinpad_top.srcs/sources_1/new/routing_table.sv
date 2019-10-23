`timescale 1ns / 1ps

`include "constants.vh"

module routing_table(
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
enum logic [2:0] {READY, LOOKUP, INSERT, EXPAND, WAIT_I, WAIT_E} StateType;

/* Variables */
logic [`NODE_INDEX_WIDTH-1:0] index, num_nodes;
logic [`IPV4_WIDTH-1:0] addr_saved, nexthop_saved, nexthop_root = 32'b0;
logic [`MASK_WIDTH-1:0] shift;
logic [`LOG_BITS_PER_STEP-1:0] bits_left;
logic [`BITS_PER_STEP:0] expand_counter, expand_end;

/* Memory control */
logic en_write;
logic [`BLCK_ENTRY_WIDTH-1:0] write_data, entry_data;

/* Assign */
wire [`BITS_PER_STEP-1:0] current_bits, bits_helper;
wire [`BLCK_INDEX_WIDTH-1:0] entry_index;
wire [`IPV4_WIDTH-1:0] entry_nexthop;
wire [`NODE_INDEX_WIDTH-1:0] entry_next_index;
wire [`BLCK_COVER_WIDTH-1:0] entry_cover;
wire entry_state;

assign current_bits = addr_saved[`IPV4_WIDTH-1:`IPV4_WIDTH-`BITS_PER_STEP];
assign bits_helper = (`BITS_PER_STEP'b1 << bits_left) - `BITS_PER_STEP'b1;
assign entry_index = index * `NUM_CHILDS + current_bits;
assign entry_cover = entry_data[`BLCK_ENTRY_WIDTH-1:`BLCK_ENTRY_WIDTH-`BLCK_COVER_WIDTH];
assign entry_nexthop = entry_data[`IPV4_WIDTH+`NODE_INDEX_WIDTH-1:`NODE_INDEX_WIDTH];
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
                    if (insert_mask_len == 0) begin
                        nexthop_root <= insert_nexthop;
                    end else begin
                        lookup_insert_ready <= 0;
                        addr_saved <= lookup_insert_addr;
                        nexthop_saved <= insert_nexthop;
                        shift <= (insert_mask_len - 1) >> `LOG_BITS_PER_STEP;
                        bits_left <= ~ (insert_mask_len - 1); // Low bits will be used
                        state <= INSERT;
                    end
                end else if (lookup_valid) begin
                    lookup_insert_ready <= 0;
                    lookup_output_nexthop <= nexthop_root;
                    addr_saved <= lookup_insert_addr;
                    state <= LOOKUP;
                end
                index <= 0;
                lookup_output_valid <= 0;
            end

            LOOKUP: begin
                if (entry_nexthop) begin
                    lookup_output_nexthop <= entry_nexthop;
                end
                if (!entry_next_index) begin    
                    state <= READY;
                    lookup_output_valid <= 1;
                    lookup_insert_ready <= 1;
                end else begin
                    index <= entry_next_index;
                    addr_saved <= addr_saved << `BITS_PER_STEP;
                end
            end
            
            WAIT_I: begin
                en_write <= 0;
                index <= num_nodes + 1;
                num_nodes <= num_nodes + 1;
                shift <= shift - 1;
                addr_saved <= addr_saved << `BITS_PER_STEP;
                state <= INSERT;
            end

            WAIT_E: begin
                en_write <= 0;
                expand_counter <= expand_counter + 1;
                addr_saved <= addr_saved + `ADDR_JUMP;
                state <= EXPAND;
            end

            EXPAND: begin
                if (expand_counter > expand_end) begin
                    state <= READY;
                    en_write <= 0;
                    lookup_insert_ready <= 1;
                end else begin
                    if (entry_cover > (~ bits_left)) begin
                        en_write <= 0;
                        expand_counter <= expand_counter + 1;
                        addr_saved <= addr_saved + `ADDR_JUMP;
                    end else begin
                        en_write <= 1;
                        write_data <= {~ bits_left, nexthop_saved, entry_next_index};
                        state <= WAIT_E;
                    end
                end
            end

            INSERT: begin
                if (shift == 0) begin
                    expand_end <= current_bits | bits_helper;
                    expand_counter <= current_bits & (~ bits_helper);
                    addr_saved <= {current_bits & (~ bits_helper), `ZERO_FILL};
                    state <= EXPAND;
                end else begin
                    if (entry_next_index) begin
                        index <= entry_next_index;
                        shift <= shift - 1;
                        addr_saved <= addr_saved << `BITS_PER_STEP;
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