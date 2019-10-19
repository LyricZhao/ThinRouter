/*
修改自杰哥的代码
*/
`timescale 1ns / 1ps
`include "constants.vh"

module testbench_arp_table();

    logic clk;
    logic rst;
    logic [`IPV4_WIDTH-1:0] lookup_ip;
    logic [`MAC_WIDTH-1:0] lookup_mac;
    logic [1:0] lookup_port;
    logic lookup_ip_valid;
    logic lookup_mac_valid;
    logic lookup_mac_not_found;

    logic [`IPV4_WIDTH-1:0] insert_ip;
    logic [`MAC_WIDTH-1:0] insert_mac;
    logic [`PORT_WIDTH-1:0] insert_port;
    logic insert_valid;
    logic insert_ready;
    logic [`IPV4_WIDTH+`MAC_WIDTH+`PORT_WIDTH-1:0] data_douta_debug;
    //logic [`IPV4_WIDTH+`MAC_WIDTH+`PORT_WIDTH-1:0] data_doutb_debug;
    
    arp_table arp_table_inst(
        .clk(clk),
        .rst(rst),

        .lookup_ip(lookup_ip),
        .lookup_mac(lookup_mac),
        .lookup_port(lookup_port),
        .lookup_ip_valid(lookup_ip_valid),
        .lookup_mac_valid(lookup_mac_valid),
        .lookup_mac_not_found(lookup_mac_not_found),

        .insert_ip(insert_ip),
        .insert_mac(insert_mac),
        .insert_port(insert_port),
        .insert_valid(insert_valid),
        .insert_ready(insert_ready),
        .data_douta_debug(data_douta_debug)
        //.data_doutb_debug(data_doutb_debug)
    );

    initial begin
        clk = 0;
        rst = 1;
        lookup_ip = 0;
        lookup_ip_valid = 0;
        insert_ip = 0;
        insert_mac = 0;
        insert_port = 0;
        insert_valid = 0;
        #100
        rst = 0;

        // lookup 10.0.0.1, not found
        repeat (10) @ (posedge clk);
        lookup_ip <= 32'h0a000001; // 10.0.0.1
        lookup_ip_valid <= 1;
        repeat (1) @ (posedge clk);
        lookup_ip_valid <= 0;
        repeat (10) @ (posedge clk);
        if (!lookup_mac_not_found) $finish;

        // insert 10.0.0.1
        repeat (10) @ (posedge clk);
        insert_ip <= 32'h0a000001; // 10.0.0.1
        insert_mac <= 48'hcafed00dbeef;
        insert_port <= 2'b10;
        insert_valid <= 1;
        repeat (1) @ (posedge clk);
        insert_valid <= 0;

        // insert 10.0.0.2
        repeat (10) @ (posedge clk);
        insert_ip <= 32'h0a000002; // 10.0.0.2
        insert_mac <= 48'habababababab;
        insert_port <= 2'b11;
        insert_valid <= 1;
        repeat (1) @ (posedge clk);
        insert_valid <= 0;

        // insert 10.0.0.3
        repeat (10) @ (posedge clk);
        insert_ip <= 32'h0a000003; // 10.0.0.3
        insert_mac <= 48'h101010101010;
        insert_port <= 2'b00;
        insert_valid <= 1;
        repeat (1) @ (posedge clk);
        insert_valid <= 0;

        // lookup 10.0.0.1
        repeat (10) @ (posedge clk);
        lookup_ip <= 32'h0a000001; // 10.0.0.1
        lookup_ip_valid <= 1;
        repeat (10) @ (posedge clk);
        lookup_ip_valid <= 0;
        if (lookup_mac != `MAC_WIDTH'hcafed00dbeef) $finish;
        if (lookup_port != 2'b10) $finish;

        // lookup 10.0.0.2
        repeat (10) @ (posedge clk);
        lookup_ip <= 32'h0a000002; // 10.0.0.2
        lookup_ip_valid <= 1;
        repeat (10) @ (posedge clk);
        lookup_ip_valid <= 0;
        if (lookup_mac != `MAC_WIDTH'habababababab) $finish;
        if (lookup_port != 2'b11) $finish;

        // lookup 10.0.0.1
        repeat (10) @ (posedge clk);
        insert_valid <= 0;
        lookup_ip <= 32'h0a000001; // 10.0.0.1
        lookup_ip_valid <= 1;
        repeat (10) @ (posedge clk);
        lookup_ip_valid <= 0;
        if (lookup_mac != `MAC_WIDTH'hcafed00dbeef) $finish;
        if (lookup_port != 2'b10) $finish;

        // lookup 10.0.0.3
        repeat (10) @ (posedge clk);
        insert_valid <= 0;
        lookup_ip <= 32'h0a000003; // 10.0.0.3
        lookup_ip_valid <= 1;
        repeat (10) @ (posedge clk);
        lookup_ip_valid <= 0;
        if (lookup_mac != `MAC_WIDTH'h101010101010) $finish;
        if (lookup_port != 2'b00) $finish;

        // update 10.0.0.2
        repeat (10) @ (posedge clk);
        insert_ip <= 32'h0a000002; // 10.0.0.2
        insert_mac <= 48'hcccccccccccc;
        insert_port <= 2'b01;
        insert_valid <= 1;
        repeat (1) @ (posedge clk);
        insert_valid <= 0;

        // lookup 10.0.0.2
        repeat (10) @ (posedge clk);
        insert_valid <= 0;
        lookup_ip <= 32'h0a000002; // 10.0.0.2
        lookup_ip_valid <= 1;
        repeat (10) @ (posedge clk);
        lookup_ip_valid <= 0;
        if (lookup_mac != `MAC_WIDTH'hcccccccccccc) $finish;
        if (lookup_port != 2'b01) $finish;

        // lookup 10.0.0.1, no overflow yet
        repeat (10) @ (posedge clk);
        insert_valid <= 0;
        lookup_ip <= 32'h0a000001; // 10.0.0.1
        lookup_ip_valid <= 1;
        repeat (10) @ (posedge clk);
        lookup_ip_valid <= 0;
        if (lookup_mac != `MAC_WIDTH'hcafed00dbeef) $finish;
        if (lookup_port != 2'b10) $finish;

        // insert 10.0.0.4
        repeat (10) @ (posedge clk);
        insert_ip <= 32'h0a000004; // 10.0.0.4
        insert_mac <= 48'h111111111111;
        insert_port <= 2'b00;
        insert_valid <= 1;
        repeat (1) @ (posedge clk);
        insert_valid <= 0;

        // lookup 10.0.0.1, overflow
        repeat (10) @ (posedge clk);
        insert_valid <= 0;
        lookup_ip <= 32'h0a000001; // 10.0.0.1
        lookup_ip_valid <= 1;
        repeat (10) @ (posedge clk);
        lookup_ip_valid <= 0;
        if (!lookup_mac_not_found) $finish;

        // insert 10.0.0.5
        repeat (10) @ (posedge clk);
        insert_ip <= 32'h0a000005; // 10.0.0.5
        insert_mac <= 48'h222222222222;
        insert_port <= 2'b11;
        insert_valid <= 1;
        repeat (1) @ (posedge clk);
        insert_valid <= 0;

        // lookup 10.0.0.3, on the top
        repeat (10) @ (posedge clk);
        insert_valid <= 0;
        lookup_ip <= 32'h0a000003; // 10.0.0.3
        lookup_ip_valid <= 1;
        repeat (10) @ (posedge clk);
        lookup_ip_valid <= 0;
        if (lookup_mac != `MAC_WIDTH'h101010101010) $finish;
        if (lookup_port != 2'b00) $finish;

        // insert 255.0.0.1
        repeat (10) @ (posedge clk);
        insert_ip <= 32'hff000001; // 255.0.0.1
        insert_mac <= 48'h00000000;
        insert_port <= 2'b10;
        insert_valid <= 1;
        repeat (1) @ (posedge clk);
        insert_valid <= 0;
    end
    
    always clk = #10 ~clk; // 50MHz

endmodule
