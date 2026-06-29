-- Created by IP Generator (Version 2022.2-SP6.7 build 153067)
-- Instantiation Template
--
-- Insert the following codes into your VHDL file.
--   * Change the_instance_name to your own instance name.
--   * Change the net names in the port map.


COMPONENT hsst_test
  PORT (
    i_free_clk : IN STD_LOGIC;
    i_pll_rst_0 : IN STD_LOGIC;
    i_wtchdg_clr_0 : IN STD_LOGIC;
    o_wtchdg_st_0 : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    o_pll_done_0 : OUT STD_LOGIC;
    o_txlane_done_0 : OUT STD_LOGIC;
    o_txlane_done_1 : OUT STD_LOGIC;
    o_txlane_done_2 : OUT STD_LOGIC;
    o_txlane_done_3 : OUT STD_LOGIC;
    o_rxlane_done_0 : OUT STD_LOGIC;
    o_rxlane_done_1 : OUT STD_LOGIC;
    o_rxlane_done_2 : OUT STD_LOGIC;
    o_rxlane_done_3 : OUT STD_LOGIC;
    i_p_refckn_0 : IN STD_LOGIC;
    i_p_refckp_0 : IN STD_LOGIC;
    o_p_clk2core_tx_0 : OUT STD_LOGIC;
    o_p_clk2core_tx_1 : OUT STD_LOGIC;
    o_p_clk2core_tx_2 : OUT STD_LOGIC;
    o_p_clk2core_tx_3 : OUT STD_LOGIC;
    i_p_tx0_clk_fr_core : IN STD_LOGIC;
    i_p_tx1_clk_fr_core : IN STD_LOGIC;
    i_p_tx2_clk_fr_core : IN STD_LOGIC;
    i_p_tx3_clk_fr_core : IN STD_LOGIC;
    o_p_clk2core_rx_0 : OUT STD_LOGIC;
    o_p_clk2core_rx_1 : OUT STD_LOGIC;
    o_p_clk2core_rx_2 : OUT STD_LOGIC;
    o_p_clk2core_rx_3 : OUT STD_LOGIC;
    i_p_rx0_clk_fr_core : IN STD_LOGIC;
    i_p_rx1_clk_fr_core : IN STD_LOGIC;
    i_p_rx2_clk_fr_core : IN STD_LOGIC;
    i_p_rx3_clk_fr_core : IN STD_LOGIC;
    o_p_pll_lock_0 : OUT STD_LOGIC;
    o_p_rx_sigdet_sta_0 : OUT STD_LOGIC;
    o_p_rx_sigdet_sta_1 : OUT STD_LOGIC;
    o_p_rx_sigdet_sta_2 : OUT STD_LOGIC;
    o_p_rx_sigdet_sta_3 : OUT STD_LOGIC;
    o_p_lx_cdr_align_0 : OUT STD_LOGIC;
    o_p_lx_cdr_align_1 : OUT STD_LOGIC;
    o_p_lx_cdr_align_2 : OUT STD_LOGIC;
    o_p_lx_cdr_align_3 : OUT STD_LOGIC;
    o_p_pcs_lsm_synced_0 : OUT STD_LOGIC;
    o_p_pcs_lsm_synced_1 : OUT STD_LOGIC;
    o_p_pcs_lsm_synced_2 : OUT STD_LOGIC;
    o_p_pcs_lsm_synced_3 : OUT STD_LOGIC;
    i_p_l0rxn : IN STD_LOGIC;
    i_p_l0rxp : IN STD_LOGIC;
    i_p_l1rxn : IN STD_LOGIC;
    i_p_l1rxp : IN STD_LOGIC;
    i_p_l2rxn : IN STD_LOGIC;
    i_p_l2rxp : IN STD_LOGIC;
    i_p_l3rxn : IN STD_LOGIC;
    i_p_l3rxp : IN STD_LOGIC;
    o_p_l0txn : OUT STD_LOGIC;
    o_p_l0txp : OUT STD_LOGIC;
    o_p_l1txn : OUT STD_LOGIC;
    o_p_l1txp : OUT STD_LOGIC;
    o_p_l2txn : OUT STD_LOGIC;
    o_p_l2txp : OUT STD_LOGIC;
    o_p_l3txn : OUT STD_LOGIC;
    o_p_l3txp : OUT STD_LOGIC;
    i_txd_0 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    i_tdispsel_0 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    i_tdispctrl_0 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    i_txk_0 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    i_txd_1 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    i_tdispsel_1 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    i_tdispctrl_1 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    i_txk_1 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    i_txd_2 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    i_tdispsel_2 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    i_tdispctrl_2 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    i_txk_2 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    i_txd_3 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    i_tdispsel_3 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    i_tdispctrl_3 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    i_txk_3 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    o_rxstatus_0 : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    o_rxd_0 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    o_rdisper_0 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    o_rdecer_0 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    o_rxk_0 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    o_rxstatus_1 : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    o_rxd_1 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    o_rdisper_1 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    o_rdecer_1 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    o_rxk_1 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    o_rxstatus_2 : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    o_rxd_2 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    o_rdisper_2 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    o_rdecer_2 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    o_rxk_2 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    o_rxstatus_3 : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    o_rxd_3 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    o_rdisper_3 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    o_rdecer_3 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    o_rxk_3 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
  );
END COMPONENT;


