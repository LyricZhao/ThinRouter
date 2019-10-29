`timescale 1ns / 1ps

`include "constants.vh"

module testbench_routing_table();

logic clk, rst;

logic [`IPV4_WIDTH-1:0] lookup_insert_addr;
logic lookup_valid;

logic insert_valid;
logic [`IPV4_WIDTH-1:0] insert_nexthop;
logic [`MASK_WIDTH-1:0] insert_mask_len;

wire lookup_insert_ready;
wire lookup_output_valid;
wire [`IPV4_WIDTH-1:0] lookup_output_nexthop;

// 用于读取测例数据
int file_descriptor;
bit[127:0] buffer;

// 等待 lookup_insert_ready 变回 1
task wait_till_ready;
begin
    do
        repeat (1) @ (posedge clk);
    while (!lookup_insert_ready);
end
endtask

task wait_for_lookup_output;
begin
    do
        repeat (1) @ (posedge clk);
    while (!lookup_output_valid);
end
endtask

// 在路由表中插入一条。测例保证不会有地址、掩码一样的条目
task insert;
    input bit[31:0] addr;       // 插入地址
    input bit[7:0] mask_len;    // 掩码长度
    input bit[31:0] nexthop;    // 下一跳地址
begin
    $display("%0t\tinsert %0d.%0d.%0d.%0d/%0d -> %0d.%0d.%0d.%0d", $realtime,
        addr[31:24], addr[23:16], addr[15:8], addr[7:0], mask_len,
        nexthop[31:24], nexthop[23:16], nexthop[15:8], nexthop[7:0]);
    // 拷贝的之前代码
    repeat (2) @ (posedge clk);
    insert_valid = 1;
    lookup_insert_addr = addr;
    insert_nexthop = nexthop;
    insert_mask_len = mask_len;
    repeat (1) @ (posedge clk);
    insert_valid = 0;
    wait_till_ready();
    $display("%0t\tinsert done", $realtime);
end
endtask

// 在路由表中进行查询，如果结果和预期结果不同会报错
task query;
    input bit[31:0] addr;           // 查询地址
    input bit[31:0] expect_nexthop; // 预期匹配的 nexthop，没有匹配则为 0
begin
    $display("%0t\tquery  %0d.%0d.%0d.%0d", $realtime,
        addr[31:24], addr[23:16], addr[15:8], addr[7:0]);
    // 拷贝的之前代码
    repeat (2) @ (posedge clk);
    lookup_valid <= 1;
    lookup_insert_addr <= addr;
    repeat (1) @ (posedge clk);
    lookup_valid <= 0;
    wait_for_lookup_output();
    $display("%0t\tget    %0d.%0d.%0d.%0d", $realtime, 
        lookup_output_nexthop[31:24], lookup_output_nexthop[23:16], lookup_output_nexthop[15:8], lookup_output_nexthop[7:0]);
    if (lookup_output_nexthop == expect_nexthop)
        $display("correct");
    else
        $display("WRONG! Expecting %0d.%0d.%0d.%0d", 
            expect_nexthop[31:24], expect_nexthop[23:16], expect_nexthop[15:8], expect_nexthop[7:0]);
    wait_till_ready();
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
                $display("%0d.", count);
                $fscanf(file_descriptor, "%d.%d.%d.%d/%d -> %d.%d.%d.%d",
                    buffer[31:24], buffer[23:16], buffer[15:8], buffer[7:0], 
                    buffer[39:32], 
                    buffer[71:64], buffer[63:56], buffer[55:48], buffer[47:40]);
                insert(buffer[31:0], buffer[39:32], buffer[71:40]);
            end
            {8'h??, "query"}: begin
                // query
                count += 1;
                $display("%0d.", count);
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
    clk = 0;
    rst = 1;
    lookup_valid = 0;
    insert_valid = 0;
    lookup_insert_addr = 0;
    insert_nexthop = 0;
    insert_mask_len = 0;
    #100
    rst = 0;

    run_test_entry();
end

always clk = #10 ~clk;

routing_table routing_table_inst(
    .clk(clk),
    .rst(rst),

    .lookup_insert_addr(lookup_insert_addr),
    .lookup_valid(lookup_valid),

    .insert_valid(insert_valid),
    .insert_nexthop(insert_nexthop),
    .insert_mask_len(insert_mask_len),

    .lookup_insert_ready(lookup_insert_ready),
    .lookup_output_valid(lookup_output_valid),
    .lookup_output_nexthop(lookup_output_nexthop)
);

endmodule