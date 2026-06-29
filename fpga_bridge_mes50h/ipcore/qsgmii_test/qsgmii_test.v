
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

module qsgmii_test(
//Port0
    //APB of QGMII Core
    //output wire          p0_cfg_rst_n               ,
    //input  wire          p0_pclk                    ,//free_clk
    //input  wire [18:0]   p0_paddr                   ,
    //input  wire          p0_pwrite                  ,
    //input  wire          p0_psel                    ,
    //input  wire          p0_penable                 ,
    //input  wire [31:0]   p0_pwdata                  ,
    //output wire [31:0]   p0_prdata                  ,
    //output wire          p0_pready                  ,
    //Status Vector
    output wire [15:0]   p0_status_vector           ,
    //QSGMII Control Bits
    input  wire          p0_pin_cfg_en              ,//Fast Config Enable
    input  wire          p0_phy_link                ,//Link: 1=link up, 0=link down
    input  wire          p0_phy_duplex              ,//Duplex mode: 1=full duplex, 0=half duplex
    input  wire [1:0]    p0_phy_speed               ,//11 = Reserved 10=1000Mbps; 01=100Mbps; 00=10Mbps
    input  wire          p0_unidir_en               ,//Unidir Mode Enable
    input  wire          p0_an_restart              ,//Auto_Negotiation Restart
    input  wire          p0_an_enable               ,//Auto_Negotiation Enable
    input  wire          p0_loopback                ,//QSGMII Port Loopback Enable
    //QSGMII Clock/Clock Enable for Client MAC
    output wire          p0_sgmii_clk               ,
    output wire          p0_tx_clken                ,
    output wire          p0_tx_rstn_sync            ,
    output wire          p0_rx_rstn_sync            ,
    //GMII RX
    output wire [7:0]    p0_gmii_rxd                ,
    output wire          p0_gmii_rx_dv              ,
    output wire          p0_gmii_rx_er              ,
    output wire          p0_receiving               ,
    //GMII TX
    input  wire [7:0]    p0_gmii_txd                ,
    input  wire          p0_gmii_tx_en              ,
    input  wire          p0_gmii_tx_er              ,
    output wire          p0_transmitting            ,
//Port1
    //APB of QGMII Core
    //output wire          p1_cfg_rst_n               ,
    //input  wire          p1_pclk                    ,
    //input  wire [18:0]   p1_paddr                   ,
    //input  wire          p1_pwrite                  ,
    //input  wire          p1_psel                    ,
    //input  wire          p1_penable                 ,
    //input  wire [31:0]   p1_pwdata                  ,
    //output wire [31:0]   p1_prdata                  ,
    //output wire          p1_pready                  ,
    //Status Vector
    output wire [15:0]   p1_status_vector           ,
    //QSGMII Control Bits
    input  wire          p1_pin_cfg_en              ,
    input  wire          p1_phy_link                ,
    input  wire          p1_phy_duplex              ,
    input  wire [1:0]    p1_phy_speed               ,
    input  wire          p1_unidir_en               ,
    input  wire          p1_an_restart              ,
    input  wire          p1_an_enable               ,
    input  wire          p1_loopback                ,
    //QSGMII Clock/Clock Enable for Client MAC
    output wire          p1_sgmii_clk               ,
    output wire          p1_tx_clken                ,
    output wire          p1_tx_rstn_sync            ,
    output wire          p1_rx_rstn_sync            ,
    //GMII RX
    output wire [7:0]    p1_gmii_rxd                ,
    output wire          p1_gmii_rx_dv              ,
    output wire          p1_gmii_rx_er              ,
    output wire          p1_receiving               ,
    //GMII TX
    input  wire [7:0]    p1_gmii_txd                ,
    input  wire          p1_gmii_tx_en              ,
    input  wire          p1_gmii_tx_er              ,
    output wire          p1_transmitting            ,
//Port2
    //APB of QGMII Core
    //output wire          p2_cfg_rst_n               ,
    //input  wire          p2_pclk                    ,
    //input  wire [18:0]   p2_paddr                   ,
    //input  wire          p2_pwrite                  ,
    //input  wire          p2_psel                    ,
    //input  wire          p2_penable                 ,
    //input  wire [31:0]   p2_pwdata                  ,
    //output wire [31:0]   p2_prdata                  ,
    //output wire          p2_pready                  ,
    //Status Vector
    output wire [15:0]   p2_status_vector           ,
    //QSGMII Control Bits
    input  wire          p2_pin_cfg_en              ,
    input  wire          p2_phy_link                ,
    input  wire          p2_phy_duplex              ,
    input  wire [1:0]    p2_phy_speed               ,
    input  wire          p2_unidir_en               ,
    input  wire          p2_an_restart              ,
    input  wire          p2_an_enable               ,
    input  wire          p2_loopback                ,
    //QSGMII Clock/Clock Enable for Client MAC
    output wire          p2_sgmii_clk               ,
    output wire          p2_tx_clken                ,
    output wire          p2_tx_rstn_sync            ,
    output wire          p2_rx_rstn_sync            ,
    //GMII RX
    output wire [7:0]    p2_gmii_rxd                ,
    output wire          p2_gmii_rx_dv              ,
    output wire          p2_gmii_rx_er              ,
    output wire          p2_receiving               ,
    //GMII TX
    input  wire [7:0]    p2_gmii_txd                ,
    input  wire          p2_gmii_tx_en              ,
    input  wire          p2_gmii_tx_er              ,
    output wire          p2_transmitting            ,
//Port3
    //APB of QGMII Core
    //output wire          p3_cfg_rst_n               ,
    //input  wire          p3_pclk                    ,
    //input  wire [18:0]   p3_paddr                   ,
    //input  wire          p3_pwrite                  ,
    //input  wire          p3_psel                    ,
    //input  wire          p3_penable                 ,
    //input  wire [31:0]   p3_pwdata                  ,
    //output wire [31:0]   p3_prdata                  ,
    //output wire          p3_pready                  ,
    //Status Vector
    output wire [15:0]   p3_status_vector           ,
    //QSGMII Control Bits
    input  wire          p3_pin_cfg_en              ,
    input  wire          p3_phy_link                ,
    input  wire          p3_phy_duplex              ,
    input  wire [1:0]    p3_phy_speed               ,
    input  wire          p3_unidir_en               ,
    input  wire          p3_an_restart              ,
    input  wire          p3_an_enable               ,
    input  wire          p3_loopback                ,
    //QSGMII Clock/Clock Enable for Client MAC
    output wire          p3_sgmii_clk               ,
    output wire          p3_tx_clken                ,
    output wire          p3_tx_rstn_sync            ,
    output wire          p3_rx_rstn_sync            ,
    //GMII RX
    output wire [7:0]    p3_gmii_rxd                ,
    output wire          p3_gmii_rx_dv              ,
    output wire          p3_gmii_rx_er              ,
    output wire          p3_receiving               ,
    //GMII TX
    input  wire [7:0]    p3_gmii_txd                ,
    input  wire          p3_gmii_tx_en              ,
    input  wire          p3_gmii_tx_er              ,
    output wire          p3_transmitting            ,
//SerDes output
    //output wire          P_L0TXN                    ,
    //output wire          P_L0TXP                    ,
    //input  wire          P_L0RXN                    ,
    //input  wire          P_L0RXP                    ,
    //HSST Reference Clock
    //input  wire          P_REFCKN                   ,
    //input  wire          P_REFCKP                   ,
    //HSST Status indicators
    //output wire          l0_signal_loss             ,
    //output wire          l0_cdr_align               ,
    //output wire          l0_tx_pll_lock             ,
    //output wire          l0_lsm_synced              ,
    //HSST Resets and HSST Ready
    //output wire [3:0]    hsst_ch_ready              ,
    input  wire          txpll_sof_rst_n            ,
    input  wire          hsst_cfg_soft_rstn         ,
    //input  wire          txlane_sof_rst_n           ,
    //input  wire [3:0]    rxlane_sof_rst_n           ,
    //input  wire          wtchdg_clr                 ,
//Reset and free_clk
    input  wire          external_rstn              ,
    input  wire          p0_soft_rstn               ,
    input  wire          p1_soft_rstn               ,
    input  wire          p2_soft_rstn               ,
    input  wire          p3_soft_rstn               ,
    input  wire          free_clk                   ,
    output wire          qsgmii_tx_rstn             ,
    output wire          qsgmii_rx_rstn             ,
//Just for debug
    //input  wire          l0_pcs_nearend_loop        ,
    //input  wire          l0_pcs_farend_loop         ,
    //input  wire          l0_pma_nearend_ploop       ,
    //input  wire          l0_pma_nearend_sloop       ,
    output wire [3:0]    p0_AN_CS                   ,
    output wire [3:0]    p0_AN_NS                   ,
    output wire [4:0]    p0_RS_CS                   ,
    output wire [4:0]    p0_RS_NS                   ,
    output wire [4:0]    p0_TS_CS                   ,
    output wire [4:0]    p0_TS_NS                   ,
    output wire [1:0]    p0_xmit                    ,
    output wire [1:0]    p0_rx_unitdata_indicate    ,//rx_unitdata_indicate  ge_pcs_rx_sm  01:RUDI(INVALID) 10:RUDI(/C/) 11:RUDI(/I/)
    output wire [3:0]    p1_AN_CS                   ,
    output wire [3:0]    p1_AN_NS                   ,
    output wire [4:0]    p1_RS_CS                   ,
    output wire [4:0]    p1_RS_NS                   ,
    output wire [4:0]    p1_TS_CS                   ,
    output wire [4:0]    p1_TS_NS                   ,
    output wire [1:0]    p1_xmit                    ,
    output wire [1:0]    p1_rx_unitdata_indicate    ,
    output wire [3:0]    p2_AN_CS                   ,
    output wire [3:0]    p2_AN_NS                   ,
    output wire [4:0]    p2_RS_CS                   ,
    output wire [4:0]    p2_RS_NS                   ,
    output wire [4:0]    p2_TS_CS                   ,
    output wire [4:0]    p2_TS_NS                   ,
    output wire [1:0]    p2_xmit                    ,
    output wire [1:0]    p2_rx_unitdata_indicate    ,
    output wire [3:0]    p3_AN_CS                   ,
    output wire [3:0]    p3_AN_NS                   ,
    output wire [4:0]    p3_RS_CS                   ,
    output wire [4:0]    p3_RS_NS                   ,
    output wire [4:0]    p3_TS_CS                   ,
    output wire [4:0]    p3_TS_NS                   ,
    output wire [1:0]    p3_xmit                    ,
    output wire [1:0]    p3_rx_unitdata_indicate    ,
    //output wire          l0_pcs_clk                 ,// clk_tx
    //output wire          l0_pcs_rx_clk              ,// clk_rx
    //output wire [3:0]    l0_pcs_rxk                 ,
    output wire          l0_pcs_rdispdec_er         ,
    //output wire [31:0]   l0_pcs_rxd                 ,
    //output wire [3:0]    l0_pcs_txk                 ,
    //output wire [3:0]    l0_pcs_tx_dispctrl         ,
    //output wire [3:0]    l0_pcs_tx_dispsel          ,
    //output wire [31:0]   l0_pcs_txd                 ,
//
    output wire [2:0]    i_loop_dbg_0               ,
    input  wire          o_txlane_done_0            ,
    input  wire          o_rxlane_done_0            ,
    input  wire          o_p_clk2core_tx_0          ,
    input  wire          o_p_clk2core_rx_0          ,
    input  wire          l0_lsm_synced              ,
    output wire          i_p_cfg_psel               ,
    output wire          i_p_cfg_enable             ,
    output wire          i_p_cfg_write              ,
    output wire [15:0]   i_p_cfg_addr               ,
    output wire [7:0]    i_p_cfg_wdata              ,
    input  wire [7:0]    o_p_cfg_rdata              ,
    input  wire          o_p_cfg_ready              ,
    output wire [31:0]   i_txd_0                    ,
    output wire [3:0]    i_tdispsel_0               ,
    output wire [3:0]    i_tdispctrl_0              ,
    output wire [3:0]    i_txk_0                    ,
    input  wire [31:0]   o_rxd_0                    ,
    input  wire [3:0]    o_rdisper_0                ,
    input  wire [3:0]    o_rdecer_0                 ,
    input  wire [3:0]    o_rxk_0                    
);

