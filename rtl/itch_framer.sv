`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// itch_framer.sv
// Frames a raw byte stream into ITCH messages.
//
// Wire format: [len_hi][len_lo][type][payload ... ]
//   msg_len (the 2-byte big-endian header) counts the TYPE byte plus payload,
//   so payload length = msg_len - 1.
// -----------------------------------------------------------------------------

module itch_framer (
    input  logic        clk,
    input  logic        rst_n,       // active-low synchronous reset

    // ---- upstream: raw byte stream ----
    input  logic [7:0]  s_data,
    input  logic        s_valid,
    output logic        s_ready,

    // ---- downstream: framed payload bytes ----
    output logic [7:0]  m_data,      // payload byte
    output logic        m_valid,     // m_data is good this cycle
    output logic [7:0]  m_type,      // message type, held for whole message
    output logic [15:0] m_idx,       // payload byte index, 0 = first after type
    output logic        m_eop        // this is the last payload byte
);

    typedef enum logic [2:0] {
        LEN_HI  = 3'd0,
        LEN_LO  = 3'd1,
        TYPE    = 3'd2,
        PAYLOAD = 3'd3,
        DONE    = 3'd4
    } state_t;

    state_t state, next_state;

    logic [15:0] msg_len;    // full length from header
    logic [15:0] last_idx;   // index of final payload byte = msg_len - 2
    logic [15:0] idx;        // current payload byte index
    logic [7:0]  type_reg;

    // A byte moves only when both sides agree. This is THE handshake.
    logic byte_accepted;
    assign byte_accepted = s_valid && s_ready;


    // =========================================================================
    // BLOCK 1 - State register.  GIVEN. Memorize this shape.
    // =========================================================================
    always_ff @(posedge clk) begin
        if (!rst_n) state <= LEN_HI;
        else        state <= next_state;
    end


    // =========================================================================
    // BLOCK 2 - Next-state logic.  YOU WRITE THIS.
    // =========================================================================
    always_comb begin
    next_state = state;

    case (state)
        LEN_HI: begin
            if (byte_accepted) next_state = LEN_LO;
        end

        LEN_LO: begin
            if (byte_accepted) next_state = TYPE;
        end

        TYPE: begin
            if (byte_accepted) begin
                if (msg_len == 16'd1) next_state = DONE;
                else                  next_state = PAYLOAD;
            end
        end

        PAYLOAD: begin
            if (byte_accepted && (idx == last_idx)) next_state = DONE;
        end

        DONE: begin
            next_state = LEN_HI;
        end

        default: next_state = LEN_HI;
    endcase
end


    // =========================================================================
    // BLOCK 3 - Datapath registers.  YOU WRITE THIS (one example given).
    // =========================================================================
    always_ff @(posedge clk) begin
    if (!rst_n) begin
        msg_len  <= 16'd0;
        last_idx <= 16'd0;
        idx      <= 16'd0;
        type_reg <= 8'd0;
    end else begin
        case (state)

            LEN_HI: begin
                if (byte_accepted) msg_len[15:8] <= s_data;
            end

            LEN_LO: begin
                if (byte_accepted) begin
                    msg_len[7:0] <= s_data;
                    last_idx     <= {msg_len[15:8], s_data} - 16'd2;
                end
            end

            TYPE: begin
                if (byte_accepted) begin
                    type_reg <= s_data;
                    idx      <= 16'd0;
                end
            end

            PAYLOAD: begin
                if (byte_accepted) idx <= idx + 16'd1;
            end

            default: ;
        endcase
    end
end


    // =========================================================================
    // BLOCK 4 - Output logic.  YOU WRITE THIS.
    // =========================================================================
    always_comb begin
    s_ready = (state != DONE);

    m_data  = s_data;
    m_valid = (state == PAYLOAD) && byte_accepted;
    m_type  = type_reg;
    m_idx   = idx;
    m_eop   = m_valid && (idx == last_idx);
end

endmodule