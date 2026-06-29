
module frame_luma_stat #(
    parameter UNDER_EXP_TH = 8'd30,
    parameter OVER_EXP_TH  = 8'd230
)(
    input             clk,
    input             rst_n,
    input             in_valid,
    input             in_href,
    input             in_vsync,
    input      [15:0] in_rgb565,
    output reg        stat_valid,
    output reg [39:0] sum_y,
    output reg [31:0] pixel_count,
    output reg [31:0] under_exp_count,
    output reg [31:0] over_exp_count
);
    wire [7:0] y;
    reg        vsync_d0;
    reg        vsync_d1;
    reg [39:0] sum_y_acc;
    reg [31:0] pixel_count_acc;
    reg [31:0] under_acc;
    reg [31:0] over_acc;

    wire frame_end;

    rgb565_to_gray u_gray(.rgb565(in_rgb565), .y(y));

    assign frame_end = vsync_d1 & (~vsync_d0);  // 下降沿，与 ATK 参考例程习惯保持一致

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            vsync_d0 <= 1'b0;
            vsync_d1 <= 1'b0;
        end else begin
            vsync_d0 <= in_vsync;
            vsync_d1 <= vsync_d0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sum_y_acc <= 40'd0;
            pixel_count_acc <= 32'd0;
            under_acc <= 32'd0;
            over_acc <= 32'd0;
            sum_y <= 40'd0;
            pixel_count <= 32'd0;
            under_exp_count <= 32'd0;
            over_exp_count <= 32'd0;
            stat_valid <= 1'b0;
        end else begin
            stat_valid <= 1'b0;
            if(frame_end) begin
                sum_y <= sum_y_acc;
                pixel_count <= pixel_count_acc;
                under_exp_count <= under_acc;
                over_exp_count <= over_acc;
                stat_valid <= 1'b1;
                sum_y_acc <= 40'd0;
                pixel_count_acc <= 32'd0;
                under_acc <= 32'd0;
                over_acc <= 32'd0;
            end else if(in_valid && in_href) begin
                sum_y_acc <= sum_y_acc + y;
                pixel_count_acc <= pixel_count_acc + 1'b1;
                if(y < UNDER_EXP_TH)
                    under_acc <= under_acc + 1'b1;
                if(y > OVER_EXP_TH)
                    over_acc <= over_acc + 1'b1;
            end
        end
    end
endmodule
