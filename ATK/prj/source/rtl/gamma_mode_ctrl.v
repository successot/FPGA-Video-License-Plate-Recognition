

module gamma_mode_ctrl #(
    parameter DARK_AVG_TH       = 8'd90,
    parameter BRIGHT_AVG_TH     = 8'd180,
    parameter UNDER_RATIO_NUM   = 8'd30,  // 百分比
    parameter OVER_RATIO_NUM    = 8'd20,  // 百分比
    parameter MODE_HOLD_FRAMES  = 8'd3
)(
    input             clk,
    input             rst_n,
    input             stat_valid,
    input      [39:0] sum_y,
    input      [31:0] pixel_count,
    input      [31:0] under_exp_count,
    input      [31:0] over_exp_count,
    input      [2:0]  manual_mode,       // 0 raw, 1 gamma0.8, 2 gamma1.2, 3 auto, 4/5/6 debug
    output reg [2:0]  active_mode,
    output reg [1:0]  auto_gamma_sel     // 0 raw, 1 dark gamma0.8, 2 bright gamma1.2
);
    localparam MODE_RAW          = 3'd0;
    localparam MODE_GAMMA_DARK   = 3'd1;
    localparam MODE_GAMMA_BRIGHT = 3'd2;
    localparam MODE_AUTO         = 3'd3;

    reg [7:0] dark_cnt;
    reg [7:0] bright_cnt;
    reg [7:0] normal_cnt;

    wire dark_by_avg;
    wire bright_by_avg;
    wire dark_by_ratio;
    wire bright_by_ratio;
    wire dark_cond;
    wire bright_cond;
    wire normal_cond;

    assign dark_by_avg    = (pixel_count != 32'd0) && (sum_y < (pixel_count * DARK_AVG_TH));
    assign bright_by_avg  = (pixel_count != 32'd0) && (sum_y > (pixel_count * BRIGHT_AVG_TH));
    assign dark_by_ratio  = (pixel_count != 32'd0) && ((under_exp_count * 8'd100) > (pixel_count * UNDER_RATIO_NUM));
    assign bright_by_ratio= (pixel_count != 32'd0) && ((over_exp_count  * 8'd100) > (pixel_count * OVER_RATIO_NUM));

    assign dark_cond   = dark_by_avg | dark_by_ratio;
    assign bright_cond = bright_by_avg | bright_by_ratio;
    assign normal_cond = (~dark_cond) & (~bright_cond);

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dark_cnt <= 8'd0;
            bright_cnt <= 8'd0;
            normal_cnt <= 8'd0;
            auto_gamma_sel <= 2'd0;
            active_mode <= MODE_AUTO;
        end else begin
            if(stat_valid) begin
                if(dark_cond) begin
                    if(dark_cnt < MODE_HOLD_FRAMES) dark_cnt <= dark_cnt + 1'b1;
                    bright_cnt <= 8'd0;
                    normal_cnt <= 8'd0;
                end else if(bright_cond) begin
                    if(bright_cnt < MODE_HOLD_FRAMES) bright_cnt <= bright_cnt + 1'b1;
                    dark_cnt <= 8'd0;
                    normal_cnt <= 8'd0;
                end else if(normal_cond) begin
                    if(normal_cnt < MODE_HOLD_FRAMES) normal_cnt <= normal_cnt + 1'b1;
                    dark_cnt <= 8'd0;
                    bright_cnt <= 8'd0;
                end

                if(dark_cnt >= (MODE_HOLD_FRAMES-1))
                    auto_gamma_sel <= 2'd1;
                else if(bright_cnt >= (MODE_HOLD_FRAMES-1))
                    auto_gamma_sel <= 2'd2;
                else if(normal_cnt >= (MODE_HOLD_FRAMES-1))
                    auto_gamma_sel <= 2'd0;
            end

            case(manual_mode)
                MODE_RAW:          active_mode <= MODE_RAW;
                MODE_GAMMA_DARK:   active_mode <= MODE_GAMMA_DARK;
                MODE_GAMMA_BRIGHT: active_mode <= MODE_GAMMA_BRIGHT;
                MODE_AUTO: begin
                    if(auto_gamma_sel == 2'd1)
                        active_mode <= MODE_GAMMA_DARK;
                    else if(auto_gamma_sel == 2'd2)
                        active_mode <= MODE_GAMMA_BRIGHT;
                    else
                        active_mode <= MODE_RAW;
                end
                default: active_mode <= manual_mode; // debug modes are manual only
            endcase
        end
    end
endmodule
