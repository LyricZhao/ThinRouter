/*
涂轶翔：
各种控制 led 灯的方法
*/

// 温度计码
module progress_led (
    input   wire    [3:0]   value,
    output  wire    [15:0]  led
);
genvar i;
generate for (i = 0; i < 16; i++)
    assign led[i] = value >= i;
endgenerate
endmodule

// 亮指定位置的
module single_led (
    input   wire    [3:0]   value,
    output  wire    [15:0]  led
);
assign led = 1 << value;
endmodule

// 左右摇摆
module led_loop #(parameter LEN = 16) (
    input   wire    rst,
    input   wire    clk,
    output  bit     [LEN-1:0] led
);
bit flipped;
always_ff @ (posedge clk or posedge rst) begin
    if (rst) begin
        led <= 0;
    end else begin
        if (led == 0) begin
            led <= 1;
        end else if (led[0] == 1) begin
            led <= 2;
            flipped <= 0;
        end else if (led[LEN-1] == 1) begin
            led[LEN-1:LEN-2] <= 2'b01;
            flipped <= 1;
        end else if (flipped)
            led <= led >>> 1;
        else
            led <= led << 1;
    end
end
endmodule

// 0-F
module digit_hex (
    input   wire    [3:0] value,
    output  bit     [7:0] digit
);
always_comb case (value)
    0 : digit = 8'b01111110;
    1 : digit = 8'b00010010;
    2 : digit = 8'b10111100;
    3 : digit = 8'b10110110;
    4 : digit = 8'b11010010;
    5 : digit = 8'b11100110;
    6 : digit = 8'b11101110;
    7 : digit = 8'b00110010;
    8 : digit = 8'b11111110;
    9 : digit = 8'b11110110;
    10: digit = 8'b11111011;
    11: digit = 8'b11001110;
    12: digit = 8'b01101100;
    13: digit = 8'b10011110;
    14: digit = 8'b11101100;
    15: digit = 8'b11101000;
endcase
endmodule

// 00-99
module digit_dec_count (
    input   wire    rst,
    input   wire    clk,
    output  wire    [7:0] digit0,
    output  wire    [7:0] digit1
);
bit [3:0] value0;
bit [3:0] value1;
digit_hex lo(value0, digit0);
digit_hex hi(value1, digit1);
always_ff @ (posedge clk or posedge rst) begin
    if (rst) begin
        value0 <= 0;
        value1 <= 0;
    end else begin
        if (value0 == 9) begin
            value0 <= 0;
            if (value1 == 9) 
                value1 <= 0;
            else
                value1 <= value1 + 1;
        end else 
            value0 <= value0 + 1;
    end
end
endmodule

// 数码管循环亮灯
module digit_loop (
    input   wire    rst,
    input   wire    clk,
    output  bit     [7:0] digit
);
bit [2:0] cnt;
always_comb case (cnt)
    0: digit = 8'b00000001;
    1: digit = 8'b00000010;
    2: digit = 8'b00000100;
    3: digit = 8'b00001000;
    4: digit = 8'b01000000;
    5: digit = 8'b00100000;
    6: digit = 8'b00010000;
    7: digit = 8'b00000000;
endcase
always_ff @ (posedge clk or posedge rst) begin
    if (rst)
        cnt <= 0;
    else case (cnt)
        0, 6: cnt <= 1;
        default: cnt <= cnt + 1;
    endcase
end
endmodule

// 数码管循环亮灯
module digit_loop_alt (
    input   wire    rst,
    input   wire    clk,
    output  bit     [7:0] digit
);
bit [2:0] cnt;
always_comb
    if (rst)
        digit = 8'b00000001;
    else case (cnt)
        0: digit = 8'b00010000;
        1: digit = 8'b00100000;
        2: digit = 8'b01000000;
        3: digit = 8'b10000000;
        4: digit = 8'b00000010;
        5: digit = 8'b00000100;
        6: digit = 8'b00001000;
        7: digit = 8'b10000000;
    endcase
always_ff @ (posedge clk or posedge rst) begin
    if (rst)
        cnt <= 0;
    else
        cnt <= cnt + 1;
end
endmodule