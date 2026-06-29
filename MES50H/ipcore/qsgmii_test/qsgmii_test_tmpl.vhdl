-- Created by IP Generator (Version 2022.2-SP6.7 build 153067)
-- Instantiation Template
--
-- Insert the following codes into your VHDL file.
--   * Change the_instance_name to your own instance name.
--   * Change the net names in the port map.


COMPONENT qsgmii_test
  PORT (
    p0_gmii_txd : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    p0_gmii_tx_en : IN STD_LOGIC;
    p0_gmii_tx_er : IN STD_LOGIC;
    p0_gmii_rxd : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    p0_gmii_rx_dv : OUT STD_LOGIC;
    p0_gmii_rx_er : OUT STD_LOGIC;
    p0_receiving : OUT STD_LOGIC;
    p0_transmitting : OUT STD_LOGIC;
    p0_sgmii_clk : OUT STD_LOGIC;
    p0_tx_clken : OUT STD_LOGIC;
    p0_tx_rstn_sync : OUT STD_LOGIC;
    p0_rx_rstn_sync : OUT STD_LOGIC;
    p1_gmii_txd : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    p1_gmii_tx_en : IN STD_LOGIC;
    p1_gmii_tx_er : IN STD_LOGIC;
    p1_gmii_rxd : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    p1_gmii_rx_dv : OUT STD_LOGIC;
    p1_gmii_rx_er : OUT STD_LOGIC;
    p1_receiving : OUT STD_LOGIC;
    p1_transmitting : OUT STD_LOGIC;
    p1_sgmii_clk : OUT STD_LOGIC;
    p1_tx_clken : OUT STD_LOGIC;
    p1_tx_rstn_sync : OUT STD_LOGIC;
    p1_rx_rstn_sync : OUT STD_LOGIC;
    p2_gmii_txd : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    p2_gmii_tx_en : IN STD_LOGIC;
    p2_gmii_tx_er : IN STD_LOGIC;
    p2_gmii_rxd : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    p2_gmii_rx_dv : OUT STD_LOGIC;
    p2_gmii_rx_er : OUT STD_LOGIC;
    p2_receiving : OUT STD_LOGIC;
    p2_transmitting : OUT STD_LOGIC;
    p2_sgmii_clk : OUT STD_LOGIC;
    p2_tx_clken : OUT STD_LOGIC;
    p2_tx_rstn_sync : OUT STD_LOGIC;
    p2_rx_rstn_sync : OUT STD_LOGIC;
    p3_gmii_txd : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    p3_gmii_tx_en : IN STD_LOGIC;
    p3_gmii_tx_er : IN STD_LOGIC;
    p3_gmii_rxd : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    p3_gmii_rx_dv : OUT STD_LOGIC;
    p3_gmii_rx_er : OUT STD_LOGIC;
    p3_receiving : OUT STD_LOGIC;
    p3_transmitting : OUT STD_LOGIC;
    p3_sgmii_clk : OUT STD_LOGIC;
    p3_tx_clken : OUT STD_LOGIC;
    p3_tx_rstn_sync : OUT STD_LOGIC;
    p3_rx_rstn_sync : OUT STD_LOGIC;
    p0_pclk : IN STD_LOGIC;
    p0_paddr : IN STD_LOGIC_VECTOR(18 DOWNTO 0);
    p0_pwrite : IN STD_LOGIC;
    p0_psel : IN STD_LOGIC;
    p0_penable : IN STD_LOGIC;
    p0_pwdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    p0_prdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    p0_pready : OUT STD_LOGIC;
    p0_cfg_rst_n : OUT STD_LOGIC;
    p1_pclk : IN STD_LOGIC;
    p1_paddr : IN STD_LOGIC_VECTOR(18 DOWNTO 0);
    p1_pwrite : IN STD_LOGIC;
    p1_psel : IN STD_LOGIC;
    p1_penable : IN STD_LOGIC;
    p1_pwdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    p1_prdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    p1_pready : OUT STD_LOGIC;
    p1_cfg_rst_n : OUT STD_LOGIC;
    p2_pclk : IN STD_LOGIC;
    p2_paddr : IN STD_LOGIC_VECTOR(18 DOWNTO 0);
    p2_pwrite : IN STD_LOGIC;
    p2_psel : IN STD_LOGIC;
    p2_penable : IN STD_LOGIC;
    p2_pwdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    p2_prdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    p2_pready : OUT STD_LOGIC;
    p2_cfg_rst_n : OUT STD_LOGIC;
    p3_pclk : IN STD_LOGIC;
    p3_paddr : IN STD_LOGIC_VECTOR(18 DOWNTO 0);
    p3_pwrite : IN STD_LOGIC;
    p3_psel : IN STD_LOGIC;
    p3_penable : IN STD_LOGIC;
    p3_pwdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    p3_prdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    p3_pready : OUT STD_LOGIC;
    p3_cfg_rst_n : OUT STD_LOGIC;
    P_REFCKN : IN STD_LOGIC;
    P_REFCKP : IN STD_LOGIC;
    free_clk : IN STD_LOGIC;
    external_rstn : IN STD_LOGIC;
    qsgmii_tx_rstn : OUT STD_LOGIC;
    qsgmii_rx_rstn : OUT STD_LOGIC;
    p0_soft_rstn : IN STD_LOGIC;
    p1_soft_rstn : IN STD_LOGIC;
    p2_soft_rstn : IN STD_LOGIC;
    p3_soft_rstn : IN STD_LOGIC;
    txpll_sof_rst_n : IN STD_LOGIC;
    hsst_cfg_soft_rstn : IN STD_LOGIC;
    txlane_sof_rst_n : IN STD_LOGIC;
    rxlane_sof_rst_n : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    wtchdg_clr : IN STD_LOGIC;
    hsst_ch_ready : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    P_L0TXN : OUT STD_LOGIC;
    P_L0TXP : OUT STD_LOGIC;
    P_L0RXN : IN STD_LOGIC;
    P_L0RXP : IN STD_LOGIC;
    l0_signal_loss : OUT STD_LOGIC;
    l0_cdr_align : OUT STD_LOGIC;
    l0_tx_pll_lock : OUT STD_LOGIC;
    l0_lsm_synced : OUT STD_LOGIC;
    l0_pcs_nearend_loop : IN STD_LOGIC;
    l0_pcs_farend_loop : IN STD_LOGIC;
    l0_pma_nearend_ploop : IN STD_LOGIC;
    l0_pma_nearend_sloop : IN STD_LOGIC;
    p0_AN_CS : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    p0_AN_NS : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    p0_RS_CS : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    p0_RS_NS : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    p0_TS_CS : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    p0_TS_NS : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    p0_xmit : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    p0_rx_unitdata_indicate : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    p1_AN_CS : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    p1_AN_NS : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    p1_RS_CS : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    p1_RS_NS : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    p1_TS_CS : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    p1_TS_NS : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    p1_xmit : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    p1_rx_unitdata_indicate : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    p2_AN_CS : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    p2_AN_NS : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    p2_RS_CS : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    p2_RS_NS : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    p2_TS_CS : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    p2_TS_NS : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    p2_xmit : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    p2_rx_unitdata_indicate : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    p3_AN_CS : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    p3_AN_NS : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    p3_RS_CS : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    p3_RS_NS : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    p3_TS_CS : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    p3_TS_NS : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    p3_xmit : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    p3_rx_unitdata_indicate : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    l0_pcs_clk : OUT STD_LOGIC;
    l0_pcs_rx_clk : OUT STD_LOGIC;
    l0_pcs_rxk : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    l0_pcs_rdispdec_er : OUT STD_LOGIC;
    l0_pcs_rxd : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    l0_pcs_txk : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    l0_pcs_tx_dispctrl : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    l0_pcs_tx_dispsel : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    l0_pcs_txd : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    p0_status_vector : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    p0_pin_cfg_en : IN STD_LOGIC;
    p0_phy_link : IN STD_LOGIC;
    p0_phy_duplex : IN STD_LOGIC;
    p0_phy_speed : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    p0_unidir_en : IN STD_LOGIC;
    p0_an_restart : IN STD_LOGIC;
    p0_an_enable : IN STD_LOGIC;
    p0_loopback : IN STD_LOGIC;
    p1_status_vector : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    p1_pin_cfg_en : IN STD_LOGIC;
    p1_phy_link : IN STD_LOGIC;
    p1_phy_duplex : IN STD_LOGIC;
    p1_phy_speed : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    p1_unidir_en : IN STD_LOGIC;
    p1_an_restart : IN STD_LOGIC;
    p1_an_enable : IN STD_LOGIC;
    p1_loopback : IN STD_LOGIC;
    p2_status_vector : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    p2_pin_cfg_en : IN STD_LOGIC;
    p2_phy_link : IN STD_LOGIC;
    p2_phy_duplex : IN STD_LOGIC;
    p2_phy_speed : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    p2_unidir_en : IN STD_LOGIC;
    p2_an_restart : IN STD_LOGIC;
    p2_an_enable : IN STD_LOGIC;
    p2_loopback : IN STD_LOGIC;
    p3_status_vector : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    p3_pin_cfg_en : IN STD_LOGIC;
    p3_phy_link : IN STD_LOGIC;
    p3_phy_duplex : IN STD_LOGIC;
    p3_phy_speed : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    p3_unidir_en : IN STD_LOGIC;
    p3_an_restart : IN STD_LOGIC;
    p3_an_enable : IN STD_LOGIC;
    p3_loopback : IN STD_LOGIC
  );
