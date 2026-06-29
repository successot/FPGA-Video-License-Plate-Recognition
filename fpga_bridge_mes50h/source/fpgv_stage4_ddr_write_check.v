`timescale 1ns / 1ps
`default_nettype wire
module fpgv_stage4_ddr_write_check #(
    parameter [47:0] LOCAL_MAC = 48'h02_00_00_00_50_01,
    parameter [31:0] LOCAL_IP  = 32'hC0A8_0164,       // 192.168.1.100
    parameter [15:0] UDP_PORT  = 16'd5000,
    parameter [15:0] EXPECTED_PACKET_TOTAL = 16'd750,
    parameter [31:0] EXPECTED_FRAME_BYTES  = 32'd768000,
    parameter [15:0] EXPECTED_PAYLOAD_LEN  = 16'd1024,
    parameter [31:0] FRAME0_BASE_ADDR = 32'h0000_0000,
    parameter [31:0] FRAME1_BASE_ADDR = 32'h0010_0000,
    parameter        CHECK_DEST_MAC = 1'b1,
    parameter        CHECK_DEST_IP  = 1'b1
)(
    input             rx_clk,
    input             rx_rst_n,

    input      [7:0]  gmii_rxd,
    input             gmii_rx_dv,
    input             gmii_rx_er,

    // 当前工程没有真实 DDR3 IP。ddr_clk/ddr_rst_n 是“DDR 写侧验证时钟/复位”。
    // 顶层默认先接到已验证的 p0_sgmii_clk_u10/p0_rx_rstn_sync_u10，保证可直接综合验证。
    input             ddr_clk,
    input             ddr_rst_n,

    output reg        raw_frame_pulse,
    output reg        udp5000_pulse,
    output reg        fpgv_packet_pulse,
    output reg        fifo_wr_pulse,
    output reg        fifo_rd_pulse,
    output reg        ddr_cmd_en,
    output reg        ddr_wdata_en,
    output reg        ddr_frame_done_pulse,
    output reg        seq_error_pulse,
    output reg        length_error_pulse,
    output reg        fifo_error_pulse,
    output reg        error_pulse,

    output reg [31:0] raw_frame_count,
    output reg [31:0] udp5000_count,
    output reg [31:0] fpgv_packet_count,
    output reg [31:0] fifo_write_byte_count,
    output reg [31:0] fifo_read_byte_count,
    output reg [31:0] ddr_write_word_count,
    output reg [31:0] ddr_complete_frame_count,
    output reg [31:0] seq_error_count,
    output reg [31:0] length_error_count,
    output reg [31:0] fifo_overflow_count,
    output reg [31:0] fifo_underflow_count,
    output reg [31:0] rx_error_count,

    output reg [31:0] last_frame_id,
    output reg [15:0] last_packet_id,
    output reg [15:0] last_packet_total,
    output reg [15:0] last_width,
    output reg [15:0] last_height,
    output reg [15:0] last_payload_len,
    output reg [31:0] last_byte_offset,
    output reg [15:0] expected_packet_id,
    output reg [31:0] rx_frame_payload_byte_count,
    output reg [15:0] rx_packet_payload_byte_count,

    output reg [31:0] ddr_addr,
    output reg [31:0] ddr_wdata,
    output reg [31:0] ddr_frame_byte_count,
    output reg        frame_buffer_index,

    output     [12:0] fifo_wr_level_approx,
    output     [12:0] fifo_rd_level_approx,
    output            fifo_full,
    output            fifo_empty,

    output reg        packet_seq_ok,
    output reg        payload_fifo_write_active,
    output reg        ddr_write_active,
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
reg        packet_header_accept;

reg        fifo_wr_en;
reg [7:0]  fifo_wr_data;
wire       fifo_overflow_sticky;
wire       fifo_underflow_sticky;
reg        fifo_full_d1;
reg        fifo_empty_d1;

reg        fifo_rd_en;
wire [7:0] fifo_rd_data;
reg        fifo_rd_data_valid;

reg [1:0]  ddr_byte_lane;
reg [31:0] ddr_pack_word;

reg [23:0] blink_cnt;
reg        blink;

wire dv_rise = gmii_rx_dv & ~dv_d1;

wire [10:0] payload_start_idx = udp_base_idx + 11'd8;
wire [10:0] image_data_start_idx = udp_base_idx + 11'd40;

always @(posedge rx_clk or negedge rx_rst_n) begin
    if(!rx_rst_n)
        dv_d1 <= 1'b0;
    else
        dv_d1 <= gmii_rx_dv;
end

fpgv_stage4_async_byte_fifo #(
    .ADDR_WIDTH(12)
) u_stage4_payload_fifo (
    .wr_clk          (rx_clk),
    .wr_rst_n        (rx_rst_n),
    .wr_en           (fifo_wr_en),
    .wr_data         (fifo_wr_data),
    .full            (fifo_full),
    .overflow        (fifo_overflow_sticky),

    .rd_clk          (ddr_clk),
    .rd_rst_n        (ddr_rst_n),
    .rd_en           (fifo_rd_en),
    .rd_data         (fifo_rd_data),
    .empty           (fifo_empty),
    .underflow       (fifo_underflow_sticky),

    .wr_level_approx (fifo_wr_level_approx),
    .rd_level_approx (fifo_rd_level_approx)
);

