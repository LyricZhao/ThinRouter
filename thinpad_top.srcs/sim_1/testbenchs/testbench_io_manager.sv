`timescale 1ns / 1ps
module testbench_io_manager ();

reg clk_125M;
reg [7:0] rx_data = 0;
reg rx_valid = 0;
reg rx_last = 0;
logic rx_ready;
logic [7:0] tx_data;
logic tx_valid;
logic tx_last;
wire tx_ready = 1;

localparam WAIT = 9;
localparam READ_LABEL = 10;
localparam READ_DATA = 11;
int state = 0;

int fd = 0;                 // file descriptor
string buffer;
bit [15:0] data;

logic rst_n;

initial begin
    clk_125M = 0;
    rst_n = 0;
    rst_n = #100 1;
end

always clk_125M = #4 ~clk_125M;

string tx_packet = "";
always_ff @ (negedge clk_125M) begin
    if (tx_valid) begin
        $sformat(tx_packet, "%s %02x", tx_packet, tx_data);
        if (tx_last) begin
            $display("LAST");
            $display("TX:%s", tx_packet);
            tx_packet = "";
        end
    end
end

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
                        $fgets(buffer, fd);
                        $write("Info:\t%s", buffer);
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
                $display("RX:%s", rx_packet);
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
        fd = $fopen("eth_frame_test.mem", "r");
end


wire [4:0] debug_state;
wire [15:0] debug_countdown;
wire [5:0] debug_current;
wire [5:0] debug_tx;
wire [5:0] debug_last;
wire [6:0] debug_case;
string io_state;

always_comb case (debug_state)
    0: io_state = "Idle";
    1: io_state = "Load_Unprocessed_Packet";
    2: io_state = "Load_Processing_Packet";
    3: io_state = "Discard_Packet";
    4: io_state = "Send_Load_Packet";
    5: io_state = "Send_Detrailer_Packet";
    6: io_state = "Send_Packet";
    7: io_state = "Send_Load_Another_Unprocessed";
    8: io_state = "Send_Load_Another_Processing";
    9: io_state = "Send_Load_Another_Processed";
    10: io_state = "Send_Discard_Another";
endcase

io_manager inst (
    .clk_fifo(clk_125M),
    .*
);

endmodule
