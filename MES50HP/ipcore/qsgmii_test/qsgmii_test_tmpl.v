// Created by IP Generator (Version 2022.2-SP6.7 build 153067)
// Instantiation Template
//
// Insert the following codes into your Verilog file.
//   * Change the_instance_name to your own instance name.
//   * Change the signal names in the port associations


qsgmii_test the_instance_name (
  .p0_gmii_txd(p0_gmii_txd),                            // input [7:0]
  .p0_gmii_tx_en(p0_gmii_tx_en),                        // input
  .p0_gmii_tx_er(p0_gmii_tx_er),                        // input
  .p0_gmii_rxd(p0_gmii_rxd),                            // output [7:0]
  .p0_gmii_rx_dv(p0_gmii_rx_dv),                        // output
  .p0_gmii_rx_er(p0_gmii_rx_er),                        // output
  .p0_receiving(p0_receiving),                          // output
  .p0_transmitting(p0_transmitting),                    // output
  .p0_sgmii_clk(p0_sgmii_clk),                          // output
  .p0_tx_clken(p0_tx_clken),                            // output
  .p0_tx_rstn_sync(p0_tx_rstn_sync),                    // output
  .p0_rx_rstn_sync(p0_rx_rstn_sync),                    // output
  .p1_gmii_txd(p1_gmii_txd),                            // input [7:0]
  .p1_gmii_tx_en(p1_gmii_tx_en),                        // input
  .p1_gmii_tx_er(p1_gmii_tx_er),                        // input
  .p1_gmii_rxd(p1_gmii_rxd),                            // output [7:0]
  .p1_gmii_rx_dv(p1_gmii_rx_dv),                        // output
  .p1_gmii_rx_er(p1_gmii_rx_er),                        // output
  .p1_receiving(p1_receiving),                          // output
  .p1_transmitting(p1_transmitting),                    // output
  .p1_sgmii_clk(p1_sgmii_clk),                          // output
  .p1_tx_clken(p1_tx_clken),                            // output
  .p1_tx_rstn_sync(p1_tx_rstn_sync),                    // output
  .p1_rx_rstn_sync(p1_rx_rstn_sync),                    // output
  .p2_gmii_txd(p2_gmii_txd),                            // input [7:0]
  .p2_gmii_tx_en(p2_gmii_tx_en),                        // input
  .p2_gmii_tx_er(p2_gmii_tx_er),                        // input
  .p2_gmii_rxd(p2_gmii_rxd),                            // output [7:0]
  .p2_gmii_rx_dv(p2_gmii_rx_dv),                        // output
  .p2_gmii_rx_er(p2_gmii_rx_er),                        // output
  .p2_receiving(p2_receiving),                          // output
  .p2_transmitting(p2_transmitting),                    // output
  .p2_sgmii_clk(p2_sgmii_clk),                          // output
  .p2_tx_clken(p2_tx_clken),                            // output
  .p2_tx_rstn_sync(p2_tx_rstn_sync),                    // output
  .p2_rx_rstn_sync(p2_rx_rstn_sync),                    // output
  .p3_gmii_txd(p3_gmii_txd),                            // input [7:0]
  .p3_gmii_tx_en(p3_gmii_tx_en),                        // input
  .p3_gmii_tx_er(p3_gmii_tx_er),                        // input
  .p3_gmii_rxd(p3_gmii_rxd),                            // output [7:0]
  .p3_gmii_rx_dv(p3_gmii_rx_dv),                        // output
  .p3_gmii_rx_er(p3_gmii_rx_er),                        // output
  .p3_receiving(p3_receiving),                          // output
  .p3_transmitting(p3_transmitting),                    // output
  .p3_sgmii_clk(p3_sgmii_clk),                          // output
  .p3_tx_clken(p3_tx_clken),                            // output
  .p3_tx_rstn_sync(p3_tx_rstn_sync),                    // output
  .p3_rx_rstn_sync(p3_rx_rstn_sync),                    // output
  .p0_pclk(p0_pclk),                                    // input
  .p0_paddr(p0_paddr),                                  // input [18:0]
  .p0_pwrite(p0_pwrite),                                // input
  .p0_psel(p0_psel),                                    // input
  .p0_penable(p0_penable),                              // input
  .p0_pwdata(p0_pwdata),                                // input [31:0]
  .p0_prdata(p0_prdata),                                // output [31:0]
  .p0_pready(p0_pready),                                // output
  .p0_cfg_rst_n(p0_cfg_rst_n),                          // output
  .p1_pclk(p1_pclk),                                    // input
  .p1_paddr(p1_paddr),                                  // input [18:0]
  .p1_pwrite(p1_pwrite),                                // input
  .p1_psel(p1_psel),                                    // input
  .p1_penable(p1_penable),                              // input
  .p1_pwdata(p1_pwdata),                                // input [31:0]
  .p1_prdata(p1_prdata),                                // output [31:0]
  .p1_pready(p1_pready),                                // output
  .p1_cfg_rst_n(p1_cfg_rst_n),                          // output
  .p2_pclk(p2_pclk),                                    // input
  .p2_paddr(p2_paddr),                                  // input [18:0]
  .p2_pwrite(p2_pwrite),                                // input
  .p2_psel(p2_psel),                                    // input
  .p2_penable(p2_penable),                              // input
  .p2_pwdata(p2_pwdata),                                // input [31:0]
  .p2_prdata(p2_prdata),                                // output [31:0]
  .p2_pready(p2_pready),                                // output
  .p2_cfg_rst_n(p2_cfg_rst_n),                          // output
  .p3_pclk(p3_pclk),                                    // input
  .p3_paddr(p3_paddr),                                  // input [18:0]
  .p3_pwrite(p3_pwrite),                                // input
  .p3_psel(p3_psel),                                    // input
  .p3_penable(p3_penable),                              // input
  .p3_pwdata(p3_pwdata),                                // input [31:0]
  .p3_prdata(p3_prdata),                                // output [31:0]
  .p3_pready(p3_pready),                                // output
  .p3_cfg_rst_n(p3_cfg_rst_n),                          // output
  .P_REFCKN(P_REFCKN),                                  // input
  .P_REFCKP(P_REFCKP),                                  // input
  .free_clk(free_clk),                                  // input
  .external_rstn(external_rstn),                        // input
  .qsgmii_tx_rstn(qsgmii_tx_rstn),                      // output
  .qsgmii_rx_rstn(qsgmii_rx_rstn),                      // output
  .p0_soft_rstn(p0_soft_rstn),                          // input
  .p1_soft_rstn(p1_soft_rstn),                          // input
  .p2_soft_rstn(p2_soft_rstn),                          // input
  .p3_soft_rstn(p3_soft_rstn),                          // input
  .txpll_sof_rst_n(txpll_sof_rst_n),                    // input
  .hsst_cfg_soft_rstn(hsst_cfg_soft_rstn),              // input
  .txlane_sof_rst_n(txlane_sof_rst_n),                  // input
  .rxlane_sof_rst_n(rxlane_sof_rst_n),                  // input [3:0]
  .wtchdg_clr(wtchdg_clr),                              // input
  .hsst_ch_ready(hsst_ch_ready),                        // output [3:0]
  .P_L0TXN(P_L0TXN),                                    // output
  .P_L0TXP(P_L0TXP),                                    // output
  .P_L0RXN(P_L0RXN),                                    // input
  .P_L0RXP(P_L0RXP),                                    // input
  .l0_signal_loss(l0_signal_loss),                      // output
  .l0_cdr_align(l0_cdr_align),                          // output
  .l0_tx_pll_lock(l0_tx_pll_lock),                      // output
  .l0_lsm_synced(l0_lsm_synced),                        // output
  .l0_pcs_nearend_loop(l0_pcs_nearend_loop),            // input
  .l0_pcs_farend_loop(l0_pcs_farend_loop),              // input
  .l0_pma_nearend_ploop(l0_pma_nearend_ploop),          // input
  .l0_pma_nearend_sloop(l0_pma_nearend_sloop),          // input
  .p0_AN_CS(p0_AN_CS),                                  // output [3:0]
  .p0_AN_NS(p0_AN_NS),                                  // output [3:0]
  .p0_RS_CS(p0_RS_CS),                                  // output [4:0]
  .p0_RS_NS(p0_RS_NS),                                  // output [4:0]
  .p0_TS_CS(p0_TS_CS),                                  // output [4:0]
  .p0_TS_NS(p0_TS_NS),                                  // output [4:0]
  .p0_xmit(p0_xmit),                                    // output [1:0]
  .p0_rx_unitdata_indicate(p0_rx_unitdata_indicate),    // output [1:0]
  .p1_AN_CS(p1_AN_CS),                                  // output [3:0]
  .p1_AN_NS(p1_AN_NS),                                  // output [3:0]
  .p1_RS_CS(p1_RS_CS),                                  // output [4:0]
  .p1_RS_NS(p1_RS_NS),                                  // output [4:0]
  .p1_TS_CS(p1_TS_CS),                                  // output [4:0]
  .p1_TS_NS(p1_TS_NS),                                  // output [4:0]
  .p1_xmit(p1_xmit),                                    // output [1:0]
  .p1_rx_unitdata_indicate(p1_rx_unitdata_indicate),    // output [1:0]
  .p2_AN_CS(p2_AN_CS),                                  // output [3:0]
  .p2_AN_NS(p2_AN_NS),                                  // output [3:0]
  .p2_RS_CS(p2_RS_CS),                                  // output [4:0]
  .p2_RS_NS(p2_RS_NS),                                  // output [4:0]
  .p2_TS_CS(p2_TS_CS),                                  // output [4:0]
  .p2_TS_NS(p2_TS_NS),                                  // output [4:0]
  .p2_xmit(p2_xmit),                                    // output [1:0]
  .p2_rx_unitdata_indicate(p2_rx_unitdata_indicate),    // output [1:0]
  .p3_AN_CS(p3_AN_CS),                                  // output [3:0]
  .p3_AN_NS(p3_AN_NS),                                  // output [3:0]
  .p3_RS_CS(p3_RS_CS),                                  // output [4:0]
  .p3_RS_NS(p3_RS_NS),                                  // output [4:0]
  .p3_TS_CS(p3_TS_CS),                                  // output [4:0]
  .p3_TS_NS(p3_TS_NS),                                  // output [4:0]
  .p3_xmit(p3_xmit),                                    // output [1:0]
  .p3_rx_unitdata_indicate(p3_rx_unitdata_indicate),    // output [1:0]
  .l0_pcs_clk(l0_pcs_clk),                              // output
  .l0_pcs_rx_clk(l0_pcs_rx_clk),                        // output
  .l0_pcs_rxk(l0_pcs_rxk),                              // output [3:0]
  .l0_pcs_rdispdec_er(l0_pcs_rdispdec_er),              // output
  .l0_pcs_rxd(l0_pcs_rxd),                              // output [31:0]
  .l0_pcs_txk(l0_pcs_txk),                              // output [3:0]
  .l0_pcs_tx_dispctrl(l0_pcs_tx_dispctrl),              // output [3:0]
  .l0_pcs_tx_dispsel(l0_pcs_tx_dispsel),                // output [3:0]
  .l0_pcs_txd(l0_pcs_txd),                              // output [31:0]
  .p0_status_vector(p0_status_vector),                  // output [15:0]
  .p0_pin_cfg_en(p0_pin_cfg_en),                        // input
  .p0_phy_link(p0_phy_link),                            // input
  .p0_phy_duplex(p0_phy_duplex),                        // input
  .p0_phy_speed(p0_phy_speed),                          // input [1:0]
  .p0_unidir_en(p0_unidir_en),                          // input
  .p0_an_restart(p0_an_restart),                        // input
  .p0_an_enable(p0_an_enable),                          // input
  .p0_loopback(p0_loopback),                            // input
  .p1_status_vector(p1_status_vector),                  // output [15:0]
  .p1_pin_cfg_en(p1_pin_cfg_en),                        // input
  .p1_phy_link(p1_phy_link),                            // input
  .p1_phy_duplex(p1_phy_duplex),                        // input
  .p1_phy_speed(p1_phy_speed),                          // input [1:0]
  .p1_unidir_en(p1_unidir_en),                          // input
  .p1_an_restart(p1_an_restart),                        // input
  .p1_an_enable(p1_an_enable),                          // input
  .p1_loopback(p1_loopback),                            // input
  .p2_status_vector(p2_status_vector),                  // output [15:0]
  .p2_pin_cfg_en(p2_pin_cfg_en),                        // input
  .p2_phy_link(p2_phy_link),                            // input
  .p2_phy_duplex(p2_phy_duplex),                        // input
  .p2_phy_speed(p2_phy_speed),                          // input [1:0]
  .p2_unidir_en(p2_unidir_en),                          // input
  .p2_an_restart(p2_an_restart),                        // input
  .p2_an_enable(p2_an_enable),                          // input
  .p2_loopback(p2_loopback),                            // input
  .p3_status_vector(p3_status_vector),                  // output [15:0]
  .p3_pin_cfg_en(p3_pin_cfg_en),                        // input
  .p3_phy_link(p3_phy_link),                            // input
  .p3_phy_duplex(p3_phy_duplex),                        // input
  .p3_phy_speed(p3_phy_speed),                          // input [1:0]
  .p3_unidir_en(p3_unidir_en),                          // input
  .p3_an_restart(p3_an_restart),                        // input
  .p3_an_enable(p3_an_enable),                          // input
  .p3_loopback(p3_loopback)                             // input
);
