
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
module  ipsxb_sgmii_ge_pcs_core_v1_0_qsgmii_test #(
    parameter MANAGEMENT_INTERFACE ="TRUE",
    parameter AUTO_NEGOTIATION     ="TRUE",
    parameter CLOCKING_LOGIC       ="TRUE",
    parameter CLOCKEN              ="TRUE"
)(

    input  wire         clk_tx                  ,
    input  wire         clk_rx                  ,
    input  wire         mm_rst_n                ,
    input  wire         rx_rst_n                ,
    input  wire         tx_rst_n                ,
    //Management Rregister
    input  wire         mdc                     ,
    input  wire         mdi                     ,
    output wire         mdo                     ,
    output wire         mdo_en                  ,
    input  wire [4:0]   phy_addr                ,
    //Status vectors
    output wire [15:0]  status_vector           ,
    //SGMII Control bits
    input  wire         pin_cfg_en              ,
    input  wire         phy_link                , //Link: 1=link up, 0=link down
    input  wire         phy_duplex              , //Duplex mode: 1=full duplex, 0=half duplex
    input  wire [1:0]   phy_speed               , //11 = Reserved 10=1000Mbps; 01=100Mbps; 00=10Mbps defined by SGMII SPEC
    input  wire [1:0]   phy_remote_fault        ,
    input  wire [1:0]   phy_pause               ,
    input  wire         unidir_en               ,
    input  wire         an_restart              ,
    input  wire         an_enable               ,
    input  wire         loopback                ,
    //GE or SGMII switch
    input  wire         sgmii_mode              ,
    //used as SGMII PHY  control
    input  wire         sgmii_phy_en            , //enable PHY SIDE
    //used  as SGMII MAC  control
    input  wire         sgmii_mac_en            , //enable MAC SIDE
    //AN link_timer configure
    input  wire [20:0]  link_timer_value        , //set link timer 10ms or 1.6ms

    output wire         tx_clken                ,
    output wire         sgmii_clk               ,

    //SGMII LoopBack
    output wire         mr_loopback             ,
    //pcs rx
    output wire [7:0]   gmii_rxd                ,
    output wire         gmii_rx_dv              ,
    output wire         gmii_rx_er              ,
    output wire         receiving               ,
    input  wire         pcs_rxk                 ,
    input  wire         pcs_rdisp_er            ,
    input  wire         pcs_rdec_er             ,
    input  wire [7:0]   pcs_rxd                 ,
    input  wire         pcs_lsm_synced          ,
    input  wire         pcs_rx_clk              ,
    //pcs tx
    input  wire [7:0]   gmii_txd                ,
    input  wire         gmii_tx_en              ,
    input  wire         gmii_tx_er              ,
    output wire         transmitting            ,

    output wire         pcs_tx_clk              ,
    output wire         pcs_txk                 ,
    output wire         pcs_tx_dispctrl         ,
    output wire         pcs_tx_dispsel          ,
    output wire [7:0]   pcs_txd                 ,
    //HSST loopback
    output wire [3:0]   mr_rstfsm_lsm_force     ,
    output wire [3:0]   mr_rstfsm_cdr_force     ,
    output wire [3:0]   mr_rstfsm_los_force     ,
    //apb
    input  wire         pclk                    ,
    input  wire [4:0]   paddr                   ,
    input  wire         pwrite                  ,
    input  wire         psel                    ,
    input  wire         penable                 ,
    input  wire [15:0]  pwdata                  ,
    output wire [15:0]  prdata                  ,
    // just debug
    output wire [3:0]   AN_CS                   ,
    output wire [3:0]   AN_NS                   ,
    output wire [4:0]   RS_CS                   ,
    output wire [4:0]   RS_NS                   ,
    output wire [4:0]   TS_CS                   ,
    output wire [4:0]   TS_NS                   ,
    output wire [1:0]   xmit                    ,
    output wire [1:0]   rx_unitdata_indicate
);

//***********************************************************inner variables**********************************************************************
//miim_slave module variables
wire  [15:0]  paddr_o                 ;
wire          pwrite_o                ;
wire          psel_o                  ;
wire          penable_o               ;
wire  [15:0]  pwdata_o                ;

