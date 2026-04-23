// Heart-rate calc; counts samples between R-peaks and converts to BPM
module HRC_module #(
    parameter SAMPLE_RATE = 500
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       sample_tick,
    input  wire       r_peak_flag,
    output reg  [7:0] heart_rate,
    output reg        hr_valid
);

reg  [15:0] counter;
wire [23:0] bpm_full = (counter != 16'd0) ?
                       (24'd60 * SAMPLE_RATE) / counter : 24'd0;

always @(posedge clk) begin
    if (rst) begin
        counter    <= 16'd0;
        heart_rate <= 8'd0;
        hr_valid   <= 1'b0;
    end else begin
        hr_valid <= 1'b0;
        if (r_peak_flag) begin
            counter <= 16'd0;
            if (counter != 16'd0) begin
                heart_rate <= (bpm_full > 24'd255) ? 8'd255 : bpm_full[7:0];
                hr_valid   <= 1'b1;
            end
        end else if (sample_tick) begin
            counter <= counter + 1'b1;
        end
    end
end

endmodule
