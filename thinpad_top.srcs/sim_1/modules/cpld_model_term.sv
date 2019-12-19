`timescale 1ns / 1ps

module cpld_model_term(
    input  wire clk_uart,         //内部串口时钟
    input  wire uart_rdn,         //读串口信号，低有效
    input  wire uart_wrn,         //写串口信号，低有效
    output reg uart_dataready,    //串口数据准备好
    output reg uart_tbre,         //发送数据标志
    output reg uart_tsre,         //数据发送完毕标志
    inout  wire [7:0]data
);
    reg bus_analyze_clk = 0;
    reg clk_out2_rst_n = 0, bus_analyze_clk_rst_n = 0;
    wire clk_out2;

    reg [7:0] TxD_data,TxD_data0,TxD_data1;
    reg [2:0] cpld_emu_wrn_sync;
    reg [2:0] cpld_emu_rdn_sync;
    reg [7:0] uart_rx_data;
    wire uart_rx_flag;
    reg wrn_rise;

    assign data = uart_rdn ? 8'bz : uart_rx_data;
    assign #3 clk_out2 = clk_uart;

    initial begin
        uart_tsre = 1;
        uart_tbre = 1;
        uart_dataready = 0;
        repeat(2) @(negedge clk_out2);
        clk_out2_rst_n = 1;
        @(negedge bus_analyze_clk);
        bus_analyze_clk_rst_n = 1;
    end

    always #2 bus_analyze_clk = ~bus_analyze_clk;

    always @(posedge bus_analyze_clk) begin : proc_Tx
        TxD_data0 <= data[7:0];
        TxD_data1 <= TxD_data0;

        cpld_emu_rdn_sync <= {cpld_emu_rdn_sync[1:0],uart_rdn};
        cpld_emu_wrn_sync <= {cpld_emu_wrn_sync[1:0],uart_wrn};

        if(~cpld_emu_wrn_sync[1] & cpld_emu_wrn_sync[2])
            TxD_data <= TxD_data1;
        wrn_rise <= cpld_emu_wrn_sync[1] & ~cpld_emu_wrn_sync[2];
        
        if(~cpld_emu_rdn_sync[1] & cpld_emu_rdn_sync[2]) //rdn_fall
            uart_dataready <= 1'b0;
        else if(uart_rx_flag)
            uart_dataready <= 1'b1;
    end

    reg [7:0] TxD_data_sync;
    wire tx_en;
    reg rx_ack = 0;

    always @(posedge clk_out2) begin
        TxD_data_sync <= TxD_data;
    end

    always @(posedge clk_out2 or negedge uart_wrn) begin : proc_tbre
        if(~uart_wrn) begin
            uart_tbre <= 0;
        end else if(!uart_tsre) begin
            uart_tbre <= 1;
        end
    end

    flag_sync_cpld tx_flag(
        .clkA        (bus_analyze_clk),
        .clkB        (clk_out2),
        .FlagIn_clkA (wrn_rise),
        .FlagOut_clkB(tx_en),
        .a_rst_n     (bus_analyze_clk_rst_n),
        .b_rst_n     (clk_out2_rst_n)
    );

    flag_sync_cpld rx_flag(
        .clkA        (clk_out2),
        .clkB        (bus_analyze_clk),
        .FlagIn_clkA (rx_ack),
        .FlagOut_clkB(uart_rx_flag),
        .a_rst_n     (bus_analyze_clk_rst_n),
        .b_rst_n     (clk_out2_rst_n)
    );

    enum logic[3:0] {
        r_idle,
        r_t_hi, r_t_lo0, r_t_lo1,
        r_regs,
        r_d_num,
        r_g_start, r_g_end
    } recv_state;

    enum logic[3:0] {
        idle,
        a_addr, a_length, a_inst,
        t_entry,
        d_addr, d_num,
        g_addr
    } send_state;

    integer recv_length, recv_count;
    integer send_length;
    logic inited;
    logic[31:0] recv_word, send_word, recv_addr;

    initial begin
        {recv_length, send_length, recv_state, send_state, inited} = 0;
    end

    always begin
        wait(tx_en == 1);
        repeat(2)
            @(posedge clk_out2);
        uart_tsre = 0;
        #100 // 实际串口发送时间更长，为了加快仿真，等待时间较短
        // $display("RECV: %02x", TxD_data_sync);
        case (recv_state)
            r_t_hi: begin
                recv_word = recv_word | (TxD_data_sync << (recv_length * 8));
                recv_length = recv_length + 1;
                if (recv_length == 4) begin
                    $display("RECV: HI (T): 0x%08x", TxD_data_sync);
                    recv_state = r_t_lo0;
                    recv_word = 0;
                    recv_length = 0;
                end
            end
            r_t_lo0: begin
                recv_word = recv_word | (TxD_data_sync << (recv_length * 8));
                recv_length = recv_length + 1;
                if (recv_length == 4) begin
                    $display("RECV: LO0 (T): 0x%08x", TxD_data_sync);
                    recv_state = r_t_lo1;
                    recv_word = 0;
                    recv_length = 0;
                end
            end
            r_t_lo1: begin
                recv_word = recv_word | (TxD_data_sync << (recv_length * 8));
                recv_length = recv_length + 1;
                if (recv_length == 4) begin
                    $display("RECV: LO1 (T): 0x%08x", TxD_data_sync);
                    recv_state = r_idle;
                    recv_word = 0;
                    recv_length = 0;
                end
            end
            r_regs: begin
                recv_word = recv_word | (TxD_data_sync << (recv_length * 8));
                recv_length = recv_length + 1;
                if (recv_length == 4) begin
                    $display("RECV: R%d (R): 0x%08x", 32 - recv_count, TxD_data_sync);
                    recv_count = recv_count - 1;
                    recv_state = recv_count == 0 ? r_idle : r_regs;
                    recv_word = 0;
                    recv_length = 0;
                end
            end
            r_d_num: begin
                recv_word = recv_word | (TxD_data_sync << (recv_length * 8));
                recv_length = recv_length + 1;
                if (recv_length == 4) begin
                    $display("RECV: (D) 0x%08x: 0x%08x", recv_addr, TxD_data_sync);
                    recv_count = recv_count - 1;
                    recv_addr = recv_addr + 4;
                    recv_state = recv_count == 0 ? r_idle : r_d_num;
                    recv_word = 0;
                    recv_length = 0;
                end
            end
            r_g_start: begin
                if (TxD_data_sync == 'h80) begin
                    $display("RECV: (G) Trap at start");
                    recv_state = r_idle;
                end else if (TxD_data_sync == 'h06) begin
                    $display("RECV: (G) Start running");
                    recv_state = r_g_end;
                end else begin
                    $display("RECV: (G) Invalid start (BUG)");
                    recv_state = r_idle;
                end
            end
            r_g_end: begin
                if (TxD_data_sync == 'h80) begin
                    $display("RECV: (G) Trap at end");
                    recv_state = r_idle;
                end else if (TxD_data_sync == 'h07) begin
                    $display("RECV: (G) End running");
                    recv_state = r_idle;
                end else begin
                    $display("RECV: Running (G): %02x (%c)", TxD_data_sync, TxD_data_sync);
                    recv_state = r_g_end;
                end
            end
            default: begin
                if (!inited) begin
                    $display("RECV: %02x (%c)", TxD_data_sync, TxD_data_sync);
                end else begin
                    $display("RECV: Invalid state (BUG)");
                end

                if (TxD_data_sync == ".") begin
                    inited = 1;
                end
            end
        endcase
        uart_tsre = 1;
    end

    // 指令间要隔一段时间
    task pc_send_byte;
    input [7:0] arg;
    begin
        wait(recv_state == r_idle);
        // $display("SEND: %02x", arg);
        case(send_state)
            idle: begin
                send_length = 0;
                send_word = 0;
                case(arg)
                    "A": begin
                        send_state = a_addr;
                        $display("SEND: Command A");
                    end
                    "T": begin
                        send_state = t_entry;
                        $display("SEND: Command T");
                    end
                    "D": begin
                        send_state = d_addr;
                        $display("SEND: Command D");
                    end
                    "R": begin
                        send_state = idle;
                        recv_state = r_regs;
                        recv_count = 30;
                        recv_length = 0;
                        recv_word = 0;
                        $display("SEND: Command R");
                    end
                    "G": begin
                        send_state = g_addr;
                        $display("SEND: Command G");
                    end
                    default: begin
                        $display("SEND: Invalid command");
                    end
                endcase
            end
            a_addr: begin
                send_word = send_word | (arg << (send_length * 8));
                send_length = send_length + 1;
                if (send_length == 4) begin
                    $display("SEND: Addr (A): 0x%08x", send_word);
                    send_state = a_length;
                    send_word = 0;
                    send_length = 0;
                end
            end
            a_length: begin
                send_word = send_word | (arg << (send_length * 8));
                send_length = send_length + 1;
                if (send_length == 4) begin
                    $display("SEND: Length (A): %d", send_word);
                    send_state = a_inst;
                    send_word = 0;
                    send_length = 0;
                end
            end
            a_inst: begin
                send_word = send_word | (arg << (send_length * 8));
                send_length = send_length + 1;
                if (send_length == 4) begin
                    $display("SEND: Inst (A): 0x%08x", send_word);
                    send_state = idle;
                    send_word = 0;
                    send_length = 0;
                end
            end
            t_entry: begin
                send_word = send_word | (arg << (send_length * 8));
                send_length = send_length + 1;
                if (send_length == 4) begin
                    $display("SEND: Entry (T): %d", send_word);
                    send_state = idle;
                    send_word = 0;
                    send_length = 0;
                    recv_state = r_t_hi;
                    recv_length = 0;
                    recv_word = 0;
                end
            end
            d_addr: begin
                send_word = send_word | (arg << (send_length * 8));
                send_length = send_length + 1;
                if (send_length == 4) begin
                    $display("SEND: Addr (D): 0x%08x", send_word);
                    recv_addr = send_word;
                    send_state = d_num;
                    send_word = 0;
                    send_length = 0;
                end
            end
            d_num: begin
                send_word = send_word | (arg << (send_length * 8));
                send_length = send_length + 1;
                if (send_length == 4) begin
                    $display("SEND: Num (D): %d", send_word);
                    send_state = idle;
                    send_word = 0;
                    send_length = 0;
                    recv_state = r_d_num;
                    recv_count = send_word;
                    recv_length = 0;
                    recv_word = 0;
                end
            end
            g_addr: begin
                send_word = send_word | (arg << (send_length * 8));
                send_length = send_length + 1;
                if (send_length == 4) begin
                    $display("SEND: Addr (G): 0x%08x", send_word);
                    send_state = idle;
                    send_word = 0;
                    send_length = 0;
                    recv_state = r_g_start;
                end
            end
            default: begin
                $display("SEND: Invalid state. (BUG)");
            end
        endcase

        uart_rx_data = arg;
        @(negedge clk_out2);
        rx_ack = 1;
        @(negedge clk_out2);
        rx_ack = 0;
    end
    endtask
endmodule