wire  [4:0]   paddr_i                 ;
wire          pwrite_i                ;
wire          psel_i                  ;
wire          penable_i               ;
wire  [15:0]  pwdata_i                ;
wire  [15:0]  prdata_o                ;

//manage_reg module variables
wire          mr_unidir_en            ; //0.5 Unidirectional enable
wire          mr_unidir_en_txsync     ; //0.5 Unidirectional enable sync
wire          mr_restart_an           ; //0.9 Auto-Negotiation restart
wire  [15:0]  mr_adv_ability          ; //4.15:0 Auto-Negotiation advertisement register
wire  [15:0]  mr_adv_ability_sync     ; //4.15:0 Auto-Negotiation advertisement register
wire          mr_an_enable            ; //0.12 Auto-Negotiation enable
wire          mr_an_enable_txsync     ; //0.12 Auto-Negotiation enable sync
wire          mr_loopback_syn         ; //mr_loopback sync
wire          mr_loopback_rx          ;
wire  [15:0]  mr_lp_adv_ability       ; //5.15:0 AN link partner ability register
wire  [15:0]  mr_lp_adv_ability_mrs   ; //5.15:0 AN link partner ability register sync
wire  [15:0]  mr_np_tx                ; //7.15:0 AN next page transmit register
wire  [15:0]  mr_np_tx_sync           ; //7.15:0 AN next page transmit register
wire          mr_page_rx              ; //6.1 Page received
wire          mr_page_rx_sync         ; //6.1 Page received sync
wire          mr_an_complete          ; //1.5 Auto-Negotiation complete
wire          mr_an_complete_sync     ; //1.5 Auto-Negotiation complete sync
wire          resolve_priority        ;

// ge_pcs_auto_neg module variables
wire  [15:0]  tx_config_reg           ; //ge_pcs_tx_sm
wire  [15:0]  rx_config_reg           ; //ge_pcs_rx_sm
wire          rx_config_flag          ; //ge_pcs_rx_sm
wire  [15:0]  rx_config_reg_txs       ; //ge_pcs_rx_sm
wire          rx_config_flag_txs      ; //ge_pcs_rx_sm
wire          idle_flag               ;
wire          idle_flag_txs           ;
wire          idle_flag_vld           ;
wire  [19:0]  rx_to_auto_sync_in      ;
wire  [19:0]  rx_to_auto_sync_out     ;

wire          pcs_rxk_out             ;
wire  [7:0]   pcs_rxd_out             ;
wire          pcs_rxk_in              ;
wire          pcs_rdispdec_er         ;
wire          pcs_rdispdec_er_in      ;
wire  [7:0]   pcs_rxd_in              ;
wire          pcs_lsm_synced_in       ;
wire          pcs_rdispdec_er_out     ;
wire          pcs_lsm_synced_out      ;
wire          pcs_lsm_synced_rxs      ;
wire          pcs_lsm_synced_pcs_rxs  ;
wire          pcs_lsm_synced_mrs      ;
wire  [1:0]   xmit_rxs                ;
wire          pcs_lsm_synced_txs      ;
//wire  [15:0]  rx_config_reg_txs     ;
wire  [1:0]   rudi_txs                ;
wire          ack_bit_sync            ;

//
wire          auto_en                 ;
wire  [1:0]   sgmii_speed             ;//11 = Reserved 10=1000Mbps;01=100Mbps;00=10Mbps defined by SGMII SPEC
wire  [1:0]   sgmii_speed_rxs         ;//11 = Reserved 10=1000Mbps;01=100Mbps;00=10Mbps defined by SGMII SPEC
wire  [1:0]   sgmii_speed_txs         ;//11 = Reserved 10=1000Mbps;01=100Mbps;00=10Mbps defined by SGMII SPEC
wire  [1:0]   sgmii_speed_rx_rec_s    ;//11 = Reserved 10=1000Mbps;01=100Mbps;00=10Mbps defined by SGMII SPEC
wire          sgmii_duplex            ;//Duplex mode: 1=full duplex,0=half duplex
wire          rxbuferr                ;
wire          rxbuferr_out            ;
wire  [3:0]   min_ipg                 ;
wire  [3:0]   min_ipg_sync            ;

