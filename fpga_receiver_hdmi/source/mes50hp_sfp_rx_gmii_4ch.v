`timescale 1ns / 1ps
`default_nettype wire
// -----------------------------------------------------------------------------
// MES50HP port-matrix RX: selected SFP0/lane2 or SFP1/lane3 -> QSGMII -> four GMII RX
//
// Basis:
//   - HSST/SFP pin and lane2/lane3 hardware style from official 08_hsst_test.
//   - qsgmii_test IP copied from the frozen MES50H Stage5A successful bridge.
//   - fpgv_gmii_rx_monitor copied from the frozen MES50H Stage5A successful bridge.
//
// Scope of this stage:
//   - Receive-only verification on MES50HP.
//   - No DDR3 write and no HDMI display are included here.
// -----------------------------------------------------------------------------

module mes50hp_sfp_rx_gmii_4ch #(
    // 0 = MES50HP SFP0 / HSST lane2, 1 = MES50HP SFP1 / HSST lane3.
    parameter USE_SFP1_RX = 1'b0
) (
    input          i_free_clk,
    input          rst_n,

    // 125 MHz HSST reference clock, see MES50HP hardware manual.
    input          i_p_refckn_0,
    input          i_p_refckp_0,

    // MES50HP SFP0 is HSST lane2.
    input          i_p_l2rxn,
    input          i_p_l2rxp,
    output         o_p_l2txn,
    output         o_p_l2txp,

    // MES50HP SFP1 is HSST lane3. Kept at top level for compatibility,
    // but Stage5B uses SFP0/lane2 first.
    input          i_p_l3rxn,
    input          i_p_l3rxp,
    output         o_p_l3txn,
    output         o_p_l3txp,

    // SFP module status/control.
    input          sfp0_los,
    input          sfp1_los,
    output [1:0]   tx_disable,

    // Eight debug LEDs from the original Stage5B logic.
    output [7:0]   led,

    // Recovered GMII clocks/data exported to Stage7A image receiver.
    output         out_p0_sgmii_clk,
    output         out_p1_sgmii_clk,
    output         out_p2_sgmii_clk,
    output         out_p3_sgmii_clk,
    output         out_p0_rx_rstn,
    output         out_p1_rx_rstn,
    output         out_p2_rx_rstn,
    output         out_p3_rx_rstn,
    output [7:0]   out_p0_gmii_rxd,
    output [7:0]   out_p1_gmii_rxd,
    output [7:0]   out_p2_gmii_rxd,
    output [7:0]   out_p3_gmii_rxd,
    output         out_p0_gmii_rx_dv,
    output         out_p1_gmii_rx_dv,
    output         out_p2_gmii_rx_dv,
    output         out_p3_gmii_rx_dv,
    output         out_p0_gmii_rx_er,
    output         out_p1_gmii_rx_er,
    output         out_p2_gmii_rx_er,
    output         out_p3_gmii_rx_er,

    // Sticky/debug status from the original Stage5B monitor.
    output [3:0]   out_rx_activity_live,
    output [3:0]   out_rx_frame_seen,
    output [3:0]   out_udp5000_seen,
    output [3:0]   out_fpgv_seen,
    output [3:0]   out_rx_error_seen,
    output         out_hsst_pll_lock,
    output         out_sfp0_lane_done,
    output         out_sfp0_pcs_synced,

    // LINK_ATTRIB_DIAG_LITE: counters reused from existing CH2 monitor.
    output [31:0]  out_diag_ch2_frame_count,
    output [31:0]  out_diag_ch2_udp5000_count,
    output [31:0]  out_diag_ch2_fpgv_count,
    output [31:0]  out_diag_ch2_er_cycle_count
);

wire sys_rst_n;

cross_reset_sync u_sys_reset_sync (
    .free_clk_pll  (i_free_clk),
    .external_rstn (rst_n),
    .rst_n         (sys_rst_n)
);

assign tx_disable = 2'b00;   // SFP TX disable is active high. 0 enables SFP0/SFP1 TX.

