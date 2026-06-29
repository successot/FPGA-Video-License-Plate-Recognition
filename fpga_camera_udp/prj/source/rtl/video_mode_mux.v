

module video_mode_mux(
    input             clk,
    input             rst_n,
    input             raw_valid,
    input             raw_href,
    input             raw_vsync,
    input      [15:0] raw_rgb565,
    input             gamma_valid,
    input             gamma_href,
    input             gamma_vsync,
    input      [15:0] gamma_rgb565,
    input      [2:0]  active_mode,
    output reg        out_valid,
    output reg        out_href,
    output reg        out_vsync,
    output reg [15:0] out_rgb565
);
    localparam MODE_RAW          = 3'd0;
    localparam MODE_GAMMA_DARK   = 3'd1;
    localparam MODE_GAMMA_BRIGHT = 3'd2;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            out_valid <= 1'b0;
            out_href  <= 1'b0;
            out_vsync <= 1'b0;
            out_rgb565 <= 16'd0;
        end else begin
            if(active_mode == MODE_RAW) begin
                out_valid <= raw_valid;
                out_href  <= raw_href;
                out_vsync <= raw_vsync;
                out_rgb565 <= raw_rgb565;
            end else if(active_mode == MODE_GAMMA_DARK || active_mode == MODE_GAMMA_BRIGHT) begin
                out_valid <= gamma_valid;
                out_href  <= gamma_href;
                out_vsync <= gamma_vsync;
                out_rgb565 <= gamma_rgb565;
            end else begin
                // 调试模式占位：默认 raw 透传，避免引入模型输入风格偏移。
                out_valid <= raw_valid;
                out_href  <= raw_href;
                out_vsync <= raw_vsync;
                out_rgb565 <= raw_rgb565;
            end
        end
    end
endmodule