END COMPONENT;


the_instance_name : qsgmii_test
  PORT MAP (
    p0_gmii_txd => p0_gmii_txd,
    p0_gmii_tx_en => p0_gmii_tx_en,
    p0_gmii_tx_er => p0_gmii_tx_er,
    p0_gmii_rxd => p0_gmii_rxd,
    p0_gmii_rx_dv => p0_gmii_rx_dv,
    p0_gmii_rx_er => p0_gmii_rx_er,
    p0_receiving => p0_receiving,
    p0_transmitting => p0_transmitting,
    p0_sgmii_clk => p0_sgmii_clk,
    p0_tx_clken => p0_tx_clken,
    p0_tx_rstn_sync => p0_tx_rstn_sync,
    p0_rx_rstn_sync => p0_rx_rstn_sync,
    p1_gmii_txd => p1_gmii_txd,
    p1_gmii_tx_en => p1_gmii_tx_en,
    p1_gmii_tx_er => p1_gmii_tx_er,
    p1_gmii_rxd => p1_gmii_rxd,
    p1_gmii_rx_dv => p1_gmii_rx_dv,
    p1_gmii_rx_er => p1_gmii_rx_er,
    p1_receiving => p1_receiving,
    p1_transmitting => p1_transmitting,
    p1_sgmii_clk => p1_sgmii_clk,
    p1_tx_clken => p1_tx_clken,
    p1_tx_rstn_sync => p1_tx_rstn_sync,
    p1_rx_rstn_sync => p1_rx_rstn_sync,
    p2_gmii_txd => p2_gmii_txd,
    p2_gmii_tx_en => p2_gmii_tx_en,
    p2_gmii_tx_er => p2_gmii_tx_er,
    p2_gmii_rxd => p2_gmii_rxd,
    p2_gmii_rx_dv => p2_gmii_rx_dv,
    p2_gmii_rx_er => p2_gmii_rx_er,
    p2_receiving => p2_receiving,
    p2_transmitting => p2_transmitting,
    p2_sgmii_clk => p2_sgmii_clk,
    p2_tx_clken => p2_tx_clken,
    p2_tx_rstn_sync => p2_tx_rstn_sync,
    p2_rx_rstn_sync => p2_rx_rstn_sync,
    p3_gmii_txd => p3_gmii_txd,
    p3_gmii_tx_en => p3_gmii_tx_en,
    p3_gmii_tx_er => p3_gmii_tx_er,
    p3_gmii_rxd => p3_gmii_rxd,
    p3_gmii_rx_dv => p3_gmii_rx_dv,
    p3_gmii_rx_er => p3_gmii_rx_er,
    p3_receiving => p3_receiving,
    p3_transmitting => p3_transmitting,
    p3_sgmii_clk => p3_sgmii_clk,
    p3_tx_clken => p3_tx_clken,
    p3_tx_rstn_sync => p3_tx_rstn_sync,
    p3_rx_rstn_sync => p3_rx_rstn_sync,
    p0_pclk => p0_pclk,
    p0_paddr => p0_paddr,
    p0_pwrite => p0_pwrite,
    p0_psel => p0_psel,
    p0_penable => p0_penable,
    p0_pwdata => p0_pwdata,
    p0_prdata => p0_prdata,
    p0_pready => p0_pready,
    p0_cfg_rst_n => p0_cfg_rst_n,
    p1_pclk => p1_pclk,
    p1_paddr => p1_paddr,
    p1_pwrite => p1_pwrite,
    p1_psel => p1_psel,
    p1_penable => p1_penable,
    p1_pwdata => p1_pwdata,
    p1_prdata => p1_prdata,
    p1_pready => p1_pready,
    p1_cfg_rst_n => p1_cfg_rst_n,
    p2_pclk => p2_pclk,
    p2_paddr => p2_paddr,
    p2_pwrite => p2_pwrite,
    p2_psel => p2_psel,
    p2_penable => p2_penable,
    p2_pwdata => p2_pwdata,
    p2_prdata => p2_prdata,
    p2_pready => p2_pready,
    p2_cfg_rst_n => p2_cfg_rst_n,
    p3_pclk => p3_pclk,
    p3_paddr => p3_paddr,
    p3_pwrite => p3_pwrite,
    p3_psel => p3_psel,
    p3_penable => p3_penable,
    p3_pwdata => p3_pwdata,
    p3_prdata => p3_prdata,
    p3_pready => p3_pready,
    p3_cfg_rst_n => p3_cfg_rst_n,
    P_REFCKN => P_REFCKN,
    P_REFCKP => P_REFCKP,
    free_clk => free_clk,
    external_rstn => external_rstn,
    qsgmii_tx_rstn => qsgmii_tx_rstn,
    qsgmii_rx_rstn => qsgmii_rx_rstn,
    p0_soft_rstn => p0_soft_rstn,
    p1_soft_rstn => p1_soft_rstn,
    p2_soft_rstn => p2_soft_rstn,
    p3_soft_rstn => p3_soft_rstn,
    txpll_sof_rst_n => txpll_sof_rst_n,
    hsst_cfg_soft_rstn => hsst_cfg_soft_rstn,
    txlane_sof_rst_n => txlane_sof_rst_n,
    rxlane_sof_rst_n => rxlane_sof_rst_n,
    wtchdg_clr => wtchdg_clr,
    hsst_ch_ready => hsst_ch_ready,
    P_L0TXN => P_L0TXN,
    P_L0TXP => P_L0TXP,
    P_L0RXN => P_L0RXN,
    P_L0RXP => P_L0RXP,
    l0_signal_loss => l0_signal_loss,
    l0_cdr_align => l0_cdr_align,
    l0_tx_pll_lock => l0_tx_pll_lock,
    l0_lsm_synced => l0_lsm_synced,
    l0_pcs_nearend_loop => l0_pcs_nearend_loop,
    l0_pcs_farend_loop => l0_pcs_farend_loop,
    l0_pma_nearend_ploop => l0_pma_nearend_ploop,
    l0_pma_nearend_sloop => l0_pma_nearend_sloop,
    p0_AN_CS => p0_AN_CS,
    p0_AN_NS => p0_AN_NS,
    p0_RS_CS => p0_RS_CS,
    p0_RS_NS => p0_RS_NS,
    p0_TS_CS => p0_TS_CS,
    p0_TS_NS => p0_TS_NS,
    p0_xmit => p0_xmit,
    p0_rx_unitdata_indicate => p0_rx_unitdata_indicate,
    p1_AN_CS => p1_AN_CS,
    p1_AN_NS => p1_AN_NS,
    p1_RS_CS => p1_RS_CS,
    p1_RS_NS => p1_RS_NS,
    p1_TS_CS => p1_TS_CS,
    p1_TS_NS => p1_TS_NS,
    p1_xmit => p1_xmit,
    p1_rx_unitdata_indicate => p1_rx_unitdata_indicate,
    p2_AN_CS => p2_AN_CS,
    p2_AN_NS => p2_AN_NS,
    p2_RS_CS => p2_RS_CS,
    p2_RS_NS => p2_RS_NS,
    p2_TS_CS => p2_TS_CS,
    p2_TS_NS => p2_TS_NS,
    p2_xmit => p2_xmit,
    p2_rx_unitdata_indicate => p2_rx_unitdata_indicate,
    p3_AN_CS => p3_AN_CS,
    p3_AN_NS => p3_AN_NS,
    p3_RS_CS => p3_RS_CS,
    p3_RS_NS => p3_RS_NS,
    p3_TS_CS => p3_TS_CS,
    p3_TS_NS => p3_TS_NS,
    p3_xmit => p3_xmit,
    p3_rx_unitdata_indicate => p3_rx_unitdata_indicate,
    l0_pcs_clk => l0_pcs_clk,
    l0_pcs_rx_clk => l0_pcs_rx_clk,
    l0_pcs_rxk => l0_pcs_rxk,
    l0_pcs_rdispdec_er => l0_pcs_rdispdec_er,
    l0_pcs_rxd => l0_pcs_rxd,
    l0_pcs_txk => l0_pcs_txk,
    l0_pcs_tx_dispctrl => l0_pcs_tx_dispctrl,
    l0_pcs_tx_dispsel => l0_pcs_tx_dispsel,
    l0_pcs_txd => l0_pcs_txd,
    p0_status_vector => p0_status_vector,
    p0_pin_cfg_en => p0_pin_cfg_en,
    p0_phy_link => p0_phy_link,
    p0_phy_duplex => p0_phy_duplex,
    p0_phy_speed => p0_phy_speed,
    p0_unidir_en => p0_unidir_en,
    p0_an_restart => p0_an_restart,
    p0_an_enable => p0_an_enable,
    p0_loopback => p0_loopback,
    p1_status_vector => p1_status_vector,
    p1_pin_cfg_en => p1_pin_cfg_en,
    p1_phy_link => p1_phy_link,
    p1_phy_duplex => p1_phy_duplex,
    p1_phy_speed => p1_phy_speed,
    p1_unidir_en => p1_unidir_en,
    p1_an_restart => p1_an_restart,
    p1_an_enable => p1_an_enable,
    p1_loopback => p1_loopback,
    p2_status_vector => p2_status_vector,
    p2_pin_cfg_en => p2_pin_cfg_en,
    p2_phy_link => p2_phy_link,
    p2_phy_duplex => p2_phy_duplex,
    p2_phy_speed => p2_phy_speed,
    p2_unidir_en => p2_unidir_en,
    p2_an_restart => p2_an_restart,
    p2_an_enable => p2_an_enable,
    p2_loopback => p2_loopback,
    p3_status_vector => p3_status_vector,
    p3_pin_cfg_en => p3_pin_cfg_en,
    p3_phy_link => p3_phy_link,
    p3_phy_duplex => p3_phy_duplex,
    p3_phy_speed => p3_phy_speed,
    p3_unidir_en => p3_unidir_en,
    p3_an_restart => p3_an_restart,
    p3_an_enable => p3_an_enable,
    p3_loopback => p3_loopback
  );
