`timescale 1ns / 1ps
`default_nettype wire
// -----------------------------------------------------------------------------
// MES50H 阶段2：UDP 图像包检查模块
// -----------------------------------------------------------------------------
// 目标：
//   1. 继续监听阶段1已经验证通过的 GMII RX。
//   2. 识别 IPv4/UDP 目的端口 5000。
//   3. 识别 UDP payload 前 4 字节 "FPGV"。
//   4. 解析 FPGV 包头字段：frame_id、packet_id、packet_total、width、height、payload_len。
//   5. 检查同一 frame_id 内 packet_id 是否连续。
//   6. 检查一帧是否收到 EXPECTED_PACKET_TOTAL 个包，默认 750。
//   7. 只做检查和计数，不写 DDR3，不驱动 LCD。
// -----------------------------------------------------------------------------
module fpgv_stage2_udp_packet_check #(
    parameter [47:0] LOCAL_MAC = 48'h02_00_00_00_50_01,
    parameter [31:0] LOCAL_IP  = 32'hC0A8_0164,       // 192.168.1.100
    parameter [15:0] UDP_PORT  = 16'd5000,
    parameter [15:0] EXPECTED_PACKET_TOTAL = 16'd750,
    parameter        CHECK_DEST_MAC = 1'b1,
    parameter        CHECK_DEST_IP  = 1'b1
)(
    input             clk,
    input             rst_n,

    input      [7:0]  gmii_rxd,
    input             gmii_rx_dv,
    input             gmii_rx_er,

    output reg        raw_frame_pulse,
    output reg        udp5000_pulse,
    output reg        fpgv_packet_pulse,
    output reg        frame_complete_pulse,
    output reg        seq_error_pulse,
    output reg        error_pulse,

    output reg [31:0] raw_frame_count,
    output reg [31:0] udp5000_count,
    output reg [31:0] fpgv_packet_count,
    output reg [31:0] complete_frame_count,
    output reg [31:0] seq_error_count,
    output reg [31:0] frame_drop_count,
    output reg [31:0] rx_error_count,

    output reg [31:0] last_frame_id,
    output reg [15:0] last_packet_id,
    output reg [15:0] last_packet_total,
    output reg [15:0] last_width,
    output reg [15:0] last_height,
    output reg [15:0] last_payload_len,
    output reg [31:0] last_byte_offset,
    output reg [15:0] expected_packet_id,
    output reg [7:0]  last_version,
    output reg [7:0]  last_mode,
    output reg [7:0]  last_pixel_format,

    output reg        packet_seq_ok,
    output reg [7:0]  debug_led
);

localparam S_IDLE  = 2'd0;
localparam S_PREAM = 2'd1;
localparam S_FRAME = 2'd2;

reg [1:0]  state;
reg        dv_d1;
reg [10:0] byte_idx;
reg [2:0]  pre_cnt;

reg [47:0] dst_mac_shift;
reg [31:0] dst_ip_shift;
reg [15:0] eth_type;
reg [15:0] udp_dst_port;
reg [31:0] magic_shift;

reg [10:0] udp_base_idx;

reg        dest_mac_ok;
reg        ipv4_ok;
reg        udp_proto_ok;
reg        dst_ip_ok;
reg        udp_port_ok;
reg        fpgv_ok;