wire          link_status             ;
wire  [1:0]   lp_pause                ;
wire  [1:0]   remote_fault_encode     ;

wire          rx_rec_rst_n            ;
wire          rx_rstn_txs             ;

wire          sgmii_mode_rxs          ;
wire          sgmii_mode_txs          ;

wire          clk_cfg                 ;


//************************************************************main code***************************************************************************

assign  link_status   = mr_an_enable_txsync ? mr_an_complete : pcs_lsm_synced_txs;

assign  status_vector = {resolve_priority     ,
                         mr_an_complete       ,
                         mr_page_rx           ,
                         pcs_rdisp_er         ,
                         pcs_rdec_er          ,
                         remote_fault_encode  ,
                         lp_pause             ,
                         rxbuferr             ,
                         sgmii_duplex         ,
                         sgmii_speed          ,
                         rx_unitdata_indicate ,
                         link_status
                        };

assign  pcs_tx_clk      = clk_tx;
assign  pcs_rdispdec_er = pcs_rdisp_er | pcs_rdec_er;

assign  clk_cfg    = (MANAGEMENT_INTERFACE == "TRUE") ?  mdc          : pclk      ;
assign  paddr_i    = (MANAGEMENT_INTERFACE == "TRUE") ?  paddr_o[4:0] : paddr     ;
assign  pwrite_i   = (MANAGEMENT_INTERFACE == "TRUE") ?  pwrite_o     : pwrite    ;
assign  psel_i     = (MANAGEMENT_INTERFACE == "TRUE") ?  psel_o       : psel      ;
assign  penable_i  = (MANAGEMENT_INTERFACE == "TRUE") ?  penable_o    : penable   ;
assign  pwdata_i   = (MANAGEMENT_INTERFACE == "TRUE") ?  pwdata_o     : pwdata    ;
assign  prdata     = (MANAGEMENT_INTERFACE == "TRUE") ?  16'b0        : prdata_o  ;
assign  auto_en    = (AUTO_NEGOTIATION     == "TRUE") ?  1'b1         : 1'b0      ;

//miim_slave instance
ips_sgmii_miim_slave_v1_9a   U_ips_sgmii_miim_slave    (
    .rst_n               (mm_rst_n            ),
    .mdc                 (mdc                 ),
    .mdi                 (mdi                 ),
    .mdo                 (mdo                 ),
    .mdo_en              (mdo_en              ),
    .device_addr         (                    ),
    .phy_addr            (phy_addr            ),
    .paddr               (paddr_o             ),
    .pwrite              (pwrite_o            ),
    .psel                (psel_o              ),
    .penable             (penable_o           ),
    .pwdata              (pwdata_o            ),
    .prdata              (prdata_o            )
);

ips_sgmii_sync_v1_0 ack_sync         (.clk(clk_cfg), .rst_n(mm_rst_n), .sig_async(tx_config_reg[14]), .sig_synced(ack_bit_sync       ));
ips_sgmii_sync_v1_0 page_rx_sync     (.clk(clk_cfg), .rst_n(mm_rst_n), .sig_async(mr_page_rx       ), .sig_synced(mr_page_rx_sync    ));
ips_sgmii_sync_v1_0 an_complete_sync (.clk(clk_cfg), .rst_n(mm_rst_n), .sig_async(mr_an_complete   ), .sig_synced(mr_an_complete_sync));
ips_sgmii_sync_v1_0 pcs_lsm_mrsync   (.clk(clk_cfg), .rst_n(mm_rst_n), .sig_async(pcs_lsm_synced   ), .sig_synced(pcs_lsm_synced_mrs ));

ips_sgmii_handshake_sync_v1_0 #(
    .DATA_WIDTH         (16                    ),
    .DFT_VALUE          (16'h0800              )
) lp_adv_ability_sync (
    .src_clk            (clk_tx                ),
    .src_rstn           (tx_rst_n              ),
    .src_data           (mr_lp_adv_ability     ),
    .des_clk            (clk_cfg               ),
    .des_rstn           (mm_rst_n              ),
    .des_data           (mr_lp_adv_ability_mrs )
);

