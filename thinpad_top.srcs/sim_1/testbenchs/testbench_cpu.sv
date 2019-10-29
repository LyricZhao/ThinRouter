
`include "constants_cpu.vh"
`timescale 1ns/1ps

module testbench_cpu();

    reg CLOCK_50;
    reg rst;
  
       
    initial begin
        CLOCK_50 = 1'b0;
        forever #10 CLOCK_50 = ~CLOCK_50;
    end
      
    initial begin
        rst = `RstEnable;
        #195 rst= `RstDisable;
        #1000 $stop;
    end
       
    naive_sopc naive_sopc0(
        .clk(CLOCK_50),
        .rst(rst)	
    );

endmodule