// Caravel user project wrapper — ECG monitor
// io[0]=UART TX  io[1]=SPI CS_N  io[2]=SPI SCLK  io[3]=SPI MOSI  io[4]=SPI MISO
`default_nettype none

module user_project_wrapper #(
    parameter BITS = 32
)(
`ifdef USE_POWER_PINS
    inout vccd1, inout vssd1,
    inout vccd2, inout vssd2,
`endif
    input  wire         wb_clk_i,
    input  wire         wb_rst_i,
    input  wire         wbs_stb_i,
    input  wire         wbs_cyc_i,
    input  wire         wbs_we_i,
    input  wire [3:0]   wbs_sel_i,
    input  wire [31:0]  wbs_dat_i,
    input  wire [31:0]  wbs_adr_i,
    output wire         wbs_ack_o,
    output wire [31:0]  wbs_dat_o,
    input  wire [127:0] la_data_in,
    output wire [127:0] la_data_out,
    input  wire [127:0] la_oenb,
    inout  wire [37:0]  io_in,
    output wire [37:0]  io_out,
    output wire [37:0]  io_oeb,
    output wire [2:0]   irq
);

assign la_data_out = 128'd0;
assign irq         = 3'd0;

// Pad direction: 0=output 1=input
assign io_oeb[0]    = 1'b0;
assign io_oeb[1]    = 1'b0;
assign io_oeb[2]    = 1'b0;
assign io_oeb[3]    = 1'b0;
assign io_oeb[4]    = 1'b1;
assign io_oeb[37:5] = {33{1'b1}};
assign io_out[37:5] = {33{1'b0}};

// Pipeline wires
wire        sample_tick;
wire [11:0] adc_data;
wire        adc_valid;
wire [11:0] sampler_out;
wire        sampler_valid;
wire        sampler_dropped;
wire        sampler_adc_ready;

wire signed [31:0] filt_in;
wire signed [31:0] filt_out;
wire               filt_valid;

wire [11:0]        fifo_din;
wire [11:0]        fifo_dout;
wire               fifo_full;
wire               fifo_empty;
wire               fifo_overflow;

wire               peak_valid;
wire [10:0]        r_idx;
wire signed [31:0] r_val;

wire [7:0]         heart_rate;
wire               hr_valid;

wire               uart_tx_ready;
wire               uart_tx_valid;
wire [7:0]         uart_tx_data;

// QRS sample index counter (advances with filt_valid)
reg [10:0] qrs_idx;
always @(posedge wb_clk_i) begin
    if (wb_rst_i)        qrs_idx <= 11'd0;
    else if (filt_valid) qrs_idx <= qrs_idx + 11'd1;
end

// 12-bit unsigned MCP3204 code → signed zero-centered 32-bit
assign filt_in = $signed({20'd0, sampler_out}) - 32'sd2048;

// Sideband FIFO stores raw 12-bit samples for mgmt-core debug
assign fifo_din = sampler_out;

clock_divider #(.CLK_FREQ(10_000_000), .SAMPLE_RATE(500)) u_clkdiv (
    .clk(wb_clk_i), .rst(wb_rst_i),
    .sample_tick(sample_tick)
);

spi_adc_interface u_adc (
    .clk(wb_clk_i),  .rst(wb_rst_i),
    .sample_tick(sample_tick),
    .spi_cs_n(io_out[1]), .spi_sclk(io_out[2]),
    .spi_mosi(io_out[3]), .spi_miso(io_in[4]),
    .adc_data(adc_data),  .adc_valid(adc_valid)
);

// sample_tick tied high: SPI ADC already runs at sample rate
ecg_sampler #(.DATA_WIDTH(12)) u_sampler (
    .clk(wb_clk_i),           .rst(wb_rst_i),
    .sample_tick(1'b1),
    .adc_data(adc_data),      .adc_valid(adc_valid),
    .adc_ready(sampler_adc_ready),
    .sample_out(sampler_out),
    .sample_valid(sampler_valid),
    .sample_ready(1'b1),
    .sample_dropped(sampler_dropped)
);

digital_filter u_filter (
    .clk(wb_clk_i),           .rst(wb_rst_i),
    .sample_valid(sampler_valid),
    .sample_in(filt_in),
    .out_valid(filt_valid),
    .sample_out(filt_out)
);

// Self-draining raw-sample buffer; overflow flag only asserts on true backpressure
fifo_buffer #(.DATA_WIDTH(12), .DEPTH(64)) u_fifo (
    .clk(wb_clk_i),           .rst(wb_rst_i),
    .wr_en(sampler_valid),    .din(fifo_din),
    .rd_en(~fifo_empty),      .dout(fifo_dout),
    .full(fifo_full),         .empty(fifo_empty),
    .overflow(fifo_overflow)
);

QRS u_qrs (
    .clk(wb_clk_i),           .rst(wb_rst_i),
    .sample_valid(filt_valid),
    .Yin(filt_out),           .i(qrs_idx),
    .r_peak_flag(peak_valid),
    .r_index_out(r_idx),      .r_value_out(r_val)
);

HRC_module #(.SAMPLE_RATE(500)) u_hrc (
    .clk(wb_clk_i),           .rst(wb_rst_i),
    .sample_tick(sample_tick),
    .r_peak_flag(peak_valid),
    .heart_rate(heart_rate),
    .hr_valid(hr_valid)
);

wishbone_regs #(.BASE_ADDR(32'h3000_0000)) u_wbregs (
    .wb_clk_i(wb_clk_i),      .wb_rst_i(wb_rst_i),
    .wbs_stb_i(wbs_stb_i),    .wbs_cyc_i(wbs_cyc_i),
    .wbs_we_i(wbs_we_i),      .wbs_sel_i(wbs_sel_i),
    .wbs_dat_i(wbs_dat_i),    .wbs_adr_i(wbs_adr_i),
    .wbs_ack_o(wbs_ack_o),    .wbs_dat_o(wbs_dat_o),
    .hr_valid(hr_valid),      .peak_valid(peak_valid),
    .sample_dropped(sampler_dropped | fifo_overflow),
    .heart_rate(heart_rate),
    .r_val(r_val),            .r_idx(r_idx)
);

uart_framer u_framer (
    .clk(wb_clk_i),           .rst(wb_rst_i),
    .hr_valid(hr_valid),
    .heart_rate(heart_rate),
    .r_val(r_val[15:0]),
    .tx_ready(uart_tx_ready),
    .tx_valid(uart_tx_valid),
    .tx_data(uart_tx_data)
);

uart_tx #(.CLK_FREQ(10_000_000), .BAUD(115200)) u_uart (
    .clk(wb_clk_i),           .rst(wb_rst_i),
    .tx_data(uart_tx_data),
    .tx_valid(uart_tx_valid),
    .tx_ready(uart_tx_ready),
    .tx(io_out[0])
);

// Unused pad outputs tied low
assign io_out[4] = 1'b0;

endmodule

`default_nettype wire
