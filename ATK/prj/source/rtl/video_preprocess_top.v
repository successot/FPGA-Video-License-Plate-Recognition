

module video_preprocess_top #(
    parameter UNDER_EXP_TH      = 8'd30,
    parameter OVER_EXP_TH       = 8'd230,
    parameter DARK_AVG_TH       = 8'd70,
    parameter BRIGHT_AVG_TH     = 8'd180,
    parameter MODE_HOLD_FRAMES  = 8'd3
)(
    input             clk,
    input             rst_n,
    input             in_valid,
    input             in_href,
    input             in_vsync,
    input      [15:0] in_rgb565,
    input      [2:0]  manual_mode, // 默认可接 3'd3，即 auto 模式
    output            out_valid,
    output            out_href,
    output            out_vsync,
    output     [15:0] out_rgb565,
    output     [2:0]  active_mode,
    output            stat_valid
);
    wire [39:0] sum_y;
    wire [31:0] pixel_count;
    wire [31:0] under_exp_count;
    wire [31:0] over_exp_count;
    wire [1:0] auto_gamma_sel;
    wire [1:0] gamma_sel;
    wire raw_valid_d, raw_href_d, raw_vsync_d;
    wire [15:0] raw_rgb565_d;
    wire gamma_valid, gamma_href, gamma_vsync;
    wire [15:0] gamma_rgb565;
    wire mux_valid, mux_href, mux_vsync;
    wire [15:0] mux_rgb565;

    frame_luma_stat #(
        .UNDER_EXP_TH(UNDER_EXP_TH),
        .OVER_EXP_TH(OVER_EXP_TH)
    ) u_stat (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_href(in_href),
        .in_vsync(in_vsync),
        .in_rgb565(in_rgb565),
        .stat_valid(stat_valid),
        .sum_y(sum_y),
        .pixel_count(pixel_count),
        .under_exp_count(under_exp_count),
        .over_exp_count(over_exp_count)
    );

    gamma_mode_ctrl #(
        .DARK_AVG_TH(DARK_AVG_TH),
        .BRIGHT_AVG_TH(BRIGHT_AVG_TH),
        .MODE_HOLD_FRAMES(MODE_HOLD_FRAMES)
    ) u_mode (
        .clk(clk),
        .rst_n(rst_n),
        .stat_valid(stat_valid),
        .sum_y(sum_y),
        .pixel_count(pixel_count),
        .under_exp_count(under_exp_count),
        .over_exp_count(over_exp_count),
        .manual_mode(manual_mode),
        .active_mode(active_mode),
        .auto_gamma_sel(auto_gamma_sel)
    );

    assign gamma_sel = (active_mode == 3'd1) ? 2'd1 :
                       (active_mode == 3'd2) ? 2'd2 : 2'd0;

    video_sync_delay #(.DATA_WIDTH(16), .DELAY(1)) u_raw_delay (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_href(in_href),
        .in_vsync(in_vsync),
        .in_data(in_rgb565),
        .out_valid(raw_valid_d),
        .out_href(raw_href_d),
        .out_vsync(raw_vsync_d),
        .out_data(raw_rgb565_d)
    );

    gamma_rgb565 u_gamma (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_href(in_href),
        .in_vsync(in_vsync),
        .in_rgb565(in_rgb565),
        .gamma_sel(gamma_sel),
        .out_valid(gamma_valid),
        .out_href(gamma_href),
        .out_vsync(gamma_vsync),
        .out_rgb565(gamma_rgb565)
    );

    video_mode_mux u_mux (
        .clk(clk),
        .rst_n(rst_n),
        .raw_valid(raw_valid_d),
        .raw_href(raw_href_d),
        .raw_vsync(raw_vsync_d),
        .raw_rgb565(raw_rgb565_d),
        .gamma_valid(gamma_valid),
        .gamma_href(gamma_href),
        .gamma_vsync(gamma_vsync),
        .gamma_rgb565(gamma_rgb565),
        .active_mode(active_mode),
        .out_valid(mux_valid),
        .out_href(mux_href),
        .out_vsync(mux_vsync),
        .out_rgb565(mux_rgb565)
    );

    lcd_debug_overlay u_overlay (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(mux_valid),
        .in_href(mux_href),
        .in_vsync(mux_vsync),
        .in_rgb565(mux_rgb565),
        .mode(active_mode),
        .out_valid(out_valid),
        .out_href(out_href),
        .out_vsync(out_vsync),
        .out_rgb565(out_rgb565)
    );
endmodule