//****************************************************************************//
//                      Parameter and Define                                  //
//****************************************************************************//
// QSGMII Parameter

localparam L0_AUTO_NEGOTIATION     = "TRUE"; //@IPC bool

localparam L0_MANAGEMENT_INTERFACE = "FALSE"; //@IPC bool

localparam L0_CLOCKING_LOGIC       = "TRUE"; //@IPC bool



//****************************************************************************//
//                      Internal Signal                                       //
//****************************************************************************//

wire          p0_mdo                    ;
wire          p1_mdo                    ;
wire          p2_mdo                    ;
wire          p3_mdo                    ;
wire          p0_mdo_en                 ;
wire          p1_mdo_en                 ;
wire          p2_mdo_en                 ;
wire          p3_mdo_en                 ;
wire          p0_mm_rst_n               ;
wire          p1_mm_rst_n               ;
wire          p2_mm_rst_n               ;
wire          p3_mm_rst_n               ;

//wire          l0_pma_farend_ploop       ;
//wire          l0_signal_detect          ;
//wire          i_pll_rst_0               ;
//wire          i_p_cfg_psel              ;
//wire          i_p_cfg_enable            ;
//wire          i_p_cfg_write             ;
//wire [15:0]   i_p_cfg_addr              ;
//wire [7:0]    i_p_cfg_wdata             ;
//wire [7:0]    o_p_cfg_rdata             ;
//wire          o_p_cfg_ready             ;
//wire [31:0]   i_txd_0                   ;
//wire [3:0]    i_tdispsel_0              ;
//wire [3:0]    i_tdispctrl_0             ;
//wire [3:0]    i_txk_0                   ;
//wire [31:0]   o_rxd_0                   ;
//wire [3:0]    o_rdisper_0               ;
//wire [3:0]    o_rdecer_0                ;
//wire [3:0]    o_rxk_0                   ;
//wire [2:0]    i_loop_dbg_0              ;
//wire          o_pll_done_0              ;
//wire          o_txlane_done_0           ;
//wire          o_rxlane_done_0           ;
//wire          o_p_clk2core_tx_0         ;
//wire          o_p_clk2core_rx_0         ;
//wire          i_p_tx0_clk_fr_core       ;
//wire          i_p_rx0_clk_fr_core       ;