reg        stream_started;
reg [31:0] current_frame_id;
reg [15:0] packets_seen_in_frame;
reg        current_frame_seq_ok;

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
        state                 <= S_IDLE;
        byte_idx              <= 11'd0;
        pre_cnt               <= 3'd0;

        dst_mac_shift         <= 48'd0;
        dst_ip_shift          <= 32'd0;
        eth_type              <= 16'd0;
        udp_dst_port          <= 16'd0;
        magic_shift           <= 32'd0;
        udp_base_idx          <= 11'd34;

        dest_mac_ok           <= 1'b0;
        ipv4_ok               <= 1'b0;
        udp_proto_ok          <= 1'b0;
        dst_ip_ok             <= 1'b0;
        udp_port_ok           <= 1'b0;
        fpgv_ok               <= 1'b0;

        stream_started        <= 1'b0;
        current_frame_id      <= 32'd0;
        packets_seen_in_frame <= 16'd0;
        current_frame_seq_ok  <= 1'b1;
        expected_packet_id    <= 16'd0;
        packet_seq_ok         <= 1'b0;

        raw_frame_pulse       <= 1'b0;
        udp5000_pulse         <= 1'b0;
        fpgv_packet_pulse     <= 1'b0;
        frame_complete_pulse  <= 1'b0;
        seq_error_pulse       <= 1'b0;
        error_pulse           <= 1'b0;

        raw_frame_count       <= 32'd0;
        udp5000_count         <= 32'd0;
        fpgv_packet_count     <= 32'd0;
        complete_frame_count  <= 32'd0;
        seq_error_count       <= 32'd0;
        frame_drop_count      <= 32'd0;
        rx_error_count        <= 32'd0;

        last_frame_id         <= 32'd0;
        last_packet_id        <= 16'd0;
        last_packet_total     <= 16'd0;
        last_width            <= 16'd0;
        last_height           <= 16'd0;
        last_payload_len      <= 16'd0;
        last_byte_offset      <= 32'd0;
        last_version          <= 8'd0;
        last_mode             <= 8'd0;
        last_pixel_format     <= 8'd0;
    end else begin
        raw_frame_pulse      <= 1'b0;
        udp5000_pulse        <= 1'b0;
        fpgv_packet_pulse    <= 1'b0;
        frame_complete_pulse <= 1'b0;
        seq_error_pulse      <= 1'b0;
        error_pulse          <= 1'b0;

        if(gmii_rx_dv && gmii_rx_er) begin
            rx_error_count <= rx_error_count + 32'd1;
            error_pulse    <= 1'b1;
        end

        case(state)
        S_IDLE: begin
            if(dv_rise) begin
                byte_idx              <= 11'd0;
                pre_cnt               <= 3'd0;

                dst_mac_shift         <= 48'd0;
                dst_ip_shift          <= 32'd0;
                eth_type              <= 16'd0;
                udp_dst_port          <= 16'd0;
                magic_shift           <= 32'd0;
                udp_base_idx          <= 11'd34;

                dest_mac_ok           <= 1'b0;
                ipv4_ok               <= 1'b0;
                udp_proto_ok          <= 1'b0;
                dst_ip_ok             <= 1'b0;
                udp_port_ok           <= 1'b0;
                fpgv_ok               <= 1'b0;

                if(gmii_rxd == 8'h55) begin
                    state   <= S_PREAM;
                    pre_cnt <= 3'd1;
                end else begin
                    // 兼容 QSGMII IP 已经去掉前导码/SFD 的情况。
                    state            <= S_FRAME;
                    raw_frame_pulse  <= 1'b1;
                    raw_frame_count  <= raw_frame_count + 32'd1;
                    dst_mac_shift    <= {40'd0, gmii_rxd};
                    byte_idx         <= 11'd1;
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
                state            <= S_FRAME;
                byte_idx         <= 11'd0;
                raw_frame_pulse  <= 1'b1;
                raw_frame_count  <= raw_frame_count + 32'd1;
            end else begin
                // 如果没有标准 SFD，则把当前字节当作以太网帧第一个字节。
                state            <= S_FRAME;
                byte_idx         <= 11'd1;
                raw_frame_pulse  <= 1'b1;
                raw_frame_count  <= raw_frame_count + 32'd1;
                dst_mac_shift    <= {40'd0, gmii_rxd};
            end
        end

        S_FRAME: begin
            if(!gmii_rx_dv) begin
                state <= S_IDLE;
            end else begin
                // 目的 MAC：Ethernet byte 0..5。
                if(byte_idx <= 11'd5)
                    dst_mac_shift <= {dst_mac_shift[39:0], gmii_rxd};

                if(byte_idx == 11'd5) begin
                    if(CHECK_DEST_MAC)
                        dest_mac_ok <= (({dst_mac_shift[39:0], gmii_rxd} == LOCAL_MAC) ||
                                        ({dst_mac_shift[39:0], gmii_rxd} == 48'hFF_FF_FF_FF_FF_FF));
                    else
                        dest_mac_ok <= 1'b1;
                end

                // EtherType：Ethernet byte 12..13。
                if(byte_idx == 11'd12)
                    eth_type[15:8] <= gmii_rxd;

                if(byte_idx == 11'd13) begin
                    eth_type[7:0] <= gmii_rxd;
                    ipv4_ok       <= ({eth_type[15:8], gmii_rxd} == 16'h0800);
                end

                // IPv4 IHL：byte 14 低 4 位，UDP 头起始位置 = 14 + IHL*4。
                if(byte_idx == 11'd14)
                    udp_base_idx <= 11'd14 + {5'd0, gmii_rxd[3:0], 2'b00};

                // IPv4 protocol：byte 23，17 表示 UDP。
                if(byte_idx == 11'd23)
                    udp_proto_ok <= dest_mac_ok && ipv4_ok && (gmii_rxd == 8'd17);

                // IPv4 目的 IP：byte 30..33。
                if((byte_idx >= 11'd30) && (byte_idx <= 11'd33))
                    dst_ip_shift <= {dst_ip_shift[23:0], gmii_rxd};

                if(byte_idx == 11'd33) begin
                    if(CHECK_DEST_IP)
                        dst_ip_ok <= ({dst_ip_shift[23:0], gmii_rxd} == LOCAL_IP);
                    else
                        dst_ip_ok <= 1'b1;
                end

                // UDP 目的端口：udp_base_idx + 2, +3。
                if(byte_idx == udp_base_idx + 11'd2)
                    udp_dst_port[15:8] <= gmii_rxd;

                if(byte_idx == udp_base_idx + 11'd3) begin
                    udp_dst_port[7:0] <= gmii_rxd;
                    udp_port_ok <= udp_proto_ok && dst_ip_ok && ({udp_dst_port[15:8], gmii_rxd} == UDP_PORT);
                    if(udp_proto_ok && dst_ip_ok && ({udp_dst_port[15:8], gmii_rxd} == UDP_PORT)) begin
                        udp5000_pulse <= 1'b1;
                        udp5000_count <= udp5000_count + 32'd1;
                    end
                end

                // UDP payload byte 0..3：FPGV 魔数。
                if((byte_idx >= udp_base_idx + 11'd8) && (byte_idx <= udp_base_idx + 11'd11))
                    magic_shift <= {magic_shift[23:0], gmii_rxd};

                if(byte_idx == udp_base_idx + 11'd11) begin
                    fpgv_ok <= udp_port_ok && ({magic_shift[23:0], gmii_rxd} == 32'h46_50_47_56);
                end

                // FPGV header:
                // payload[0:3]   = "FPGV"
                // payload[4]     = version
                // payload[5]     = mode
                // payload[6]     = pixel_format
                // payload[8:11]  = frame_id
                // payload[12:13] = width
                // payload[14:15] = height
                // payload[16:17] = packet_id
                // payload[18:19] = packet_total
                // payload[20:21] = payload_len
                // payload[24:27] = byte_offset
                if(byte_idx == udp_base_idx + 11'd12) last_version      <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd13) last_mode         <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd14) last_pixel_format <= gmii_rxd;

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

                if(byte_idx == udp_base_idx + 11'd28) last_payload_len[15:8] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd29) last_payload_len[7:0]  <= gmii_rxd;

                if(byte_idx == udp_base_idx + 11'd32) last_byte_offset[31:24] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd33) last_byte_offset[23:16] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd34) last_byte_offset[15:8]  <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd35) last_byte_offset[7:0]   <= gmii_rxd;

                // payload[31] 是 FPGV 头最后一个字节。到这里所有关键字段已经锁存完成。
                if(byte_idx == udp_base_idx + 11'd39) begin
                    if(fpgv_ok) begin
                        fpgv_packet_pulse <= 1'b1;
                        fpgv_packet_count <= fpgv_packet_count + 32'd1;

                        if(!stream_started) begin
                            // 第一次进入时可能正好位于一帧中间，因此先建立基准，不马上报错。
                            stream_started        <= 1'b1;
                            current_frame_id      <= last_frame_id;
                            packets_seen_in_frame <= 16'd1;
                            expected_packet_id    <= last_packet_id + 16'd1;
                            current_frame_seq_ok  <= 1'b1;
                            packet_seq_ok         <= 1'b1;
                        end else if(last_frame_id != current_frame_id) begin
                            // 新 frame_id 出现，开启新帧检查。
                            current_frame_id      <= last_frame_id;
                            packets_seen_in_frame <= 16'd1;
                            expected_packet_id    <= last_packet_id + 16'd1;

                            if(last_packet_id == 16'd0) begin
                                current_frame_seq_ok <= 1'b1;
                                packet_seq_ok        <= 1'b1;
                            end else begin
                                current_frame_seq_ok <= 1'b0;
                                packet_seq_ok        <= 1'b0;
                                seq_error_pulse      <= 1'b1;
                                error_pulse          <= 1'b1;
                                seq_error_count      <= seq_error_count + 32'd1;
                                frame_drop_count     <= frame_drop_count + 32'd1;
                            end
                        end else begin
                            // 同一帧内检查 packet_id 是否连续。
                            packets_seen_in_frame <= packets_seen_in_frame + 16'd1;
                            expected_packet_id    <= last_packet_id + 16'd1;

                            if(last_packet_id != expected_packet_id) begin
                                current_frame_seq_ok <= 1'b0;
                                packet_seq_ok        <= 1'b0;
                                seq_error_pulse      <= 1'b1;
                                error_pulse          <= 1'b1;
                                seq_error_count      <= seq_error_count + 32'd1;
                            end else begin
                                packet_seq_ok <= current_frame_seq_ok;
                            end

                            // 一帧最后一个包：packet_id == packet_total - 1。
                            if(last_packet_id == (last_packet_total - 16'd1)) begin
                                if(((packets_seen_in_frame + 16'd1) == last_packet_total) &&
                                   current_frame_seq_ok &&
                                   (last_packet_total == EXPECTED_PACKET_TOTAL)) begin
                                    frame_complete_pulse <= 1'b1;
                                    complete_frame_count <= complete_frame_count + 32'd1;
                                end else begin
                                    error_pulse      <= 1'b1;
                                    frame_drop_count <= frame_drop_count + 32'd1;
                                end
                            end
                        end
                    end
                end

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
        debug_led[0] <= blink;                           // 时钟心跳
        debug_led[1] <= gmii_rx_dv;                      // GMII RX_DV 活动
        debug_led[2] <= |fpgv_packet_count[7:0];         // 已识别到 FPGV 包
        debug_led[3] <= packet_seq_ok;                   // packet_id 当前连续
        debug_led[4] <= |complete_frame_count[7:0];      // 已收到至少一帧完整 750 包
        debug_led[5] <= (|seq_error_count[7:0]) | (|frame_drop_count[7:0]) | (|rx_error_count[7:0]);
        debug_led[6] <= last_packet_id[0];               // 最近 packet_id bit0
        debug_led[7] <= last_frame_id[0];                // 最近 frame_id bit0
    end
end

endmodule
