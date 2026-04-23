// Wishbone slave — read-only ECG results
// 0x00 STATUS [2]=dropped [1]=peak_valid [0]=hr_valid
// 0x04 HEART_RATE [7:0]
// 0x08 R_VAL (signed)
// 0x0C R_IDX [10:0]
module wishbone_regs #(
    parameter [31:0] BASE_ADDR = 32'h3000_0000
)(
    input  wire        wb_clk_i,
    input  wire        wb_rst_i,
    input  wire        wbs_stb_i,
    input  wire        wbs_cyc_i,
    input  wire        wbs_we_i,
    input  wire [3:0]  wbs_sel_i,
    input  wire [31:0] wbs_dat_i,
    input  wire [31:0] wbs_adr_i,
    output reg         wbs_ack_o,
    output reg  [31:0] wbs_dat_o,
    input  wire        hr_valid,
    input  wire        peak_valid,
    input  wire        sample_dropped,
    input  wire [7:0]  heart_rate,
    input  wire signed [31:0] r_val,
    input  wire [10:0]        r_idx
);

wire valid_access = wbs_stb_i && wbs_cyc_i &&
                    (wbs_adr_i[31:4] == BASE_ADDR[31:4]);

reg signed [31:0] r_val_lat;
reg [10:0]        r_idx_lat;
reg [7:0]         hr_lat;
reg               hr_valid_lat, peak_valid_lat;

always @(posedge wb_clk_i) begin
    if (wb_rst_i) begin
        r_val_lat      <= 32'sd0;
        r_idx_lat      <= 11'd0;
        hr_lat         <= 8'd0;
        hr_valid_lat   <= 1'b0;
        peak_valid_lat <= 1'b0;
    end else begin
        if (peak_valid) begin
            r_val_lat      <= r_val;
            r_idx_lat      <= r_idx;
            peak_valid_lat <= 1'b1;
        end
        if (hr_valid) hr_lat <= heart_rate;
        hr_valid_lat <= hr_valid;
    end
end

always @(posedge wb_clk_i) begin
    if (wb_rst_i) begin
        wbs_ack_o <= 1'b0;
        wbs_dat_o <= 32'd0;
    end else begin
        wbs_ack_o <= 1'b0;
        if (valid_access && !wbs_we_i) begin
            wbs_ack_o <= 1'b1;
            case (wbs_adr_i[3:2])
                2'd0: wbs_dat_o <= {29'd0, sample_dropped, peak_valid_lat, hr_valid_lat};
                2'd1: wbs_dat_o <= {24'd0, hr_lat};
                2'd2: wbs_dat_o <= r_val_lat;
                2'd3: wbs_dat_o <= {21'd0, r_idx_lat};
            endcase
        end
        if (valid_access && wbs_we_i) wbs_ack_o <= 1'b1;
    end
end

endmodule