// -----------------------------------------------------------------------------
// HSST lane2/lane3 wires.
// -----------------------------------------------------------------------------
wire [1:0]  o_wtchdg_st_0;
wire        o_pll_done_0;
wire        o_txlane_done_2 /* synthesis PAP_MARK_DEBUG="true" */;
wire        o_txlane_done_3 /* synthesis PAP_MARK_DEBUG="true" */;
wire        o_rxlane_done_2 /* synthesis PAP_MARK_DEBUG="true" */;
wire        o_rxlane_done_3 /* synthesis PAP_MARK_DEBUG="true" */;
wire        o_p_clk2core_tx_2 /* synthesis PAP_MARK_DEBUG="true" */;
wire        o_p_pll_lock_0 /* synthesis PAP_MARK_DEBUG="true" */;
wire        o_p_rx_sigdet_sta_2 /* synthesis PAP_MARK_DEBUG="true" */;
wire        o_p_rx_sigdet_sta_3 /* synthesis PAP_MARK_DEBUG="true" */;
wire        o_p_lx_cdr_align_2 /* synthesis PAP_MARK_DEBUG="true" */;
wire        o_p_lx_cdr_align_3 /* synthesis PAP_MARK_DEBUG="true" */;
wire        o_p_pcs_lsm_synced_2 /* synthesis PAP_MARK_DEBUG="true" */;
wire        o_p_pcs_lsm_synced_3 /* synthesis PAP_MARK_DEBUG="true" */;

wire [31:0] i_txd_2;
wire [3:0]  i_tdispsel_2;
wire [3:0]  i_tdispctrl_2;
wire [3:0]  i_txk_2;
wire [2:0]  o_rxstatus_2;
wire [31:0] o_rxd_2;
wire [3:0]  o_rdisper_2;
wire [3:0]  o_rdecer_2;
wire [3:0]  o_rxk_2;

wire [2:0]  o_rxstatus_3;
wire [31:0] o_rxd_3;
wire [3:0]  o_rdisper_3;
wire [3:0]  o_rdecer_3;
wire [3:0]  o_rxk_3;

