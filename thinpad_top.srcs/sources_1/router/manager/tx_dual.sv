/*
RIP 的发送不是由 io_manager 控制，也不走 tx_manager
因此，此模块接入二者的输出（tx_manager 为 AXIS，RIP 为 fifo）整合
优先保证 tx_manager 的输出
*/

module tx_dual (
    input  logic clk,
    input  logic rst_n,
    
    // tx_manager 的输出
    input  logic [7:0] tx_data,
    input  logic tx_valid,
    input  logic tx_last,

    // packer 的输出
    input  logic [8:0] rip_data,
    input  logic rip_empty,
    output logic rip_read_valid,

    // eth_mac 上的真正 tx
    output logic [7:0] out_data,
    output logic out_valid,
    output logic out_last,
    input  logic out_ready
);

logic [8:0] tx_fifo_out;
logic tx_fifo_empty;
logic tx_fifo_read_valid;
// 给 tx_manager 一层缓冲
xpm_fifo_sync #(
    .FIFO_MEMORY_TYPE("distributed"),
    .FIFO_READ_LATENCY(0),
    .FIFO_WRITE_DEPTH(2048),
    .READ_DATA_WIDTH(9),
    .READ_MODE("fwft"),
    .USE_ADV_FEATURES("0000"),
    .WRITE_DATA_WIDTH(9)
) tx_fifo (
    .din({tx_last, tx_data}),
    .dout(tx_fifo_out),
    .empty(tx_fifo_empty),
    .full(),
    .injectdbiterr(0),
    .injectsbiterr(0),
    .rd_en(tx_fifo_read_valid),
    .rst(0),
    .sleep(0),
    .wr_clk(clk),
    .wr_en(tx_valid)
);

enum logic [1:0] {
    None, TX, RIP
} sending_from;

always_comb begin
    tx_fifo_read_valid = sending_from == TX && !tx_fifo_empty;
    rip_read_valid = sending_from == RIP && !rip_empty;
end

always_ff @(posedge clk) begin
    if (!rst_n) begin
        sending_from <= None;
    end else begin

        out_data <= 0;
        out_valid <= 0;
        out_last <= 0;

        if (out_ready) begin
            case (sending_from)
                None: begin
                    if (!tx_fifo_empty) begin
                        sending_from <= TX;
                    end else if (!rip_empty) begin
                        sending_from <= RIP;
                    end
                end
                TX: begin
                    if (!tx_fifo_empty) begin
                        {out_last, out_data} <= tx_fifo_out;
                        out_valid <= 1;
                        // last
                        if (tx_fifo_out[8]) begin
                            sending_from <= None;
                        end
                    end
                end
                RIP: begin
                    if (!rip_empty) begin
                        {out_last, out_data} <= rip_data;
                        out_valid <= 1;
                        // last
                        if (rip_data[8]) begin
                            sending_from <= None;
                        end
                    end
                end
            endcase
        end
        
    end
end

endmodule