
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
`timescale 1ns/1ps
module ipsxb_qsgmii_onboard_top(
    input  wire          free_clk                ,
    input  wire          external_rstn           ,
    input  wire          hsst_cfg_soft_rstn      ,

    input  wire          P_REFCKN                ,
    input  wire          P_REFCKP                ,

    output wire          P_L0TXN                 ,
    output wire          P_L0TXP                 ,
    input  wire          P_L0RXN                 ,
    input  wire          P_L0RXP                 ,

    output wire          LED50M1S                ,//LED0
    output wire          LED125M1S               ,//LED1
    output wire          ok_led                  ,//LED2

    output wire          cfg_uart_txd            ,
    input  wire          cfg_uart_rxd            ,

    output wire          uart_rxd_to_partner     ,
    input  wire          uart_txd_from_partner   ,

    output wire          l0_cdr_align            ,//LED3
    output wire          l0_tx_pll_lock          ,//LED4
    output wire          l0_lsm_synced           ,//LED5
    output wire          l0_an_status            ,//LED6


    input  wire          l0_ctrl3                 //board_addr_sel
);

wire                     rst_n                   ;
wire                     main_rst_n              ;
wire                     uart_ctrl_sel           ;
wire                     uart_match              ;
wire                     local_uart_txd          ;
wire                     l0_pcs_rx_clk           ;
wire                     clk_tx                  ;
wire                     clk_rx                  ;

wire [3:0]               pma_nearend_sloop       ;
wire [3:0]               pma_nearend_ploop       ;
wire [3:0]               pcs_farend_loop         ;
wire [3:0]               pcs_nearend_loop        ;
wire                     rg_external_sof_rst_n   ;
wire                     cfg_rstn                ;

//Port0
wire [4:0]               p0_phy_addr             ;
wire                     p0_pin_cfg_en           ;
wire                     p0_phy_duplex           ;
wire                     p0_phy_link             ;
wire                     p0_unidir_en            ;
wire                     p0_an_restart           ;
wire                     p0_an_enable            ;
wire                     p0_loopback             ;
wire [1:0]               p0_phy_speed            ;

wire                     p0_rg_start_test        ;
wire                     p0_rg_length_cfg_en     ;
wire [18:0]              p0_rg_length_num        ;
wire                     p0_rg_pld_max_sel       ;
wire                     p0_rg_ipg_max_sel       ;
wire                     p0_rg_pre_max_sel       ;
wire                     p0_rg_burst_tx_en       ;
wire                     p0_rg_pre_cfg_en        ;
wire [3:0]               p0_rg_pre_num           ;
wire                     p0_rg_ipg_cfg_en        ;
wire [7:0]               p0_rg_ipg_num           ;
wire                     p0_rg_soft_rstn         ;
wire [3:0]               p0_rg_pkg_chk_clr       ;
wire                     p0_rg_pkg_send_clr      ;
wire [31:0]              p0_pkg_gen_cnt          ;
wire [31:0]              p0_crc_ok_cnt           ;
wire [31:0]              p0_crc_err_cnt          ;
wire [31:0]              p0_rcving_cnt           ;
wire [31:0]              p0_byte_cnt             ;
wire [15:0]              p0_status_vector        ;

//Port1
wire [4:0]               p1_phy_addr             ;
wire                     p1_pin_cfg_en           ;
wire                     p1_phy_duplex           ;
wire                     p1_phy_link             ;
wire                     p1_unidir_en            ;
wire                     p1_an_restart           ;
wire                     p1_an_enable            ;
wire                     p1_loopback             ;
wire [1:0]               p1_phy_speed            ;

wire                     p1_rg_start_test        ;
wire                     p1_rg_length_cfg_en     ;
wire [18:0]              p1_rg_length_num        ;
wire                     p1_rg_pld_max_sel       ;
wire                     p1_rg_ipg_max_sel       ;
wire                     p1_rg_pre_max_sel       ;
wire                     p1_rg_burst_tx_en       ;
wire                     p1_rg_pre_cfg_en        ;
wire [3:0]               p1_rg_pre_num           ;
wire                     p1_rg_ipg_cfg_en        ;
wire [7:0]               p1_rg_ipg_num           ;
wire                     p1_rg_soft_rstn         ;
wire [3:0]               p1_rg_pkg_chk_clr       ;
wire                     p1_rg_pkg_send_clr      ;
wire [31:0]              p1_pkg_gen_cnt          ;
wire [31:0]              p1_crc_ok_cnt           ;
wire [31:0]              p1_crc_err_cnt          ;
wire [31:0]              p1_rcving_cnt           ;
wire [31:0]              p1_byte_cnt             ;
wire [15:0]              p1_status_vector        ;

//Port2
wire [4:0]               p2_phy_addr             ;
wire                     p2_pin_cfg_en           ;
wire                     p2_phy_duplex           ;
wire                     p2_phy_link             ;
wire                     p2_unidir_en            ;
wire                     p2_an_restart           ;
wire                     p2_an_enable            ;
wire                     p2_loopback             ;
wire [1:0]               p2_phy_speed            ;

wire                     p2_rg_start_test        ;
wire                     p2_rg_length_cfg_en     ;
wire [18:0]              p2_rg_length_num        ;
wire                     p2_rg_pld_max_sel       ;
wire                     p2_rg_ipg_max_sel       ;
wire                     p2_rg_pre_max_sel       ;
wire                     p2_rg_burst_tx_en       ;
wire                     p2_rg_pre_cfg_en        ;
wire [3:0]               p2_rg_pre_num           ;
wire                     p2_rg_ipg_cfg_en        ;
wire [7:0]               p2_rg_ipg_num           ;
wire                     p2_rg_soft_rstn         ;
wire [3:0]               p2_rg_pkg_chk_clr       ;
wire                     p2_rg_pkg_send_clr      ;
wire [31:0]              p2_pkg_gen_cnt          ;
wire [31:0]              p2_crc_ok_cnt           ;
wire [31:0]              p2_crc_err_cnt          ;
wire [31:0]              p2_rcving_cnt           ;
wire [31:0]              p2_byte_cnt             ;
wire [15:0]              p2_status_vector        ;

//Port3
wire [4:0]               p3_phy_addr             ;
wire                     p3_pin_cfg_en           ;
wire                     p3_phy_duplex           ;
wire                     p3_phy_link             ;
wire                     p3_unidir_en            ;
wire                     p3_an_restart           ;
wire                     p3_an_enable            ;
wire                     p3_loopback             ;
wire [1:0]               p3_phy_speed            ;

wire                     p3_rg_start_test        ;
wire                     p3_rg_length_cfg_en     ;
wire [18:0]              p3_rg_length_num        ;
wire                     p3_rg_pld_max_sel       ;
wire                     p3_rg_ipg_max_sel       ;
wire                     p3_rg_pre_max_sel       ;
wire                     p3_rg_burst_tx_en       ;
wire                     p3_rg_pre_cfg_en        ;
wire [3:0]               p3_rg_pre_num           ;
wire                     p3_rg_ipg_cfg_en        ;
wire [7:0]               p3_rg_ipg_num           ;
wire                     p3_rg_soft_rstn         ;
wire [3:0]               p3_rg_pkg_chk_clr       ;
wire                     p3_rg_pkg_send_clr      ;
wire [31:0]              p3_pkg_gen_cnt          ;
wire [31:0]              p3_crc_ok_cnt           ;
wire [31:0]              p3_crc_err_cnt          ;
wire [31:0]              p3_rcving_cnt           ;
wire [31:0]              p3_byte_cnt             ;
wire [15:0]              p3_status_vector        ;

wire                     rg_wtchdg_sof_clr       ;
wire [3:0]               rg_rx_lane_sof_rst_n    ;
wire [3:0]               rg_tx_lane_sof_rst_n    ;
wire                     rg_tx_pll_sof_rst_n     ;
wire                     rg_hsst_cfg_soft_rstn   ;
wire                     hsst_cfg_rstn           ;
wire                     hsst_cfg_rstn_deb       ;
wire                     rdispdec_er             ;
wire                     signal_loss             ;
wire [3:0]               l0_pcs_txk              ;
wire [3:0]               l0_pcs_rxk              ;
wire [31:0]              l0_pcs_txd              ;
wire [31:0]              l0_pcs_rxd              ;

wire                     qsgmii_psel             ;
wire                     qsgmii_write            ;
wire                     qsgmii_enable           ;
wire [20:0]              qsgmii_addr             ;
wire [31:0]              qsgmii_wdata            ;
wire [31:0]              qsgmii_rdata            ;
wire                     qsgmii_ready            ;

wire                     cfg_psel                ;
wire                     cfg_enable              ;
wire                     cfg_write               ;
wire [31:0]              cfg_addr                ;
wire [31:0]              cfg_wdata               ;
wire [31:0]              cfg_rdata               ;
wire                     cfg_ready               ;

wire [14:0]              hub_tdo                 ;
wire                     drck_o                  ;
wire                     hub_tdi                 ;
wire                     capt_o                  ;
wire [14:0]              conf_sel                ;
wire [4:0]               id_o                    ;
wire                     shift_o                 ;
wire                     debug_clk0              ;
wire                     debug_clk1              ;
wire                     debug_clk2              ;
wire                     debug_clk3              ;
wire [127:0]             debug_sig0              ;
wire [127:0]             debug_sig1              ;
wire [127:0]             debug_sig2              ;
wire [127:0]             debug_sig3              ;


//****************************************************************************//
//                       uart interface switch                                //
//****************************************************************************//

assign uart_rxd_to_partner = cfg_uart_rxd;
assign cfg_uart_txd        = uart_match ? local_uart_txd : uart_txd_from_partner;
//****************************************************************************//
assign main_rst_n = external_rstn & rg_external_sof_rst_n;
assign hsst_cfg_rstn = rg_hsst_cfg_soft_rstn & hsst_cfg_soft_rstn;
assign uart_ctrl_sel = l0_ctrl3;


pgr_uart_ctrl_top_32bit # (
    .CLK_FREQ            (50                       ),
    .FIFO_D              (16                       ),
    .WORD_LEN            (2'b11                    ),
    .PARITY_EN           (1'b0                     ),
    .PARITY_TYPE         (1'b0                     ),
    .STOP_LEN            (1'b0                     ),
    .MODE                (1'b0                     ),
    .AW                  (32                       ),
    .DW                  (32                       ),
    .MDC_DIV             (7'd20                    )
) U_uart_ctrl (
    .rst_n               (rst_n                    ),
    .clk                 (free_clk                 ),
    .uart_ctrl_sel       (uart_ctrl_sel            ),
    .uart_match          (uart_match               ),

    .p_addr              (cfg_addr                 ),
    .p_wdata             (cfg_wdata                ),
    .p_ce                (cfg_psel                 ),
    .p_enable            (cfg_enable               ),
    .p_we                (cfg_write                ),
    .p_rdy               (cfg_ready                ),
    .p_rdata             (cfg_rdata                ),

    .mdc                 (                         ),
    .mdi                 (                         ),
    .mdo                 (                         ),
    .mdo_en              (                         ),

    .txd                 (local_uart_txd           ),
    .rxd                 (cfg_uart_rxd             )
);

ipsxb_qsgmii_reg_slave    U_ipsxb_qsgmii_reg_slave(

//CLK for sync
    .clk_tx                    (clk_tx                   ),
    .clk_rx                    (clk_rx                   ),
    .pcs_rx_clk                (l0_pcs_rx_clk            ),
//APB In
    .cfg_clk                   (free_clk                 ),
    .cfg_rstn                  (rst_n                    ),
    .cfg_psel                  (cfg_psel                 ),
    .cfg_enable                (cfg_enable               ),
    .cfg_write                 (cfg_write                ),
    .cfg_addr                  (cfg_addr                 ),
    .cfg_wdata                 (cfg_wdata                ),
    .cfg_rdata                 (cfg_rdata                ),
    .cfg_ready                 (cfg_ready                ),
//To Core APB
    .qsgmii_psel               (qsgmii_psel              ),
    .qsgmii_write              (qsgmii_write             ),
    .qsgmii_enable             (qsgmii_enable            ),
    .qsgmii_addr               (qsgmii_addr              ),
    .qsgmii_wdata              (qsgmii_wdata             ),
    .qsgmii_rdata              (qsgmii_rdata             ),
    .qsgmii_ready              (qsgmii_ready             ),
//Ctrl Signals
//Port0
    .p0_phy_addr               (p0_phy_addr              ),
    .p0_pin_cfg_en             (p0_pin_cfg_en            ),
    .p0_phy_link               (p0_phy_link              ),
    .p0_phy_duplex             (p0_phy_duplex            ),
    .p0_phy_speed              (p0_phy_speed             ),
    .p0_unidir_en              (p0_unidir_en             ),
    .p0_an_restart             (p0_an_restart            ),
    .p0_an_enable              (p0_an_enable             ),
    .p0_loopback               (p0_loopback              ),
//Port1
    .p1_phy_addr               (p1_phy_addr              ),
    .p1_pin_cfg_en             (p1_pin_cfg_en            ),
    .p1_phy_link               (p1_phy_link              ),
    .p1_phy_duplex             (p1_phy_duplex            ),
    .p1_phy_speed              (p1_phy_speed             ),
    .p1_unidir_en              (p1_unidir_en             ),
    .p1_an_restart             (p1_an_restart            ),
    .p1_an_enable              (p1_an_enable             ),
    .p1_loopback               (p1_loopback              ),
//Port2
    .p2_phy_addr               (p2_phy_addr              ),
    .p2_pin_cfg_en             (p2_pin_cfg_en            ),
    .p2_phy_link               (p2_phy_link              ),
    .p2_phy_duplex             (p2_phy_duplex            ),
    .p2_phy_speed              (p2_phy_speed             ),
    .p2_unidir_en              (p2_unidir_en             ),
    .p2_an_restart             (p2_an_restart            ),
    .p2_an_enable              (p2_an_enable             ),
    .p2_loopback               (p2_loopback              ),
//Port3
    .p3_phy_addr               (p3_phy_addr              ),
    .p3_pin_cfg_en             (p3_pin_cfg_en            ),
    .p3_phy_link               (p3_phy_link              ),
    .p3_phy_duplex             (p3_phy_duplex            ),
    .p3_phy_speed              (p3_phy_speed             ),
    .p3_unidir_en              (p3_unidir_en             ),
    .p3_an_restart             (p3_an_restart            ),
    .p3_an_enable              (p3_an_enable             ),
    .p3_loopback               (p3_loopback              ),

    .pma_nearend_sloop         (pma_nearend_sloop        ),
    .pma_nearend_ploop         (pma_nearend_ploop        ),
    .pcs_farend_loop           (pcs_farend_loop          ),
    .pcs_nearend_loop          (pcs_nearend_loop         ),
    .rg_external_sof_rst_n     (rg_external_sof_rst_n    ),
//Port0
    .p0_rg_soft_rstn           (p0_rg_soft_rstn          ),
    .p0_rg_start_test          (p0_rg_start_test         ),
    .p0_rg_length_cfg_en       (p0_rg_length_cfg_en      ),
    .p0_rg_length_num          (p0_rg_length_num         ),
    .p0_rg_pld_max_sel         (p0_rg_pld_max_sel        ),
    .p0_rg_ipg_max_sel         (p0_rg_ipg_max_sel        ),
    .p0_rg_pre_max_sel         (p0_rg_pre_max_sel        ),
    .p0_rg_burst_tx_en         (p0_rg_burst_tx_en        ),
    .p0_rg_pre_cfg_en          (p0_rg_pre_cfg_en         ),
    .p0_rg_pre_num             (p0_rg_pre_num            ),
    .p0_rg_ipg_cfg_en          (p0_rg_ipg_cfg_en         ),
    .p0_rg_ipg_num             (p0_rg_ipg_num            ),
    .rg_wtchdg_sof_clr         (rg_wtchdg_sof_clr        ),
    .rg_tx_lane_sof_rst_n      (rg_tx_lane_sof_rst_n     ),
    .rg_rx_lane_sof_rst_n      (rg_rx_lane_sof_rst_n     ),
    .rg_tx_pll_sof_rst_n       (rg_tx_pll_sof_rst_n      ),
    .rg_hsst_cfg_soft_rstn     (rg_hsst_cfg_soft_rstn    ),
    .p0_rg_pkg_chk_clr         (p0_rg_pkg_chk_clr        ),
    .p0_rg_pkg_send_clr        (p0_rg_pkg_send_clr       ),
    .p0_pkg_gen_cnt            (p0_pkg_gen_cnt           ),
    .p0_crc_ok_cnt             (p0_crc_ok_cnt            ),
    .p0_crc_err_cnt            (p0_crc_err_cnt           ),
    .p0_rcving_cnt             (p0_rcving_cnt            ),
    .p0_byte_cnt               (p0_byte_cnt              ),
    .p0_status_vector          (p0_status_vector         ),
//Port1
    .p1_rg_soft_rstn           (p1_rg_soft_rstn          ),
    .p1_rg_start_test          (p1_rg_start_test         ),
    .p1_rg_length_cfg_en       (p1_rg_length_cfg_en      ),
    .p1_rg_length_num          (p1_rg_length_num         ),
    .p1_rg_pld_max_sel         (p1_rg_pld_max_sel        ),
    .p1_rg_ipg_max_sel         (p1_rg_ipg_max_sel        ),
    .p1_rg_pre_max_sel         (p1_rg_pre_max_sel        ),
    .p1_rg_burst_tx_en         (p1_rg_burst_tx_en        ),
    .p1_rg_pre_cfg_en          (p1_rg_pre_cfg_en         ),
    .p1_rg_pre_num             (p1_rg_pre_num            ),
    .p1_rg_ipg_cfg_en          (p1_rg_ipg_cfg_en         ),
    .p1_rg_ipg_num             (p1_rg_ipg_num            ),
    .p1_rg_pkg_chk_clr         (p1_rg_pkg_chk_clr        ),
    .p1_rg_pkg_send_clr        (p1_rg_pkg_send_clr       ),
    .p1_pkg_gen_cnt            (p1_pkg_gen_cnt           ),
    .p1_crc_ok_cnt             (p1_crc_ok_cnt            ),
    .p1_crc_err_cnt            (p1_crc_err_cnt           ),
    .p1_rcving_cnt             (p1_rcving_cnt            ),
    .p1_byte_cnt               (p1_byte_cnt              ),
    .p1_status_vector          (p1_status_vector         ),
//Port2
    .p2_rg_soft_rstn           (p2_rg_soft_rstn          ),
    .p2_rg_start_test          (p2_rg_start_test         ),
    .p2_rg_length_cfg_en       (p2_rg_length_cfg_en      ),
    .p2_rg_length_num          (p2_rg_length_num         ),
    .p2_rg_pld_max_sel         (p2_rg_pld_max_sel        ),
    .p2_rg_ipg_max_sel         (p2_rg_ipg_max_sel        ),
    .p2_rg_pre_max_sel         (p2_rg_pre_max_sel        ),
    .p2_rg_burst_tx_en         (p2_rg_burst_tx_en        ),
    .p2_rg_pre_cfg_en          (p2_rg_pre_cfg_en         ),
    .p2_rg_pre_num             (p2_rg_pre_num            ),
    .p2_rg_ipg_cfg_en          (p2_rg_ipg_cfg_en         ),
    .p2_rg_ipg_num             (p2_rg_ipg_num            ),
    .p2_rg_pkg_chk_clr         (p2_rg_pkg_chk_clr        ),
    .p2_rg_pkg_send_clr        (p2_rg_pkg_send_clr       ),
    .p2_pkg_gen_cnt            (p2_pkg_gen_cnt           ),
    .p2_crc_ok_cnt             (p2_crc_ok_cnt            ),
    .p2_crc_err_cnt            (p2_crc_err_cnt           ),
    .p2_rcving_cnt             (p2_rcving_cnt            ),
    .p2_byte_cnt               (p2_byte_cnt              ),
    .p2_status_vector          (p2_status_vector         ),
//Port3
    .p3_rg_soft_rstn           (p3_rg_soft_rstn          ),
    .p3_rg_start_test          (p3_rg_start_test         ),
    .p3_rg_length_cfg_en       (p3_rg_length_cfg_en      ),
    .p3_rg_length_num          (p3_rg_length_num         ),
    .p3_rg_pld_max_sel         (p3_rg_pld_max_sel        ),
    .p3_rg_ipg_max_sel         (p3_rg_ipg_max_sel        ),
    .p3_rg_pre_max_sel         (p3_rg_pre_max_sel        ),
    .p3_rg_burst_tx_en         (p3_rg_burst_tx_en        ),
    .p3_rg_pre_cfg_en          (p3_rg_pre_cfg_en         ),
    .p3_rg_pre_num             (p3_rg_pre_num            ),
    .p3_rg_ipg_cfg_en          (p3_rg_ipg_cfg_en         ),
    .p3_rg_ipg_num             (p3_rg_ipg_num            ),
    .p3_rg_pkg_chk_clr         (p3_rg_pkg_chk_clr        ),
    .p3_rg_pkg_send_clr        (p3_rg_pkg_send_clr       ),
    .p3_pkg_gen_cnt            (p3_pkg_gen_cnt           ),
    .p3_crc_ok_cnt             (p3_crc_ok_cnt            ),
    .p3_crc_err_cnt            (p3_crc_err_cnt           ),
    .p3_rcving_cnt             (p3_rcving_cnt            ),
    .p3_byte_cnt               (p3_byte_cnt              ),
    .p3_status_vector          (p3_status_vector         ),

    .rdispdec_er               (rdispdec_er              ),
    .signal_loss               (signal_loss              ),
    .cdr_align                 (l0_cdr_align             ),
    .tx_pll_lock               (l0_tx_pll_lock           ),
    .lsm_synced                (l0_lsm_synced            )
);

ipsxb_qsgmii_dut_top_qsgmii_test       U_ipsxb_qsgmii_dut(
    .P_REFCKN                  (P_REFCKN              ),
    .P_REFCKP                  (P_REFCKP              ),
    .P_L0TXN                   (P_L0TXN               ),
    .P_L0TXP                   (P_L0TXP               ),
    .P_L0RXN                   (P_L0RXN               ),
    .P_L0RXP                   (P_L0RXP               ),
    .free_clk                  (free_clk              ),
    .external_rstn             (rst_n                 ),
    .p0_soft_rstn              (p0_rg_soft_rstn       ),
    .p1_soft_rstn              (p1_rg_soft_rstn       ),
    .p2_soft_rstn              (p2_rg_soft_rstn       ),
    .p3_soft_rstn              (p3_rg_soft_rstn       ),
    .clk_tx                    (clk_tx                ),
    .clk_rx                    (clk_rx                ),
    .tx_rst_n                  (tx_rst_n              ),
    .rx_rst_n                  (                      ),
//Debug LED
    .ok_led                    (ok_led                ),
    .cdr_align                 (l0_cdr_align          ),
    .tx_pll_lock               (l0_tx_pll_lock        ),
    .lsm_synced                (l0_lsm_synced         ),
    .an_status                 (l0_an_status          ),
    .cfg_rstn                  (cfg_rstn              ),
    .pma_nearend_sloop         (pma_nearend_sloop     ),
    .pma_nearend_ploop         (pma_nearend_ploop     ),
    .pcs_farend_loop           (pcs_farend_loop       ),
    .pcs_nearend_loop          (pcs_nearend_loop      ),
//Port0
    .p0_pin_cfg_en             (p0_pin_cfg_en         ),
    .p0_phy_link               (p0_phy_link           ),
    .p0_phy_duplex             (p0_phy_duplex         ),
    .p0_phy_speed              (p0_phy_speed          ),
    .p0_unidir_en              (p0_unidir_en          ),
    .p0_an_restart             (p0_an_restart         ),
    .p0_an_enable              (p0_an_enable          ),
    .p0_loopback               (p0_loopback           ),
    .p0_rg_start_test          (p0_rg_start_test      ),
    .p0_rg_length_cfg_en       (p0_rg_length_cfg_en   ),
    .p0_rg_length_num          (p0_rg_length_num      ),
    .p0_rg_pld_max_sel         (p0_rg_pld_max_sel     ),
    .p0_rg_ipg_max_sel         (p0_rg_ipg_max_sel     ),
    .p0_rg_pre_max_sel         (p0_rg_pre_max_sel     ),
    .p0_rg_burst_tx_en         (p0_rg_burst_tx_en     ),
    .p0_rg_pre_cfg_en          (p0_rg_pre_cfg_en      ),
    .p0_rg_pre_num             (p0_rg_pre_num         ),
    .p0_rg_ipg_cfg_en          (p0_rg_ipg_cfg_en      ),
    .p0_rg_ipg_num             (p0_rg_ipg_num         ),
    .p0_rg_pkg_chk_clr         (p0_rg_pkg_chk_clr     ),
    .p0_rg_pkg_send_clr        (p0_rg_pkg_send_clr    ),
    .p0_pkg_gen_cnt            (p0_pkg_gen_cnt        ),
    .p0_crc_ok_cnt             (p0_crc_ok_cnt         ),
    .p0_crc_err_cnt            (p0_crc_err_cnt        ),
    .p0_rcving_cnt             (p0_rcving_cnt         ),
    .p0_byte_cnt               (p0_byte_cnt           ),
    .p0_status_vector          (p0_status_vector      ),
//Port1
    .p1_pin_cfg_en             (p1_pin_cfg_en         ),
    .p1_phy_link               (p1_phy_link           ),
    .p1_phy_duplex             (p1_phy_duplex         ),
    .p1_phy_speed              (p1_phy_speed          ),
    .p1_unidir_en              (p1_unidir_en          ),
    .p1_an_restart             (p1_an_restart         ),
    .p1_an_enable              (p1_an_enable          ),
    .p1_loopback               (p1_loopback           ),
    .p1_rg_start_test          (p1_rg_start_test      ),
    .p1_rg_length_cfg_en       (p1_rg_length_cfg_en   ),
    .p1_rg_length_num          (p1_rg_length_num      ),
    .p1_rg_pld_max_sel         (p1_rg_pld_max_sel     ),
    .p1_rg_ipg_max_sel         (p1_rg_ipg_max_sel     ),
    .p1_rg_pre_max_sel         (p1_rg_pre_max_sel     ),
    .p1_rg_burst_tx_en         (p1_rg_burst_tx_en     ),
    .p1_rg_pre_cfg_en          (p1_rg_pre_cfg_en      ),
    .p1_rg_pre_num             (p1_rg_pre_num         ),
    .p1_rg_ipg_cfg_en          (p1_rg_ipg_cfg_en      ),
    .p1_rg_ipg_num             (p1_rg_ipg_num         ),
    .p1_rg_pkg_chk_clr         (p1_rg_pkg_chk_clr     ),
    .p1_rg_pkg_send_clr        (p1_rg_pkg_send_clr    ),
    .p1_pkg_gen_cnt            (p1_pkg_gen_cnt        ),
    .p1_crc_ok_cnt             (p1_crc_ok_cnt         ),
    .p1_crc_err_cnt            (p1_crc_err_cnt        ),
    .p1_rcving_cnt             (p1_rcving_cnt         ),
    .p1_byte_cnt               (p1_byte_cnt           ),
    .p1_status_vector          (p1_status_vector      ),
//Port2
    .p2_pin_cfg_en             (p2_pin_cfg_en         ),
    .p2_phy_link               (p2_phy_link           ),
    .p2_phy_duplex             (p2_phy_duplex         ),
    .p2_phy_speed              (p2_phy_speed          ),
    .p2_unidir_en              (p2_unidir_en          ),
    .p2_an_restart             (p2_an_restart         ),
    .p2_an_enable              (p2_an_enable          ),
    .p2_loopback               (p2_loopback           ),
    .p2_rg_start_test          (p2_rg_start_test      ),
    .p2_rg_length_cfg_en       (p2_rg_length_cfg_en   ),
    .p2_rg_length_num          (p2_rg_length_num      ),
    .p2_rg_pld_max_sel         (p2_rg_pld_max_sel     ),
    .p2_rg_ipg_max_sel         (p2_rg_ipg_max_sel     ),
    .p2_rg_pre_max_sel         (p2_rg_pre_max_sel     ),
    .p2_rg_burst_tx_en         (p2_rg_burst_tx_en     ),
    .p2_rg_pre_cfg_en          (p2_rg_pre_cfg_en      ),
    .p2_rg_pre_num             (p2_rg_pre_num         ),
    .p2_rg_ipg_cfg_en          (p2_rg_ipg_cfg_en      ),
    .p2_rg_ipg_num             (p2_rg_ipg_num         ),
    .p2_rg_pkg_chk_clr         (p2_rg_pkg_chk_clr     ),
    .p2_rg_pkg_send_clr        (p2_rg_pkg_send_clr    ),
    .p2_pkg_gen_cnt            (p2_pkg_gen_cnt        ),
    .p2_crc_ok_cnt             (p2_crc_ok_cnt         ),
    .p2_crc_err_cnt            (p2_crc_err_cnt        ),
    .p2_rcving_cnt             (p2_rcving_cnt         ),
    .p2_byte_cnt               (p2_byte_cnt           ),
    .p2_status_vector          (p2_status_vector      ),
//Port3
    .p3_pin_cfg_en             (p3_pin_cfg_en         ),
    .p3_phy_link               (p3_phy_link           ),
    .p3_phy_duplex             (p3_phy_duplex         ),
    .p3_phy_speed              (p3_phy_speed          ),
    .p3_unidir_en              (p3_unidir_en          ),
    .p3_an_restart             (p3_an_restart         ),
    .p3_an_enable              (p3_an_enable          ),
    .p3_loopback               (p3_loopback           ),
    .p3_rg_start_test          (p3_rg_start_test      ),
    .p3_rg_length_cfg_en       (p3_rg_length_cfg_en   ),
    .p3_rg_length_num          (p3_rg_length_num      ),
    .p3_rg_pld_max_sel         (p3_rg_pld_max_sel     ),
    .p3_rg_ipg_max_sel         (p3_rg_ipg_max_sel     ),
    .p3_rg_pre_max_sel         (p3_rg_pre_max_sel     ),
    .p3_rg_burst_tx_en         (p3_rg_burst_tx_en     ),
    .p3_rg_pre_cfg_en          (p3_rg_pre_cfg_en      ),
    .p3_rg_pre_num             (p3_rg_pre_num         ),
    .p3_rg_ipg_cfg_en          (p3_rg_ipg_cfg_en      ),
    .p3_rg_ipg_num             (p3_rg_ipg_num         ),
    .p3_rg_pkg_chk_clr         (p3_rg_pkg_chk_clr     ),
    .p3_rg_pkg_send_clr        (p3_rg_pkg_send_clr    ),
    .p3_pkg_gen_cnt            (p3_pkg_gen_cnt        ),
    .p3_crc_ok_cnt             (p3_crc_ok_cnt         ),
    .p3_crc_err_cnt            (p3_crc_err_cnt        ),
    .p3_rcving_cnt             (p3_rcving_cnt         ),
    .p3_byte_cnt               (p3_byte_cnt           ),
    .p3_status_vector          (p3_status_vector      ),

    .rg_wtchdg_sof_clr         (rg_wtchdg_sof_clr     ),
    .rg_rx_lane_sof_rst_n      (rg_rx_lane_sof_rst_n  ),
    .rg_tx_lane_sof_rst_n      (rg_tx_lane_sof_rst_n  ),
    .rg_tx_pll_sof_rst_n       (rg_tx_pll_sof_rst_n   ),
    .rg_hsst_cfg_soft_rstn     (hsst_cfg_rstn_deb     ),
    .rdispdec_er               (rdispdec_er           ),
    .signal_loss               (signal_loss           ),

//APB
    .pclk                      (free_clk              ),
    .paddr                     (qsgmii_addr           ),
    .pwrite                    (qsgmii_write          ),
    .psel                      (qsgmii_psel           ),
    .penable                   (qsgmii_enable         ),
    .pwdata                    (qsgmii_wdata          ),
    .prdata                    (qsgmii_rdata          ),
    .pready                    (qsgmii_ready          ),
//Debug
    .l0_pcs_txk                (l0_pcs_txk            ),
    .l0_pcs_txd                (l0_pcs_txd            ),
    .l0_pcs_rx_clk             (l0_pcs_rx_clk         ),
    .l0_pcs_rxk                (l0_pcs_rxk            ),
    .l0_pcs_rxd                (l0_pcs_rxd            )
);

cross_reset_sync  u1_reset_sync (
    // Reset and Clock
    .free_clk_pll            (free_clk          ),
    .external_rstn           (main_rst_n        ),

    .rst_n                   (rst_n             )
);

cross_reset_sync  u2_reset_sync (
    // Reset and Clock
    .free_clk_pll            (free_clk          ),
    .external_rstn           (hsst_cfg_rstn     ),

    .rst_n                   (hsst_cfg_rstn_deb )
);

// Debug
clock_chk   u1_clock_chk (
    // Reset and Clock
    .clk1                    (free_clk          ),
    .clk2                    (clk_tx            ),
    .rst1_n                  (cfg_rstn          ),
    .rst2_n                  (tx_rst_n          ),

    .LED50M1S                (LED50M1S          ),
    .LED125M1S               (LED125M1S         )
);
/*********************************************DEBUG**********************************************************/

assign debug_clk0 = clk_tx;
assign debug_clk1 = clk_tx;
assign debug_clk2 = clk_rx;
assign debug_clk3 = l0_pcs_rx_clk;

assign debug_sig0 = {p3_pkg_gen_cnt[31:0],
                     p2_pkg_gen_cnt[31:0],
                     p1_pkg_gen_cnt[31:0],
                     p0_pkg_gen_cnt[31:0]
                     };
assign debug_sig1 = {88'h0,
                     4'b0,l0_pcs_txk,
                     l0_pcs_txd[31:0]
                     };
assign debug_sig2 = {p3_crc_ok_cnt[31:0],
                     p2_crc_ok_cnt[31:0],
                     p1_crc_ok_cnt[31:0],
                     p0_crc_ok_cnt[31:0]
                     };
assign debug_sig3 = {72'h0,
                     4'h0,l0_pcs_rxk,
                     l0_pcs_rxd[31:0],
                     7'h0,rdispdec_er,
                     7'h0,signal_loss
                     };

jtag_hub jhub(
    .resetn_i        (1'b1              ),
    .hub_tdo         (hub_tdo           ),
    .shift_o         (shift_o           ),
    .drck_o          (drck_o            ),
    .hub_tdi         (hub_tdi           ),
    .capt_o          (capt_o            ),
    .conf_sel        (conf_sel          ),
    .id_o            (id_o              )
);

debug_core debug_core0(
    .drck_in         (drck_o            ),
    .hub_tdi         (hub_tdi           ),
    .id_i            (id_o              ),
    .capt_i          (capt_o            ),
    .conf_sel        (conf_sel[0]       ),
    .clk             (debug_clk0        ),
    .trig0_i         (debug_sig0        ),
    .resetn_i        (1'b1              ),
    .shift_i         (shift_o           ),
    .hub_tdo         (hub_tdo[0]        )
);

debug_core debug_core1(
    .drck_in         (drck_o            ),
    .hub_tdi         (hub_tdi           ),
    .id_i            (id_o              ),
    .capt_i          (capt_o            ),
    .conf_sel        (conf_sel[1]       ),
    .clk             (debug_clk1        ),
    .trig0_i         (debug_sig1        ),
    .resetn_i        (1'b1              ),
    .shift_i         (shift_o           ),
    .hub_tdo         (hub_tdo[1]        )
);

debug_core debug_core2(
    .drck_in         (drck_o            ),
    .hub_tdi         (hub_tdi           ),
    .id_i            (id_o              ),
    .capt_i          (capt_o            ),
    .conf_sel        (conf_sel[2]       ),
    .clk             (debug_clk2        ),
    .trig0_i         (debug_sig2        ),
    .resetn_i        (1'b1              ),
    .shift_i         (shift_o           ),
    .hub_tdo         (hub_tdo[2]        )
);

debug_core debug_core3(
    .drck_in         (drck_o            ),
    .hub_tdi         (hub_tdi           ),
    .id_i            (id_o              ),
    .capt_i          (capt_o            ),
    .conf_sel        (conf_sel[3]       ),
    .clk             (debug_clk3        ),
    .trig0_i         (debug_sig3        ),
    .resetn_i        (1'b1              ),
    .shift_i         (shift_o           ),
    .hub_tdo         (hub_tdo[3]        )
);

endmodule
