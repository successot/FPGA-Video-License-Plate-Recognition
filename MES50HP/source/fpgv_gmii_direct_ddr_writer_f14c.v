`timescale 1ns / 1ps
`default_nettype wire
// -----------------------------------------------------------------------------
// Stage7F14C compile-fix direct DDR writer.
//
// Fixes the F14B compile hang caused by pkt_mem being inferred as a huge
// register/mux network.  Packet payload storage now uses the existing Pango
// wr_fram_buf SDPRAM IP:
//     GMII clock domain writes 32-bit words
//     DDR clock domain reads 256-bit beats
// Metadata crosses clock domains through a small single-write/single-read
// Gray-code FIFO.  There is exactly one write point to each storage object.
// -----------------------------------------------------------------------------
module fpgv_gmii_direct_ddr_writer_f14c #(
    parameter [47:0] LOCAL_MAC = 48'h02_00_00_00_50_01,
    parameter [31:0] LOCAL_IP  = 32'hC0A8_0164,
    parameter [15:0] UDP_PORT  = 16'd5000,
    parameter        ACCEPT_BROADCAST = 1,
    parameter [11:0] SRC_W = 12'd800,
    parameter [11:0] SRC_H = 12'd480,
    parameter        ADDR_WIDTH = 28,
    parameter [ADDR_WIDTH-1:0] ADDR_OFFSET = {ADDR_WIDTH{1'b0}},
    parameter        DQ_WIDTH   = 32,
    parameter        LEN_WIDTH  = 32,
    parameter        LINE_ADDR_WIDTH = 19
)(
    input                    gmii_clk,
    input                    gmii_rstn,
    input      [7:0]         gmii_rxd,
    input                    gmii_rx_dv,
    input                    gmii_rx_er,

    input                    ddr_clk,
    input                    ddr_rstn,

    output reg               ddr_wreq,
    output reg [ADDR_WIDTH-1:0] ddr_waddr,
    output reg [LEN_WIDTH-1:0]  ddr_wr_len,
    input                    ddr_wrdy,
    input                    ddr_wdone,
    output     [DQ_WIDTH*8-1:0] ddr_wdata,
    input                    ddr_wdata_req,

    output reg               frame_done_bank,
    output reg               frame_done_toggle,
    output reg [31:0]        frame_done_count,

    output reg [31:0]        udp_packet_count,
    output reg [31:0]        fpgv_packet_count,
    output reg [31:0]        accepted_packet_count,
    output reg [31:0]        overflow_count,
    output reg [31:0]        last_frame_id,
    output reg [15:0]        last_packet_id,
    output reg [15:0]        last_packet_total,
    output reg [15:0]        last_payload_len,
    output reg [31:0]        last_byte_offset,
    output reg [7:0]         debug_state
);

localparam S_IDLE  = 2'd0;
localparam S_PREAM = 2'd1;
localparam S_FRAME = 2'd2;

localparam [15:0] MAX_PAYLOAD_BYTES = 16'd1536;
localparam [31:0] FRAME_BYTES = 32'd800 * 32'd480 * 32'd2;
localparam SLOT_NUM       = 4;
localparam SLOT_WORDS     = 512; // 2048 byte/slot, enough for 1536-byte payload
localparam SLOT_BEATS     = 64;  // 64 * 256-bit = 2048 byte
localparam META_WIDTH     = ADDR_WIDTH + 16 + 1 + 1 + 2; // addr, beats, publish, bank, slot

// -----------------------------------------------------------------------------
// RX-domain slot ownership.  DDR releases a slot by toggling rel_toggle_ddr.
// -----------------------------------------------------------------------------
reg [SLOT_NUM-1:0] slot_busy_rx;
reg [SLOT_NUM-1:0] rel_toggle_ddr;
reg [SLOT_NUM-1:0] rel_sync1_rx;
reg [SLOT_NUM-1:0] rel_sync2_rx;
reg [SLOT_NUM-1:0] rel_sync3_rx;
wire [SLOT_NUM-1:0] rel_pulse_rx = rel_sync2_rx ^ rel_sync3_rx;

always @(posedge gmii_clk or negedge gmii_rstn) begin
    if(!gmii_rstn) begin
        rel_sync1_rx <= 4'b0000;
        rel_sync2_rx <= 4'b0000;
        rel_sync3_rx <= 4'b0000;
    end else begin
        rel_sync1_rx <= rel_toggle_ddr;
        rel_sync2_rx <= rel_sync1_rx;
        rel_sync3_rx <= rel_sync2_rx;
    end
end

function [1:0] first_free_slot;
    input [3:0] busy;
    begin
        if(!busy[0])      first_free_slot = 2'd0;
        else if(!busy[1]) first_free_slot = 2'd1;
        else if(!busy[2]) first_free_slot = 2'd2;
        else              first_free_slot = 2'd3;
    end
endfunction

function [31:0] offset_from_packet;
    input [15:0] packet_id;
    input [15:0] payload_len;
    begin
        offset_from_packet = packet_id * payload_len;
    end
endfunction

// -----------------------------------------------------------------------------
// Ethernet/IPv4/UDP/FPGV parser and packet payload writer.
// -----------------------------------------------------------------------------
reg [1:0]  rx_state;
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
reg        drop_payload;
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

reg        rx_write_bank;
reg        rx_frame_seen;
reg        pkt_bank;
reg [1:0]  pkt_slot;
reg [31:0] pkt_byte_offset;
reg [15:0] pkt_beat_count;
reg        pkt_publish;

reg [7:0]  byte_pack0;
reg [7:0]  byte_pack1;
reg [7:0]  byte_pack2;
reg [1:0]  byte_phase;
reg [8:0]  word_index;
reg [31:0] ram_wr_data;
reg [11:0] ram_wr_addr;
reg        ram_wr_en;

wire [31:0] hdr_offset_effective = (hdr_byte_offset < FRAME_BYTES) ? hdr_byte_offset : offset_from_packet(hdr_packet_id, hdr_payload_len);
wire [15:0] hdr_beats_effective  = (hdr_payload_len[4:0] == 5'd0) ? (hdr_payload_len >> 5) : ((hdr_payload_len >> 5) + 16'd1);
wire        hdr_last_by_id        = (hdr_packet_total != 16'd0) && (hdr_packet_id == hdr_packet_total - 16'd1);
wire        hdr_last_by_offset    = (hdr_offset_effective + hdr_payload_len) >= FRAME_BYTES;
wire        hdr_valid_size        = (hdr_width == {4'd0,SRC_W}) && (hdr_height == {4'd0,SRC_H});
wire        hdr_valid_payload     = (hdr_payload_len != 16'd0) && (hdr_payload_len <= MAX_PAYLOAD_BYTES);
wire [1:0]  alloc_slot_w          = first_free_slot(slot_busy_rx);
wire        have_free_slot_w      = (slot_busy_rx != 4'b1111);

// Metadata FIFO write side.
reg                   meta_wr_en;
reg [META_WIDTH-1:0]  meta_wr_data;
wire                  meta_full;

wire [ADDR_WIDTH-1:0] meta_addr_w = ADDR_OFFSET + {pkt_bank, pkt_byte_offset[LINE_ADDR_WIDTH+1:2]};
wire [META_WIDTH-1:0] meta_data_packet_w = {pkt_slot, pkt_bank, pkt_publish, pkt_beat_count, meta_addr_w};
wire [META_WIDTH-1:0] meta_data_publish_w = {2'd0, rx_write_bank, 1'b1, 16'd0, {ADDR_WIDTH{1'b0}}};

always @(posedge gmii_clk or negedge gmii_rstn) begin
    if(!gmii_rstn) begin
        rx_state              <= S_IDLE;
        dv_d1                 <= 1'b0;
        pre_cnt               <= 3'd0;
        byte_idx              <= 11'd0;
        udp_base_idx          <= 11'd34;
        eth_accept            <= 1'b0;
        ipv4_accept           <= 1'b0;
        udp_accept            <= 1'b0;
        fpgv_accept           <= 1'b0;
        payload_active        <= 1'b0;
        drop_payload          <= 1'b0;
        payload_byte_cnt      <= 16'd0;
        eth_type              <= 16'd0;
        udp_dst_port          <= 16'd0;
        dst_mac_shift         <= 48'd0;
        dst_ip_shift          <= 32'd0;
        magic_shift           <= 32'd0;
        hdr_frame_id          <= 32'd0;
        hdr_width             <= 16'd0;
        hdr_height            <= 16'd0;
        hdr_packet_id         <= 16'd0;
        hdr_packet_total      <= 16'd0;
        hdr_payload_len       <= 16'd0;
        hdr_byte_offset       <= 32'd0;
        rx_write_bank         <= 1'b0;
        rx_frame_seen         <= 1'b0;
        pkt_bank              <= 1'b0;
        pkt_slot              <= 2'd0;
        pkt_byte_offset       <= 32'd0;
        pkt_beat_count        <= 16'd0;
        pkt_publish           <= 1'b0;
        byte_pack0            <= 8'd0;
        byte_pack1            <= 8'd0;
        byte_pack2            <= 8'd0;
        byte_phase            <= 2'd0;
        word_index            <= 9'd0;
        ram_wr_data           <= 32'd0;
        ram_wr_addr           <= 12'd0;
        ram_wr_en             <= 1'b0;
        slot_busy_rx          <= 4'b0000;
        meta_wr_en            <= 1'b0;
        meta_wr_data          <= {META_WIDTH{1'b0}};
        udp_packet_count      <= 32'd0;
        fpgv_packet_count     <= 32'd0;
        accepted_packet_count <= 32'd0;
        overflow_count        <= 32'd0;
        last_frame_id         <= 32'd0;
        last_packet_id        <= 16'd0;
        last_packet_total     <= 16'd0;
        last_payload_len      <= 16'd0;
        last_byte_offset      <= 32'd0;
        debug_state           <= 8'd0;
    end else begin
        dv_d1      <= gmii_rx_dv;
        ram_wr_en  <= 1'b0;
        meta_wr_en <= 1'b0;
        slot_busy_rx <= slot_busy_rx & ~rel_pulse_rx;

        if(gmii_rx_dv && gmii_rx_er)
            overflow_count <= overflow_count + 32'd1;

        case(rx_state)
        S_IDLE: begin
            payload_active   <= 1'b0;
            drop_payload     <= 1'b0;
            payload_byte_cnt <= 16'd0;
            byte_phase       <= 2'd0;
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
                if(pre_cnt != 3'd7) pre_cnt <= pre_cnt + 3'd1;
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
                rx_state       <= S_IDLE;
                payload_active <= 1'b0;
                drop_payload   <= 1'b0;
                payload_byte_cnt <= 16'd0;
                byte_phase     <= 2'd0;
            end else begin
                if(byte_idx <= 11'd5)
                    dst_mac_shift <= {dst_mac_shift[39:0], gmii_rxd};
                if(byte_idx == 11'd5)
                    eth_accept <= (({dst_mac_shift[39:0], gmii_rxd} == LOCAL_MAC) ||
                                  (ACCEPT_BROADCAST && ({dst_mac_shift[39:0], gmii_rxd} == 48'hFF_FF_FF_FF_FF_FF)));
                if(byte_idx == 11'd12) eth_type[15:8] <= gmii_rxd;
                if(byte_idx == 11'd13) begin
                    eth_type[7:0] <= gmii_rxd;
                    if({eth_type[15:8], gmii_rxd} != 16'h0800) eth_accept <= 1'b0;
                end
                if(byte_idx == 11'd14) udp_base_idx <= 11'd14 + {5'd0, gmii_rxd[3:0], 2'b00};
                if(byte_idx == 11'd23) ipv4_accept <= eth_accept && (eth_type == 16'h0800) && (gmii_rxd == 8'd17);
                if((byte_idx >= 11'd30) && (byte_idx <= 11'd33)) dst_ip_shift <= {dst_ip_shift[23:0], gmii_rxd};
                if(byte_idx == 11'd33) begin
                    if({dst_ip_shift[23:0], gmii_rxd} != LOCAL_IP) ipv4_accept <= 1'b0;
                end
                if(byte_idx == udp_base_idx + 11'd2) udp_dst_port[15:8] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd3) begin
                    udp_dst_port[7:0] <= gmii_rxd;
                    udp_accept <= ipv4_accept && ({udp_dst_port[15:8], gmii_rxd} == UDP_PORT);
                    if(ipv4_accept && ({udp_dst_port[15:8], gmii_rxd} == UDP_PORT))
                        udp_packet_count <= udp_packet_count + 32'd1;
                end
                if((byte_idx >= udp_base_idx + 11'd8) && (byte_idx <= udp_base_idx + 11'd11))
                    magic_shift <= {magic_shift[23:0], gmii_rxd};
                if(byte_idx == udp_base_idx + 11'd11) begin
                    fpgv_accept <= udp_accept && ({magic_shift[23:0], gmii_rxd} == 32'h46_50_47_56);
                    if(udp_accept && ({magic_shift[23:0], gmii_rxd} == 32'h46_50_47_56))
                        fpgv_packet_count <= fpgv_packet_count + 32'd1;
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
                    byte_phase       <= 2'd0;
                    word_index       <= 9'd0;
                    last_frame_id    <= hdr_frame_id;
                    last_packet_id   <= hdr_packet_id;
                    last_packet_total<= hdr_packet_total;
                    last_payload_len <= hdr_payload_len;
                    last_byte_offset <= hdr_offset_effective;

                    if(hdr_packet_id == 16'd0) begin
                        if(rx_frame_seen && !meta_full) begin
                            meta_wr_en   <= 1'b1;
                            meta_wr_data <= meta_data_publish_w;
                        end
                        rx_write_bank <= ~rx_write_bank;
                        rx_frame_seen <= 1'b1;
                    end

                    pkt_bank        <= (hdr_packet_id == 16'd0) ? ~rx_write_bank : rx_write_bank;
                    pkt_byte_offset <= hdr_offset_effective;
                    pkt_beat_count  <= hdr_beats_effective;
                    pkt_publish     <= hdr_last_by_id || hdr_last_by_offset;

                    if(fpgv_accept && hdr_valid_size && hdr_valid_payload && have_free_slot_w && !meta_full) begin
                        pkt_slot <= alloc_slot_w;
                        slot_busy_rx[alloc_slot_w] <= 1'b1;
                        payload_active <= 1'b1;
                        drop_payload   <= 1'b0;
                    end else begin
                        payload_active <= 1'b0;
                        drop_payload   <= fpgv_accept;
                        if(fpgv_accept) overflow_count <= overflow_count + 32'd1;
                    end
                end

                if((byte_idx >= udp_base_idx + 11'd40) && payload_active && (payload_byte_cnt < hdr_payload_len)) begin
                    payload_byte_cnt <= payload_byte_cnt + 16'd1;
                    case(byte_phase)
                    2'd0: begin byte_pack0 <= gmii_rxd; byte_phase <= 2'd1; end
                    2'd1: begin byte_pack1 <= gmii_rxd; byte_phase <= 2'd2; end
                    2'd2: begin byte_pack2 <= gmii_rxd; byte_phase <= 2'd3; end
                    default: begin
                        ram_wr_data <= {byte_pack0, byte_pack1, byte_pack2, gmii_rxd};
                        ram_wr_addr <= {1'b0, pkt_slot, word_index};
                        ram_wr_en   <= 1'b1;
                        word_index  <= word_index + 9'd1;
                        byte_phase  <= 2'd0;
                    end
                    endcase

                    if((payload_byte_cnt + 16'd1) >= hdr_payload_len) begin
                        payload_active <= 1'b0;
                        byte_phase     <= 2'd0;
                        accepted_packet_count <= accepted_packet_count + 32'd1;
                        if(!meta_full) begin
                            meta_wr_en   <= 1'b1;
                            meta_wr_data <= meta_data_packet_w;
                        end else begin
                            overflow_count <= overflow_count + 32'd1;
                        end
                    end
                end

                if(byte_idx != 11'h7ff)
                    byte_idx <= byte_idx + 11'd1;
            end
        end
        default: rx_state <= S_IDLE;
        endcase

        debug_state <= {rx_state, payload_active, drop_payload, meta_full, slot_busy_rx[3:0]};
    end
end

// Payload storage: clean single-write Pango SDPRAM IP.
reg [8:0] ram_rd_addr;
wire [255:0] ram_rd_data;
wr_fram_buf u_pkt_payload_ram (
    .wr_data (ram_wr_data),
    .wr_addr (ram_wr_addr),
    .wr_en   (ram_wr_en),
    .wr_clk  (gmii_clk),
    .wr_rst  (~gmii_rstn),
    .rd_data (ram_rd_data),
    .rd_addr (ram_rd_addr),
    .rd_clk  (ddr_clk),
    .rd_rst  (~ddr_rstn)
);

// -----------------------------------------------------------------------------
// DDR-domain metadata consumer.
// -----------------------------------------------------------------------------
wire [META_WIDTH-1:0] meta_rd_data;
wire                  meta_empty;
reg                   meta_rd_en;
reg [1:0]             cur_slot;
reg                   cur_bank;
reg                   cur_publish;
reg [15:0]            cur_beats;
reg [15:0]            beat_idx;
reg                   cmd_active;
reg                   cmd_started;

wire [ADDR_WIDTH-1:0] meta_addr;
wire [15:0]           meta_beats;
wire                  meta_publish;
wire                  meta_bank;
wire [1:0]            meta_slot;
assign {meta_slot, meta_bank, meta_publish, meta_beats, meta_addr} = meta_rd_data;

async_fifo_gray #(.DSIZE(META_WIDTH), .ASIZE(3)) u_meta_fifo (
    .wclk   (gmii_clk),
    .wrst_n (gmii_rstn),
    .winc   (meta_wr_en),
    .wdata  (meta_wr_data),
    .wfull  (meta_full),
    .rclk   (ddr_clk),
    .rrst_n (ddr_rstn),
    .rinc   (meta_rd_en),
    .rdata  (meta_rd_data),
    .rempty (meta_empty)
);

always @(posedge ddr_clk or negedge ddr_rstn) begin
    if(!ddr_rstn) begin
        ddr_wreq          <= 1'b0;
        ddr_waddr         <= {ADDR_WIDTH{1'b0}};
        ddr_wr_len        <= {LEN_WIDTH{1'b0}};
        meta_rd_en        <= 1'b0;
        cur_slot          <= 2'd0;
        cur_bank          <= 1'b0;
        cur_publish       <= 1'b0;
        cur_beats         <= 16'd0;
        beat_idx          <= 16'd0;
        cmd_active        <= 1'b0;
        cmd_started       <= 1'b0;
        ram_rd_addr       <= 9'd0;
        frame_done_bank   <= 1'b0;
        frame_done_toggle <= 1'b0;
        frame_done_count  <= 32'd0;
        rel_toggle_ddr    <= 4'b0000;
    end else begin
        meta_rd_en <= 1'b0;

        if(!cmd_active && !meta_empty) begin
            meta_rd_en <= 1'b1;
            cur_slot    <= meta_slot;
            cur_bank    <= meta_bank;
            cur_publish <= meta_publish;
            cur_beats   <= meta_beats;
            beat_idx    <= 16'd0;
            ram_rd_addr <= {1'b0, meta_slot, 6'd0};
            if(meta_beats == 16'd0) begin
                if(meta_publish) begin
                    frame_done_bank   <= meta_bank;
                    frame_done_toggle <= ~frame_done_toggle;
                    frame_done_count  <= frame_done_count + 32'd1;
                end
            end else begin
                ddr_waddr   <= meta_addr;
                ddr_wr_len  <= {{(LEN_WIDTH-16){1'b0}}, meta_beats};
                ddr_wreq    <= 1'b1;
                cmd_active  <= 1'b1;
                cmd_started <= 1'b0;
            end
        end else if(cmd_active) begin
            if(ddr_wdata_req) begin
                ddr_wreq    <= 1'b0;
                cmd_started <= 1'b1;
                if(beat_idx < cur_beats - 16'd1) begin
                    beat_idx    <= beat_idx + 16'd1;
                    ram_rd_addr <= {1'b0, cur_slot, beat_idx[5:0] + 6'd1};
                end
            end
            if(ddr_wdone) begin
                cmd_active <= 1'b0;
                ddr_wreq   <= 1'b0;
                rel_toggle_ddr[cur_slot] <= ~rel_toggle_ddr[cur_slot];
                if(cur_publish) begin
                    frame_done_bank   <= cur_bank;
                    frame_done_toggle <= ~frame_done_toggle;
                    frame_done_count  <= frame_done_count + 32'd1;
                end
            end
        end else begin
            ddr_wreq <= 1'b0;
        end
    end
end

assign ddr_wdata = ram_rd_data;

endmodule
