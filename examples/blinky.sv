// blinky.sv - a trivial synchronous counter.
// Purpose: confirm the edit -> simulate -> view-waveform loop works.
// The MSB of the counter "blinks" slowly, like an LED would on real hardware.

module blinky #(
    parameter int WIDTH = 4          // counter width; blink = top bit
)(
    input  logic             clk,    // clock
    input  logic             rst_n,  // active-low synchronous reset
    output logic [WIDTH-1:0] count,  // full counter value
    output logic             led     // "blink" = the counter's top bit
);

    always_ff @(posedge clk) begin
        if (!rst_n)
            count <= '0;             // reset clears the counter
        else
            count <= count + 1'b1;   // otherwise count up every clock
    end

    assign led = count[WIDTH-1];     // top bit toggles slowly => "blink"

endmodule
