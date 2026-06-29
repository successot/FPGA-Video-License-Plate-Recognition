`timescale 1ns / 1ps
`default_nettype wire
// -----------------------------------------------------------------------------
// Stage7F14X wrap-aware previous-bank direct DDR writer.
//
// Fixes the F14B compile hang caused by pkt_mem being inferred as a huge
// register/mux network.  Packet payload storage now uses the existing Pango
// wr_fram_buf SDPRAM IP:
//     GMII clock domain writes 32-bit words
//     DDR clock domain reads 256-bit beats
// Metadata crosses clock domains through a small single-write/single-read
// Gray-code FIFO.  There is exactly one write point to each storage object.
// -----------------------------------------------------------------------------
// F14R_HANDOFF_NOTE:
// This source intentionally keeps the F14Q force-last-publish behavior:
// PUBLISH_ON_LAST_PACKET=1 and MIN_PACKETS_FOR_RELAXED_PUBLISH=1.
// It is a handoff/debug baseline, not a final quality-tuned build.
// New work should first confirm whether LED7/LED8 turn on and whether HDMI leaves black.
// If it still stays black, inspect rx_relaxed_complete_w, rx_publish_candidate_w,
// meta_wr_en/meta_rd_en, dbg_wr_cmd_en, shared_wr_cmd_done, and frame_done_count.
// If it displays with noise, gradually raise MIN_PACKETS_FOR_RELAXED_PUBLISH.

module fpgv_gmii_direct_ddr_writer_f14d #(
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
    parameter        LINE_ADDR_WIDTH = 19,
    // F14D: lightweight packet completeness checker. 1024 bits/bank is enough
    // for the current 800x480/1024-byte-payload stream (750 packets/frame).
    parameter [15:0] MAX_PACKET_NUM = 16'd1024,
    parameter [15:0] NOMINAL_PAYLOAD_BYTES = 16'd1024,
    // 1: reject non-packet0 packets whose frame_id does not match current bank.
    // The ATK sender increments frame_id correctly, so use this to avoid
    // cross-frame late packets corrupting the current bank.
    parameter        GATE_FRAME_ID = 0,
    // F14P: physical link/debug traces show occasional packet drop/overflow.
    // Strict 750/750 bitmap completion can keep LED7 black forever. F14Q
    // forces publication at a valid last packet so HDMI can leave black-screen mode.
    parameter        PUBLISH_ON_LAST_PACKET = 1,
    parameter [15:0] MIN_PACKETS_FOR_RELAXED_PUBLISH = 16'd1,
    // F14X: stable display path. When packet0 OR a large packet_id/byte_offset wrap arrives, latch the
    // PREVIOUS write bank number, then submit a zero-beat publish marker only
    // after any pending packet metadata has drained.  Latching the bank is the
    // key fix versus the F14U experiment: a delayed marker must not sample the
    // already-flipped rx_write_bank and publish the new/current bank.
    parameter        PUBLISH_PREV_BANK_ON_PACKET0 = 1,
    parameter [15:0] MIN_PACKETS_FOR_PREV_BANK_PUBLISH = 16'd16,
    // Diagnostic only: when enabled, any successful DDR write burst publishes
    // the current bank. F14T default is OFF because it causes visible tearing.
    parameter        FORCE_FRAME_DONE_AFTER_ANY_WRITE = 0
)(
    input                    gmii_clk,
    input                    gmii_rstn,
    input      [7:0]         gmii_rxd,
    input                    gmii_rx_dv,
    input                    gmii_rx_er,

    input                    ddr_clk,
    input                    ddr_rstn,

    output reg               ddr_wreq /* synthesis PAP_MARK_DEBUG="true" */,
    output reg [ADDR_WIDTH-1:0] ddr_waddr,
    output reg [LEN_WIDTH-1:0]  ddr_wr_len,
    input                    ddr_wrdy,
    input                    ddr_wdone /* synthesis PAP_MARK_DEBUG="true" */,
    output     [DQ_WIDTH*8-1:0] ddr_wdata,
    input                    ddr_wdata_req,

    output reg               frame_done_bank /* synthesis PAP_MARK_DEBUG="true" */,
    output reg               frame_done_toggle /* synthesis PAP_MARK_DEBUG="true" */,
    output reg [31:0]        frame_done_count /* synthesis PAP_MARK_DEBUG="true" */,

    output reg [31:0]        udp_packet_count /* synthesis PAP_MARK_DEBUG="true" */,
    output reg [31:0]        fpgv_packet_count /* synthesis PAP_MARK_DEBUG="true" */,
    output reg [31:0]        accepted_packet_count /* synthesis PAP_MARK_DEBUG="true" */,
    output reg [31:0]        overflow_count /* synthesis PAP_MARK_DEBUG="true" */,
    output reg [31:0]        last_frame_id,
    output reg [15:0]        last_packet_id /* synthesis PAP_MARK_DEBUG="true" */,
    output reg [15:0]        last_packet_total /* synthesis PAP_MARK_DEBUG="true" */,
    output reg [15:0]        last_payload_len /* synthesis PAP_MARK_DEBUG="true" */,
    output reg [31:0]        last_byte_offset /* synthesis PAP_MARK_DEBUG="true" */,
    output reg [7:0]         debug_state /* synthesis PAP_MARK_DEBUG="true" */,

    // F14W: explicit debug ports.  These make CH2 probes visible at fram_buf/top
    // level with deterministic names, instead of relying on deep internal nets
    // that Pango may rename or hide from Select Net.
    output                  dbg_hdr_accept,
    output                  dbg_hdr_last_by_id,
    output                  dbg_hdr_last_by_offset,
    output                  dbg_rx_prevbank_publish_candidate,
    output                  dbg_rx_relaxed_complete,
    output                  dbg_rx_publish_candidate,
    output                  dbg_pkt_publish,
    output                  dbg_meta_wr_en,
    output                  dbg_meta_pending_valid,
    output                  dbg_meta_full,
    output                  dbg_meta_empty,
    output                  dbg_meta_rd_en,
    output                  dbg_cmd_active,
    output                  dbg_cmd_started,
    output                  dbg_prev_publish_pending,
    output                  dbg_prev_publish_bank,
    output [31:0]           dbg_prev_publish_latched_count,
    output [31:0]           dbg_prevbank_publish_count,
    output [31:0]           dbg_prevbank_skip_count,
    output [15:0]           dbg_prevbank_packet_count_at_event,
    output [31:0]           dbg_meta_wr_count,
    output [31:0]           dbg_meta_rd_count,
    output [31:0]           dbg_ddr_wreq_count,
    output [31:0]           dbg_ddr_wdone_count,
    output [31:0]           dbg_force_done_count,
    output [15:0]           dbg_last_good_packet_id,
    output [15:0]           dbg_last_good_packet_total,
    output [15:0]           dbg_last_good_payload_len,
    output [31:0]           dbg_last_good_byte_offset,
    output [31:0]           dbg_relaxed_publish_count,
    output [31:0]           dbg_strict_publish_count,
    // F14Y: top-searchable packet-drop classification and staging pressure probes.
    output [31:0]           dbg_drop_bad_header_count,
    output [31:0]           dbg_drop_no_free_slot_count,
    output [31:0]           dbg_drop_meta_pending_count,
    output [31:0]           dbg_drop_meta_full_count,
    output [31:0]           dbg_drop_gmii_error_count,
    output [31:0]           dbg_drop_payload_error_count,
    output [31:0]           dbg_duplicate_packet_count,
    output [15:0]           dbg_slot_busy_count,
    output [15:0]           dbg_slot_busy_max,
    output                  dbg_have_free_slot
);

