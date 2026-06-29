

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
`timescale  1ns/100ps
module ipsxb_qsgmii_core_only_v1_0(
    input  wire        free_clk               ,

    output wire        status_vector          ,
    input  wire        pin_cfg_en             ,
    input  wire        phy_link               ,
    input  wire        phy_duplex             ,
    input  wire [1:0]  phy_speed              ,
    input  wire        unidir_en              ,
    input  wire        an_restart             ,
    input  wire        an_enable              ,
    input  wire        loopback               ,
    output wire        sgmii_clk           ,
    output wire        tx_clk_en           ,
    output wire        tx_rstn_sync        ,

    output wire        gmii_rxd            ,
    output wire        gmii_rx_dv          ,
    output wire        gmii_rx_er          ,
    output wire        receiving           ,
    input  wire [7:0]  gmii_txd               ,
    input  wire        gmii_tx_en             ,
    input  wire        gmii_tx_er             ,
    output wire        transmitting           ,


//SerDes
    output wire        P_L0TXN                ,
    output wire        P_L0TXP                ,
    input  wire        P_L0RXN                ,
    input  wire        P_L0RXP                ,
    input  wire        P_REFCKN               ,
    input  wire        P_REFCKP               ,
    output wire        l0_signal_loss         ,
    output wire        l0_cdr_align           ,
    output wire        l0_tx_pll_lock         ,
    output wire        l0_lsm_synced          ,
    output wire        hsst_ch_ready          ,
    input  wire        txpll_sof_rst_n        ,
    input  wire        hsst_cfg_soft_rstn     ,
    input  wire        txlane_sof_rst_n       ,
    input  wire        rxlane_sof_rst_n       ,
    input  wire        wtchdg_clr             ,
    input  wire        external_rstn          ,
    input  wire        soft_rstn              ,

    output wire        qsgmii_tx_rstn         ,
    output wire        qsgmii_rx_rstn         ,
//Debug
    input  wire        l0_pcs_nearend_loop    ,
    input  wire        l0_pcs_farend_loop     ,
    input  wire        l0_pma_nearend_ploop   ,
    input  wire        l0_pma_nearend_sloop   ,
    output wire [3:0]  l0_pcs_tx_dispctrl     ,
    output wire [3:0]  l0_pcs_tx_dispsel
    );


wire        p0_cfg_rst_n       ;
wire [31:0] p0_prdata          ;
wire        p0_pready          ;


wire        p1_cfg_rst_n       ;
wire [31:0] p1_prdata          ;
wire        p1_pready          ;


wire        p2_cfg_rst_n       ;
wire [31:0] p2_prdata          ;
wire        p2_pready          ;


wire        p3_cfg_rst_n       ;
wire [31:0] p3_prdata          ;
wire        p3_pready          ;

wire        p0_transmitting    ;
wire        p1_transmitting    ;
wire        p2_transmitting    ;
wire        p3_transmitting    ;

wire [18:0] paddr                  ;
wire        pwrite                 ;
wire        psel                   ;
wire        penable                ;
wire [31:0] pwdata                 ;
wire [31:0] prdata                 ;
wire        p_rdata                ;
wire        pready                 ;
wire [15:0] p0_status_vector       ;
wire [15:0] p1_status_vector       ;
wire [15:0] p2_status_vector       ;
wire [15:0] p3_status_vector       ;

wire        p0_tx_clk_en           ;
wire        p0_tx_rstn_sync        ;

assign       paddr = {gmii_txd,gmii_txd,gmii_tx_en,gmii_tx_er};
assign       pwrite = gmii_tx_er;
assign       psel   = gmii_tx_en;
assign       penable = gmii_tx_er;
assign       pwdata  = {4{gmii_txd}};
assign       p_rdata = | prdata;
assign       status_vector = (| p0_status_vector) || (| p1_status_vector) || (| p2_status_vector) || (| p3_status_vector) || p_rdata || pready;
assign       sgmii_clk = p0_sgmii_clk | p1_sgmii_clk | p2_sgmii_clk | p3_sgmii_clk;
assign       tx_clk_en = p0_tx_clk_en | p1_tx_clk_en | p2_tx_clk_en | p3_tx_clk_en;
assign       tx_rstn_sync = p0_tx_rstn_sync | p1_tx_rstn_sync | p2_tx_rstn_sync | p3_tx_rstn_sync;
assign       gmii_rxd = (| p0_gmii_rxd) || (| p1_gmii_rxd) || (| p2_gmii_rxd) || (| p3_gmii_rxd);
assign       gmii_rx_dv = p0_gmii_rx_dv | p1_gmii_rx_dv | p2_gmii_rx_dv | p3_gmii_rx_dv;
assign       gmii_rx_er = p0_gmii_rx_er | p1_gmii_rx_er | p3_gmii_rx_er | p2_gmii_rx_er;
assign       receiving  = p0_receiving | p1_receiving | p2_receiving | p3_receiving;


wire [7:0]  p0_gmii_rxd            ;
wire        p0_gmii_rx_dv          ;
wire        p0_gmii_rx_er          ;
wire        p0_receiving           ;
wire [7:0]  gmii_txd               ;
wire        gmii_tx_en             ;
wire        gmii_tx_er             ;
wire        transmitting           ;
wire        p1_sgmii_clk           ;
wire        p1_tx_clk_en           ;
wire        p1_tx_rstn_sync        ;


wire [7:0]  p1_gmii_rxd            ;
wire        p1_gmii_rx_dv          ;
wire        p1_gmii_rx_er          ;
wire        p1_receiving           ;
wire        p2_sgmii_clk           ;
wire        p2_tx_clk_en           ;
wire        p2_tx_rstn_sync        ;


wire [7:0]  p2_gmii_rxd            ;
wire        p2_gmii_rx_dv          ;
wire        p2_gmii_rx_er          ;
wire        p2_receiving           ;
wire        p3_sgmii_clk           ;
wire        p3_tx_clk_en           ;
wire        p3_tx_rstn_sync        ;


wire [7:0]  p3_gmii_rxd            ;
wire        p3_gmii_rx_dv          ;
wire        p3_gmii_rx_er          ;
wire        p3_receiving           ;

assign transmitting = p0_transmitting | p1_transmitting | p2_transmitting | p3_transmitting;



assign cfg_rst_n = p0_cfg_rst_n | p1_cfg_rst_n | p2_cfg_rst_n | p3_cfg_rst_n;
//assign pready = p0_pready | p1_pready | p2_pready | p3_pready;
assign prdata = p0_prdata || p1_prdata || p2_prdata || p3_prdata;

qsgmii_test    U_qsgmii_test(
//Port0
//MDIO

//APB
    .p0_cfg_rst_n               (p0_cfg_rst_n               ),
    .p0_pclk                    (free_clk                   ),
    .p0_paddr                   (paddr                      ),
    .p0_pwrite                  (pwrite                     ),
    .p0_psel                    (psel                       ),
    .p0_penable                 (penable                    ),
    .p0_pwdata                  (pwdata                     ),
    .p0_prdata                  (p0_prdata                  ),
    .p0_pready                  (p0_pready                  ),
//QSGMII Clock/Clock Enable for client MAC
    .p0_sgmii_clk               (p0_sgmii_clk               ),
    .p0_tx_clken                (p0_tx_clken                ),

//Status Vectors
    .p0_status_vector           (p0_status_vector           ),
//QSGMII Control Bits
    .p0_pin_cfg_en              (pin_cfg_en                 ),
    .p0_phy_link                (phy_link                   ),
    .p0_phy_duplex              (phy_duplex                 ),
    .p0_phy_speed               (phy_speed                  ),
    .p0_unidir_en               (unidir_en                  ),
    .p0_an_restart              (an_restart                 ),
    .p0_an_enable               (an_enable                  ),
    .p0_loopback                (loopback                   ),
//GMII RX
    .p0_gmii_rxd                (p0_gmii_rxd                ),
    .p0_gmii_rx_dv              (p0_gmii_rx_dv              ),
    .p0_gmii_rx_er              (p0_gmii_rx_er              ),
    .p0_receiving               (p0_receiving               ),
//GMII TX
    .p0_gmii_txd                (gmii_txd                   ),
    .p0_gmii_tx_en              (gmii_tx_en                 ),
    .p0_gmii_tx_er              (gmii_tx_er                 ),
    .p0_transmitting            (p0_transmitting            ),
//Port1
//MDIO

//APB
    .p1_cfg_rst_n               (p1_cfg_rst_n               ),
    .p1_pclk                    (free_clk                   ),
    .p1_paddr                   (paddr                      ),
    .p1_pwrite                  (pwrite                     ),
    .p1_psel                    (psel                       ),
    .p1_penable                 (penable                    ),
    .p1_pwdata                  (pwdata                     ),
    .p1_prdata                  (p1_prdata                  ),
    .p1_pready                  (p1_pready                  ),
//QSGMII Clock/Clock Enable for client MAC
    .p1_sgmii_clk               (p1_sgmii_clk               ),
    .p1_tx_clken                (p1_tx_clken                ),

//Status Vectors
    .p1_status_vector           (p1_status_vector           ),
//QSGMII Control Bits
    .p1_pin_cfg_en              (pin_cfg_en                 ),
    .p1_phy_link                (phy_link                   ),
    .p1_phy_duplex              (phy_duplex                 ),
    .p1_phy_speed               (phy_speed                  ),
    .p1_unidir_en               (unidir_en                  ),
    .p1_an_restart              (an_restart                 ),
    .p1_an_enable               (an_enable                  ),
    .p1_loopback                (loopback                   ),
//GMII RX
    .p1_gmii_rxd                (p1_gmii_rxd                ),
    .p1_gmii_rx_dv              (p1_gmii_rx_dv              ),
    .p1_gmii_rx_er              (p1_gmii_rx_er              ),
    .p1_receiving               (p1_receiving               ),
//GMII TX
    .p1_gmii_txd                (gmii_txd                   ),
    .p1_gmii_tx_en              (gmii_tx_en                 ),
    .p1_gmii_tx_er              (gmii_tx_er                 ),
    .p1_transmitting            (p1_transmitting            ),
//Port2
//MDIO

//APB
    .p2_cfg_rst_n               (p2_cfg_rst_n               ),
    .p2_pclk                    (free_clk                   ),
    .p2_paddr                   (paddr                      ),
    .p2_pwrite                  (pwrite                     ),
    .p2_psel                    (psel                       ),
    .p2_penable                 (penable                    ),
    .p2_pwdata                  (pwdata                     ),
    .p2_prdata                  (p2_prdata                  ),
    .p2_pready                  (p2_pready                  ),
//QSGMII Clock/Clock Enable for client MAC
    .p2_sgmii_clk               (p2_sgmii_clk               ),
    .p2_tx_clken                (p2_tx_clken                ),

//Status Vectors
    .p2_status_vector           (p2_status_vector           ),
//QSGMII Control Bits
    .p2_pin_cfg_en              (pin_cfg_en                 ),
    .p2_phy_link                (phy_link                   ),
    .p2_phy_duplex              (phy_duplex                 ),
    .p2_phy_speed               (phy_speed                  ),
    .p2_unidir_en               (unidir_en                  ),
    .p2_an_restart              (an_restart                 ),
    .p2_an_enable               (an_enable                  ),
    .p2_loopback                (loopback                   ),
//GMII RX
    .p2_gmii_rxd                (p2_gmii_rxd                ),
    .p2_gmii_rx_dv              (p2_gmii_rx_dv              ),
    .p2_gmii_rx_er              (p2_gmii_rx_er              ),
    .p2_receiving               (p2_receiving               ),
//GMII TX
    .p2_gmii_txd                (gmii_txd                   ),
    .p2_gmii_tx_en              (gmii_tx_en                 ),
    .p2_gmii_tx_er              (gmii_tx_er                 ),
    .p2_transmitting            (p2_transmitting            ),
//Port3
//MDIO

//APB
    .p3_cfg_rst_n               (p3_cfg_rst_n               ),
    .p3_pclk                    (free_clk                   ),
    .p3_paddr                   (paddr                      ),
    .p3_pwrite                  (pwrite                     ),
    .p3_psel                    (psel                       ),
    .p3_penable                 (penable                    ),
    .p3_pwdata                  (pwdata                     ),
    .p3_prdata                  (p3_prdata                  ),
    .p3_pready                  (p3_pready                  ),
//QSGMII Clock/Clock Enable for client MAC
    .p3_sgmii_clk               (p3_sgmii_clk               ),
    .p3_tx_clken                (p3_tx_clken                ),

//Status Vectors
    .p3_status_vector           (p3_status_vector           ),
//QSGMII Control Bits
    .p3_pin_cfg_en              (pin_cfg_en                 ),
    .p3_phy_link                (phy_link                   ),
    .p3_phy_duplex              (phy_duplex                 ),
    .p3_phy_speed               (phy_speed                  ),
    .p3_unidir_en               (unidir_en                  ),
    .p3_an_restart              (an_restart                 ),
    .p3_an_enable               (an_enable                  ),
    .p3_loopback                (loopback                   ),
//GMII RX
    .p3_gmii_rxd                (p3_gmii_rxd                ),
    .p3_gmii_rx_dv              (p3_gmii_rx_dv              ),
    .p3_gmii_rx_er              (p3_gmii_rx_er              ),
    .p3_receiving               (p3_receiving               ),
//GMII TX
    .p3_gmii_txd                (gmii_txd                   ),
    .p3_gmii_tx_en              (gmii_tx_en                 ),
    .p3_gmii_tx_er              (gmii_tx_er                 ),
    .p3_transmitting            (p3_transmitting            ),
// SerDes output
    .P_L0TXN                    (P_L0TXN                    ),
    .P_L0TXP                    (P_L0TXP                    ),
    .P_L0RXN                    (P_L0RXN                    ),
    .P_L0RXP                    (P_L0RXP                    ),
// HSST Reference Clock
    .P_REFCKN                   (P_REFCKN                   ),
    .P_REFCKP                   (P_REFCKP                   ),
// HSST Status indicators
    .l0_signal_loss             (l0_signal_loss             ),
    .l0_cdr_align               (l0_cdr_align               ),
    .l0_tx_pll_lock             (l0_tx_pll_lock             ),
    .l0_lsm_synced              (l0_lsm_synced              ),
//HSST Resets and HSST Ready
    .hsst_ch_ready              (hsst_ch_ready              ),
    .txpll_sof_rst_n            (txpll_sof_rst_n            ),
    .hsst_cfg_soft_rstn         (hsst_cfg_soft_rstn         ),
    .txlane_sof_rst_n           (txlane_sof_rst_n           ),
    .rxlane_sof_rst_n           ({3'b0,rxlane_sof_rst_n}    ),
    .wtchdg_clr                 (rg_wtchdg_sof_clr          ),
//External reset and free run clk
    .external_rstn              (external_rstn              ),
    .p0_soft_rstn               (soft_rstn                  ),
    .p1_soft_rstn               (soft_rstn                  ),
    .p2_soft_rstn               (soft_rstn                  ),
    .p3_soft_rstn               (soft_rstn                  ),
    .free_clk                   (free_clk                   ),
    .qsgmii_tx_rstn             (qsgmii_tx_rstn             ),
    .qsgmii_rx_rstn             (qsgmii_rx_rstn             ),
//Just for debug
    .l0_pcs_nearend_loop        (l0_pcs_nearend_loop        ),
    .l0_pcs_farend_loop         (l0_pcs_farend_loop         ),
    .l0_pma_nearend_ploop       (l0_pma_nearend_ploop       ),
    .l0_pma_nearend_sloop       (l0_pma_nearend_sloop       ),
    .p0_AN_CS                   (                           ),
    .p0_AN_NS                   (                           ),
    .p0_TS_CS                   (                           ),
    .p0_TS_NS                   (                           ),
    .p0_RS_CS                   (                           ),
    .p0_RS_NS                   (                           ),
    .p0_xmit                    (                           ),
    .p0_rx_unitdata_indicate    (                           ),
    .p1_AN_CS                   (                           ),
    .p1_AN_NS                   (                           ),
    .p1_TS_CS                   (                           ),
    .p1_TS_NS                   (                           ),
    .p1_RS_CS                   (                           ),
    .p1_RS_NS                   (                           ),
    .p1_xmit                    (                           ),
    .p1_rx_unitdata_indicate    (                           ),
    .p2_AN_CS                   (                           ),
    .p2_AN_NS                   (                           ),
    .p2_TS_CS                   (                           ),
    .p2_TS_NS                   (                           ),
    .p2_RS_CS                   (                           ),
    .p2_RS_NS                   (                           ),
    .p2_xmit                    (                           ),
    .p2_rx_unitdata_indicate    (                           ),
    .p3_AN_CS                   (                           ),
    .p3_AN_NS                   (                           ),
    .p3_TS_CS                   (                           ),
    .p3_TS_NS                   (                           ),
    .p3_RS_CS                   (                           ),
    .p3_RS_NS                   (                           ),
    .p3_xmit                    (                           ),
    .p3_rx_unitdata_indicate    (                           ),
    .l0_pcs_rdispdec_er         (                           ),
    .l0_pcs_clk                 (                           ),
    .l0_pcs_rx_clk              (                           ),
    .l0_pcs_rxk                 (                           ),
    .l0_pcs_rxd                 (                           ),
    .l0_pcs_txk                 (                           ),
    .l0_pcs_txd                 (                           ),
    .l0_pcs_tx_dispctrl         (l0_pcs_tx_dispctrl         ),
    .l0_pcs_tx_dispsel          (l0_pcs_tx_dispsel          )

);

endmodule
