`timescale 1ns / 1ps

module tb_itch_top;

    logic        clk = 0;
    logic        rst_n;
    wire  [7:0]  s_data;
    logic        s_valid;
    logic        s_ready;

    wire  [7:0]  m_data;
    wire         m_valid;
    wire  [7:0]  m_type;
    wire  [15:0] m_idx;
    wire         m_eop;

    wire  [7:0]  d_msg_type;
    wire  [15:0] d_stock_locate;
    wire  [15:0] d_tracking_num;
    wire  [47:0] d_timestamp;
    wire  [63:0] d_order_ref;
    wire  [7:0]  d_buy_sell;
    wire  [31:0] d_shares;
    wire  [63:0] d_stock;
    wire  [31:0] d_price;
    wire         d_valid;

    itch_framer u_framer (
        .clk(clk), .rst_n(rst_n),
        .s_data(s_data), .s_valid(s_valid), .s_ready(s_ready),
        .m_data(m_data), .m_valid(m_valid),
        .m_type(m_type), .m_idx(m_idx), .m_eop(m_eop)
    );

    itch_decoder u_decoder (
        .clk(clk), .rst_n(rst_n),
        .m_data(m_data), .m_valid(m_valid),
        .m_type(m_type), .m_idx(m_idx), .m_eop(m_eop),
        .d_msg_type(d_msg_type),
        .d_stock_locate(d_stock_locate),
        .d_tracking_num(d_tracking_num),
        .d_timestamp(d_timestamp),
        .d_order_ref(d_order_ref),
        .d_buy_sell(d_buy_sell),
        .d_shares(d_shares),
        .d_stock(d_stock),
        .d_price(d_price),
        .d_valid(d_valid)
    );

    always #5 clk = ~clk;

    localparam int NBYTES = 1900;
    localparam int NMSGS  = 50;

    logic [7:0] stim [0:NBYTES-1];

    longint unsigned e_type      [0:NMSGS-1];
    longint unsigned e_locate    [0:NMSGS-1];
    longint unsigned e_tracking  [0:NMSGS-1];
    longint unsigned e_timestamp [0:NMSGS-1];
    longint unsigned e_orderref  [0:NMSGS-1];
    longint unsigned e_buysell   [0:NMSGS-1];
    longint unsigned e_shares    [0:NMSGS-1];
    longint unsigned e_stock     [0:NMSGS-1];
    longint unsigned e_price     [0:NMSGS-1];

    int unsigned send_ptr  = 0;
    int unsigned nxt_ptr   = 0;
    int unsigned errors    = 0;
    int unsigned msg_count = 0;

    assign s_data = (send_ptr < NBYTES) ? stim[send_ptr] : 8'h00;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s_valid  <= 1'b0;
            send_ptr <= 0;
        end else begin
            nxt_ptr  = (s_valid && s_ready) ? send_ptr + 1 : send_ptr;
            send_ptr <= nxt_ptr;
            s_valid  <= (nxt_ptr < NBYTES) ? ($urandom_range(0,9) < 8) : 1'b0;
        end
    end

    task automatic chk(input string nm, input longint unsigned got,
                       input longint unsigned exp);
        if (got !== exp) begin
            $display("ERROR msg %0d  %s: got %0d, expected %0d",
                     msg_count, nm, got, exp);
            errors = errors + 1;
        end
    endtask

    always_ff @(posedge clk) begin
        if (rst_n && d_valid) begin
            if (msg_count < NMSGS) begin
                chk("msg_type",  d_msg_type,     e_type[msg_count]);
                chk("locate",    d_stock_locate, e_locate[msg_count]);
                chk("tracking",  d_tracking_num, e_tracking[msg_count]);
                chk("timestamp", d_timestamp,    e_timestamp[msg_count]);
                chk("order_ref", d_order_ref,    e_orderref[msg_count]);
                chk("buy_sell",  d_buy_sell,     e_buysell[msg_count]);
                chk("shares",    d_shares,       e_shares[msg_count]);
                chk("stock",     d_stock,        e_stock[msg_count]);
                chk("price",     d_price,        e_price[msg_count]);
            end
            msg_count = msg_count + 1;
        end
    end

    int fd, code, i;

    initial begin
        $dumpfile("top.vcd");
        $dumpvars(0, tb_itch_top);
        $readmemh("vectors/stimulus.hex", stim);

        fd = $fopen("vectors/expected.txt", "r");
        if (fd == 0) begin
            $display("FATAL: cannot open vectors/expected.txt");
            $finish;
        end
        for (i = 0; i < NMSGS; i = i + 1) begin
            code = $fscanf(fd, "%d %d %d %d %d %d %d %h %d\n",
                           e_type[i], e_locate[i], e_tracking[i],
                           e_timestamp[i], e_orderref[i], e_buysell[i],
                           e_shares[i], e_stock[i], e_price[i]);
            if (code != 9) begin
                $display("FATAL: expected.txt line %0d parsed %0d/9 fields", i+1, code);
                $finish;
            end
        end
        $fclose(fd);

        rst_n = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;

        wait (send_ptr >= NBYTES);
        repeat (40) @(posedge clk);

        $display("--------------------------------------------");
        $display("messages decoded : %0d (expected %0d)", msg_count, NMSGS);
        $display("field errors     : %0d", errors);
        if (errors == 0 && msg_count == NMSGS) $display("RESULT: PASS");
        else                                    $display("RESULT: FAIL");
        $display("--------------------------------------------");
        $finish;
    end

endmodule