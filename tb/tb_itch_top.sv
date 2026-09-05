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

    // expected.txt columns, in order:
    // type  locate  tracking  timestamp  order_ref  buy_sell  shares  stock(hex)  price
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