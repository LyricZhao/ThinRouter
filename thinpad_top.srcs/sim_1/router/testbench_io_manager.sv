`timescale 1ns / 1ps
module testbench_io_manager ();

bit clk_125M;
bit clk_200M;
reg [7:0] rx_data = 0;
reg rx_valid = 0;
reg rx_last = 0;
logic rx_ready;
logic [7:0] tx_data;
logic tx_valid;
logic tx_last;
wire tx_ready = 1;
logic [15:0] debug;

localparam WAIT = 9;
localparam READ_LABEL = 10;
localparam READ_DATA = 11;
int state = 0;

int fd = $fopen("io_manager_test.mem", "r");                 // file descriptor
string buffer;
bit [15:0] data;

logic rst_n;

initial begin
    clk_125M = 0;
    rst_n = 0;
    rst_n = #100 1;
end

always #2.5 clk_200M = ~clk_200M;
always #4 clk_125M = ~clk_125M;

string tx_packet = "";
always_ff @ (negedge clk_125M) begin
    if (tx_valid) begin
        $sformat(tx_packet, "%s %02x", tx_packet, tx_data);
        if (tx_last) begin
            $display("Router OUT:\t%s\n", tx_packet);
            tx_packet = "";
        end
    end
end

string info_line = "";
string packet_info = "";
string rx_packet = "";
always_ff @ (negedge clk_125M) begin
    if (fd) case (state)
        READ_LABEL: begin
            if ($feof(fd))
                fd = 0;
            else begin
                $fscanf(fd, "%s", buffer);
                case (buffer)
                    "info:": begin
                        $fgets(info_line, fd);
                        $sformat(packet_info, "%s%s", packet_info, info_line);
                    end
                    "eth_frame:": begin
                        state = state + 1;
                        $fscanf(fd, "%x", data);
                        rx_packet = "";
                        // $write("Frame IN:\t");
                    end
                endcase
            end
        end
        READ_DATA: begin
            if (data == 12'hfff) begin
                // end of line
                state = WAIT;
                rx_valid = 0;
                rx_last = 0;
                $display("%0t", $realtime);
                $write("Info:\t%s", packet_info);
                $display("Router IN:\t%s\n", rx_packet);
                packet_info = "";
                // $display("");
            end else begin
                rx_valid = 1;
                rx_data = data[7:0];
                $sformat(rx_packet, "%s %02x", rx_packet, data[7:0]);
                $fscanf(fd, "%x", data);
                rx_last = data == 12'hfff;
                // $write("%02x ", data[7:0]);
            end
        end
        default:
            state = state + 1;
    endcase
    else
        fd = #1000000 $fopen("io_manager_test.mem", "r");
end

logic clk_btn;
logic [3:0]  btn;
logic [15:0] led_out;
logic [7:0]  digit0_out;
logic [7:0]  digit1_out;


logic   [8:0] fifo_din;
logic   [8:0] fifo_wr_en;
logic   [5:0] read_cnt;
io_manager inst (
    .*
);

endmodule