//manage_reg instance
ips_sgmii_manage_reg_v1_9  U_ips_sgmii_manage_reg (
    .rst_n              (mm_rst_n              ),
    .clk_mdc            (clk_cfg               ),
    .paddr              (paddr_i               ),
    .pwrite             (pwrite_i              ),
    .psel               (psel_i                ),
    .penable            (penable_i             ),
    .pwdata             (pwdata_i              ),
    .prdata             (prdata_o              ),
     //used  as SGMII PHY
    .sgmii_phy_en       (sgmii_phy_en          ),
    .phy_link           (phy_link              ),
    .phy_duplex         (phy_duplex            ),
    .phy_speed          (phy_speed             ),
    .phy_remote_fault   (phy_remote_fault      ),
    .phy_pause          (phy_pause             ),
     //used  as SGMII
    .sgmii_mac_en       (sgmii_mac_en          ),
     //used  as  1000BASE-X default configuration
    .sgmii_speed        (sgmii_speed           ),
    .sgmii_duplex       (sgmii_duplex          ),
    .sgmii_mode         (sgmii_mode            ),
    //port configuration
    .pin_cfg_en         (pin_cfg_en            ),
    .unidir_en          (unidir_en             ),
    .an_restart         (an_restart            ),
    .an_enable          (an_enable             ),
    .loopback           (loopback              ),
    //to status vector
    .lp_pause           (lp_pause              ),
    .remote_fault_encode (remote_fault_encode  ),

    .pcs_lsm_synced     (pcs_lsm_synced_mrs    ),
    .ack_bit            (ack_bit_sync          ),
    .auto_en            (auto_en               ),

    .min_ipg            (min_ipg               ),
    .mr_rstfsm_lsm_force(mr_rstfsm_lsm_force   ),
    .mr_rstfsm_cdr_force(mr_rstfsm_cdr_force   ),
    .mr_rstfsm_los_force(mr_rstfsm_los_force   ),

    .mr_unidir_en       (mr_unidir_en          ),
    .mr_restart_an      (mr_restart_an         ),
    .mr_adv_ability     (mr_adv_ability        ),
    .mr_an_enable       (mr_an_enable          ),
    .mr_loopback        (mr_loopback           ),
    .mr_lp_adv_ability  (mr_lp_adv_ability_mrs ),
    .mr_np_tx           (mr_np_tx              ),
    .mr_page_rx         (mr_page_rx_sync       ),
    .mr_an_complete     (mr_an_complete_sync   )
);


ips_sgmii_sync_v1_0 mr_restart_an_sync (.clk(clk_tx), .rst_n(tx_rst_n), .sig_async(mr_restart_an), .sig_synced(mr_restart_an_txsync));
ips_sgmii_sync_v1_0 mr_an_enable_sync  (.clk(clk_tx), .rst_n(tx_rst_n), .sig_async(mr_an_enable & auto_en), .sig_synced(mr_an_enable_txsync));
ips_sgmii_sync_v1_0 mr_unidir_en_sync  (.clk(clk_tx), .rst_n(tx_rst_n), .sig_async(mr_unidir_en), .sig_synced(mr_unidir_en_txsync));
//ips_sgmii_sync_v1_0 idle_match_sync    (.clk(clk_tx), .rst_n(tx_rst_n), .sig_async(idle_match), .sig_synced(idle_match_txsync));

ips_sgmii_handshake_sync_v1_0 #(.DATA_WIDTH(16), .DFT_VALUE(16'h01a0))
   adv_ability_sync  (.src_clk(clk_cfg), .src_rstn(mm_rst_n), .src_data(mr_adv_ability), .des_clk(clk_tx), .des_rstn(tx_rst_n), .des_data(mr_adv_ability_sync));

ips_sgmii_handshake_sync_v1_0 #(.DATA_WIDTH(16), .DFT_VALUE(16'h2001))
   np_tx_sync  (.src_clk(clk_cfg), .src_rstn(mm_rst_n), .src_data(mr_np_tx), .des_clk(clk_tx), .des_rstn(tx_rst_n), .des_data(mr_np_tx_sync));


