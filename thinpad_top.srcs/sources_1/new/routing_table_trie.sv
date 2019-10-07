`timescale 1ns / 1ps

`define IPV4_WIDTH 32
`define MASK_WIDTH 5
`define BYTE_WIDTH 8
`define INDEX_WIDTH 16
`define ENTRY_WIDTH 128 // `INDEX_WIDTH*2+IPV4_WIDTH+1 rounded up to 2's pow
`define ENTRY_COUNT 1024

module routing_table_trie(
    input wire clk,
    input wire rst,

    input wire [`IPV4_WIDTH-1:0] lookup_insert_addr,
    input wire [`IPV4_WIDTH-1:0] insert_nexthop;
    input wire lookup_valid,

    input wire [`MASK_WIDTH-1:0] insert_mask_len,
    input wire insert_valid,

    output logic lookup_insert_ready,
    output logic insert_valid,
    output logic insert_error,
    output logic lookup_valid,
    // TODO: output logic lookup_not_found 
    output logic [`IPV4_WIDTH-1:0] lookup_nexthop
);

logic proc_state, en_write;
logic [`INDEX_WIDTH-1:0] index, node_count;
logic [`ENTRY_WIDTH-1:0] write_data;
logic [`ENTRY_WIDTH-1:0] entry_data;
logic [`IPV4_WIDTH-1:0] addr_saved, insert_nexthop_saved;
logic [`MASK_WIDTH-1:0] shift_pos;

wire current_bit, node_valid;
wire [INDEX_WIDTH-1:0] node_left_index, node_right_index;
wire [IPV4_WIDTH-1:0] node_nexthop;
assign current_bit = addr_saved[31];
assign node_valid = entry_data[`INDEX_WIDTH+`INDEX_WIDTH+`IPV4_WIDTH:`INDEX_WIDTH+`INDEX_WIDTH+`IPV4_WIDTH];
assign node_left_index = entry_data[`INDEX_WIDTH-1:0], node_right_index = entry_data[`INDEX_WIDTH+`INDEX_WIDTH-1:`INDEX_WIDTH];
assign node_nexthop = entry_data[`INDEX_WIDTH+`INDEX_WIDTH+`IPV4_WIDTH-1:`INDEX_WIDTH+`INDEX_WIDTH];

xpm_memory_spram #(
    .ADDR_WIDTH_A(`INDEX_WIDTH),
    .WRITE_DATA_WIDTH_A(`ENTRY_WIDTH),
    .BYTE_WRITE_WIDTH_A(`BYTE_WIDTH),
    .READ_DATA_WIDTH_A(`ENTRY_WIDTH),
    .READ_LATENCY_A(0),
    .MEMORY_SIZE(`ENTRY_COUNT * `ENTRY_WIDTH),
) xpm_memory_spram_data (
    .addra(index),
    .wea(en_write),
    .dina(write_data),
    .douta(entry_data),
    .clka(clk),
    .rsta(rst),
    .ena(1'b1)
);

logic [2:0] state;
enum logic [2:0] {READY, NEW_INSERT, NEW_LOOKUP, PROC_INSERT, PROC_LOOKUP, NEW_NODE, SET_VALID} StateType;

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
        en_write <= 0;
        node_count <= 0;
        state <= READY;
    end else begin
        case (state)
            READY: begin
                /* TODO: Clean up */
            end

            NEW_INSERT: begin
                lookup_insert_ready <= 0;
                addr_saved <= lookup_insert_addr;
                insert_nexthop_saved <= insert_nexthop;
                shift_pos <= insert_mask_len;
                proc_state <= 0;
            end

            NEW_NODE: begin
                en_write <= 0;
                index <= node_count;
                state <= PROC_INSERT;
                shift_pos <= shift_pos - 1;
                addr_saved <= addr_saved << 1;
            end

            SET_VALID: begin
                en_write <= 0;
                insert_valid <= 1;
                insert_error <= 0;
                lookup_insert_ready <= 1;
                state <= READY;
            end

            PROC_INSERT: begin
                if (shift_pos == 0) begin
                    if (node_valid) begin
                        insert_error <= 1;
                        insert_valid <= 0;
                        lookup_insert_ready <= 1;
                    end else begin
                        en_write <= 1;
                        write_data <= {64'h0x1, insert_nexthop_saved, node_left_index, node_right_index};
                    end
                end else begin
                    if (current_bit == 0) begin
                        if (node_left_index == 0) begin
                            en_write <= 1;
                            node_count <= node_count + 1;
                            write_data <= node_count + 1;
                            state <= NEW_NODE;
                        end else begin
                            index <= node_left_index;
                            shift_pos <= shift_pos - 1;
                            addr_saved <= addr_saved << 1;
                        end
                    end else begin
                        if (node_right_index == 0) begin
                            en_write <= 1;
                            node_count <= node_count + 1;
                            write_data <= node_count + 1;
                            state <= NEW_NODE;
                        end else begin
                            index <= node_right_index;
                            shift_pos <= shift_pos - 1;
                            addr_saved <= addr_saved << 1;
                        end
                    end
                end
            end

            NEW_LOOKUP: begin

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