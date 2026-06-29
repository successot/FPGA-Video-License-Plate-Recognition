`timescale 1ns / 1ps
`default_nettype wire
`define UD #1
// -----------------------------------------------------------------------------
// MES50HP Stage7F14ZQ 4CH NATIVE QUAD DISPLAY PATCH
//
// Selected SFP0/lane2 or SFP1/lane3 -> QSGMII -> GMII ch0/ch1/ch2/ch3
// -> four UDP5000/FPGV RGB565 800x480 receivers
// -> shared DDR3 two-bank-per-channel frame storage
// -> 1920x1080 HDMI 2x2 quad view, no scaling/no stretching.
//
// Layout on 1920x1080:
//   margin L/R = 140, margin T/B = 40, center gap X/Y = 40
//   ch0: top-left      x=140..939,  y=40..519
//   ch1: top-right     x=980..1779, y=40..519
//   ch2: bottom-left   x=140..939,  y=560..1039
//   ch3: bottom-right  x=980..1779, y=560..1039
// -----------------------------------------------------------------------------
module mes50hp_stage7f14d_4ch_direct_ddr_stable_top #(
    parameter MEM_ROW_ADDR_WIDTH   = 15,
    parameter MEM_COL_ADDR_WIDTH   = 10,
    parameter MEM_BADDR_WIDTH      = 3,
    parameter MEM_DQ_WIDTH         = 32,
    parameter MEM_DQS_WIDTH        = 32/8,
    // FREEZE_ON_LOSS=0: black out a window after timeout. 1: keep showing last complete frame.
    parameter FREEZE_ON_LOSS       = 1'b1,
    parameter [31:0] LOSS_TIMEOUT_CORE_CYCLES = 32'd99_000_000,
    parameter DEBUG_LED_CHANNEL    = 2,
    // 0 = true four-channel quad; 1 = mirror CH2 into all four windows for single-camera verification.
    // F14ZQ default is native 4CH display: CH0/CH1/CH2/CH3 map to distinct HDMI windows.
    parameter MIRROR_CH2_TO_ALL_WINDOWS = 1'b0,
    // 1 = no colorbar fallback; output black until at least one complete DDR frame is readable.
    parameter BLACK_UNTIL_FRAME = 1'b1,
    // F14T previous-bank publish threshold. Default 700 keeps the display stable
    // while tolerating limited packet loss from the UDP path.
    parameter [15:0] MIN_PACKETS_FOR_PREV_BANK_PUBLISH = 16'd690,
    // Diagnostic only. Keep OFF for stable display; ON causes read/write tearing.
    parameter FORCE_CH2_DONE_AFTER_ANY_WRITE = 1'b0,
    // PORT_MATRIX_DIAG_V3: 0=MES50HP SFP0/lane2, 1=MES50HP SFP1/lane3.
    parameter USE_SFP1_RX = 1'b1,
    // PLATE_V1_STEP4 HDMI debug view:
    // 0=normal, 1=raw color_mask BW, 2=raw color_mask highlight, 3=gray,
    // 4=aligned usable edge BW = Sobel & aligned color-near gate,
    // 5=aligned usable edge overlay, 6=aligned raw Sobel BW, 7=aligned color-near BW.
    parameter [2:0]  PLATE_DEBUG_MODE = 3'd4,
    parameter [10:0] PLATE_SOBEL_TH   = 11'd40,
    // STEP4: morphology / projection / bbox defaults.
    parameter [10:0] PLATE_ROW_TH     = 11'd18,
    parameter [9:0]  PLATE_COL_TH     = 10'd6,
    parameter [11:0] PLATE_MIN_W      = 12'd80,
    parameter [11:0] PLATE_MAX_W      = 12'd420,
    parameter [11:0] PLATE_MIN_H      = 12'd20,
    parameter [11:0] PLATE_MAX_H      = 12'd140,
    // 0: draw dynamic detected bbox only. 1: restore STEP1 fixed coordinate box.
    parameter        PLATE_SHOW_FIXED_TEST_BOX = 1'b0
)(
    input                                sys_clk,
    input                                rst_n,

    input                                i_p_refckn_0,
    input                                i_p_refckp_0,
    input                                i_p_l2rxn,
    input                                i_p_l2rxp,
    output                               o_p_l2txn,
    output                               o_p_l2txp,
    input                                i_p_l3rxn,
    input                                i_p_l3rxp,
    output                               o_p_l3txn,
    output                               o_p_l3txp,
    input                                sfp0_los,
    input                                sfp1_los,
    output [1:0]                         tx_disable,

    output [7:0]                         led,

    output                               mem_rst_n,
    output                               mem_ck,
    output                               mem_ck_n,
    output                               mem_cke,
    output                               mem_cs_n,
    output                               mem_ras_n,
    output                               mem_cas_n,
    output                               mem_we_n,
    output                               mem_odt,
    output      [MEM_ROW_ADDR_WIDTH-1:0] mem_a,
    output      [MEM_BADDR_WIDTH-1:0]    mem_ba,
    inout       [MEM_DQ_WIDTH/8-1:0]     mem_dqs,
    inout       [MEM_DQ_WIDTH/8-1:0]     mem_dqs_n,
    inout       [MEM_DQ_WIDTH-1:0]       mem_dq,
    output      [MEM_DQ_WIDTH/8-1:0]     mem_dm,

    output                               rstn_out,
    output                               iic_tx_scl,
    inout                                iic_tx_sda,
    output                               pix_clk,
    output reg                           vs_out,
    output reg                           hs_out,
    output reg                           de_out,
    output reg [7:0]                     r_out,
    output reg [7:0]                     g_out,
    output reg [7:0]                     b_out
);

localparam CTRL_ADDR_WIDTH = MEM_ROW_ADDR_WIDTH + MEM_BADDR_WIDTH + MEM_COL_ADDR_WIDTH;
localparam TH_1S = 27'd33000000;
localparam [11:0] SRC_W = 12'd800;
localparam [11:0] SRC_H = 12'd480;
localparam [11:0] WIN_W = 12'd800;
localparam [11:0] WIN_H = 12'd480;
localparam [11:0] WIN0_X = 12'd140;
localparam [11:0] WIN1_X = 12'd980;
localparam [11:0] WIN0_Y = 12'd40;
localparam [11:0] WIN1_Y = 12'd560;

wire sys_rst_n;
cross_reset_sync u_sys_reset_sync (
    .free_clk_pll  (sys_clk),
    .external_rstn (rst_n),
    .rst_n         (sys_rst_n)
);

wire cfg_clk;
wire clk_25M_unused;
wire locked;
wire init_over_tx;
wire init_over_rx;
wire iic_scl;
wire iic_sda;
reg  [15:0] rstn_1ms;

// Stage7F13: pll.v ratios changed so clkout0 is approximately 148.48 MHz.
pll u_pll (
    .clkin1   (sys_clk),
    .clkout0  (pix_clk),
    .clkout1  (cfg_clk),
    .clkout2  (clk_25M_unused),
    .pll_lock (locked)
);

ms72xx_ctl ms72xx_ctl (
    .clk          (cfg_clk),
    .rst_n        (rstn_out),
    .init_over_tx (init_over_tx),
    .init_over_rx (init_over_rx),
    .iic_tx_scl   (iic_tx_scl),
    .iic_tx_sda   (iic_tx_sda),
    .iic_scl      (iic_scl),
    .iic_sda      (iic_sda)
);

always @(posedge cfg_clk) begin
    if(!locked)
        rstn_1ms <= 16'd0;
    else if(rstn_1ms == 16'h2710)
        rstn_1ms <= rstn_1ms;
    else
        rstn_1ms <= rstn_1ms + 1'b1;
end
assign rstn_out = (rstn_1ms == 16'h2710);

wire [7:0] sfp_debug_led;
wire p0_clk, p1_clk, p2_clk, p3_clk;
wire p0_rstn, p1_rstn, p2_rstn, p3_rstn;
wire [7:0] p0_rxd, p1_rxd, p2_rxd, p3_rxd;
wire p0_dv, p1_dv, p2_dv, p3_dv;
wire p0_er, p1_er, p2_er, p3_er;
wire [3:0] sfp_rx_activity_live;
wire [3:0] sfp_rx_frame_seen;
wire [3:0] sfp_udp5000_seen /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0] sfp_fpgv_seen /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0] sfp_rx_error_seen /* synthesis PAP_MARK_DEBUG="true" */;
wire hsst_pll_lock;
wire selected_sfp_lane_done;
wire selected_sfp_pcs_synced;

// PORT_MATRIX_DIAG_V3: search Fabric Debugger with dbg_route_hp_
wire [31:0] dbg_route_hp_ch2_monitor_frame_count    /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_route_hp_ch2_monitor_udp5000_count  /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_route_hp_ch2_monitor_fpgv_count     /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_route_hp_ch2_monitor_er_cycle_count /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_route_hp_ch2_rx_segment_count       /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_route_hp_ch2_rx_byte_count          /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_route_hp_ch2_rx_er_segment_count    /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_route_hp_ch2_rx_shape_er_cycle_count/* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_route_hp_ch2_rx_short_segment_count /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_route_hp_ch2_rx_last_segment_len    /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_route_hp_ch2_rx_min_segment_len     /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_route_hp_ch2_rx_max_segment_len     /* synthesis PAP_MARK_DEBUG="true" */;
wire        dbg_route_hp_selected_pcs_synced            /* synthesis PAP_MARK_DEBUG="true" */;
wire        dbg_route_hp_selected_lane_done             /* synthesis PAP_MARK_DEBUG="true" */;
wire        dbg_route_hp_hsst_pll_lock              /* synthesis PAP_MARK_DEBUG="true" */;
reg         dbg_route_hp_cfg_use_sfp1_rx            /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg  [31:0] dbg_route_hp_selected_pcs_sync_drop_count   /* synthesis PAP_MARK_DEBUG="true" */;

// REPEAT_BITMAP_DIAG_V2: top-level searchable observability only.  This does
// not alter the direct-DDR writer, frame publication policy, HDMI, HSST, or
// QSGMII hierarchy. V2 masks the invalid tail bits for packet_id 750..767 and
// latches the first two real missing packet_id values. Search exactly: dbg_repeat
wire [31:0] dbg_repeat_round_count                  /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_repeat_last_round_good_count        /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_repeat_last_round_missing_count     /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_repeat_accum_unique_count           /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_repeat_accum_missing_count          /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_repeat_new_unique_last_round        /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_repeat_same_missing_prev_count      /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_repeat_current_round_unique_count   /* synthesis PAP_MARK_DEBUG="true" */;
wire        dbg_repeat_accum_complete               /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_repeat_legal_payload_count          /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_repeat_duplicate_payload_count      /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_repeat_bad_header_count             /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_repeat_incomplete_payload_count     /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_repeat_rx_er_packet_count           /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_repeat_critical_er_packet_count     /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_repeat_tail_er_packet_count         /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_repeat_last_header_packet_id        /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_repeat_last_legal_packet_id         /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_repeat_last_rx_er_packet_id         /* synthesis PAP_MARK_DEBUG="true" */;
wire [10:0] dbg_repeat_last_er_byte_index           /* synthesis PAP_MARK_DEBUG="true" */;
wire [10:0] dbg_repeat_min_er_byte_index            /* synthesis PAP_MARK_DEBUG="true" */;
wire [10:0] dbg_repeat_max_er_byte_index            /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_repeat_last_frame_id                /* synthesis PAP_MARK_DEBUG="true" */;
wire [4:0]  dbg_repeat_scan_word_index              /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_repeat_scan_round_valid_word        /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_repeat_scan_accum_valid_word        /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_repeat_scan_accum_missing_word      /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_repeat_scan_valid_mask             /* synthesis PAP_MARK_DEBUG="true" */;
wire        dbg_repeat_missing_ids_valid           /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_repeat_missing_id_count             /* synthesis PAP_MARK_DEBUG="true" */;
wire        dbg_repeat_missing_id0_valid            /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_repeat_missing_id0                  /* synthesis PAP_MARK_DEBUG="true" */;
wire        dbg_repeat_missing_id1_valid            /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_repeat_missing_id1                  /* synthesis PAP_MARK_DEBUG="true" */;
// BND_REPLAY_OBS_V3: searchable completion / replay-observability probes.
// Capture these in the MES50HP Fabric Debugger with p2_clk.
wire [31:0] dbg_repeat_complete_round_count         /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_repeat_complete_pulse_count         /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_repeat_boundary_replay_accept_count /* synthesis PAP_MARK_DEBUG="true" */;
// BND_R4A/F14ZQ: per protected packet-id replay acceptance counters.
// The bitmap diagnostic emits these in p2_clk; mirror them into top-level p2_clk
// registers with stable names so Pango Fabric Debugger can find them reliably.
wire [31:0] dbg_repeat_replay_accept_pid0_count_raw;
wire [31:0] dbg_repeat_replay_accept_pid1_count_raw;
wire [31:0] dbg_repeat_replay_accept_pid748_count_raw;
wire [31:0] dbg_repeat_replay_accept_pid749_count_raw;
reg  [31:0] dbg_repeat_replay_accept_pid0_count   /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg  [31:0] dbg_repeat_replay_accept_pid1_count   /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg  [31:0] dbg_repeat_replay_accept_pid748_count /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg  [31:0] dbg_repeat_replay_accept_pid749_count /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg  [1:0]  dbg_route_hp_pcs_sync_ff;
reg         dbg_route_hp_pcs_sync_prev;

assign dbg_route_hp_selected_pcs_synced = selected_sfp_pcs_synced;
assign dbg_route_hp_selected_lane_done  = selected_sfp_lane_done;
assign dbg_route_hp_hsst_pll_lock   = hsst_pll_lock;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        dbg_route_hp_pcs_sync_ff              <= 2'b00;
        dbg_route_hp_pcs_sync_prev            <= 1'b0;
        dbg_route_hp_selected_pcs_sync_drop_count <= 32'd0;
        dbg_route_hp_cfg_use_sfp1_rx               <= USE_SFP1_RX;
    end else begin
        dbg_route_hp_pcs_sync_ff   <= {dbg_route_hp_pcs_sync_ff[0], selected_sfp_pcs_synced};
        dbg_route_hp_cfg_use_sfp1_rx <= USE_SFP1_RX;
        dbg_route_hp_pcs_sync_prev <= dbg_route_hp_pcs_sync_ff[1];
        if(dbg_route_hp_pcs_sync_prev && !dbg_route_hp_pcs_sync_ff[1])
            dbg_route_hp_selected_pcs_sync_drop_count <= dbg_route_hp_selected_pcs_sync_drop_count + 32'd1;
    end
end

// F14ZQ/R4A visibility fix: keep the per-PID replay counters as top-level
// p2_clk registers, not just deep combinational wires from the diagnostic module.
always @(posedge p2_clk or negedge p2_rstn or negedge sys_rst_n) begin
    if(!p2_rstn || !sys_rst_n) begin
        dbg_repeat_replay_accept_pid0_count   <= 32'd0;
        dbg_repeat_replay_accept_pid1_count   <= 32'd0;
        dbg_repeat_replay_accept_pid748_count <= 32'd0;
        dbg_repeat_replay_accept_pid749_count <= 32'd0;
    end else begin
        dbg_repeat_replay_accept_pid0_count   <= dbg_repeat_replay_accept_pid0_count_raw;
        dbg_repeat_replay_accept_pid1_count   <= dbg_repeat_replay_accept_pid1_count_raw;
        dbg_repeat_replay_accept_pid748_count <= dbg_repeat_replay_accept_pid748_count_raw;
        dbg_repeat_replay_accept_pid749_count <= dbg_repeat_replay_accept_pid749_count_raw;
    end
end

mes50hp_sfp_rx_gmii_4ch #(.USE_SFP1_RX(USE_SFP1_RX)) u_sfp_rx (
    .i_free_clk           (sys_clk),
    .rst_n                (rst_n),
    .i_p_refckn_0         (i_p_refckn_0),
    .i_p_refckp_0         (i_p_refckp_0),
    .i_p_l2rxn            (i_p_l2rxn),
    .i_p_l2rxp            (i_p_l2rxp),
    .o_p_l2txn            (o_p_l2txn),
    .o_p_l2txp            (o_p_l2txp),
    .i_p_l3rxn            (i_p_l3rxn),
    .i_p_l3rxp            (i_p_l3rxp),
    .o_p_l3txn            (o_p_l3txn),
    .o_p_l3txp            (o_p_l3txp),
    .sfp0_los             (sfp0_los),
    .sfp1_los             (sfp1_los),
    .tx_disable           (tx_disable),
    .led                  (sfp_debug_led),
    .out_p0_sgmii_clk     (p0_clk),
    .out_p1_sgmii_clk     (p1_clk),
    .out_p2_sgmii_clk     (p2_clk),
    .out_p3_sgmii_clk     (p3_clk),
    .out_p0_rx_rstn       (p0_rstn),
    .out_p1_rx_rstn       (p1_rstn),
    .out_p2_rx_rstn       (p2_rstn),
    .out_p3_rx_rstn       (p3_rstn),
    .out_p0_gmii_rxd      (p0_rxd),
    .out_p1_gmii_rxd      (p1_rxd),
    .out_p2_gmii_rxd      (p2_rxd),
    .out_p3_gmii_rxd      (p3_rxd),
    .out_p0_gmii_rx_dv    (p0_dv),
    .out_p1_gmii_rx_dv    (p1_dv),
    .out_p2_gmii_rx_dv    (p2_dv),
    .out_p3_gmii_rx_dv    (p3_dv),
    .out_p0_gmii_rx_er    (p0_er),
    .out_p1_gmii_rx_er    (p1_er),
    .out_p2_gmii_rx_er    (p2_er),
    .out_p3_gmii_rx_er    (p3_er),
    .out_rx_activity_live (sfp_rx_activity_live),
    .out_rx_frame_seen    (sfp_rx_frame_seen),
    .out_udp5000_seen     (sfp_udp5000_seen),
    .out_fpgv_seen        (sfp_fpgv_seen),
    .out_rx_error_seen    (sfp_rx_error_seen),
    .out_hsst_pll_lock    (hsst_pll_lock),
    .out_sfp0_lane_done   (selected_sfp_lane_done),
    .out_sfp0_pcs_synced  (selected_sfp_pcs_synced),
    .out_diag_ch2_frame_count   (dbg_route_hp_ch2_monitor_frame_count),
    .out_diag_ch2_udp5000_count (dbg_route_hp_ch2_monitor_udp5000_count),
    .out_diag_ch2_fpgv_count    (dbg_route_hp_ch2_monitor_fpgv_count),
    .out_diag_ch2_er_cycle_count(dbg_route_hp_ch2_monitor_er_cycle_count)
);

gmii_frame_shape_monitor_lite u_dbg_route_hp_ch2_rx_shape (
    .clk(p2_clk), .rst_n(p2_rstn & sys_rst_n),
    .gmii_rx_dv(p2_dv), .gmii_rx_er(p2_er),
    .segment_count(dbg_route_hp_ch2_rx_segment_count),
    .byte_count(dbg_route_hp_ch2_rx_byte_count),
    .er_segment_count(dbg_route_hp_ch2_rx_er_segment_count),
    .er_cycle_count(dbg_route_hp_ch2_rx_shape_er_cycle_count),
    .short_segment_count(dbg_route_hp_ch2_rx_short_segment_count),
    .last_segment_len(dbg_route_hp_ch2_rx_last_segment_len),
    .min_segment_len(dbg_route_hp_ch2_rx_min_segment_len),
    .max_segment_len(dbg_route_hp_ch2_rx_max_segment_len)
);

// REPEAT_BITMAP_DIAG_V2: parse CH2 alongside the existing writer and measure
// whether repeated snapshot rounds eventually cover all packet_id values.
// Legal coverage requires UDP5000/5000, FPGV, strict fixed header fields, full
// payload arrival, and no RX_ER before the end of the RGB565 payload.
fpgv_repeat_bitmap_diag_ch2 u_dbg_repeat_bitmap_ch2 (
    .clk                              (p2_clk),
    .rst_n                            (p2_rstn & sys_rst_n),
    .gmii_rxd                         (p2_rxd),
    .gmii_rx_dv                       (p2_dv),
    .gmii_rx_er                       (p2_er),
    .dbg_repeat_round_count           (dbg_repeat_round_count),
    .dbg_repeat_last_round_good_count (dbg_repeat_last_round_good_count),
    .dbg_repeat_last_round_missing_count(dbg_repeat_last_round_missing_count),
    .dbg_repeat_accum_unique_count    (dbg_repeat_accum_unique_count),
    .dbg_repeat_accum_missing_count   (dbg_repeat_accum_missing_count),
    .dbg_repeat_new_unique_last_round (dbg_repeat_new_unique_last_round),
    .dbg_repeat_same_missing_prev_count(dbg_repeat_same_missing_prev_count),
    .dbg_repeat_current_round_unique_count(dbg_repeat_current_round_unique_count),
    .dbg_repeat_accum_complete        (dbg_repeat_accum_complete),
    .dbg_repeat_legal_payload_count   (dbg_repeat_legal_payload_count),
    .dbg_repeat_duplicate_payload_count(dbg_repeat_duplicate_payload_count),
    .dbg_repeat_bad_header_count      (dbg_repeat_bad_header_count),
    .dbg_repeat_incomplete_payload_count(dbg_repeat_incomplete_payload_count),
    .dbg_repeat_rx_er_packet_count    (dbg_repeat_rx_er_packet_count),
    .dbg_repeat_critical_er_packet_count(dbg_repeat_critical_er_packet_count),
    .dbg_repeat_tail_er_packet_count  (dbg_repeat_tail_er_packet_count),
    .dbg_repeat_last_header_packet_id (dbg_repeat_last_header_packet_id),
    .dbg_repeat_last_legal_packet_id  (dbg_repeat_last_legal_packet_id),
    .dbg_repeat_last_rx_er_packet_id  (dbg_repeat_last_rx_er_packet_id),
    .dbg_repeat_last_er_byte_index    (dbg_repeat_last_er_byte_index),
    .dbg_repeat_min_er_byte_index     (dbg_repeat_min_er_byte_index),
    .dbg_repeat_max_er_byte_index     (dbg_repeat_max_er_byte_index),
    .dbg_repeat_last_frame_id         (dbg_repeat_last_frame_id),
    .dbg_repeat_scan_word_index       (dbg_repeat_scan_word_index),
    .dbg_repeat_scan_round_valid_word (dbg_repeat_scan_round_valid_word),
    .dbg_repeat_scan_accum_valid_word (dbg_repeat_scan_accum_valid_word),
    .dbg_repeat_scan_accum_missing_word(dbg_repeat_scan_accum_missing_word),
    .dbg_repeat_scan_valid_mask        (dbg_repeat_scan_valid_mask),
    .dbg_repeat_missing_ids_valid      (dbg_repeat_missing_ids_valid),
    .dbg_repeat_missing_id_count       (dbg_repeat_missing_id_count),
    .dbg_repeat_missing_id0_valid      (dbg_repeat_missing_id0_valid),
    .dbg_repeat_missing_id0            (dbg_repeat_missing_id0),
    .dbg_repeat_missing_id1_valid      (dbg_repeat_missing_id1_valid),
    .dbg_repeat_missing_id1            (dbg_repeat_missing_id1),
    .dbg_repeat_complete_round_count   (dbg_repeat_complete_round_count),
    .dbg_repeat_complete_pulse_count   (dbg_repeat_complete_pulse_count),
    .dbg_repeat_boundary_replay_accept_count(dbg_repeat_boundary_replay_accept_count),
    .dbg_repeat_replay_accept_pid0_count  (dbg_repeat_replay_accept_pid0_count_raw),
    .dbg_repeat_replay_accept_pid1_count  (dbg_repeat_replay_accept_pid1_count_raw),
    .dbg_repeat_replay_accept_pid748_count(dbg_repeat_replay_accept_pid748_count_raw),
    .dbg_repeat_replay_accept_pid749_count(dbg_repeat_replay_accept_pid749_count_raw)
);

// Stage7F14C: FPGV packets are no longer converted into a VIN stream here.
// The direct-DDR wrapper parses all four GMII channels and writes each packet
// payload to DDR according to byte_offset.
wire [31:0] ch0_overflow_count /* synthesis PAP_MARK_DEBUG="true" */, ch1_overflow_count /* synthesis PAP_MARK_DEBUG="true" */, ch2_overflow_count /* synthesis PAP_MARK_DEBUG="true" */, ch3_overflow_count /* synthesis PAP_MARK_DEBUG="true" */;

wire [15:0] fb_rgb0, fb_rgb1, fb_rgb2, fb_rgb3;
wire        fb_de0, fb_de1, fb_de2, fb_de3;
wire [3:0]  fb_init_done /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  fb_frame_done_seen /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] fb_done_cnt0 /* synthesis PAP_MARK_DEBUG="true" */, fb_done_cnt1 /* synthesis PAP_MARK_DEBUG="true" */, fb_done_cnt2 /* synthesis PAP_MARK_DEBUG="true" */, fb_done_cnt3 /* synthesis PAP_MARK_DEBUG="true" */;

// F14W: all debugger-visible CH2 signals are lifted to this top module.
// In Fabric Debugger / Select Net, set Net Name and search exactly: dbg_ch2
wire dbg_clk_core /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_clk_p2   /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_clk_pix  /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_wr_req /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_wr_done /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_wdata_req /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_wr_grant_is_ch2 /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_shared_wr_cmd_en /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_shared_wr_cmd_done /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_rd_req /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_rd_done /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_rd_ready /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_rd_data_en /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_rd_grant_is_ch2 /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_shared_rd_cmd_en /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_shared_rd_cmd_done /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_shared_rd_cmd_ready /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_done_bank /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_done_toggle /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_init_done_core /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_hdr_accept /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_hdr_last_by_id /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_hdr_last_by_offset /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_rx_prevbank_candidate /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_rx_relaxed_complete /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_rx_publish_candidate /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_pkt_publish /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_meta_wr_en /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_meta_pending_valid /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_meta_full /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_meta_empty /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_meta_rd_en /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_cmd_active /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_cmd_started /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_prev_publish_pending /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_prev_publish_bank /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_ch2_prev_publish_latched_count /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_ch2_prevbank_publish_count /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_ch2_prevbank_skip_count /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_ch2_prevbank_packet_count_at_event /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_ch2_meta_wr_count /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_ch2_meta_rd_count /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_ch2_ddr_wreq_count /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_ch2_ddr_wdone_count /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_ch2_force_done_count /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_ch2_last_good_packet_id /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_ch2_last_good_packet_total /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_ch2_last_good_payload_len /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_ch2_last_good_byte_offset /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_ch2_relaxed_publish_count /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_ch2_strict_publish_count /* synthesis PAP_MARK_DEBUG="true" */;
// F14Y: search exactly dbg_ch2_drop or dbg_ch2_slot in Fabric Debugger.
wire [31:0] dbg_ch2_drop_bad_header_count /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_ch2_drop_no_free_slot_count /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_ch2_drop_meta_pending_count /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_ch2_drop_meta_full_count /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_ch2_drop_gmii_error_count /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_ch2_drop_payload_error_count /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] dbg_ch2_duplicate_packet_count /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_ch2_slot_busy_count /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_ch2_slot_busy_max /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_have_free_slot /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_fb_init_done_top /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_fb_frame_done_seen_top /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_rd_en_pix /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_rd_line_req_pix /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_fb_de_pix /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_ch2_fb_rgb_pix /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_video_show_pix /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_ch_visible_pix /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_in_window_pix /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] dbg_ch2_hdmi_rgb565_pix /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_led6_done_sticky /* synthesis PAP_MARK_DEBUG="true" */;
wire dbg_ch2_led7_video_show /* synthesis PAP_MARK_DEBUG="true" */;

// F14ZQ 4CH native-quad display probes.  Search dbg_quad in Fabric Debugger.
reg         dbg_quad_mirror_ch2_mode /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
wire [3:0]  dbg_quad_rx_activity_live /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_quad_udp5000_seen /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_quad_fpgv_seen /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_quad_frame_done_seen /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_quad_fb_init_done_pix /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_quad_ch_visible_pix /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_quad_in_window_pix /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_quad_rd_en_pix /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_quad_rd_line_req_pix /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_quad_fb_de_pix /* synthesis PAP_MARK_DEBUG="true" */;

// PLATE_V1_STEP3_FIX6: fixed overlay, color masks, aligned Sobel/color-near probes.
// Search dbg_plate in Fabric Debugger.
wire [3:0]  dbg_plate_overlay_box_hit_pix /* synthesis PAP_MARK_DEBUG="true" */;
wire [11:0] dbg_plate_local_x_pix        /* synthesis PAP_MARK_DEBUG="true" */;
wire [11:0] dbg_plate_local_y_pix        /* synthesis PAP_MARK_DEBUG="true" */;
wire        dbg_plate_overlay_enable_pix /* synthesis PAP_MARK_DEBUG="true" */;
wire [2:0]  dbg_plate_debug_mode_pix     /* synthesis PAP_MARK_DEBUG="true" */;
wire [10:0] dbg_plate_sobel_th_pix       /* synthesis PAP_MARK_DEBUG="true" */;
wire [7:0]  dbg_plate_gray_pix           /* synthesis PAP_MARK_DEBUG="true" */;
wire [10:0] dbg_plate_sobel_abs_gx_pix   /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_plate_blue_mask_pix      /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_plate_green_mask_pix     /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_plate_color_mask_pix     /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_plate_color_clean_mask_pix/* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_plate_color_near_mask_pix/* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_plate_edge_mask_pix      /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_plate_usable_edge_mask_pix/* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_plate_aligned_valid_pix  /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_plate_same_pixel_pix     /* synthesis PAP_MARK_DEBUG="true" */;
// PLATE_V1_STEP4 morphology / projection bbox probes.
wire [3:0]  dbg_plate_morph_valid_pix    /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_plate_morph_mask_pix     /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_plate_bbox_valid_pix     /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_plate_bbox_candidate_valid_pix /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_plate_bbox_update_pulse_pix /* synthesis PAP_MARK_DEBUG="true" */;
wire [11:0] dbg_plate_bbox_x0_pix        /* synthesis PAP_MARK_DEBUG="true" */;
wire [11:0] dbg_plate_bbox_y0_pix        /* synthesis PAP_MARK_DEBUG="true" */;
wire [11:0] dbg_plate_bbox_x1_pix        /* synthesis PAP_MARK_DEBUG="true" */;
wire [11:0] dbg_plate_bbox_y1_pix        /* synthesis PAP_MARK_DEBUG="true" */;
wire [19:0] dbg_plate_bbox_score_pix     /* synthesis PAP_MARK_DEBUG="true" */;
wire [19:0] dbg_plate_morph_pixel_count_pix /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]  dbg_plate_bbox_miss_count_pix /* synthesis PAP_MARK_DEBUG="true" */;
wire        vs_o;
wire        hs_o;
wire        vg_de_o;
wire        de_re;
wire [11:0] vg_x;
wire [11:0] vg_y;

wire [12:0] pre_x = {1'b0, vg_x} + 13'd2;
wire        y_top = (vg_y >= WIN0_Y) && (vg_y < WIN0_Y + WIN_H);
wire        y_bot = (vg_y >= WIN1_Y) && (vg_y < WIN1_Y + WIN_H);
wire        pre_x_left  = (pre_x >= WIN0_X) && (pre_x < WIN0_X + WIN_W);
wire        pre_x_right = (pre_x >= WIN1_X) && (pre_x < WIN1_X + WIN_W);
wire        x_left_now  = (vg_x >= WIN0_X) && (vg_x < WIN0_X + WIN_W);
wire        x_right_now = (vg_x >= WIN1_X) && (vg_x < WIN1_X + WIN_W);

wire rd_en_ch0 = de_re && y_top && pre_x_left;
wire rd_en_ch1 = de_re && y_top && pre_x_right;
wire rd_en_ch2 = de_re && y_bot && pre_x_left;
wire rd_en_ch3 = de_re && y_bot && pre_x_right;

// F14H: prefetch several lines ahead.  F14F/F14G proved prefetch helps;
// the remaining left-edge flicker can occur when DDR returns the line too late
// for the first visible pixels.  Four-line lead is still inside rd_fram_buf's
// rolling line buffer depth and gives much more DDR arbitration margin.
localparam [11:0] PREFETCH_LEAD_LINES = 12'd6;
wire line_req_x0 = vg_de_o && (vg_x == 12'd0);
wire y_top_prefetch = (vg_y >= (WIN0_Y - PREFETCH_LEAD_LINES)) &&
                      (vg_y <  (WIN0_Y + WIN_H - PREFETCH_LEAD_LINES));
wire y_bot_prefetch = (vg_y >= (WIN1_Y - PREFETCH_LEAD_LINES)) &&
                      (vg_y <  (WIN1_Y + WIN_H - PREFETCH_LEAD_LINES));
wire rd_line_req_ch0 = line_req_x0 && y_top_prefetch;
wire rd_line_req_ch1 = line_req_x0 && y_top_prefetch;
wire rd_line_req_ch2 = line_req_x0 && y_bot_prefetch;
wire rd_line_req_ch3 = line_req_x0 && y_bot_prefetch;

wire [CTRL_ADDR_WIDTH-1:0]  axi_awaddr;
wire [3:0]                  axi_awuser_id;
wire [3:0]                  axi_awlen;
wire                        axi_awready;
wire                        axi_awvalid;
wire [MEM_DQ_WIDTH*8-1:0]   axi_wdata;
wire [MEM_DQ_WIDTH*8/8-1:0] axi_wstrb;
wire                        axi_wready;
wire                        axi_wusero_last;
wire [CTRL_ADDR_WIDTH-1:0]  axi_araddr;
wire [3:0]                  axi_aruser_id;
wire [3:0]                  axi_arlen;
wire                        axi_arready;
wire                        axi_arvalid;
wire [MEM_DQ_WIDTH*8-1:0]   axi_rdata;
wire                        axi_rvalid;
wire [3:0]                  axi_rid;
wire                        axi_rlast;
wire                        core_clk;
wire                        pll_lock;
wire                        ddr_init_done;
reg  [26:0]                 cnt;
reg                         heart_beat_led;

fram_buf_4ch_direct_f14d #(
    .MEM_ROW_WIDTH(MEM_ROW_ADDR_WIDTH),
    .MEM_COLUMN_WIDTH(MEM_COL_ADDR_WIDTH),
    .MEM_BANK_WIDTH(MEM_BADDR_WIDTH),
    .MEM_DQ_WIDTH(MEM_DQ_WIDTH),
    .H_NUM(12'd800),
    .V_NUM(12'd480),
    .PIX_WIDTH(16),
    .LINE_ADDR_WIDTH(19),
    .MIN_PACKETS_FOR_PREV_BANK_PUBLISH(MIN_PACKETS_FOR_PREV_BANK_PUBLISH),
    .FORCE_CH2_DONE_AFTER_ANY_WRITE(FORCE_CH2_DONE_AFTER_ANY_WRITE)
) u_fram_buf_4ch_direct_f14d (
    .ddr_clk(core_clk),
    .ddr_rstn(ddr_init_done),
    .ch0_gmii_clk(p0_clk), .ch0_gmii_rstn(p0_rstn & sys_rst_n), .ch0_gmii_rxd(p0_rxd), .ch0_gmii_dv(p0_dv), .ch0_gmii_er(p0_er),
    .ch1_gmii_clk(p1_clk), .ch1_gmii_rstn(p1_rstn & sys_rst_n), .ch1_gmii_rxd(p1_rxd), .ch1_gmii_dv(p1_dv), .ch1_gmii_er(p1_er),
    .ch2_gmii_clk(p2_clk), .ch2_gmii_rstn(p2_rstn & sys_rst_n), .ch2_gmii_rxd(p2_rxd), .ch2_gmii_dv(p2_dv), .ch2_gmii_er(p2_er),
    .ch3_gmii_clk(p3_clk), .ch3_gmii_rstn(p3_rstn & sys_rst_n), .ch3_gmii_rxd(p3_rxd), .ch3_gmii_dv(p3_dv), .ch3_gmii_er(p3_er),
    .init_done(fb_init_done), .frame_done_seen(fb_frame_done_seen),
    .ch0_frame_done_count(fb_done_cnt0), .ch1_frame_done_count(fb_done_cnt1), .ch2_frame_done_count(fb_done_cnt2), .ch3_frame_done_count(fb_done_cnt3),
    .ch0_overflow_count(ch0_overflow_count), .ch1_overflow_count(ch1_overflow_count), .ch2_overflow_count(ch2_overflow_count), .ch3_overflow_count(ch3_overflow_count),
    .vout_clk(pix_clk), .rd_fsync(vs_o), .rd_en_ch0(rd_en_ch0), .rd_en_ch1(rd_en_ch1), .rd_en_ch2(rd_en_ch2), .rd_en_ch3(rd_en_ch3),
    .rd_line_req_ch0(rd_line_req_ch0), .rd_line_req_ch1(rd_line_req_ch1), .rd_line_req_ch2(rd_line_req_ch2), .rd_line_req_ch3(rd_line_req_ch3),
    .vout_de_ch0(fb_de0), .vout_de_ch1(fb_de1), .vout_de_ch2(fb_de2), .vout_de_ch3(fb_de3),
    .vout_data_ch0(fb_rgb0), .vout_data_ch1(fb_rgb1), .vout_data_ch2(fb_rgb2), .vout_data_ch3(fb_rgb3),
    .axi_awaddr(axi_awaddr), .axi_awid(axi_awuser_id), .axi_awlen(axi_awlen), .axi_awsize(), .axi_awburst(), .axi_awready(axi_awready), .axi_awvalid(axi_awvalid),
    .axi_wdata(axi_wdata), .axi_wstrb(axi_wstrb), .axi_wlast(axi_wusero_last), .axi_wvalid(), .axi_wready(axi_wready), .axi_bid(4'd0),
    .axi_araddr(axi_araddr), .axi_arid(axi_aruser_id), .axi_arlen(axi_arlen), .axi_arsize(), .axi_arburst(), .axi_arvalid(axi_arvalid), .axi_arready(axi_arready),
    .axi_rready(), .axi_rdata(axi_rdata), .axi_rvalid(axi_rvalid), .axi_rlast(axi_rlast), .axi_rid(axi_rid),
    .dbg_ch2_wr_req_out(dbg_ch2_wr_req),
    .dbg_ch2_wr_done_out(dbg_ch2_wr_done),
    .dbg_ch2_wdata_req_out(dbg_ch2_wdata_req),
    .dbg_ch2_wr_grant_is_ch2_out(dbg_ch2_wr_grant_is_ch2),
    .dbg_shared_wr_cmd_en_out(dbg_shared_wr_cmd_en),
    .dbg_shared_wr_cmd_done_out(dbg_shared_wr_cmd_done),
    .dbg_ch2_rd_req_out(dbg_ch2_rd_req),
    .dbg_ch2_rd_done_out(dbg_ch2_rd_done),
    .dbg_ch2_rd_ready_out(dbg_ch2_rd_ready),
    .dbg_ch2_rd_data_en_out(dbg_ch2_rd_data_en),
    .dbg_ch2_rd_grant_is_ch2_out(dbg_ch2_rd_grant_is_ch2),
    .dbg_shared_rd_cmd_en_out(dbg_shared_rd_cmd_en),
    .dbg_shared_rd_cmd_done_out(dbg_shared_rd_cmd_done),
    .dbg_shared_rd_cmd_ready_out(dbg_shared_rd_cmd_ready),
    .dbg_ch2_done_bank_out(dbg_ch2_done_bank),
    .dbg_ch2_done_toggle_out(dbg_ch2_done_toggle),
    .dbg_ch2_init_done_out(dbg_ch2_init_done_core),
    .dbg_ch2_hdr_accept_out(dbg_ch2_hdr_accept),
    .dbg_ch2_hdr_last_by_id_out(dbg_ch2_hdr_last_by_id),
    .dbg_ch2_hdr_last_by_offset_out(dbg_ch2_hdr_last_by_offset),
    .dbg_ch2_rx_prevbank_candidate_out(dbg_ch2_rx_prevbank_candidate),
    .dbg_ch2_rx_relaxed_complete_out(dbg_ch2_rx_relaxed_complete),
    .dbg_ch2_rx_publish_candidate_out(dbg_ch2_rx_publish_candidate),
    .dbg_ch2_pkt_publish_out(dbg_ch2_pkt_publish),
    .dbg_ch2_meta_wr_en_out(dbg_ch2_meta_wr_en),
    .dbg_ch2_meta_pending_valid_out(dbg_ch2_meta_pending_valid),
    .dbg_ch2_meta_full_out(dbg_ch2_meta_full),
    .dbg_ch2_meta_empty_out(dbg_ch2_meta_empty),
    .dbg_ch2_meta_rd_en_out(dbg_ch2_meta_rd_en),
    .dbg_ch2_cmd_active_out(dbg_ch2_cmd_active),
    .dbg_ch2_cmd_started_out(dbg_ch2_cmd_started),
    .dbg_ch2_prev_publish_pending_out(dbg_ch2_prev_publish_pending),
    .dbg_ch2_prev_publish_bank_out(dbg_ch2_prev_publish_bank),
    .dbg_ch2_prev_publish_latched_count_out(dbg_ch2_prev_publish_latched_count),
    .dbg_ch2_prevbank_publish_count_out(dbg_ch2_prevbank_publish_count),
    .dbg_ch2_prevbank_skip_count_out(dbg_ch2_prevbank_skip_count),
    .dbg_ch2_prevbank_packet_count_at_event_out(dbg_ch2_prevbank_packet_count_at_event),
    .dbg_ch2_meta_wr_count_out(dbg_ch2_meta_wr_count),
    .dbg_ch2_meta_rd_count_out(dbg_ch2_meta_rd_count),
    .dbg_ch2_ddr_wreq_count_out(dbg_ch2_ddr_wreq_count),
    .dbg_ch2_ddr_wdone_count_out(dbg_ch2_ddr_wdone_count),
    .dbg_ch2_force_done_count_out(dbg_ch2_force_done_count),
    .dbg_ch2_last_good_packet_id_out(dbg_ch2_last_good_packet_id),
    .dbg_ch2_last_good_packet_total_out(dbg_ch2_last_good_packet_total),
    .dbg_ch2_last_good_payload_len_out(dbg_ch2_last_good_payload_len),
    .dbg_ch2_last_good_byte_offset_out(dbg_ch2_last_good_byte_offset),
    .dbg_ch2_relaxed_publish_count_out(dbg_ch2_relaxed_publish_count),
    .dbg_ch2_strict_publish_count_out(dbg_ch2_strict_publish_count),
    .dbg_ch2_drop_bad_header_count_out(dbg_ch2_drop_bad_header_count),
    .dbg_ch2_drop_no_free_slot_count_out(dbg_ch2_drop_no_free_slot_count),
    .dbg_ch2_drop_meta_pending_count_out(dbg_ch2_drop_meta_pending_count),
    .dbg_ch2_drop_meta_full_count_out(dbg_ch2_drop_meta_full_count),
    .dbg_ch2_drop_gmii_error_count_out(dbg_ch2_drop_gmii_error_count),
    .dbg_ch2_drop_payload_error_count_out(dbg_ch2_drop_payload_error_count),
    .dbg_ch2_duplicate_packet_count_out(dbg_ch2_duplicate_packet_count),
    .dbg_ch2_slot_busy_count_out(dbg_ch2_slot_busy_count),
    .dbg_ch2_slot_busy_max_out(dbg_ch2_slot_busy_max),
    .dbg_ch2_have_free_slot_out(dbg_ch2_have_free_slot)
);

// F14G: synchronize cfg_clk/core_clk ready signals into pix_clk before they
// reset or gate HDMI timing. F14F timing reports still showed async paths from
// cfg_clk/ddrphy_clkin into sync_vg and RGB output logic.
reg [2:0] rstn_out_pix_sync;
reg [2:0] init_over_tx_pix_sync;
reg [2:0] ddr_init_done_pix_sync;
always @(posedge pix_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        rstn_out_pix_sync       <= 3'b000;
        init_over_tx_pix_sync   <= 3'b000;
        ddr_init_done_pix_sync  <= 3'b000;
    end else begin
        rstn_out_pix_sync       <= {rstn_out_pix_sync[1:0], rstn_out};
        init_over_tx_pix_sync   <= {init_over_tx_pix_sync[1:0], init_over_tx};
        ddr_init_done_pix_sync  <= {ddr_init_done_pix_sync[1:0], ddr_init_done};
    end
end

wire pix_video_rstn = rstn_out_pix_sync[2] & init_over_tx_pix_sync[2] & ddr_init_done_pix_sync[2];

sync_vg #(
    .V_TOTAL(12'd1125), .V_FP(12'd4), .V_BP(12'd36), .V_SYNC(12'd5), .V_ACT(12'd1080),
    .H_TOTAL(12'd2200), .H_FP(12'd88), .H_BP(12'd148), .H_SYNC(12'd44), .H_ACT(12'd1920), .HV_OFFSET(12'd0)
) u_sync_vg_1080p (
    .clk    (pix_clk),
    .rstn   (pix_video_rstn),
    .vs_out (vs_o),
    .hs_out (hs_o),
    .de_out (vg_de_o),
    .de_re  (de_re),
    .x_act  (vg_x),
    .y_act  (vg_y)
);

wire [15:0] test_rgb565 =
    (vg_x < 12'd274)  ? 16'hF800 :
    (vg_x < 12'd548)  ? 16'hFFE0 :
    (vg_x < 12'd822)  ? 16'h07E0 :
    (vg_x < 12'd1096) ? 16'h07FF :
    (vg_x < 12'd1370) ? 16'h001F :
    (vg_x < 12'd1644) ? 16'hF81F :
                         16'hFFFF;

// F14D: per-channel loss timeout. A new frame_done_count value means the
// channel has published a complete DDR bank. With FREEZE_ON_LOSS=0, the HDMI
// compositor blacks that window after LOSS_TIMEOUT_CORE_CYCLES without a new
// completed frame; with FREEZE_ON_LOSS=1 it keeps reading the last completed bank.
reg [31:0] last_done_cnt0, last_done_cnt1, last_done_cnt2, last_done_cnt3;
reg [31:0] loss_cnt0, loss_cnt1, loss_cnt2, loss_cnt3;
reg [3:0]  ch_active_core;

always @(posedge core_clk) begin
    if(!ddr_init_done) begin
        last_done_cnt0 <= 32'd0; last_done_cnt1 <= 32'd0; last_done_cnt2 <= 32'd0; last_done_cnt3 <= 32'd0;
        loss_cnt0 <= 32'd0; loss_cnt1 <= 32'd0; loss_cnt2 <= 32'd0; loss_cnt3 <= 32'd0;
        ch_active_core <= 4'b0000;
    end else begin
        if(fb_done_cnt0 != last_done_cnt0) begin
            last_done_cnt0 <= fb_done_cnt0; loss_cnt0 <= 32'd0; ch_active_core[0] <= 1'b1;
        end else if(loss_cnt0 < LOSS_TIMEOUT_CORE_CYCLES) begin
            loss_cnt0 <= loss_cnt0 + 32'd1;
        end else begin
            ch_active_core[0] <= 1'b0;
        end

        if(fb_done_cnt1 != last_done_cnt1) begin
            last_done_cnt1 <= fb_done_cnt1; loss_cnt1 <= 32'd0; ch_active_core[1] <= 1'b1;
        end else if(loss_cnt1 < LOSS_TIMEOUT_CORE_CYCLES) begin
            loss_cnt1 <= loss_cnt1 + 32'd1;
        end else begin
            ch_active_core[1] <= 1'b0;
        end

        if(fb_done_cnt2 != last_done_cnt2) begin
            last_done_cnt2 <= fb_done_cnt2; loss_cnt2 <= 32'd0; ch_active_core[2] <= 1'b1;
        end else if(loss_cnt2 < LOSS_TIMEOUT_CORE_CYCLES) begin
            loss_cnt2 <= loss_cnt2 + 32'd1;
        end else begin
            ch_active_core[2] <= 1'b0;
        end

        if(fb_done_cnt3 != last_done_cnt3) begin
            last_done_cnt3 <= fb_done_cnt3; loss_cnt3 <= 32'd0; ch_active_core[3] <= 1'b1;
        end else if(loss_cnt3 < LOSS_TIMEOUT_CORE_CYCLES) begin
            loss_cnt3 <= loss_cnt3 + 32'd1;
        end else begin
            ch_active_core[3] <= 1'b0;
        end
    end
end

reg [2:0] ch0_active_pix_sync, ch1_active_pix_sync, ch2_active_pix_sync, ch3_active_pix_sync;
reg [2:0] init0_pix_sync, init1_pix_sync, init2_pix_sync, init3_pix_sync;
always @(posedge pix_clk or negedge pix_video_rstn) begin
    if(!pix_video_rstn) begin
        ch0_active_pix_sync <= 3'b000;
        ch1_active_pix_sync <= 3'b000;
        ch2_active_pix_sync <= 3'b000;
        ch3_active_pix_sync <= 3'b000;
        init0_pix_sync <= 3'b000;
        init1_pix_sync <= 3'b000;
        init2_pix_sync <= 3'b000;
        init3_pix_sync <= 3'b000;
    end else begin
        ch0_active_pix_sync <= {ch0_active_pix_sync[1:0], ch_active_core[0]};
        ch1_active_pix_sync <= {ch1_active_pix_sync[1:0], ch_active_core[1]};
        ch2_active_pix_sync <= {ch2_active_pix_sync[1:0], ch_active_core[2]};
        ch3_active_pix_sync <= {ch3_active_pix_sync[1:0], ch_active_core[3]};
        init0_pix_sync <= {init0_pix_sync[1:0], fb_init_done[0]};
        init1_pix_sync <= {init1_pix_sync[1:0], fb_init_done[1]};
        init2_pix_sync <= {init2_pix_sync[1:0], fb_init_done[2]};
        init3_pix_sync <= {init3_pix_sync[1:0], fb_init_done[3]};
    end
end

wire [3:0] ch_active_pix    = {ch3_active_pix_sync[2], ch2_active_pix_sync[2], ch1_active_pix_sync[2], ch0_active_pix_sync[2]};
wire [3:0] fb_init_done_pix = {init3_pix_sync[2], init2_pix_sync[2], init1_pix_sync[2], init0_pix_sync[2]};
wire [3:0] ch_visible_pix   = FREEZE_ON_LOSS ? fb_init_done_pix : (fb_init_done_pix & ch_active_pix);

reg [2:0] any_init_pix_sync;
always @(posedge pix_clk or negedge pix_video_rstn) begin
    if(!pix_video_rstn)
        any_init_pix_sync <= 3'b000;
    else
        any_init_pix_sync <= {any_init_pix_sync[1:0], |fb_init_done_pix};
end
wire video_show_pix = any_init_pix_sync[2] && (|ch_visible_pix);

// F14W top-level debug signal assignments.
assign dbg_clk_core = core_clk;
assign dbg_clk_p2   = p2_clk;
assign dbg_clk_pix  = pix_clk;
assign dbg_ch2_fb_init_done_top       = fb_init_done[2];
assign dbg_ch2_fb_frame_done_seen_top = fb_frame_done_seen[2];
assign dbg_ch2_rd_en_pix              = rd_en_ch2;
assign dbg_ch2_rd_line_req_pix        = rd_line_req_ch2;
assign dbg_ch2_fb_de_pix              = fb_de2;
assign dbg_ch2_fb_rgb_pix             = fb_rgb2;
assign dbg_ch2_video_show_pix         = video_show_pix;
assign dbg_ch2_ch_visible_pix         = ch_visible_pix[2];
assign dbg_ch2_in_window_pix          = in_ch2_now;

wire in_ch0_now = y_top && x_left_now;
wire in_ch1_now = y_top && x_right_now;
wire in_ch2_now = y_bot && x_left_now;
wire in_ch3_now = y_bot && x_right_now;

// PLATE_V1_STEP1: per-window local pixel coordinates used only for the fixed
// box overlay.  These are valid when the corresponding in_chX_now is true.
wire [11:0] plate_local_x_left  = vg_x - WIN0_X;
wire [11:0] plate_local_x_right = vg_x - WIN1_X;
wire [11:0] plate_local_y_top   = vg_y - WIN0_Y;
wire [11:0] plate_local_y_bot   = vg_y - WIN1_Y;

always @(posedge pix_clk or negedge pix_video_rstn) begin
    if(!pix_video_rstn)
        dbg_quad_mirror_ch2_mode <= MIRROR_CH2_TO_ALL_WINDOWS;
    else
        dbg_quad_mirror_ch2_mode <= MIRROR_CH2_TO_ALL_WINDOWS;
end
assign dbg_quad_rx_activity_live   = sfp_rx_activity_live;
assign dbg_quad_udp5000_seen       = sfp_udp5000_seen;
assign dbg_quad_fpgv_seen          = sfp_fpgv_seen;
assign dbg_quad_frame_done_seen    = fb_frame_done_seen;
assign dbg_quad_fb_init_done_pix   = fb_init_done_pix;
assign dbg_quad_ch_visible_pix     = ch_visible_pix;
assign dbg_quad_in_window_pix      = {in_ch3_now, in_ch2_now, in_ch1_now, in_ch0_now};
assign dbg_quad_rd_en_pix          = {rd_en_ch3, rd_en_ch2, rd_en_ch1, rd_en_ch0};
assign dbg_quad_rd_line_req_pix    = {rd_line_req_ch3, rd_line_req_ch2, rd_line_req_ch1, rd_line_req_ch0};
assign dbg_quad_fb_de_pix          = {fb_de3, fb_de2, fb_de1, fb_de0};


// PLATE_V1_STEP3_FIX6: RGB565 preprocessing plus an aligned shared-window
// color/Sobel fusion module.  The previous separate color_near and Sobel
// pipelines could be off by several pixels; STEP3_FIX6 computes both from the
// same 9x3 window so Mode4 no longer uses random cross-pipeline intersections.
wire [15:0] plate_base_rgb0 = (ch_visible_pix[0] && fb_de0) ? fb_rgb0 : 16'h0000;
wire [15:0] plate_base_rgb1 = (ch_visible_pix[1] && fb_de1) ? fb_rgb1 : 16'h0000;
wire [15:0] plate_base_rgb2 = (ch_visible_pix[2] && fb_de2) ? fb_rgb2 : 16'h0000;
wire [15:0] plate_base_rgb3 = (ch_visible_pix[3] && fb_de3) ? fb_rgb3 : 16'h0000;

wire [15:0] plate_pre_rgb0;
wire [15:0] plate_pre_rgb1;
wire [15:0] plate_pre_rgb2;
wire [15:0] plate_pre_rgb3;
wire [7:0]  plate_gray0;
wire [7:0]  plate_gray1;
wire [7:0]  plate_gray2;
wire [7:0]  plate_gray3;
wire        plate_blue_mask0;
wire        plate_blue_mask1;
wire        plate_blue_mask2;
wire        plate_blue_mask3;
wire        plate_green_mask0;
wire        plate_green_mask1;
wire        plate_green_mask2;
wire        plate_green_mask3;
wire        plate_color_mask0;
wire        plate_color_mask1;
wire        plate_color_mask2;
wire        plate_color_mask3;

// Window DE is used by the fixed coordinate test box.  Algorithm DE is further
// gated with ch_visible/fb_de so invalid DDR-reader cycles do not enter the
// line buffers and create artificial edges.
wire        plate_win_de0  = in_ch0_now && vg_de_o;
wire        plate_win_de1  = in_ch1_now && vg_de_o;
wire        plate_win_de2  = in_ch2_now && vg_de_o;
wire        plate_win_de3  = in_ch3_now && vg_de_o;
wire        plate_algo_de0 = plate_win_de0 && ch_visible_pix[0] && fb_de0;
wire        plate_algo_de1 = plate_win_de1 && ch_visible_pix[1] && fb_de1;
wire        plate_algo_de2 = plate_win_de2 && ch_visible_pix[2] && fb_de2;
wire        plate_algo_de3 = plate_win_de3 && ch_visible_pix[3] && fb_de3;

plate_rgb565_preprocess #(
    .DEBUG_MODE(PLATE_DEBUG_MODE)
) u_plate_preprocess_ch0 (
    .rgb565_in  (plate_base_rgb0),
    .de         (plate_algo_de0),
    .rgb565_out (plate_pre_rgb0),
    .gray       (plate_gray0),
    .blue_mask  (plate_blue_mask0),
    .green_mask (plate_green_mask0),
    .color_mask (plate_color_mask0)
);

plate_rgb565_preprocess #(
    .DEBUG_MODE(PLATE_DEBUG_MODE)
) u_plate_preprocess_ch1 (
    .rgb565_in  (plate_base_rgb1),
    .de         (plate_algo_de1),
    .rgb565_out (plate_pre_rgb1),
    .gray       (plate_gray1),
    .blue_mask  (plate_blue_mask1),
    .green_mask (plate_green_mask1),
    .color_mask (plate_color_mask1)
);

plate_rgb565_preprocess #(
    .DEBUG_MODE(PLATE_DEBUG_MODE)
) u_plate_preprocess_ch2 (
    .rgb565_in  (plate_base_rgb2),
    .de         (plate_algo_de2),
    .rgb565_out (plate_pre_rgb2),
    .gray       (plate_gray2),
    .blue_mask  (plate_blue_mask2),
    .green_mask (plate_green_mask2),
    .color_mask (plate_color_mask2)
);

plate_rgb565_preprocess #(
    .DEBUG_MODE(PLATE_DEBUG_MODE)
) u_plate_preprocess_ch3 (
    .rgb565_in  (plate_base_rgb3),
    .de         (plate_algo_de3),
    .rgb565_out (plate_pre_rgb3),
    .gray       (plate_gray3),
    .blue_mask  (plate_blue_mask3),
    .green_mask (plate_green_mask3),
    .color_mask (plate_color_mask3)
);

wire        plate_edge_valid0, plate_edge_valid1, plate_edge_valid2, plate_edge_valid3;
wire        plate_edge_mask0,  plate_edge_mask1,  plate_edge_mask2,  plate_edge_mask3;
wire [10:0] plate_abs_gx0,     plate_abs_gx1,     plate_abs_gx2,     plate_abs_gx3;
wire        plate_color_clean0, plate_color_clean1, plate_color_clean2, plate_color_clean3;
wire        plate_color_near0,  plate_color_near1,  plate_color_near2,  plate_color_near3;
wire        plate_usable_edge0, plate_usable_edge1, plate_usable_edge2, plate_usable_edge3;
wire [11:0] plate_aligned_x0, plate_aligned_x1, plate_aligned_x2, plate_aligned_x3;
wire [11:0] plate_aligned_y0, plate_aligned_y1, plate_aligned_y2, plate_aligned_y3;
wire        plate_same_pixel0 = plate_edge_valid0;
wire        plate_same_pixel1 = plate_edge_valid1;
wire        plate_same_pixel2 = plate_edge_valid2;
wire        plate_same_pixel3 = plate_edge_valid3;

plate_color_sobel_fuse_aligned #(
    .IMG_W(800), .SOBEL_TH(PLATE_SOBEL_TH), .COLOR_CLEAN_MIN(4'd4), .COLOR_NEAR_MIN(6'd4)
) u_plate_fuse_ch0 (
    .clk(pix_clk), .rstn(pix_video_rstn), .de(plate_algo_de0),
    .local_x(plate_local_x_left), .local_y(plate_local_y_top),
    .gray_in(plate_gray0), .color_mask_in(plate_color_mask0),
    .aligned_valid(plate_edge_valid0), .aligned_x(plate_aligned_x0), .aligned_y(plate_aligned_y0),
    .raw_edge_mask(plate_edge_mask0), .color_clean_mask(plate_color_clean0),
    .color_near_mask(plate_color_near0), .usable_edge_mask(plate_usable_edge0), .abs_gx(plate_abs_gx0)
);
plate_color_sobel_fuse_aligned #(
    .IMG_W(800), .SOBEL_TH(PLATE_SOBEL_TH), .COLOR_CLEAN_MIN(4'd4), .COLOR_NEAR_MIN(6'd4)
) u_plate_fuse_ch1 (
    .clk(pix_clk), .rstn(pix_video_rstn), .de(plate_algo_de1),
    .local_x(plate_local_x_right), .local_y(plate_local_y_top),
    .gray_in(plate_gray1), .color_mask_in(plate_color_mask1),
    .aligned_valid(plate_edge_valid1), .aligned_x(plate_aligned_x1), .aligned_y(plate_aligned_y1),
    .raw_edge_mask(plate_edge_mask1), .color_clean_mask(plate_color_clean1),
    .color_near_mask(plate_color_near1), .usable_edge_mask(plate_usable_edge1), .abs_gx(plate_abs_gx1)
);
plate_color_sobel_fuse_aligned #(
    .IMG_W(800), .SOBEL_TH(PLATE_SOBEL_TH), .COLOR_CLEAN_MIN(4'd4), .COLOR_NEAR_MIN(6'd4)
) u_plate_fuse_ch2 (
    .clk(pix_clk), .rstn(pix_video_rstn), .de(plate_algo_de2),
    .local_x(plate_local_x_left), .local_y(plate_local_y_bot),
    .gray_in(plate_gray2), .color_mask_in(plate_color_mask2),
    .aligned_valid(plate_edge_valid2), .aligned_x(plate_aligned_x2), .aligned_y(plate_aligned_y2),
    .raw_edge_mask(plate_edge_mask2), .color_clean_mask(plate_color_clean2),
    .color_near_mask(plate_color_near2), .usable_edge_mask(plate_usable_edge2), .abs_gx(plate_abs_gx2)
);
plate_color_sobel_fuse_aligned #(
    .IMG_W(800), .SOBEL_TH(PLATE_SOBEL_TH), .COLOR_CLEAN_MIN(4'd4), .COLOR_NEAR_MIN(6'd4)
) u_plate_fuse_ch3 (
    .clk(pix_clk), .rstn(pix_video_rstn), .de(plate_algo_de3),
    .local_x(plate_local_x_right), .local_y(plate_local_y_bot),
    .gray_in(plate_gray3), .color_mask_in(plate_color_mask3),
    .aligned_valid(plate_edge_valid3), .aligned_x(plate_aligned_x3), .aligned_y(plate_aligned_y3),
    .raw_edge_mask(plate_edge_mask3), .color_clean_mask(plate_color_clean3),
    .color_near_mask(plate_color_near3), .usable_edge_mask(plate_usable_edge3), .abs_gx(plate_abs_gx3)
);

// PLATE_V1_STEP4: connect aligned usable edges into lightweight morphology,
// row/column projection and dynamic bbox publication. The algorithm consumes
// the internal usable_edge stream before overlay, so the red/black box itself
// can never feed back into detection.
wire plate_frame_start_pix = (vg_x == 12'd0) && (vg_y == 12'd0);
wire plate_morph_valid0, plate_morph_valid1, plate_morph_valid2, plate_morph_valid3;
wire plate_morph_mask0,  plate_morph_mask1,  plate_morph_mask2,  plate_morph_mask3;
wire [11:0] plate_morph_x0, plate_morph_x1, plate_morph_x2, plate_morph_x3;
wire [11:0] plate_morph_y0, plate_morph_y1, plate_morph_y2, plate_morph_y3;
wire plate_bbox_valid0, plate_bbox_valid1, plate_bbox_valid2, plate_bbox_valid3;
wire plate_bbox_candidate_valid0, plate_bbox_candidate_valid1, plate_bbox_candidate_valid2, plate_bbox_candidate_valid3;
wire plate_bbox_update0, plate_bbox_update1, plate_bbox_update2, plate_bbox_update3;
wire [11:0] plate_bbox_x0_0, plate_bbox_x0_1, plate_bbox_x0_2, plate_bbox_x0_3;
wire [11:0] plate_bbox_y0_0, plate_bbox_y0_1, plate_bbox_y0_2, plate_bbox_y0_3;
wire [11:0] plate_bbox_x1_0, plate_bbox_x1_1, plate_bbox_x1_2, plate_bbox_x1_3;
wire [11:0] plate_bbox_y1_0, plate_bbox_y1_1, plate_bbox_y1_2, plate_bbox_y1_3;
wire [19:0] plate_bbox_score0, plate_bbox_score1, plate_bbox_score2, plate_bbox_score3;
wire [3:0] plate_bbox_miss0, plate_bbox_miss1, plate_bbox_miss2, plate_bbox_miss3;
wire [19:0] plate_morph_pixels0, plate_morph_pixels1, plate_morph_pixels2, plate_morph_pixels3;
wire [19:0] plate_best_row_score0, plate_best_row_score1, plate_best_row_score2, plate_best_row_score3;
wire [19:0] plate_best_col_score0, plate_best_col_score1, plate_best_col_score2, plate_best_col_score3;

plate_edge_morph_bbox_project #(
    .IMG_W(800), .ROW_TH(PLATE_ROW_TH), .COL_TH(PLATE_COL_TH),
    .MIN_PLATE_W(PLATE_MIN_W), .MAX_PLATE_W(PLATE_MAX_W),
    .MIN_PLATE_H(PLATE_MIN_H), .MAX_PLATE_H(PLATE_MAX_H)
) u_plate_bbox_ch0 (
    .clk(pix_clk), .rstn(pix_video_rstn), .frame_start(plate_frame_start_pix),
    .in_valid(plate_edge_valid0), .in_x(plate_aligned_x0), .in_y(plate_aligned_y0), .usable_edge_in(plate_usable_edge0),
    .morph_valid(plate_morph_valid0), .morph_x(plate_morph_x0), .morph_y(plate_morph_y0), .morph_mask(plate_morph_mask0),
    .bbox_valid(plate_bbox_valid0), .bbox_x0(plate_bbox_x0_0), .bbox_y0(plate_bbox_y0_0), .bbox_x1(plate_bbox_x1_0), .bbox_y1(plate_bbox_y1_0),
    .bbox_score(plate_bbox_score0), .bbox_candidate_valid(plate_bbox_candidate_valid0), .bbox_update_pulse(plate_bbox_update0),
    .bbox_miss_count(plate_bbox_miss0), .morph_pixel_count_last(plate_morph_pixels0),
    .best_row_score_dbg(plate_best_row_score0), .best_col_score_dbg(plate_best_col_score0)
);
plate_edge_morph_bbox_project #(
    .IMG_W(800), .ROW_TH(PLATE_ROW_TH), .COL_TH(PLATE_COL_TH),
    .MIN_PLATE_W(PLATE_MIN_W), .MAX_PLATE_W(PLATE_MAX_W),
    .MIN_PLATE_H(PLATE_MIN_H), .MAX_PLATE_H(PLATE_MAX_H)
) u_plate_bbox_ch1 (
    .clk(pix_clk), .rstn(pix_video_rstn), .frame_start(plate_frame_start_pix),
    .in_valid(plate_edge_valid1), .in_x(plate_aligned_x1), .in_y(plate_aligned_y1), .usable_edge_in(plate_usable_edge1),
    .morph_valid(plate_morph_valid1), .morph_x(plate_morph_x1), .morph_y(plate_morph_y1), .morph_mask(plate_morph_mask1),
    .bbox_valid(plate_bbox_valid1), .bbox_x0(plate_bbox_x0_1), .bbox_y0(plate_bbox_y0_1), .bbox_x1(plate_bbox_x1_1), .bbox_y1(plate_bbox_y1_1),
    .bbox_score(plate_bbox_score1), .bbox_candidate_valid(plate_bbox_candidate_valid1), .bbox_update_pulse(plate_bbox_update1),
    .bbox_miss_count(plate_bbox_miss1), .morph_pixel_count_last(plate_morph_pixels1),
    .best_row_score_dbg(plate_best_row_score1), .best_col_score_dbg(plate_best_col_score1)
);
plate_edge_morph_bbox_project #(
    .IMG_W(800), .ROW_TH(PLATE_ROW_TH), .COL_TH(PLATE_COL_TH),
    .MIN_PLATE_W(PLATE_MIN_W), .MAX_PLATE_W(PLATE_MAX_W),
    .MIN_PLATE_H(PLATE_MIN_H), .MAX_PLATE_H(PLATE_MAX_H)
) u_plate_bbox_ch2 (
    .clk(pix_clk), .rstn(pix_video_rstn), .frame_start(plate_frame_start_pix),
    .in_valid(plate_edge_valid2), .in_x(plate_aligned_x2), .in_y(plate_aligned_y2), .usable_edge_in(plate_usable_edge2),
    .morph_valid(plate_morph_valid2), .morph_x(plate_morph_x2), .morph_y(plate_morph_y2), .morph_mask(plate_morph_mask2),
    .bbox_valid(plate_bbox_valid2), .bbox_x0(plate_bbox_x0_2), .bbox_y0(plate_bbox_y0_2), .bbox_x1(plate_bbox_x1_2), .bbox_y1(plate_bbox_y1_2),
    .bbox_score(plate_bbox_score2), .bbox_candidate_valid(plate_bbox_candidate_valid2), .bbox_update_pulse(plate_bbox_update2),
    .bbox_miss_count(plate_bbox_miss2), .morph_pixel_count_last(plate_morph_pixels2),
    .best_row_score_dbg(plate_best_row_score2), .best_col_score_dbg(plate_best_col_score2)
);
plate_edge_morph_bbox_project #(
    .IMG_W(800), .ROW_TH(PLATE_ROW_TH), .COL_TH(PLATE_COL_TH),
    .MIN_PLATE_W(PLATE_MIN_W), .MAX_PLATE_W(PLATE_MAX_W),
    .MIN_PLATE_H(PLATE_MIN_H), .MAX_PLATE_H(PLATE_MAX_H)
) u_plate_bbox_ch3 (
    .clk(pix_clk), .rstn(pix_video_rstn), .frame_start(plate_frame_start_pix),
    .in_valid(plate_edge_valid3), .in_x(plate_aligned_x3), .in_y(plate_aligned_y3), .usable_edge_in(plate_usable_edge3),
    .morph_valid(plate_morph_valid3), .morph_x(plate_morph_x3), .morph_y(plate_morph_y3), .morph_mask(plate_morph_mask3),
    .bbox_valid(plate_bbox_valid3), .bbox_x0(plate_bbox_x0_3), .bbox_y0(plate_bbox_y0_3), .bbox_x1(plate_bbox_x1_3), .bbox_y1(plate_bbox_y1_3),
    .bbox_score(plate_bbox_score3), .bbox_candidate_valid(plate_bbox_candidate_valid3), .bbox_update_pulse(plate_bbox_update3),
    .bbox_miss_count(plate_bbox_miss3), .morph_pixel_count_last(plate_morph_pixels3),
    .best_row_score_dbg(plate_best_row_score3), .best_col_score_dbg(plate_best_col_score3)
);

wire [15:0] plate_dbg_rgb0 = (PLATE_DEBUG_MODE == 3'd4) ? (plate_usable_edge0 ? 16'hFFFF : 16'h0000) :
                             (PLATE_DEBUG_MODE == 3'd5) ? (plate_usable_edge0 ? 16'hFFFF : plate_base_rgb0) :
                             (PLATE_DEBUG_MODE == 3'd6) ? (plate_edge_mask0  ? 16'hFFFF : 16'h0000) :
                             (PLATE_DEBUG_MODE == 3'd7) ? (plate_color_near0 ? 16'hFFFF : 16'h0000) :
                                                          plate_pre_rgb0;
wire [15:0] plate_dbg_rgb1 = (PLATE_DEBUG_MODE == 3'd4) ? (plate_usable_edge1 ? 16'hFFFF : 16'h0000) :
                             (PLATE_DEBUG_MODE == 3'd5) ? (plate_usable_edge1 ? 16'hFFFF : plate_base_rgb1) :
                             (PLATE_DEBUG_MODE == 3'd6) ? (plate_edge_mask1  ? 16'hFFFF : 16'h0000) :
                             (PLATE_DEBUG_MODE == 3'd7) ? (plate_color_near1 ? 16'hFFFF : 16'h0000) :
                                                          plate_pre_rgb1;
wire [15:0] plate_dbg_rgb2 = (PLATE_DEBUG_MODE == 3'd4) ? (plate_usable_edge2 ? 16'hFFFF : 16'h0000) :
                             (PLATE_DEBUG_MODE == 3'd5) ? (plate_usable_edge2 ? 16'hFFFF : plate_base_rgb2) :
                             (PLATE_DEBUG_MODE == 3'd6) ? (plate_edge_mask2  ? 16'hFFFF : 16'h0000) :
                             (PLATE_DEBUG_MODE == 3'd7) ? (plate_color_near2 ? 16'hFFFF : 16'h0000) :
                                                          plate_pre_rgb2;
wire [15:0] plate_dbg_rgb3 = (PLATE_DEBUG_MODE == 3'd4) ? (plate_usable_edge3 ? 16'hFFFF : 16'h0000) :
                             (PLATE_DEBUG_MODE == 3'd5) ? (plate_usable_edge3 ? 16'hFFFF : plate_base_rgb3) :
                             (PLATE_DEBUG_MODE == 3'd6) ? (plate_edge_mask3  ? 16'hFFFF : 16'h0000) :
                             (PLATE_DEBUG_MODE == 3'd7) ? (plate_color_near3 ? 16'hFFFF : 16'h0000) :
                                                          plate_pre_rgb3;

wire [15:0] plate_rgb0;
wire [15:0] plate_rgb1;
wire [15:0] plate_rgb2;
wire [15:0] plate_rgb3;
wire        plate_box_hit0;
wire        plate_box_hit1;
wire        plate_box_hit2;
wire        plate_box_hit3;

// STEP4 dynamic bbox overlay. Set PLATE_SHOW_FIXED_TEST_BOX=1 only when the
// original coordinate test frame is needed again.
wire plate_overlay_valid0 = PLATE_SHOW_FIXED_TEST_BOX ? 1'b1 : plate_bbox_valid0;
wire plate_overlay_valid1 = PLATE_SHOW_FIXED_TEST_BOX ? 1'b1 : plate_bbox_valid1;
wire plate_overlay_valid2 = PLATE_SHOW_FIXED_TEST_BOX ? 1'b1 : plate_bbox_valid2;
wire plate_overlay_valid3 = PLATE_SHOW_FIXED_TEST_BOX ? 1'b1 : plate_bbox_valid3;
wire [11:0] plate_overlay_x0_0 = PLATE_SHOW_FIXED_TEST_BOX ? 12'd200 : plate_bbox_x0_0;
wire [11:0] plate_overlay_y0_0 = PLATE_SHOW_FIXED_TEST_BOX ? 12'd180 : plate_bbox_y0_0;
wire [11:0] plate_overlay_x1_0 = PLATE_SHOW_FIXED_TEST_BOX ? 12'd500 : plate_bbox_x1_0;
wire [11:0] plate_overlay_y1_0 = PLATE_SHOW_FIXED_TEST_BOX ? 12'd260 : plate_bbox_y1_0;
wire [11:0] plate_overlay_x0_1 = PLATE_SHOW_FIXED_TEST_BOX ? 12'd200 : plate_bbox_x0_1;
wire [11:0] plate_overlay_y0_1 = PLATE_SHOW_FIXED_TEST_BOX ? 12'd180 : plate_bbox_y0_1;
wire [11:0] plate_overlay_x1_1 = PLATE_SHOW_FIXED_TEST_BOX ? 12'd500 : plate_bbox_x1_1;
wire [11:0] plate_overlay_y1_1 = PLATE_SHOW_FIXED_TEST_BOX ? 12'd260 : plate_bbox_y1_1;
wire [11:0] plate_overlay_x0_2 = PLATE_SHOW_FIXED_TEST_BOX ? 12'd200 : plate_bbox_x0_2;
wire [11:0] plate_overlay_y0_2 = PLATE_SHOW_FIXED_TEST_BOX ? 12'd180 : plate_bbox_y0_2;
wire [11:0] plate_overlay_x1_2 = PLATE_SHOW_FIXED_TEST_BOX ? 12'd500 : plate_bbox_x1_2;
wire [11:0] plate_overlay_y1_2 = PLATE_SHOW_FIXED_TEST_BOX ? 12'd260 : plate_bbox_y1_2;
wire [11:0] plate_overlay_x0_3 = PLATE_SHOW_FIXED_TEST_BOX ? 12'd200 : plate_bbox_x0_3;
wire [11:0] plate_overlay_y0_3 = PLATE_SHOW_FIXED_TEST_BOX ? 12'd180 : plate_bbox_y0_3;
wire [11:0] plate_overlay_x1_3 = PLATE_SHOW_FIXED_TEST_BOX ? 12'd500 : plate_bbox_x1_3;
wire [11:0] plate_overlay_y1_3 = PLATE_SHOW_FIXED_TEST_BOX ? 12'd260 : plate_bbox_y1_3;

plate_overlay_bbox_dynamic u_plate_overlay_ch0 (
    .rgb565_in(plate_dbg_rgb0), .local_x(plate_local_x_left), .local_y(plate_local_y_top), .de(plate_win_de0),
    .bbox_valid(plate_overlay_valid0), .bbox_x0(plate_overlay_x0_0), .bbox_y0(plate_overlay_y0_0), .bbox_x1(plate_overlay_x1_0), .bbox_y1(plate_overlay_y1_0),
    .rgb565_out(plate_rgb0), .border_hit(plate_box_hit0)
);
plate_overlay_bbox_dynamic u_plate_overlay_ch1 (
    .rgb565_in(plate_dbg_rgb1), .local_x(plate_local_x_right), .local_y(plate_local_y_top), .de(plate_win_de1),
    .bbox_valid(plate_overlay_valid1), .bbox_x0(plate_overlay_x0_1), .bbox_y0(plate_overlay_y0_1), .bbox_x1(plate_overlay_x1_1), .bbox_y1(plate_overlay_y1_1),
    .rgb565_out(plate_rgb1), .border_hit(plate_box_hit1)
);
plate_overlay_bbox_dynamic u_plate_overlay_ch2 (
    .rgb565_in(plate_dbg_rgb2), .local_x(plate_local_x_left), .local_y(plate_local_y_bot), .de(plate_win_de2),
    .bbox_valid(plate_overlay_valid2), .bbox_x0(plate_overlay_x0_2), .bbox_y0(plate_overlay_y0_2), .bbox_x1(plate_overlay_x1_2), .bbox_y1(plate_overlay_y1_2),
    .rgb565_out(plate_rgb2), .border_hit(plate_box_hit2)
);
plate_overlay_bbox_dynamic u_plate_overlay_ch3 (
    .rgb565_in(plate_dbg_rgb3), .local_x(plate_local_x_right), .local_y(plate_local_y_bot), .de(plate_win_de3),
    .bbox_valid(plate_overlay_valid3), .bbox_x0(plate_overlay_x0_3), .bbox_y0(plate_overlay_y0_3), .bbox_x1(plate_overlay_x1_3), .bbox_y1(plate_overlay_y1_3),
    .rgb565_out(plate_rgb3), .border_hit(plate_box_hit3)
);

assign dbg_plate_overlay_box_hit_pix = {plate_box_hit3, plate_box_hit2, plate_box_hit1, plate_box_hit0};
assign dbg_plate_overlay_enable_pix = 1'b1;
assign dbg_plate_debug_mode_pix = PLATE_DEBUG_MODE;
assign dbg_plate_sobel_th_pix = PLATE_SOBEL_TH;
assign dbg_plate_blue_mask_pix  = {plate_blue_mask3,  plate_blue_mask2,  plate_blue_mask1,  plate_blue_mask0};
assign dbg_plate_green_mask_pix = {plate_green_mask3, plate_green_mask2, plate_green_mask1, plate_green_mask0};
assign dbg_plate_color_mask_pix = {plate_color_mask3, plate_color_mask2, plate_color_mask1, plate_color_mask0};
assign dbg_plate_color_clean_mask_pix = {plate_color_clean3, plate_color_clean2, plate_color_clean1, plate_color_clean0};
assign dbg_plate_color_near_mask_pix = {plate_color_near3, plate_color_near2, plate_color_near1, plate_color_near0};
assign dbg_plate_edge_mask_pix = {plate_edge_mask3, plate_edge_mask2, plate_edge_mask1, plate_edge_mask0};
assign dbg_plate_usable_edge_mask_pix = {plate_usable_edge3, plate_usable_edge2, plate_usable_edge1, plate_usable_edge0};
assign dbg_plate_aligned_valid_pix = {plate_edge_valid3, plate_edge_valid2, plate_edge_valid1, plate_edge_valid0};
assign dbg_plate_same_pixel_pix = {plate_same_pixel3, plate_same_pixel2, plate_same_pixel1, plate_same_pixel0};
assign dbg_plate_morph_valid_pix = {plate_morph_valid3, plate_morph_valid2, plate_morph_valid1, plate_morph_valid0};
assign dbg_plate_morph_mask_pix = {plate_morph_mask3, plate_morph_mask2, plate_morph_mask1, plate_morph_mask0};
assign dbg_plate_bbox_valid_pix = {plate_bbox_valid3, plate_bbox_valid2, plate_bbox_valid1, plate_bbox_valid0};
assign dbg_plate_bbox_candidate_valid_pix = {plate_bbox_candidate_valid3, plate_bbox_candidate_valid2, plate_bbox_candidate_valid1, plate_bbox_candidate_valid0};
assign dbg_plate_bbox_update_pulse_pix = {plate_bbox_update3, plate_bbox_update2, plate_bbox_update1, plate_bbox_update0};
assign dbg_plate_bbox_x0_pix = in_ch0_now ? plate_bbox_x0_0 : in_ch1_now ? plate_bbox_x0_1 : in_ch2_now ? plate_bbox_x0_2 : in_ch3_now ? plate_bbox_x0_3 : 12'd0;
assign dbg_plate_bbox_y0_pix = in_ch0_now ? plate_bbox_y0_0 : in_ch1_now ? plate_bbox_y0_1 : in_ch2_now ? plate_bbox_y0_2 : in_ch3_now ? plate_bbox_y0_3 : 12'd0;
assign dbg_plate_bbox_x1_pix = in_ch0_now ? plate_bbox_x1_0 : in_ch1_now ? plate_bbox_x1_1 : in_ch2_now ? plate_bbox_x1_2 : in_ch3_now ? plate_bbox_x1_3 : 12'd0;
assign dbg_plate_bbox_y1_pix = in_ch0_now ? plate_bbox_y1_0 : in_ch1_now ? plate_bbox_y1_1 : in_ch2_now ? plate_bbox_y1_2 : in_ch3_now ? plate_bbox_y1_3 : 12'd0;
assign dbg_plate_bbox_score_pix = in_ch0_now ? plate_bbox_score0 : in_ch1_now ? plate_bbox_score1 : in_ch2_now ? plate_bbox_score2 : in_ch3_now ? plate_bbox_score3 : 20'd0;
assign dbg_plate_morph_pixel_count_pix = in_ch0_now ? plate_morph_pixels0 : in_ch1_now ? plate_morph_pixels1 : in_ch2_now ? plate_morph_pixels2 : in_ch3_now ? plate_morph_pixels3 : 20'd0;
assign dbg_plate_bbox_miss_count_pix = in_ch0_now ? plate_bbox_miss0 : in_ch1_now ? plate_bbox_miss1 : in_ch2_now ? plate_bbox_miss2 : in_ch3_now ? plate_bbox_miss3 : 4'd0;
assign dbg_plate_local_x_pix = (in_ch0_now || in_ch2_now) ? plate_local_x_left  :
                               (in_ch1_now || in_ch3_now) ? plate_local_x_right : 12'd0;
assign dbg_plate_local_y_pix = (in_ch0_now || in_ch1_now) ? plate_local_y_top   :
                               (in_ch2_now || in_ch3_now) ? plate_local_y_bot   : 12'd0;
assign dbg_plate_gray_pix = in_ch0_now ? plate_gray0 :
                            in_ch1_now ? plate_gray1 :
                            in_ch2_now ? plate_gray2 :
                            in_ch3_now ? plate_gray3 : 8'd0;
assign dbg_plate_sobel_abs_gx_pix = in_ch0_now ? plate_abs_gx0 :
                                    in_ch1_now ? plate_abs_gx1 :
                                    in_ch2_now ? plate_abs_gx2 :
                                    in_ch3_now ? plate_abs_gx3 : 11'd0;

wire [15:0] quad_rgb565_native =
    in_ch0_now ? plate_rgb0 :
    in_ch1_now ? plate_rgb1 :
    in_ch2_now ? plate_rgb2 :
    in_ch3_now ? plate_rgb3 :
                 16'h0000;

// Native 4CH mode is now the default: each HDMI window uses its corresponding
// recovered QSGMII channel.  Set MIRROR_CH2_TO_ALL_WINDOWS=1 only for the old
// single-camera lab check.
wire in_any_window_now = in_ch0_now | in_ch1_now | in_ch2_now | in_ch3_now;
wire [15:0] quad_rgb565_mirror_ch2 =
    (in_any_window_now && ch_visible_pix[2]) ? (fb_de2 ? fb_rgb2 : 16'h0000) : 16'h0000;

wire [15:0] quad_rgb565 = MIRROR_CH2_TO_ALL_WINDOWS ? quad_rgb565_mirror_ch2 : quad_rgb565_native;

// Do not fall back to colorbar in the final display build.  Before the first
// completed DDR frame, output black so any later picture proves DDR write/read
// and complete-bank publication are actually working.
wire [15:0] no_frame_rgb565 = BLACK_UNTIL_FRAME ? 16'h0000 : test_rgb565;
wire [15:0] hdmi_rgb565 = video_show_pix ? quad_rgb565 : no_frame_rgb565;
assign dbg_ch2_hdmi_rgb565_pix = hdmi_rgb565;

always @(posedge pix_clk or negedge pix_video_rstn) begin
    if(!pix_video_rstn) begin
        vs_out <= 1'b0;
        hs_out <= 1'b0;
        de_out <= 1'b0;
        r_out  <= 8'h00;
        g_out  <= 8'h00;
        b_out  <= 8'h00;
    end else begin
        vs_out <= vs_o;
        hs_out <= hs_o;
        de_out <= vg_de_o;
        if(vg_de_o) begin
            r_out <= {hdmi_rgb565[15:11], 3'b000};
            g_out <= {hdmi_rgb565[10:5],  2'b00};
            b_out <= {hdmi_rgb565[4:0],   3'b000};
        end else begin
            r_out <= 8'h00;
            g_out <= 8'h00;
            b_out <= 8'h00;
        end
    end
end

DDR3_50H u_DDR3_50H (
    .ref_clk(sys_clk),
    .resetn(rstn_out),
    .ddr_init_done(ddr_init_done),
    .ddrphy_clkin(core_clk),
    .pll_lock(pll_lock),
    .axi_awaddr(axi_awaddr),
    .axi_awuser_ap(1'b0),
    .axi_awuser_id(axi_awuser_id),
    .axi_awlen(axi_awlen),
    .axi_awready(axi_awready),
    .axi_awvalid(axi_awvalid),
    .axi_wdata(axi_wdata),
    .axi_wstrb(axi_wstrb),
    .axi_wready(axi_wready),
    .axi_wusero_id(),
    .axi_wusero_last(axi_wusero_last),
    .axi_araddr(axi_araddr),
    .axi_aruser_ap(1'b0),
    .axi_aruser_id(axi_aruser_id),
    .axi_arlen(axi_arlen),
    .axi_arready(axi_arready),
    .axi_arvalid(axi_arvalid),
    .axi_rdata(axi_rdata),
    .axi_rid(axi_rid),
    .axi_rlast(axi_rlast),
    .axi_rvalid(axi_rvalid),
    .apb_clk(1'b0), .apb_rst_n(1'b1), .apb_sel(1'b0), .apb_enable(1'b0), .apb_addr(8'b0), .apb_write(1'b0), .apb_ready(), .apb_wdata(16'b0), .apb_rdata(), .apb_int(),
    .mem_rst_n(mem_rst_n), .mem_ck(mem_ck), .mem_ck_n(mem_ck_n), .mem_cke(mem_cke), .mem_cs_n(mem_cs_n), .mem_ras_n(mem_ras_n), .mem_cas_n(mem_cas_n), .mem_we_n(mem_we_n), .mem_odt(mem_odt),
    .mem_a(mem_a), .mem_ba(mem_ba), .mem_dqs(mem_dqs), .mem_dqs_n(mem_dqs_n), .mem_dq(mem_dq), .mem_dm(mem_dm),
    .debug_data(), .debug_slice_state(), .debug_calib_ctrl(), .ck_dly_set_bin(), .force_ck_dly_en(1'b0), .force_ck_dly_set_bin(8'h05), .dll_step(), .dll_lock(),
    .init_read_clk_ctrl(2'b0), .init_slip_step(4'b0), .force_read_clk_ctrl(1'b0), .ddrphy_gate_update_en(1'b0), .update_com_val_err_flag(), .rd_fake_stop(1'b0)
);

always @(posedge core_clk) begin
    if(!ddr_init_done)
        cnt <= 27'd0;
    else if(cnt >= TH_1S)
        cnt <= 27'd0;
    else
        cnt <= cnt + 27'd1;
end

always @(posedge core_clk) begin
    if(!ddr_init_done)
        heart_beat_led <= 1'b1;
    else if(cnt >= TH_1S)
        heart_beat_led <= ~heart_beat_led;
end

// F14L display-build LEDs.
// LED5~LED8 are synchronized/sticky enough for board observation and do not
// replace the strict frame_done logic used by HDMI.
reg [2:0] any_udp_core_sync, any_fpgv_core_sync, any_done_core_sync;
reg       any_udp_sticky, any_fpgv_sticky, any_done_sticky;
always @(posedge core_clk) begin
    if(!ddr_init_done) begin
        any_udp_core_sync  <= 3'b000;
        any_fpgv_core_sync <= 3'b000;
        any_done_core_sync <= 3'b000;
        any_udp_sticky     <= 1'b0;
        any_fpgv_sticky    <= 1'b0;
        any_done_sticky    <= 1'b0;
    end else begin
        any_udp_core_sync  <= {any_udp_core_sync[1:0],  |sfp_udp5000_seen};
        any_fpgv_core_sync <= {any_fpgv_core_sync[1:0], |sfp_fpgv_seen};
        any_done_core_sync <= {any_done_core_sync[1:0], |fb_frame_done_seen};
        if(any_udp_core_sync[2])  any_udp_sticky  <= 1'b1;
        if(any_fpgv_core_sync[2]) any_fpgv_sticky <= 1'b1;
        if(any_done_core_sync[2]) any_done_sticky <= 1'b1;
    end
end

assign dbg_ch2_led6_done_sticky = any_done_sticky;
assign dbg_ch2_led7_video_show  = video_show_pix;

assign led[0] = heart_beat_led;
assign led[1] = init_over_tx;
assign led[2] = selected_sfp_pcs_synced;
assign led[3] = ddr_init_done;
assign led[4] = any_udp_sticky;        // UDP5000 seen on any QSGMII channel
assign led[5] = any_fpgv_sticky;       // FPGV seen on any QSGMII channel
assign led[6] = any_done_sticky;       // F14V: lights after true last-packet or latched previous-bank publication
assign led[7] = video_show_pix;        // HDMI currently using DDR quad compositor, not colorbar

endmodule


// -----------------------------------------------------------------------------
// LINK_ATTRIB_DIAG_LITE: diagnostics-only GMII DV-segment monitor.
// A segment is one contiguous gmii_rx_dv assertion interval.  This logic never
// drives the bridge, parser, DDR, HDMI, HSST, or QSGMII datapath.
// -----------------------------------------------------------------------------
module gmii_frame_shape_monitor_lite (
    input             clk,
    input             rst_n,
    input             gmii_rx_dv,
    input             gmii_rx_er,
    output reg [31:0] segment_count,
    output reg [31:0] byte_count,
    output reg [31:0] er_segment_count,
    output reg [31:0] er_cycle_count,
    output reg [31:0] short_segment_count,
    output reg [15:0] last_segment_len,
    output reg [15:0] min_segment_len,
    output reg [15:0] max_segment_len
);
reg        dv_d1;
reg        segment_er_seen;
reg [15:0] cur_segment_len;
wire       dv_rise = gmii_rx_dv && !dv_d1;
wire       dv_fall = !gmii_rx_dv && dv_d1;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        dv_d1               <= 1'b0;
        segment_er_seen     <= 1'b0;
        cur_segment_len     <= 16'd0;
        segment_count       <= 32'd0;
        byte_count          <= 32'd0;
        er_segment_count    <= 32'd0;
        er_cycle_count      <= 32'd0;
        short_segment_count <= 32'd0;
        last_segment_len    <= 16'd0;
        min_segment_len     <= 16'hffff;
        max_segment_len     <= 16'd0;
    end else begin
        dv_d1 <= gmii_rx_dv;
        if(dv_rise) begin
            segment_count   <= segment_count + 32'd1;
            byte_count      <= byte_count + 32'd1;
            cur_segment_len <= 16'd1;
            segment_er_seen <= gmii_rx_er;
            if(gmii_rx_er)
                er_cycle_count <= er_cycle_count + 32'd1;
        end else if(gmii_rx_dv) begin
            byte_count      <= byte_count + 32'd1;
            cur_segment_len <= cur_segment_len + 16'd1;
            if(gmii_rx_er) begin
                segment_er_seen <= 1'b1;
                er_cycle_count  <= er_cycle_count + 32'd1;
            end
        end
        if(dv_fall) begin
            last_segment_len <= cur_segment_len;
            if(cur_segment_len < 16'd64)
                short_segment_count <= short_segment_count + 32'd1;
            if(segment_er_seen)
                er_segment_count <= er_segment_count + 32'd1;
            if(cur_segment_len < min_segment_len)
                min_segment_len <= cur_segment_len;
            if(cur_segment_len > max_segment_len)
                max_segment_len <= cur_segment_len;
            cur_segment_len <= 16'd0;
            segment_er_seen <= 1'b0;
        end
    end
end
endmodule



// -----------------------------------------------------------------------------
// REPEAT_BITMAP_DIAG_V2: CH2 snapshot-repeat coverage monitor.
//
// Diagnostics only.  It never drives DDR, HDMI, HSST, QSGMII, or publication.
// A legal payload is a complete 1024-byte FPGV image chunk with the fixed
// 800x480 / 750-packet geometry, UDP source+destination port 5000, correct
// packet_id-to-byte_offset mapping, correct lightweight checksum16, and no
// RX_ER before the last RGB565 payload byte.  RX_ER after payload completion is
// counted separately because it may be a tail/FCS symptom rather than image
// payload corruption.
// -----------------------------------------------------------------------------
module fpgv_repeat_bitmap_diag_ch2 #(
    parameter [47:0] LOCAL_MAC = 48'h02_00_00_00_50_01,
    parameter [31:0] LOCAL_IP  = 32'hC0A8_0164,
    parameter [15:0] UDP_PORT  = 16'd5000
)(
    input             clk,
    input             rst_n,
    input      [7:0]  gmii_rxd,
    input             gmii_rx_dv,
    input             gmii_rx_er,

    output reg [31:0] dbg_repeat_round_count,
    output reg [15:0] dbg_repeat_last_round_good_count,
    output reg [15:0] dbg_repeat_last_round_missing_count,
    output reg [15:0] dbg_repeat_accum_unique_count,
    output     [15:0] dbg_repeat_accum_missing_count,
    output reg [15:0] dbg_repeat_new_unique_last_round,
    output reg [15:0] dbg_repeat_same_missing_prev_count,
    output reg [15:0] dbg_repeat_current_round_unique_count,
    output            dbg_repeat_accum_complete,
    output reg [31:0] dbg_repeat_legal_payload_count,
    output reg [31:0] dbg_repeat_duplicate_payload_count,
    output reg [31:0] dbg_repeat_bad_header_count,
    output reg [31:0] dbg_repeat_incomplete_payload_count,
    output reg [31:0] dbg_repeat_rx_er_packet_count,
    output reg [31:0] dbg_repeat_critical_er_packet_count,
    output reg [31:0] dbg_repeat_tail_er_packet_count,
    output reg [15:0] dbg_repeat_last_header_packet_id,
    output reg [15:0] dbg_repeat_last_legal_packet_id,
    output reg [15:0] dbg_repeat_last_rx_er_packet_id,
    output reg [10:0] dbg_repeat_last_er_byte_index,
    output reg [10:0] dbg_repeat_min_er_byte_index,
    output reg [10:0] dbg_repeat_max_er_byte_index,
    output reg [31:0] dbg_repeat_last_frame_id,
    output reg [4:0]  dbg_repeat_scan_word_index,
    output reg [31:0] dbg_repeat_scan_round_valid_word,
    output reg [31:0] dbg_repeat_scan_accum_valid_word,
    output reg [31:0] dbg_repeat_scan_accum_missing_word,
    output reg [31:0] dbg_repeat_scan_valid_mask,
    output reg        dbg_repeat_missing_ids_valid,
    output reg [15:0] dbg_repeat_missing_id_count,
    output reg        dbg_repeat_missing_id0_valid,
    output reg [15:0] dbg_repeat_missing_id0,
    output reg        dbg_repeat_missing_id1_valid,
    output reg [15:0] dbg_repeat_missing_id1,
    output reg [31:0] dbg_repeat_complete_round_count,
    output reg [31:0] dbg_repeat_complete_pulse_count,
    output reg [31:0] dbg_repeat_boundary_replay_accept_count,
    output reg [31:0] dbg_repeat_replay_accept_pid0_count,
    output reg [31:0] dbg_repeat_replay_accept_pid1_count,
    output reg [31:0] dbg_repeat_replay_accept_pid748_count,
    output reg [31:0] dbg_repeat_replay_accept_pid749_count
);

localparam [1:0] S_IDLE  = 2'd0;
localparam [1:0] S_PREAM = 2'd1;
localparam [1:0] S_FRAME = 2'd2;
localparam [15:0] EXPECT_WIDTH        = 16'd800;
localparam [15:0] EXPECT_HEIGHT       = 16'd480;
localparam [15:0] EXPECT_PACKET_TOTAL = 16'd750;
localparam [15:0] EXPECT_PAYLOAD_LEN  = 16'd1024;
localparam [15:0] BITMAP_PACKET_COUNT = 16'd750;
// packet_id 736..749 occupy bits 0..13 of scan word 23. Bits 14..31 map to
// non-existent packet_id 750..767 and must never be reported as missing.
localparam [31:0] LAST_WORD_VALID_MASK = 32'h0000_3fff;

reg [1:0]  state;
reg        dv_d1;
reg [2:0]  pre_cnt;
reg [10:0] byte_idx;
reg [10:0] udp_base_idx;
reg [47:0] dst_mac_shift;
reg [31:0] dst_ip_shift;
reg [31:0] magic_shift;
reg [15:0] eth_type;
reg [15:0] udp_src_port;
reg [15:0] udp_dst_port;
reg        eth_accept;
reg        ipv4_accept;
reg        udp_accept;
reg        fpgv_accept;

reg [7:0]  hdr_mode;
reg [31:0] hdr_frame_id;
reg [15:0] hdr_width;
reg [15:0] hdr_height;
reg [15:0] hdr_packet_id;
reg [15:0] hdr_packet_total;
reg [15:0] hdr_payload_len;
reg [31:0] hdr_byte_offset;
reg [15:0] hdr_checksum16;
reg        hdr_complete_seen;
reg [15:0] payload_byte_count;

reg        segment_er_seen;
reg        critical_er_seen;
reg        tail_er_seen;
reg [10:0] segment_last_er_byte_idx;

reg [767:0] round_valid_bitmap;
reg [767:0] prev_round_valid_bitmap;
reg [767:0] accum_valid_bitmap;
reg [767:0] pair_union_bitmap;
reg         prev_round_valid;
reg         round_started;
reg [15:0]  prev_round_unique_count;
reg [15:0]  pair_union_count;
reg [15:0]  new_unique_this_round;
reg [15:0]  last_header_packet_id_internal;

reg [21:0] scan_div;
reg [15:0] scan_missing_count_work;
reg        scan_missing_id0_valid_work;
reg [15:0] scan_missing_id0_work;
reg        scan_missing_id1_valid_work;
reg [15:0] scan_missing_id1_work;
reg [5:0]  scan_word_missing_count;
reg        scan_word_missing_id0_valid;
reg [4:0]  scan_word_missing_id0_bit;
reg        scan_word_missing_id1_valid;
reg [4:0]  scan_word_missing_id1_bit;
integer scan_i;
integer scan_bit_i;

wire dv_rise = gmii_rx_dv & ~dv_d1;
wire [31:0] expected_byte_offset = ({16'd0, hdr_packet_id} << 10);
wire [15:0] expected_checksum16 =
        hdr_frame_id[15:0] ^
        {13'd0, hdr_mode[2:0]} ^
        EXPECT_WIDTH ^ EXPECT_HEIGHT ^
        hdr_packet_id ^ hdr_packet_total ^ hdr_payload_len ^
        hdr_byte_offset[15:0] ^ hdr_byte_offset[31:16];
wire strict_header_valid = hdr_complete_seen && fpgv_accept &&
        (hdr_width        == EXPECT_WIDTH) &&
        (hdr_height       == EXPECT_HEIGHT) &&
        (hdr_packet_total == EXPECT_PACKET_TOTAL) &&
        (hdr_packet_id    <  EXPECT_PACKET_TOTAL) &&
        (hdr_payload_len  == EXPECT_PAYLOAD_LEN) &&
        (hdr_byte_offset  == expected_byte_offset) &&
        (hdr_checksum16   == expected_checksum16);
wire full_payload_seen = (payload_byte_count >= hdr_payload_len) &&
                         (hdr_payload_len == EXPECT_PAYLOAD_LEN);
wire legal_payload = strict_header_valid && full_payload_seen && !critical_er_seen;
// BND_REPLAY_OBS_V3: ATK sets hdr_mode[7] only for cached supplemental
// boundary replay packets. The normal low three mode bits and checksum rule are
// unchanged. Tagged replay packets contribute to the cumulative coverage bitmap
// but must not be mistaken for new normal-round boundaries.
wire boundary_replay_tag = hdr_mode[7];
wire wrap_boundary = strict_header_valid && round_started && !boundary_replay_tag &&
        ((hdr_packet_id == 16'd0) ||
         ((last_header_packet_id_internal >= 16'd700) && (hdr_packet_id <= 16'd16)));
wire [767:0] hdr_packet_onehot = ({{767{1'b0}},1'b1} << hdr_packet_id);
wire [15:0] scan_word_missing_id0 = ({11'd0, dbg_repeat_scan_word_index} << 5) + {11'd0, scan_word_missing_id0_bit};
wire [15:0] scan_word_missing_id1 = ({11'd0, dbg_repeat_scan_word_index} << 5) + {11'd0, scan_word_missing_id1_bit};
wire [15:0] scan_merged_missing_count = scan_missing_count_work + {10'd0, scan_word_missing_count};
wire        scan_merged_missing_id0_valid = scan_missing_id0_valid_work | scan_word_missing_id0_valid;
wire [15:0] scan_merged_missing_id0 = scan_missing_id0_valid_work ? scan_missing_id0_work : scan_word_missing_id0;
wire        scan_merged_missing_id1_valid = scan_missing_id1_valid_work |
                                            (scan_missing_id0_valid_work ? scan_word_missing_id0_valid : scan_word_missing_id1_valid);
wire [15:0] scan_merged_missing_id1 = scan_missing_id1_valid_work ? scan_missing_id1_work :
                                     (scan_missing_id0_valid_work ? scan_word_missing_id0 : scan_word_missing_id1);

assign dbg_repeat_accum_complete      = (dbg_repeat_accum_unique_count >= BITMAP_PACKET_COUNT);
assign dbg_repeat_accum_missing_count = (dbg_repeat_accum_unique_count >= BITMAP_PACKET_COUNT) ?
                                        16'd0 : (BITMAP_PACKET_COUNT - dbg_repeat_accum_unique_count);

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state                                  <= S_IDLE;
        dv_d1                                  <= 1'b0;
        pre_cnt                                <= 3'd0;
        byte_idx                               <= 11'd0;
        udp_base_idx                           <= 11'd34;
        dst_mac_shift                          <= 48'd0;
        dst_ip_shift                           <= 32'd0;
        magic_shift                            <= 32'd0;
        eth_type                               <= 16'd0;
        udp_src_port                           <= 16'd0;
        udp_dst_port                           <= 16'd0;
        eth_accept                             <= 1'b0;
        ipv4_accept                            <= 1'b0;
        udp_accept                             <= 1'b0;
        fpgv_accept                            <= 1'b0;
        hdr_mode                               <= 8'd0;
        hdr_frame_id                           <= 32'd0;
        hdr_width                              <= 16'd0;
        hdr_height                             <= 16'd0;
        hdr_packet_id                          <= 16'd0;
        hdr_packet_total                       <= 16'd0;
        hdr_payload_len                        <= 16'd0;
        hdr_byte_offset                        <= 32'd0;
        hdr_checksum16                         <= 16'd0;
        hdr_complete_seen                      <= 1'b0;
        payload_byte_count                     <= 16'd0;
        segment_er_seen                        <= 1'b0;
        critical_er_seen                       <= 1'b0;
        tail_er_seen                           <= 1'b0;
        segment_last_er_byte_idx               <= 11'd0;
        round_valid_bitmap                     <= {768{1'b0}};
        prev_round_valid_bitmap                <= {768{1'b0}};
        accum_valid_bitmap                     <= {768{1'b0}};
        pair_union_bitmap                      <= {768{1'b0}};
        prev_round_valid                       <= 1'b0;
        round_started                          <= 1'b0;
        prev_round_unique_count                <= 16'd0;
        pair_union_count                       <= 16'd0;
        new_unique_this_round                  <= 16'd0;
        last_header_packet_id_internal         <= 16'd0;
        dbg_repeat_round_count                 <= 32'd0;
        dbg_repeat_last_round_good_count       <= 16'd0;
        dbg_repeat_last_round_missing_count    <= BITMAP_PACKET_COUNT;
        dbg_repeat_accum_unique_count          <= 16'd0;
        dbg_repeat_new_unique_last_round       <= 16'd0;
        dbg_repeat_same_missing_prev_count     <= 16'd0;
        dbg_repeat_current_round_unique_count  <= 16'd0;
        dbg_repeat_legal_payload_count         <= 32'd0;
        dbg_repeat_duplicate_payload_count     <= 32'd0;
        dbg_repeat_bad_header_count            <= 32'd0;
        dbg_repeat_incomplete_payload_count    <= 32'd0;
        dbg_repeat_rx_er_packet_count          <= 32'd0;
        dbg_repeat_critical_er_packet_count    <= 32'd0;
        dbg_repeat_tail_er_packet_count        <= 32'd0;
        dbg_repeat_last_header_packet_id       <= 16'd0;
        dbg_repeat_last_legal_packet_id        <= 16'd0;
        dbg_repeat_last_rx_er_packet_id        <= 16'd0;
        dbg_repeat_last_er_byte_index          <= 11'd0;
        dbg_repeat_min_er_byte_index           <= 11'h7ff;
        dbg_repeat_max_er_byte_index           <= 11'd0;
        dbg_repeat_last_frame_id               <= 32'd0;
        dbg_repeat_complete_round_count        <= 32'd0;
        dbg_repeat_complete_pulse_count        <= 32'd0;
        dbg_repeat_boundary_replay_accept_count<= 32'd0;
        dbg_repeat_replay_accept_pid0_count    <= 32'd0;
        dbg_repeat_replay_accept_pid1_count    <= 32'd0;
        dbg_repeat_replay_accept_pid748_count  <= 32'd0;
        dbg_repeat_replay_accept_pid749_count  <= 32'd0;
    end else begin
        dv_d1 <= gmii_rx_dv;

        if((state != S_IDLE) && gmii_rx_dv && gmii_rx_er) begin
            segment_er_seen          <= 1'b1;
            segment_last_er_byte_idx <= byte_idx;
            dbg_repeat_last_er_byte_index <= byte_idx;
            if(byte_idx < dbg_repeat_min_er_byte_index)
                dbg_repeat_min_er_byte_index <= byte_idx;
            if(byte_idx > dbg_repeat_max_er_byte_index)
                dbg_repeat_max_er_byte_index <= byte_idx;
            if(!hdr_complete_seen || (byte_idx < (udp_base_idx + 11'd40 + hdr_payload_len)))
                critical_er_seen <= 1'b1;
            else
                tail_er_seen <= 1'b1;
        end

        case(state)
        S_IDLE: begin
            if(dv_rise) begin
                pre_cnt                  <= 3'd0;
                byte_idx                 <= 11'd0;
                udp_base_idx             <= 11'd34;
                dst_mac_shift            <= 48'd0;
                dst_ip_shift             <= 32'd0;
                magic_shift              <= 32'd0;
                eth_type                 <= 16'd0;
                udp_src_port             <= 16'd0;
                udp_dst_port             <= 16'd0;
                eth_accept               <= 1'b0;
                ipv4_accept              <= 1'b0;
                udp_accept               <= 1'b0;
                fpgv_accept              <= 1'b0;
                hdr_mode                 <= 8'd0;
                hdr_frame_id             <= 32'd0;
                hdr_width                <= 16'd0;
                hdr_height               <= 16'd0;
                hdr_packet_id            <= 16'd0;
                hdr_packet_total         <= 16'd0;
                hdr_payload_len          <= 16'd0;
                hdr_byte_offset          <= 32'd0;
                hdr_checksum16           <= 16'd0;
                hdr_complete_seen        <= 1'b0;
                payload_byte_count       <= 16'd0;
                segment_er_seen          <= gmii_rx_er;
                critical_er_seen         <= gmii_rx_er;
                tail_er_seen             <= 1'b0;
                segment_last_er_byte_idx <= 11'd0;
                if(gmii_rxd == 8'h55) begin
                    state   <= S_PREAM;
                    pre_cnt <= 3'd1;
                end else begin
                    state         <= S_FRAME;
                    dst_mac_shift <= {40'd0, gmii_rxd};
                    byte_idx      <= 11'd1;
                end
            end
        end

        S_PREAM: begin
            if(!gmii_rx_dv) begin
                state <= S_IDLE;
            end else if(gmii_rxd == 8'h55) begin
                if(pre_cnt != 3'd7) pre_cnt <= pre_cnt + 3'd1;
            end else if(gmii_rxd == 8'hD5) begin
                state    <= S_FRAME;
                byte_idx <= 11'd0;
            end else begin
                state         <= S_FRAME;
                dst_mac_shift <= {40'd0, gmii_rxd};
                byte_idx      <= 11'd1;
            end
        end

        S_FRAME: begin
            if(!gmii_rx_dv) begin
                state <= S_IDLE;

                if(hdr_complete_seen) begin
                    dbg_repeat_last_header_packet_id <= hdr_packet_id;
                    dbg_repeat_last_frame_id         <= hdr_frame_id;

                    if(segment_er_seen) begin
                        dbg_repeat_rx_er_packet_count   <= dbg_repeat_rx_er_packet_count + 32'd1;
                        dbg_repeat_last_rx_er_packet_id <= hdr_packet_id;
                    end
                    if(critical_er_seen)
                        dbg_repeat_critical_er_packet_count <= dbg_repeat_critical_er_packet_count + 32'd1;
                    if(tail_er_seen)
                        dbg_repeat_tail_er_packet_count <= dbg_repeat_tail_er_packet_count + 32'd1;

                    if(!strict_header_valid) begin
                        dbg_repeat_bad_header_count <= dbg_repeat_bad_header_count + 32'd1;
                    end else begin
                        last_header_packet_id_internal <= hdr_packet_id;

                        if(!round_started) begin
                            // A tagged supplemental replay never starts a new
                            // normal 0..749 accounting round.
                            if(!boundary_replay_tag) begin
                                round_started                         <= 1'b1;
                                round_valid_bitmap                    <= legal_payload ? hdr_packet_onehot : {768{1'b0}};
                                dbg_repeat_current_round_unique_count <= legal_payload ? 16'd1 : 16'd0;
                                pair_union_bitmap                     <= (prev_round_valid_bitmap | (legal_payload ? hdr_packet_onehot : {768{1'b0}}));
                                pair_union_count                      <= prev_round_unique_count + ((legal_payload && !prev_round_valid_bitmap[hdr_packet_id]) ? 16'd1 : 16'd0);
                                new_unique_this_round                 <= (legal_payload && !accum_valid_bitmap[hdr_packet_id]) ? 16'd1 : 16'd0;
                            end
                        end else if(wrap_boundary) begin
                            dbg_repeat_round_count              <= dbg_repeat_round_count + 32'd1;
                            dbg_repeat_last_round_good_count    <= dbg_repeat_current_round_unique_count;
                            dbg_repeat_last_round_missing_count <= BITMAP_PACKET_COUNT - dbg_repeat_current_round_unique_count;
                            dbg_repeat_new_unique_last_round    <= new_unique_this_round;
                            dbg_repeat_same_missing_prev_count  <= prev_round_valid ? (BITMAP_PACKET_COUNT - pair_union_count) : 16'd0;
                            prev_round_valid                    <= 1'b1;
                            prev_round_valid_bitmap             <= round_valid_bitmap;
                            prev_round_unique_count             <= dbg_repeat_current_round_unique_count;
                            round_valid_bitmap                  <= legal_payload ? hdr_packet_onehot : {768{1'b0}};
                            dbg_repeat_current_round_unique_count <= legal_payload ? 16'd1 : 16'd0;
                            pair_union_bitmap                   <= round_valid_bitmap | (legal_payload ? hdr_packet_onehot : {768{1'b0}});
                            pair_union_count                    <= dbg_repeat_current_round_unique_count + ((legal_payload && !round_valid_bitmap[hdr_packet_id]) ? 16'd1 : 16'd0);
                            new_unique_this_round               <= (legal_payload && !accum_valid_bitmap[hdr_packet_id]) ? 16'd1 : 16'd0;
                        end else if(legal_payload) begin
                            // Keep last_round_* statistics tied to the normal
                            // 0..749 pass. Supplemental tagged packets still
                            // contribute to cumulative coverage below.
                            if(!boundary_replay_tag) begin
                                if(!round_valid_bitmap[hdr_packet_id]) begin
                                    round_valid_bitmap[hdr_packet_id] <= 1'b1;
                                    dbg_repeat_current_round_unique_count <= dbg_repeat_current_round_unique_count + 16'd1;
                                end
                                if(!pair_union_bitmap[hdr_packet_id]) begin
                                    pair_union_bitmap[hdr_packet_id] <= 1'b1;
                                    pair_union_count <= pair_union_count + 16'd1;
                                end
                            end
                            if(!accum_valid_bitmap[hdr_packet_id])
                                new_unique_this_round <= new_unique_this_round + 16'd1;
                        end

                        if(legal_payload) begin
                            dbg_repeat_legal_payload_count  <= dbg_repeat_legal_payload_count + 32'd1;
                            dbg_repeat_last_legal_packet_id <= hdr_packet_id;
                            if(boundary_replay_tag) begin
                                dbg_repeat_boundary_replay_accept_count <= dbg_repeat_boundary_replay_accept_count + 32'd1;
                                if(hdr_packet_id == 16'd0)
                                    dbg_repeat_replay_accept_pid0_count <= dbg_repeat_replay_accept_pid0_count + 32'd1;
                                else if(hdr_packet_id == 16'd1)
                                    dbg_repeat_replay_accept_pid1_count <= dbg_repeat_replay_accept_pid1_count + 32'd1;
                                else if(hdr_packet_id == (EXPECT_PACKET_TOTAL - 16'd2))
                                    dbg_repeat_replay_accept_pid748_count <= dbg_repeat_replay_accept_pid748_count + 32'd1;
                                else if(hdr_packet_id == (EXPECT_PACKET_TOTAL - 16'd1))
                                    dbg_repeat_replay_accept_pid749_count <= dbg_repeat_replay_accept_pid749_count + 32'd1;
                            end
                            if(!accum_valid_bitmap[hdr_packet_id]) begin
                                accum_valid_bitmap[hdr_packet_id] <= 1'b1;
                                dbg_repeat_accum_unique_count <= dbg_repeat_accum_unique_count + 16'd1;
                                if(dbg_repeat_accum_unique_count == (BITMAP_PACKET_COUNT - 16'd1)) begin
                                    // dbg_repeat_round_count advances when the
                                    // next untagged round starts, so +1 reports
                                    // the number of normal full-pass attempts
                                    // required when cumulative coverage first
                                    // reaches 750/750.
                                    dbg_repeat_complete_round_count <= dbg_repeat_round_count + 32'd1;
                                    dbg_repeat_complete_pulse_count <= dbg_repeat_complete_pulse_count + 32'd1;
                                end
                            end else begin
                                dbg_repeat_duplicate_payload_count <= dbg_repeat_duplicate_payload_count + 32'd1;
                            end
                        end else if(!full_payload_seen || critical_er_seen) begin
                            dbg_repeat_incomplete_payload_count <= dbg_repeat_incomplete_payload_count + 32'd1;
                        end
                    end
                end
            end else begin
                if(byte_idx <= 11'd5)
                    dst_mac_shift <= {dst_mac_shift[39:0], gmii_rxd};
                if(byte_idx == 11'd5)
                    eth_accept <= (({dst_mac_shift[39:0], gmii_rxd} == LOCAL_MAC) ||
                                   ({dst_mac_shift[39:0], gmii_rxd} == 48'hFF_FF_FF_FF_FF_FF));
                if(byte_idx == 11'd12) eth_type[15:8] <= gmii_rxd;
                if(byte_idx == 11'd13) begin
                    eth_type[7:0] <= gmii_rxd;
                    if({eth_type[15:8], gmii_rxd} != 16'h0800) eth_accept <= 1'b0;
                end
                if(byte_idx == 11'd14) udp_base_idx <= 11'd14 + {5'd0, gmii_rxd[3:0], 2'b00};
                if(byte_idx == 11'd23) ipv4_accept <= eth_accept && (eth_type == 16'h0800) && (gmii_rxd == 8'd17);
                if((byte_idx >= 11'd30) && (byte_idx <= 11'd33)) dst_ip_shift <= {dst_ip_shift[23:0], gmii_rxd};
                if(byte_idx == 11'd33 && ({dst_ip_shift[23:0], gmii_rxd} != LOCAL_IP)) ipv4_accept <= 1'b0;
                if(byte_idx == udp_base_idx + 11'd0) udp_src_port[15:8] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd1) udp_src_port[7:0]  <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd2) udp_dst_port[15:8] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd3) begin
                    udp_dst_port[7:0] <= gmii_rxd;
                    udp_accept <= ipv4_accept && (udp_src_port == UDP_PORT) && ({udp_dst_port[15:8], gmii_rxd} == UDP_PORT);
                end
                if((byte_idx >= udp_base_idx + 11'd8) && (byte_idx <= udp_base_idx + 11'd11))
                    magic_shift <= {magic_shift[23:0], gmii_rxd};
                if(byte_idx == udp_base_idx + 11'd11)
                    fpgv_accept <= udp_accept && ({magic_shift[23:0], gmii_rxd} == 32'h46_50_47_56);
                if(byte_idx == udp_base_idx + 11'd13) hdr_mode <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd16) hdr_frame_id[31:24] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd17) hdr_frame_id[23:16] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd18) hdr_frame_id[15:8]  <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd19) hdr_frame_id[7:0]   <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd20) hdr_width[15:8] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd21) hdr_width[7:0]  <= gmii_rxd;
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
                if(byte_idx == udp_base_idx + 11'd36) hdr_checksum16[15:8] <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd37) hdr_checksum16[7:0]  <= gmii_rxd;
                if(byte_idx == udp_base_idx + 11'd39) hdr_complete_seen <= 1'b1;
                if((byte_idx >= udp_base_idx + 11'd40) &&
                   (byte_idx <  udp_base_idx + 11'd40 + hdr_payload_len) &&
                   (payload_byte_count != 16'hffff))
                    payload_byte_count <= payload_byte_count + 16'd1;
                if(byte_idx != 11'h7ff) byte_idx <= byte_idx + 11'd1;
            end
        end
        default: state <= S_IDLE;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        scan_div                   <= 22'd0;
        dbg_repeat_scan_word_index <= 5'd0;
    end else begin
        scan_div <= scan_div + 22'd1;
        if(scan_div == 22'd0) begin
            if(dbg_repeat_scan_word_index >= 5'd23)
                dbg_repeat_scan_word_index <= 5'd0;
            else
                dbg_repeat_scan_word_index <= dbg_repeat_scan_word_index + 5'd1;
        end
    end
end

// Count and priority-encode only the currently displayed, already-masked
// missing word. The work registers accumulate one 32-bit word at a time, so
// the added diagnostic logic stays small and the published IDs remain stable.
always @(*) begin
    scan_word_missing_count     = 6'd0;
    scan_word_missing_id0_valid = 1'b0;
    scan_word_missing_id0_bit   = 5'd0;
    scan_word_missing_id1_valid = 1'b0;
    scan_word_missing_id1_bit   = 5'd0;
    for(scan_bit_i = 0; scan_bit_i < 32; scan_bit_i = scan_bit_i + 1) begin
        if(dbg_repeat_scan_accum_missing_word[scan_bit_i]) begin
            scan_word_missing_count = scan_word_missing_count + 6'd1;
            if(!scan_word_missing_id0_valid) begin
                scan_word_missing_id0_valid = 1'b1;
                scan_word_missing_id0_bit   = scan_bit_i[4:0];
            end else if(!scan_word_missing_id1_valid) begin
                scan_word_missing_id1_valid = 1'b1;
                scan_word_missing_id1_bit   = scan_bit_i[4:0];
            end
        end
    end
end

// Refresh the latched summary after each complete 24-word scan. The summary
// exposes the first two real missing IDs and the total real missing count.
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        scan_missing_count_work      <= 16'd0;
        scan_missing_id0_valid_work  <= 1'b0;
        scan_missing_id0_work        <= 16'd0;
        scan_missing_id1_valid_work  <= 1'b0;
        scan_missing_id1_work        <= 16'd0;
        dbg_repeat_missing_ids_valid <= 1'b0;
        dbg_repeat_missing_id_count  <= 16'd0;
        dbg_repeat_missing_id0_valid <= 1'b0;
        dbg_repeat_missing_id0       <= 16'd0;
        dbg_repeat_missing_id1_valid <= 1'b0;
        dbg_repeat_missing_id1       <= 16'd0;
    end else if(scan_div == 22'd0) begin
        if(dbg_repeat_scan_word_index == 5'd0) begin
            scan_missing_count_work     <= {10'd0, scan_word_missing_count};
            scan_missing_id0_valid_work <= scan_word_missing_id0_valid;
            scan_missing_id0_work       <= scan_word_missing_id0;
            scan_missing_id1_valid_work <= scan_word_missing_id1_valid;
            scan_missing_id1_work       <= scan_word_missing_id1;
        end else begin
            scan_missing_count_work     <= scan_merged_missing_count;
            scan_missing_id0_valid_work <= scan_merged_missing_id0_valid;
            scan_missing_id0_work       <= scan_merged_missing_id0;
            scan_missing_id1_valid_work <= scan_merged_missing_id1_valid;
            scan_missing_id1_work       <= scan_merged_missing_id1;
            if(dbg_repeat_scan_word_index == 5'd23) begin
                dbg_repeat_missing_ids_valid <= 1'b1;
                dbg_repeat_missing_id_count  <= scan_merged_missing_count;
                dbg_repeat_missing_id0_valid <= scan_merged_missing_id0_valid;
                dbg_repeat_missing_id0       <= scan_merged_missing_id0;
                dbg_repeat_missing_id1_valid <= scan_merged_missing_id1_valid;
                dbg_repeat_missing_id1       <= scan_merged_missing_id1;
            end
        end
    end
end

always @(*) begin
    dbg_repeat_scan_round_valid_word   = 32'd0;
    dbg_repeat_scan_accum_valid_word   = 32'd0;
    dbg_repeat_scan_accum_missing_word = 32'd0;
    dbg_repeat_scan_valid_mask         = 32'd0;
    case(dbg_repeat_scan_word_index)
    5'd0: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[31:0]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[31:0]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[31:0]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd1: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[63:32]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[63:32]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[63:32]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd2: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[95:64]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[95:64]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[95:64]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd3: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[127:96]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[127:96]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[127:96]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd4: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[159:128]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[159:128]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[159:128]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd5: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[191:160]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[191:160]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[191:160]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd6: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[223:192]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[223:192]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[223:192]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd7: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[255:224]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[255:224]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[255:224]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd8: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[287:256]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[287:256]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[287:256]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd9: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[319:288]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[319:288]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[319:288]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd10: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[351:320]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[351:320]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[351:320]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd11: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[383:352]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[383:352]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[383:352]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd12: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[415:384]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[415:384]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[415:384]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd13: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[447:416]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[447:416]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[447:416]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd14: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[479:448]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[479:448]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[479:448]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd15: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[511:480]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[511:480]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[511:480]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd16: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[543:512]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[543:512]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[543:512]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd17: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[575:544]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[575:544]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[575:544]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd18: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[607:576]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[607:576]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[607:576]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd19: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[639:608]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[639:608]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[639:608]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd20: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[671:640]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[671:640]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[671:640]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd21: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[703:672]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[703:672]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[703:672]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd22: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[735:704]; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[735:704]; dbg_repeat_scan_accum_missing_word = ~accum_valid_bitmap[735:704]; dbg_repeat_scan_valid_mask = 32'hffff_ffff; end
    5'd23: begin dbg_repeat_scan_round_valid_word = round_valid_bitmap[767:736] & LAST_WORD_VALID_MASK; dbg_repeat_scan_accum_valid_word = accum_valid_bitmap[767:736] & LAST_WORD_VALID_MASK; dbg_repeat_scan_accum_missing_word = (~accum_valid_bitmap[767:736]) & LAST_WORD_VALID_MASK; dbg_repeat_scan_valid_mask = LAST_WORD_VALID_MASK; end
    default: begin dbg_repeat_scan_round_valid_word = 32'd0; dbg_repeat_scan_accum_valid_word = 32'd0; dbg_repeat_scan_accum_missing_word = 32'd0; dbg_repeat_scan_valid_mask = 32'd0; end
    endcase
end

endmodule
