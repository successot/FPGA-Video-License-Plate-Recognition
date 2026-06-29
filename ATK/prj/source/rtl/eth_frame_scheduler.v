

module eth_frame_scheduler #(
    parameter SEND_EVERY_N_FRAMES = 8'd30
)(
    input            clk,
    input            rst_n,
    input            frame_end,
    input            transfer_enable,
    output reg       capture_this_frame,
    output reg [31:0] frame_id
);
    reg [7:0] div_cnt;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            div_cnt <= 8'd0;
            capture_this_frame <= 1'b0;
            frame_id <= 32'd0;
        end else begin
            capture_this_frame <= 1'b0;
            if(!transfer_enable) begin
                div_cnt <= 8'd0;
            end else if(frame_end) begin
                if(div_cnt == 8'd0) begin
                    capture_this_frame <= 1'b1;
                    frame_id <= frame_id + 1'b1;
                    div_cnt <= SEND_EVERY_N_FRAMES - 1'b1;
                end else begin
                    div_cnt <= div_cnt - 1'b1;
                end
            end
        end
    end
endmodule
