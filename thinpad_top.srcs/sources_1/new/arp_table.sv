`timescale 1ns / 1ps

`include "constants.vh"


module arp_table(
    input clk,
    input rst,

    input [`IPV4_WIDTH-1:0] lookup_ip,// ip that is looked up for.
    output logic [`MAC_WIDTH-1:0] lookup_mac, // mac that is found
    output logic [`PORT_WIDTH-1:0] lookup_port, // port that is found
    input lookup_ip_valid, // 1 if the lookup_ip is valid
    output logic lookup_mac_found,
    output logic lookup_mac_not_found,

    input [`IPV4_WIDTH-1:0] insert_ip,
    input [`MAC_WIDTH-1:0] insert_mac,
    input [`PORT_WIDTH-1:0] insert_port,
    input insert_valid,
    output logic insert_ready
    );


    // a for lookup, b for insert
    logic [`IPV4_WIDTH+`MAC_WIDTH+`PORT_WIDTH-1:0] data_dina;
    logic [`IPV4_WIDTH+`MAC_WIDTH+`PORT_WIDTH-1:0] data_douta;
    logic [`ARP_ITEM_NUM_WIDTH-1:0] data_addra;
    logic [`IPV4_WIDTH+`MAC_WIDTH+`PORT_WIDTH-1:0] data_dinb;
    logic [`IPV4_WIDTH+`MAC_WIDTH+`PORT_WIDTH-1:0] data_doutb;
    logic [`ARP_ITEM_NUM_WIDTH-1:0] data_addrb;
    logic data_web;


    // Each item consists of (IP, MAC, PORT) tuple.
    // Data: (IP, MAC, PORT)
    xpm_memory_tdpram #(
        .ADDR_WIDTH_A(`ARP_ITEM_NUM_WIDTH),
        .WRITE_DATA_WIDTH_A(`IPV4_WIDTH+`MAC_WIDTH+`PORT_WIDTH),
        .BYTE_WRITE_WIDTH_A(`IPV4_WIDTH+`MAC_WIDTH+`PORT_WIDTH),

        .ADDR_WIDTH_B(`ARP_ITEM_NUM_WIDTH),
        .WRITE_DATA_WIDTH_B(`IPV4_WIDTH+`MAC_WIDTH+`PORT_WIDTH),
        .BYTE_WRITE_WIDTH_B(`IPV4_WIDTH+`MAC_WIDTH+`PORT_WIDTH),
        .MEMORY_SIZE(`ARP_ITEM_NUM*(`IPV4_WIDTH+`MAC_WIDTH+`PORT_WIDTH)),
        .READ_LATENCY_A(0),
        .READ_LATENCY_B(0)
    ) xpm_memory_tdpram_inst (
        .dina(data_dina),
        .douta(data_douta),
        .addra(data_addra),
        .wea(1'b0), // not allowed to write
        .clka(clk),
        .rsta(rst),
        .ena(1'b1),

        .dinb(data_dinb),
        .doutb(data_doutb),
        .addrb(data_addrb),
        .web(data_web),
        .clkb(clk),
        .rstb(rst),
        .enb(1'b1)
    );



enum logic [1:0] {S3,S2,S1,S0} StateA;

always_ff @ (posedge clk) begin
    if (rst) begin
        data_addra <= 0;
        lookup_mac_found <= 0;
        lookup_mac_not_found <= 0;
        lookup_mac <= 0;
        lookup_port <= 0;
        StateA <= S0;
    end else begin
        case (StateA)
            S0: begin
                if (lookup_ip_valid) begin
                    data_addra <= 0;
                    lookup_mac_found <= 0;
                    lookup_mac_not_found <= 0;       
                    StateA <= S1;                 
                end     
            end
            S1: begin
                if (data_douta[`IPV4_WIDTH+`MAC_WIDTH+`PORT_WIDTH-1:`MAC_WIDTH+`PORT_WIDTH]==lookup_ip) begin
                    lookup_mac_found <= 1;
                    lookup_mac <= data_douta[`MAC_WIDTH+`PORT_WIDTH-1:`PORT_WIDTH];
                    lookup_port <= data_douta[`PORT_WIDTH-1:0];
                    StateA <= S0;
                end else if (data_addra==`ARP_ITEM_NUM-1) begin
                    lookup_mac_not_found <= 1;
                    StateA <= S0;
                end else begin
                    data_addra <= data_addra + 1;
                    StateA <= S1;
                end
            end
            default: begin
                /*nothing*/ 
            end
        endcase
    end
end

logic [`IPV4_WIDTH-1:0] saved_insert_ip;
logic [`MAC_WIDTH-1:0] saved_insert_mac;
logic [`PORT_WIDTH-1:0] saved_insert_port;
logic [`IPV4_WIDTH+`MAC_WIDTH+`PORT_WIDTH-1:0] saved_data_doutb;
enum logic [1:0] {S3B,S2B,S1B,S0B} StateB;
logic [`ARP_ITEM_NUM_WIDTH-1:0] writing_addr;
always_ff @ (posedge clk) begin
    if (rst) begin
        data_addrb <= 0;
        saved_insert_ip <= 0;
        saved_insert_mac <= 0;
        saved_insert_port <= 0;
        insert_ready <= 1;
        data_web <= 0;
        writing_addr <= 0;
        StateB <= S0B;  
    end else begin
        case (StateB)
            S0B: begin
                if (insert_valid) begin
                    data_addrb <= 0;
                    insert_ready <= 0;
                    StateB <= S3B;    
                    data_web <= 0; 
                end     
            end
            S3B: begin
                    saved_insert_ip <= insert_ip;
                    saved_insert_mac <= insert_mac;
                    saved_insert_port <= insert_port;   
                    StateB <= S1B;                
            end
            S1B: begin
                if (data_doutb[`IPV4_WIDTH+`MAC_WIDTH+`PORT_WIDTH-1:`MAC_WIDTH+`PORT_WIDTH]==saved_insert_ip) begin
                    data_web <= 1;
                    data_dinb <= {saved_insert_ip,saved_insert_mac,saved_insert_port};
                    StateB <= S2B;
                end else if (data_addrb==`ARP_ITEM_NUM-1) begin
                    data_addrb <= writing_addr;
                    writing_addr <= writing_addr + 1;
                    data_web <= 1;
                    data_dinb <= {saved_insert_ip,saved_insert_mac,saved_insert_port};
                    StateB <= S2B;
                end else begin
                    data_addrb <= data_addrb + 1;
                    StateB <= S1B;
                end
            end
            S2B: begin
                insert_ready <= 1;
                data_web <= 0;
                StateB <= S0B;  
            end
            default: begin
                /*nothing*/
            end
        endcase
    end
end

endmodule