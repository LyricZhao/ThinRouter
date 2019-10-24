`timescale 1ns / 1ps
module rgmii_model (
    input clk_125M,
    input clk_125M_90deg,

    output [3:0] rgmii_rd,
    output rgmii_rx_ctl,
    output rgmii_rxc
);

localparam INTERVAL = 10;   // 发包间隔

bit trans;                  // 给 ODDR 的传输信号
bit [3:0] data1;            // 给 ODDR 的数据
bit [3:0] data2;            // 给 ODDR 的数据
int fd;                     // file descriptor
int interval_cnt;           // 间隔计数

initial begin
    fd = $fopen("example_frame.mem", "r");

    while (!$feof(fd)) begin
        res = $fscanf(fd, "%x", frame_data[frame_count][index]);
        if (res != 1) begin
            // end of a frame
            // read a line
            $fgets(buffer, fd);
            if (index > 0) begin
                frame_size[frame_count] = index + 1;
                frame_count = frame_count + 1;
            end
            index = 0;
        end else begin
            index = index + 1;
        end
    end

    if (index > 0) begin
        frame_size[frame_count] = index + 1;
        frame_count = frame_count + 1;
    end
end

always_ff @ (posedge clk_125M) begin
    if (packet_clk && count < frame_size[frame_index] - 1) begin
        trans <= 1'b1;
        data1 <= frame_data[frame_index][count][3:0];
        data2 <= frame_data[frame_index][count][7:4];
    end else begin
        trans <= 1'b0;
        data1 <= 4'b0;
        data2 <= 4'b0;
    end
end

genvar i;
for (i = 0;i < 4;i++) begin
    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE") // OPPOSITE_EDGE or SAME_EDGE
    ) oddr_inst (
        .D1(data1[i]),      // 1-bit data input (posedge)
        .D2(data2[i]),      // 1-bit data input (negedge)
        .C(clk_125M),       // 1-bit clock
        .CE(1'b1),          // 1-bit clock enable
        .Q(rgmii_rd[i]),    // 1-bit ddr output
        .R(1'b0)            // 1-bit reset
    );
end

ODDR #(
    .DDR_CLK_EDGE("SAME_EDGE")
) oddr_inst_ctl (
    .D1(trans),
    .D2(trans),
    .C(clk_125M),
    .CE(1'b1),
    .Q(rgmii_rx_ctl), // ctl = dv ^ er
    .R(1'b0)
);

assign rgmii_rxc = clk_125M_90deg; // clock

endmodule
