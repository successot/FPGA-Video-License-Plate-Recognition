

module lcd_debug_overlay #(
    parameter BOX_W = 12'd32,
    parameter BOX_H = 12'd32
)(
    input             clk,
    input             rst_n,
    input             in_valid,
    input             in_href,
    input             in_vsync,
    input      [15:0] in_rgb565,
    input      [2:0]  mode,
    output reg        out_valid,
    output reg        out_href,
    output reg        out_vsync,
    output reg [15:0] out_rgb565
);
    reg in_href_d;
    reg in_vsync_d;
    reg [11:0] x_cnt;
    reg [11:0] y_cnt;
    wire line_start;
    wire frame_start;
    reg [15:0] color;

    assign line_start  = in_href & (~in_href_d);
    assign frame_start = in_vsync & (~in_vsync_d);

    always @(*) begin
        case(mode)
            3'd0: color = 16'hFFFF; // raw 白色
            3'd1: color = 16'h001F; // gamma0.8 蓝色
            3'd2: color = 16'hF800; // gamma1.2 红色
            3'd3: color = 16'h07E0; // auto 绿色
            3'd4: color = 16'hFFE0; // sharpen 黄色
            3'd5: color = 16'hF81F; // HE 紫色
            3'd6: color = 16'h07FF; // CLAHE 青色
            default: color = 16'hFFFF;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            in_href_d <= 1'b0;
            in_vsync_d <= 1'b0;
            x_cnt <= 12'd0;
            y_cnt <= 12'd0;
            out_valid <= 1'b0;
            out_href <= 1'b0;
            out_vsync <= 1'b0;
            out_rgb565 <= 16'd0;
        end else begin
            in_href_d <= in_href;
            in_vsync_d <= in_vsync;

            if(frame_start) begin
                x_cnt <= 12'd0;
                y_cnt <= 12'd0;
            end else if(line_start) begin
                x_cnt <= 12'd0;
                y_cnt <= y_cnt + 1'b1;
            end else if(in_valid && in_href) begin
                x_cnt <= x_cnt + 1'b1;
            end

            out_valid <= in_valid;
            out_href <= in_href;
            out_vsync <= in_vsync;
            if(in_valid && in_href && x_cnt < BOX_W && y_cnt < BOX_H)
                out_rgb565 <= color;
            else
                out_rgb565 <= in_rgb565;
        end
    end
endmodule