localparam S_IDLE  = 2'd0;
localparam S_PREAM = 2'd1;
localparam S_FRAME = 2'd2;

localparam [15:0] MAX_PAYLOAD_BYTES = 16'd1024;
localparam [31:0] FRAME_BYTES = 32'd800 * 32'd480 * 32'd2;
// F14M: ATK payload is exactly 1024 bytes, so use the same 16KB Pango SDPRAM
// as sixteen 1KB packet slots instead of eight 2KB slots.  This greatly reduces
// packet drops when DDR read/write arbitration is busy.
localparam SLOT_NUM       = 16;
localparam SLOT_WORDS     = 256; // 1024 byte/slot
localparam SLOT_BEATS     = 32;  // 32 * 256-bit = 1024 byte
localparam SLOT_BITS      = 4;
localparam META_WIDTH     = ADDR_WIDTH + 16 + 1 + 1 + SLOT_BITS; // addr, beats, publish, bank, slot
localparam [3:0] META_COMMIT_DELAY = 4'd12; // gmii_clk cycles after final packet RAM write

// -----------------------------------------------------------------------------
// RX-domain slot ownership.  DDR releases a slot by toggling rel_toggle_ddr.
// -----------------------------------------------------------------------------
reg [SLOT_NUM-1:0] slot_busy_rx /* synthesis PAP_MARK_DEBUG="true" */;
reg [SLOT_NUM-1:0] rel_toggle_ddr;
reg [SLOT_NUM-1:0] rel_sync1_rx;
reg [SLOT_NUM-1:0] rel_sync2_rx;
reg [SLOT_NUM-1:0] rel_sync3_rx;
wire [SLOT_NUM-1:0] rel_pulse_rx = rel_sync2_rx ^ rel_sync3_rx;

