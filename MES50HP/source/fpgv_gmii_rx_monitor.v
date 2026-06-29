`timescale 1ns / 1ps
`default_nettype wire
// -----------------------------------------------------------------------------
// MES50H eth_test 阶段1 GMII 接收监视模块
// 功能：
//   1. 只旁路监听一路 GMII RX 接口。
//   2. 统计原始以太网帧数量。
//   3. 识别发往 LOCAL_IP:UDP_PORT 的 IPv4/UDP 包。
//   4. 识别简单图像测试包头魔数 "FPGV"。
// 本模块不回 ARP，不发送以太网帧，不写 DDR，也不做图像拼接。
// -----------------------------------------------------------------------------
module fpgv_gmii_rx_monitor #(
    parameter [47:0] LOCAL_MAC = 48'h02_00_00_00_50_01,
    parameter [31:0] LOCAL_IP  = 32'hC0A8_0164,   // 192.168.1.100
    parameter [15:0] UDP_PORT  = 16'd5000
)(
    input             clk,
    input             rst_n,

    input      [7:0]  gmii_rxd,
    input             gmii_rx_dv,
    input             gmii_rx_er,

    output reg        gmii_frame_pulse,
    output reg        ip_udp_pulse,
    output reg        fpgv_pulse,
    output reg        error_pulse,

    output reg [31:0] gmii_frame_count,
    output reg [31:0] udp_packet_count,
    output reg [31:0] fpgv_packet_count,
    output reg [31:0] error_count,

    output reg [31:0] last_frame_id,
    output reg [15:0] last_packet_id,
    output reg [15:0] last_packet_total,
    output reg [15:0] last_width,
    output reg [15:0] last_height,
    output reg [7:0]  last_mode,

    output reg [7:0]  debug_led
);

localparam S_IDLE  = 2'd0;
localparam S_PREAM = 2'd1;
localparam S_FRAME = 2'd2;

reg [1:0]  state;
reg        dv_d1;
reg [10:0] byte_idx;
reg [2:0]  pre_cnt;

reg        eth_accept;
reg        ipv4_accept;
reg        udp_accept;

reg [10:0] udp_base_idx;
reg [15:0] eth_type;
reg [15:0] udp_dst_port;
reg [47:0] dst_mac_shift;
reg [31:0] dst_ip_shift;
reg [31:0] magic_shift;

reg [23:0] blink_cnt;
reg        blink;

