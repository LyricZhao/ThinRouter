/*
ARP的Testbench
*/
`timescale 1ns / 1ps

`include "types.vh"

module testbench_arp_table();

    logic clk;
    logic rst;
    ip_t lookup_ip;
    mac_t lookup_mac;
    logic [2:0] lookup_port;
    logic lookup_ip_valid;
    logic lookup_mac_found;
    logic lookup_mac_not_found;

    ip_t insert_ip;
    mac_t insert_mac;
    logic [2:0] insert_port;
    logic insert_valid;
    logic insert_ready = 1;
    
    simple_arp_table arp_table_inst(
        .clk(clk),
        .rst_n(~rst),

        .ip_query(lookup_ip),
        .mac_output(lookup_mac),
        .vlan_output(lookup_port),
        .query(lookup_ip_valid),
        .found(lookup_mac_found),
        .done(lookup_mac_not_found),

        .ip_insert(insert_ip),
        .mac_input(insert_mac),
        .vlan_input(insert_port),
        .write(insert_valid)
        //.data_douta_debug(data_douta_debug)
        //.data_doutb_debug(data_doutb_debug)
    );

    // 等待插入处理完毕
    task wait_till_insert_ready;
    begin
        do
            repeat (1) @ (posedge clk);
        while (!insert_ready);
    end
    endtask

    // 等待查询结果
    task wait_for_result;
    begin
        do
            repeat (1) @ (posedge clk);
        while (!lookup_mac_found && !lookup_mac_not_found);
    end
    endtask

    task insert;
        input bit[31:0] addr;   // ip 地址
        input bit[47:0] mac;    // mac 地址
        input bit[2:0] port;    // 物理接口
    begin
        $display("insert %0d.%0d.%0d.%0d -> %2x:%2x:%2x:%2x:%2x:%2x@%d",
            addr[31:24], addr[23:16], addr[15:8], addr[7:0],
            mac[47:40], mac[39:32], mac[31:24], mac[23:16], mac[15:8], mac[7:0],
            port);
        insert_ip <= addr;
        insert_mac <= mac;
        insert_port <= port;
        insert_valid <= 1;
        repeat (1) @ (posedge clk);
        insert_valid <= 0;
        wait_till_insert_ready();
        $display("insert done");
    end
    endtask

    task query;
        input bit[31:0] addr;       // ip 地址
        input bit[47:0] expect_mac; // 预期 mac 地址
        input bit[2:0] expect_port; // 预期物理接口
    begin
        $display("query  %0d.%0d.%0d.%0d",
            addr[31:24], addr[23:16], addr[15:8], addr[7:0]);
        lookup_ip <= addr;
        lookup_ip_valid <= 1;
        repeat (1) @ (posedge clk);
        lookup_ip_valid <= 0;
        wait_for_result();

        if (lookup_mac_found) begin
            $display("get    %2x:%2x:%2x:%2x:%2x:%2x@%d",
                lookup_mac[47:40], lookup_mac[39:32], lookup_mac[31:24], 
                lookup_mac[23:16], lookup_mac[15:8], lookup_mac[7:0], lookup_port);
            if (expect_mac == lookup_mac && expect_port == lookup_port)
                $display("correct");
            else
                $display("WRONG! Expecting %2x:%2x:%2x:%2x:%2x:%2x@%d",
                    expect_mac[47:40], expect_mac[39:32], expect_mac[31:24], 
                    expect_mac[23:16], expect_mac[15:8], expect_mac[7:0], expect_port);
        end else begin
            $display("get    none");
            if (expect_mac == '0 && expect_port == '0)
                $display("correct");
            else
                $display("WRONG! Expecting %2x:%2x:%2x:%2x:%2x:%2x@%d",
                    expect_mac[47:40], expect_mac[39:32], expect_mac[31:24], 
                    expect_mac[23:16], expect_mac[15:8], expect_mac[7:0], expect_port);
        end
        
        wait_till_insert_ready();
    end
    endtask

    // 根据输入数据进行插入/查询
    task run_test_entry;
        bit finished;
        int count;
        int file_descriptor;
        bit[127:0] buffer;
    begin
        finished = 0;
        count = 0;
        file_descriptor = $fopen("arp_test.mem", "r");
        while (!finished) begin
            $fscanf(file_descriptor, "%s", buffer);
            unique casez (buffer[47:0])
                "insert": begin
                    // insert
                    count += 1;
                    $display("%0d.", count);
                    $fscanf(file_descriptor, "%d.%d.%d.%d -> %2x:%2x:%2x:%2x:%2x:%2x@%d",
                        buffer[31:24], buffer[23:16], buffer[15:8], buffer[7:0], 
                        buffer[79:72], buffer[71:64], buffer[63:56], buffer[55:48], buffer[47:40], buffer[39:32], 
                        buffer[82:80]);
                    insert(buffer[31:0], buffer[79:32], buffer[82:80]);
                end
                {8'h??, "query"}: begin
                    // query
                    count += 1;
                    $display("%0d.", count);
                    $fscanf(file_descriptor, "%d.%d.%d.%d -> %2x:%2x:%2x:%2x:%2x:%2x@%d",
                        buffer[31:24], buffer[23:16], buffer[15:8], buffer[7:0], 
                        buffer[79:72], buffer[71:64], buffer[63:56], buffer[55:48], buffer[47:40], buffer[39:32], 
                        buffer[82:80]);
                    query(buffer[31:0], buffer[79:32], buffer[82:80]);
                end
                {24'h??????, "end"}: begin
                    finished = 1;
                    $display("end");
                end
            endcase
        end
    end
    endtask 

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

        run_test_entry();
    end
    
    always clk = #10 ~clk; // 50MHz

endmodule
