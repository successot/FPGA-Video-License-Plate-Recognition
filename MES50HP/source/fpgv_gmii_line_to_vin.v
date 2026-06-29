`timescale 1ns / 1ps
`default_nettype wire
// -----------------------------------------------------------------------------
// Stage7F11: CH2 FPGV packet_id ring repacker, non-disruptive packet0.
//
// Base: Stage7F4 image-producing path.
// Non-regression:
//   - No strict packet_id/byte_offset/continuous-frame gate is added.
//   - Payload is still accepted with the same loose checks as Stage7F4:
//       FPGV magic, 800x480, nonzero/even payload_len <= 1536.
//   - payload_len gate is kept so Ethernet FCS/tail bytes cannot enter image.
//
// Why this version:
//   Stage7F4/F6 still used a pure sequential rx_row/rx_col stream and only two
//   line buffers.  UDP/FPGV packets are 1024 bytes = 512 pixels, while one source
//   line is 1600 bytes = 800 pixels.  If a packet is repeated, lost, or delayed,
//   all following pixels keep accumulating at the wrong row/column and the HDMI
//   image becomes horizontal blocks / tearing.
//   Stage7F11 places each packet using packet_id modulo the known 25-packet /
//   16-line pattern.  One bad packet no longer shifts the entire rest of frame.
// -----------------------------------------------------------------------------
module fpgv_gmii_line_to_vin #(
    parameter [47:0] LOCAL_MAC = 48'h02_00_00_00_50_01,
    parameter [31:0] LOCAL_IP  = 32'hC0A8_0164,
    parameter [15:0] UDP_PORT  = 16'd5000,
    parameter        ACCEPT_BROADCAST = 1,
    parameter [11:0] SRC_W = 12'd800,
    parameter [11:0] SRC_H = 12'd480,
    parameter [11:0] OUT_W = 12'd1280,
    parameter [11:0] OUT_H = 12'd720
)(
    input             clk,
    input             rst_n,

    input      [7:0]  gmii_rxd,
    input             gmii_rx_dv,
    input             gmii_rx_er,

    output reg        vin_vsync,
    output reg        vin_de,
    output reg [15:0] vin_data,

    output reg        udp_packet_pulse,
    output reg        fpgv_packet_pulse,
    output reg        frame_written_pulse,
    output reg        overflow_pulse,

    output reg [31:0] udp_packet_count,
    output reg [31:0] fpgv_packet_count,
    output reg [31:0] frame_written_count,
    output reg [31:0] overflow_count,

    output reg [31:0] last_frame_id,
    output reg [15:0] last_packet_id,
    output reg [15:0] last_width,
    output reg [15:0] last_height,
    output reg [7:0]  debug_state
);

localparam S_IDLE  = 2'd0;
localparam S_PREAM = 2'd1;
localparam S_FRAME = 2'd2;

localparam O_IDLE  = 2'd0;
localparam O_VSYNC = 2'd1;
localparam O_LINE  = 2'd2;
localparam O_GAP   = 2'd3;

// 2 blocks * 16 rows/block * 1024 address stride.  Only columns 0..799 are used.
// This power-of-two stride avoids constant multiply on the RAM address path.
localparam [15:0] MAX_PAYLOAD_BYTES = 16'd1536;
localparam [15:0] LINE_WAIT_MAX     = 16'd8191;

