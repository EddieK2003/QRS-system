`timescale 1ns/1ps

module HRC_tb;

    // Parameters
    parameter CLK_FREQ = 10000000; // 10 MHz

    // Signals
    reg clk;
    reg rst;
    reg r_peak;
    wire [7:0] heart_rate;

    // Instantiate DUT
    HRC_module #(
        .CLK_FREQ(CLK_FREQ)
    ) dut (
        .clk(clk),
        .rst(rst),
        .r_peak(r_peak),
        .heart_rate(heart_rate)
    );

    // Clock generation (10 MHz → 100 ns period)
    initial clk = 0;
    always #50 clk = ~clk;

    // Task to generate R-peak pulse
    task generate_r_peak;
    begin
        @(posedge clk);
        r_peak = 1;
        @(posedge clk);
        r_peak = 0;
    end
    endtask

    // Stimulus
    initial begin
        $display("Starting Heart Rate Calculator Testbench");
        rst = 1;
        r_peak = 0;
        #200;
        rst = 0;

        // ~60 BPM (1 sec interval)
        repeat (3) begin
            #(1000000000);
            generate_r_peak;
        end

        // ~120 BPM (0.5 sec interval)
        repeat (3) begin
            #(500000000);
            generate_r_peak;
        end

        // ~30 BPM (2 sec interval)
        repeat (2) begin
            #(2000000000);
            generate_r_peak;
        end

        #1000;
        $display("Testbench Finished");
        $finish;
    end

    // Dump waves (standard VCD instead of FSDB for portability)
    initial begin
        $fsdbDumpfile("simv_out/novas.fsdb");
        $fsdbDumpvars(0, HRC_tb);
    end

    // Monitor outputs
    initial begin
        $monitor("Time=%0t | r_peak=%b | heart_rate=%d BPM",
                  $time, r_peak, heart_rate);
    end

endmodule