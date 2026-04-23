// 8N1 UART transmitter — 115200 baud at 10 MHz default
module uart_tx #(
    parameter CLK_FREQ = 10_000_000,
    parameter BAUD     = 115200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] tx_data,
    input  wire       tx_valid,
    output reg        tx_ready,
    output reg        tx
);

localparam BAUD_DIV = CLK_FREQ / BAUD;

localparam IDLE  = 1'b0;
localparam TXING = 1'b1;

reg        state;
reg [6:0]  baud_cnt;
reg [9:0]  shift_reg;
reg [3:0]  bit_cnt;

always @(posedge clk) begin
    if (rst) begin
        state     <= IDLE;
        tx        <= 1'b1;
        tx_ready  <= 1'b1;
        baud_cnt  <= 7'd0;
        bit_cnt   <= 4'd0;
        shift_reg <= 10'd0;
    end else begin
        case (state)
            IDLE: begin
                tx       <= 1'b1;
                tx_ready <= 1'b1;
                if (tx_valid) begin
                    shift_reg <= {1'b1, tx_data, 1'b0}; // {stop, data, start}
                    bit_cnt   <= 4'd0;
                    baud_cnt  <= 7'd0;
                    tx_ready  <= 1'b0;
                    state     <= TXING;
                end
            end

            TXING: begin
                tx <= shift_reg[0];
                if (baud_cnt == BAUD_DIV - 1) begin
                    baud_cnt  <= 7'd0;
                    shift_reg <= {1'b1, shift_reg[9:1]};
                    bit_cnt   <= bit_cnt + 4'd1;
                    if (bit_cnt == 4'd9) begin
                        state    <= IDLE;
                        tx_ready <= 1'b1;
                    end
                end else begin
                    baud_cnt <= baud_cnt + 7'd1;
                end
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule
