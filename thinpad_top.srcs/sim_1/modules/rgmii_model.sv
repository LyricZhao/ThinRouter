`timescale 1ns / 1ps
module rgmii_model (
    input wire clk_125M,
    input wire clk_125M_90deg,

    output bit [3:0] rgmii_rd,
    output bit rgmii_rx_ctl,
    output bit rgmii_rxc
);

bit rgmii_rxc;
initial begin
    rgmii_rxc = 1;
    #2;
    forever rgmii_rxc = #4 ~rgmii_rxc;
end

enum {
    WAIT,
    READ_LABEL,
    READ_DATA
} state = WAIT;

int fd = 0;                 // file descriptor
string buffer;

string packet_info;
string rx_stream;

initial forever begin
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
                        state = READ_DATA;
                    end
                endcase
            end
        end
        READ_DATA: begin
            int data;
            $fscanf(fd, "%x", data);
            if (data == 12'hfff) begin
                // end of line
                state = WAIT;
                rgmii_rx_ctl = 0;
                $write("Info:\t%s", packet_info);
                $display("Router IN:\t%s\n", rx_stream);
                rx_stream = "";
            end else begin
                rgmii_rx_ctl = 1;
                $sformat(rx_stream, "%s %02x", rx_stream, data[7:0]);
                rgmii_rd = data[3:0];
                #4;
                rgmii_rd = data[7:4];
                #4;
            end
        end
        WAIT: begin
            #64;
            state = READ_LABEL;
        end
    endcase
    else
        fd = #4000 $fopen("eth_frame_test.mem", "r");
end

endmodule
