`timescale 1ns / 1ps

`include "constants.vh"
`include "debug.vh"
`include "types.vh"

module testbench_routing_table();

logic clk_125M, rst_n;
time_t second = 0;
integer count = 0;

// 需要查询的 IP 地址
ip_t  ip_query;
// 进行查询，同步置 1
logic query_valid;
// 查询结果，0 表示无连接
ip_t  nexthop_result;
// 可以查询
logic query_ready;

// 从文件里面读存到 fifo 里面
routing_entry_t fifo_in;
logic fifo_write_valid = 0;

// 从 fifo 给路由表
routing_entry_t fifo_out;
logic fifo_empty, fifo_read_valid;

// 一个 fifo 输出直接给路由表模块
xpm_fifo_sync #(
    .FIFO_MEMORY_TYPE("distributed"),
    .FIFO_READ_LATENCY(0),
    .FIFO_WRITE_DEPTH(64),
    .READ_DATA_WIDTH($bits(routing_entry_t)),
    .READ_MODE("fwft"),
    .USE_ADV_FEATURES("0000"),
    .WRITE_DATA_WIDTH($bits(routing_entry_t))
) routing_insert_fifo (
    .din(fifo_in),
    .dout(fifo_out),
    .empty(fifo_empty),
    .injectdbiterr('0),
    .injectsbiterr('0),
    .rd_en(fifo_read_valid),
    .rst('0),
    .sleep('0),
    .wr_clk(clk_125M),
    .wr_en(fifo_write_valid)
);

// 路由表满，此后只可以查询和修改
logic overflow;

// 用于读取测例数据
int file_descriptor;
bit[127:0] buffer;

// 在路由表中插入一条。测例保证不会有地址、掩码一样的条目
task insert;
    input ip_t addr;            // 插入地址
    input ip_t nexthop;         // 下一跳
    input bit[5:0] mask_len;    // 掩码长度
    input bit[4:0] metric;      // 下一跳地址
    input bit[2:0] from_vlan;   // vlan
begin
    int start = $realtime;
    $display("%0d. insert %0d.%0d.%0d.%0d/%0d -> %0d.%0d.%0d.%0d (%0d, %0d)", count,
        addr[31:24], addr[23:16], addr[15:8], addr[7:0], mask_len,
        nexthop[31:24], nexthop[23:16], nexthop[15:8], nexthop[7:0], metric, from_vlan);
    fifo_in.prefix <= addr;
    fifo_in.nexthop <= nexthop;
    fifo_in.mask <= mask_len;
    fifo_in.metric <= metric;
    fifo_in.from_vlan <= from_vlan;
    fifo_write_valid <= 1;
    @ (posedge clk_125M);
    fifo_write_valid <= 0;
end
endtask

// 在路由表中进行查询，如果结果和预期结果不同会报错
task query;
    input ip_t addr;           // 查询地址
    input ip_t expect_nexthop; // 预期匹配的 nexthop，没有匹配则为 0
begin
    int start = $realtime;
    wait(query_ready == 1);
    $display("%0d. query  %0d.%0d.%0d.%0d", count,
        addr[31:24], addr[23:16], addr[15:8], addr[7:0]);
    query_valid <= 1;
    ip_query <= addr;
    @ (posedge clk_125M);
    query_valid <= 0;
    wait(query_ready == 0); // 开始查询
    wait(query_ready == 1); // 结束查询
    $display(" -> %0d.%0d.%0d.%0d", 
        nexthop_result[31:24], nexthop_result[23:16], nexthop_result[15:8], nexthop_result[7:0]);
    if (nexthop_result == expect_nexthop)
        $display("\t\tcorrect in %0t", $realtime - start);
    else
        $fatal(0, "\t\tWRONG! Expecting %0d.%0d.%0d.%0d",
            expect_nexthop[31:24], expect_nexthop[23:16], expect_nexthop[15:8], expect_nexthop[7:0]);
end
endtask

// 根据输入数据进行插入/查询
task run_test_entry;
    bit finished;
begin
    finished = 0;
    file_descriptor = $fopen("routing_test.mem", "r");
    while (!finished) begin
        #100;
        $fscanf(file_descriptor, "%s", buffer);
        unique casez (buffer[47:0])
            "insert": begin
                // insert
                count += 1;
                $fscanf(file_descriptor, "%d.%d.%d.%d/%d -> %d.%d.%d.%d/32 (%d, %d)",
                    buffer[31:24], buffer[23:16], buffer[15:8], buffer[7:0], // ip
                    buffer[37:32], // mask
                    buffer[71:64], buffer[63:56], buffer[55:48], buffer[47:40], // nexthop
                    buffer[76:72], // metric
                    buffer[79:77]); // from_vlan
                insert(buffer[31:0], buffer[71:40], buffer[37:32], buffer[76:72], buffer[79:77]);
            end
            {8'h??, "query"}: begin
                // query
                count += 1;
                $fscanf(file_descriptor, "%d.%d.%d.%d/32 -> %d.%d.%d.%d/32",
                    buffer[31:24], buffer[23:16], buffer[15:8], buffer[7:0], // ip
                    buffer[71:64], buffer[63:56], buffer[55:48], buffer[47:40]); // nexthop
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
    #100
    rst_n = 1;
    #1000

    @ (posedge clk_125M);
    run_test_entry();
end

always clk_125M = #4 ~clk_125M;

routing_table routing_table_inst (
    .clk_125M(clk_125M),
    .rst_n(rst_n),
    .second(second),

    // ignore digit*_out and debug

    .ip_query(ip_query),
    .query_valid(query_valid),
    .nexthop_result(nexthop_result),
    .query_ready(query_ready),

    .insert_fifo_data(fifo_out),
    .insert_fifo_empty(fifo_empty),
    .insert_fifo_read_valid(fifo_read_valid),

    .overflow(overflow)
);

endmodule