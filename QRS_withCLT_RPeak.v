// CLT-based QRS detector; pulses r_peak_flag on detected R-peak
module QRS (
    input  wire              clk,
    input  wire              rst,
    input  wire              sample_valid,
    input  wire signed [31:0] Yin,
    input  wire        [10:0] i,
    output reg                r_peak_flag,
    output reg         [10:0] r_index_out,
    output reg  signed [31:0] r_value_out
);

reg  signed [31:0] mem [0:31];
reg  signed [31:0] ps;
reg  signed [31:0] clt_out;
reg  signed [31:0] prev_s, curr_s, next_s;
reg  signed [31:0] threshold;

wire signed [31:0] abs_diff_now =
    (mem[i[4:0]] > mem[(i-11'd1) & 11'd31]) ?
    (mem[i[4:0]] - mem[(i-11'd1) & 11'd31]) :
    (mem[(i-11'd1) & 11'd31] - mem[i[4:0]]);

wire signed [31:0] abs_diff_old =
    (mem[(i-11'd30) & 11'd31] > mem[(i-11'd31) & 11'd31]) ?
    (mem[(i-11'd30) & 11'd31] - mem[(i-11'd31) & 11'd31]) :
    (mem[(i-11'd31) & 11'd31] - mem[(i-11'd30) & 11'd31]);

wire signed [31:0] x2 = 32'sd2 + (abs_diff_now <<< 2);
wire signed [31:0] x4 = 32'sd2 + (abs_diff_old <<< 2);
wire signed [31:0] ns = (i > 11'd31) ? (ps + x2 - x4) : (ps + x2);

integer k;

always @(posedge clk) begin
    if (rst) begin
        for (k = 0; k < 32; k = k + 1) mem[k] <= 32'sd0;
        ps          <= 32'sd0;
        clt_out     <= 32'sd0;
        prev_s      <= 32'sd0;
        curr_s      <= 32'sd0;
        next_s      <= 32'sd0;
        threshold   <= 32'sd50;
        r_peak_flag <= 1'b0;
        r_index_out <= 11'd0;
        r_value_out <= 32'sd0;
    end else begin
        r_peak_flag <= 1'b0;
        if (sample_valid) begin
            mem[i[4:0]] <= Yin;
            ps          <= ns;
            clt_out     <= ns;
            prev_s      <= curr_s;
            curr_s      <= next_s;
            next_s      <= clt_out;
            if ((curr_s > prev_s) && (curr_s > next_s) && (curr_s > threshold)) begin
                r_peak_flag <= 1'b1;
                r_index_out <= i - 11'd1;
                r_value_out <= curr_s;
            end
        end
    end
end

endmodule