always @(posedge gmii_clk or negedge gmii_rstn) begin
    if(!gmii_rstn) begin
        rel_sync1_rx <= {SLOT_NUM{1'b0}};
        rel_sync2_rx <= {SLOT_NUM{1'b0}};
        rel_sync3_rx <= {SLOT_NUM{1'b0}};
    end else begin
        rel_sync1_rx <= rel_toggle_ddr;
        rel_sync2_rx <= rel_sync1_rx;
        rel_sync3_rx <= rel_sync2_rx;
    end
end

function [SLOT_BITS-1:0] first_free_slot;
    input [SLOT_NUM-1:0] busy;
    integer k;
    reg found;
    begin
        first_free_slot = {SLOT_BITS{1'b0}};
        found = 1'b0;
        for(k = 0; k < SLOT_NUM; k = k + 1) begin
            if(!busy[k] && !found) begin
                first_free_slot = k[SLOT_BITS-1:0];
                found = 1'b1;
            end
        end
    end
endfunction

function [15:0] count_busy_slots;
    input [SLOT_NUM-1:0] busy;
    integer n;
    begin
        count_busy_slots = 16'd0;
        for(n = 0; n < SLOT_NUM; n = n + 1)
            count_busy_slots = count_busy_slots + busy[n];
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
// F14D packet completeness state. Each DDR bank has its own bitmap so a bank
// can be cleared for a new frame without disturbing the last readable bank.
reg [MAX_PACKET_NUM-1:0] rx_pkt_seen_bank0;
reg [MAX_PACKET_NUM-1:0] rx_pkt_seen_bank1;
reg [15:0]              rx_pkt_count_bank0;
reg [15:0]              rx_pkt_count_bank1;
reg [31:0]              rx_frame_id_bank0;
reg [31:0]              rx_frame_id_bank1;
// F14P legal-header debug: updated only when hdr_accept_w is true.
reg [15:0] last_good_packet_id    /* synthesis PAP_MARK_DEBUG="true" */;
reg [15:0] last_good_packet_total /* synthesis PAP_MARK_DEBUG="true" */;
reg [15:0] last_good_payload_len  /* synthesis PAP_MARK_DEBUG="true" */;
reg [31:0] last_good_byte_offset  /* synthesis PAP_MARK_DEBUG="true" */;
reg [31:0] relaxed_publish_count  /* synthesis PAP_MARK_DEBUG="true" */;
reg [31:0] strict_publish_count   /* synthesis PAP_MARK_DEBUG="true" */;

reg [1:0]               rx_bank_active;
reg [1:0]               rx_bank_published;
reg        pkt_error_seen;
reg        pkt_bank;
reg [SLOT_BITS-1:0]  pkt_slot;
reg [31:0] pkt_byte_offset;
reg [15:0] pkt_beat_count;
reg        pkt_publish /* synthesis PAP_MARK_DEBUG="true" */;

reg [7:0]  byte_pack0;
reg [7:0]  byte_pack1;
reg [7:0]  byte_pack2;
reg [1:0]  byte_phase;
reg [8:0]  word_index;
reg [31:0] ram_wr_data;
reg [11:0] ram_wr_addr;
reg        ram_wr_en;

// Use byte_offset as the primary DDR placement source. If an old sender leaves
// byte_offset invalid, fall back to packet_id*NOMINAL_PAYLOAD_BYTES only to keep
// the stream diagnosable; valid FPGV packets should use hdr_byte_offset.
wire [31:0] hdr_offset_fallback   = offset_from_packet(hdr_packet_id, NOMINAL_PAYLOAD_BYTES);
wire [31:0] hdr_offset_effective  = (hdr_byte_offset < FRAME_BYTES) ? hdr_byte_offset : hdr_offset_fallback;
wire [15:0] hdr_beats_effective   = (hdr_payload_len[4:0] == 5'd0) ? (hdr_payload_len >> 5) : ((hdr_payload_len >> 5) + 16'd1);
wire        hdr_valid_size        = (hdr_width == {4'd0,SRC_W}) && (hdr_height == {4'd0,SRC_H});
wire        hdr_valid_payload     = (hdr_payload_len != 16'd0) && (hdr_payload_len <= MAX_PAYLOAD_BYTES);
wire        hdr_valid_packet      = (hdr_packet_total != 16'd0) &&
                                    (hdr_packet_total <= MAX_PACKET_NUM) &&
                                    (hdr_packet_id < hdr_packet_total) &&
                                    (hdr_packet_id < MAX_PACKET_NUM);
wire        hdr_valid_offset      = (hdr_offset_effective < FRAME_BYTES) &&
                                    ((hdr_offset_effective + hdr_payload_len) <= FRAME_BYTES);
wire        hdr_last_by_id /* synthesis PAP_MARK_DEBUG="true" */ = (hdr_packet_total != 16'd0) &&
                                    (hdr_packet_id == (hdr_packet_total - 16'd1));
wire        hdr_last_by_offset /* synthesis PAP_MARK_DEBUG="true" */ = ((hdr_offset_effective + hdr_payload_len) >= FRAME_BYTES);
wire [SLOT_BITS-1:0]  alloc_slot_w = first_free_slot(slot_busy_rx);
wire        have_free_slot_w      = (slot_busy_rx != {SLOT_NUM{1'b1}});
wire [15:0] slot_busy_count_w      = count_busy_slots(slot_busy_rx);
// F14X: do not rely only on packet_id==0 for frame boundary.  On the
// real link, Debugger showed continuous valid packet writes but no publish:
// packet_id often reached 0x02ec/offset 0x000bb000, while packet0/last-packet
// publish never fired.  Treat a large packet_id/byte_offset wrap as a new frame
// start so the writer can flip banks and publish the previous bank even when
// packet0 or the last UDP packet is dropped.
wire        rx_wrap_by_id_w /* synthesis PAP_MARK_DEBUG="true" */ = rx_frame_seen &&
                                    (last_good_packet_id >= 16'd700) &&
                                    (hdr_packet_id      <= 16'd350) &&
                                    (hdr_packet_id + 16'd16 < last_good_packet_id);
wire        rx_wrap_by_offset_w /* synthesis PAP_MARK_DEBUG="true" */ = rx_frame_seen &&
                                    (last_good_byte_offset >= (FRAME_BYTES - 32'd65536)) &&
                                    (hdr_offset_effective  <= (FRAME_BYTES >> 1)) &&
                                    (hdr_offset_effective + 32'd32768 < last_good_byte_offset);
wire        rx_frame_start_w /* synthesis PAP_MARK_DEBUG="true" */ = (hdr_packet_id == 16'd0) ||
                                    rx_wrap_by_id_w || rx_wrap_by_offset_w;
wire        rx_target_bank_w      = rx_frame_start_w ? ~rx_write_bank : rx_write_bank;
wire        rx_packet_seen_w      = rx_frame_start_w ? 1'b0 :
                                    (rx_target_bank_w ? rx_pkt_seen_bank1[hdr_packet_id[9:0]] : rx_pkt_seen_bank0[hdr_packet_id[9:0]]);
wire [15:0] rx_packet_count_w     = rx_frame_start_w ? 16'd0 :
                                    (rx_target_bank_w ? rx_pkt_count_bank1 : rx_pkt_count_bank0);
wire [15:0] rx_packet_count_next_w= rx_packet_count_w + (rx_packet_seen_w ? 16'd0 : 16'd1);
wire        rx_frame_id_ok_w      = (hdr_packet_id == 16'd0) ? 1'b1 :
                                    ((GATE_FRAME_ID == 0) ? 1'b1 :
                                     (rx_target_bank_w ? (rx_bank_active[1] && (hdr_frame_id == rx_frame_id_bank1)) :
                                                         (rx_bank_active[0] && (hdr_frame_id == rx_frame_id_bank0))));
wire        rx_frame_complete_w /* synthesis PAP_MARK_DEBUG="true" */   = hdr_valid_packet && (!rx_packet_seen_w) &&
                                    (rx_packet_count_next_w >= hdr_packet_total);
wire        rx_relaxed_complete_w /* synthesis PAP_MARK_DEBUG="true" */ = hdr_valid_packet &&
                                    PUBLISH_ON_LAST_PACKET &&
                                    (hdr_last_by_id || hdr_last_by_offset) &&
                                    ((rx_packet_count_next_w >= MIN_PACKETS_FOR_RELAXED_PUBLISH) ||
                                     (rx_packet_count_w      >= MIN_PACKETS_FOR_RELAXED_PUBLISH));
wire        rx_bank_published_w /* synthesis PAP_MARK_DEBUG="true" */ = rx_target_bank_w ? rx_bank_published[1] : rx_bank_published[0];
wire [15:0] rx_prev_bank_packet_count_w /* synthesis PAP_MARK_DEBUG="true" */ = rx_write_bank ? rx_pkt_count_bank1 : rx_pkt_count_bank0;
wire        rx_prev_bank_published_w /* synthesis PAP_MARK_DEBUG="true" */ = rx_write_bank ? rx_bank_published[1] : rx_bank_published[0];
wire        rx_prev_bank_enough_w /* synthesis PAP_MARK_DEBUG="true" */ = (rx_prev_bank_packet_count_w >= MIN_PACKETS_FOR_PREV_BANK_PUBLISH);
wire        rx_prevbank_publish_candidate_w /* synthesis PAP_MARK_DEBUG="true" */ = PUBLISH_PREV_BANK_ON_PACKET0 && rx_frame_seen &&
                                    rx_frame_start_w && (!rx_prev_bank_published_w) && rx_prev_bank_enough_w;
wire        rx_publish_candidate_w /* synthesis PAP_MARK_DEBUG="true" */= (!rx_bank_published_w) &&
                                    (rx_frame_complete_w || rx_relaxed_complete_w);
wire        hdr_base_valid_w      = fpgv_accept && hdr_valid_size && hdr_valid_payload &&
                                    hdr_valid_packet && hdr_valid_offset && rx_frame_id_ok_w;
wire        hdr_accept_w /* synthesis PAP_MARK_DEBUG="true" */          = hdr_base_valid_w && have_free_slot_w;

// Metadata FIFO write side.
reg                   meta_wr_en /* synthesis PAP_MARK_DEBUG="true" */;
reg [META_WIDTH-1:0]  meta_wr_data;
wire                  meta_full /* synthesis PAP_MARK_DEBUG="true" */;

// F14G: packet slot RAM write and metadata FIFO write used to happen in the
// same gmii_clk edge on the last payload byte.  The DDR domain could then read
// the slot before the final SDPRAM write was fully visible, creating short
// colored horizontal noise.  Queue metadata locally and publish it after a
// small gmii_clk delay.
reg                   meta_pending_valid /* synthesis PAP_MARK_DEBUG="true" */;
reg [META_WIDTH-1:0]  meta_pending_data;
reg [3:0]             meta_pending_delay;

// F14T diagnostic counters. These are marked for Fabric Debugger and
// do not affect normal data placement.
reg [31:0] meta_wr_count    /* synthesis PAP_MARK_DEBUG="true" */;
reg [31:0] meta_rd_count    /* synthesis PAP_MARK_DEBUG="true" */;
reg [31:0] ddr_wreq_count   /* synthesis PAP_MARK_DEBUG="true" */;
reg [31:0] ddr_wdone_count  /* synthesis PAP_MARK_DEBUG="true" */;
reg [31:0] force_done_count /* synthesis PAP_MARK_DEBUG="true" */;
reg [31:0] prevbank_publish_count /* synthesis PAP_MARK_DEBUG="true" */;
reg [31:0] prevbank_skip_count    /* synthesis PAP_MARK_DEBUG="true" */;
reg [15:0] prevbank_packet_count_at_event /* synthesis PAP_MARK_DEBUG="true" */;
// F14V: latched previous-bank publish marker.  The bank number is captured at
// packet0 header time, before rx_write_bank is flipped to the new bank.
reg        prev_publish_pending /* synthesis PAP_MARK_DEBUG="true" */;
reg        prev_publish_bank    /* synthesis PAP_MARK_DEBUG="true" */;
reg [31:0] prev_publish_latched_count /* synthesis PAP_MARK_DEBUG="true" */;

// F14Y drop-reason counters. These are observability-only and do not change acceptance policy.
reg [31:0] drop_bad_header_count       /* synthesis PAP_MARK_DEBUG="true" */;
reg [31:0] drop_no_free_slot_count     /* synthesis PAP_MARK_DEBUG="true" */;
reg [31:0] drop_meta_pending_count     /* synthesis PAP_MARK_DEBUG="true" */;
reg [31:0] drop_meta_full_count        /* synthesis PAP_MARK_DEBUG="true" */;
reg [31:0] drop_gmii_error_count       /* synthesis PAP_MARK_DEBUG="true" */;
reg [31:0] drop_payload_error_count    /* synthesis PAP_MARK_DEBUG="true" */;
reg [31:0] duplicate_packet_count      /* synthesis PAP_MARK_DEBUG="true" */;
reg [15:0] slot_busy_max               /* synthesis PAP_MARK_DEBUG="true" */;
reg        pkt_gmii_error_latched;

wire [ADDR_WIDTH-1:0] meta_addr_w = ADDR_OFFSET + {pkt_bank, pkt_byte_offset[LINE_ADDR_WIDTH+1:2]};
wire [META_WIDTH-1:0] meta_data_packet_w = {pkt_slot, pkt_bank, pkt_publish, pkt_beat_count, meta_addr_w};
wire [META_WIDTH-1:0] meta_data_packet_commit_w = {pkt_slot, pkt_bank, rx_publish_candidate_w, pkt_beat_count, meta_addr_w};
wire [META_WIDTH-1:0] meta_data_publish_w = {{SLOT_BITS{1'b0}}, prev_publish_bank, 1'b1, 16'd0, {ADDR_WIDTH{1'b0}}};

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
        rx_pkt_seen_bank0     <= {MAX_PACKET_NUM{1'b0}};
        rx_pkt_seen_bank1     <= {MAX_PACKET_NUM{1'b0}};
        rx_pkt_count_bank0    <= 16'd0;
        rx_pkt_count_bank1    <= 16'd0;
        rx_frame_id_bank0     <= 32'd0;        rx_frame_id_bank1      <= 32'd0;
        last_good_packet_id    <= 16'd0;
        last_good_packet_total <= 16'd0;
        last_good_payload_len  <= 16'd0;
        last_good_byte_offset  <= 32'd0;
        relaxed_publish_count  <= 32'd0;
        strict_publish_count   <= 32'd0;
        rx_bank_active        <= 2'b00;
        rx_bank_published     <= 2'b00;
        pkt_error_seen        <= 1'b0;
        pkt_bank              <= 1'b0;
        pkt_slot              <= {SLOT_BITS{1'b0}};
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
        slot_busy_rx          <= {SLOT_NUM{1'b0}};
        meta_wr_en            <= 1'b0;
        meta_wr_data          <= {META_WIDTH{1'b0}};
        meta_pending_valid    <= 1'b0;
        meta_pending_data     <= {META_WIDTH{1'b0}};
        meta_pending_delay    <= 4'd0;
        meta_wr_count        <= 32'd0;
        prevbank_publish_count <= 32'd0;
        prevbank_skip_count    <= 32'd0;
        prevbank_packet_count_at_event <= 16'd0;
        prev_publish_pending   <= 1'b0;
        prev_publish_bank      <= 1'b0;
        prev_publish_latched_count <= 32'd0;
        drop_bad_header_count    <= 32'd0;
        drop_no_free_slot_count  <= 32'd0;
        drop_meta_pending_count  <= 32'd0;
        drop_meta_full_count     <= 32'd0;
        drop_gmii_error_count    <= 32'd0;
        drop_payload_error_count <= 32'd0;
        duplicate_packet_count   <= 32'd0;
        slot_busy_max            <= 16'd0;
        pkt_gmii_error_latched   <= 1'b0;
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
        if(slot_busy_count_w > slot_busy_max)
            slot_busy_max <= slot_busy_count_w;

        if(meta_pending_valid) begin
            if(meta_pending_delay != 4'd0) begin
                meta_pending_delay <= meta_pending_delay - 4'd1;
            end else if(!meta_full) begin
                meta_wr_en         <= 1'b1;
                meta_wr_data       <= meta_pending_data;
                meta_pending_valid <= 1'b0;
                meta_wr_count      <= meta_wr_count + 32'd1;
            end
        end else if(prev_publish_pending && !meta_full) begin
            // F14V: delayed previous-bank marker.  It is inserted only after
            // the regular packet metadata queue is empty, so FIFO order makes
            // DDR complete all prior packet writes before this zero-beat publish
            // toggles frame_done.
            meta_wr_en           <= 1'b1;
            meta_wr_data         <= meta_data_publish_w;
            prev_publish_pending <= 1'b0;
            meta_wr_count        <= meta_wr_count + 32'd1;
            prevbank_publish_count <= prevbank_publish_count + 32'd1;
        end

        if(gmii_rx_dv && gmii_rx_er) begin
            overflow_count <= overflow_count + 32'd1;
            pkt_error_seen <= 1'b1;
            if(!pkt_gmii_error_latched) begin
                drop_gmii_error_count <= drop_gmii_error_count + 32'd1;
                pkt_gmii_error_latched <= 1'b1;
            end
        end

        case(rx_state)
        S_IDLE: begin
            payload_active   <= 1'b0;
            drop_payload     <= 1'b0;
            payload_byte_cnt <= 16'd0;
            byte_phase       <= 2'd0;
            if(dv_rise) begin
                pkt_gmii_error_latched <= 1'b0;
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
                if(payload_active && (payload_byte_cnt < hdr_payload_len))
                    drop_payload_error_count <= drop_payload_error_count + 32'd1;
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

                    pkt_bank        <= rx_target_bank_w;
                    pkt_byte_offset <= hdr_offset_effective;
                    pkt_beat_count  <= hdr_beats_effective;
                    // F14H: do not update bitmap or publish a frame at header time.
                    // A packet is counted only when its payload slot metadata is
                    // successfully committed. Otherwise the old code could mark a
                    // packet received even though it was never written to DDR,
                    // which created stale horizontal line segments.
                    pkt_publish     <= 1'b0;
                    pkt_error_seen  <= 1'b0;

                    // F14X stable fallback: when a new frame boundary appears
                    // (packet0 OR large packet_id/byte_offset wrap), latch the previous
                    // bank to be published later.  Do NOT test meta_pending_valid/meta_full
                    // here; the boundary is a one-shot event and the marker must be retried
                    // until the metadata FIFO can take it.
                    if(fpgv_accept && hdr_valid_size && hdr_valid_packet && rx_frame_start_w &&
                       rx_prevbank_publish_candidate_w && !prev_publish_pending) begin
                        prev_publish_pending <= 1'b1;
                        prev_publish_bank    <= rx_write_bank; // capture OLD/previous bank before rx_write_bank flips below
                        prev_publish_latched_count <= prev_publish_latched_count + 32'd1;
                        if(rx_write_bank)
                            rx_bank_published[1] <= 1'b1;
                        else
                            rx_bank_published[0] <= 1'b1;
                        prevbank_packet_count_at_event <= rx_prev_bank_packet_count_w;
                    end else if(fpgv_accept && hdr_valid_size && hdr_valid_packet && rx_frame_start_w &&
                                PUBLISH_PREV_BANK_ON_PACKET0 && rx_frame_seen && !rx_prev_bank_published_w &&
                                !prev_publish_pending) begin
                        prevbank_skip_count <= prevbank_skip_count + 32'd1;
                        prevbank_packet_count_at_event <= rx_prev_bank_packet_count_w;
                    end

                    if(fpgv_accept && !hdr_base_valid_w)
                        drop_bad_header_count <= drop_bad_header_count + 32'd1;
                    else if(hdr_base_valid_w && !have_free_slot_w)
                        drop_no_free_slot_count <= drop_no_free_slot_count + 32'd1;
                    else if(hdr_accept_w && rx_packet_seen_w)
                        duplicate_packet_count <= duplicate_packet_count + 32'd1;

                    if(hdr_accept_w) begin
                        last_good_packet_id    <= hdr_packet_id;
                        last_good_packet_total <= hdr_packet_total;
                        last_good_payload_len  <= hdr_payload_len;
                        last_good_byte_offset  <= hdr_offset_effective;

                        if(rx_frame_start_w) begin
                            rx_write_bank <= rx_target_bank_w;
                            rx_frame_seen <= 1'b1;
                            if(rx_target_bank_w) begin
                                rx_bank_active[1]     <= 1'b1;
                                rx_bank_published[1]  <= 1'b0;
                                rx_pkt_seen_bank1     <= {MAX_PACKET_NUM{1'b0}};
                                rx_pkt_count_bank1    <= 16'd0;
                                rx_frame_id_bank1     <= hdr_frame_id;
                            end else begin
                                rx_bank_active[0]     <= 1'b1;
                                rx_bank_published[0]  <= 1'b0;
                                rx_pkt_seen_bank0     <= {MAX_PACKET_NUM{1'b0}};
                                rx_pkt_count_bank0    <= 16'd0;
                                rx_frame_id_bank0     <= hdr_frame_id;
                            end
                        end else if(!rx_frame_seen) begin
                            // F14X: if the first observed packet after reset is not
                            // packet0, still arm wrap detection.  The existing packet
                            // bitmap/count are already reset by global reset, so do not
                            // clear them here; just mark the current bank active.
                            rx_frame_seen <= 1'b1;
                            if(rx_target_bank_w) begin
                                rx_bank_active[1]    <= 1'b1;
                                rx_bank_published[1] <= 1'b0;
                                rx_frame_id_bank1    <= hdr_frame_id;
                            end else begin
                                rx_bank_active[0]    <= 1'b1;
                                rx_bank_published[0] <= 1'b0;
                                rx_frame_id_bank0    <= hdr_frame_id;
                            end
                        end

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
                        ram_wr_data <= {byte_pack2, gmii_rxd, byte_pack0, byte_pack1};
                        ram_wr_addr <= {pkt_slot, word_index[7:0]};
                        ram_wr_en   <= 1'b1;
                        word_index  <= word_index + 9'd1;
                        byte_phase  <= 2'd0;
                    end
                    endcase

                    if((payload_byte_cnt + 16'd1) >= hdr_payload_len) begin
                        payload_active <= 1'b0;
                        byte_phase     <= 2'd0;

                        if((!meta_pending_valid) && (!pkt_error_seen)) begin
                            accepted_packet_count <= accepted_packet_count + 32'd1;
                            meta_pending_valid <= 1'b1;
                            meta_pending_data  <= meta_data_packet_commit_w;
                            meta_pending_delay <= META_COMMIT_DELAY;

                            if(!rx_packet_seen_w) begin
                                if(pkt_bank) begin
                                    rx_pkt_seen_bank1[hdr_packet_id[9:0]] <= 1'b1;
                                    rx_pkt_count_bank1 <= rx_pkt_count_bank1 + 16'd1;
                                end else begin
                                    rx_pkt_seen_bank0[hdr_packet_id[9:0]] <= 1'b1;
                                    rx_pkt_count_bank0 <= rx_pkt_count_bank0 + 16'd1;
                                end
                            end

                            if(rx_publish_candidate_w) begin
                                if(pkt_bank)
                                    rx_bank_published[1] <= 1'b1;
                                else
                                    rx_bank_published[0] <= 1'b1;
                                pkt_publish <= 1'b1;
                                if(rx_frame_complete_w)
                                    strict_publish_count <= strict_publish_count + 32'd1;
                                else if(rx_relaxed_complete_w)
                                    relaxed_publish_count <= relaxed_publish_count + 32'd1;
                            end
                        end else begin
                            // Metadata could not be committed or GMII error occurred.
                            // Release the staging slot without counting the packet.
                            slot_busy_rx[pkt_slot] <= 1'b0;
                            overflow_count <= overflow_count + 32'd1;
                            if(meta_pending_valid) begin
                                drop_meta_pending_count <= drop_meta_pending_count + 32'd1;
                                if(meta_full)
                                    drop_meta_full_count <= drop_meta_full_count + 32'd1;
                            end
                            if(pkt_error_seen)
                                drop_payload_error_count <= drop_payload_error_count + 32'd1;
                        end
                    end
                end

                if(byte_idx != 11'h7ff)
                    byte_idx <= byte_idx + 11'd1;
            end
        end
        default: rx_state <= S_IDLE;
        endcase

        debug_state <= {rx_state, payload_active, pkt_error_seen, meta_full, meta_pending_valid, have_free_slot_w};
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
wire                  meta_empty /* synthesis PAP_MARK_DEBUG="true" */;
reg                   meta_rd_en /* synthesis PAP_MARK_DEBUG="true" */;
// F14Z: zero-beat publish metadata must be popped exactly once.
// The FIFO read pointer advances one ddr_clk after meta_rd_en is asserted.
// Hold off one cycle after consuming a zero-beat marker so the same head
// entry cannot be interpreted twice before rbin advances.
reg                   meta_zero_beat_holdoff /* synthesis PAP_MARK_DEBUG="true" */;
reg [SLOT_BITS-1:0]   cur_slot;
reg                   cur_bank;
reg                   cur_publish;
reg [15:0]            cur_beats /* synthesis PAP_MARK_DEBUG="true" */;
reg [15:0]            beat_idx /* synthesis PAP_MARK_DEBUG="true" */;
reg                   cmd_active /* synthesis PAP_MARK_DEBUG="true" */;
reg                   cmd_started /* synthesis PAP_MARK_DEBUG="true" */;
reg [2:0]             prefetch_cnt;
reg [DQ_WIDTH*8-1:0]  ram_rd_data_first;

wire [ADDR_WIDTH-1:0] meta_addr;
wire [15:0]           meta_beats;
wire                  meta_publish;
wire                  meta_bank;
wire [SLOT_BITS-1:0]  meta_slot;
assign {meta_slot, meta_bank, meta_publish, meta_beats, meta_addr} = meta_rd_data;

async_fifo_gray #(.DSIZE(META_WIDTH), .ASIZE(4)) u_meta_fifo (
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


// F14W explicit debug port assignments.
assign dbg_hdr_accept                    = hdr_accept_w;
assign dbg_hdr_last_by_id                = hdr_last_by_id;
assign dbg_hdr_last_by_offset            = hdr_last_by_offset;
assign dbg_rx_prevbank_publish_candidate = rx_prevbank_publish_candidate_w;
assign dbg_rx_relaxed_complete           = rx_relaxed_complete_w;
assign dbg_rx_publish_candidate          = rx_publish_candidate_w;
assign dbg_pkt_publish                   = pkt_publish;
assign dbg_meta_wr_en                    = meta_wr_en;
assign dbg_meta_pending_valid            = meta_pending_valid;
assign dbg_meta_full                     = meta_full;
assign dbg_meta_empty                    = meta_empty;
assign dbg_meta_rd_en                    = meta_rd_en;
assign dbg_cmd_active                    = cmd_active;
assign dbg_cmd_started                   = cmd_started;
assign dbg_prev_publish_pending          = prev_publish_pending;
assign dbg_prev_publish_bank             = prev_publish_bank;
assign dbg_prev_publish_latched_count    = prev_publish_latched_count;
assign dbg_prevbank_publish_count        = prevbank_publish_count;
assign dbg_prevbank_skip_count           = prevbank_skip_count;
assign dbg_prevbank_packet_count_at_event= prevbank_packet_count_at_event;
assign dbg_meta_wr_count                 = meta_wr_count;
assign dbg_meta_rd_count                 = meta_rd_count;
assign dbg_ddr_wreq_count                = ddr_wreq_count;
assign dbg_ddr_wdone_count               = ddr_wdone_count;
assign dbg_force_done_count              = force_done_count;
assign dbg_last_good_packet_id           = last_good_packet_id;
assign dbg_last_good_packet_total        = last_good_packet_total;
assign dbg_last_good_payload_len         = last_good_payload_len;
assign dbg_last_good_byte_offset         = last_good_byte_offset;
assign dbg_relaxed_publish_count         = relaxed_publish_count;
assign dbg_strict_publish_count          = strict_publish_count;
assign dbg_drop_bad_header_count          = drop_bad_header_count;
assign dbg_drop_no_free_slot_count        = drop_no_free_slot_count;
assign dbg_drop_meta_pending_count        = drop_meta_pending_count;
assign dbg_drop_meta_full_count           = drop_meta_full_count;
assign dbg_drop_gmii_error_count          = drop_gmii_error_count;
assign dbg_drop_payload_error_count       = drop_payload_error_count;
assign dbg_duplicate_packet_count         = duplicate_packet_count;
assign dbg_slot_busy_count                = slot_busy_count_w;
assign dbg_slot_busy_max                  = slot_busy_max;
assign dbg_have_free_slot                 = have_free_slot_w;

always @(posedge ddr_clk or negedge ddr_rstn) begin
    if(!ddr_rstn) begin
        ddr_wreq          <= 1'b0;
        ddr_waddr         <= {ADDR_WIDTH{1'b0}};
        ddr_wr_len        <= {LEN_WIDTH{1'b0}};
        meta_rd_en             <= 1'b0;
        meta_zero_beat_holdoff <= 1'b0;
        cur_slot               <= {SLOT_BITS{1'b0}};
        cur_bank          <= 1'b0;
        cur_publish       <= 1'b0;
        cur_beats         <= 16'd0;
        beat_idx          <= 16'd0;
        cmd_active        <= 1'b0;
        cmd_started       <= 1'b0;
        prefetch_cnt      <= 3'd0;
        ram_rd_data_first <= {DQ_WIDTH*8{1'b0}};
        ram_rd_addr       <= 9'd0;
        frame_done_bank   <= 1'b0;
        frame_done_toggle <= 1'b0;
        frame_done_count  <= 32'd0;
        rel_toggle_ddr    <= {SLOT_NUM{1'b0}};
        meta_rd_count     <= 32'd0;
        ddr_wreq_count    <= 32'd0;
        ddr_wdone_count   <= 32'd0;
        force_done_count  <= 32'd0;
    end else begin
        meta_rd_en <= 1'b0;

        // F14Z: a zero-beat marker does not raise cmd_active. Without this
        // one-cycle guard, registered meta_rd_en allows the same FIFO head
        // marker to be interpreted again on the next ddr_clk edge.
        if(meta_zero_beat_holdoff) begin
            meta_zero_beat_holdoff <= 1'b0;
            ddr_wreq               <= 1'b0;
        end else if(!cmd_active && !meta_empty) begin
            meta_rd_en     <= 1'b1;
            meta_rd_count  <= meta_rd_count + 32'd1;
            cur_slot       <= meta_slot;
            cur_bank    <= meta_bank;
            cur_publish <= meta_publish;
            cur_beats   <= meta_beats;
            beat_idx    <= 16'd0;
            ram_rd_addr <= {meta_slot, 5'd0};
            if(meta_beats == 16'd0) begin
                // Allow async_fifo_gray.rbin to advance before examining the
                // next FIFO head. This makes zero-beat publish markers one-shot.
                meta_zero_beat_holdoff <= 1'b1;
                if(meta_publish) begin
                    frame_done_bank   <= meta_bank;
                    frame_done_toggle <= ~frame_done_toggle;
                    frame_done_count  <= frame_done_count + 32'd1;
                end
            end else begin
                ddr_waddr    <= meta_addr;
                ddr_wr_len   <= {{(LEN_WIDTH-16){1'b0}}, meta_beats};
                ddr_wreq     <= 1'b0;
                cmd_active   <= 1'b1;
                cmd_started  <= 1'b0;
                // Give the Pango SDPRAM two ddr_clk cycles to present slot beat0
                // before the AXI writer can request the first 256-bit beat.
                prefetch_cnt <= 3'd4;
            end
        end else if(cmd_active) begin
            if(prefetch_cnt != 3'd0) begin
                prefetch_cnt      <= prefetch_cnt - 2'd1;
                ram_rd_data_first <= ram_rd_data;
                if(prefetch_cnt == 3'd1) begin
                    ddr_wreq       <= 1'b1;
                    ddr_wreq_count <= ddr_wreq_count + 32'd1;
                end
            end else begin
                if(ddr_wdata_req) begin
                    ddr_wreq    <= 1'b0;
                    cmd_started <= 1'b1;
                    if(beat_idx < cur_beats - 16'd1) begin
                        beat_idx    <= beat_idx + 16'd1;
                        ram_rd_addr <= {cur_slot, beat_idx[4:0] + 5'd1};
                    end
                end
                if(ddr_wdone) begin
                    cmd_active <= 1'b0;
                    ddr_wreq   <= 1'b0;
                    ddr_wdone_count <= ddr_wdone_count + 32'd1;
                    rel_toggle_ddr[cur_slot] <= ~rel_toggle_ddr[cur_slot];
                    if(cur_publish || FORCE_FRAME_DONE_AFTER_ANY_WRITE) begin
                        frame_done_bank   <= cur_bank;
                        frame_done_toggle <= ~frame_done_toggle;
                        frame_done_count  <= frame_done_count + 32'd1;
                        if(!cur_publish)
                            force_done_count <= force_done_count + 32'd1;
                    end
                end
            end
        end else begin
            ddr_wreq <= 1'b0;
        end
    end
end

assign ddr_wdata = (!cmd_started && ddr_wdata_req) ? ram_rd_data_first : ram_rd_data;

endmodule
