// SPI Mode 0 master — reads one 12-bit sample per sample_tick (MCP3204 ch0)
module spi_adc_interface (
    input  wire        clk,
    input  wire        rst,
    input  wire        sample_tick,
    output reg         spi_cs_n,
    output reg         spi_sclk,
    output reg         spi_mosi,
    input  wire        spi_miso,
    output reg  [11:0] adc_data,
    output reg         adc_valid
);

localparam TOTAL_BITS = 16;
localparam [3:0] CMD  = 4'b1100; // start=1, SGL=1, ch=0

localparam IDLE   = 2'd0;
localparam ASSERT = 2'd1;
localparam SHIFT  = 2'd2;
localparam DONE   = 2'd3;

reg [1:0]  state;
reg [3:0]  bit_cnt;
reg [11:0] shift_reg;
reg [3:0]  cmd_reg;

always @(posedge clk) begin
    if (rst) begin
        state     <= IDLE;
        spi_cs_n  <= 1'b1;
        spi_sclk  <= 1'b0;
        spi_mosi  <= 1'b0;
        adc_valid <= 1'b0;
        adc_data  <= 12'd0;
        bit_cnt   <= 4'd0;
        shift_reg <= 12'd0;
        cmd_reg   <= 4'd0;
    end else begin
        adc_valid <= 1'b0;

        case (state)
            IDLE: begin
                spi_cs_n <= 1'b1;
                spi_sclk <= 1'b0;
                if (sample_tick) begin
                    cmd_reg <= CMD;
                    bit_cnt <= 4'd0;
                    state   <= ASSERT;
                end
            end

            ASSERT: begin
                spi_cs_n <= 1'b0;
                spi_mosi <= CMD[3];
                cmd_reg  <= {CMD[2:0], 1'b0};
                bit_cnt  <= 4'd0;
                state    <= SHIFT;
            end

            SHIFT: begin
                spi_sclk <= ~spi_sclk;
                if (spi_sclk == 1'b0) begin
                    if (bit_cnt >= 4'd4)
                        shift_reg <= {shift_reg[10:0], spi_miso};
                end else begin
                    if (bit_cnt < 4'd4) begin
                        spi_mosi <= cmd_reg[3];
                        cmd_reg  <= {cmd_reg[2:0], 1'b0};
                    end else begin
                        spi_mosi <= 1'b0;
                    end
                    bit_cnt <= bit_cnt + 4'd1;
                    if (bit_cnt == TOTAL_BITS - 1)
                        state <= DONE;
                end
            end

            DONE: begin
                spi_cs_n  <= 1'b1;
                spi_sclk  <= 1'b0;
                adc_data  <= shift_reg;
                adc_valid <= 1'b1;
                state     <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule
