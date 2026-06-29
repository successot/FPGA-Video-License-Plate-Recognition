
/////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2014 PANGO MICROSYSTEMS, INC
// ALL RIGHTS REVERVED.
//
// THE SOURCE CODE CONTAINED HEREIN IS PROPRIETARY TO PANGO MICROSYSTEMS, INC.
// IT SHALL NOT BE REPRODUCED OR DISCLOSED IN WHOLE OR IN PART OR USED BY
// PARTIES WITHOUT WRITTEN AUTHORIZATION FROM THE OWNER.
//
//////////////////////////////////////////////////////////////////////////////
// Functional description: pango_qsgmii_top_tb

`timescale 1ps/100fs
module ipsxb_qsgmii_dut_sim_top();

reg                     u1_P_REFCKN            ;
reg                     u1_P_REFCKP            ;

wire                    u1_P_L0TXN             ;
wire                    u1_P_L0TXP             ;
wire                    u1_P_L0RXN             ;
wire                    u1_P_L0RXP             ;

reg                     u2_P_REFCKN            ;
reg                     u2_P_REFCKP            ;

wire                    u2_P_L0TXN             ;
wire                    u2_P_L0TXP             ;
wire                    u2_P_L0RXN             ;
wire                    u2_P_L0RXP             ;

reg                     u1_free_clk            ;
wire                    u1_external_rstn       ;
wire                    u1_p0_soft_rstn        ;
wire                    u1_p1_soft_rstn        ;
wire                    u1_p2_soft_rstn        ;
wire                    u1_p3_soft_rstn        ;
wire                    u2_p0_soft_rstn        ;
wire                    u2_p1_soft_rstn        ;
wire                    u2_p2_soft_rstn        ;
wire                    u2_p3_soft_rstn        ;
reg                     u2_free_clk            ;
wire                    u2_external_rstn       ;
wire                    u1_mm_rst_n            ;
wire                    u2_mm_rst_n            ;
wire    [4:0]           u1_p0_phy_addr         ;
wire    [4:0]           u1_p1_phy_addr         ;
wire    [4:0]           u1_p2_phy_addr         ;
wire    [4:0]           u1_p3_phy_addr         ;
wire    [4:0]           u2_p0_phy_addr         ;
wire    [4:0]           u2_p1_phy_addr         ;
wire    [4:0]           u2_p2_phy_addr         ;
wire    [4:0]           u2_p3_phy_addr         ;
wire                    u1_mdio_done           ;
wire    [1:0]           u1_op                  ;
wire    [4:0]           u1_regad               ;
wire    [15:0]          u1_data0               ;
wire                    u1_mdio_load           ;
wire                    u2_mdio_done           ;
wire    [1:0]           u2_op                  ;
wire    [4:0]           u2_regad               ;
wire    [15:0]          u2_data0               ;
wire                    u2_mdio_load           ;
wire                    mdc_clk                ;
wire                    u1_mdi                 ;
wire                    u2_mdi                 ;
wire                    u1_mdo                 ;
wire                    u1_mdo_en              ;
wire    [15:0]          u1_mdio_rd_shift       ;
wire                    u2_mdo                 ;
wire                    u2_mdo_en              ;
wire    [15:0]          u2_mdio_rd_shift       ;
wire                    u1_clk_tx              ;
wire                    u1_clk_rx              ;
wire                    u2_clk_tx              ;
wire                    u2_clk_rx              ;
wire                    u1_pin_cfg_en          ;
wire  [1:0]             u1_phy_speed           ;
wire [4:0]              u1_phy_addr            ;
wire                    u1_phy_duplex          ;
wire                    u1_phy_link            ;
wire                    u1_unidir_en           ;
wire                    u1_an_restart          ;
wire                    u1_an_enable           ;
wire                    u1_loopback            ;
wire [3:0]              u1_pma_nearend_sloop   ;
wire [3:0]              u1_pma_nearend_ploop   ;
wire [3:0]              u1_pcs_farend_loop     ;
wire [3:0]              u1_pcs_nearend_loop    ;
wire                    u1_rg_start_test       ;
wire                    u1_rg_length_cfg_en    ;
wire [18:0]             u1_rg_length_num       ;
wire                    u1_rg_pld_max_sel      ;
wire                    u1_rg_ipg_max_sel      ;
wire                    u1_rg_pre_max_sel      ;
wire                    u1_rg_pre_cfg_en       ;
wire [3:0]              u1_rg_pre_num          ;
wire                    u1_rg_ipg_cfg_en       ;
wire [7:0]              u1_rg_ipg_num          ;
wire                    u1_rg_wtchdg_sof_clr   ;
wire [3:0]              u1_rg_rx_lane_sof_rst_n;
wire [3:0]              u1_rg_tx_lane_sof_rst_n;
wire                    u1_rg_tx_pll_sof_rst_n ;
reg                     u1_rg_hsst_cfg_soft_rstn;
wire                    u1_rg_pkg_send_clr     ;
wire [3:0]              u1_rg_pkg_chk_clr      ;
wire [31:0]             u1_pkg_gen_cnt         ;
wire [31:0]             u1_p0_crc_ok_cnt       ;
wire [31:0]             u1_p1_crc_ok_cnt       ;
wire [31:0]             u1_p2_crc_ok_cnt       ;
wire [31:0]             u1_p3_crc_ok_cnt       ;
wire [31:0]             u1_p0_crc_err_cnt      ;
wire [31:0]             u1_p1_crc_err_cnt      ;
wire [31:0]             u1_p2_crc_err_cnt      ;
wire [31:0]             u1_p3_crc_err_cnt      ;
wire [31:0]             u1_p0_rcving_cnt       ;
wire [31:0]             u1_p1_rcving_cnt       ;
wire [31:0]             u1_p2_rcving_cnt       ;
wire [31:0]             u1_p3_rcving_cnt       ;
wire [15:0]             u1_p0_status_vector    ;
wire [15:0]             u1_p1_status_vector    ;
wire [15:0]             u1_p2_status_vector    ;
wire [15:0]             u1_p3_status_vector    ;
wire                    u1_rdispdec_er         ;
wire                    u1_signal_loss         ;
wire                    u1_cdr_align           ;
wire                    u1_tx_pll_lock         ;
wire                    u1_lsm_synced          ;
wire                    u2_pin_cfg_en          ;
wire [4:0]              u2_phy_addr            ;
wire [1:0]              u2_phy_speed           ;
wire                    u2_phy_duplex          ;
wire                    u2_phy_link            ;
wire                    u2_unidir_en           ;
wire                    u2_an_restart          ;
wire                    u2_an_enable           ;
wire                    u2_loopback            ;
wire [20:0]             u2_link_timer_value    ;
wire [3:0]              u2_pma_nearend_sloop   ;
wire [3:0]              u2_pma_nearend_ploop   ;
wire [3:0]              u2_pcs_farend_loop     ;
wire [3:0]              u2_pcs_nearend_loop    ;
wire                    u2_rg_start_test       ;
wire                    u2_rg_length_cfg_en    ;
wire [18:0]             u2_rg_length_num       ;
wire                    u2_rg_pld_max_sel      ;
wire                    u2_rg_ipg_max_sel      ;
wire                    u2_rg_pre_max_sel      ;
wire                    u2_rg_pre_cfg_en       ;
wire [3:0]              u2_rg_pre_num          ;
wire                    u2_rg_ipg_cfg_en       ;
wire [7:0]              u2_rg_ipg_num          ;
wire                    u2_rg_wtchdg_sof_clr   ;
wire [3:0]              u2_rg_rx_lane_sof_rst_n;
wire [3:0]              u2_rg_tx_lane_sof_rst_n;
wire                    u2_rg_tx_pll_sof_rst_n ;
reg                     u2_rg_hsst_cfg_soft_rstn;
wire                    u2_rg_pkg_send_clr     ;
wire [3:0]              u2_rg_pkg_chk_clr      ;
wire [31:0]             u2_pkg_gen_cnt         ;
wire [31:0]             u2_p0_crc_ok_cnt       ;
wire [31:0]             u2_p1_crc_ok_cnt       ;
wire [31:0]             u2_p2_crc_ok_cnt       ;
wire [31:0]             u2_p3_crc_ok_cnt       ;
wire [31:0]             u2_p0_crc_err_cnt      ;
wire [31:0]             u2_p1_crc_err_cnt      ;
wire [31:0]             u2_p2_crc_err_cnt      ;
wire [31:0]             u2_p3_crc_err_cnt      ;
wire [31:0]             u2_p0_rcving_cnt       ;
wire [31:0]             u2_p1_rcving_cnt       ;
wire [31:0]             u2_p2_rcving_cnt       ;
wire [31:0]             u2_p3_rcving_cnt       ;
wire [15:0]             u2_p0_status_vector    ;
wire [15:0]             u2_p1_status_vector    ;
wire [15:0]             u2_p2_status_vector    ;
wire [15:0]             u2_p3_status_vector    ;
wire                    u2_rdispdec_er         ;
wire                    u2_signal_loss         ;
wire                    u2_cdr_align           ;
wire                    u2_tx_pll_lock         ;
wire                    u2_lsm_synced          ;


initial
begin
    u1_rg_hsst_cfg_soft_rstn = 0;
    u2_rg_hsst_cfg_soft_rstn = 0;
    #10000
    u1_rg_hsst_cfg_soft_rstn = 0;
    u2_rg_hsst_cfg_soft_rstn = 0;
    #20000
    u1_rg_hsst_cfg_soft_rstn = 1;
    u2_rg_hsst_cfg_soft_rstn = 1;
end

initial
begin
    u1_P_REFCKN = 1'b0;
    forever #4000.4 u1_P_REFCKN = ~u1_P_REFCKN;
end

initial
begin
    u1_P_REFCKP = 1'b1;
    forever #4000.4 u1_P_REFCKP = ~u1_P_REFCKP;
end

initial
begin
    u2_P_REFCKN = 1'b0;
    forever #3999.6 u2_P_REFCKN = ~u2_P_REFCKN;
end

initial
begin
    u2_P_REFCKP = 1'b1;
    forever #3999.6 u2_P_REFCKP = ~u2_P_REFCKP;
end

// FreeClock
initial
begin
    u1_free_clk = 1'b0;
    forever #10000 u1_free_clk = ~u1_free_clk;
end

initial
begin
    u2_free_clk = 1'b0;
    #200;
    forever #10000 u2_free_clk = ~u2_free_clk;
end

GTP_GRS GRS_INST(
    .GRS_N(1'b1)
    ) ;

assign u1_rg_start_test = u1_p0_status_vector[0] && u1_p1_status_vector[0] && u1_p2_status_vector[0] && u1_p3_status_vector[0];
assign u2_rg_start_test = u2_p0_status_vector[0] && u2_p1_status_vector[0] && u2_p2_status_vector[0] && u2_p3_status_vector[0];


assign u1_P_L0RXN = u2_P_L0TXN;
assign u1_P_L0RXP = u2_P_L0TXP;
assign u2_P_L0RXN = u1_P_L0TXN;
assign u2_P_L0RXP = u1_P_L0TXP;

ipsxb_qsgmii_dut_top_qsgmii_test      U1_ipsxb_qsgmii_dut(
    .P_REFCKN            (u1_P_REFCKN           ),
    .P_REFCKP            (u1_P_REFCKP           ),
    .P_L0TXN             (u1_P_L0TXN            ),
    .P_L0TXP             (u1_P_L0TXP            ),
    .P_L0RXN             (u1_P_L0RXN            ),
    .P_L0RXP             (u1_P_L0RXP            ),
    .free_clk            (u1_free_clk           ),
    .external_rstn       (u1_external_rstn      ),
    .p0_soft_rstn        (u1_p0_soft_rstn       ),
    .p1_soft_rstn        (u1_p1_soft_rstn       ),
    .p2_soft_rstn        (u1_p2_soft_rstn       ),
    .p3_soft_rstn        (u1_p3_soft_rstn       ),
    .clk_tx              (u1_clk_tx             ),
    .clk_rx              (u1_clk_rx             ),
    .tx_rst_n            (                      ),
    .rx_rst_n            (                      ),
//Debug LED
    .ok_led              (                      ),
    .cdr_align           (u1_cdr_align          ),
    .tx_pll_lock         (u1_tx_pll_lock        ),
    .lsm_synced          (u1_lsm_synced         ),
    .an_status           (                      ),
    .cfg_rstn            (                      ),
    .p0_pin_cfg_en       (u1_pin_cfg_en         ),
    .p1_pin_cfg_en       (u1_pin_cfg_en         ),
    .p2_pin_cfg_en       (u1_pin_cfg_en         ),
    .p3_pin_cfg_en       (u1_pin_cfg_en         ),
    .p0_phy_link         (u1_phy_link           ),
    .p1_phy_link         (u1_phy_link           ),
    .p2_phy_link         (u1_phy_link           ),
    .p3_phy_link         (u1_phy_link           ),
    .p0_phy_duplex       (u1_phy_duplex         ),
    .p1_phy_duplex       (u1_phy_duplex         ),
    .p2_phy_duplex       (u1_phy_duplex         ),
    .p3_phy_duplex       (u1_phy_duplex         ),
    .p0_phy_speed        (u1_phy_speed          ),
    .p1_phy_speed        (u1_phy_speed          ),
    .p2_phy_speed        (u1_phy_speed          ),
    .p3_phy_speed        (u1_phy_speed          ),
    .p0_unidir_en        (u1_unidir_en          ),
    .p1_unidir_en        (u1_unidir_en          ),
    .p2_unidir_en        (u1_unidir_en          ),
    .p3_unidir_en        (u1_unidir_en          ),
    .p0_an_restart       (u1_an_restart         ),
    .p1_an_restart       (u1_an_restart         ),
    .p2_an_restart       (u1_an_restart         ),
    .p3_an_restart       (u1_an_restart         ),
    .p0_an_enable        (u1_an_enable          ),
    .p1_an_enable        (u1_an_enable          ),
    .p2_an_enable        (u1_an_enable          ),
    .p3_an_enable        (u1_an_enable          ),
    .p0_loopback         (u1_loopback           ),
    .p1_loopback         (u1_loopback           ),
    .p2_loopback         (u1_loopback           ),
    .p3_loopback         (u1_loopback           ),
    .pma_nearend_sloop   (u1_pma_nearend_sloop  ),
    .pma_nearend_ploop   (u1_pma_nearend_ploop  ),
    .pcs_farend_loop     (u1_pcs_farend_loop    ),
    .pcs_nearend_loop    (u1_pcs_nearend_loop   ),
    .p0_rg_start_test    (u1_rg_start_test      ),
    .p1_rg_start_test    (u1_rg_start_test      ),
    .p2_rg_start_test    (u1_rg_start_test      ),
    .p3_rg_start_test    (u1_rg_start_test      ),
    .p0_rg_length_cfg_en (u1_rg_length_cfg_en   ),
    .p1_rg_length_cfg_en (u1_rg_length_cfg_en   ),
    .p2_rg_length_cfg_en (u1_rg_length_cfg_en   ),
    .p3_rg_length_cfg_en (u1_rg_length_cfg_en   ),
    .p0_rg_length_num    (u1_rg_length_num      ),
    .p1_rg_length_num    (u1_rg_length_num      ),
    .p2_rg_length_num    (u1_rg_length_num      ),
    .p3_rg_length_num    (u1_rg_length_num      ),
    .p0_rg_pld_max_sel   (u1_rg_pld_max_sel     ),
    .p1_rg_pld_max_sel   (u1_rg_pld_max_sel     ),
    .p2_rg_pld_max_sel   (u1_rg_pld_max_sel     ),
    .p3_rg_pld_max_sel   (u1_rg_pld_max_sel     ),
    .p0_rg_ipg_max_sel   (u1_rg_ipg_max_sel     ),
    .p1_rg_ipg_max_sel   (u1_rg_ipg_max_sel     ),
    .p2_rg_ipg_max_sel   (u1_rg_ipg_max_sel     ),
    .p3_rg_ipg_max_sel   (u1_rg_ipg_max_sel     ),
    .p0_rg_pre_max_sel   (u1_rg_pre_max_sel     ),
    .p1_rg_pre_max_sel   (u1_rg_pre_max_sel     ),
    .p2_rg_pre_max_sel   (u1_rg_pre_max_sel     ),
    .p3_rg_pre_max_sel   (u1_rg_pre_max_sel     ),
    .p0_rg_burst_tx_en   (u1_rg_burst_tx_en     ),
    .p1_rg_burst_tx_en   (u1_rg_burst_tx_en     ),
    .p2_rg_burst_tx_en   (u1_rg_burst_tx_en     ),
    .p3_rg_burst_tx_en   (u1_rg_burst_tx_en     ),
    .p0_rg_pre_cfg_en    (u1_rg_pre_cfg_en      ),
    .p1_rg_pre_cfg_en    (u1_rg_pre_cfg_en      ),
    .p2_rg_pre_cfg_en    (u1_rg_pre_cfg_en      ),
    .p3_rg_pre_cfg_en    (u1_rg_pre_cfg_en      ),
    .p0_rg_pre_num       (u1_rg_pre_num         ),
    .p1_rg_pre_num       (u1_rg_pre_num         ),
    .p2_rg_pre_num       (u1_rg_pre_num         ),
    .p3_rg_pre_num       (u1_rg_pre_num         ),
    .p0_rg_ipg_cfg_en    (u1_rg_ipg_cfg_en      ),
    .p1_rg_ipg_cfg_en    (u1_rg_ipg_cfg_en      ),
    .p2_rg_ipg_cfg_en    (u1_rg_ipg_cfg_en      ),
    .p3_rg_ipg_cfg_en    (u1_rg_ipg_cfg_en      ),
    .p0_rg_ipg_num       (u1_rg_ipg_num         ),
    .p1_rg_ipg_num       (u1_rg_ipg_num         ),
    .p2_rg_ipg_num       (u1_rg_ipg_num         ),
    .p3_rg_ipg_num       (u1_rg_ipg_num         ),
    .rg_wtchdg_sof_clr   (u1_rg_wtchdg_sof_clr  ),
    .rg_rx_lane_sof_rst_n(u1_rg_rx_lane_sof_rst_n),
    .rg_tx_lane_sof_rst_n(u1_rg_tx_lane_sof_rst_n),
    .rg_tx_pll_sof_rst_n (u1_rg_tx_pll_sof_rst_n ),
    .rg_hsst_cfg_soft_rstn(u1_rg_hsst_cfg_soft_rstn),
    .p0_rg_pkg_chk_clr   (u1_rg_pkg_chk_clr     ),
    .p1_rg_pkg_chk_clr   (u1_rg_pkg_chk_clr     ),
    .p2_rg_pkg_chk_clr   (u1_rg_pkg_chk_clr     ),
    .p3_rg_pkg_chk_clr   (u1_rg_pkg_chk_clr     ),
    .p0_rg_pkg_send_clr  (u1_rg_pkg_send_clr    ),
    .p1_rg_pkg_send_clr  (u1_rg_pkg_send_clr    ),
    .p2_rg_pkg_send_clr  (u1_rg_pkg_send_clr    ),
    .p3_rg_pkg_send_clr  (u1_rg_pkg_send_clr    ),
    .p0_pkg_gen_cnt      (                      ),
    .p1_pkg_gen_cnt      (                      ),
    .p2_pkg_gen_cnt      (                      ),
    .p3_pkg_gen_cnt      (                      ),
    .p0_crc_ok_cnt       (u1_p0_crc_ok_cnt      ),
    .p1_crc_ok_cnt       (u1_p1_crc_ok_cnt      ),
    .p2_crc_ok_cnt       (u1_p2_crc_ok_cnt      ),
    .p3_crc_ok_cnt       (u1_p3_crc_ok_cnt      ),
    .p0_crc_err_cnt      (                      ),
    .p1_crc_err_cnt      (                      ),
    .p2_crc_err_cnt      (                      ),
    .p3_crc_err_cnt      (                      ),
    .p0_rcving_cnt       (u1_p0_rcving_cnt      ),
    .p1_rcving_cnt       (u1_p1_rcving_cnt      ),
    .p2_rcving_cnt       (u1_p2_rcving_cnt      ),
    .p3_rcving_cnt       (u1_p3_rcving_cnt      ),
    .p0_status_vector    (u1_p0_status_vector   ),
    .p1_status_vector    (u1_p1_status_vector   ),
    .p2_status_vector    (u1_p2_status_vector   ),
    .p3_status_vector    (u1_p3_status_vector   ),
    .rdispdec_er         (u1_rdispdec_er        ),
    .signal_loss         (u1_signal_loss        ),

//APB
    .pclk                (u1_free_clk           ),
    .paddr               (21'b0                 ),
    .pwrite              (1'b0                  ),
    .psel                (1'b0                  ),
    .penable             (1'b0                  ),
    .pwdata              (32'h0                 ),
    .prdata              (                      ),
    .pready              (                      ),
//Debug
    .l0_pcs_txk          (                      ),
    .l0_pcs_txd          (                      ),
    .l0_pcs_rx_clk       (                      ),
    .l0_pcs_rxk          (                      ),
    .l0_pcs_rxd          (                      )
    );

ipsxb_qsgmii_dut_top_qsgmii_test      U2_ipsxb_qsgmii_dut(
    .P_REFCKN            (u2_P_REFCKN           ),
    .P_REFCKP            (u2_P_REFCKP           ),
    .P_L0TXN             (u2_P_L0TXN            ),
    .P_L0TXP             (u2_P_L0TXP            ),
    .P_L0RXN             (u2_P_L0RXN            ),
    .P_L0RXP             (u2_P_L0RXP            ),
    .free_clk            (u2_free_clk           ),
    .external_rstn       (u2_external_rstn      ),
    .p0_soft_rstn        (u2_p0_soft_rstn       ),
    .p1_soft_rstn        (u2_p1_soft_rstn       ),
    .p2_soft_rstn        (u2_p2_soft_rstn       ),
    .p3_soft_rstn        (u2_p3_soft_rstn       ),
    .clk_tx              (u2_clk_tx             ),
    .clk_rx              (u2_clk_rx             ),
    .tx_rst_n            (                      ),
    .rx_rst_n            (                      ),
//Debug LED
    .ok_led              (                      ),
    .cdr_align           (u2_cdr_align          ),
    .tx_pll_lock         (u2_tx_pll_lock        ),
    .lsm_synced          (u2_lsm_synced         ),
    .an_status           (                      ),
    .cfg_rstn            (                      ),
    .p0_pin_cfg_en       (u2_pin_cfg_en         ),
    .p1_pin_cfg_en       (u2_pin_cfg_en         ),
    .p2_pin_cfg_en       (u2_pin_cfg_en         ),
    .p3_pin_cfg_en       (u2_pin_cfg_en         ),
    .p0_phy_link         (u2_phy_link           ),
    .p1_phy_link         (u2_phy_link           ),
    .p2_phy_link         (u2_phy_link           ),
    .p3_phy_link         (u2_phy_link           ),
    .p0_phy_duplex       (u2_phy_duplex         ),
    .p1_phy_duplex       (u2_phy_duplex         ),
    .p2_phy_duplex       (u2_phy_duplex         ),
    .p3_phy_duplex       (u2_phy_duplex         ),
    .p0_phy_speed        (u2_phy_speed          ),
    .p1_phy_speed        (u2_phy_speed          ),
    .p2_phy_speed        (u2_phy_speed          ),
    .p3_phy_speed        (u2_phy_speed          ),
    .p0_unidir_en        (u2_unidir_en          ),
    .p1_unidir_en        (u2_unidir_en          ),
    .p2_unidir_en        (u2_unidir_en          ),
    .p3_unidir_en        (u2_unidir_en          ),
    .p0_an_restart       (u2_an_restart         ),
    .p1_an_restart       (u2_an_restart         ),
    .p2_an_restart       (u2_an_restart         ),
    .p3_an_restart       (u2_an_restart         ),
    .p0_an_enable        (u2_an_enable          ),
    .p1_an_enable        (u2_an_enable          ),
    .p2_an_enable        (u2_an_enable          ),
    .p3_an_enable        (u2_an_enable          ),
    .p0_loopback         (u2_loopback           ),
    .p1_loopback         (u2_loopback           ),
    .p2_loopback         (u2_loopback           ),
    .p3_loopback         (u2_loopback           ),
    .pma_nearend_sloop   (u2_pma_nearend_sloop  ),
    .pma_nearend_ploop   (u2_pma_nearend_ploop  ),
    .pcs_farend_loop     (u2_pcs_farend_loop    ),
    .pcs_nearend_loop    (u2_pcs_nearend_loop   ),
    .p0_rg_start_test    (u2_rg_start_test      ),
    .p1_rg_start_test    (u2_rg_start_test      ),
    .p2_rg_start_test    (u2_rg_start_test      ),
    .p3_rg_start_test    (u2_rg_start_test      ),
    .p0_rg_length_cfg_en (u2_rg_length_cfg_en   ),
    .p1_rg_length_cfg_en (u2_rg_length_cfg_en   ),
    .p2_rg_length_cfg_en (u2_rg_length_cfg_en   ),
    .p3_rg_length_cfg_en (u2_rg_length_cfg_en   ),
    .p0_rg_length_num    (u2_rg_length_num      ),
    .p1_rg_length_num    (u2_rg_length_num      ),
    .p2_rg_length_num    (u2_rg_length_num      ),
    .p3_rg_length_num    (u2_rg_length_num      ),
    .p0_rg_pld_max_sel   (u2_rg_pld_max_sel     ),
    .p1_rg_pld_max_sel   (u2_rg_pld_max_sel     ),
    .p2_rg_pld_max_sel   (u2_rg_pld_max_sel     ),
    .p3_rg_pld_max_sel   (u2_rg_pld_max_sel     ),
    .p0_rg_ipg_max_sel   (u2_rg_ipg_max_sel     ),
    .p1_rg_ipg_max_sel   (u2_rg_ipg_max_sel     ),
    .p2_rg_ipg_max_sel   (u2_rg_ipg_max_sel     ),
    .p3_rg_ipg_max_sel   (u2_rg_ipg_max_sel     ),
    .p0_rg_pre_max_sel   (u2_rg_pre_max_sel     ),
    .p1_rg_pre_max_sel   (u2_rg_pre_max_sel     ),
    .p2_rg_pre_max_sel   (u2_rg_pre_max_sel     ),
    .p3_rg_pre_max_sel   (u2_rg_pre_max_sel     ),
    .p0_rg_burst_tx_en   (u2_rg_burst_tx_en     ),
    .p1_rg_burst_tx_en   (u2_rg_burst_tx_en     ),
    .p2_rg_burst_tx_en   (u2_rg_burst_tx_en     ),
    .p3_rg_burst_tx_en   (u2_rg_burst_tx_en     ),
    .p0_rg_pre_cfg_en    (u2_rg_pre_cfg_en      ),
    .p1_rg_pre_cfg_en    (u2_rg_pre_cfg_en      ),
    .p2_rg_pre_cfg_en    (u2_rg_pre_cfg_en      ),
    .p3_rg_pre_cfg_en    (u2_rg_pre_cfg_en      ),
    .p0_rg_pre_num       (u2_rg_pre_num         ),
    .p1_rg_pre_num       (u2_rg_pre_num         ),
    .p2_rg_pre_num       (u2_rg_pre_num         ),
    .p3_rg_pre_num       (u2_rg_pre_num         ),
    .p0_rg_ipg_cfg_en    (u2_rg_ipg_cfg_en      ),
    .p1_rg_ipg_cfg_en    (u2_rg_ipg_cfg_en      ),
    .p2_rg_ipg_cfg_en    (u2_rg_ipg_cfg_en      ),
    .p3_rg_ipg_cfg_en    (u2_rg_ipg_cfg_en      ),
    .p0_rg_ipg_num       (u2_rg_ipg_num         ),
    .p1_rg_ipg_num       (u2_rg_ipg_num         ),
    .p2_rg_ipg_num       (u2_rg_ipg_num         ),
    .p3_rg_ipg_num       (u2_rg_ipg_num         ),
    .rg_wtchdg_sof_clr   (u2_rg_wtchdg_sof_clr  ),
    .rg_rx_lane_sof_rst_n(u2_rg_rx_lane_sof_rst_n),
    .rg_tx_lane_sof_rst_n(u2_rg_tx_lane_sof_rst_n),
    .rg_tx_pll_sof_rst_n (u2_rg_tx_pll_sof_rst_n ),
    .rg_hsst_cfg_soft_rstn(u2_rg_hsst_cfg_soft_rstn),
    .p0_rg_pkg_chk_clr   (u2_rg_pkg_chk_clr     ),
    .p1_rg_pkg_chk_clr   (u2_rg_pkg_chk_clr     ),
    .p2_rg_pkg_chk_clr   (u2_rg_pkg_chk_clr     ),
    .p3_rg_pkg_chk_clr   (u2_rg_pkg_chk_clr     ),
    .p0_rg_pkg_send_clr  (u2_rg_pkg_send_clr    ),
    .p1_rg_pkg_send_clr  (u2_rg_pkg_send_clr    ),
    .p2_rg_pkg_send_clr  (u2_rg_pkg_send_clr    ),
    .p3_rg_pkg_send_clr  (u2_rg_pkg_send_clr    ),
    .p0_pkg_gen_cnt      (                      ),
    .p1_pkg_gen_cnt      (                      ),
    .p2_pkg_gen_cnt      (                      ),
    .p3_pkg_gen_cnt      (                      ),
    .p0_byte_cnt         (                      ),
    .p1_byte_cnt         (                      ),
    .p2_byte_cnt         (                      ),
    .p3_byte_cnt         (                      ),
    .p0_crc_ok_cnt       (u2_p0_crc_ok_cnt      ),
    .p1_crc_ok_cnt       (u2_p1_crc_ok_cnt      ),
    .p2_crc_ok_cnt       (u2_p2_crc_ok_cnt      ),
    .p3_crc_ok_cnt       (u2_p3_crc_ok_cnt      ),
    .p0_crc_err_cnt      (                      ),
    .p1_crc_err_cnt      (                      ),
    .p2_crc_err_cnt      (                      ),
    .p3_crc_err_cnt      (                      ),
    .p0_rcving_cnt       (u2_p0_rcving_cnt      ),
    .p1_rcving_cnt       (u2_p1_rcving_cnt      ),
    .p2_rcving_cnt       (u2_p2_rcving_cnt      ),
    .p3_rcving_cnt       (u2_p3_rcving_cnt      ),
    .p0_status_vector    (u2_p0_status_vector   ),
    .p1_status_vector    (u2_p1_status_vector   ),
    .p2_status_vector    (u2_p2_status_vector   ),
    .p3_status_vector    (u2_p3_status_vector   ),
    .rdispdec_er         (u2_rdispdec_er        ),
    .signal_loss         (u2_signal_loss        ),

//APB
    .pclk                (u2_free_clk           ),
    .paddr               (21'b0                 ),
    .pwrite              (1'b0                  ),
    .psel                (1'b0                  ),
    .penable             (1'b0                  ),
    .pwdata              (32'h0                 ),
    .prdata              (                      ),
    .pready              (                      ),
//Debug
    .l0_pcs_txk          (                      ),
    .l0_pcs_txd          (                      ),
    .l0_pcs_rx_clk       (                      ),
    .l0_pcs_rxk          (                      ),
    .l0_pcs_rxd          (                      )
    );

endmodule
