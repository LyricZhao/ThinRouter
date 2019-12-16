// TODO

`timescale 1ns / 1ps

`include "constants.vh"

module testbench_routing_table();

typedef logic [31:0] ip_t;

logic clk_125M, rst_n;
logic [15:0] second = 0;

// 需要查询的 IP 地址
ip_t  ip_query;
// 进行查询，同步置 1
logic query_valid;
// 查询结果，0 表示无连接
ip_t  nexthop_result;
// 可以查询
logic query_ready;

// 需要插入的 IP 地址
ip_t  ip_insert;
// 插入的 mask
logic [4:0] mask_insert;
// 插入的 nexthop
ip_t  nexthop_insert;
// 插入的 metric
logic [4:0] metric_insert;
// 插入的 vlan port
logic [2:0] vlan_port_insert;
// 进行插入，同步置 1
logic insert_valid;
// 可以插入
logic insert_ready;

// 路由表满，此后只可以查询和修改
logic overflow;

// 用于读取测例数据
int file_descriptor;
bit[127:0] buffer;

// 等待 lookup_insert_ready 变回 1
task wait_till_ready;
begin
    do
        @ (posedge clk_125M);
    while (!insert_ready);
end
endtask

task wait_for_lookup_output;
begin
    do
        @ (posedge clk_125M);
    while (!query_ready);
end
endtask

// 在路由表中插入一条。测例保证不会有地址、掩码一样的条目
task insert;
    input bit[31:0] addr;       // 插入地址
    input bit[7:0] mask_len;    // 掩码长度
    input bit[31:0] nexthop;    // 下一跳地址
begin
    int start = $realtime;
    $display("insert %0d.%0d.%0d.%0d/%0d -> %0d.%0d.%0d.%0d",
        addr[31:24], addr[23:16], addr[15:8], addr[7:0], mask_len,
        nexthop[31:24], nexthop[23:16], nexthop[15:8], nexthop[7:0]);
    // 拷贝的之前代码
    insert_valid <= 1;
    ip_insert <= addr;
    nexthop_insert <= nexthop;
    mask_insert <= mask_len;
    @ (posedge clk_125M);
    insert_valid <= 0;
    wait_till_ready();
    $display("\t\tdone in %0t", $realtime - start);
end
endtask

// 在路由表中进行查询，如果结果和预期结果不同会报错
task query;
    input bit[31:0] addr;           // 查询地址
    input bit[31:0] expect_nexthop; // 预期匹配的 nexthop，没有匹配则为 0
begin
    int start = $realtime;
    $write("query  %0d.%0d.%0d.%0d",
        addr[31:24], addr[23:16], addr[15:8], addr[7:0]);
    // 拷贝的之前代码
    query_valid <= 1;
    ip_query <= addr;
    @ (posedge clk_125M);
    query_valid <= 0;
    wait_for_lookup_output();
    $display(" -> %0d.%0d.%0d.%0d", 
        nexthop_result[31:24], nexthop_result[23:16], nexthop_result[15:8], nexthop_result[7:0]);
    if (nexthop_result == expect_nexthop)
        $display("\t\tcorrect in %0t", $realtime - start);
    else
        $display("\t\tWRONG! Expecting %0d.%0d.%0d.%0d",
            expect_nexthop[31:24], expect_nexthop[23:16], expect_nexthop[15:8], expect_nexthop[7:0]);
end
endtask

// 根据输入数据进行插入/查询
task run_test_entry;
    bit finished;
    integer count;
begin
    finished = 0;
    count = 0;
    file_descriptor = $fopen("routing_test.mem", "r");
    while (!finished) begin
        $fscanf(file_descriptor, "%s", buffer);
        unique casez (buffer[47:0])
            "insert": begin
                // insert
                count += 1;
                $write("%4d.\t", count);
                $fscanf(file_descriptor, "%d.%d.%d.%d/%d -> %d.%d.%d.%d",
                    buffer[31:24], buffer[23:16], buffer[15:8], buffer[7:0], 
                    buffer[39:32], 
                    buffer[71:64], buffer[63:56], buffer[55:48], buffer[47:40]);
                insert(buffer[31:0], buffer[39:32], buffer[71:40]);
            end
            {8'h??, "query"}: begin
                // query
                count += 1;
                $write("%4d.\t", count);
                $fscanf(file_descriptor, "%d.%d.%d.%d -> %d.%d.%d.%d", 
                    buffer[31:24], buffer[23:16], buffer[15:8], buffer[7:0],
                    buffer[71:64], buffer[63:56], buffer[55:48], buffer[47:40]);
                query(buffer[31:0], buffer[71:40]);
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
    $timeformat(-9, 0, " ns", 12);
    clk_125M = 0;
    rst_n = 0;
    query_valid = 0;
    insert_valid = 0;
    #100
    rst_n = 1;

    @ (posedge clk_125M);
    run_test_entry();
end

always clk_125M = #4 ~clk_125M;

routing_table routing_table_inst (
    .*
);

endmodule