wire dv_rise = gmii_rx_dv & ~dv_d1;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        dv_d1 <= 1'b0;
    else
        dv_d1 <= gmii_rx_dv;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state              <= S_IDLE;
        byte_idx           <= 11'd0;
        pre_cnt            <= 3'd0;

        eth_accept         <= 1'b0;
        ipv4_accept        <= 1'b0;
        udp_accept         <= 1'b0;

        udp_base_idx       <= 11'd34;
        eth_type           <= 16'd0;
        udp_dst_port       <= 16'd0;
        dst_mac_shift      <= 48'd0;
        dst_ip_shift       <= 32'd0;
        magic_shift        <= 32'd0;

        gmii_frame_pulse   <= 1'b0;
        ip_udp_pulse       <= 1'b0;
        fpgv_pulse         <= 1'b0;
        error_pulse        <= 1'b0;

        gmii_frame_count   <= 32'd0;
        udp_packet_count   <= 32'd0;
        fpgv_packet_count  <= 32'd0;
        error_count        <= 32'd0;

        last_frame_id      <= 32'd0;
        last_packet_id     <= 16'd0;
        last_packet_total  <= 16'd0;
        last_width         <= 16'd0;
        last_height        <= 16'd0;
        last_mode          <= 8'd0;
    end else begin
        gmii_frame_pulse <= 1'b0;
        ip_udp_pulse     <= 1'b0;
        fpgv_pulse       <= 1'b0;
        error_pulse      <= 1'b0;

        if(gmii_rx_dv && gmii_rx_er) begin
            error_pulse <= 1'b1;
            error_count <= error_count + 32'd1;
        end

        case(state)
        S_IDLE: begin
            if(dv_rise) begin
                pre_cnt       <= 3'd0;
                byte_idx      <= 11'd0;
                eth_accept    <= 1'b0;
                ipv4_accept   <= 1'b0;
                udp_accept    <= 1'b0;
                udp_base_idx  <= 11'd34;
                dst_mac_shift <= 48'd0;
                dst_ip_shift  <= 32'd0;
                magic_shift   <= 32'd0;

                if(gmii_rxd == 8'h55) begin
                    state   <= S_PREAM;
                    pre_cnt <= 3'd1;
                end else begin
                    // 有些 IP 输出给用户侧时可能已经去掉前导码/SFD，这里兼容这种情况。
                    state             <= S_FRAME;
                    gmii_frame_pulse  <= 1'b1;
                    gmii_frame_count  <= gmii_frame_count + 32'd1;
                    dst_mac_shift     <= {40'd0, gmii_rxd};
                    byte_idx          <= 11'd1;
                end
            end
        end

        S_PREAM: begin
            if(!gmii_rx_dv) begin
                state <= S_IDLE;
            end else if(gmii_rxd == 8'h55) begin
                if(pre_cnt != 3'd7)
                    pre_cnt <= pre_cnt + 3'd1;
            end else if(gmii_rxd == 8'hD5) begin
                // 下一个有效字节就是以太网目的 MAC 的第 0 字节。
                state             <= S_FRAME;
                byte_idx          <= 11'd0;
                gmii_frame_pulse  <= 1'b1;
                gmii_frame_count  <= gmii_frame_count + 32'd1;
            end else begin
                // 兜底处理：把当前字节当作以太网帧第一个字节。
                state             <= S_FRAME;
                byte_idx          <= 11'd1;
                gmii_frame_pulse  <= 1'b1;
                gmii_frame_count  <= gmii_frame_count + 32'd1;
                dst_mac_shift     <= {40'd0, gmii_rxd};
            end
        end

        S_FRAME: begin
            if(!gmii_rx_dv) begin
                state <= S_IDLE;
            end else begin
                // 以太网目的 MAC：字节 0..5。
                if(byte_idx <= 11'd5)
                    dst_mac_shift <= {dst_mac_shift[39:0], gmii_rxd};

                if(byte_idx == 11'd5) begin
                    eth_accept <= (({dst_mac_shift[39:0], gmii_rxd} == LOCAL_MAC) ||
                                   ({dst_mac_shift[39:0], gmii_rxd} == 48'hFF_FF_FF_FF_FF_FF));
                end

                // EtherType：字节 12..13。
                if(byte_idx == 11'd12)
                    eth_type[15:8] <= gmii_rxd;

                if(byte_idx == 11'd13) begin
                    eth_type[7:0] <= gmii_rxd;
                    if({eth_type[15:8], gmii_rxd} != 16'h0800)
                        eth_accept <= 1'b0;
                end

                // IPv4 IHL 位于第 14 字节低 4 位；UDP 头起始位置 = 14 + IHL*4。
                if(byte_idx == 11'd14)
                    udp_base_idx <= 11'd14 + {5'd0, gmii_rxd[3:0], 2'b00};

                // IPv4 协议字段：17 表示 UDP。
                if(byte_idx == 11'd23) begin
                    ipv4_accept <= eth_accept && (eth_type == 16'h0800) && (gmii_rxd == 8'd17);
                end

                // IPv4 目的 IP：字节 30..33。
                if((byte_idx >= 11'd30) && (byte_idx <= 11'd33))
                    dst_ip_shift <= {dst_ip_shift[23:0], gmii_rxd};

                if(byte_idx == 11'd33) begin
                    if({dst_ip_shift[23:0], gmii_rxd} != LOCAL_IP)
                        ipv4_accept <= 1'b0;
                end

                // UDP 目的端口：udp_base_idx + 2、+3。
                if(byte_idx == udp_base_idx + 11'd2)
                    udp_dst_port[15:8] <= gmii_rxd;

                if(byte_idx == udp_base_idx + 11'd3) begin
                    udp_dst_port[7:0] <= gmii_rxd;
                    udp_accept <= ipv4_accept && ({udp_dst_port[15:8], gmii_rxd} == UDP_PORT);
                    if(ipv4_accept && ({udp_dst_port[15:8], gmii_rxd} == UDP_PORT)) begin
                        ip_udp_pulse     <= 1'b1;
                        udp_packet_count <= udp_packet_count + 32'd1;
                    end
                end

                // UDP payload 第 0..3 字节应为 ASCII 字符串 "FPGV"。
                if((byte_idx >= udp_base_idx + 11'd8) && (byte_idx <= udp_base_idx + 11'd11))
                    magic_shift <= {magic_shift[23:0], gmii_rxd};

                if(byte_idx == udp_base_idx + 11'd11) begin
                    if(udp_accept && ({magic_shift[23:0], gmii_rxd} == 32'h46_50_47_56)) begin
                        fpgv_pulse        <= 1'b1;
                        fpgv_packet_count <= fpgv_packet_count + 32'd1;
                    end
                end

                // 可选：解析 FPGV 包头中魔数之后的字段：
                // payload[4]  = mode，图像/测试模式
                // payload[8:11]  = frame_id，帧编号
                // payload[12:13] = width，图像宽度
                // payload[14:15] = height，图像高度
                // payload[16:17] = packet_id，当前包编号
                // payload[18:19] = packet_total，本帧总包数
                if(byte_idx == udp_base_idx + 11'd13) last_mode <= gmii_rxd;

                if(byte_idx == udp_base_idx + 11'd16) last_frame_id[31:24] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd17) last_frame_id[23:16] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd18) last_frame_id[15:8]  <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd19) last_frame_id[7:0]   <= gmii_rxd;

                if(byte_idx == udp_base_idx + 11'd20) last_width[15:8]  <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd21) last_width[7:0]   <= gmii_rxd;

                if(byte_idx == udp_base_idx + 11'd22) last_height[15:8] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd23) last_height[7:0]  <= gmii_rxd;

                if(byte_idx == udp_base_idx + 11'd24) last_packet_id[15:8] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd25) last_packet_id[7:0]  <= gmii_rxd;

                if(byte_idx == udp_base_idx + 11'd26) last_packet_total[15:8] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd27) last_packet_total[7:0]  <= gmii_rxd;

                if(byte_idx != 11'h7ff)
                    byte_idx <= byte_idx + 11'd1;
            end
        end

        default: begin
            state <= S_IDLE;
        end
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        blink_cnt <= 24'd0;
        blink     <= 1'b0;
    end else begin
        blink_cnt <= blink_cnt + 24'd1;
        if(blink_cnt == 24'd0)
            blink <= ~blink;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        debug_led <= 8'h00;
    end else begin
        debug_led[0] <= blink;
        debug_led[1] <= gmii_rx_dv;
        debug_led[2] <= |gmii_frame_count[7:0];
        debug_led[3] <= |udp_packet_count[7:0];
        debug_led[4] <= |fpgv_packet_count[7:0];
        debug_led[5] <= |error_count[7:0];
        debug_led[6] <= last_packet_id[0];
        debug_led[7] <= last_frame_id[0];
    end
end

endmodule