hsst_test u_hsst_test (
    .i_free_clk                   (i_free_clk                  ),
    .i_p_refckn_0                 (i_p_refckn_0                ),
    .i_p_refckp_0                 (i_p_refckp_0                ),
    .i_wtchdg_clr_0               (~sys_rst_n                  ),
    .o_wtchdg_st_0                (o_wtchdg_st_0               ),
    .o_pll_done_0                 (o_pll_done_0                ),
    .o_txlane_done_2              (o_txlane_done_2             ),
    .o_txlane_done_3              (o_txlane_done_3             ),
    .o_rxlane_done_2              (o_rxlane_done_2             ),
    .o_rxlane_done_3              (o_rxlane_done_3             ),
    .o_p_clk2core_tx_2            (o_p_clk2core_tx_2           ),
    .i_p_tx2_clk_fr_core          (o_p_clk2core_tx_2           ),
    .i_p_tx3_clk_fr_core          (o_p_clk2core_tx_2           ),
    .i_p_rx2_clk_fr_core          (o_p_clk2core_tx_2           ),
    .i_p_rx3_clk_fr_core          (o_p_clk2core_tx_2           ),
    .o_p_pll_lock_0               (o_p_pll_lock_0              ),
    .o_p_rx_sigdet_sta_2          (o_p_rx_sigdet_sta_2         ),
    .o_p_rx_sigdet_sta_3          (o_p_rx_sigdet_sta_3         ),
    .o_p_lx_cdr_align_2           (o_p_lx_cdr_align_2          ),
    .o_p_lx_cdr_align_3           (o_p_lx_cdr_align_3          ),
    .o_p_pcs_lsm_synced_2         (o_p_pcs_lsm_synced_2        ),
    .o_p_pcs_lsm_synced_3         (o_p_pcs_lsm_synced_3        ),
    .i_p_l2rxn                    (i_p_l2rxn                   ),
    .i_p_l2rxp                    (i_p_l2rxp                   ),
    .i_p_l3rxn                    (i_p_l3rxn                   ),
    .i_p_l3rxp                    (i_p_l3rxp                   ),
    .o_p_l2txn                    (o_p_l2txn                   ),
    .o_p_l2txp                    (o_p_l2txp                   ),
    .o_p_l3txn                    (o_p_l3txn                   ),
    .o_p_l3txp                    (o_p_l3txp                   ),
    .i_txd_2                      (USE_SFP1_RX ? 32'h0 : i_txd_2),
    .i_tdispsel_2                 (USE_SFP1_RX ? 4'h0 : i_tdispsel_2),
    .i_tdispctrl_2                (USE_SFP1_RX ? 4'h0 : i_tdispctrl_2),
    .i_txk_2                      (USE_SFP1_RX ? 4'h0 : i_txk_2),
    .i_txd_3                      (USE_SFP1_RX ? i_txd_2 : 32'h0),
    .i_tdispsel_3                 (USE_SFP1_RX ? i_tdispsel_2 : 4'h0),
    .i_tdispctrl_3                (USE_SFP1_RX ? i_tdispctrl_2 : 4'h0),
    .i_txk_3                      (USE_SFP1_RX ? i_txk_2 : 4'h0),
    .o_rxstatus_2                 (o_rxstatus_2                ),
    .o_rxd_2                      (o_rxd_2                     ),
    .o_rdisper_2                  (o_rdisper_2                 ),
    .o_rdecer_2                   (o_rdecer_2                  ),
    .o_rxk_2                      (o_rxk_2                     ),
    .o_rxstatus_3                 (o_rxstatus_3                ),
    .o_rxd_3                      (o_rxd_3                     ),
    .o_rdisper_3                  (o_rdisper_3                 ),
    .o_rdecer_3                   (o_rdecer_3                  ),
    .o_rxk_3                      (o_rxk_3                     ),
    .i_pll_rst_0                  (~sys_rst_n                  )
);

// -----------------------------------------------------------------------------
// QSGMII lane selected at compile time: SFP0/lane2 or SFP1/lane3.
// -----------------------------------------------------------------------------
wire        qsgmii_tx_rstn_sfp0;
wire        qsgmii_rx_rstn_sfp0;

wire [15:0] p0_status_vector_sfp0;
wire [15:0] p1_status_vector_sfp0;
wire [15:0] p2_status_vector_sfp0;
wire [15:0] p3_status_vector_sfp0;

wire        p0_sgmii_clk_sfp0 /* synthesis PAP_MARK_DEBUG="true" */;
wire        p1_sgmii_clk_sfp0 /* synthesis PAP_MARK_DEBUG="true" */;
wire        p2_sgmii_clk_sfp0 /* synthesis PAP_MARK_DEBUG="true" */;
wire        p3_sgmii_clk_sfp0 /* synthesis PAP_MARK_DEBUG="true" */;

wire        p0_tx_clken_sfp0;
wire        p1_tx_clken_sfp0;
wire        p2_tx_clken_sfp0;
wire        p3_tx_clken_sfp0;

wire        p0_tx_rstn_sync_sfp0;
wire        p1_tx_rstn_sync_sfp0;
wire        p2_tx_rstn_sync_sfp0;
wire        p3_tx_rstn_sync_sfp0;
wire        p0_rx_rstn_sync_sfp0;
wire        p1_rx_rstn_sync_sfp0;
wire        p2_rx_rstn_sync_sfp0;
wire        p3_rx_rstn_sync_sfp0;

wire [7:0]  p0_gmii_rxd_sfp0 /* synthesis PAP_MARK_DEBUG="true" */;
wire [7:0]  p1_gmii_rxd_sfp0 /* synthesis PAP_MARK_DEBUG="true" */;
wire [7:0]  p2_gmii_rxd_sfp0 /* synthesis PAP_MARK_DEBUG="true" */;
wire [7:0]  p3_gmii_rxd_sfp0 /* synthesis PAP_MARK_DEBUG="true" */;
wire        p0_gmii_rx_dv_sfp0 /* synthesis PAP_MARK_DEBUG="true" */;
wire        p1_gmii_rx_dv_sfp0 /* synthesis PAP_MARK_DEBUG="true" */;
wire        p2_gmii_rx_dv_sfp0 /* synthesis PAP_MARK_DEBUG="true" */;
wire        p3_gmii_rx_dv_sfp0 /* synthesis PAP_MARK_DEBUG="true" */;
wire        p0_gmii_rx_er_sfp0 /* synthesis PAP_MARK_DEBUG="true" */;
wire        p1_gmii_rx_er_sfp0 /* synthesis PAP_MARK_DEBUG="true" */;
wire        p2_gmii_rx_er_sfp0 /* synthesis PAP_MARK_DEBUG="true" */;
wire        p3_gmii_rx_er_sfp0 /* synthesis PAP_MARK_DEBUG="true" */;
wire        p0_receiving_sfp0;
wire        p1_receiving_sfp0;
wire        p2_receiving_sfp0;
wire        p3_receiving_sfp0;
wire        p0_transmitting_sfp0;
wire        p1_transmitting_sfp0;
wire        p2_transmitting_sfp0;
wire        p3_transmitting_sfp0;

qsgmii_test u_qsgmii_sfp0_lane2 (
    .p0_status_vector             (p0_status_vector_sfp0       ),
    .p0_pin_cfg_en                (1'b1                        ),
    .p0_phy_link                  (1'b1                        ),
    .p0_phy_duplex                (1'b1                        ),
    .p0_phy_speed                 (2'b10                       ),
    .p0_unidir_en                 (1'b0                        ),
    .p0_an_restart                (1'b0                        ),
    .p0_an_enable                 (1'b0                        ),
    .p0_loopback                  (1'b0                        ),
    .p0_sgmii_clk                 (p0_sgmii_clk_sfp0           ),
    .p0_tx_clken                  (p0_tx_clken_sfp0            ),
    .p0_tx_rstn_sync              (p0_tx_rstn_sync_sfp0        ),
    .p0_rx_rstn_sync              (p0_rx_rstn_sync_sfp0        ),
    .p0_gmii_rxd                  (p0_gmii_rxd_sfp0            ),
    .p0_gmii_rx_dv                (p0_gmii_rx_dv_sfp0          ),
    .p0_gmii_rx_er                (p0_gmii_rx_er_sfp0          ),
    .p0_receiving                 (p0_receiving_sfp0           ),
    .p0_gmii_txd                  (8'h00                       ),
    .p0_gmii_tx_en                (1'b0                        ),
    .p0_gmii_tx_er                (1'b0                        ),
    .p0_transmitting              (p0_transmitting_sfp0        ),
    .p1_status_vector             (p1_status_vector_sfp0       ),
    .p1_pin_cfg_en                (1'b1                        ),
    .p1_phy_link                  (1'b1                        ),
    .p1_phy_duplex                (1'b1                        ),
    .p1_phy_speed                 (2'b10                       ),
    .p1_unidir_en                 (1'b0                        ),
    .p1_an_restart                (1'b0                        ),
    .p1_an_enable                 (1'b0                        ),
    .p1_loopback                  (1'b0                        ),
    .p1_sgmii_clk                 (p1_sgmii_clk_sfp0           ),
    .p1_tx_clken                  (p1_tx_clken_sfp0            ),
    .p1_tx_rstn_sync              (p1_tx_rstn_sync_sfp0        ),
    .p1_rx_rstn_sync              (p1_rx_rstn_sync_sfp0        ),
    .p1_gmii_rxd                  (p1_gmii_rxd_sfp0            ),
    .p1_gmii_rx_dv                (p1_gmii_rx_dv_sfp0          ),
    .p1_gmii_rx_er                (p1_gmii_rx_er_sfp0          ),
    .p1_receiving                 (p1_receiving_sfp0           ),
    .p1_gmii_txd                  (8'h00                       ),
    .p1_gmii_tx_en                (1'b0                        ),
    .p1_gmii_tx_er                (1'b0                        ),
    .p1_transmitting              (p1_transmitting_sfp0        ),
    .p2_status_vector             (p2_status_vector_sfp0       ),
    .p2_pin_cfg_en                (1'b1                        ),
    .p2_phy_link                  (1'b1                        ),
    .p2_phy_duplex                (1'b1                        ),
    .p2_phy_speed                 (2'b10                       ),
    .p2_unidir_en                 (1'b0                        ),
    .p2_an_restart                (1'b0                        ),
    .p2_an_enable                 (1'b0                        ),
    .p2_loopback                  (1'b0                        ),
    .p2_sgmii_clk                 (p2_sgmii_clk_sfp0           ),
    .p2_tx_clken                  (p2_tx_clken_sfp0            ),
    .p2_tx_rstn_sync              (p2_tx_rstn_sync_sfp0        ),
    .p2_rx_rstn_sync              (p2_rx_rstn_sync_sfp0        ),
    .p2_gmii_rxd                  (p2_gmii_rxd_sfp0            ),
    .p2_gmii_rx_dv                (p2_gmii_rx_dv_sfp0          ),
    .p2_gmii_rx_er                (p2_gmii_rx_er_sfp0          ),
    .p2_receiving                 (p2_receiving_sfp0           ),
    .p2_gmii_txd                  (8'h00                       ),
    .p2_gmii_tx_en                (1'b0                        ),
    .p2_gmii_tx_er                (1'b0                        ),
    .p2_transmitting              (p2_transmitting_sfp0        ),
    .p3_status_vector             (p3_status_vector_sfp0       ),
    .p3_pin_cfg_en                (1'b1                        ),
    .p3_phy_link                  (1'b1                        ),
    .p3_phy_duplex                (1'b1                        ),
    .p3_phy_speed                 (2'b10                       ),
    .p3_unidir_en                 (1'b0                        ),
    .p3_an_restart                (1'b0                        ),
    .p3_an_enable                 (1'b0                        ),
    .p3_loopback                  (1'b0                        ),
    .p3_sgmii_clk                 (p3_sgmii_clk_sfp0           ),
    .p3_tx_clken                  (p3_tx_clken_sfp0            ),
    .p3_tx_rstn_sync              (p3_tx_rstn_sync_sfp0        ),
    .p3_rx_rstn_sync              (p3_rx_rstn_sync_sfp0        ),
    .p3_gmii_rxd                  (p3_gmii_rxd_sfp0            ),
    .p3_gmii_rx_dv                (p3_gmii_rx_dv_sfp0          ),
    .p3_gmii_rx_er                (p3_gmii_rx_er_sfp0          ),
    .p3_receiving                 (p3_receiving_sfp0           ),
    .p3_gmii_txd                  (8'h00                       ),
    .p3_gmii_tx_en                (1'b0                        ),
    .p3_gmii_tx_er                (1'b0                        ),
    .p3_transmitting              (p3_transmitting_sfp0        ),
    .txpll_sof_rst_n              (sys_rst_n                   ),
    .hsst_cfg_soft_rstn           (sys_rst_n                   ),
    .external_rstn                (sys_rst_n                   ),
    .p0_soft_rstn                 (sys_rst_n                   ),
    .p1_soft_rstn                 (sys_rst_n                   ),
    .p2_soft_rstn                 (sys_rst_n                   ),
    .p3_soft_rstn                 (sys_rst_n                   ),
    .free_clk                     (i_free_clk                  ),
    .qsgmii_tx_rstn               (qsgmii_tx_rstn_sfp0         ),
    .qsgmii_rx_rstn               (qsgmii_rx_rstn_sfp0         ),
    .p0_AN_CS                     (                            ),
    .p0_AN_NS                     (                            ),
    .p0_RS_CS                     (                            ),
    .p0_RS_NS                     (                            ),
    .p0_TS_CS                     (                            ),
    .p0_TS_NS                     (                            ),
    .p0_xmit                      (                            ),
    .p0_rx_unitdata_indicate      (                            ),
    .p1_AN_CS                     (                            ),
    .p1_AN_NS                     (                            ),
    .p1_RS_CS                     (                            ),
    .p1_RS_NS                     (                            ),
    .p1_TS_CS                     (                            ),
    .p1_TS_NS                     (                            ),
    .p1_xmit                      (                            ),
    .p1_rx_unitdata_indicate      (                            ),
    .p2_AN_CS                     (                            ),
    .p2_AN_NS                     (                            ),
    .p2_RS_CS                     (                            ),
    .p2_RS_NS                     (                            ),
    .p2_TS_CS                     (                            ),
    .p2_TS_NS                     (                            ),
    .p2_xmit                      (                            ),
    .p2_rx_unitdata_indicate      (                            ),
    .p3_AN_CS                     (                            ),
    .p3_AN_NS                     (                            ),
    .p3_RS_CS                     (                            ),
    .p3_RS_NS                     (                            ),
    .p3_TS_CS                     (                            ),
    .p3_TS_NS                     (                            ),
    .p3_xmit                      (                            ),
    .p3_rx_unitdata_indicate      (                            ),
    .l0_pcs_rdispdec_er           (                            ),
    .i_loop_dbg_0                 (                            ),
    .o_txlane_done_0              (USE_SFP1_RX ? o_txlane_done_3 : o_txlane_done_2),
    .o_rxlane_done_0              (USE_SFP1_RX ? o_rxlane_done_3 : o_rxlane_done_2),
    .o_p_clk2core_tx_0            (o_p_clk2core_tx_2           ),
    .o_p_clk2core_rx_0            (o_p_clk2core_tx_2           ),
    .l0_lsm_synced                (USE_SFP1_RX ? o_p_pcs_lsm_synced_3 : o_p_pcs_lsm_synced_2),
    .i_p_cfg_psel                 (                            ),
    .i_p_cfg_enable               (                            ),
    .i_p_cfg_write                (                            ),
    .i_p_cfg_addr                 (                            ),
    .i_p_cfg_wdata                (                            ),
    .o_p_cfg_rdata                (8'h00                       ),
    .o_p_cfg_ready                (1'b0                        ),
    .i_txd_0                      (i_txd_2                     ),
    .i_tdispsel_0                 (i_tdispsel_2                ),
    .i_tdispctrl_0                (i_tdispctrl_2               ),
    .i_txk_0                      (i_txk_2                     ),
    .o_rxd_0                      (USE_SFP1_RX ? o_rxd_3 : o_rxd_2),
    .o_rdisper_0                  (USE_SFP1_RX ? o_rdisper_3 : o_rdisper_2),
    .o_rdecer_0                   (USE_SFP1_RX ? o_rdecer_3 : o_rdecer_2),
    .o_rxk_0                      (USE_SFP1_RX ? o_rxk_3 : o_rxk_2)
);

// Compact debug buses for Fabric Debugger.
wire [8:0] dbg_sfp0_ch0_rx_bus /* synthesis PAP_MARK_DEBUG="true" */;
assign dbg_sfp0_ch0_rx_bus = {p0_gmii_rx_dv_sfp0, p0_gmii_rxd_sfp0};
wire [8:0] dbg_sfp0_ch1_rx_bus /* synthesis PAP_MARK_DEBUG="true" */;
assign dbg_sfp0_ch1_rx_bus = {p1_gmii_rx_dv_sfp0, p1_gmii_rxd_sfp0};
wire [8:0] dbg_sfp0_ch2_rx_bus /* synthesis PAP_MARK_DEBUG="true" */;
assign dbg_sfp0_ch2_rx_bus = {p2_gmii_rx_dv_sfp0, p2_gmii_rxd_sfp0};
wire [8:0] dbg_sfp0_ch3_rx_bus /* synthesis PAP_MARK_DEBUG="true" */;
assign dbg_sfp0_ch3_rx_bus = {p3_gmii_rx_dv_sfp0, p3_gmii_rxd_sfp0};

// -----------------------------------------------------------------------------
// UDP5000/FPGV monitor for four recovered GMII channels.
// -----------------------------------------------------------------------------
wire [3:0] sfp0_rx_activity_live /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0] sfp0_rx_frame_seen    /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0] sfp0_udp5000_seen     /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0] sfp0_fpgv_seen        /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0] sfp0_rx_error_seen    /* synthesis PAP_MARK_DEBUG="true" */;
wire [1:0] sfp0_active_channel   /* synthesis PAP_MARK_DEBUG="true" */;
wire [7:0] sfp0_debug_led;

wire [15:0] last_packet_id_ch0 /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] last_packet_id_ch1 /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] last_packet_id_ch2 /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] last_packet_id_ch3 /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] last_packet_total_ch0 /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] last_packet_total_ch1 /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] last_packet_total_ch2 /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] last_packet_total_ch3 /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] last_width_ch0 /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] last_width_ch1 /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] last_width_ch2 /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] last_width_ch3 /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] last_height_ch0 /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] last_height_ch1 /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] last_height_ch2 /* synthesis PAP_MARK_DEBUG="true" */;
wire [15:0] last_height_ch3 /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] diag_ch2_frame_count;
wire [31:0] diag_ch2_udp5000_count;
wire [31:0] diag_ch2_fpgv_count;
wire [31:0] diag_ch2_er_cycle_count;

mes50hp_sfp_rx_debug_4ch #(
    .LOCAL_MAC(48'h02_00_00_00_50_01),
    .LOCAL_IP (32'hC0A8_0164),
    .UDP_PORT (16'd5000)
) u_sfp0_rx_debug (
    .free_clk(i_free_clk),
    .free_rst_n(sys_rst_n),

    .clk_ch0(p0_sgmii_clk_sfp0), .rstn_ch0(p0_rx_rstn_sync_sfp0), .rxd_ch0(p0_gmii_rxd_sfp0), .dv_ch0(p0_gmii_rx_dv_sfp0), .er_ch0(p0_gmii_rx_er_sfp0),
    .clk_ch1(p1_sgmii_clk_sfp0), .rstn_ch1(p1_rx_rstn_sync_sfp0), .rxd_ch1(p1_gmii_rxd_sfp0), .dv_ch1(p1_gmii_rx_dv_sfp0), .er_ch1(p1_gmii_rx_er_sfp0),
    .clk_ch2(p2_sgmii_clk_sfp0), .rstn_ch2(p2_rx_rstn_sync_sfp0), .rxd_ch2(p2_gmii_rxd_sfp0), .dv_ch2(p2_gmii_rx_dv_sfp0), .er_ch2(p2_gmii_rx_er_sfp0),
    .clk_ch3(p3_sgmii_clk_sfp0), .rstn_ch3(p3_rx_rstn_sync_sfp0), .rxd_ch3(p3_gmii_rxd_sfp0), .dv_ch3(p3_gmii_rx_dv_sfp0), .er_ch3(p3_gmii_rx_er_sfp0),

    .rx_activity_live(sfp0_rx_activity_live),
    .rx_frame_seen(sfp0_rx_frame_seen),
    .udp5000_seen(sfp0_udp5000_seen),
    .fpgv_seen(sfp0_fpgv_seen),
    .rx_error_seen(sfp0_rx_error_seen),
    .active_channel(sfp0_active_channel),

    .last_packet_id_ch0(last_packet_id_ch0), .last_packet_id_ch1(last_packet_id_ch1), .last_packet_id_ch2(last_packet_id_ch2), .last_packet_id_ch3(last_packet_id_ch3),
    .last_packet_total_ch0(last_packet_total_ch0), .last_packet_total_ch1(last_packet_total_ch1), .last_packet_total_ch2(last_packet_total_ch2), .last_packet_total_ch3(last_packet_total_ch3),
    .last_width_ch0(last_width_ch0), .last_width_ch1(last_width_ch1), .last_width_ch2(last_width_ch2), .last_width_ch3(last_width_ch3),
    .last_height_ch0(last_height_ch0), .last_height_ch1(last_height_ch1), .last_height_ch2(last_height_ch2), .last_height_ch3(last_height_ch3),
    .debug_led(sfp0_debug_led),
    .diag_ch2_frame_count(diag_ch2_frame_count),
    .diag_ch2_udp5000_count(diag_ch2_udp5000_count),
    .diag_ch2_fpgv_count(diag_ch2_fpgv_count),
    .diag_ch2_er_cycle_count(diag_ch2_er_cycle_count)
);


// -----------------------------------------------------------------------------
// Stage7A exported GMII/status ports.
// -----------------------------------------------------------------------------
assign out_p0_sgmii_clk      = p0_sgmii_clk_sfp0;
assign out_p1_sgmii_clk      = p1_sgmii_clk_sfp0;
assign out_p2_sgmii_clk      = p2_sgmii_clk_sfp0;
assign out_p3_sgmii_clk      = p3_sgmii_clk_sfp0;

assign out_p0_rx_rstn        = p0_rx_rstn_sync_sfp0;
assign out_p1_rx_rstn        = p1_rx_rstn_sync_sfp0;
assign out_p2_rx_rstn        = p2_rx_rstn_sync_sfp0;
assign out_p3_rx_rstn        = p3_rx_rstn_sync_sfp0;

assign out_p0_gmii_rxd       = p0_gmii_rxd_sfp0;
assign out_p1_gmii_rxd       = p1_gmii_rxd_sfp0;
assign out_p2_gmii_rxd       = p2_gmii_rxd_sfp0;
assign out_p3_gmii_rxd       = p3_gmii_rxd_sfp0;

assign out_p0_gmii_rx_dv     = p0_gmii_rx_dv_sfp0;
assign out_p1_gmii_rx_dv     = p1_gmii_rx_dv_sfp0;
assign out_p2_gmii_rx_dv     = p2_gmii_rx_dv_sfp0;
assign out_p3_gmii_rx_dv     = p3_gmii_rx_dv_sfp0;

assign out_p0_gmii_rx_er     = p0_gmii_rx_er_sfp0;
assign out_p1_gmii_rx_er     = p1_gmii_rx_er_sfp0;
assign out_p2_gmii_rx_er     = p2_gmii_rx_er_sfp0;
assign out_p3_gmii_rx_er     = p3_gmii_rx_er_sfp0;

assign out_rx_activity_live  = sfp0_rx_activity_live;
assign out_rx_frame_seen     = sfp0_rx_frame_seen;
assign out_udp5000_seen      = sfp0_udp5000_seen;
assign out_fpgv_seen         = sfp0_fpgv_seen;
assign out_rx_error_seen     = sfp0_rx_error_seen;
assign out_hsst_pll_lock     = o_p_pll_lock_0;
assign out_sfp0_lane_done    = USE_SFP1_RX ? o_rxlane_done_3 : o_rxlane_done_2;
assign out_sfp0_pcs_synced   = USE_SFP1_RX ? o_p_pcs_lsm_synced_3 : o_p_pcs_lsm_synced_2;
assign out_diag_ch2_frame_count    = diag_ch2_frame_count;
assign out_diag_ch2_udp5000_count  = diag_ch2_udp5000_count;
assign out_diag_ch2_fpgv_count     = diag_ch2_fpgv_count;
assign out_diag_ch2_er_cycle_count = diag_ch2_er_cycle_count;

// LED mapping for board bring-up.
assign led[0] = sfp0_debug_led[0];       // heartbeat
assign led[1] = o_p_pll_lock_0;          // HSST PLL lock
assign led[2] = USE_SFP1_RX ? o_rxlane_done_3 : o_rxlane_done_2; // selected SFP RX lane ready
assign led[3] = USE_SFP1_RX ? o_p_pcs_lsm_synced_3 : o_p_pcs_lsm_synced_2; // selected SFP PCS synced
assign led[4] = |sfp0_rx_activity_live;  // any recovered GMII RX activity
assign led[5] = |sfp0_udp5000_seen;      // UDP destination port 5000 seen
assign led[6] = |sfp0_fpgv_seen;         // FPGV magic seen
assign led[7] = (USE_SFP1_RX ? sfp1_los : sfp0_los) | |sfp0_rx_error_seen; // selected SFP loss/error

endmodule
