`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// itch_decoder.sv
// Decodes ITCH 5.0 Add Order (type 'A') payload bytes into fields.
//
// Consumes the framer's payload stream. m_idx is 0 at the first byte AFTER
// the type byte, so every offset here is the gen_vectors.py FIELDS offset
// minus one.
//
// Bytes arrive most-significant first, so each field is assembled by shifting
// the register left one byte and dropping the new byte into the bottom.
// -----------------------------------------------------------------------------

module itch_decoder (
    input  logic        clk,
    input  logic        rst_n,

    // ---- from framer ----
    input  logic [7:0]  m_data,
    input  logic        m_valid,
    input  logic [7:0]  m_type,
    input  logic [15:0] m_idx,
    input  logic        m_eop,

    // ---- decoded Add Order fields ----
    output logic [7:0]  d_msg_type,
    output logic [15:0] d_stock_locate,
    output logic [15:0] d_tracking_num,
    output logic [47:0] d_timestamp,
    output logic [63:0] d_order_ref,
    output logic [7:0]  d_buy_sell,
    output logic [31:0] d_shares,
    output logic [63:0] d_stock,
    output logic [31:0] d_price,      // raw integer, 4 implied decimals
    output logic        d_valid       // one-cycle pulse: fields are complete
);

    logic is_add;
    assign is_add = (m_type == 8'h41);

    logic take;
    assign take = m_valid && is_add;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            d_stock_locate <= 16'd0;
            d_tracking_num <= 16'd0;
            d_timestamp    <= 48'd0;
            d_order_ref    <= 64'd0;
            d_buy_sell     <= 8'd0;
            d_shares       <= 32'd0;
            d_stock        <= 64'd0;
            d_price        <= 32'd0;
            d_msg_type     <= 8'd0;
        end else if (take) begin
            d_msg_type <= m_type;

            if (m_idx <= 16'd1)
                d_stock_locate <= {d_stock_locate[7:0], m_data};
            else if (m_idx <= 16'd3)
                d_tracking_num <= {d_tracking_num[7:0], m_data};
            else if (m_idx <= 16'd9)
                d_timestamp    <= {d_timestamp[39:0], m_data};
            else if (m_idx <= 16'd17)
                d_order_ref    <= {d_order_ref[55:0], m_data};
            else if (m_idx == 16'd18)
                d_buy_sell     <= m_data;
            else if (m_idx <= 16'd22)
                d_shares       <= {d_shares[23:0], m_data};
            else if (m_idx <= 16'd30)
                d_stock        <= {d_stock[55:0], m_data};
            else
                d_price        <= {d_price[23:0], m_data};
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) d_valid <= 1'b0;
        else        d_valid <= take && m_eop;
    end

endmodule