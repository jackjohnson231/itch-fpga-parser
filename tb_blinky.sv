// tb_blinky.sv - testbench for blinky.
// Generates a clock, applies reset, runs the counter, dumps a VCD for GTKWave,
// and does a tiny self-check so you get a PASS/FAIL, not just a waveform.

`timescale 1ns/1ps

module tb_blinky;

    localparam int WIDTH = 4;

    logic             clk;
    logic             rst_n;
    logic [WIDTH-1:0] count;
    logic             led;

    // Instantiate the device under test (DUT).
    blinky #(.WIDTH(WIDTH)) dut (
        .clk   (clk),
        .rst_n (rst_n),
        .count (count),
        .led   (led)
    );

    // Clock: toggle every 5 ns => 10 ns period => 100 MHz.
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Waveform dump for GTKWave.
    initial begin
        $dumpfile("blinky.vcd");   // output file GTKWave opens
        $dumpvars(0, tb_blinky);   // dump all signals in this scope + below
    end

    // Stimulus + self-check.
    integer errors = 0;
    initial begin
        rst_n = 1'b0;              // assert reset
        @(posedge clk);            // one edge with reset asserted
        #1;                        // settle just after the edge
        if (count !== 4'd0) begin
            $display("FAIL: after reset expected count=0, got %0d", count);
            errors = errors + 1;
        end

        rst_n = 1'b1;              // release reset (takes effect next edge)

        // Now count should climb 0 -> 1 -> 2 -> 3 -> 4 ... one per clock.
        // Sample just after each edge (#1) so we read the settled value.
        for (int i = 1; i <= 5; i++) begin
            @(posedge clk);
            #1;
            if (count !== i[WIDTH-1:0]) begin
                $display("FAIL: after %0d clocks expected count=%0d, got %0d", i, i, count);
                errors = errors + 1;
            end else begin
                $display("PASS: count=%0d after %0d clock(s)", count, i);
            end
        end

        // Let it run a bit so you can see the LED bit blink in the waveform.
        repeat (40) @(posedge clk);

        if (errors == 0) $display("ALL CHECKS PASSED");
        else             $display("%0d CHECK(S) FAILED", errors);

        $finish;
    end

endmodule
