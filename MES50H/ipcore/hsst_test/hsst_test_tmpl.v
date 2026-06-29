// Created by IP Generator (Version 2022.2-SP6.7 build 153067)
// Instantiation Template
//
// Insert the following codes into your Verilog file.
//   * Change the_instance_name to your own instance name.
//   * Change the signal names in the port associations


hsst_test the_instance_name (
  .i_free_clk(i_free_clk),                        // input
  .i_pll_rst_0(i_pll_rst_0),                      // input
  .i_wtchdg_clr_0(i_wtchdg_clr_0),                // input
  .o_wtchdg_st_0(o_wtchdg_st_0),                  // output [1:0]
  .o_pll_done_0(o_pll_done_0),                    // output
  .o_txlane_done_0(o_txlane_done_0),              // output
  .o_txlane_done_1(o_txlane_done_1),              // output
  .o_txlane_done_2(o_txlane_done_2),              // output
  .o_txlane_done_3(o_txlane_done_3),              // output
  .o_rxlane_done_0(o_rxlane_done_0),              // output
  .o_rxlane_done_1(o_rxlane_done_1),              // output
  .o_rxlane_done_2(o_rxlane_done_2),              // output
  .o_rxlane_done_3(o_rxlane_done_3),              // output
  .i_p_refckn_0(i_p_refckn_0),                    // input
  .i_p_refckp_0(i_p_refckp_0),                    // input
  .o_p_clk2core_tx_0(o_p_clk2core_tx_0),          // output
  .o_p_clk2core_tx_1(o_p_clk2core_tx_1),          // output
  .o_p_clk2core_tx_2(o_p_clk2core_tx_2),          // output
  .o_p_clk2core_tx_3(o_p_clk2core_tx_3),          // output
  .i_p_tx0_clk_fr_core(i_p_tx0_clk_fr_core),      // input
  .i_p_tx1_clk_fr_core(i_p_tx1_clk_fr_core),      // input
  .i_p_tx2_clk_fr_core(i_p_tx2_clk_fr_core),      // input
  .i_p_tx3_clk_fr_core(i_p_tx3_clk_fr_core),      // input
  .o_p_clk2core_rx_0(o_p_clk2core_rx_0),          // output
  .o_p_clk2core_rx_1(o_p_clk2core_rx_1),          // output
  .o_p_clk2core_rx_2(o_p_clk2core_rx_2),          // output
  .o_p_clk2core_rx_3(o_p_clk2core_rx_3),          // output
  .i_p_rx0_clk_fr_core(i_p_rx0_clk_fr_core),      // input
  .i_p_rx1_clk_fr_core(i_p_rx1_clk_fr_core),      // input
  .i_p_rx2_clk_fr_core(i_p_rx2_clk_fr_core),      // input
  .i_p_rx3_clk_fr_core(i_p_rx3_clk_fr_core),      // input
  .o_p_pll_lock_0(o_p_pll_lock_0),                // output
  .o_p_rx_sigdet_sta_0(o_p_rx_sigdet_sta_0),      // output
  .o_p_rx_sigdet_sta_1(o_p_rx_sigdet_sta_1),      // output
  .o_p_rx_sigdet_sta_2(o_p_rx_sigdet_sta_2),      // output
  .o_p_rx_sigdet_sta_3(o_p_rx_sigdet_sta_3),      // output
  .o_p_lx_cdr_align_0(o_p_lx_cdr_align_0),        // output
  .o_p_lx_cdr_align_1(o_p_lx_cdr_align_1),        // output
  .o_p_lx_cdr_align_2(o_p_lx_cdr_align_2),        // output
  .o_p_lx_cdr_align_3(o_p_lx_cdr_align_3),        // output
  .o_p_pcs_lsm_synced_0(o_p_pcs_lsm_synced_0),    // output
  .o_p_pcs_lsm_synced_1(o_p_pcs_lsm_synced_1),    // output
  .o_p_pcs_lsm_synced_2(o_p_pcs_lsm_synced_2),    // output
  .o_p_pcs_lsm_synced_3(o_p_pcs_lsm_synced_3),    // output
  .i_p_l0rxn(i_p_l0rxn),                          // input
  .i_p_l0rxp(i_p_l0rxp),                          // input
  .i_p_l1rxn(i_p_l1rxn),                          // input
  .i_p_l1rxp(i_p_l1rxp),                          // input
  .i_p_l2rxn(i_p_l2rxn),                          // input
  .i_p_l2rxp(i_p_l2rxp),                          // input
  .i_p_l3rxn(i_p_l3rxn),                          // input
  .i_p_l3rxp(i_p_l3rxp),                          // input
  .o_p_l0txn(o_p_l0txn),                          // output
  .o_p_l0txp(o_p_l0txp),                          // output
  .o_p_l1txn(o_p_l1txn),                          // output
  .o_p_l1txp(o_p_l1txp),                          // output
  .o_p_l2txn(o_p_l2txn),                          // output
  .o_p_l2txp(o_p_l2txp),                          // output
  .o_p_l3txn(o_p_l3txn),                          // output
  .o_p_l3txp(o_p_l3txp),                          // output
  .i_txd_0(i_txd_0),                              // input [31:0]
  .i_tdispsel_0(i_tdispsel_0),                    // input [3:0]
  .i_tdispctrl_0(i_tdispctrl_0),                  // input [3:0]
  .i_txk_0(i_txk_0),                              // input [3:0]
  .i_txd_1(i_txd_1),                              // input [31:0]
  .i_tdispsel_1(i_tdispsel_1),                    // input [3:0]
  .i_tdispctrl_1(i_tdispctrl_1),                  // input [3:0]
  .i_txk_1(i_txk_1),                              // input [3:0]
  .i_txd_2(i_txd_2),                              // input [31:0]
  .i_tdispsel_2(i_tdispsel_2),                    // input [3:0]
  .i_tdispctrl_2(i_tdispctrl_2),                  // input [3:0]
  .i_txk_2(i_txk_2),                              // input [3:0]
  .i_txd_3(i_txd_3),                              // input [31:0]
  .i_tdispsel_3(i_tdispsel_3),                    // input [3:0]
  .i_tdispctrl_3(i_tdispctrl_3),                  // input [3:0]
  .i_txk_3(i_txk_3),                              // input [3:0]
  .o_rxstatus_0(o_rxstatus_0),                    // output [2:0]
  .o_rxd_0(o_rxd_0),                              // output [31:0]
  .o_rdisper_0(o_rdisper_0),                      // output [3:0]
  .o_rdecer_0(o_rdecer_0),                        // output [3:0]
  .o_rxk_0(o_rxk_0),                              // output [3:0]
  .o_rxstatus_1(o_rxstatus_1),                    // output [2:0]
  .o_rxd_1(o_rxd_1),                              // output [31:0]
  .o_rdisper_1(o_rdisper_1),                      // output [3:0]
  .o_rdecer_1(o_rdecer_1),                        // output [3:0]
  .o_rxk_1(o_rxk_1),                              // output [3:0]
  .o_rxstatus_2(o_rxstatus_2),                    // output [2:0]
  .o_rxd_2(o_rxd_2),                              // output [31:0]
  .o_rdisper_2(o_rdisper_2),                      // output [3:0]
  .o_rdecer_2(o_rdecer_2),                        // output [3:0]
  .o_rxk_2(o_rxk_2),                              // output [3:0]
  .o_rxstatus_3(o_rxstatus_3),                    // output [2:0]
  .o_rxd_3(o_rxd_3),                              // output [31:0]
  .o_rdisper_3(o_rdisper_3),                      // output [3:0]
  .o_rdecer_3(o_rdecer_3),                        // output [3:0]
  .o_rxk_3(o_rxk_3)                               // output [3:0]
);
