module RPeakDetector (
    input  logic clk,
    input  logic rst,
    input  logic signed [31:0] clt_in,
    input  logic [10:0] i,


    output logic [10:0] r_index_out,
    output logic signed [31:0] r_value_out,
    output logic r_peak_flag
);


    logic signed [31:0] prev, curr, next;
    logic signed [31:0] threshold;


    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            prev <= 0;
            curr <= 0;
            next <= 0;
            r_peak_flag <= 0;
            r_index_out <= 0;
            r_value_out <= 0;
            threshold <= 50;  // adjust as needed
        end else begin
            // Shift samples
            prev <= curr;
            curr <= next;
            next <= clt_in;


            // Peak detection
            if ((curr > prev) && (curr > next) && (curr > threshold)) begin
                r_peak_flag <= 1;
                r_index_out <= i - 1;   // center sample
                r_value_out <= curr;
            end else begin
                r_peak_flag <= 0;
            end
        end
    end


endmodule
