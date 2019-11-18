`timescale 1ns / 1ps
module rgmii_model (
    input wire clk_125M,
    input wire clk_125M_90deg,

    output wire [3:0] rgmii_rd,
    output wire rgmii_rx_ctl,
    output wire rgmii_rxc
);

localparam WAIT = 0;
localparam READ_LABEL = 10;
localparam READ_DATA = 11;
int state = 0;

bit trans = 0;              // 给 ODDR 的传输信号
bit [3:0] data1;            // 给 ODDR 的数据
bit [3:0] data2;            // 给 ODDR 的数据
int fd = 0;                 // file descriptor
string buffer;
bit [15:0] data;

string packet_info;
string rx_stream;
always_ff @ (posedge clk_125M) begin
    if (fd) case (state)
        READ_LABEL: begin
            if ($feof(fd))
                fd = 0;
            else begin
                $fscanf(fd, "%s", buffer);
                case (buffer)
                    "info:": begin
                        $fgets(packet_info, fd);
                    end
                    "eth_frame:": begin
                        state = state + 1;
                        $fscanf(fd, "%x", data);
                        // $write("Frame IN:\t");
                    end
                endcase
            end
        end
        READ_DATA: begin
            if (data == 12'hfff) begin
                // end of line
                state = WAIT;
                trans = 0;
                $write("Info:\t%s", packet_info);
                $display("Router IN:\t%s\n", rx_stream);
                rx_stream = "";
            end else begin
                trans = 1;
                data1 = data[3:0];
                data2 = data[7:4];
                $sformat(rx_stream, "%s %02x", rx_stream, data[7:0]);
                $fscanf(fd, "%x", data);
            end
        end
        default:
            state = state + 1;
    endcase
    else
        fd = #1000 $fopen("eth_frame_test.mem", "r");
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
