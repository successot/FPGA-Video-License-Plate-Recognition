

module udp_cmd_rx(
    input             clk,
    input             rst_n,
    input             rec_pkt_done,
    input             rec_en,
    input      [31:0] rec_data,
    input      [15:0] rec_byte_num,
    output reg        transfer_flag,
    output reg [2:0]  manual_mode
);
    // 简单 32-bit 命令字：
    // "STRT" starts, "STOP" stops, "RAW0", "G08x", "G12x", "AUTO", "DBG4/DBG5/DBG6".
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            transfer_flag <= 1'b0;
            manual_mode <= 3'd3; // auto
        end else if(rec_en) begin
            case(rec_data)
                32'h53545254: transfer_flag <= 1'b1; // STRT 开始发送
                32'h53544F50: transfer_flag <= 1'b0; // STOP 停止发送
                32'h52415730: manual_mode <= 3'd0;   // RAW0 raw 模式
                32'h47303858: manual_mode <= 3'd1;   // G08X gamma_0.8
                32'h47313258: manual_mode <= 3'd2;   // G12X gamma_1.2
                32'h4155544F: manual_mode <= 3'd3;   // AUTO 自动模式
                32'h44424734: manual_mode <= 3'd4;   // DBG4 调试模式 4
                32'h44424735: manual_mode <= 3'd5;   // DBG5 调试模式 5
                32'h44424736: manual_mode <= 3'd6;   // DBG6 调试模式 6
                default: ;
            endcase
        end
    end
endmodule
