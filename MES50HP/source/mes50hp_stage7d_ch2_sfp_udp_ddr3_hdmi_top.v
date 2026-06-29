`timescale 1ns / 1ps
`default_nettype wire
`define UD #1
// -----------------------------------------------------------------------------
// MES50HP Stage7D_CH2
// SFP0/lane2 -> QSGMII -> GMII -> UDP5000/FPGV -> line rebuild
// -> original fram_buf -> original DDR3_50H -> original HDMI/MS72xx output.
//
// Important anti-regression rules:
//   1. Keep top input clock named sys_clk, as in 10_HDMI_DDR3_OV5640_test.
//   2. Keep DDR3 instance directly at top level: DDR3_50H u_DDR3_50H.
//   3. Keep local HDMI PLL directly at top level: pll u_pll.
//   4. Keep original ms72xx_ctl port name: .rst_n(...).
//   5. Keep original DDR3 port name: .ddr_init_done(...).
// -----------------------------------------------------------------------------
module mes50hp_stage7d_ch2_sfp_udp_ddr3_hdmi_top #(
    parameter MEM_ROW_ADDR_WIDTH   = 15,
    parameter MEM_COL_ADDR_WIDTH   = 10,
    parameter MEM_BADDR_WIDTH      = 3,
    parameter MEM_DQ_WIDTH         = 32,
    parameter MEM_DQS_WIDTH        = 32/8,
    parameter ACTIVE_CHANNEL       = 2
)(
    input                                sys_clk,     // 50 MHz, same name as original HDMI project
    input                                rst_n,

    // 125 MHz HSST reference clock and MES50HP SFP lanes.
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

    // Eight user LEDs.
    output [7:0]                         led,

    // DDR3.
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

    // MS72xx / HDMI.
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

wire sys_rst_n;
cross_reset_sync u_sys_reset_sync (
    .free_clk_pll  (sys_clk),
    .external_rstn (rst_n),
    .rst_n         (sys_rst_n)
);

// -----------------------------------------------------------------------------
// HDMI PLL and MS72xx initialization: unchanged top-level instance style.
// -----------------------------------------------------------------------------
wire cfg_clk;
wire clk_25M_unused;
wire locked;
wire init_over_tx;
wire init_over_rx;
wire iic_scl;
wire iic_sda;
reg  [15:0] rstn_1ms;

// Stage7C: PLL clkout0 is changed to about 74.24 MHz for 1280x720@60Hz.
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

// -----------------------------------------------------------------------------
// MES50HP SFP0/lane2 receive chain from the verified Stage5B project.
// -----------------------------------------------------------------------------
wire [7:0] sfp_debug_led;
wire p0_clk, p1_clk, p2_clk, p3_clk;
wire p0_rstn, p1_rstn, p2_rstn, p3_rstn;
wire [7:0] p0_rxd, p1_rxd, p2_rxd, p3_rxd;
wire p0_dv, p1_dv, p2_dv, p3_dv;
wire p0_er, p1_er, p2_er, p3_er;
wire [3:0] sfp_rx_activity_live;
wire [3:0] sfp_rx_frame_seen;
wire [3:0] sfp_udp5000_seen;
wire [3:0] sfp_fpgv_seen;
wire [3:0] sfp_rx_error_seen;
wire hsst_pll_lock;
wire sfp0_lane_done;
wire sfp0_pcs_synced;

mes50hp_sfp_rx_gmii_4ch u_sfp_rx (
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
    .out_sfp0_lane_done   (sfp0_lane_done),
    .out_sfp0_pcs_synced  (sfp0_pcs_synced)
);

// Select one recovered QSGMII channel as the actual video stream source.
// Default ACTIVE_CHANNEL=0. If MES50H sends on another lane, change the parameter.
wire gmii_clk;
wire gmii_rstn;
wire [7:0] gmii_rxd;
wire gmii_dv;
wire gmii_er;

generate
if(ACTIVE_CHANNEL == 0) begin : g_ch0
    assign gmii_clk  = p0_clk;  assign gmii_rstn = p0_rstn;
    assign gmii_rxd  = p0_rxd;  assign gmii_dv   = p0_dv; assign gmii_er = p0_er;
end else if(ACTIVE_CHANNEL == 1) begin : g_ch1
    assign gmii_clk  = p1_clk;  assign gmii_rstn = p1_rstn;
    assign gmii_rxd  = p1_rxd;  assign gmii_dv   = p1_dv; assign gmii_er = p1_er;
end else if(ACTIVE_CHANNEL == 2) begin : g_ch2
    assign gmii_clk  = p2_clk;  assign gmii_rstn = p2_rstn;
    assign gmii_rxd  = p2_rxd;  assign gmii_dv   = p2_dv; assign gmii_er = p2_er;
end else begin : g_ch3
    assign gmii_clk  = p3_clk;  assign gmii_rstn = p3_rstn;
    assign gmii_rxd  = p3_rxd;  assign gmii_dv   = p3_dv; assign gmii_er = p3_er;
end
endgenerate

// -----------------------------------------------------------------------------
// UDP/FPGV to line-burst video input for original fram_buf.
// -----------------------------------------------------------------------------
wire        udp_vsync;
wire        udp_de;
wire [15:0] udp_rgb565;
wire        udp_packet_pulse;
wire        fpgv_packet_pulse;
wire        udp_frame_written_pulse;
wire        udp_overflow_pulse;
wire [31:0] udp_packet_count;
wire [31:0] fpgv_packet_count;
wire [31:0] udp_frame_written_count;
wire [31:0] udp_overflow_count;
wire [31:0] udp_last_frame_id;
wire [15:0] udp_last_packet_id;
wire [15:0] udp_last_width;
wire [15:0] udp_last_height;
wire [7:0]  udp_debug_state;

fpgv_gmii_line_to_vin #(
    .LOCAL_MAC(48'h02_00_00_00_50_01),
    .LOCAL_IP (32'hC0A8_0164),
    .UDP_PORT (16'd5000),
    .SRC_W    (12'd800),
    .SRC_H    (12'd480),
    .OUT_W    (12'd1280),
    .OUT_H    (12'd720)
) u_fpgv_line_to_vin (
    .clk                 (gmii_clk),
    .rst_n               (gmii_rstn & sys_rst_n),
    .gmii_rxd            (gmii_rxd),
    .gmii_rx_dv          (gmii_dv),
    .gmii_rx_er          (gmii_er),
    .vin_vsync           (udp_vsync),
    .vin_de              (udp_de),
    .vin_data            (udp_rgb565),
    .udp_packet_pulse    (udp_packet_pulse),
    .fpgv_packet_pulse   (fpgv_packet_pulse),
    .frame_written_pulse (udp_frame_written_pulse),
    .overflow_pulse      (udp_overflow_pulse),
    .udp_packet_count    (udp_packet_count),
    .fpgv_packet_count   (fpgv_packet_count),
    .frame_written_count (udp_frame_written_count),
    .overflow_count      (udp_overflow_count),
    .last_frame_id       (udp_last_frame_id),
    .last_packet_id      (udp_last_packet_id),
    .last_width          (udp_last_width),
    .last_height         (udp_last_height),
    .debug_state         (udp_debug_state)
);

// -----------------------------------------------------------------------------
// Stage7F12 stable DDR read-bank selection.
// Original rd_buf toggled DDR read bank at every HDMI vsync. With UDP input,
// write frames and HDMI frames are asynchronous, so HDMI can alternate between
// stale and half-written banks. Publish only the bank of a fully emitted VIN frame.
// -----------------------------------------------------------------------------
reg udp_vsync_d_gmii;
reg udp_write_bank_gmii;
reg udp_done_bank_gmii;
reg udp_done_bank_toggle_gmii;

always @(posedge gmii_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        udp_vsync_d_gmii          <= 1'b0;
        udp_write_bank_gmii       <= 1'b0;
        udp_done_bank_gmii        <= 1'b0;
        udp_done_bank_toggle_gmii <= 1'b0;
    end else begin
        udp_vsync_d_gmii <= udp_vsync;

        if(udp_vsync && !udp_vsync_d_gmii)
            udp_write_bank_gmii <= ~udp_write_bank_gmii;

        if(udp_frame_written_pulse) begin
            udp_done_bank_gmii        <= udp_write_bank_gmii;
            udp_done_bank_toggle_gmii <= ~udp_done_bank_toggle_gmii;
        end
    end
end

// -----------------------------------------------------------------------------
// Original DDR3 frame buffer path.
// -----------------------------------------------------------------------------
wire [15:0] o_rgb565;
wire        fb_de_o;
wire        init_done;
wire        vs_o;
wire        hs_o;
wire        vg_de_o;
wire        de_re;
wire [11:0] vg_x;
wire [11:0] vg_y;

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

fram_buf fram_buf (
    .ddr_clk        (core_clk),
    .ddr_rstn       (ddr_init_done),

    .vin_clk        (gmii_clk),
    .wr_fsync       (udp_vsync),
    .wr_en          (udp_de),
    .wr_data        (udp_rgb565),

    .rd_frame_sel        (udp_done_bank_gmii),
    .rd_frame_sel_toggle (udp_done_bank_toggle_gmii),

    .vout_clk       (pix_clk),
    .rd_fsync       (vs_o),
    .rd_en          (de_re),
    .vout_de        (fb_de_o),
    .vout_data      (o_rgb565),
    .init_done      (init_done),

    .axi_awaddr     (axi_awaddr),
    .axi_awid       (axi_awuser_id),
    .axi_awlen      (axi_awlen),
    .axi_awsize     (),
    .axi_awburst    (),
    .axi_awready    (axi_awready),
    .axi_awvalid    (axi_awvalid),
    .axi_wdata      (axi_wdata),
    .axi_wstrb      (axi_wstrb),
    .axi_wlast      (axi_wusero_last),
    .axi_wvalid     (),
    .axi_wready     (axi_wready),
    .axi_bid        (4'd0),
    .axi_araddr     (axi_araddr),
    .axi_arid       (axi_aruser_id),
    .axi_arlen      (axi_arlen),
    .axi_arsize     (),
    .axi_arburst    (),
    .axi_arvalid    (axi_arvalid),
    .axi_arready    (axi_arready),
    .axi_rready     (),
    .axi_rdata      (axi_rdata),
    .axi_rvalid     (axi_rvalid),
    .axi_rlast      (axi_rlast),
    .axi_rid        (axi_rid)
);

// HDMI timing is released after PLL/MS72xx/DDR are ready, not after first UDP frame.
// This guarantees that the HDMI port is detected even before image packets arrive.
sync_vg sync_vg (
    .clk    (pix_clk),
    .rstn   (rstn_out & init_over_tx & ddr_init_done),
    .vs_out (vs_o),
    .hs_out (hs_o),
    .de_out (vg_de_o),
    .de_re  (de_re),
    .x_act  (vg_x),
    .y_act  (vg_y)
);

wire [15:0] test_rgb565 =
    (vg_x < 12'd183)  ? 16'hF800 :
    (vg_x < 12'd366)  ? 16'hFFE0 :
    (vg_x < 12'd549)  ? 16'h07E0 :
    (vg_x < 12'd732)  ? 16'h07FF :
    (vg_x < 12'd915)  ? 16'h001F :
    (vg_x < 12'd1098) ? 16'hF81F :
                        16'hFFFF;

// Stage7F12: keep the image path permissive, but do not mix test color bars
// back into the camera picture after fram_buf has initialized.
// If rd_buf says data is invalid after init_done, output black, not color bars.
reg [2:0] init_done_pix_sync;
always @(posedge pix_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)
        init_done_pix_sync <= 3'b000;
    else
        init_done_pix_sync <= {init_done_pix_sync[1:0], init_done};
end

wire video_show_pix = init_done_pix_sync[2];
wire [15:0] hdmi_rgb565 = video_show_pix ? (fb_de_o ? o_rgb565 : 16'h0000) : test_rgb565;

always @(posedge pix_clk) begin
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

DDR3_50H u_DDR3_50H (
    .ref_clk                   (sys_clk),
    .resetn                    (rstn_out),
    .ddr_init_done             (ddr_init_done),
    .ddrphy_clkin              (core_clk),
    .pll_lock                  (pll_lock),

    .axi_awaddr                (axi_awaddr),
    .axi_awuser_ap             (1'b0),
    .axi_awuser_id             (axi_awuser_id),
    .axi_awlen                 (axi_awlen),
    .axi_awready               (axi_awready),
    .axi_awvalid               (axi_awvalid),
    .axi_wdata                 (axi_wdata),
    .axi_wstrb                 (axi_wstrb),
    .axi_wready                (axi_wready),
    .axi_wusero_id             (),
    .axi_wusero_last           (axi_wusero_last),
    .axi_araddr                (axi_araddr),
    .axi_aruser_ap             (1'b0),
    .axi_aruser_id             (axi_aruser_id),
    .axi_arlen                 (axi_arlen),
    .axi_arready               (axi_arready),
    .axi_arvalid               (axi_arvalid),
    .axi_rdata                 (axi_rdata),
    .axi_rid                   (axi_rid),
    .axi_rlast                 (axi_rlast),
    .axi_rvalid                (axi_rvalid),

    .apb_clk                   (1'b0),
    .apb_rst_n                 (1'b1),
    .apb_sel                   (1'b0),
    .apb_enable                (1'b0),
    .apb_addr                  (8'b0),
    .apb_write                 (1'b0),
    .apb_ready                 (),
    .apb_wdata                 (16'b0),
    .apb_rdata                 (),
    .apb_int                   (),

    .mem_rst_n                 (mem_rst_n),
    .mem_ck                    (mem_ck),
    .mem_ck_n                  (mem_ck_n),
    .mem_cke                   (mem_cke),
    .mem_cs_n                  (mem_cs_n),
    .mem_ras_n                 (mem_ras_n),
    .mem_cas_n                 (mem_cas_n),
    .mem_we_n                  (mem_we_n),
    .mem_odt                   (mem_odt),
    .mem_a                     (mem_a),
    .mem_ba                    (mem_ba),
    .mem_dqs                   (mem_dqs),
    .mem_dqs_n                 (mem_dqs_n),
    .mem_dq                    (mem_dq),
    .mem_dm                    (mem_dm),

    .debug_data                (),
    .debug_slice_state         (),
    .debug_calib_ctrl          (),
    .ck_dly_set_bin            (),
    .force_ck_dly_en           (1'b0),
    .force_ck_dly_set_bin      (8'h05),
    .dll_step                  (),
    .dll_lock                  (),
    .init_read_clk_ctrl        (2'b0),
    .init_slip_step            (4'b0),
    .force_read_clk_ctrl       (1'b0),
    .ddrphy_gate_update_en     (1'b0),
    .update_com_val_err_flag   (),
    .rd_fake_stop              (1'b0)
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


// Stage7F12_CH2 STABLE_READBANK LED mapping.
// This build routes QSGMII ch2 into fpgv_gmii_line_to_vin.
// LED5/LED6 are now active CH2 only, not OR of all four channels.
// LED7/LED8 tell whether the active-channel image really reached DDR fram_buf.
assign led[0] = heart_beat_led;                 // LED1 heartbeat
assign led[1] = init_over_tx;                   // LED2 HDMI TX init
assign led[2] = sfp0_pcs_synced;                // LED3 SFP0 PCS synced
assign led[3] = ddr_init_done;                  // LED4 DDR initialized
assign led[4] = sfp_udp5000_seen[2];           // LED5 UDP5000 seen on active CH2
assign led[5] = sfp_fpgv_seen[2];              // LED6 FPGV seen on active CH2
assign led[6] = |udp_frame_written_count;       // LED7 active ch2 rebuilt/output a frame
assign led[7] = video_show_pix;                 // LED8 HDMI switched to DDR/black-valid image path

endmodule
