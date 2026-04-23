// Emits {0xAA, heart_rate, r_val[15:8], r_val[7:0], 0x55} on hr_valid
module uart_framer (
    input  wire        clk,
    input  wire        rst,
    input  wire        hr_valid,
    input  wire [7:0]  heart_rate,
    input  wire [15:0] r_val,
    input  wire        tx_ready,
    output reg         tx_valid,
    output reg  [7:0]  tx_data
);

localparam IDLE = 2'd0;
localparam SEND = 2'd1;
localparam WAIT = 2'd2;

reg [1:0] state;
reg [2:0] idx;
reg [7:0] frame [0:4];

always @(posedge clk) begin
    if (rst) begin
        state    <= IDLE;
        idx      <= 3'd0;
        tx_valid <= 1'b0;
        tx_data  <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                tx_valid <= 1'b0;
                if (hr_valid) begin
                    frame[0] <= 8'hAA;
                    frame[1] <= heart_rate;
                    frame[2] <= r_val[15:8];
                    frame[3] <= r_val[7:0];
                    frame[4] <= 8'h55;
                    idx      <= 3'd0;
                    state    <= SEND;
                end
            end
            SEND: begin
                if (tx_ready) begin
                    tx_data  <= frame[idx];
                    tx_valid <= 1'b1;
                    state    <= WAIT;
                end
            end
            WAIT: begin
                tx_valid <= 1'b0;
                if (!tx_ready) begin
                    if (idx == 3'd4) state <= IDLE;
                    else begin
                        idx   <= idx + 3'd1;
                        state <= SEND;
                    end
                end
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule
