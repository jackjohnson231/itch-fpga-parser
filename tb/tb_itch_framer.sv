`timescale 1ns / 1ps

module tb_itch_framer;

    logic        clk = 0;
    logic        rst_n;
    wire  [7:0]  s_data;
    logic        s_valid;
    logic        s_ready;
    logic [7:0]  m_data;
    logic        m_valid;
    logic [7:0]  m_type;
    logic [15:0] m_idx;
    logic        m_eop;

    itch_framer dut (
        .clk(clk), .rst_n(rst_n),
        .s_data(s_data), .s_valid(s_valid), .s_ready(s_ready),
        .m_data(m_data), .m_valid(m_valid),
        .m_type(m_type), .m_idx(m_idx), .m_eop(m_eop)
    );

    always #5 clk = ~clk;

    localparam int NBYTES = 1900;
    logic [7:0] stim [0:NBYTES-1];

    int unsigned send_ptr   = 0;
    int unsigned nxt_ptr    = 0;
    int unsigned errors     = 0;
    int unsigned msg_count  = 0;
    int unsigned expect_idx = 0;

    assign s_data = (send_ptr < NBYTES) ? stim[send_ptr] : 8'h00;

    // ---- stimulus driver: offers bytes, randomly stalls ~20% of cycles ----
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

    // ---- scoreboard ----
    // NOTE: the 34 below is last_idx for a 36-byte Add Order. When E/X/D/U
    // land, message lengths vary and this must be computed, not hardcoded.
    always_ff @(posedge clk) begin
        if (rst_n && m_valid) begin

            if (m_idx !== expect_idx) begin
                $display("ERROR t=%0t: idx got %0d, expected %0d", $time, m_idx, expect_idx);
                errors = errors + 1;
            end

            if (m_type !== 8'h41) begin
                $display("ERROR t=%0t: type got %02h, expected 41", $time, m_type);
                errors = errors + 1;
            end

            if (m_eop !== (m_idx == 16'd34)) begin
                $display("ERROR t=%0t: eop=%0b at idx %0d", $time, m_eop, m_idx);
                errors = errors + 1;
            end

            if (m_eop) begin
                msg_count  = msg_count + 1;
                expect_idx = 0;
            end else begin
                expect_idx = expect_idx + 1;
            end
        end
    end

    initial begin
        $dumpfile("framer.vcd");
        $dumpvars(0, tb_itch_framer);
        $readmemh("vectors/stimulus.hex", stim);

        rst_n = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;

        wait (send_ptr >= NBYTES);
        repeat (20) @(posedge clk);

        $display("--------------------------------------------");
        $display("messages seen : %0d (expected 50)", msg_count);
        $display("errors        : %0d", errors);
        if (errors == 0 && msg_count == 50) $display("RESULT: PASS");
        else                                 $display("RESULT: FAIL");
        $display("--------------------------------------------");
        $finish;
    end

endmodule