function [4:0] pid_group25;
    input [15:0] pid;
    begin
        if(pid < 16'd25)        pid_group25 = 5'd0;
        else if(pid < 16'd50)   pid_group25 = 5'd1;
        else if(pid < 16'd75)   pid_group25 = 5'd2;
        else if(pid < 16'd100)  pid_group25 = 5'd3;
        else if(pid < 16'd125)  pid_group25 = 5'd4;
        else if(pid < 16'd150)  pid_group25 = 5'd5;
        else if(pid < 16'd175)  pid_group25 = 5'd6;
        else if(pid < 16'd200)  pid_group25 = 5'd7;
        else if(pid < 16'd225)  pid_group25 = 5'd8;
        else if(pid < 16'd250)  pid_group25 = 5'd9;
        else if(pid < 16'd275)  pid_group25 = 5'd10;
        else if(pid < 16'd300)  pid_group25 = 5'd11;
        else if(pid < 16'd325)  pid_group25 = 5'd12;
        else if(pid < 16'd350)  pid_group25 = 5'd13;
        else if(pid < 16'd375)  pid_group25 = 5'd14;
        else if(pid < 16'd400)  pid_group25 = 5'd15;
        else if(pid < 16'd425)  pid_group25 = 5'd16;
        else if(pid < 16'd450)  pid_group25 = 5'd17;
        else if(pid < 16'd475)  pid_group25 = 5'd18;
        else if(pid < 16'd500)  pid_group25 = 5'd19;
        else if(pid < 16'd525)  pid_group25 = 5'd20;
        else if(pid < 16'd550)  pid_group25 = 5'd21;
        else if(pid < 16'd575)  pid_group25 = 5'd22;
        else if(pid < 16'd600)  pid_group25 = 5'd23;
        else if(pid < 16'd625)  pid_group25 = 5'd24;
        else if(pid < 16'd650)  pid_group25 = 5'd25;
        else if(pid < 16'd675)  pid_group25 = 5'd26;
        else if(pid < 16'd700)  pid_group25 = 5'd27;
        else if(pid < 16'd725)  pid_group25 = 5'd28;
        else                    pid_group25 = 5'd29;
    end
endfunction

function [4:0] pid_mod25;
    input [15:0] pid;
    reg [4:0] g;
    begin
        g = pid_group25(pid);
        pid_mod25 = pid - (g * 5'd25);
    end
endfunction

function [3:0] row_mod25;
    input [4:0] m;
    begin
        case(m)
        5'd0:  row_mod25 = 4'd0;
        5'd1:  row_mod25 = 4'd0;
        5'd2:  row_mod25 = 4'd1;
        5'd3:  row_mod25 = 4'd1;
        5'd4:  row_mod25 = 4'd2;
        5'd5:  row_mod25 = 4'd3;
        5'd6:  row_mod25 = 4'd3;
        5'd7:  row_mod25 = 4'd4;
        5'd8:  row_mod25 = 4'd5;
        5'd9:  row_mod25 = 4'd5;
        5'd10: row_mod25 = 4'd6;
        5'd11: row_mod25 = 4'd7;
        5'd12: row_mod25 = 4'd7;
        5'd13: row_mod25 = 4'd8;
        5'd14: row_mod25 = 4'd8;
        5'd15: row_mod25 = 4'd9;
        5'd16: row_mod25 = 4'd10;
        5'd17: row_mod25 = 4'd10;
        5'd18: row_mod25 = 4'd11;
        5'd19: row_mod25 = 4'd12;
        5'd20: row_mod25 = 4'd12;
        5'd21: row_mod25 = 4'd13;
        5'd22: row_mod25 = 4'd14;
        5'd23: row_mod25 = 4'd14;
        default: row_mod25 = 4'd15;
        endcase
    end
endfunction

function [9:0] col_mod25;
    input [4:0] m;
    begin
        case(m)
        5'd0:  col_mod25 = 10'd0;
        5'd1:  col_mod25 = 10'd512;
        5'd2:  col_mod25 = 10'd224;
        5'd3:  col_mod25 = 10'd736;
        5'd4:  col_mod25 = 10'd448;
        5'd5:  col_mod25 = 10'd160;
        5'd6:  col_mod25 = 10'd672;
        5'd7:  col_mod25 = 10'd384;
        5'd8:  col_mod25 = 10'd96;
        5'd9:  col_mod25 = 10'd608;
        5'd10: col_mod25 = 10'd320;
        5'd11: col_mod25 = 10'd32;
        5'd12: col_mod25 = 10'd544;
        5'd13: col_mod25 = 10'd256;
        5'd14: col_mod25 = 10'd768;
        5'd15: col_mod25 = 10'd480;
        5'd16: col_mod25 = 10'd192;
        5'd17: col_mod25 = 10'd704;
        5'd18: col_mod25 = 10'd416;
        5'd19: col_mod25 = 10'd128;
        5'd20: col_mod25 = 10'd640;
        5'd21: col_mod25 = 10'd352;
        5'd22: col_mod25 = 10'd64;
        5'd23: col_mod25 = 10'd576;
        default: col_mod25 = 10'd288;
        endcase
    end
endfunction

reg [1:0]  rx_state;
reg [1:0]  out_state;

reg        dv_d1;
wire       dv_rise = gmii_rx_dv & ~dv_d1;

reg [2:0]  pre_cnt;
reg [10:0] byte_idx;
reg [10:0] udp_base_idx;

reg        eth_accept;
reg        ipv4_accept;
reg        udp_accept;
reg        fpgv_accept;
reg        payload_active;
reg [15:0] payload_byte_cnt;

reg [15:0] eth_type;
reg [15:0] udp_dst_port;
reg [47:0] dst_mac_shift;
reg [31:0] dst_ip_shift;
reg [31:0] magic_shift;

reg [31:0] hdr_frame_id;
reg [15:0] hdr_width;
reg [15:0] hdr_height;
reg [15:0] hdr_packet_id;
reg [15:0] hdr_packet_total;
reg [15:0] hdr_payload_len;
reg [31:0] hdr_byte_offset;

wire [4:0] pkt_group_w = pid_group25(hdr_packet_id);
wire [4:0] pkt_mod_w   = pid_mod25(hdr_packet_id);
wire [3:0] pkt_row_w   = row_mod25(pkt_mod_w);
wire [9:0] pkt_col_w   = col_mod25(pkt_mod_w);
wire [11:0] pkt_abs_row_w = {3'd0, pkt_group_w, 4'b0000} + {8'd0, pkt_row_w};
wire        pkt_block_w   = pkt_group_w[0];

reg [7:0]  pix_hi;
reg        pix_phase;
reg [11:0] wr_row;
reg [9:0]  wr_col;
reg        wr_block;

// 2 * 16 * 1024 memory. Address = {block, local_row[3:0], col[9:0]}.
reg [15:0] line_mem [0:32767];
reg [15:0] line_ready0;
reg [15:0] line_ready1;

reg        frame_out_active;
reg [11:0] out_row;
reg [11:0] out_col;
reg [11:0] vsync_stretch_cnt;
reg [15:0] line_wait_cnt;

wire out_src_phase   = (out_row < SRC_H);
wire out_block       = out_row[4];
wire [3:0] out_lrow  = out_row[3:0];
wire out_line_ready  = out_block ? line_ready1[out_lrow] : line_ready0[out_lrow];
wire out_line_timeout = (line_wait_cnt >= LINE_WAIT_MAX);

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rx_state            <= S_IDLE;
        out_state           <= O_IDLE;
        dv_d1               <= 1'b0;
        pre_cnt             <= 3'd0;
        byte_idx            <= 11'd0;
        udp_base_idx        <= 11'd34;

        eth_accept          <= 1'b0;
        ipv4_accept         <= 1'b0;
        udp_accept          <= 1'b0;
        fpgv_accept         <= 1'b0;
        payload_active      <= 1'b0;
        payload_byte_cnt    <= 16'd0;

        eth_type            <= 16'd0;
        udp_dst_port        <= 16'd0;
        dst_mac_shift       <= 48'd0;
        dst_ip_shift        <= 32'd0;
        magic_shift         <= 32'd0;

        hdr_frame_id        <= 32'd0;
        hdr_width           <= 16'd0;
        hdr_height          <= 16'd0;
        hdr_packet_id       <= 16'd0;
        hdr_packet_total    <= 16'd0;
        hdr_payload_len     <= 16'd0;
        hdr_byte_offset     <= 32'd0;

        pix_hi              <= 8'd0;
        pix_phase           <= 1'b0;
        wr_row              <= 12'd0;
        wr_col              <= 10'd0;
        wr_block            <= 1'b0;
        line_ready0         <= 16'd0;
        line_ready1         <= 16'd0;

        frame_out_active    <= 1'b0;
        out_row             <= 12'd0;
        out_col             <= 12'd0;
        vsync_stretch_cnt   <= 12'd0;
        line_wait_cnt       <= 16'd0;

        vin_vsync           <= 1'b0;
        vin_de              <= 1'b0;
        vin_data            <= 16'd0;

        udp_packet_pulse    <= 1'b0;
        fpgv_packet_pulse   <= 1'b0;
        frame_written_pulse <= 1'b0;
        overflow_pulse      <= 1'b0;

        udp_packet_count    <= 32'd0;
        fpgv_packet_count   <= 32'd0;
        frame_written_count <= 32'd0;
        overflow_count      <= 32'd0;

        last_frame_id       <= 32'd0;
        last_packet_id      <= 16'd0;
        last_width          <= 16'd0;
        last_height         <= 16'd0;
        debug_state         <= 8'd0;
    end else begin
        dv_d1 <= gmii_rx_dv;

        if(vsync_stretch_cnt != 12'd0) begin
            vin_vsync         <= 1'b1;
            vsync_stretch_cnt <= vsync_stretch_cnt - 12'd1;
        end else begin
            vin_vsync         <= 1'b0;
        end

        vin_de              <= 1'b0;
        udp_packet_pulse    <= 1'b0;
        fpgv_packet_pulse   <= 1'b0;
        frame_written_pulse <= 1'b0;
        overflow_pulse      <= 1'b0;

        if(gmii_rx_dv && gmii_rx_er) begin
            overflow_pulse <= 1'b1;
            overflow_count <= overflow_count + 32'd1;
        end

        // ---------------------------------------------------------------------
        // GMII Ethernet/IPv4/UDP/FPGV parser.
        // ---------------------------------------------------------------------
        case(rx_state)
        S_IDLE: begin
            payload_active   <= 1'b0;
            payload_byte_cnt <= 16'd0;
            pix_phase        <= 1'b0;
            if(dv_rise) begin
                pre_cnt        <= 3'd0;
                byte_idx       <= 11'd0;
                udp_base_idx   <= 11'd34;
                eth_accept     <= 1'b0;
                ipv4_accept    <= 1'b0;
                udp_accept     <= 1'b0;
                fpgv_accept    <= 1'b0;
                dst_mac_shift  <= 48'd0;
                dst_ip_shift   <= 32'd0;
                magic_shift    <= 32'd0;

                if(gmii_rxd == 8'h55) begin
                    rx_state <= S_PREAM;
                    pre_cnt  <= 3'd1;
                end else begin
                    rx_state      <= S_FRAME;
                    dst_mac_shift <= {40'd0, gmii_rxd};
                    byte_idx      <= 11'd1;
                end
            end
        end

        S_PREAM: begin
            if(!gmii_rx_dv) begin
                rx_state <= S_IDLE;
            end else if(gmii_rxd == 8'h55) begin
                if(pre_cnt != 3'd7)
                    pre_cnt <= pre_cnt + 3'd1;
            end else if(gmii_rxd == 8'hD5) begin
                rx_state <= S_FRAME;
                byte_idx <= 11'd0;
            end else begin
                rx_state      <= S_FRAME;
                byte_idx      <= 11'd1;
                dst_mac_shift <= {40'd0, gmii_rxd};
            end
        end

        S_FRAME: begin
            if(!gmii_rx_dv) begin
                rx_state          <= S_IDLE;
                payload_active    <= 1'b0;
                payload_byte_cnt  <= 16'd0;
                pix_phase         <= 1'b0;
            end else begin
                if(byte_idx <= 11'd5)
                    dst_mac_shift <= {dst_mac_shift[39:0], gmii_rxd};

                if(byte_idx == 11'd5) begin
                    eth_accept <= (({dst_mac_shift[39:0], gmii_rxd} == LOCAL_MAC) ||
                                  (ACCEPT_BROADCAST && ({dst_mac_shift[39:0], gmii_rxd} == 48'hFF_FF_FF_FF_FF_FF)));
                end

                if(byte_idx == 11'd12)
                    eth_type[15:8] <= gmii_rxd;

                if(byte_idx == 11'd13) begin
                    eth_type[7:0] <= gmii_rxd;
                    if({eth_type[15:8], gmii_rxd} != 16'h0800)
                        eth_accept <= 1'b0;
                end

                if(byte_idx == 11'd14)
                    udp_base_idx <= 11'd14 + {5'd0, gmii_rxd[3:0], 2'b00};

                if(byte_idx == 11'd23)
                    ipv4_accept <= eth_accept && (eth_type == 16'h0800) && (gmii_rxd == 8'd17);

                if((byte_idx >= 11'd30) && (byte_idx <= 11'd33))
                    dst_ip_shift <= {dst_ip_shift[23:0], gmii_rxd};

                if(byte_idx == 11'd33) begin
                    if({dst_ip_shift[23:0], gmii_rxd} != LOCAL_IP)
                        ipv4_accept <= 1'b0;
                end

                if(byte_idx == udp_base_idx + 11'd2)
                    udp_dst_port[15:8] <= gmii_rxd;

                if(byte_idx == udp_base_idx + 11'd3) begin
                    udp_dst_port[7:0] <= gmii_rxd;
                    udp_accept <= ipv4_accept && ({udp_dst_port[15:8], gmii_rxd} == UDP_PORT);
                    if(ipv4_accept && ({udp_dst_port[15:8], gmii_rxd} == UDP_PORT)) begin
                        udp_packet_pulse <= 1'b1;
                        udp_packet_count <= udp_packet_count + 32'd1;
                    end
                end

                if((byte_idx >= udp_base_idx + 11'd8) && (byte_idx <= udp_base_idx + 11'd11))
                    magic_shift <= {magic_shift[23:0], gmii_rxd};

                if(byte_idx == udp_base_idx + 11'd11) begin
                    fpgv_accept <= udp_accept && ({magic_shift[23:0], gmii_rxd} == 32'h46_50_47_56);
                    if(udp_accept && ({magic_shift[23:0], gmii_rxd} == 32'h46_50_47_56)) begin
                        fpgv_packet_pulse <= 1'b1;
                        fpgv_packet_count <= fpgv_packet_count + 32'd1;
                    end
                end

                if(byte_idx == udp_base_idx + 11'd16) hdr_frame_id[31:24] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd17) hdr_frame_id[23:16] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd18) hdr_frame_id[15:8]  <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd19) hdr_frame_id[7:0]   <= gmii_rxd;

                if(byte_idx == udp_base_idx + 11'd20) hdr_width[15:8]  <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd21) hdr_width[7:0]   <= gmii_rxd;

                if(byte_idx == udp_base_idx + 11'd22) hdr_height[15:8] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd23) hdr_height[7:0]  <= gmii_rxd;

                if(byte_idx == udp_base_idx + 11'd24) hdr_packet_id[15:8] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd25) hdr_packet_id[7:0]  <= gmii_rxd;

                if(byte_idx == udp_base_idx + 11'd26) hdr_packet_total[15:8] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd27) hdr_packet_total[7:0]  <= gmii_rxd;

                if(byte_idx == udp_base_idx + 11'd28) hdr_payload_len[15:8] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd29) hdr_payload_len[7:0]  <= gmii_rxd;

                if(byte_idx == udp_base_idx + 11'd32) hdr_byte_offset[31:24] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd33) hdr_byte_offset[23:16] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd34) hdr_byte_offset[15:8]  <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd35) hdr_byte_offset[7:0]   <= gmii_rxd;

                if(byte_idx == udp_base_idx + 11'd39) begin
                    payload_byte_cnt <= 16'd0;
                    pix_phase        <= 1'b0;
                    payload_active   <= fpgv_accept &&
                                        (hdr_width  == {4'd0, SRC_W}) &&
                                        (hdr_height == {4'd0, SRC_H}) &&
                                        (hdr_payload_len != 16'd0) &&
                                        (hdr_payload_len <= MAX_PAYLOAD_BYTES) &&
                                        (hdr_payload_len[0] == 1'b0);

                    last_frame_id    <= hdr_frame_id;
                    last_packet_id   <= hdr_packet_id;
                    last_width       <= hdr_width;
                    last_height      <= hdr_height;

                    // Position by packet_id pattern.  This is placement, not a
                    // strict gate: even if packet_id jumps, payload is still
                    // accepted and written to its own approximate block.
                    wr_row   <= pkt_abs_row_w;
                    wr_col   <= pkt_col_w;
                    wr_block <= pkt_block_w;

                    // Clear the destination 16-line block when a new 25-packet
                    // block starts.  Packet 0 starts a visible frame immediately
                    // so HDMI/fram_buf cannot get stuck on color bars.
                    if(pkt_mod_w == 5'd0) begin
                        if(pkt_block_w)
                            line_ready1 <= 16'd0;
                        else
                            line_ready0 <= 16'd0;
                    end

                    if(hdr_packet_id == 16'd0) begin
                        // Stage7F11: packet0 must not restart the DDR-write
                        // output FSM while a 1280x720 padded frame is already
                        // being emitted.  Keep payload permissive; only make the
                        // frame-start side effect non-disruptive.
                        if(!frame_out_active) begin
                            line_ready0         <= 16'd0;
                            line_ready1         <= 16'd0;
                            frame_out_active    <= 1'b1;
                            out_row             <= 12'd0;
                            out_col             <= 12'd0;
                            out_state           <= O_VSYNC;
                            line_wait_cnt       <= 16'd0;
                        end
                    end
                end

                if((byte_idx >= udp_base_idx + 11'd40) &&
                   payload_active &&
                   (payload_byte_cnt < hdr_payload_len)) begin
                    payload_byte_cnt <= payload_byte_cnt + 16'd1;

                    if(!pix_phase) begin
                        pix_hi    <= gmii_rxd;
                        pix_phase <= 1'b1;
                    end else begin
                        pix_phase <= 1'b0;

                        if((wr_row < SRC_H) && (wr_col < SRC_W[9:0])) begin
                            line_mem[{wr_block, wr_row[3:0], wr_col}] <= {pix_hi, gmii_rxd};

                            if(wr_col == SRC_W[9:0] - 1'b1) begin
                                if(wr_block)
                                    line_ready1[wr_row[3:0]] <= 1'b1;
                                else
                                    line_ready0[wr_row[3:0]] <= 1'b1;

                                wr_col <= 10'd0;
                                wr_row <= wr_row + 12'd1;
                                if(wr_row[3:0] == 4'd15)
                                    wr_block <= ~wr_block;
                            end else begin
                                wr_col <= wr_col + 10'd1;
                            end
                        end
                    end

                    if((payload_byte_cnt + 16'd1) >= hdr_payload_len) begin
                        payload_active   <= 1'b0;
                        payload_byte_cnt <= 16'd0;
                        pix_phase        <= 1'b0;
                    end
                end

                if(byte_idx != 11'h7ff)
                    byte_idx <= byte_idx + 11'd1;
            end
        end

        default: rx_state <= S_IDLE;
        endcase

        // ---------------------------------------------------------------------
        // Camera-like line output toward fram_buf.
        // Wait for a source line to be ready, but use a timeout so the video path
        // never stays in color bars forever if one line/packet is damaged.
        // ---------------------------------------------------------------------
        case(out_state)
        O_IDLE: begin
            vin_de <= 1'b0;

            if(frame_out_active && (vsync_stretch_cnt == 12'd0)) begin
                if(out_src_phase) begin
                    if(out_line_ready || out_line_timeout) begin
                        out_col       <= 12'd0;
                        out_state     <= O_LINE;
                        line_wait_cnt <= 16'd0;
                    end else begin
                        line_wait_cnt <= line_wait_cnt + 16'd1;
                    end
                end else begin
                    out_col       <= 12'd0;
                    out_state     <= O_LINE;
                    line_wait_cnt <= 16'd0;
                end
            end
        end

        O_VSYNC: begin
            vin_vsync         <= 1'b1;
            vsync_stretch_cnt <= 12'd128;
            out_state         <= O_IDLE;
        end

        O_LINE: begin
            vin_de <= 1'b1;

            if(out_row < SRC_H) begin
                if(out_col < SRC_W)
                    vin_data <= line_mem[{out_block, out_lrow, out_col[9:0]}];
                else
                    vin_data <= 16'h0000;
            end else begin
                vin_data <= 16'h0000;
            end

            if(out_col == OUT_W - 1'b1) begin
                out_col   <= 12'd0;
                out_state <= O_GAP;

                if(out_row < SRC_H) begin
                    if(out_block)
                        line_ready1[out_lrow] <= 1'b0;
                    else
                        line_ready0[out_lrow] <= 1'b0;
                end

                if(out_row == OUT_H - 1'b1) begin
                    frame_out_active    <= 1'b0;
                    out_row             <= 12'd0;
                    frame_written_pulse <= 1'b1;
                    frame_written_count <= frame_written_count + 32'd1;
                end else begin
                    out_row <= out_row + 12'd1;
                end
            end else begin
                out_col <= out_col + 12'd1;
            end
        end

        O_GAP: begin
            vin_de    <= 1'b0;
            vin_data  <= 16'h0000;
            out_state <= O_IDLE;
        end

        default: out_state <= O_IDLE;
        endcase

        debug_state <= {rx_state, out_state, line_ready1[0], line_ready0[0], frame_out_active, payload_active};
    end
end

endmodule