the_instance_name : hsst_test
  PORT MAP (
    i_free_clk => i_free_clk,
    i_pll_rst_0 => i_pll_rst_0,
    i_wtchdg_clr_0 => i_wtchdg_clr_0,
    o_wtchdg_st_0 => o_wtchdg_st_0,
    o_pll_done_0 => o_pll_done_0,
    o_txlane_done_0 => o_txlane_done_0,
    o_txlane_done_1 => o_txlane_done_1,
    o_txlane_done_2 => o_txlane_done_2,
    o_txlane_done_3 => o_txlane_done_3,
    o_rxlane_done_0 => o_rxlane_done_0,
    o_rxlane_done_1 => o_rxlane_done_1,
    o_rxlane_done_2 => o_rxlane_done_2,
    o_rxlane_done_3 => o_rxlane_done_3,
    i_p_refckn_0 => i_p_refckn_0,
    i_p_refckp_0 => i_p_refckp_0,
    o_p_clk2core_tx_0 => o_p_clk2core_tx_0,
    o_p_clk2core_tx_1 => o_p_clk2core_tx_1,
    o_p_clk2core_tx_2 => o_p_clk2core_tx_2,
    o_p_clk2core_tx_3 => o_p_clk2core_tx_3,
    i_p_tx0_clk_fr_core => i_p_tx0_clk_fr_core,
    i_p_tx1_clk_fr_core => i_p_tx1_clk_fr_core,
    i_p_tx2_clk_fr_core => i_p_tx2_clk_fr_core,
    i_p_tx3_clk_fr_core => i_p_tx3_clk_fr_core,
    o_p_clk2core_rx_0 => o_p_clk2core_rx_0,
    o_p_clk2core_rx_1 => o_p_clk2core_rx_1,
    o_p_clk2core_rx_2 => o_p_clk2core_rx_2,
    o_p_clk2core_rx_3 => o_p_clk2core_rx_3,
    i_p_rx0_clk_fr_core => i_p_rx0_clk_fr_core,
    i_p_rx1_clk_fr_core => i_p_rx1_clk_fr_core,
    i_p_rx2_clk_fr_core => i_p_rx2_clk_fr_core,
    i_p_rx3_clk_fr_core => i_p_rx3_clk_fr_core,
    o_p_pll_lock_0 => o_p_pll_lock_0,
    o_p_rx_sigdet_sta_0 => o_p_rx_sigdet_sta_0,
    o_p_rx_sigdet_sta_1 => o_p_rx_sigdet_sta_1,
    o_p_rx_sigdet_sta_2 => o_p_rx_sigdet_sta_2,
    o_p_rx_sigdet_sta_3 => o_p_rx_sigdet_sta_3,
    o_p_lx_cdr_align_0 => o_p_lx_cdr_align_0,
    o_p_lx_cdr_align_1 => o_p_lx_cdr_align_1,
    o_p_lx_cdr_align_2 => o_p_lx_cdr_align_2,
    o_p_lx_cdr_align_3 => o_p_lx_cdr_align_3,
    o_p_pcs_lsm_synced_0 => o_p_pcs_lsm_synced_0,
    o_p_pcs_lsm_synced_1 => o_p_pcs_lsm_synced_1,
    o_p_pcs_lsm_synced_2 => o_p_pcs_lsm_synced_2,
    o_p_pcs_lsm_synced_3 => o_p_pcs_lsm_synced_3,
    i_p_l0rxn => i_p_l0rxn,
    i_p_l0rxp => i_p_l0rxp,
    i_p_l1rxn => i_p_l1rxn,
    i_p_l1rxp => i_p_l1rxp,
    i_p_l2rxn => i_p_l2rxn,
    i_p_l2rxp => i_p_l2rxp,
    i_p_l3rxn => i_p_l3rxn,
    i_p_l3rxp => i_p_l3rxp,
    o_p_l0txn => o_p_l0txn,
    o_p_l0txp => o_p_l0txp,
    o_p_l1txn => o_p_l1txn,
    o_p_l1txp => o_p_l1txp,
    o_p_l2txn => o_p_l2txn,
    o_p_l2txp => o_p_l2txp,
    o_p_l3txn => o_p_l3txn,
    o_p_l3txp => o_p_l3txp,
    i_txd_0 => i_txd_0,
    i_tdispsel_0 => i_tdispsel_0,
    i_tdispctrl_0 => i_tdispctrl_0,
    i_txk_0 => i_txk_0,
    i_txd_1 => i_txd_1,
    i_tdispsel_1 => i_tdispsel_1,
    i_tdispctrl_1 => i_tdispctrl_1,
    i_txk_1 => i_txk_1,
    i_txd_2 => i_txd_2,
    i_tdispsel_2 => i_tdispsel_2,
    i_tdispctrl_2 => i_tdispctrl_2,
    i_txk_2 => i_txk_2,
    i_txd_3 => i_txd_3,
    i_tdispsel_3 => i_tdispsel_3,
    i_tdispctrl_3 => i_tdispctrl_3,
    i_txk_3 => i_txk_3,
    o_rxstatus_0 => o_rxstatus_0,
    o_rxd_0 => o_rxd_0,
    o_rdisper_0 => o_rdisper_0,
    o_rdecer_0 => o_rdecer_0,
    o_rxk_0 => o_rxk_0,
    o_rxstatus_1 => o_rxstatus_1,
    o_rxd_1 => o_rxd_1,
    o_rdisper_1 => o_rdisper_1,
    o_rdecer_1 => o_rdecer_1,
    o_rxk_1 => o_rxk_1,
    o_rxstatus_2 => o_rxstatus_2,
    o_rxd_2 => o_rxd_2,
    o_rdisper_2 => o_rdisper_2,
    o_rdecer_2 => o_rdecer_2,
    o_rxk_2 => o_rxk_2,
    o_rxstatus_3 => o_rxstatus_3,
    o_rxd_3 => o_rxd_3,
    o_rdisper_3 => o_rdisper_3,
    o_rdecer_3 => o_rdecer_3,
    o_rxk_3 => o_rxk_3
  );