//ge_pcs_auto_neg instance
ips_sgmii_ge_pcs_auto_neg_v1_9a  U_ips_sgmii_ge_pcs_auto_neg   (
    .clk               (clk_tx                 ),
    .rst_n             (tx_rst_n               ),

    .link_timer_value  (link_timer_value       ),
    .mr_restart_an     (mr_restart_an_txsync   ),
    .mr_adv_ability    (mr_adv_ability_sync    ),

    .mr_an_enable      (mr_an_enable_txsync    ),
    .auto_en           (auto_en                ),

    .mr_lp_adv_ability (mr_lp_adv_ability      ),
    .mr_an_complete    (mr_an_complete         ),
    .mr_np_tx          (mr_np_tx_sync          ),
    .mr_page_rx        (mr_page_rx             ),
    .mr_np_loaded      (mr_np_loaded           ),
    .resolve_priority  (resolve_priority       ),

    .tx_config_reg     (tx_config_reg          ),
    .xmit_o            (xmit                   ),
    .rx_config_reg     (rx_config_reg_txs      ),
    .rx_config_flag    (rx_config_flag_txs     ),
    .rudi              (rudi_txs               ),
    .idle_flag         (idle_flag_txs          ),
    .idle_flag_vld     (idle_flag_vld          ),
    .pcs_lsm_synced    (pcs_lsm_synced_txs     ),
    // just for debug
    .AN_CS             (AN_CS                  ),
    .AN_NS             (AN_NS                  )
);