// RX 时钟域：GMII/UDP/FPGV 解析、payload 写入 FIFO。
always @(posedge rx_clk or negedge rx_rst_n) begin
    if(!rx_rst_n) begin
        state                         <= S_IDLE;
        byte_idx                      <= 11'd0;
        pre_cnt                       <= 3'd0;

        dst_mac_shift                 <= 48'd0;
        dst_ip_shift                  <= 32'd0;
        eth_type                      <= 16'd0;
        udp_dst_port                  <= 16'd0;
        magic_shift                   <= 32'd0;
        udp_base_idx                  <= 11'd34;

        dest_mac_ok                   <= 1'b0;
        ipv4_ok                       <= 1'b0;
        udp_proto_ok                  <= 1'b0;
        dst_ip_ok                     <= 1'b0;
        udp_port_ok                   <= 1'b0;
        fpgv_ok                       <= 1'b0;

        stream_started                <= 1'b0;
        current_frame_id              <= 32'd0;
        packets_seen_in_frame         <= 16'd0;
        current_frame_seq_ok          <= 1'b1;
        expected_packet_id            <= 16'd0;
        packet_seq_ok                 <= 1'b0;
        packet_header_accept          <= 1'b0;
        payload_fifo_write_active     <= 1'b0;

        raw_frame_pulse               <= 1'b0;
        udp5000_pulse                 <= 1'b0;
        fpgv_packet_pulse             <= 1'b0;
        fifo_wr_pulse                 <= 1'b0;
        seq_error_pulse               <= 1'b0;
        length_error_pulse            <= 1'b0;
        fifo_error_pulse              <= 1'b0;
        error_pulse                   <= 1'b0;

        raw_frame_count               <= 32'd0;
        udp5000_count                 <= 32'd0;
        fpgv_packet_count             <= 32'd0;
        fifo_write_byte_count         <= 32'd0;
        seq_error_count               <= 32'd0;
        length_error_count            <= 32'd0;
        fifo_overflow_count           <= 32'd0;
        rx_error_count                <= 32'd0;

        last_frame_id                 <= 32'd0;
        last_packet_id                <= 16'd0;
        last_packet_total             <= 16'd0;
        last_width                    <= 16'd0;
        last_height                   <= 16'd0;
        last_payload_len              <= 16'd0;
        last_byte_offset              <= 32'd0;
        rx_frame_payload_byte_count   <= 32'd0;
        rx_packet_payload_byte_count  <= 16'd0;

        fifo_wr_en                    <= 1'b0;
        fifo_wr_data                  <= 8'd0;
        fifo_full_d1                  <= 1'b0;
    end else begin
        raw_frame_pulse       <= 1'b0;
        udp5000_pulse         <= 1'b0;
        fpgv_packet_pulse     <= 1'b0;
        fifo_wr_pulse         <= 1'b0;
        seq_error_pulse       <= 1'b0;
        length_error_pulse    <= 1'b0;
        fifo_error_pulse      <= 1'b0;
        error_pulse           <= 1'b0;
        fifo_wr_en            <= 1'b0;
        fifo_wr_data          <= gmii_rxd;
        fifo_full_d1          <= fifo_full;

        if(fifo_wr_en && fifo_full) begin
            fifo_error_pulse    <= 1'b1;
            error_pulse         <= 1'b1;
            fifo_overflow_count <= fifo_overflow_count + 32'd1;
        end

        if(gmii_rx_dv && gmii_rx_er) begin
            rx_error_count <= rx_error_count + 32'd1;
            error_pulse    <= 1'b1;
        end

        case(state)
        S_IDLE: begin
            payload_fifo_write_active <= 1'b0;
            if(dv_rise) begin
                byte_idx                      <= 11'd0;
                pre_cnt                       <= 3'd0;
                dst_mac_shift                 <= 48'd0;
                dst_ip_shift                  <= 32'd0;
                eth_type                      <= 16'd0;
                udp_dst_port                  <= 16'd0;
                magic_shift                   <= 32'd0;
                udp_base_idx                  <= 11'd34;
                dest_mac_ok                   <= 1'b0;
                ipv4_ok                       <= 1'b0;
                udp_proto_ok                  <= 1'b0;
                dst_ip_ok                     <= 1'b0;
                udp_port_ok                   <= 1'b0;
                fpgv_ok                       <= 1'b0;
                packet_header_accept          <= 1'b0;
                rx_packet_payload_byte_count  <= 16'd0;

                if(gmii_rxd == 8'h55) begin
                    state   <= S_PREAM;
                    pre_cnt <= 3'd1;
                end else begin
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
                payload_fifo_write_active <= 1'b0;
            end else begin
                if(byte_idx <= 11'd5)
                    dst_mac_shift <= {dst_mac_shift[39:0], gmii_rxd};

                if(byte_idx == 11'd5) begin
                    if(CHECK_DEST_MAC)
                        dest_mac_ok <= (({dst_mac_shift[39:0], gmii_rxd} == LOCAL_MAC) ||
                                        ({dst_mac_shift[39:0], gmii_rxd} == 48'hFF_FF_FF_FF_FF_FF));
                    else
                        dest_mac_ok <= 1'b1;
                end

                if(byte_idx == 11'd12)
                    eth_type[15:8] <= gmii_rxd;

                if(byte_idx == 11'd13) begin
                    eth_type[7:0] <= gmii_rxd;
                    ipv4_ok       <= ({eth_type[15:8], gmii_rxd} == 16'h0800);
                end

                if(byte_idx == 11'd14)
                    udp_base_idx <= 11'd14 + {5'd0, gmii_rxd[3:0], 2'b00};

                if(byte_idx == 11'd23)
                    udp_proto_ok <= dest_mac_ok && ipv4_ok && (gmii_rxd == 8'd17);

                if((byte_idx >= 11'd30) && (byte_idx <= 11'd33))
                    dst_ip_shift <= {dst_ip_shift[23:0], gmii_rxd};

                if(byte_idx == 11'd33) begin
                    if(CHECK_DEST_IP)
                        dst_ip_ok <= ({dst_ip_shift[23:0], gmii_rxd} == LOCAL_IP);
                    else
                        dst_ip_ok <= 1'b1;
                end

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

                if((byte_idx >= payload_start_idx) && (byte_idx <= udp_base_idx + 11'd11))
                    magic_shift <= {magic_shift[23:0], gmii_rxd};

                if(byte_idx == udp_base_idx + 11'd11)
                    fpgv_ok <= udp_port_ok && ({magic_shift[23:0], gmii_rxd} == 32'h46_50_47_56);

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

                if(byte_idx == udp_base_idx + 11'd39) begin
                    rx_packet_payload_byte_count <= 16'd0;
                    payload_fifo_write_active    <= fpgv_ok;
                    packet_header_accept         <= fpgv_ok;

                    if(fpgv_ok) begin
                        fpgv_packet_pulse <= 1'b1;
                        fpgv_packet_count <= fpgv_packet_count + 32'd1;

                        if(last_payload_len != EXPECTED_PAYLOAD_LEN) begin
                            length_error_pulse <= 1'b1;
                            error_pulse        <= 1'b1;
                            length_error_count <= length_error_count + 32'd1;
                        end

                        if(!stream_started) begin
                            stream_started              <= 1'b1;
                            current_frame_id            <= last_frame_id;
                            packets_seen_in_frame       <= 16'd1;
                            expected_packet_id          <= last_packet_id + 16'd1;
                            current_frame_seq_ok        <= 1'b1;
                            packet_seq_ok               <= 1'b1;
                            rx_frame_payload_byte_count <= 32'd0;
                        end else if(last_frame_id != current_frame_id) begin
                            current_frame_id            <= last_frame_id;
                            packets_seen_in_frame       <= 16'd1;
                            expected_packet_id          <= last_packet_id + 16'd1;
                            rx_frame_payload_byte_count <= 32'd0;

                            if(last_packet_id == 16'd0) begin
                                current_frame_seq_ok <= 1'b1;
                                packet_seq_ok        <= 1'b1;
                            end else begin
                                current_frame_seq_ok <= 1'b0;
                                packet_seq_ok        <= 1'b0;
                                seq_error_pulse      <= 1'b1;
                                error_pulse          <= 1'b1;
                                seq_error_count      <= seq_error_count + 32'd1;
                            end
                        end else begin
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
                        end
                    end
                end

                if(packet_header_accept &&
                   (byte_idx >= image_data_start_idx) &&
                   (rx_packet_payload_byte_count < last_payload_len)) begin

                    rx_packet_payload_byte_count <= rx_packet_payload_byte_count + 16'd1;
                    rx_frame_payload_byte_count  <= rx_frame_payload_byte_count + 32'd1;

                    if(!fifo_full) begin
                        fifo_wr_en            <= 1'b1;
                        fifo_wr_data          <= gmii_rxd;
                        fifo_wr_pulse         <= 1'b1;
                        fifo_write_byte_count <= fifo_write_byte_count + 32'd1;
                    end else begin
                        fifo_error_pulse    <= 1'b1;
                        error_pulse         <= 1'b1;
                        fifo_overflow_count <= fifo_overflow_count + 32'd1;
                    end

                    if(rx_packet_payload_byte_count == (last_payload_len - 16'd1)) begin
                        payload_fifo_write_active <= 1'b0;
                        packet_header_accept      <= 1'b0;

                        if(last_packet_id == (last_packet_total - 16'd1)) begin
                            if(((rx_frame_payload_byte_count + 32'd1) != EXPECTED_FRAME_BYTES) ||
                               (!current_frame_seq_ok) ||
                               (last_packet_total != EXPECTED_PACKET_TOTAL)) begin
                                length_error_pulse <= 1'b1;
                                error_pulse        <= 1'b1;
                                length_error_count <= length_error_count + 32'd1;
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

// DDR 写侧时钟域：从 FIFO 读出字节，每 4 字节打包成 32bit 写请求。
// 当前是抽象写接口，ddr_cmd_en/ddr_wdata_en/ddr_addr/ddr_wdata 均可接 ILA 观察。
always @(posedge ddr_clk or negedge ddr_rst_n) begin
    if(!ddr_rst_n) begin
        fifo_rd_en                  <= 1'b0;
        fifo_rd_data_valid          <= 1'b0;
        fifo_rd_pulse               <= 1'b0;
        ddr_cmd_en                  <= 1'b0;
        ddr_wdata_en                <= 1'b0;
        ddr_frame_done_pulse        <= 1'b0;
        ddr_write_active            <= 1'b0;

        fifo_read_byte_count        <= 32'd0;
        ddr_write_word_count        <= 32'd0;
        ddr_complete_frame_count    <= 32'd0;
        fifo_underflow_count        <= 32'd0;

        ddr_byte_lane               <= 2'd0;
        ddr_pack_word               <= 32'd0;
        ddr_addr                    <= FRAME0_BASE_ADDR;
        ddr_wdata                   <= 32'd0;
        ddr_frame_byte_count        <= 32'd0;
        frame_buffer_index          <= 1'b0;
        fifo_empty_d1               <= 1'b0;
    end else begin
        fifo_rd_en           <= 1'b0;
        fifo_rd_pulse        <= 1'b0;
        ddr_cmd_en           <= 1'b0;
        ddr_wdata_en         <= 1'b0;
        ddr_frame_done_pulse <= 1'b0;
        fifo_empty_d1        <= fifo_empty;

        if(!fifo_empty) begin
            fifo_rd_en         <= 1'b1;
            fifo_rd_data_valid <= 1'b1;
        end else begin
            fifo_rd_data_valid <= 1'b0;
        end

        if(fifo_rd_en && fifo_empty) begin
            fifo_underflow_count <= fifo_underflow_count + 32'd1;
        end

        if(fifo_rd_data_valid) begin
            fifo_rd_pulse        <= 1'b1;
            ddr_write_active     <= 1'b1;
            fifo_read_byte_count <= fifo_read_byte_count + 32'd1;

            case(ddr_byte_lane)
            2'd0: begin
                ddr_pack_word[31:24] <= fifo_rd_data;
                ddr_byte_lane        <= 2'd1;
            end
            2'd1: begin
                ddr_pack_word[23:16] <= fifo_rd_data;
                ddr_byte_lane        <= 2'd2;
            end
            2'd2: begin
                ddr_pack_word[15:8] <= fifo_rd_data;
                ddr_byte_lane       <= 2'd3;
            end
            default: begin
                ddr_pack_word[7:0]  <= fifo_rd_data;
                ddr_wdata           <= {ddr_pack_word[31:8], fifo_rd_data};
                ddr_cmd_en          <= 1'b1;
                ddr_wdata_en        <= 1'b1;
                ddr_write_word_count <= ddr_write_word_count + 32'd1;
                ddr_byte_lane       <= 2'd0;

                if(ddr_frame_byte_count == (EXPECTED_FRAME_BYTES - 32'd1)) begin
                    ddr_frame_done_pulse     <= 1'b1;
                    ddr_complete_frame_count <= ddr_complete_frame_count + 32'd1;
                    frame_buffer_index       <= ~frame_buffer_index;
                    ddr_frame_byte_count     <= 32'd0;
                    ddr_addr                 <= frame_buffer_index ? FRAME0_BASE_ADDR : FRAME1_BASE_ADDR;
                    ddr_write_active         <= 1'b0;
                end else begin
                    ddr_frame_byte_count <= ddr_frame_byte_count + 32'd1;
                    ddr_addr             <= ddr_addr + 32'd4;
                end
            end
            endcase

            if(ddr_byte_lane != 2'd3)
                ddr_frame_byte_count <= ddr_frame_byte_count + 32'd1;
        end else begin
            ddr_write_active <= 1'b0;
        end
    end
end

always @(posedge ddr_clk or negedge ddr_rst_n) begin
    if(!ddr_rst_n) begin
        blink_cnt <= 24'd0;
        blink     <= 1'b0;
    end else begin
        blink_cnt <= blink_cnt + 24'd1;
        if(blink_cnt == 24'd0)
            blink <= ~blink;
    end
end

always @(posedge ddr_clk or negedge ddr_rst_n) begin
    if(!ddr_rst_n) begin
        debug_led <= 8'h00;
    end else begin
        debug_led[0] <= blink;                           // DDR 写侧验证时钟心跳
        debug_led[1] <= gmii_rx_dv;                      // GMII RX_DV 活动
        debug_led[2] <= fifo_wr_pulse;                   // payload 正在写入 FIFO
        debug_led[3] <= |ddr_write_word_count[7:0];      // 已产生 DDR 32bit 写请求
        debug_led[4] <= |ddr_complete_frame_count[7:0];  // 已完成至少一帧抽象 DDR 写入
        debug_led[5] <= (|seq_error_count[7:0]) |
                        (|length_error_count[7:0]) |
                        (|fifo_overflow_count[7:0]) |
                        (|fifo_underflow_count[7:0]) |
                        (|rx_error_count[7:0]);          // 错误指示
        debug_led[6] <= frame_buffer_index;              // 当前模拟帧 buffer
        debug_led[7] <= last_frame_id[0];                // 最近 frame_id bit0
    end
end

endmodule
