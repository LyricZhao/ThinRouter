
`include "constants_cpu.vh"

module inst_rom(

//	input wire clk,
	input wire ce,
	input wire[`InstAddrBus] addr,
	output reg[`InstBus] inst
	
);

reg[`InstBus]  inst_mem[0:`InstMemNum-1];

initial $readmemh ( "inst_rom.data", inst_mem );
initial $display("insert done");
// initial begin
//     inst_mem[0]<=8'h34011100;
//     inst_mem[1]<=8'h34020020;
//     inst_mem[2]<=8'h3403ff00;
//     inst_mem[3]<=8'h3404ffff;
// end

// assign inst_mem[0]=8'h34011100;
// assign inst_mem[1]=8'h34020020;
// assign inst_mem[2]=8'h3403ff00;
// assign inst_mem[3]=8'h3404ffff;



always_comb begin
    if (ce == 1'b0) 
    begin
        inst <= `ZeroWord;
    end else begin
        inst <= inst_mem[addr[`InstMemNumLog2+1:2]];
    end
end

endmodule