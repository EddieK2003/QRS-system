module HRC_module #(
    parameter CLK_FREQ = 1000
)(
    input clk,
    input rst,
    input r_peak,
    output reg [7:0] heart_rate
);

reg [31:0] counter;
reg [31:0] last_interval;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        counter <= 0;
        heart_rate <= 0;
        last_interval <= 0;
    end else begin
        counter <= counter + 1;

        if (r_peak) begin
            last_interval <= counter;
            counter <= 0;

            if (last_interval != 0)
                heart_rate <= (60 * CLK_FREQ) / last_interval;
        end
    end
end

endmodule