//assign l0_signal_loss       = ~l0_signal_detect;
//assign l0_pma_farend_ploop  = 1'b0;
//assign i_pll_rst_0          = ~( external_rstn & txpll_sof_rst_n );
//assign hsst_ch_ready        = {3'b0,o_rxlane_done_0};
//assign l0_pcs_clk           = o_p_clk2core_tx_0;
//assign l0_pcs_rx_clk        = o_p_clk2core_rx_0;
//assign i_p_tx0_clk_fr_core  = l0_pcs_clk;
//assign i_p_rx0_clk_fr_core  = l0_pcs_rx_clk;
//assign l0_pcs_rxk           = o_rxk_0;
//assign l0_pcs_rxd           = o_rxd_0;
//assign l0_pcs_txk           = i_txk_0;
//assign l0_pcs_txd           = i_txd_0;
//assign l0_pcs_tx_dispctrl   = i_tdispctrl_0;
//assign l0_pcs_tx_dispsel    = i_tdispsel_0;

ipsxb_qsgmii_pcs_core_v1_0_qsgmii_test#(
    .MANAGEMENT_INTERFACE       (L0_MANAGEMENT_INTERFACE    ),//
    .AUTO_NEGOTIATION           (L0_AUTO_NEGOTIATION        ),//
    .CLOCKING_LOGIC             (L0_CLOCKING_LOGIC          ) //
) U_qsgmii_core0(
    .external_rstn              (external_rstn              ),// input             
    .p0_soft_rstn               (p0_soft_rstn               ),// input             
    .p1_soft_rstn               (p1_soft_rstn               ),// input             
    .p2_soft_rstn               (p2_soft_rstn               ),// input             
    .p3_soft_rstn               (p3_soft_rstn               ),// input             
    .qsgmii_tx_rstn             (qsgmii_tx_rstn             ),// output            
    .qsgmii_rx_rstn             (qsgmii_rx_rstn             ),// output            
    .pcs_clk                    (o_p_clk2core_tx_0          ),// input             
    .pcs_rx_clk                 (o_p_clk2core_rx_0          ),// input             
    .i_tx_lane_done             (o_txlane_done_0            ),// input             
    .i_rx_lane_done             (o_rxlane_done_0            ),// input             
    .hsst_cfg_soft_rstn         (hsst_cfg_soft_rstn         ),// input              
//Port0
    .p0_tx_rstn_sync            (p0_tx_rstn_sync            ),// output            
    .p0_rx_rstn_sync            (p0_rx_rstn_sync            ),// output            
    .p0_sgmii_clk               (p0_sgmii_clk               ),// output            
    .p0_tx_clken                (p0_tx_clken                ),// output            
    .p0_mm_rst_n                (p0_mm_rst_n                ),// output                                                      
    .p0_mdc                     (1'b1                       ),// input             
    .p0_mdo                     (p0_mdo                     ),// output            
    .p0_mdi                     (1'b0                       ),// input             
    .p0_mdo_en                  (p0_mdo_en                  ),// output            
    .p0_phy_addr                (5'b0                       ),// input  [4:0]      
    //APB                                                        
    .p0_cfg_rst_n               (                           ),// output         
    .p0_pclk                    (free_clk                   ),// input          
    .p0_paddr                   (19'b0                      ),// input  [18:0]  
    .p0_pwrite                  (1'b0                       ),// input          
    .p0_psel                    (1'b0                       ),// input          
    .p0_penable                 (1'b0                       ),// input          
    .p0_pwdata                  (1'b0                       ),// input  [31:0]  
    .p0_prdata                  (                           ),// output [31:0]  
    .p0_pready                  (                           ),// output         
    //Status Vectors
    .p0_status_vector           (p0_status_vector           ),// output [15:0]     
    //QSGMII Control Bits
    .p0_pin_cfg_en              (p0_pin_cfg_en              ),// input             
    .p0_phy_link                (p0_phy_link                ),// input             
    .p0_phy_duplex              (p0_phy_duplex              ),// input             
    .p0_phy_speed               (p0_phy_speed               ),// input  [1:0]      
    .p0_unidir_en               (p0_unidir_en               ),// input             
    .p0_an_restart              (p0_an_restart              ),// input             
    .p0_an_enable               (p0_an_enable               ),// input             
    .p0_loopback                (p0_loopback                ),// input             
    //GMII RX
    .p0_gmii_rxd                (p0_gmii_rxd                ),// output [7:0]      
    .p0_gmii_rx_dv              (p0_gmii_rx_dv              ),// output            
    .p0_gmii_rx_er              (p0_gmii_rx_er              ),// output            
    .p0_receiving               (p0_receiving               ),// output            
    //GMII TX
    .p0_gmii_txd                (p0_gmii_txd                ),// input  [7:0]      
    .p0_gmii_tx_en              (p0_gmii_tx_en              ),// input             
    .p0_gmii_tx_er              (p0_gmii_tx_er              ),// input             
    .p0_transmitting            (p0_transmitting            ),// output            
//Port1
    .p1_tx_rstn_sync            (p1_tx_rstn_sync            ),//
    .p1_rx_rstn_sync            (p1_rx_rstn_sync            ),//
    .p1_sgmii_clk               (p1_sgmii_clk               ),//
    .p1_tx_clken                (p1_tx_clken                ),//
    .p1_mm_rst_n                (p1_mm_rst_n                ),//
    .p1_mdc                     (1'b1                       ),//
    .p1_mdi                     (1'b0                       ),//
    .p1_mdo                     (p1_mdo                     ),//
    .p1_mdo_en                  (p1_mdo_en                  ),//
    .p1_phy_addr                (5'b0                       ),//
    //APB
    .p1_cfg_rst_n               (                           ),//
    .p1_pclk                    (free_clk                   ),//
    .p1_paddr                   (19'b0                      ),//
    .p1_pwrite                  (1'b0                       ),//
    .p1_psel                    (1'b0                       ),//
    .p1_penable                 (1'b0                       ),//
    .p1_pwdata                  (1'b0                       ),//
    .p1_prdata                  (                           ),//
    .p1_pready                  (                           ),//
    //Status Vectors
    .p1_status_vector           (p1_status_vector           ),//
    //QSGMII Control Bits
    .p1_pin_cfg_en              (p1_pin_cfg_en              ),//
    .p1_phy_link                (p1_phy_link                ),//
    .p1_phy_duplex              (p1_phy_duplex              ),//
    .p1_phy_speed               (p1_phy_speed               ),//
    .p1_unidir_en               (p1_unidir_en               ),//
    .p1_an_restart              (p1_an_restart              ),//
    .p1_an_enable               (p1_an_enable               ),//
    .p1_loopback                (p1_loopback                ),//
    //GMII RX
    .p1_gmii_rxd                (p1_gmii_rxd                ),//
    .p1_gmii_rx_dv              (p1_gmii_rx_dv              ),//
    .p1_gmii_rx_er              (p1_gmii_rx_er              ),//
    .p1_receiving               (p1_receiving               ),//
    //GMII TX
    .p1_gmii_txd                (p1_gmii_txd                ),//
    .p1_gmii_tx_en              (p1_gmii_tx_en              ),//
    .p1_gmii_tx_er              (p1_gmii_tx_er              ),//
    .p1_transmitting            (p1_transmitting            ),//
//Port2
    .p2_tx_rstn_sync            (p2_tx_rstn_sync            ),//
    .p2_rx_rstn_sync            (p2_rx_rstn_sync            ),//
    .p2_sgmii_clk               (p2_sgmii_clk               ),//
    .p2_tx_clken                (p2_tx_clken                ),//
    .p2_mm_rst_n                (p2_mm_rst_n                ),//
    .p2_mdc                     (1'b1                       ),//
    .p2_mdi                     (1'b0                       ),//
    .p2_mdo                     (p2_mdo                     ),//
    .p2_mdo_en                  (p2_mdo_en                  ),//
    .p2_phy_addr                (5'b0                       ),//
    //APB
    .p2_cfg_rst_n               (                           ),//
    .p2_pclk                    (free_clk                   ),//
    .p2_paddr                   (19'b0                      ),//
    .p2_pwrite                  (1'b0                       ),//
    .p2_psel                    (1'b0                       ),//
    .p2_penable                 (1'b0                       ),//
    .p2_pwdata                  (1'b0                       ),//
    .p2_prdata                  (                           ),//
    .p2_pready                  (                           ),//
    //Status Vectors
    .p2_status_vector           (p2_status_vector           ),//
    //QSGMII Control Bits
    .p2_pin_cfg_en              (p2_pin_cfg_en              ),//
    .p2_phy_link                (p2_phy_link                ),//
    .p2_phy_duplex              (p2_phy_duplex              ),//
    .p2_phy_speed               (p2_phy_speed               ),//
    .p2_unidir_en               (p2_unidir_en               ),//
    .p2_an_restart              (p2_an_restart              ),//
    .p2_an_enable               (p2_an_enable               ),//
    .p2_loopback                (p2_loopback                ),//
    //GMII RX
    .p2_gmii_rxd                (p2_gmii_rxd                ),//
    .p2_gmii_rx_dv              (p2_gmii_rx_dv              ),//
    .p2_gmii_rx_er              (p2_gmii_rx_er              ),//
    .p2_receiving               (p2_receiving               ),//
    //GMII TX
    .p2_gmii_txd                (p2_gmii_txd                ),//
    .p2_gmii_tx_en              (p2_gmii_tx_en              ),//
    .p2_gmii_tx_er              (p2_gmii_tx_er              ),//
    .p2_transmitting            (p2_transmitting            ),//
    //Port3
    .p3_tx_rstn_sync            (p3_tx_rstn_sync            ),//
    .p3_rx_rstn_sync            (p3_rx_rstn_sync            ),//
    .p3_sgmii_clk               (p3_sgmii_clk               ),//
    .p3_tx_clken                (p3_tx_clken                ),//
    .p3_mm_rst_n                (p3_mm_rst_n                ),//
    .p3_mdc                     (1'b1                       ),//
    .p3_mdi                     (1'b0                       ),//
    .p3_mdo                     (p3_mdo                     ),//
    .p3_mdo_en                  (p3_mdo_en                  ),//
    .p3_phy_addr                (5'b0                       ),//
    //APB
    .p3_cfg_rst_n               (                           ),//
    .p3_pclk                    (free_clk                   ),//
    .p3_paddr                   (19'b0                      ),//
    .p3_pwrite                  (1'b0                       ),//
    .p3_psel                    (1'b0                       ),//
    .p3_penable                 (1'b0                       ),//
    .p3_pwdata                  (1'b0                       ),//
    .p3_prdata                  (                           ),//
    .p3_pready                  (                           ),//
    //Status Vectors
    .p3_status_vector           (p3_status_vector           ),//
    //QSGMII Control Bits
    .p3_pin_cfg_en              (p3_pin_cfg_en              ),//
    .p3_phy_link                (p3_phy_link                ),//
    .p3_phy_duplex              (p3_phy_duplex              ),//
    .p3_phy_speed               (p3_phy_speed               ),//
    .p3_unidir_en               (p3_unidir_en               ),//
    .p3_an_restart              (p3_an_restart              ),//
    .p3_an_enable               (p3_an_enable               ),//
    .p3_loopback                (p3_loopback                ),//
    //GMII RX
    .p3_gmii_rxd                (p3_gmii_rxd                ),//
    .p3_gmii_rx_dv              (p3_gmii_rx_dv              ),//
    .p3_gmii_rx_er              (p3_gmii_rx_er              ),//
    .p3_receiving               (p3_receiving               ),//
    //GMII TX
    .p3_gmii_txd                (p3_gmii_txd                ),//
    .p3_gmii_tx_en              (p3_gmii_tx_en              ),//
    .p3_gmii_tx_er              (p3_gmii_tx_er              ),//
    .p3_transmitting            (p3_transmitting            ),//
//HSST Signals
    .i_rxk_0                    (o_rxk_0                    ),// input  [3:0]     
    .i_rxd_0                    (o_rxd_0                    ),// input  [31:0]    
    .i_rdisper_0                (o_rdisper_0                ),// input  [3:0]     
    .i_rdecer_0                 (o_rdecer_0                 ),// input  [3:0]     
    .i_p_pcs_lsm_synced_0       (l0_lsm_synced              ),// input            
    .o_txk_0                    (i_txk_0                    ),// output [3:0]     
    .o_txd_0                    (i_txd_0                    ),// output [31:0]    
    .i_tdispctrl_0              (i_tdispctrl_0              ),// output [3:0]     
    .i_tdispsel_0               (i_tdispsel_0               ),// output [3:0]     
    .i_loop_dbg_0               (i_loop_dbg_0               ),// output [2:0]     
    .o_p_cfg_addr               (i_p_cfg_addr               ),// output [15:0]    
    .o_p_cfg_write              (i_p_cfg_write              ),// output           
    .o_p_cfg_psel               (i_p_cfg_psel               ),// output           
    .o_p_cfg_enable             (i_p_cfg_enable             ),// output           
    .o_p_cfg_wdata              (i_p_cfg_wdata              ),// output [7:0]     
    .i_p_cfg_rdata              (o_p_cfg_rdata              ),// input  [7:0]     
    .i_p_cfg_ready              (o_p_cfg_ready              ),// input            
//Debug
    .p0_AN_CS                   (p0_AN_CS                   ),// output [3:0]     
    .p0_AN_NS                   (p0_AN_NS                   ),// output [3:0]     
    .p0_TS_CS                   (p0_TS_CS                   ),// output [4:0]     
    .p0_TS_NS                   (p0_TS_NS                   ),// output [4:0]     
    .p0_RS_CS                   (p0_RS_CS                   ),// output [4:0]     
    .p0_RS_NS                   (p0_RS_NS                   ),// output [4:0]     
    .p0_xmit                    (p0_xmit                    ),// output [1:0]     
    .p0_rx_unitdata_indicate    (p0_rx_unitdata_indicate    ),// output [1:0]     
    .p1_AN_CS                   (p1_AN_CS                   ),// output [3:0]     
    .p1_AN_NS                   (p1_AN_NS                   ),// output [3:0]     
    .p1_TS_CS                   (p1_TS_CS                   ),// output [4:0]     
    .p1_TS_NS                   (p1_TS_NS                   ),// output [4:0]     
    .p1_RS_CS                   (p1_RS_CS                   ),// output [4:0]     
    .p1_RS_NS                   (p1_RS_NS                   ),// output [4:0]     
    .p1_xmit                    (p1_xmit                    ),// output [1:0]     
    .p1_rx_unitdata_indicate    (p1_rx_unitdata_indicate    ),// output [1:0]     
    .p2_AN_CS                   (p2_AN_CS                   ),// output [3:0]     
    .p2_AN_NS                   (p2_AN_NS                   ),// output [3:0]     
    .p2_TS_CS                   (p2_TS_CS                   ),// output [4:0]     
    .p2_TS_NS                   (p2_TS_NS                   ),// output [4:0]     
    .p2_RS_CS                   (p2_RS_CS                   ),// output [4:0]     
    .p2_RS_NS                   (p2_RS_NS                   ),// output [4:0]     
    .p2_xmit                    (p2_xmit                    ),// output [1:0]     
    .p2_rx_unitdata_indicate    (p2_rx_unitdata_indicate    ),// output [1:0]     
    .p3_AN_CS                   (p3_AN_CS                   ),// output [3:0]     
    .p3_AN_NS                   (p3_AN_NS                   ),// output [3:0]     
    .p3_TS_CS                   (p3_TS_CS                   ),// output [4:0]     
    .p3_TS_NS                   (p3_TS_NS                   ),// output [4:0]     
    .p3_RS_CS                   (p3_RS_CS                   ),// output [4:0]     
    .p3_RS_NS                   (p3_RS_NS                   ),// output [4:0]     
    .p3_xmit                    (p3_xmit                    ),// output [1:0]     
    .p3_rx_unitdata_indicate    (p3_rx_unitdata_indicate    ),// output [1:0]     
    .l0_pcs_rdispdec_er         (l0_pcs_rdispdec_er         ) // output           
);
/*
ipmxb_qsgmii_hsst U_hsst_ch0(
    .i_free_clk                 (free_clk                   ),// input          
    .i_pll_rst_0                (i_pll_rst_0                ),// input          
    .i_wtchdg_clr_0             (wtchdg_clr                 ),// input          
    .i_txlane_rst_0             (~txlane_sof_rst_n          ),// input          
    .i_rxlane_rst_0             (~rxlane_sof_rst_n[0]       ),// input          
    .i_hsst_fifo_clr_0          (1'b0                       ),// input          
    .i_pcs_cb_rst_0             (1'b0                       ),// input          
    .i_loop_dbg_0               (i_loop_dbg_0               ),// input  [2:0]   
    .o_wtchdg_st_0              (                           ),// output [1:0]   
    .o_pll_done_0               (                           ),// output         
    .o_txlane_done_0            (o_txlane_done_0            ),// output         
    .o_rxlane_done_0            (o_rxlane_done_0            ),// output         
    .i_p_refckn_0               (P_REFCKN                   ),// input          
    .i_p_refckp_0               (P_REFCKP                   ),// input          
    .o_p_clk2core_tx_0          (o_p_clk2core_tx_0          ),// output         
    .i_p_tx0_clk_fr_core        (i_p_tx0_clk_fr_core        ),// input          
    .o_p_clk2core_rx_0          (o_p_clk2core_rx_0          ),// output         
    .i_p_rx0_clk_fr_core        (i_p_rx0_clk_fr_core        ),// input          
    .o_p_pll_lock_0             (l0_tx_pll_lock             ),// output         
    .o_p_rx_sigdet_sta_0        (l0_signal_detect           ),// output         
    .o_p_lx_cdr_align_0         (l0_cdr_align               ),// output         
    .o_p_pcs_lsm_synced_0       (l0_lsm_synced              ),// output         
    .i_p_pcs_nearend_loop_0     (l0_pcs_nearend_loop        ),// input          
    .i_p_pcs_farend_loop_0      (l0_pcs_farend_loop         ),// input          
    .i_p_pma_nearend_ploop_0    (l0_pma_nearend_ploop       ),// input          
    .i_p_pma_nearend_sloop_0    (l0_pma_nearend_sloop       ),// input          
    .i_p_pma_farend_ploop_0     (l0_pma_farend_ploop        ),// input          
    .i_p_cfg_clk                (p0_pclk                    ),// input          
    .i_p_cfg_rst                (~hsst_cfg_soft_rstn        ),// input          
    .i_p_cfg_psel               (i_p_cfg_psel               ),// input          
    .i_p_cfg_enable             (i_p_cfg_enable             ),// input          
    .i_p_cfg_write              (i_p_cfg_write              ),// input          
    .i_p_cfg_addr               (i_p_cfg_addr               ),// input  [15:0]  
    .i_p_cfg_wdata              (i_p_cfg_wdata              ),// input  [7:0]   
    .o_p_cfg_rdata              (o_p_cfg_rdata              ),// output [7:0]   
    .o_p_cfg_int                (                           ),// output         
    .o_p_cfg_ready              (o_p_cfg_ready              ),// output         
    .i_p_l0rxn                  (P_L0RXN                    ),// input          
    .i_p_l0rxp                  (P_L0RXP                    ),// input          
    .o_p_l0txn                  (P_L0TXN                    ),// output         
    .o_p_l0txp                  (P_L0TXP                    ),// output         
    .i_txd_0                    (i_txd_0                    ),// input  [31:0]  
    .i_tdispsel_0               (i_tdispsel_0               ),// input  [3:0]   
    .i_tdispctrl_0              (i_tdispctrl_0              ),// input  [3:0]   
    .i_txk_0                    (i_txk_0                    ),// input  [3:0]   
    .o_rxstatus_0               (                           ),// output [2:0]   
    .o_rxd_0                    (o_rxd_0                    ),// output [31:0]  
    .o_rdisper_0                (o_rdisper_0                ),// output [3:0]   
    .o_rdecer_0                 (o_rdecer_0                 ),// output [3:0]   
    .o_rxk_0                    (o_rxk_0                    ) // output [3:0]   
);
*/
endmodule