ips_sgmii_sync_v1_0  pcs_lsm_rxsync      (.clk(clk_rx),     .rst_n(rx_rst_n    ), .sig_async(pcs_lsm_synced   ), .sig_synced(pcs_lsm_synced_rxs    ) );
ips_sgmii_sync_v1_0  pcs_lsm_pcs_rxsyn   (.clk(pcs_rx_clk), .rst_n(rx_rec_rst_n), .sig_async(pcs_lsm_synced   ), .sig_synced(pcs_lsm_synced_pcs_rxs) );
ips_sgmii_sync_v1_0  pcs_lsm_txsync      (.clk(clk_tx),     .rst_n(tx_rst_n    ), .sig_async(pcs_lsm_synced_in), .sig_synced(pcs_lsm_synced_txs    ) );
ips_sgmii_sync_v1_0  loopback_sync       (.clk(clk_tx),     .rst_n(tx_rst_n    ), .sig_async(mr_loopback      ), .sig_synced(mr_loopback_syn       ) );
ips_sgmii_sync_v1_0  rx_rstn_txsync      (.clk(clk_tx),     .rst_n(rx_rst_n    ), .sig_async(1'b1             ), .sig_synced(rx_rstn_txs           ) );

assign rx_to_auto_sync_in  = {rx_unitdata_indicate,idle_flag,rx_config_flag,rx_config_reg};

ips_sgmii_fifo_sync_v1_1a # (
    .DATA_WIDTH        (20                     ),
    .DFT_VALUE         (20'hc0000              )
) rx_sm_to_auto_neg_sync(
    .src_clk           (clk_rx                 ),
    .src_rstn          (rx_rst_n               ),
    .src_data          (rx_to_auto_sync_in     ),
    .des_clk           (clk_tx                 ),
    .des_rstn          (rx_rstn_txs            ),
    .des_data          (rx_to_auto_sync_out    ),
    .idle_flag_vld     (idle_flag_vld          ),
    .wr_full           (                       ),
    .rd_empty          (                       )
);

assign {rudi_txs,idle_flag_txs,rx_config_flag_txs,rx_config_reg_txs} = rx_to_auto_sync_out;

ips_sgmii_handshake_sync_v1_0 #(
    .DATA_WIDTH        (2                      ),
    .DFT_VALUE         (2'b11                  )
) xmit_sync (
    .src_clk           (clk_tx                 ),
    .src_rstn          (tx_rst_n               ),
    .src_data          (xmit                   ),
    .des_clk           (clk_rx                 ),
    .des_rstn          (rx_rst_n               ),
    .des_data          (xmit_rxs               )
);



ips_sgmii_sync_v1_0  mr_loopback_rxs      (.clk(clk_rx),     .rst_n(rx_rst_n    ), .sig_async(mr_loopback_syn      ), .sig_synced(mr_loopback_rx      ) );

assign  pcs_rxd_in          = (mr_loopback_rx == 1'b1) ? pcs_txd : (CLOCKING_LOGIC == "TRUE") ? pcs_rxd_out         : pcs_rxd           ;
assign  pcs_rxk_in          = (mr_loopback_rx == 1'b1) ? pcs_txk : (CLOCKING_LOGIC == "TRUE") ? pcs_rxk_out         : pcs_rxk           ;
assign  pcs_rdispdec_er_in  = (mr_loopback_rx == 1'b1) ? 1'b0    : (CLOCKING_LOGIC == "TRUE") ? pcs_rdispdec_er_out : pcs_rdispdec_er   ;
assign  pcs_lsm_synced_in   = (mr_loopback_rx == 1'b1) ? 1'b1    : (CLOCKING_LOGIC == "TRUE") ? pcs_lsm_synced_out  : pcs_lsm_synced_rxs;
assign  rxbuferr            = (CLOCKING_LOGIC == "TRUE") ? rxbuferr_out : 1'b0;

//ge_pcs_rx_sm instance
ips_sgmii_ge_pcs_rx_sm_v1_9   U_ips_sgmii_ge_pcs_rx_sm (
    .clk               (clk_rx                 ),
    .rst_n             (rx_rst_n               ),
    //to  mac 10m/100m/1000m
    .gmii_rxd          (gmii_rxd               ),
    .gmii_rx_dv        (gmii_rx_dv             ),
    .gmii_rx_er        (gmii_rx_er             ),
    //ge_pcs_auto_neg signal

    .xmit              (xmit_rxs               ),

    .rx_config_reg     (rx_config_reg          ),
    .rx_config_flag    (rx_config_flag         ),
    .rudi              (rx_unitdata_indicate   ),
    .idle_flag         (idle_flag              ),
    //indicate receiving
    .receiving         (receiving              ),
    //from rx_elastic_buffer
    .pcs_rxk           (pcs_rxk_in             ),
    .pcs_rdispdec_er   (pcs_rdispdec_er_in     ),
    .pcs_rxd           (pcs_rxd_in             ),
    .pcs_lsm_synced    (pcs_lsm_synced_in      ),
    // just for debug
    .RS_CS             (RS_CS                  ),
    .RS_NS             (RS_NS                  )
);

//ge_pcs_tx_sm instance
ips_sgmii_ge_pcs_tx_sm_v1_9c   U_ips_sgmii_ge_pcs_tx_sm (
    .clk               (clk_tx                 ),
    .rst_n             (tx_rst_n               ),
    //from  rate_adapt
    .gmii_txd          (gmii_txd               ),
    .gmii_tx_en        (gmii_tx_en             ),
    .gmii_tx_er        (gmii_tx_er             ),

    //ge_pcs_auto_neg signal
    .mr_an_enable      (mr_an_enable_txsync    ),
    .mr_unidir_en      (mr_unidir_en_txsync    ),
    .xmit              (xmit                   ),
    .tx_config_reg     (tx_config_reg          ),
    .transmitting      (transmitting           ),
    //to  PCS TX CHANNEL
    .pcs_txk           (pcs_txk                ),
    .pcs_tx_dispctrl   (pcs_tx_dispctrl        ),
    .pcs_tx_dispsel    (pcs_tx_dispsel         ),
    .pcs_txd           (pcs_txd                ),
    .TS_CS             (TS_CS                  ),
    .TS_NS             (TS_NS                  )
);

ips_sgmii_sync_v1_0  rx_rec_rstn_sync (.clk(pcs_rx_clk), .rst_n(rx_rst_n), .sig_async(1'b1), .sig_synced(rx_rec_rst_n));

ips_sgmii_handshake_sync_v1_0 #(.DATA_WIDTH(4), .DFT_VALUE(4'd6))
                      min_ipg_rxsync (.src_clk(clk_cfg), .src_rstn(mm_rst_n), .src_data(min_ipg), .des_clk(pcs_rx_clk), .des_rstn(rx_rec_rst_n), .des_data(min_ipg_sync));

ips_sgmii_handshake_sync_v1_0 #(.DATA_WIDTH(2), .DFT_VALUE(2'b10))
                      sgmii_speed_rx_rec_sync (.src_clk(clk_cfg), .src_rstn(mm_rst_n), .src_data(sgmii_speed), .des_clk(pcs_rx_clk), .des_rstn(rx_rec_rst_n), .des_data(sgmii_speed_rx_rec_s));

//rx_elastic_buffer instance
ips_sgmii_rx_elastic_buffer_v1_9  U_ips_sgmii_rx_elastic_buffer
(
    .tx_rst_n          (rx_rst_n               ),
    .rx_rst_n          (rx_rec_rst_n           ),
    .clk_in            (pcs_rx_clk             ),
    .clk_out           (clk_rx                 ),
    .min_ipg           (min_ipg_sync           ),
    .sgmii_speed       (sgmii_speed_rx_rec_s   ),

    //from PCS CHANNEL
    .rxk_in            (pcs_rxk                ),
    .rdispdec_er_in    (pcs_rdispdec_er        ),
    .rxd_in            (pcs_rxd                ),
    .pcs_lsm_synced_in (pcs_lsm_synced_pcs_rxs ) ,

    //to ge_pcs_rx_sm
    .rxk_out           (pcs_rxk_out            ),
    .rdispdec_er_out   (pcs_rdispdec_er_out    ),
    .rxd_out           (pcs_rxd_out            ),
    .pcs_lsm_synced_out(pcs_lsm_synced_out     ),
    .rxbuferr          (rxbuferr_out           )
);

ips_sgmii_sync_v1_0 sgmii_mode_rxsync (.clk(clk_rx), .rst_n(rx_rst_n), .sig_async(sgmii_mode), .sig_synced(sgmii_mode_rxs));
ips_sgmii_sync_v1_0 sgmii_mode_txsync (.clk(clk_tx), .rst_n(tx_rst_n), .sig_async(sgmii_mode), .sig_synced(sgmii_mode_txs));

ips_sgmii_handshake_sync_v1_0 #(.DATA_WIDTH(2), .DFT_VALUE(2'b10))
                      sgmii_speed_rxsync (.src_clk(clk_cfg), .src_rstn(mm_rst_n), .src_data(sgmii_speed), .des_clk(clk_rx), .des_rstn(rx_rst_n), .des_data(sgmii_speed_rxs));

ips_sgmii_handshake_sync_v1_0 #(.DATA_WIDTH(2), .DFT_VALUE(2'b10))
                      sgmii_speed_txsync (.src_clk(clk_cfg), .src_rstn(mm_rst_n), .src_data(sgmii_speed), .des_clk(clk_tx), .des_rstn(tx_rst_n), .des_data(sgmii_speed_txs));

//clk_gen  instance

ips_sgmii_clk_gen_v1_9 #(
    .CLOCKEN           (CLOCKEN                )
) U_ips_sgmii_clk_gen(
    .tx_rst_n          (tx_rst_n               ),
    .rx_rst_n          (rx_rst_n               ),
    .clk_tx            (clk_tx                 ),
    .clk_rx            (clk_rx                 ),
    .sgmii_clk         (sgmii_clk              ),
    .tx_clken          (tx_clken               ),
    // RX Side Only valid when NO BUFFER Mode
    .sgmii_rx_clk      (sgmii_rx_clk           ),
    .rx_clken          (rx_clken               ),
    .speed_mode_txs    (sgmii_speed_txs        ),
    .speed_mode_rxs    (sgmii_speed_rxs        ),
    .sgmii_mode_txs    (sgmii_mode_txs         ),
    .sgmii_mode_rxs    (sgmii_mode_rxs         )
);

endmodule
