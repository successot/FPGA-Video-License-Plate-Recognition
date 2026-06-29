`default_nettype wire
`timescale 1ns / 1ps
/*////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Company:Meyesemi 
// Engineer: xx
// 
// Create Date: 2024-01-9 09:31  
// Design Name:  
// Module Name: 
// Project Name: 
// Target Devices: Pango
// Tool Versions: 
// Description: 
//      
// Dependencies: 
// 
// Revision:
// Revision 1.0 - File Created
// Additional Comments: 
*/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
module mesethernet_test(
    input                       free_clk        ,
    input                       rstn            ,
//yt8614    
    output                      u10_rstn_out    ,
    output                      u10_mdc_o      /* synthesis PAP_MARK_DEBUG="true" */ ,
    output                      u10_mdio       /* synthesis PAP_MARK_DEBUG="true" */ ,
    output                      u2_rstn_out     ,
    output                      u2_mdc_o       /* synthesis PAP_MARK_DEBUG="true" */ ,
    output                      u2_mdio        /* synthesis PAP_MARK_DEBUG="true" */ ,
//done
    output [7:0]                led             ,
//hsst
    input                       i_p_refckn_0    , 
    input                       i_p_refckp_0    ,
    input                       i_p_l0rxn       ,
    input                       i_p_l0rxp       ,
    input                       i_p_l1rxn       ,
    input                       i_p_l1rxp       ,
    input                       i_p_l2rxn       ,
    input                       i_p_l2rxp       ,
    input                       i_p_l3rxn       ,
    input                       i_p_l3rxp       ,
    output                      o_p_l0txn       ,
    output                      o_p_l0txp       ,
    output                      o_p_l1txn       ,
    output                      o_p_l1txp       ,
    output                      o_p_l2txn       ,
    output                      o_p_l2txp       ,
    output                      o_p_l3txn       ,
    output                      o_p_l3txp       ,
//phy_led
    output  [2:0]               u2_ch0_led      ,
    output  [2:0]               u2_ch1_led      ,
    output  [2:0]               u2_ch2_led      ,
    output  [2:0]               u2_ch3_led      ,
    output  [2:0]               u10_ch0_led     ,
    output  [2:0]               u10_ch1_led     ,
    output  [2:0]               u10_ch2_led     ,
    output  [2:0]               u10_ch3_led     ,
//sfp_disable
    output[1:0]                 tx_disable

);

// -----------------------------------------------------------------------------
// PORT_MATRIX_DIAG_V4_RSTN_SAFE compile-time route selector.
// 0/0: U10 <-> SFP0 and U2 <-> SFP1 (straight topology)
// 0/1: U10 <-> SFP1 and U2 <-> SFP0 (crossed topology)
// 1/0: U2  <-> SFP0 and U10<-> SFP1 (crossed topology)
// 1/1: U2  <-> SFP1 and U10<-> SFP0 (straight topology)
// Only selected-route LEDs/debug anchors change; all four QSGMII channels stay intact.
// -----------------------------------------------------------------------------
localparam LINK_TEST_INGRESS_U2  = 1'b1;
localparam LINK_TEST_EGRESS_SFP1 = 1'b0;
localparam LINK_TEST_CROSS_ROUTE = LINK_TEST_INGRESS_U2 ^ LINK_TEST_EGRESS_SFP1;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//lane0
wire [15:0]         p0_status_vector_sfp1 ,p1_status_vector_sfp1 ,p2_status_vector_sfp1 ,p3_status_vector_sfp1  /* synthesis PAP_MARK_DEBUG="true" */;
wire                p0_sgmii_clk_sfp1     ,p1_sgmii_clk_sfp1     ,p2_sgmii_clk_sfp1     ,p3_sgmii_clk_sfp1      /* synthesis PAP_MARK_DEBUG="true" */;  
wire                p0_tx_clken_sfp1      ,p1_tx_clken_sfp1      ,p2_tx_clken_sfp1      ,p3_tx_clken_sfp1       /* synthesis PAP_MARK_DEBUG="true" */;  
wire                p0_tx_rstn_sync_sfp1  ,p1_tx_rstn_sync_sfp1  ,p2_tx_rstn_sync_sfp1  ,p3_tx_rstn_sync_sfp1   /* synthesis PAP_MARK_DEBUG="true" */;  
wire                p0_rx_rstn_sync_sfp1  ,p1_rx_rstn_sync_sfp1  ,p2_rx_rstn_sync_sfp1  ,p3_rx_rstn_sync_sfp1   /* synthesis PAP_MARK_DEBUG="true" */;  
wire [7:0]          p0_gmii_rxd_sfp1      ,p1_gmii_rxd_sfp1      ,p2_gmii_rxd_sfp1      ,p3_gmii_rxd_sfp1       /* synthesis PAP_MARK_DEBUG="true" */;  
wire                p0_gmii_rx_dv_sfp1    ,p1_gmii_rx_dv_sfp1    ,p2_gmii_rx_dv_sfp1    ,p3_gmii_rx_dv_sfp1     /* synthesis PAP_MARK_DEBUG="true" */;  
wire                p0_gmii_rx_er_sfp1    ,p1_gmii_rx_er_sfp1    ,p2_gmii_rx_er_sfp1    ,p3_gmii_rx_er_sfp1     /* synthesis PAP_MARK_DEBUG="true" */;  
wire [7:0]          p0_gmii_txd_sfp1      ,p1_gmii_txd_sfp1      ,p2_gmii_txd_sfp1      ,p3_gmii_txd_sfp1       /* synthesis PAP_MARK_DEBUG="true" */;  
wire                p0_gmii_tx_en_sfp1    ,p1_gmii_tx_en_sfp1    ,p2_gmii_tx_en_sfp1    ,p3_gmii_tx_en_sfp1     /* synthesis PAP_MARK_DEBUG="true" */;  
wire                p0_gmii_tx_er_sfp1    ,p1_gmii_tx_er_sfp1    ,p2_gmii_tx_er_sfp1    ,p3_gmii_tx_er_sfp1     /* synthesis PAP_MARK_DEBUG="true" */; 
//lane1
wire [15:0]         p0_status_vector_sfp0 ,p1_status_vector_sfp0 ,p2_status_vector_sfp0 ,p3_status_vector_sfp0  /* synthesis PAP_MARK_DEBUG="true" */;
wire                p0_sgmii_clk_sfp0     ,p1_sgmii_clk_sfp0     ,p2_sgmii_clk_sfp0     ,p3_sgmii_clk_sfp0      /* synthesis PAP_MARK_DEBUG="true" */;  
wire                p0_tx_clken_sfp0      ,p1_tx_clken_sfp0      ,p2_tx_clken_sfp0      ,p3_tx_clken_sfp0       /* synthesis PAP_MARK_DEBUG="true" */;  
wire                p0_tx_rstn_sync_sfp0  ,p1_tx_rstn_sync_sfp0  ,p2_tx_rstn_sync_sfp0  ,p3_tx_rstn_sync_sfp0   /* synthesis PAP_MARK_DEBUG="true" */;  
wire                p0_rx_rstn_sync_sfp0  ,p1_rx_rstn_sync_sfp0  ,p2_rx_rstn_sync_sfp0  ,p3_rx_rstn_sync_sfp0   /* synthesis PAP_MARK_DEBUG="true" */;  
wire [7:0]          p0_gmii_rxd_sfp0      ,p1_gmii_rxd_sfp0      ,p2_gmii_rxd_sfp0      ,p3_gmii_rxd_sfp0       /* synthesis PAP_MARK_DEBUG="true" */;  
wire                p0_gmii_rx_dv_sfp0    ,p1_gmii_rx_dv_sfp0    ,p2_gmii_rx_dv_sfp0    ,p3_gmii_rx_dv_sfp0     /* synthesis PAP_MARK_DEBUG="true" */;  
wire                p0_gmii_rx_er_sfp0    ,p1_gmii_rx_er_sfp0    ,p2_gmii_rx_er_sfp0    ,p3_gmii_rx_er_sfp0     /* synthesis PAP_MARK_DEBUG="true" */;  
wire [7:0]          p0_gmii_txd_sfp0      ,p1_gmii_txd_sfp0      ,p2_gmii_txd_sfp0      ,p3_gmii_txd_sfp0       /* synthesis PAP_MARK_DEBUG="true" */;  
wire                p0_gmii_tx_en_sfp0    ,p1_gmii_tx_en_sfp0    ,p2_gmii_tx_en_sfp0    ,p3_gmii_tx_en_sfp0     /* synthesis PAP_MARK_DEBUG="true" */;  
wire                p0_gmii_tx_er_sfp0    ,p1_gmii_tx_er_sfp0    ,p2_gmii_tx_er_sfp0    ,p3_gmii_tx_er_sfp0     /* synthesis PAP_MARK_DEBUG="true" */; 

reg       dbg_sfp0_ch0_tx_en /* synthesis PAP_MARK_DEBUG="true" */;
reg [7:0] dbg_sfp0_ch0_txd   /* synthesis PAP_MARK_DEBUG="true" */;
reg       dbg_sfp0_ch1_tx_en /* synthesis PAP_MARK_DEBUG="true" */;
reg [7:0] dbg_sfp0_ch1_txd   /* synthesis PAP_MARK_DEBUG="true" */;
reg       dbg_sfp0_ch2_tx_en /* synthesis PAP_MARK_DEBUG="true" */;
reg [7:0] dbg_sfp0_ch2_txd   /* synthesis PAP_MARK_DEBUG="true" */;
reg       dbg_sfp0_ch3_tx_en /* synthesis PAP_MARK_DEBUG="true" */;
reg [7:0] dbg_sfp0_ch3_txd   /* synthesis PAP_MARK_DEBUG="true" */;

always @(posedge p0_sgmii_clk_sfp0 or negedge p0_tx_rstn_sync_sfp0) begin
    if (!p0_tx_rstn_sync_sfp0) begin
        dbg_sfp0_ch0_tx_en <= 1'b0;
        dbg_sfp0_ch0_txd   <= 8'h00;
    end else begin
        dbg_sfp0_ch0_tx_en <= p0_gmii_tx_en_sfp0;
        dbg_sfp0_ch0_txd   <= p0_gmii_txd_sfp0;
    end
end

always @(posedge p1_sgmii_clk_sfp0 or negedge p1_tx_rstn_sync_sfp0) begin
    if (!p1_tx_rstn_sync_sfp0) begin
        dbg_sfp0_ch1_tx_en <= 1'b0;
        dbg_sfp0_ch1_txd   <= 8'h00;
    end else begin
        dbg_sfp0_ch1_tx_en <= p1_gmii_tx_en_sfp0;
        dbg_sfp0_ch1_txd   <= p1_gmii_txd_sfp0;
    end
end

always @(posedge p2_sgmii_clk_sfp0 or negedge p2_tx_rstn_sync_sfp0) begin
    if (!p2_tx_rstn_sync_sfp0) begin
        dbg_sfp0_ch2_tx_en <= 1'b0;
        dbg_sfp0_ch2_txd   <= 8'h00;
    end else begin
        dbg_sfp0_ch2_tx_en <= p2_gmii_tx_en_sfp0;
        dbg_sfp0_ch2_txd   <= p2_gmii_txd_sfp0;
    end
end

always @(posedge p3_sgmii_clk_sfp0 or negedge p3_tx_rstn_sync_sfp0) begin
    if (!p3_tx_rstn_sync_sfp0) begin
        dbg_sfp0_ch3_tx_en <= 1'b0;
        dbg_sfp0_ch3_txd   <= 8'h00;
    end else begin
        dbg_sfp0_ch3_tx_en <= p3_gmii_tx_en_sfp0;
        dbg_sfp0_ch3_txd   <= p3_gmii_txd_sfp0;
    end
end


//lane2
wire [15:0]         p0_status_vector_u10 ,p1_status_vector_u10 ,p2_status_vector_u10 ,p3_status_vector_u10      /* synthesis PAP_MARK_DEBUG="true" */;
wire                p0_sgmii_clk_u10     ,p1_sgmii_clk_u10     ,p2_sgmii_clk_u10     ,p3_sgmii_clk_u10          /* synthesis PAP_MARK_DEBUG="true" */;        
wire                p0_tx_clken_u10      ,p1_tx_clken_u10      ,p2_tx_clken_u10      ,p3_tx_clken_u10           /* synthesis PAP_MARK_DEBUG="true" */;        
wire                p0_tx_rstn_sync_u10  ,p1_tx_rstn_sync_u10  ,p2_tx_rstn_sync_u10  ,p3_tx_rstn_sync_u10       /* synthesis PAP_MARK_DEBUG="true" */;        
wire                p0_rx_rstn_sync_u10  ,p1_rx_rstn_sync_u10  ,p2_rx_rstn_sync_u10  ,p3_rx_rstn_sync_u10       /* synthesis PAP_MARK_DEBUG="true" */;                      
wire [7:0]          p0_gmii_rxd_u10      ,p1_gmii_rxd_u10      ,p2_gmii_rxd_u10      ,p3_gmii_rxd_u10           /* synthesis PAP_MARK_DEBUG="true" */;   
wire                p0_gmii_rx_dv_u10    ,p1_gmii_rx_dv_u10    ,p2_gmii_rx_dv_u10    ,p3_gmii_rx_dv_u10         /* synthesis PAP_MARK_DEBUG="true" */;   
wire                p0_gmii_rx_er_u10    ,p1_gmii_rx_er_u10    ,p2_gmii_rx_er_u10    ,p3_gmii_rx_er_u10         /* synthesis PAP_MARK_DEBUG="true" */;    
wire [7:0]          p0_gmii_txd_u10      ,p1_gmii_txd_u10      ,p2_gmii_txd_u10      ,p3_gmii_txd_u10           /* synthesis PAP_MARK_DEBUG="true" */;    
wire                p0_gmii_tx_en_u10    ,p1_gmii_tx_en_u10    ,p2_gmii_tx_en_u10    ,p3_gmii_tx_en_u10         /* synthesis PAP_MARK_DEBUG="true" */;    
wire                p0_gmii_tx_er_u10    ,p1_gmii_tx_er_u10    ,p2_gmii_tx_er_u10    ,p3_gmii_tx_er_u10         /* synthesis PAP_MARK_DEBUG="true" */;
//lane3
wire [15:0]         p0_status_vector_u2 ,p1_status_vector_u2 ,p2_status_vector_u2 ,p3_status_vector_u2          /* synthesis PAP_MARK_DEBUG="true" */;
wire                p0_sgmii_clk_u2     ,p1_sgmii_clk_u2     ,p2_sgmii_clk_u2     ,p3_sgmii_clk_u2              /* synthesis PAP_MARK_DEBUG="true" */;  
wire                p0_tx_clken_u2      ,p1_tx_clken_u2      ,p2_tx_clken_u2      ,p3_tx_clken_u2               /* synthesis PAP_MARK_DEBUG="true" */;  
wire                p0_tx_rstn_sync_u2  ,p1_tx_rstn_sync_u2  ,p2_tx_rstn_sync_u2  ,p3_tx_rstn_sync_u2           /* synthesis PAP_MARK_DEBUG="true" */;  
wire                p0_rx_rstn_sync_u2  ,p1_rx_rstn_sync_u2  ,p2_rx_rstn_sync_u2  ,p3_rx_rstn_sync_u2           /* synthesis PAP_MARK_DEBUG="true" */;  
wire [7:0]          p0_gmii_rxd_u2      ,p1_gmii_rxd_u2      ,p2_gmii_rxd_u2      ,p3_gmii_rxd_u2               /* synthesis PAP_MARK_DEBUG="true" */;  
wire                p0_gmii_rx_dv_u2    ,p1_gmii_rx_dv_u2    ,p2_gmii_rx_dv_u2    ,p3_gmii_rx_dv_u2             /* synthesis PAP_MARK_DEBUG="true" */;  
wire                p0_gmii_rx_er_u2    ,p1_gmii_rx_er_u2    ,p2_gmii_rx_er_u2    ,p3_gmii_rx_er_u2             /* synthesis PAP_MARK_DEBUG="true" */;  
wire [7:0]          p0_gmii_txd_u2      ,p1_gmii_txd_u2      ,p2_gmii_txd_u2      ,p3_gmii_txd_u2               /* synthesis PAP_MARK_DEBUG="true" */;  
wire                p0_gmii_tx_en_u2    ,p1_gmii_tx_en_u2    ,p2_gmii_tx_en_u2    ,p3_gmii_tx_en_u2             /* synthesis PAP_MARK_DEBUG="true" */;  
wire                p0_gmii_tx_er_u2    ,p1_gmii_tx_er_u2    ,p2_gmii_tx_er_u2    ,p3_gmii_tx_er_u2             /* synthesis PAP_MARK_DEBUG="true" */;
//hsst_done
wire                o_txlane_done_0  ,o_txlane_done_1  ,o_txlane_done_2  ,o_txlane_done_3,
                    o_rxlane_done_0  ,o_rxlane_done_1  ,o_rxlane_done_2  ,o_rxlane_done_3   /* synthesis PAP_MARK_DEBUG="true" */;
//clk
wire                o_p_clk2core_tx_0 , o_p_clk2core_rx_0 /* synthesis PAP_MARK_DEBUG="true" */;
wire                o_p_clk2core_tx_1 , o_p_clk2core_rx_1 /* synthesis PAP_MARK_DEBUG="true" */;
wire                o_p_clk2core_tx_2 , o_p_clk2core_rx_2 /* synthesis PAP_MARK_DEBUG="true" */;
wire                o_p_clk2core_tx_3 , o_p_clk2core_rx_3 /* synthesis PAP_MARK_DEBUG="true" */;
//hsst_rx_tx
wire [31:0]         i_txd_0        ,i_txd_1       ,i_txd_2       ,i_txd_3       /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]          i_txk_0        ,i_txk_1       ,i_txk_2       ,i_txk_3       /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]          i_tdispsel_0   ,i_tdispsel_1  ,i_tdispsel_2  ,i_tdispsel_3  /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]          i_tdispctrl_0  ,i_tdispctrl_1 ,i_tdispctrl_2 ,i_tdispctrl_3 /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0]         o_rxd_0        ,o_rxd_1       ,o_rxd_2       ,o_rxd_3       /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]          o_rxk_0        ,o_rxk_1       ,o_rxk_2       ,o_rxk_3       /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]          o_rdisper_0    ,o_rdisper_1   ,o_rdisper_2   ,o_rdisper_3   /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]          o_rdecer_0     ,o_rdecer_1    ,o_rdecer_2    ,o_rdecer_3    /* synthesis PAP_MARK_DEBUG="true" */;
//yt_link
wire                u10_ch0_link,u10_ch1_link,u10_ch2_link,u10_ch3_link         /* synthesis PAP_MARK_DEBUG="true" */;
wire                u2_ch0_link ,u2_ch1_link ,u2_ch2_link ,u2_ch3_link          /* synthesis PAP_MARK_DEBUG="true" */;
wire [7:0]          done,link;
//speed
wire [1:0]          u10_ch0_speed ,u10_ch1_speed ,u10_ch2_speed ,u10_ch3_speed ;
wire [1:0]          u2_ch0_speed  ,u2_ch1_speed  ,u2_ch2_speed  ,u2_ch3_speed  ;
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
cross_reset_sync  u1_reset_sync (
    .free_clk_pll            (free_clk          ),//input       
    .external_rstn           (rstn              ),//input       
    .rst_n                   (external_rstn     ) //output
);
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
yt8614_ctrl u_yt_ctrl(
    .i_clk          (free_clk           ),//input 50M
    .i_rst_n        (rstn               ),//input
    .reset_n_out    (rstn_out           ),//output
    .reset_n_done   (                   ),//output
    .mdc            (mdc_o              ),//output
    .mdio           (mdio               ) //inout          
);
assign u10_rstn_out = rstn_out  ;
assign u10_mdc_o    = mdc_o     ;
assign u10_mdio     = mdio      ;
assign u2_rstn_out  = rstn_out  ;
assign u2_mdc_o     = mdc_o     ; 
assign u2_mdio      = mdio      ; 
//link_state/////////////////////////////////////////////////////////////////////////////////////////////////////
assign u10_ch0_link = ((p0_status_vector_u10[0]==1'b1)&&(p0_status_vector_u10[10:9]==2'b00))?1'b1:1'b0;
assign u10_ch1_link = ((p1_status_vector_u10[0]==1'b1)&&(p1_status_vector_u10[10:9]==2'b00))?1'b1:1'b0;
assign u10_ch2_link = ((p2_status_vector_u10[0]==1'b1)&&(p2_status_vector_u10[10:9]==2'b00))?1'b1:1'b0;
assign u10_ch3_link = ((p3_status_vector_u10[0]==1'b1)&&(p3_status_vector_u10[10:9]==2'b00))?1'b1:1'b0;
assign u2_ch0_link  = ((p0_status_vector_u2[0]==1'b1)&&(p0_status_vector_u2[10:9]==2'b00))?1'b1:1'b0;
assign u2_ch1_link  = ((p1_status_vector_u2[0]==1'b1)&&(p1_status_vector_u2[10:9]==2'b00))?1'b1:1'b0;
assign u2_ch2_link  = ((p2_status_vector_u2[0]==1'b1)&&(p2_status_vector_u2[10:9]==2'b00))?1'b1:1'b0;
assign u2_ch3_link  = ((p3_status_vector_u2[0]==1'b1)&&(p3_status_vector_u2[10:9]==2'b00))?1'b1:1'b0;
//speed/////////////////////////////////////////////////////////////////////////////////////////////////////////
assign u10_ch0_speed = p0_status_vector_u10[4:3];
assign u10_ch1_speed = p1_status_vector_u10[4:3];
assign u10_ch2_speed = p2_status_vector_u10[4:3];
assign u10_ch3_speed = p3_status_vector_u10[4:3];
assign u2_ch0_speed  = p0_status_vector_u2 [4:3];
assign u2_ch1_speed  = p1_status_vector_u2 [4:3];
assign u2_ch2_speed  = p2_status_vector_u2 [4:3];
assign u2_ch3_speed  = p3_status_vector_u2 [4:3];
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
assign  tx_disable  = 2'b0  ; 
assign  done    = {o_txlane_done_0,o_txlane_done_1,o_txlane_done_2,o_txlane_done_3,
                   o_rxlane_done_0,o_rxlane_done_1,o_rxlane_done_2,o_rxlane_done_3};
assign  link    = {u2_ch3_link,u2_ch2_link,u2_ch1_link,u2_ch0_link,u10_ch3_link,u10_ch2_link,u10_ch1_link,u10_ch0_link};

// -----------------------------------------------------------------------------
// V5 all-RJ45 RX debug signals. Channel bit order:
// [0] U10 ch0, [1] U10 ch1, [2] U10 ch2, [3] U10 ch3,
// [4] U2  ch0, [5] U2  ch1, [6] U2  ch2, [7] U2  ch3.
// -----------------------------------------------------------------------------
wire [7:0] v5_rx_activity_live /* synthesis PAP_MARK_DEBUG="true" */;
wire [7:0] v5_rx_frame_seen    /* synthesis PAP_MARK_DEBUG="true" */;
wire [7:0] v5_udp5000_seen     /* synthesis PAP_MARK_DEBUG="true" */;
wire [7:0] v5_fpgv_seen        /* synthesis PAP_MARK_DEBUG="true" */;
wire [7:0] v5_rx_error_seen    /* synthesis PAP_MARK_DEBUG="true" */;
wire [2:0] v5_active_channel   /* synthesis PAP_MARK_DEBUG="true" */;
wire [7:0] v5_debug_led        /* synthesis PAP_MARK_DEBUG="true" */;

// PORT_MATRIX_DIAG_V4_RSTN_SAFE selected-route LED diagnostics.
wire clean_selected_link       = LINK_TEST_INGRESS_U2 ? |link[7:4] : |link[3:0];
wire clean_selected_frame_seen = LINK_TEST_INGRESS_U2 ? |v5_rx_frame_seen[7:4] : |v5_rx_frame_seen[3:0];
wire clean_selected_udp5000    = LINK_TEST_INGRESS_U2 ? |v5_udp5000_seen[7:4]  : |v5_udp5000_seen[3:0];
wire clean_selected_fpgv       = LINK_TEST_INGRESS_U2 ? |v5_fpgv_seen[7:4]     : |v5_fpgv_seen[3:0];
wire clean_selected_rx_error   = LINK_TEST_INGRESS_U2 ? |v5_rx_error_seen[7:4] : |v5_rx_error_seen[3:0];
wire clean_selected_tx_en      = LINK_TEST_EGRESS_SFP1 ?
                                 (p0_gmii_tx_en_sfp1 | p1_gmii_tx_en_sfp1 | p2_gmii_tx_en_sfp1 | p3_gmii_tx_en_sfp1) :
                                 (p0_gmii_tx_en_sfp0 | p1_gmii_tx_en_sfp0 | p2_gmii_tx_en_sfp0 | p3_gmii_tx_en_sfp0);
// V4 RSTN-SAFE: side-band free_clk registers use the existing synchronized
// external_rstn release and synchronous reset style. This keeps top-level
// raw rstn off preserved Fabric Debugger diagnostic control sets.
reg clean_selected_tx_activity /* synthesis PAP_MARK_DEBUG="true" */;
always @(posedge free_clk) begin
    if(!external_rstn)
        clean_selected_tx_activity <= 1'b0;
    else if(clean_selected_tx_en)
        clean_selected_tx_activity <= 1'b1;
end

reg [25:0] clean_hb_cnt;
reg        clean_heartbeat;
always @(posedge free_clk) begin
    if(!external_rstn) begin
        clean_hb_cnt   <= 26'd0;
        clean_heartbeat<= 1'b0;
    end else begin
        clean_hb_cnt <= clean_hb_cnt + 26'd1;
        if(clean_hb_cnt == 26'd0)
            clean_heartbeat <= ~clean_heartbeat;
    end
end

wire [7:0] clean_debug_led = {
    clean_selected_rx_error,   // LED7: selected RJ45 ingress GMII RX error seen
    clean_selected_tx_activity,// LED6: selected SFP egress TX activity generated by bridge
    clean_selected_fpgv,       // LED5: selected ingress FPGV seen
    clean_selected_udp5000,    // LED4: selected ingress UDP5000 seen
    clean_selected_frame_seen, // LED3: selected ingress Ethernet frame seen
    clean_selected_link,       // LED2: selected RJ45 ingress link
    clean_heartbeat,           // LED1: heartbeat copy for visual check
    clean_heartbeat            // LED0: heartbeat
};


// -----------------------------------------------------------------------------
// Stage5A stream-bridge build: MES50H is a transparent RJ45-to-SFP/DAC
// relay, so all Stage4 DDR3 write-check and DDR3 AXI signals were removed.
// The original PHY/status LED generator is kept for the per-port PHY LED pins.
// -----------------------------------------------------------------------------
wire [7:0]  led_phy;




led_test u_led_test(
    .clk            (free_clk       ),//input
    .rstn           (external_rstn  ),//input
    .done           (done           ),//input[7:0]
    .link           (link           ),//input[7:0]
    .u10_ch0_speed  (u10_ch0_speed  ),//input[1:0]
    .u10_ch1_speed  (u10_ch1_speed  ),//input[1:0]
    .u10_ch2_speed  (u10_ch2_speed  ),//input[1:0]
    .u10_ch3_speed  (u10_ch3_speed  ),//input[1:0]
    .u2_ch0_speed   (u2_ch0_speed   ),//input[1:0]
    .u2_ch1_speed   (u2_ch1_speed   ),//input[1:0]
    .u2_ch2_speed   (u2_ch2_speed   ),//input[1:0]
    .u2_ch3_speed   (u2_ch3_speed   ),//input[1:0]
    .u2_ch0_led     (u2_ch0_led     ),//output[2:0]               
    .u2_ch1_led     (u2_ch1_led     ),//output[2:0]               
    .u2_ch2_led     (u2_ch2_led     ),//output[2:0]               
    .u2_ch3_led     (u2_ch3_led     ),//output[2:0]               
    .u10_ch0_led    (u10_ch0_led    ),//output[2:0]               
    .u10_ch1_led    (u10_ch1_led    ),//output[2:0]               
    .u10_ch2_led    (u10_ch2_led    ),//output[2:0]               
    .u10_ch3_led    (u10_ch3_led    ),//output[2:0]               
    .led            (led_phy        ) //output[7:0]
);               


// -----------------------------------------------------------------------------
// PORT_MATRIX_DIAG_SEARCHABLE_V4_RSTN_SAFE
// Search Fabric Debugger with: dbg_route_h_
// Selected ingress: 0=U10 CH2, 1=U2 CH2.
// Selected optical egress: 0=SFP0 CH2, 1=SFP1 CH2.
// These registered anchors are side-band only; they do not drive the bridge.
// -----------------------------------------------------------------------------
wire route_h_rx_clk  = LINK_TEST_INGRESS_U2 ? p2_sgmii_clk_u2      : p2_sgmii_clk_u10;
wire route_h_rx_rstn = LINK_TEST_INGRESS_U2 ? p2_rx_rstn_sync_u2   : p2_rx_rstn_sync_u10;
wire [7:0] route_h_rx_rxd = LINK_TEST_INGRESS_U2 ? p2_gmii_rxd_u2  : p2_gmii_rxd_u10;
wire route_h_rx_dv   = LINK_TEST_INGRESS_U2 ? p2_gmii_rx_dv_u2     : p2_gmii_rx_dv_u10;
wire route_h_rx_er   = LINK_TEST_INGRESS_U2 ? p2_gmii_rx_er_u2     : p2_gmii_rx_er_u10;
wire route_h_rx_link = LINK_TEST_INGRESS_U2 ? u2_ch2_link          : u10_ch2_link;

wire route_h_tx_clk  = LINK_TEST_EGRESS_SFP1 ? p2_sgmii_clk_sfp1    : p2_sgmii_clk_sfp0;
wire route_h_tx_rstn = LINK_TEST_EGRESS_SFP1 ? p2_tx_rstn_sync_sfp1 : p2_tx_rstn_sync_sfp0;
wire route_h_tx_en   = LINK_TEST_EGRESS_SFP1 ? p2_gmii_tx_en_sfp1   : p2_gmii_tx_en_sfp0;
wire route_h_tx_er   = LINK_TEST_EGRESS_SFP1 ? p2_gmii_tx_er_sfp1   : p2_gmii_tx_er_sfp0;

wire [31:0] raw_route_h_rx_frame_count;
wire [31:0] raw_route_h_rx_udp5000_count;
wire [31:0] raw_route_h_rx_fpgv_count;
wire [31:0] raw_route_h_rx_monitor_er_cycle_count;
wire [15:0] raw_route_h_rx_last_packet_id;
wire [15:0] raw_route_h_rx_last_packet_total;
wire [31:0] raw_route_h_rx_segment_count;
wire [31:0] raw_route_h_rx_byte_count;
wire [31:0] raw_route_h_rx_er_segment_count;
wire [31:0] raw_route_h_rx_shape_er_cycle_count;
wire [31:0] raw_route_h_rx_short_segment_count;
wire [15:0] raw_route_h_rx_last_segment_len;
wire [15:0] raw_route_h_rx_min_segment_len;
wire [15:0] raw_route_h_rx_max_segment_len;
wire [31:0] raw_route_h_tx_segment_count;
wire [31:0] raw_route_h_tx_byte_count;
wire [31:0] raw_route_h_tx_er_segment_count;
wire [31:0] raw_route_h_tx_er_cycle_count;
wire [31:0] raw_route_h_tx_short_segment_count;
wire [15:0] raw_route_h_tx_last_segment_len;
wire [15:0] raw_route_h_tx_min_segment_len;
wire [15:0] raw_route_h_tx_max_segment_len;

reg        dbg_route_h_probe_alive                  /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg        dbg_route_h_cfg_ingress_u2                /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg        dbg_route_h_cfg_egress_sfp1               /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg        dbg_route_h_rx_link                       /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [31:0] dbg_route_h_rx_frame_count                /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [31:0] dbg_route_h_rx_udp5000_count              /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [31:0] dbg_route_h_rx_fpgv_count                 /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [31:0] dbg_route_h_rx_monitor_er_cycle_count     /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [15:0] dbg_route_h_rx_last_packet_id             /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [15:0] dbg_route_h_rx_last_packet_total          /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [31:0] dbg_route_h_rx_segment_count              /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [31:0] dbg_route_h_rx_byte_count                 /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [31:0] dbg_route_h_rx_er_segment_count           /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [31:0] dbg_route_h_rx_shape_er_cycle_count       /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [31:0] dbg_route_h_rx_short_segment_count        /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [15:0] dbg_route_h_rx_last_segment_len           /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [15:0] dbg_route_h_rx_min_segment_len            /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [15:0] dbg_route_h_rx_max_segment_len            /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg        dbg_route_h_tx_en                         /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [31:0] dbg_route_h_tx_segment_count              /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [31:0] dbg_route_h_tx_byte_count                 /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [31:0] dbg_route_h_tx_er_segment_count           /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [31:0] dbg_route_h_tx_er_cycle_count             /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [31:0] dbg_route_h_tx_short_segment_count        /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [15:0] dbg_route_h_tx_last_segment_len           /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [15:0] dbg_route_h_tx_min_segment_len            /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;
reg [15:0] dbg_route_h_tx_max_segment_len            /* synthesis PAP_MARK_DEBUG="true" syn_preserve=1 */;

always @(posedge free_clk) begin
    if(!external_rstn) begin
        dbg_route_h_probe_alive    <= 1'b0;
        dbg_route_h_cfg_ingress_u2 <= LINK_TEST_INGRESS_U2;
        dbg_route_h_cfg_egress_sfp1<= LINK_TEST_EGRESS_SFP1;
    end else begin
        dbg_route_h_probe_alive    <= ~dbg_route_h_probe_alive;
        dbg_route_h_cfg_ingress_u2 <= LINK_TEST_INGRESS_U2;
        dbg_route_h_cfg_egress_sfp1<= LINK_TEST_EGRESS_SFP1;
    end
end

always @(posedge route_h_rx_clk or negedge route_h_rx_rstn) begin
    if(!route_h_rx_rstn) begin
        dbg_route_h_rx_link                   <= 1'b0;
        dbg_route_h_rx_frame_count            <= 32'd0;
        dbg_route_h_rx_udp5000_count          <= 32'd0;
        dbg_route_h_rx_fpgv_count             <= 32'd0;
        dbg_route_h_rx_monitor_er_cycle_count <= 32'd0;
        dbg_route_h_rx_last_packet_id         <= 16'd0;
        dbg_route_h_rx_last_packet_total      <= 16'd0;
        dbg_route_h_rx_segment_count          <= 32'd0;
        dbg_route_h_rx_byte_count             <= 32'd0;
        dbg_route_h_rx_er_segment_count       <= 32'd0;
        dbg_route_h_rx_shape_er_cycle_count   <= 32'd0;
        dbg_route_h_rx_short_segment_count    <= 32'd0;
        dbg_route_h_rx_last_segment_len       <= 16'd0;
        dbg_route_h_rx_min_segment_len        <= 16'hffff;
        dbg_route_h_rx_max_segment_len        <= 16'd0;
    end else begin
        dbg_route_h_rx_link                   <= route_h_rx_link;
        dbg_route_h_rx_frame_count            <= raw_route_h_rx_frame_count;
        dbg_route_h_rx_udp5000_count          <= raw_route_h_rx_udp5000_count;
        dbg_route_h_rx_fpgv_count             <= raw_route_h_rx_fpgv_count;
        dbg_route_h_rx_monitor_er_cycle_count <= raw_route_h_rx_monitor_er_cycle_count;
        dbg_route_h_rx_last_packet_id         <= raw_route_h_rx_last_packet_id;
        dbg_route_h_rx_last_packet_total      <= raw_route_h_rx_last_packet_total;
        dbg_route_h_rx_segment_count          <= raw_route_h_rx_segment_count;
        dbg_route_h_rx_byte_count             <= raw_route_h_rx_byte_count;
        dbg_route_h_rx_er_segment_count       <= raw_route_h_rx_er_segment_count;
        dbg_route_h_rx_shape_er_cycle_count   <= raw_route_h_rx_shape_er_cycle_count;
        dbg_route_h_rx_short_segment_count    <= raw_route_h_rx_short_segment_count;
        dbg_route_h_rx_last_segment_len       <= raw_route_h_rx_last_segment_len;
        dbg_route_h_rx_min_segment_len        <= raw_route_h_rx_min_segment_len;
        dbg_route_h_rx_max_segment_len        <= raw_route_h_rx_max_segment_len;
    end
end

always @(posedge route_h_tx_clk or negedge route_h_tx_rstn) begin
    if(!route_h_tx_rstn) begin
        dbg_route_h_tx_en                  <= 1'b0;
        dbg_route_h_tx_segment_count       <= 32'd0;
        dbg_route_h_tx_byte_count          <= 32'd0;
        dbg_route_h_tx_er_segment_count    <= 32'd0;
        dbg_route_h_tx_er_cycle_count      <= 32'd0;
        dbg_route_h_tx_short_segment_count <= 32'd0;
        dbg_route_h_tx_last_segment_len    <= 16'd0;
        dbg_route_h_tx_min_segment_len     <= 16'hffff;
        dbg_route_h_tx_max_segment_len     <= 16'd0;
    end else begin
        dbg_route_h_tx_en                  <= route_h_tx_en;
        dbg_route_h_tx_segment_count       <= raw_route_h_tx_segment_count;
        dbg_route_h_tx_byte_count          <= raw_route_h_tx_byte_count;
        dbg_route_h_tx_er_segment_count    <= raw_route_h_tx_er_segment_count;
        dbg_route_h_tx_er_cycle_count      <= raw_route_h_tx_er_cycle_count;
        dbg_route_h_tx_short_segment_count <= raw_route_h_tx_short_segment_count;
        dbg_route_h_tx_last_segment_len    <= raw_route_h_tx_last_segment_len;
        dbg_route_h_tx_min_segment_len     <= raw_route_h_tx_min_segment_len;
        dbg_route_h_tx_max_segment_len     <= raw_route_h_tx_max_segment_len;
    end
end

gmii_frame_shape_monitor_lite u_dbg_route_h_rx_shape (
    .clk(route_h_rx_clk), .rst_n(route_h_rx_rstn),
    .gmii_rx_dv(route_h_rx_dv), .gmii_rx_er(route_h_rx_er),
    .segment_count(raw_route_h_rx_segment_count),
    .byte_count(raw_route_h_rx_byte_count),
    .er_segment_count(raw_route_h_rx_er_segment_count),
    .er_cycle_count(raw_route_h_rx_shape_er_cycle_count),
    .short_segment_count(raw_route_h_rx_short_segment_count),
    .last_segment_len(raw_route_h_rx_last_segment_len),
    .min_segment_len(raw_route_h_rx_min_segment_len),
    .max_segment_len(raw_route_h_rx_max_segment_len)
);

gmii_frame_shape_monitor_lite u_dbg_route_h_tx_shape (
    .clk(route_h_tx_clk), .rst_n(route_h_tx_rstn),
    .gmii_rx_dv(route_h_tx_en), .gmii_rx_er(route_h_tx_er),
    .segment_count(raw_route_h_tx_segment_count),
    .byte_count(raw_route_h_tx_byte_count),
    .er_segment_count(raw_route_h_tx_er_segment_count),
    .er_cycle_count(raw_route_h_tx_er_cycle_count),
    .short_segment_count(raw_route_h_tx_short_segment_count),
    .last_segment_len(raw_route_h_tx_last_segment_len),
    .min_segment_len(raw_route_h_tx_min_segment_len),
    .max_segment_len(raw_route_h_tx_max_segment_len)
);

// -----------------------------------------------------------------------------
// V5 implementation of the plan's Stage-1/Stage-2/Stage-3 receive debug path.
// This is a pure RX side-band block: it does not change qsgmii_test, YT8614
// init, or gmii_buf transparent forwarding.
// -----------------------------------------------------------------------------
mes_rx_plan_v5_debug #(.LOCAL_MAC(48'h02_00_00_00_50_01), .LOCAL_IP(32'hC0A8_0164), .UDP_PORT(16'd5000), .DIAG_USE_U2_CH2(LINK_TEST_INGRESS_U2)) u_rx_plan_v5_debug (
    .free_clk(free_clk),
    .free_rst_n(external_rstn),
    .link(link),

    .clk_u10_ch0(p0_sgmii_clk_u10), .rstn_u10_ch0(p0_rx_rstn_sync_u10), .rxd_u10_ch0(p0_gmii_rxd_u10), .dv_u10_ch0(p0_gmii_rx_dv_u10), .er_u10_ch0(p0_gmii_rx_er_u10),
    .clk_u10_ch1(p1_sgmii_clk_u10), .rstn_u10_ch1(p1_rx_rstn_sync_u10), .rxd_u10_ch1(p1_gmii_rxd_u10), .dv_u10_ch1(p1_gmii_rx_dv_u10), .er_u10_ch1(p1_gmii_rx_er_u10),
    .clk_u10_ch2(p2_sgmii_clk_u10), .rstn_u10_ch2(p2_rx_rstn_sync_u10), .rxd_u10_ch2(p2_gmii_rxd_u10), .dv_u10_ch2(p2_gmii_rx_dv_u10), .er_u10_ch2(p2_gmii_rx_er_u10),
    .clk_u10_ch3(p3_sgmii_clk_u10), .rstn_u10_ch3(p3_rx_rstn_sync_u10), .rxd_u10_ch3(p3_gmii_rxd_u10), .dv_u10_ch3(p3_gmii_rx_dv_u10), .er_u10_ch3(p3_gmii_rx_er_u10),

    .clk_u2_ch0(p0_sgmii_clk_u2), .rstn_u2_ch0(p0_rx_rstn_sync_u2), .rxd_u2_ch0(p0_gmii_rxd_u2), .dv_u2_ch0(p0_gmii_rx_dv_u2), .er_u2_ch0(p0_gmii_rx_er_u2),
    .clk_u2_ch1(p1_sgmii_clk_u2), .rstn_u2_ch1(p1_rx_rstn_sync_u2), .rxd_u2_ch1(p1_gmii_rxd_u2), .dv_u2_ch1(p1_gmii_rx_dv_u2), .er_u2_ch1(p1_gmii_rx_er_u2),
    .clk_u2_ch2(p2_sgmii_clk_u2), .rstn_u2_ch2(p2_rx_rstn_sync_u2), .rxd_u2_ch2(p2_gmii_rxd_u2), .dv_u2_ch2(p2_gmii_rx_dv_u2), .er_u2_ch2(p2_gmii_rx_er_u2),
    .clk_u2_ch3(p3_sgmii_clk_u2), .rstn_u2_ch3(p3_rx_rstn_sync_u2), .rxd_u2_ch3(p3_gmii_rxd_u2), .dv_u2_ch3(p3_gmii_rx_dv_u2), .er_u2_ch3(p3_gmii_rx_er_u2),

    .rx_activity_live(v5_rx_activity_live),
    .rx_frame_seen(v5_rx_frame_seen),
    .udp5000_seen(v5_udp5000_seen),
    .fpgv_seen(v5_fpgv_seen),
    .rx_error_seen(v5_rx_error_seen),
    .active_channel(v5_active_channel),
    .debug_led(v5_debug_led),
    .diag_selected_ch2_frame_count(raw_route_h_rx_frame_count),
    .diag_selected_ch2_udp5000_count(raw_route_h_rx_udp5000_count),
    .diag_selected_ch2_fpgv_count(raw_route_h_rx_fpgv_count),
    .diag_selected_ch2_er_cycle_count(raw_route_h_rx_monitor_er_cycle_count),
    .diag_selected_ch2_last_packet_id(raw_route_h_rx_last_packet_id),
    .diag_selected_ch2_last_packet_total(raw_route_h_rx_last_packet_total)
);


// -----------------------------------------------------------------------------
// Board LED mapping for the no-DDR3 stream bridge build.
// LED0: free_clk heartbeat
// LED1: any RJ45 link
// LED2: any GMII RX activity now
// LED3: any U10 channel has received at least one frame
// LED4: any U2 channel has received at least one frame
// LED5: UDP dst port 5000 seen
// LED6: FPGV magic seen
// LED7: GMII RX error seen
// -----------------------------------------------------------------------------
// PORT_MATRIX_DIAG_V4_RSTN_SAFE LED mapping follows selected route:
// LED0 = heartbeat
// LED1 = heartbeat copy
// LED2 = selected RJ45 ingress link
// LED3 = selected ingress Ethernet frame seen
// LED4 = selected ingress UDP5000 seen
// LED5 = selected ingress FPGV seen
// LED6 = selected SFP egress TX activity
// LED7 = selected ingress GMII RX error seen
assign led = clean_debug_led;

//qsgmii_sfp1_lane0//////////////////////////////////////////////////////////////////////////////////////////////////////////////
qsgmii_test qsgmii_sfp1_lane0(
//Port0
    //Status Vector
    .p0_status_vector           (p0_status_vector_sfp1       ),//output wire [15:0]   
    //QSGMII Control Bits
    .p0_pin_cfg_en              (1'b1                        ),//input  wire          //Fast Config Enable
    .p0_phy_link                (1'b1                        ),//input  wire          //Link: 1=link up, 0=link down
    .p0_phy_duplex              (1'b1                        ),//input  wire          //Duplex mode: 1=full duplex, 0=half duplex
    .p0_phy_speed               (2'b10                       ),//input  wire [1:0]    //11 = Reserved 10=1000Mbps; 01=100Mbps; 00=10Mbps
    .p0_unidir_en               (1'b0                        ),//input  wire          //Unidir Mode Enable
    .p0_an_restart              (1'b0                        ),//input  wire          //Auto_Negotiation Restart
    .p0_an_enable               (1'b0                        ),//input  wire          //Auto_Negotiation Enable
    .p0_loopback                (1'b0                        ),//input  wire          //QSGMII Port Loopback Enable
    //QSGMII Clock/Clock Enable for Client MAC
    .p0_sgmii_clk               (p0_sgmii_clk_sfp1           ),//output wire          
    .p0_tx_clken                (p0_tx_clken_sfp1            ),//output wire          
    .p0_tx_rstn_sync            (p0_tx_rstn_sync_sfp1        ),//output wire          
    .p0_rx_rstn_sync            (p0_rx_rstn_sync_sfp1        ),//output wire          
    //GMII RX
    .p0_gmii_rxd                (p0_gmii_rxd_sfp1            ),//output wire [7:0]    
    .p0_gmii_rx_dv              (p0_gmii_rx_dv_sfp1          ),//output wire          
    .p0_gmii_rx_er              (p0_gmii_rx_er_sfp1          ),//output wire          
    .p0_receiving               (                            ),//output wire          
    //GMII TX
    .p0_gmii_txd                (p0_gmii_txd_sfp1            ),//input  wire [7:0]    
    .p0_gmii_tx_en              (p0_gmii_tx_en_sfp1          ),//input  wire          
    .p0_gmii_tx_er              (p0_gmii_tx_er_sfp1          ),//input  wire          
    .p0_transmitting            (                            ),//output wire          
//Port1
    //Status Vector
    .p1_status_vector           (p1_status_vector_sfp1       ),//output wire [15:0]   
    //QSGMII Control Bits
    .p1_pin_cfg_en              (1'b1                        ),//input  wire          
    .p1_phy_link                (1'b1                        ),//input  wire          
    .p1_phy_duplex              (1'b1                        ),//input  wire          
    .p1_phy_speed               (2'b10                       ),//input  wire [1:0]    
    .p1_unidir_en               (1'b0                        ),//input  wire          
    .p1_an_restart              (1'b0                        ),//input  wire          
    .p1_an_enable               (1'b0                        ),//input  wire          
    .p1_loopback                (1'b0                        ),//input  wire          
    //QSGMII Clock/Clock Enable for Client MAC
    .p1_sgmii_clk               (p1_sgmii_clk_sfp1           ),//output wire          
    .p1_tx_clken                (p1_tx_clken_sfp1            ),//output wire          
    .p1_tx_rstn_sync            (p1_tx_rstn_sync_sfp1        ),//output wire          
    .p1_rx_rstn_sync            (p1_rx_rstn_sync_sfp1        ),//output wire          
    //GMII RX
    .p1_gmii_rxd                (p1_gmii_rxd_sfp1            ),//output wire [7:0]    
    .p1_gmii_rx_dv              (p1_gmii_rx_dv_sfp1          ),//output wire          
    .p1_gmii_rx_er              (p1_gmii_rx_er_sfp1          ),//output wire          
    .p1_receiving               (                            ),//output wire          
    //GMII TX
    .p1_gmii_txd                (p1_gmii_txd_sfp1            ),//input  wire [7:0]    
    .p1_gmii_tx_en              (p1_gmii_tx_en_sfp1          ),//input  wire          
    .p1_gmii_tx_er              (p1_gmii_tx_er_sfp1          ),//input  wire          
    .p1_transmitting            (                            ),//output wire          
//Port2
    //Status Vector
    .p2_status_vector           (p2_status_vector_sfp1       ),//output wire [15:0]   
    //QSGMII Control Bits
    .p2_pin_cfg_en              (1'b1                        ),//input  wire          
    .p2_phy_link                (1'b1                        ),//input  wire          
    .p2_phy_duplex              (1'b1                        ),//input  wire          
    .p2_phy_speed               (2'b10                       ),//input  wire [1:0]    
    .p2_unidir_en               (1'b0                        ),//input  wire          
    .p2_an_restart              (1'b0                        ),//input  wire          
    .p2_an_enable               (1'b0                        ),//input  wire          
    .p2_loopback                (1'b0                        ),//input  wire          
    //QSGMII Clock/Clock Enable for Client MAC
    .p2_sgmii_clk               (p2_sgmii_clk_sfp1           ),//output wire          
    .p2_tx_clken                (p2_tx_clken_sfp1            ),//output wire          
    .p2_tx_rstn_sync            (p2_tx_rstn_sync_sfp1        ),//output wire          
    .p2_rx_rstn_sync            (p2_rx_rstn_sync_sfp1        ),//output wire          
    //GMII RX
    .p2_gmii_rxd                (p2_gmii_rxd_sfp1            ),//output wire [7:0]    
    .p2_gmii_rx_dv              (p2_gmii_rx_dv_sfp1          ),//output wire          
    .p2_gmii_rx_er              (p2_gmii_rx_er_sfp1          ),//output wire          
    .p2_receiving               (                            ),//output wire          
    //GMII TX
    .p2_gmii_txd                (p2_gmii_txd_sfp1            ),//input  wire [7:0]    
    .p2_gmii_tx_en              (p2_gmii_tx_en_sfp1          ),//input  wire          
    .p2_gmii_tx_er              (p2_gmii_tx_er_sfp1          ),//input  wire          
    .p2_transmitting            (                            ),//output wire          
//Port3
    //Status Vector
    .p3_status_vector           (p3_status_vector_sfp1       ),//output wire [15:0]   
    //QSGMII Control Bits
    .p3_pin_cfg_en              (1'b1                        ),//input  wire          
    .p3_phy_link                (1'b1                        ),//input  wire          
    .p3_phy_duplex              (1'b1                        ),//input  wire          
    .p3_phy_speed               (2'b10                       ),//input  wire [1:0]    
    .p3_unidir_en               (1'b0                        ),//input  wire          
    .p3_an_restart              (1'b0                        ),//input  wire          
    .p3_an_enable               (1'b0                        ),//input  wire          
    .p3_loopback                (1'b0                        ),//input  wire          
    //QSGMII Clock/Clock Enable for Client MAC
    .p3_sgmii_clk               (p3_sgmii_clk_sfp1           ),//output wire          
    .p3_tx_clken                (p3_tx_clken_sfp1            ),//output wire          
    .p3_tx_rstn_sync            (p3_tx_rstn_sync_sfp1        ),//output wire          
    .p3_rx_rstn_sync            (p3_rx_rstn_sync_sfp1        ),//output wire          
    //GMII RX
    .p3_gmii_rxd                (p3_gmii_rxd_sfp1            ),//output wire [7:0]    
    .p3_gmii_rx_dv              (p3_gmii_rx_dv_sfp1          ),//output wire          
    .p3_gmii_rx_er              (p3_gmii_rx_er_sfp1          ),//output wire          
    .p3_receiving               (                            ),//output wire          
    //GMII TX
    .p3_gmii_txd                (p3_gmii_txd_sfp1            ),//input  wire [7:0]    
    .p3_gmii_tx_en              (p3_gmii_tx_en_sfp1          ),//input  wire          
    .p3_gmii_tx_er              (p3_gmii_tx_er_sfp1          ),//input  wire          
    .p3_transmitting            (                            ),//output wire          
//SerDes output
    .txpll_sof_rst_n            (external_rstn               ),//input  wire          
    .hsst_cfg_soft_rstn         (external_rstn               ),//input  wire          
//Reset and free_clk
    .free_clk                   (free_clk                    ),//input  wire  
    .external_rstn              (external_rstn               ),//input  wire          
    .p0_soft_rstn               (external_rstn               ),//input  wire          
    .p1_soft_rstn               (external_rstn               ),//input  wire          
    .p2_soft_rstn               (external_rstn               ),//input  wire          
    .p3_soft_rstn               (external_rstn               ),//input  wire                  
    .qsgmii_tx_rstn             (                            ),//output wire          
    .qsgmii_rx_rstn             (                            ),//output wire               
//hsst_lane0
    .i_loop_dbg_0               (                            ),//output wire [2:0]    
    .o_txlane_done_0            (o_txlane_done_0             ),//input  wire          
    .o_rxlane_done_0            (o_rxlane_done_0             ),//input  wire          
    .o_p_clk2core_tx_0          (o_p_clk2core_tx_0           ),//input  wire          
    .o_p_clk2core_rx_0          (o_p_clk2core_rx_0           ),//input  wire          
    .l0_lsm_synced              (o_p_pcs_lsm_synced_0        ),//input  wire          
    .i_p_cfg_psel               (                            ),//output wire          
    .i_p_cfg_enable             (                            ),//output wire          
    .i_p_cfg_write              (                            ),//output wire          
    .i_p_cfg_addr               (                            ),//output wire [15:0]   
    .i_p_cfg_wdata              (                            ),//output wire [7:0]    
    .o_p_cfg_rdata              (8'b0                        ),//input  wire [7:0]    
    .o_p_cfg_ready              (1'b0                        ),//input  wire          
    .i_txd_0                    (i_txd_0                     ),//output wire [31:0]
    .i_txk_0                    (i_txk_0                     ),//output wire [3:0]
    .i_tdispsel_0               (i_tdispsel_0                ),//output wire [3:0]    
    .i_tdispctrl_0              (i_tdispctrl_0               ),//output wire [3:0]        
    .o_rxd_0                    (o_rxd_0                     ),//input  wire [31:0]
    .o_rxk_0                    (o_rxk_0                     ),//input  wire [3:0] 
    .o_rdisper_0                (o_rdisper_0                 ),//input  wire [3:0]    
    .o_rdecer_0                 (o_rdecer_0                  ) //input  wire [3:0]      
);
//qsgmii_sfp0_lane1//////////////////////////////////////////////////////////////////////////////////////////////////////////////
qsgmii_test qsgmii_sfp0_lane1(
//Port0
    //Status Vector
    .p0_status_vector           (p0_status_vector_sfp0       ),//output wire [15:0]   
    //QSGMII Control Bits
    .p0_pin_cfg_en              (1'b1                        ),//input  wire          //Fast Config Enable
    .p0_phy_link                (1'b1                        ),//input  wire          //Link: 1=link up, 0=link down
    .p0_phy_duplex              (1'b1                        ),//input  wire          //Duplex mode: 1=full duplex, 0=half duplex
    .p0_phy_speed               (2'b10                       ),//input  wire [1:0]    //11 = Reserved 10=1000Mbps; 01=100Mbps; 00=10Mbps
    .p0_unidir_en               (1'b0                        ),//input  wire          //Unidir Mode Enable
    .p0_an_restart              (1'b0                        ),//input  wire          //Auto_Negotiation Restart
    .p0_an_enable               (1'b0                        ),//input  wire          //Auto_Negotiation Enable
    .p0_loopback                (1'b0                        ),//input  wire          //QSGMII Port Loopback Enable
    //QSGMII Clock/Clock Enable for Client MAC
    .p0_sgmii_clk               (p0_sgmii_clk_sfp0           ),//output wire          
    .p0_tx_clken                (p0_tx_clken_sfp0            ),//output wire          
    .p0_tx_rstn_sync            (p0_tx_rstn_sync_sfp0        ),//output wire          
    .p0_rx_rstn_sync            (p0_rx_rstn_sync_sfp0        ),//output wire          
    //GMII RX
    .p0_gmii_rxd                (p0_gmii_rxd_sfp0            ),//output wire [7:0]    
    .p0_gmii_rx_dv              (p0_gmii_rx_dv_sfp0          ),//output wire          
    .p0_gmii_rx_er              (p0_gmii_rx_er_sfp0          ),//output wire          
    .p0_receiving               (                            ),//output wire          
    //GMII TX
    .p0_gmii_txd                (p0_gmii_txd_sfp0            ),//input  wire [7:0]    
    .p0_gmii_tx_en              (p0_gmii_tx_en_sfp0          ),//input  wire          
    .p0_gmii_tx_er              (p0_gmii_tx_er_sfp0          ),//input  wire          
    .p0_transmitting            (                            ),//output wire          
//Port1
    //Status Vector
    .p1_status_vector           (p1_status_vector_sfp0       ),//output wire [15:0]   
    //QSGMII Control Bits
    .p1_pin_cfg_en              (1'b1                        ),//input  wire          
    .p1_phy_link                (1'b1                        ),//input  wire          
    .p1_phy_duplex              (1'b1                        ),//input  wire          
    .p1_phy_speed               (2'b10                       ),//input  wire [1:0]    
    .p1_unidir_en               (1'b0                        ),//input  wire          
    .p1_an_restart              (1'b0                        ),//input  wire          
    .p1_an_enable               (1'b0                        ),//input  wire          
    .p1_loopback                (1'b0                        ),//input  wire          
    //QSGMII Clock/Clock Enable for Client MAC
    .p1_sgmii_clk               (p1_sgmii_clk_sfp0           ),//output wire          
    .p1_tx_clken                (p1_tx_clken_sfp0            ),//output wire          
    .p1_tx_rstn_sync            (p1_tx_rstn_sync_sfp0        ),//output wire          
    .p1_rx_rstn_sync            (p1_rx_rstn_sync_sfp0        ),//output wire          
    //GMII RX
    .p1_gmii_rxd                (p1_gmii_rxd_sfp0            ),//output wire [7:0]    
    .p1_gmii_rx_dv              (p1_gmii_rx_dv_sfp0          ),//output wire          
    .p1_gmii_rx_er              (p1_gmii_rx_er_sfp0          ),//output wire          
    .p1_receiving               (                            ),//output wire          
    //GMII TX
    .p1_gmii_txd                (p1_gmii_txd_sfp0            ),//input  wire [7:0]    
    .p1_gmii_tx_en              (p1_gmii_tx_en_sfp0          ),//input  wire          
    .p1_gmii_tx_er              (p1_gmii_tx_er_sfp0          ),//input  wire          
    .p1_transmitting            (                            ),//output wire          
//Port2
    //Status Vector
    .p2_status_vector           (p2_status_vector_sfp0       ),//output wire [15:0]   
    //QSGMII Control Bits
    .p2_pin_cfg_en              (1'b1                        ),//input  wire          
    .p2_phy_link                (1'b1                        ),//input  wire          
    .p2_phy_duplex              (1'b1                        ),//input  wire          
    .p2_phy_speed               (2'b10                       ),//input  wire [1:0]    
    .p2_unidir_en               (1'b0                        ),//input  wire          
    .p2_an_restart              (1'b0                        ),//input  wire          
    .p2_an_enable               (1'b0                        ),//input  wire          
    .p2_loopback                (1'b0                        ),//input  wire          
    //QSGMII Clock/Clock Enable for Client MAC
    .p2_sgmii_clk               (p2_sgmii_clk_sfp0           ),//output wire          
    .p2_tx_clken                (p2_tx_clken_sfp0            ),//output wire          
    .p2_tx_rstn_sync            (p2_tx_rstn_sync_sfp0        ),//output wire          
    .p2_rx_rstn_sync            (p2_rx_rstn_sync_sfp0        ),//output wire          
    //GMII RX
    .p2_gmii_rxd                (p2_gmii_rxd_sfp0            ),//output wire [7:0]    
    .p2_gmii_rx_dv              (p2_gmii_rx_dv_sfp0          ),//output wire          
    .p2_gmii_rx_er              (p2_gmii_rx_er_sfp0          ),//output wire          
    .p2_receiving               (                            ),//output wire          
    //GMII TX
    .p2_gmii_txd                (p2_gmii_txd_sfp0            ),//input  wire [7:0]    
    .p2_gmii_tx_en              (p2_gmii_tx_en_sfp0          ),//input  wire          
    .p2_gmii_tx_er              (p2_gmii_tx_er_sfp0          ),//input  wire          
    .p2_transmitting            (                            ),//output wire          
//Port3
    //Status Vector
    .p3_status_vector           (p3_status_vector_sfp0       ),//output wire [15:0]   
    //QSGMII Control Bits
    .p3_pin_cfg_en              (1'b1                        ),//input  wire          
    .p3_phy_link                (1'b1                        ),//input  wire          
    .p3_phy_duplex              (1'b1                        ),//input  wire          
    .p3_phy_speed               (2'b10                       ),//input  wire [1:0]    
    .p3_unidir_en               (1'b0                        ),//input  wire          
    .p3_an_restart              (1'b0                        ),//input  wire          
    .p3_an_enable               (1'b0                        ),//input  wire          
    .p3_loopback                (1'b0                        ),//input  wire          
    //QSGMII Clock/Clock Enable for Client MAC
    .p3_sgmii_clk               (p3_sgmii_clk_sfp0           ),//output wire          
    .p3_tx_clken                (p3_tx_clken_sfp0            ),//output wire          
    .p3_tx_rstn_sync            (p3_tx_rstn_sync_sfp0        ),//output wire          
    .p3_rx_rstn_sync            (p3_rx_rstn_sync_sfp0        ),//output wire          
    //GMII RX
    .p3_gmii_rxd                (p3_gmii_rxd_sfp0            ),//output wire [7:0]    
    .p3_gmii_rx_dv              (p3_gmii_rx_dv_sfp0          ),//output wire          
    .p3_gmii_rx_er              (p3_gmii_rx_er_sfp0          ),//output wire          
    .p3_receiving               (                            ),//output wire          
    //GMII TX
    .p3_gmii_txd                (p3_gmii_txd_sfp0            ),//input  wire [7:0]    
    .p3_gmii_tx_en              (p3_gmii_tx_en_sfp0          ),//input  wire          
    .p3_gmii_tx_er              (p3_gmii_tx_er_sfp0          ),//input  wire          
    .p3_transmitting            (                            ),//output wire          
//SerDes output
    .txpll_sof_rst_n            (external_rstn               ),//input  wire          
    .hsst_cfg_soft_rstn         (external_rstn               ),//input  wire          
//Reset and free_clk
    .free_clk                   (free_clk                    ),//input  wire  
    .external_rstn              (external_rstn               ),//input  wire          
    .p0_soft_rstn               (external_rstn               ),//input  wire          
    .p1_soft_rstn               (external_rstn               ),//input  wire          
    .p2_soft_rstn               (external_rstn               ),//input  wire          
    .p3_soft_rstn               (external_rstn               ),//input  wire                  
    .qsgmii_tx_rstn             (                            ),//output wire          
    .qsgmii_rx_rstn             (                            ),//output wire               
//hsst_lane1
    .i_loop_dbg_0               (                            ),//output wire [2:0]    
    .o_txlane_done_0            (o_txlane_done_1             ),//input  wire          
    .o_rxlane_done_0            (o_rxlane_done_1             ),//input  wire          
    .o_p_clk2core_tx_0          (o_p_clk2core_tx_1           ),//input  wire          
    .o_p_clk2core_rx_0          (o_p_clk2core_rx_1           ),//input  wire          
    .l0_lsm_synced              (o_p_pcs_lsm_synced_1        ),//input  wire          
    .i_p_cfg_psel               (                            ),//output wire          
    .i_p_cfg_enable             (                            ),//output wire          
    .i_p_cfg_write              (                            ),//output wire          
    .i_p_cfg_addr               (                            ),//output wire [15:0]   
    .i_p_cfg_wdata              (                            ),//output wire [7:0]    
    .o_p_cfg_rdata              (8'b0                        ),//input  wire [7:0]    
    .o_p_cfg_ready              (1'b0                        ),//input  wire          
    .i_txd_0                    (i_txd_1                     ),//output wire [31:0]
    .i_txk_0                    (i_txk_1                     ),//output wire [3:0]
    .i_tdispsel_0               (i_tdispsel_1                ),//output wire [3:0]    
    .i_tdispctrl_0              (i_tdispctrl_1               ),//output wire [3:0]        
    .o_rxd_0                    (o_rxd_1                     ),//input  wire [31:0]
    .o_rxk_0                    (o_rxk_1                     ),//input  wire [3:0] 
    .o_rdisper_0                (o_rdisper_1                 ),//input  wire [3:0]    
    .o_rdecer_0                 (o_rdecer_1                  ) //input  wire [3:0]      
);

//qsgmii_U10_lane2///////////////////////////////////////////////////////////////////////////////////////////////////////////////
qsgmii_test qsgmii_u10_lane2(
//Port0
    //Status Vector
    .p0_status_vector           (p0_status_vector_u10        ),//output wire [15:0]   
    //QSGMII Control Bits
    .p0_pin_cfg_en              (1'b0                        ),//input  wire          //Fast Config Enable
    .p0_phy_link                (1'b1                        ),//input  wire          //Link: 1=link up, 0=link down
    .p0_phy_duplex              (1'b1                        ),//input  wire          //Duplex mode: 1=full duplex, 0=half duplex
    .p0_phy_speed               (2'b10                       ),//input  wire [1:0]    //11 = Reserved 10=1000Mbps; 01=100Mbps; 00=10Mbps
    .p0_unidir_en               (1'b0                        ),//input  wire          //Unidir Mode Enable
    .p0_an_restart              (1'b0                        ),//input  wire          //Auto_Negotiation Restart
    .p0_an_enable               (1'b1                        ),//input  wire          //Auto_Negotiation Enable
    .p0_loopback                (1'b0                        ),//input  wire          //QSGMII Port Loopback Enable
    //QSGMII Clock/Clock Enable for Client MAC
    .p0_sgmii_clk               (p0_sgmii_clk_u10            ),//output wire          
    .p0_tx_clken                (p0_tx_clken_u10             ),//output wire          
    .p0_tx_rstn_sync            (p0_tx_rstn_sync_u10         ),//output wire          
    .p0_rx_rstn_sync            (p0_rx_rstn_sync_u10         ),//output wire          
    //GMII RX
    .p0_gmii_rxd                (p0_gmii_rxd_u10             ),//output wire [7:0]    
    .p0_gmii_rx_dv              (p0_gmii_rx_dv_u10           ),//output wire          
    .p0_gmii_rx_er              (p0_gmii_rx_er_u10           ),//output wire          
    .p0_receiving               (                            ),//output wire          
    //GMII TX
    .p0_gmii_txd                (p0_gmii_txd_u10             ),//input  wire [7:0]    
    .p0_gmii_tx_en              (p0_gmii_tx_en_u10           ),//input  wire          
    .p0_gmii_tx_er              (p0_gmii_tx_er_u10           ),//input  wire          
    .p0_transmitting            (                            ),//output wire          
//Port1
    //Status Vector
    .p1_status_vector           (p1_status_vector_u10        ),//output wire [15:0]   
    //QSGMII Control Bits
    .p1_pin_cfg_en              (1'b0                        ),//input  wire          
    .p1_phy_link                (1'b1                        ),//input  wire          
    .p1_phy_duplex              (1'b1                        ),//input  wire          
    .p1_phy_speed               (2'b10                       ),//input  wire [1:0]    
    .p1_unidir_en               (1'b0                        ),//input  wire          
    .p1_an_restart              (1'b0                        ),//input  wire          
    .p1_an_enable               (1'b1                        ),//input  wire          
    .p1_loopback                (1'b0                        ),//input  wire          
    //QSGMII Clock/Clock Enable for Client MAC
    .p1_sgmii_clk               (p1_sgmii_clk_u10            ),//output wire          
    .p1_tx_clken                (p1_tx_clken_u10             ),//output wire          
    .p1_tx_rstn_sync            (p1_tx_rstn_sync_u10         ),//output wire          
    .p1_rx_rstn_sync            (p1_rx_rstn_sync_u10         ),//output wire          
    //GMII RX
    .p1_gmii_rxd                (p1_gmii_rxd_u10             ),//output wire [7:0]    
    .p1_gmii_rx_dv              (p1_gmii_rx_dv_u10           ),//output wire          
    .p1_gmii_rx_er              (p1_gmii_rx_er_u10           ),//output wire          
    .p1_receiving               (                            ),//output wire          
    //GMII TX
    .p1_gmii_txd                (p1_gmii_txd_u10             ),//input  wire [7:0]    
    .p1_gmii_tx_en              (p1_gmii_tx_en_u10           ),//input  wire          
    .p1_gmii_tx_er              (p1_gmii_tx_er_u10           ),//input  wire          
    .p1_transmitting            (                            ),//output wire          
//Port2
    //Status Vector
    .p2_status_vector           (p2_status_vector_u10        ),//output wire [15:0]   
    //QSGMII Control Bits
    .p2_pin_cfg_en              (1'b0                        ),//input  wire          
    .p2_phy_link                (1'b1                        ),//input  wire          
    .p2_phy_duplex              (1'b1                        ),//input  wire          
    .p2_phy_speed               (2'b10                       ),//input  wire [1:0]    
    .p2_unidir_en               (1'b0                        ),//input  wire          
    .p2_an_restart              (1'b0                        ),//input  wire          
    .p2_an_enable               (1'b1                        ),//input  wire          
    .p2_loopback                (1'b0                        ),//input  wire          
    //QSGMII Clock/Clock Enable for Client MAC
    .p2_sgmii_clk               (p2_sgmii_clk_u10            ),//output wire          
    .p2_tx_clken                (p2_tx_clken_u10             ),//output wire          
    .p2_tx_rstn_sync            (p2_tx_rstn_sync_u10         ),//output wire          
    .p2_rx_rstn_sync            (p2_rx_rstn_sync_u10         ),//output wire          
    //GMII RX
    .p2_gmii_rxd                (p2_gmii_rxd_u10             ),//output wire [7:0]    
    .p2_gmii_rx_dv              (p2_gmii_rx_dv_u10           ),//output wire          
    .p2_gmii_rx_er              (p2_gmii_rx_er_u10           ),//output wire          
    .p2_receiving               (                            ),//output wire          
    //GMII TX
    .p2_gmii_txd                (p2_gmii_txd_u10             ),//input  wire [7:0]    
    .p2_gmii_tx_en              (p2_gmii_tx_en_u10           ),//input  wire          
    .p2_gmii_tx_er              (p2_gmii_tx_er_u10           ),//input  wire          
    .p2_transmitting            (                            ),//output wire          
//Port3
    //Status Vector
    .p3_status_vector           (p3_status_vector_u10        ),//output wire [15:0]   
    //QSGMII Control Bits
    .p3_pin_cfg_en              (1'b0                        ),//input  wire          
    .p3_phy_link                (1'b1                        ),//input  wire          
    .p3_phy_duplex              (1'b1                        ),//input  wire          
    .p3_phy_speed               (2'b10                       ),//input  wire [1:0]    
    .p3_unidir_en               (1'b0                        ),//input  wire          
    .p3_an_restart              (1'b0                        ),//input  wire          
    .p3_an_enable               (1'b1                        ),//input  wire          
    .p3_loopback                (1'b0                        ),//input  wire          
    //QSGMII Clock/Clock Enable for Client MAC
    .p3_sgmii_clk               (p3_sgmii_clk_u10            ),//output wire          
    .p3_tx_clken                (p3_tx_clken_u10             ),//output wire          
    .p3_tx_rstn_sync            (p3_tx_rstn_sync_u10         ),//output wire          
    .p3_rx_rstn_sync            (p3_rx_rstn_sync_u10         ),//output wire          
    //GMII RX
    .p3_gmii_rxd                (p3_gmii_rxd_u10             ),//output wire [7:0]    
    .p3_gmii_rx_dv              (p3_gmii_rx_dv_u10           ),//output wire          
    .p3_gmii_rx_er              (p3_gmii_rx_er_u10           ),//output wire          
    .p3_receiving               (                            ),//output wire          
    //GMII TX
    .p3_gmii_txd                (p3_gmii_txd_u10             ),//input  wire [7:0]    
    .p3_gmii_tx_en              (p3_gmii_tx_en_u10           ),//input  wire          
    .p3_gmii_tx_er              (p3_gmii_tx_er_u10           ),//input  wire          
    .p3_transmitting            (                            ),//output wire          
//SerDes output
    .txpll_sof_rst_n            (external_rstn               ),//input  wire          
    .hsst_cfg_soft_rstn         (external_rstn               ),//input  wire          
//Reset and free_clk
    .free_clk                   (free_clk                    ),//input  wire  
    .external_rstn              (external_rstn               ),//input  wire          
    .p0_soft_rstn               (external_rstn               ),//input  wire          
    .p1_soft_rstn               (external_rstn               ),//input  wire          
    .p2_soft_rstn               (external_rstn               ),//input  wire          
    .p3_soft_rstn               (external_rstn               ),//input  wire                  
    .qsgmii_tx_rstn             (                            ),//output wire          
    .qsgmii_rx_rstn             (                            ),//output wire          
//hsst_lane2
    .i_loop_dbg_0               (                            ),//output wire [2:0]    
    .o_txlane_done_0            (o_txlane_done_2             ),//input  wire          
    .o_rxlane_done_0            (o_rxlane_done_2             ),//input  wire          
    .o_p_clk2core_tx_0          (o_p_clk2core_tx_2           ),//input  wire          
    .o_p_clk2core_rx_0          (o_p_clk2core_rx_2           ),//input  wire          
    .l0_lsm_synced              (o_p_pcs_lsm_synced_2        ),//input  wire          
    .i_p_cfg_psel               (                            ),//output wire          
    .i_p_cfg_enable             (                            ),//output wire          
    .i_p_cfg_write              (                            ),//output wire          
    .i_p_cfg_addr               (                            ),//output wire [15:0]   
    .i_p_cfg_wdata              (                            ),//output wire [7:0]    
    .o_p_cfg_rdata              (8'b0                        ),//input  wire [7:0]    
    .o_p_cfg_ready              (1'b0                        ),//input  wire          
    .i_txd_0                    (i_txd_2                     ),//output wire [31:0]
    .i_txk_0                    (i_txk_2                     ),//output wire [3:0] 
    .i_tdispsel_0               (i_tdispsel_2                ),//output wire [3:0] 
    .i_tdispctrl_0              (i_tdispctrl_2               ),//output wire [3:0]   
    .o_rxd_0                    (o_rxd_2                     ),//input  wire [31:0]
    .o_rxk_0                    (o_rxk_2                     ),//input  wire [3:0] 
    .o_rdisper_0                (o_rdisper_2                 ),//input  wire [3:0] 
    .o_rdecer_0                 (o_rdecer_2                  ) //input  wire [3:0] 
);
//qsgmii_U2_lane3///////////////////////////////////////////////////////////////////////////////////////////////////////////////
qsgmii_test qsgmii_u2_lane3(
//Port0
    //Status Vector
    .p0_status_vector           (p0_status_vector_u2         ),//output wire [15:0]   
    //QSGMII Control Bits
    .p0_pin_cfg_en              (1'b0                        ),//input  wire          //Fast Config Enable
    .p0_phy_link                (1'b1                        ),//input  wire          //Link: 1=link up, 0=link down
    .p0_phy_duplex              (1'b1                        ),//input  wire          //Duplex mode: 1=full duplex, 0=half duplex
    .p0_phy_speed               (2'b10                       ),//input  wire [1:0]    //11 = Reserved 10=1000Mbps; 01=100Mbps; 00=10Mbps
    .p0_unidir_en               (1'b0                        ),//input  wire          //Unidir Mode Enable
    .p0_an_restart              (1'b0                        ),//input  wire          //Auto_Negotiation Restart
    .p0_an_enable               (1'b1                        ),//input  wire          //Auto_Negotiation Enable
    .p0_loopback                (1'b0                        ),//input  wire          //QSGMII Port Loopback Enable
    //QSGMII Clock/Clock Enable for Client MAC
    .p0_sgmii_clk               (p0_sgmii_clk_u2             ),//output wire          
    .p0_tx_clken                (p0_tx_clken_u2              ),//output wire          
    .p0_tx_rstn_sync            (p0_tx_rstn_sync_u2          ),//output wire          
    .p0_rx_rstn_sync            (p0_rx_rstn_sync_u2          ),//output wire          
    //GMII RX
    .p0_gmii_rxd                (p0_gmii_rxd_u2              ),//output wire [7:0]    
    .p0_gmii_rx_dv              (p0_gmii_rx_dv_u2            ),//output wire          
    .p0_gmii_rx_er              (p0_gmii_rx_er_u2            ),//output wire          
    .p0_receiving               (                            ),//output wire          
    //GMII TX
    .p0_gmii_txd                (p0_gmii_txd_u2              ),//input  wire [7:0]    
    .p0_gmii_tx_en              (p0_gmii_tx_en_u2            ),//input  wire          
    .p0_gmii_tx_er              (p0_gmii_tx_er_u2            ),//input  wire          
    .p0_transmitting            (                            ),//output wire          
//Port1
    //Status Vector
    .p1_status_vector           (p1_status_vector_u2         ),//output wire [15:0]   
    //QSGMII Control Bits
    .p1_pin_cfg_en              (1'b0                        ),//input  wire          
    .p1_phy_link                (1'b1                        ),//input  wire          
    .p1_phy_duplex              (1'b1                        ),//input  wire          
    .p1_phy_speed               (2'b10                       ),//input  wire [1:0]    
    .p1_unidir_en               (1'b0                        ),//input  wire          
    .p1_an_restart              (1'b0                        ),//input  wire          
    .p1_an_enable               (1'b1                        ),//input  wire          
    .p1_loopback                (1'b0                        ),//input  wire          
    //QSGMII Clock/Clock Enable for Client MAC
    .p1_sgmii_clk               (p1_sgmii_clk_u2             ),//output wire          
    .p1_tx_clken                (p1_tx_clken_u2              ),//output wire          
    .p1_tx_rstn_sync            (p1_tx_rstn_sync_u2          ),//output wire          
    .p1_rx_rstn_sync            (p1_rx_rstn_sync_u2          ),//output wire          
    //GMII RX
    .p1_gmii_rxd                (p1_gmii_rxd_u2              ),//output wire [7:0]    
    .p1_gmii_rx_dv              (p1_gmii_rx_dv_u2            ),//output wire          
    .p1_gmii_rx_er              (p1_gmii_rx_er_u2            ),//output wire          
    .p1_receiving               (                            ),//output wire          
    //GMII TX
    .p1_gmii_txd                (p1_gmii_txd_u2              ),//input  wire [7:0]    
    .p1_gmii_tx_en              (p1_gmii_tx_en_u2            ),//input  wire          
    .p1_gmii_tx_er              (p1_gmii_tx_er_u2            ),//input  wire          
    .p1_transmitting            (                            ),//output wire          
//Port2
    //Status Vector
    .p2_status_vector           (p2_status_vector_u2         ),//output wire [15:0]   
    //QSGMII Control Bits
    .p2_pin_cfg_en              (1'b0                        ),//input  wire          
    .p2_phy_link                (1'b1                        ),//input  wire          
    .p2_phy_duplex              (1'b1                        ),//input  wire          
    .p2_phy_speed               (2'b10                       ),//input  wire [1:0]    
    .p2_unidir_en               (1'b0                        ),//input  wire          
    .p2_an_restart              (1'b0                        ),//input  wire          
    .p2_an_enable               (1'b1                        ),//input  wire          
    .p2_loopback                (1'b0                        ),//input  wire          
    //QSGMII Clock/Clock Enable for Client MAC
    .p2_sgmii_clk               (p2_sgmii_clk_u2             ),//output wire          
    .p2_tx_clken                (p2_tx_clken_u2              ),//output wire          
    .p2_tx_rstn_sync            (p2_tx_rstn_sync_u2          ),//output wire          
    .p2_rx_rstn_sync            (p2_rx_rstn_sync_u2          ),//output wire          
    //GMII RX
    .p2_gmii_rxd                (p2_gmii_rxd_u2              ),//output wire [7:0]    
    .p2_gmii_rx_dv              (p2_gmii_rx_dv_u2            ),//output wire          
    .p2_gmii_rx_er              (p2_gmii_rx_er_u2            ),//output wire          
    .p2_receiving               (                            ),//output wire          
    //GMII TX
    .p2_gmii_txd                (p2_gmii_txd_u2              ),//input  wire [7:0]    
    .p2_gmii_tx_en              (p2_gmii_tx_en_u2            ),//input  wire          
    .p2_gmii_tx_er              (p2_gmii_tx_er_u2            ),//input  wire          
    .p2_transmitting            (                            ),//output wire          
//Port3
    //Status Vector
    .p3_status_vector           (p3_status_vector_u2         ),//output wire [15:0]   
    //QSGMII Control Bits
    .p3_pin_cfg_en              (1'b0                        ),//input  wire          
    .p3_phy_link                (1'b1                        ),//input  wire          
    .p3_phy_duplex              (1'b1                        ),//input  wire          
    .p3_phy_speed               (2'b10                       ),//input  wire [1:0]    
    .p3_unidir_en               (1'b0                        ),//input  wire          
    .p3_an_restart              (1'b0                        ),//input  wire          
    .p3_an_enable               (1'b1                        ),//input  wire          
    .p3_loopback                (1'b0                        ),//input  wire          
    //QSGMII Clock/Clock Enable for Client MAC
    .p3_sgmii_clk               (p3_sgmii_clk_u2             ),//output wire          
    .p3_tx_clken                (p3_tx_clken_u2              ),//output wire          
    .p3_tx_rstn_sync            (p3_tx_rstn_sync_u2          ),//output wire          
    .p3_rx_rstn_sync            (p3_rx_rstn_sync_u2          ),//output wire          
    //GMII RX
    .p3_gmii_rxd                (p3_gmii_rxd_u2              ),//output wire [7:0]    
    .p3_gmii_rx_dv              (p3_gmii_rx_dv_u2            ),//output wire          
    .p3_gmii_rx_er              (p3_gmii_rx_er_u2            ),//output wire          
    .p3_receiving               (                            ),//output wire          
    //GMII TX
    .p3_gmii_txd                (p3_gmii_txd_u2              ),//input  wire [7:0]    
    .p3_gmii_tx_en              (p3_gmii_tx_en_u2            ),//input  wire          
    .p3_gmii_tx_er              (p3_gmii_tx_er_u2            ),//input  wire          
    .p3_transmitting            (                            ),//output wire          
//SerDes output
    .txpll_sof_rst_n            (external_rstn               ),//input  wire          
    .hsst_cfg_soft_rstn         (external_rstn               ),//input  wire          
//Reset and free_clk
    .free_clk                   (free_clk                    ),//input  wire  
    .external_rstn              (external_rstn               ),//input  wire          
    .p0_soft_rstn               (external_rstn               ),//input  wire          
    .p1_soft_rstn               (external_rstn               ),//input  wire          
    .p2_soft_rstn               (external_rstn               ),//input  wire          
    .p3_soft_rstn               (external_rstn               ),//input  wire                  
    .qsgmii_tx_rstn             (                            ),//output wire          
    .qsgmii_rx_rstn             (                            ),//output wire               
//hsst_lane3
    .i_loop_dbg_0               (                            ),//output wire [2:0]    
    .o_txlane_done_0            (o_txlane_done_3             ),//input  wire          
    .o_rxlane_done_0            (o_rxlane_done_3             ),//input  wire          
    .o_p_clk2core_tx_0          (o_p_clk2core_tx_3           ),//input  wire          
    .o_p_clk2core_rx_0          (o_p_clk2core_rx_3           ),//input  wire          
    .l0_lsm_synced              (o_p_pcs_lsm_synced_3        ),//input  wire          
    .i_p_cfg_psel               (                            ),//output wire          
    .i_p_cfg_enable             (                            ),//output wire          
    .i_p_cfg_write              (                            ),//output wire          
    .i_p_cfg_addr               (                            ),//output wire [15:0]   
    .i_p_cfg_wdata              (                            ),//output wire [7:0]    
    .o_p_cfg_rdata              (8'b0                        ),//input  wire [7:0]    
    .o_p_cfg_ready              (1'b0                        ),//input  wire          
    .i_txd_0                    (i_txd_3                     ),//output wire [31:0]
    .i_txk_0                    (i_txk_3                     ),//output wire [3:0]
    .i_tdispsel_0               (i_tdispsel_3                ),//output wire [3:0]    
    .i_tdispctrl_0              (i_tdispctrl_3               ),//output wire [3:0]        
    .o_rxd_0                    (o_rxd_3                     ),//input  wire [31:0]
    .o_rxk_0                    (o_rxk_3                     ),//input  wire [3:0] 
    .o_rdisper_0                (o_rdisper_3                 ),//input  wire [3:0]    
    .o_rdecer_0                 (o_rdecer_3                  ) //input  wire [3:0]      
);

//hsst/////////////////////////////////////////////////////////////////////////////////////////////////////////////
hsst_test u_hsst_test (   
    .i_free_clk                 (free_clk                    ),//input          
    .i_pll_rst_0                (~external_rstn              ),//input           
    .i_wtchdg_clr_0             (~external_rstn              ),//input          
    .o_wtchdg_st_0              (                            ),//output [1:0]   
    .o_pll_done_0               (                            ),//output         
    .o_txlane_done_0            (o_txlane_done_0             ),//output         
    .o_txlane_done_1            (o_txlane_done_1             ),//output         
    .o_txlane_done_2            (o_txlane_done_2             ),//output         
    .o_txlane_done_3            (o_txlane_done_3             ),//output         
    .o_rxlane_done_0            (o_rxlane_done_0             ),//output         
    .o_rxlane_done_1            (o_rxlane_done_1             ),//output         
    .o_rxlane_done_2            (o_rxlane_done_2             ),//output         
    .o_rxlane_done_3            (o_rxlane_done_3             ),//output         
    .o_p_clk2core_tx_0          (o_p_clk2core_tx_0           ),//output         
    .o_p_clk2core_tx_1          (o_p_clk2core_tx_1           ),//output         
    .o_p_clk2core_tx_2          (o_p_clk2core_tx_2           ),//output         
    .o_p_clk2core_tx_3          (o_p_clk2core_tx_3           ),//output         
    .i_p_tx0_clk_fr_core        (o_p_clk2core_tx_0           ),//input          
    .i_p_tx1_clk_fr_core        (o_p_clk2core_tx_1           ),//input          
    .i_p_tx2_clk_fr_core        (o_p_clk2core_tx_2           ),//input          
    .i_p_tx3_clk_fr_core        (o_p_clk2core_tx_3           ),//input          
    .o_p_clk2core_rx_0          (o_p_clk2core_rx_0           ),//output         
    .o_p_clk2core_rx_1          (o_p_clk2core_rx_1           ),//output         
    .o_p_clk2core_rx_2          (o_p_clk2core_rx_2           ),//output         
    .o_p_clk2core_rx_3          (o_p_clk2core_rx_3           ),//output         
    .i_p_rx0_clk_fr_core        (o_p_clk2core_rx_0           ),//input          
    .i_p_rx1_clk_fr_core        (o_p_clk2core_rx_1           ),//input          
    .i_p_rx2_clk_fr_core        (o_p_clk2core_rx_2           ),//input          
    .i_p_rx3_clk_fr_core        (o_p_clk2core_rx_3           ),//input

    .o_p_pll_lock_0             (                            ),//output         
    .o_p_rx_sigdet_sta_0        (                            ),//output         
    .o_p_rx_sigdet_sta_1        (                            ),//output         
    .o_p_rx_sigdet_sta_2        (                            ),//output         
    .o_p_rx_sigdet_sta_3        (                            ),//output         
    .o_p_lx_cdr_align_0         (                            ),//output         
    .o_p_lx_cdr_align_1         (                            ),//output         
    .o_p_lx_cdr_align_2         (                            ),//output         
    .o_p_lx_cdr_align_3         (                            ),//output         
    .o_p_pcs_lsm_synced_0       (o_p_pcs_lsm_synced_0        ),//output         
    .o_p_pcs_lsm_synced_1       (o_p_pcs_lsm_synced_1        ),//output         
    .o_p_pcs_lsm_synced_2       (o_p_pcs_lsm_synced_2        ),//output         
    .o_p_pcs_lsm_synced_3       (o_p_pcs_lsm_synced_3        ),//output
//
    .i_p_refckn_0               (i_p_refckn_0                ),//input          
    .i_p_refckp_0               (i_p_refckp_0                ),//input          
    .i_p_l0rxn                  (i_p_l0rxn                   ),//input          
    .i_p_l0rxp                  (i_p_l0rxp                   ),//input          
    .i_p_l1rxn                  (i_p_l1rxn                   ),//input          
    .i_p_l1rxp                  (i_p_l1rxp                   ),//input          
    .i_p_l2rxn                  (i_p_l2rxn                   ),//input          
    .i_p_l2rxp                  (i_p_l2rxp                   ),//input          
    .i_p_l3rxn                  (i_p_l3rxn                   ),//input          
    .i_p_l3rxp                  (i_p_l3rxp                   ),//input          
    .o_p_l0txn                  (o_p_l0txn                   ),//output         
    .o_p_l0txp                  (o_p_l0txp                   ),//output         
    .o_p_l1txn                  (o_p_l1txn                   ),//output         
    .o_p_l1txp                  (o_p_l1txp                   ),//output         
    .o_p_l2txn                  (o_p_l2txn                   ),//output         
    .o_p_l2txp                  (o_p_l2txp                   ),//output         
    .o_p_l3txn                  (o_p_l3txn                   ),//output         
    .o_p_l3txp                  (o_p_l3txp                   ),//output
//hsst_tx
    .i_txd_0                    (i_txd_0                     ),//input  [31:0]      i_txd_0          
    .i_txk_0                    (i_txk_0                     ),//input  [3:0]       i_txk_0          
    .i_tdispsel_0               (i_tdispsel_0                ),//input  [3:0]       i_tdispsel_0     
    .i_tdispctrl_0              (i_tdispctrl_0               ),//input  [3:0]       i_tdispctrl_0    
                                                                                                                 
    .i_txd_1                    (i_txd_1                     ),//input  [31:0]      i_txd_1          
    .i_txk_1                    (i_txk_1                     ),//input  [3:0]       i_txk_1          
    .i_tdispsel_1               (i_tdispsel_1                ),//input  [3:0]       i_tdispsel_1     
    .i_tdispctrl_1              (i_tdispctrl_1               ),//input  [3:0]       i_tdispctrl_1    
                                                                                                                 
    .i_txd_2                    (i_txd_2                     ),//input  [31:0]      i_txd_2          
    .i_txk_2                    (i_txk_2                     ),//input  [3:0]       i_txk_2          
    .i_tdispsel_2               (i_tdispsel_2                ),//input  [3:0]       i_tdispsel_2     
    .i_tdispctrl_2              (i_tdispctrl_2               ),//input  [3:0]       i_tdispctrl_2    
                                                                                                                 
    .i_txd_3                    (i_txd_3                     ),//input  [31:0]      i_txd_3          
    .i_txk_3                    (i_txk_3                     ),//input  [3:0]       i_txk_3          
    .i_tdispsel_3               (i_tdispsel_3                ),//input  [3:0]       i_tdispsel_3     
    .i_tdispctrl_3              (i_tdispctrl_3               ),//input  [3:0]       i_tdispctrl_3     
//hsst_rx                                                                                                        
    .o_rxd_0                    (o_rxd_0                     ),//output [31:0]      o_rxd_0          
    .o_rxk_0                    (o_rxk_0                     ),//output [3:0]       o_rxk_0          
    .o_rxstatus_0               (                            ),//output [2:0]                          
    .o_rdisper_0                (o_rdisper_0                 ),//output [3:0]       o_rdisper_0      
    .o_rdecer_0                 (o_rdecer_0                  ),//output [3:0]       o_rdecer_0       
                                                                                                                 
    .o_rxd_1                    (o_rxd_1                     ),//output [31:0]      o_rxd_1          
    .o_rxk_1                    (o_rxk_1                     ),//output [3:0]       o_rxk_1          
    .o_rxstatus_1               (                            ),//output [2:0]                        
    .o_rdisper_1                (o_rdisper_1                 ),//output [3:0]       o_rdisper_1      
    .o_rdecer_1                 (o_rdecer_1                  ),//output [3:0]       o_rdecer_1       
                                                                                                                 
    .o_rxd_2                    (o_rxd_2                     ),//output [31:0]      o_rxd_2          
    .o_rxk_2                    (o_rxk_2                     ),//output [3:0]       o_rxk_2          
    .o_rxstatus_2               (                            ),//output [2:0]                        
    .o_rdisper_2                (o_rdisper_2                 ),//output [3:0]       o_rdisper_2      
    .o_rdecer_2                 (o_rdecer_2                  ),//output [3:0]       o_rdecer_2       
                                                                                                                 
    .o_rxd_3                    (o_rxd_3                     ),//output [31:0]      o_rxd_3          
    .o_rxk_3                    (o_rxk_3                     ),//output [3:0]       o_rxk_3          
    .o_rxstatus_3               (                            ),//output [2:0]                        
    .o_rdisper_3                (o_rdisper_3                 ),//output [3:0]       o_rdisper_3      
    .o_rdecer_3                 (o_rdecer_3                  ) //output [3:0]       o_rdecer_3         
);
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
gmii_buf buf_u10_2_sfp1(
//gmii_rx
//ch0
    .ch0_gmii_rx_clk      (p0_sgmii_clk_u10         ),//input
    .ch0_rx_rstn          (p0_rx_rstn_sync_u10       ),//input
    .ch0_gmii_rxd         (p0_gmii_rxd_u10          ),// input  [7:0]                    
    .ch0_gmii_rx_dv       (p0_gmii_rx_dv_u10        ),// input                                              
    .ch0_gmii_rx_er       (p0_gmii_rx_er_u10        ),// input                               
//ch1
    .ch1_gmii_rx_clk      (p1_sgmii_clk_u10         ),//input
    .ch1_rx_rstn          (p1_rx_rstn_sync_u10       ),//input
    .ch1_gmii_rxd         (p1_gmii_rxd_u10          ),// input  [7:0]               
    .ch1_gmii_rx_dv       (p1_gmii_rx_dv_u10        ),// input                      
    .ch1_gmii_rx_er       (p1_gmii_rx_er_u10        ),// input                      
//ch2
    .ch2_gmii_rx_clk      (p2_sgmii_clk_u10         ),//input
    .ch2_rx_rstn          (p2_rx_rstn_sync_u10       ),//input
    .ch2_gmii_rxd         (p2_gmii_rxd_u10          ),// input  [7:0]               
    .ch2_gmii_rx_dv       (p2_gmii_rx_dv_u10        ),// input                      
    .ch2_gmii_rx_er       (p2_gmii_rx_er_u10        ),// input                      
//ch3
    .ch3_gmii_rx_clk      (p3_sgmii_clk_u10         ),//input
    .ch3_rx_rstn          (p3_rx_rstn_sync_u10       ),//input
    .ch3_gmii_rxd         (p3_gmii_rxd_u10          ),// input  [7:0]               
    .ch3_gmii_rx_dv       (p3_gmii_rx_dv_u10        ),// input                      
    .ch3_gmii_rx_er       (p3_gmii_rx_er_u10        ),// input                      
//gmii_tx
//ch0
    .ch0_gmii_tx_clk      (p0_sgmii_clk_sfp1        ),// input
    .ch0_gmii_txd         (p0_gmii_txd_sfp1         ),// output [7:0]      
    .ch0_gmii_tx_en       (p0_gmii_tx_en_sfp1       ),// output            
    .ch0_gmii_tx_er       (p0_gmii_tx_er_sfp1       ),// output            
//ch1                                                            
    .ch1_gmii_tx_clk      (p1_sgmii_clk_sfp1        ),// input
    .ch1_gmii_txd         (p1_gmii_txd_sfp1         ),// output [7:0]                      
    .ch1_gmii_tx_en       (p1_gmii_tx_en_sfp1       ),// output                            
    .ch1_gmii_tx_er       (p1_gmii_tx_er_sfp1       ),// output                            
//ch2                                                           
    .ch2_gmii_tx_clk      (p2_sgmii_clk_sfp1        ),// input 
    .ch2_gmii_txd         (p2_gmii_txd_sfp1         ),// output [7:0]                      
    .ch2_gmii_tx_en       (p2_gmii_tx_en_sfp1       ),// output                            
    .ch2_gmii_tx_er       (p2_gmii_tx_er_sfp1       ),// output                 
//ch3
    .ch3_gmii_tx_clk      (p3_sgmii_clk_sfp1        ),// input
    .ch3_gmii_txd         (p3_gmii_txd_sfp1         ),// output [7:0]           
    .ch3_gmii_tx_en       (p3_gmii_tx_en_sfp1       ),// output                 
    .ch3_gmii_tx_er       (p3_gmii_tx_er_sfp1       ) // output                 
);
gmii_buf buf_sfp1_2_u10(
//gmii_rx
//ch0
    .ch0_gmii_rx_clk      (p0_sgmii_clk_sfp1       ),//input
    .ch0_rx_rstn          (p0_rx_rstn_sync_sfp1    ),//input
    .ch0_gmii_rxd         (p0_gmii_rxd_sfp1        ),// input  [7:0]                    
    .ch0_gmii_rx_dv       (p0_gmii_rx_dv_sfp1      ),// input                                              
    .ch0_gmii_rx_er       (p0_gmii_rx_er_sfp1      ),// input                               
//ch1
    .ch1_gmii_rx_clk      (p1_sgmii_clk_sfp1       ),//input
    .ch1_rx_rstn          (p1_rx_rstn_sync_sfp1    ),//input
    .ch1_gmii_rxd         (p1_gmii_rxd_sfp1        ),// input  [7:0]               
    .ch1_gmii_rx_dv       (p1_gmii_rx_dv_sfp1      ),// input                      
    .ch1_gmii_rx_er       (p1_gmii_rx_er_sfp1      ),// input                      
//ch2
    .ch2_gmii_rx_clk      (p2_sgmii_clk_sfp1       ),//input
    .ch2_rx_rstn          (p2_rx_rstn_sync_sfp1    ),//input
    .ch2_gmii_rxd         (p2_gmii_rxd_sfp1        ),// input  [7:0]               
    .ch2_gmii_rx_dv       (p2_gmii_rx_dv_sfp1      ),// input                      
    .ch2_gmii_rx_er       (p2_gmii_rx_er_sfp1      ),// input                      
//ch3
    .ch3_gmii_rx_clk      (p3_sgmii_clk_sfp1       ),//input
    .ch3_rx_rstn          (p3_rx_rstn_sync_sfp1    ),//input
    .ch3_gmii_rxd         (p3_gmii_rxd_sfp1        ),// input  [7:0]               
    .ch3_gmii_rx_dv       (p3_gmii_rx_dv_sfp1      ),// input                      
    .ch3_gmii_rx_er       (p3_gmii_rx_er_sfp1      ),// input                      
//gmii_tx
//ch0
    .ch0_gmii_tx_clk      (p0_sgmii_clk_u10        ),// input
    .ch0_gmii_txd         (p0_gmii_txd_u10         ),// output [7:0]      
    .ch0_gmii_tx_en       (p0_gmii_tx_en_u10       ),// output            
    .ch0_gmii_tx_er       (p0_gmii_tx_er_u10       ),// output            
//ch1                                                            
    .ch1_gmii_tx_clk      (p1_sgmii_clk_u10        ),// input
    .ch1_gmii_txd         (p1_gmii_txd_u10         ),// output [7:0]                      
    .ch1_gmii_tx_en       (p1_gmii_tx_en_u10       ),// output                            
    .ch1_gmii_tx_er       (p1_gmii_tx_er_u10       ),// output                            
//ch2                                                           
    .ch2_gmii_tx_clk      (p2_sgmii_clk_u10        ),// input 
    .ch2_gmii_txd         (p2_gmii_txd_u10         ),// output [7:0]                      
    .ch2_gmii_tx_en       (p2_gmii_tx_en_u10       ),// output                            
    .ch2_gmii_tx_er       (p2_gmii_tx_er_u10       ),// output                 
//ch3
    .ch3_gmii_tx_clk      (p3_sgmii_clk_u10        ),// input
    .ch3_gmii_txd         (p3_gmii_txd_u10         ),// output [7:0]           
    .ch3_gmii_tx_en       (p3_gmii_tx_en_u10       ),// output                 
    .ch3_gmii_tx_er       (p3_gmii_tx_er_u10       ) // output                 
);
gmii_buf buf_u2_2_sfp0(
//gmii_rx
//ch0
    .ch0_gmii_rx_clk      (p0_sgmii_clk_u2         ),//input
    .ch0_rx_rstn          (p0_rx_rstn_sync_u2      ),//input
    .ch0_gmii_rxd         (p0_gmii_rxd_u2          ),// input  [7:0]                    
    .ch0_gmii_rx_dv       (p0_gmii_rx_dv_u2        ),// input                                              
    .ch0_gmii_rx_er       (p0_gmii_rx_er_u2        ),// input                               
//ch1
    .ch1_gmii_rx_clk      (p1_sgmii_clk_u2         ),//input 
    .ch1_rx_rstn          (p1_rx_rstn_sync_u2      ),//input
    .ch1_gmii_rxd         (p1_gmii_rxd_u2          ),// input  [7:0]               
    .ch1_gmii_rx_dv       (p1_gmii_rx_dv_u2        ),// input                      
    .ch1_gmii_rx_er       (p1_gmii_rx_er_u2        ),// input                      
//ch2
    .ch2_gmii_rx_clk      (p2_sgmii_clk_u2         ),//input
    .ch2_rx_rstn          (p2_rx_rstn_sync_u2      ),//input
    .ch2_gmii_rxd         (p2_gmii_rxd_u2          ),// input  [7:0]               
    .ch2_gmii_rx_dv       (p2_gmii_rx_dv_u2        ),// input                      
    .ch2_gmii_rx_er       (p2_gmii_rx_er_u2        ),// input                      
//ch3
    .ch3_gmii_rx_clk      (p3_sgmii_clk_u2         ),//input
    .ch3_rx_rstn          (p3_rx_rstn_sync_u2      ),//input
    .ch3_gmii_rxd         (p3_gmii_rxd_u2          ),// input  [7:0]               
    .ch3_gmii_rx_dv       (p3_gmii_rx_dv_u2        ),// input                      
    .ch3_gmii_rx_er       (p3_gmii_rx_er_u2        ),// input                      
//gmii_tx
//ch0
    .ch0_gmii_tx_clk      (p0_sgmii_clk_sfp0       ),// input
    .ch0_gmii_txd         (p0_gmii_txd_sfp0        ),// output [7:0]      
    .ch0_gmii_tx_en       (p0_gmii_tx_en_sfp0      ),// output            
    .ch0_gmii_tx_er       (p0_gmii_tx_er_sfp0      ),// output            
//ch1                                                           
    .ch1_gmii_tx_clk      (p1_sgmii_clk_sfp0       ),// input
    .ch1_gmii_txd         (p1_gmii_txd_sfp0        ),// output [7:0]                      
    .ch1_gmii_tx_en       (p1_gmii_tx_en_sfp0      ),// output                            
    .ch1_gmii_tx_er       (p1_gmii_tx_er_sfp0      ),// output                            
//ch2                                                          
    .ch2_gmii_tx_clk      (p2_sgmii_clk_sfp0       ),// input 
    .ch2_gmii_txd         (p2_gmii_txd_sfp0        ),// output [7:0]                      
    .ch2_gmii_tx_en       (p2_gmii_tx_en_sfp0      ),// output                            
    .ch2_gmii_tx_er       (p2_gmii_tx_er_sfp0      ),// output                 
//ch3
    .ch3_gmii_tx_clk      (p3_sgmii_clk_sfp0       ),// input
    .ch3_gmii_txd         (p3_gmii_txd_sfp0        ),// output [7:0]           
    .ch3_gmii_tx_en       (p3_gmii_tx_en_sfp0      ),// output                 
    .ch3_gmii_tx_er       (p3_gmii_tx_er_sfp0      ) // output                 
);
gmii_buf buf_sfp0_2_u2(
//gmii_rx
//ch0
    .ch0_gmii_rx_clk      (p0_sgmii_clk_sfp0       ),//input 
    .ch0_rx_rstn          (p0_rx_rstn_sync_sfp0    ),//input
    .ch0_gmii_rxd         (p0_gmii_rxd_sfp0        ),// input  [7:0]                    
    .ch0_gmii_rx_dv       (p0_gmii_rx_dv_sfp0      ),// input                                              
    .ch0_gmii_rx_er       (p0_gmii_rx_er_sfp0      ),// input                               
//ch1
    .ch1_gmii_rx_clk      (p1_sgmii_clk_sfp0       ),//input
    .ch1_rx_rstn          (p1_rx_rstn_sync_sfp0    ),//input
    .ch1_gmii_rxd         (p1_gmii_rxd_sfp0        ),// input  [7:0]               
    .ch1_gmii_rx_dv       (p1_gmii_rx_dv_sfp0      ),// input                      
    .ch1_gmii_rx_er       (p1_gmii_rx_er_sfp0      ),// input                      
//ch2
    .ch2_gmii_rx_clk      (p2_sgmii_clk_sfp0       ),//input 
    .ch2_rx_rstn          (p2_rx_rstn_sync_sfp0    ),//input
    .ch2_gmii_rxd         (p2_gmii_rxd_sfp0        ),// input  [7:0]               
    .ch2_gmii_rx_dv       (p2_gmii_rx_dv_sfp0      ),// input                      
    .ch2_gmii_rx_er       (p2_gmii_rx_er_sfp0      ),// input                      
//ch3
    .ch3_gmii_rx_clk      (p3_sgmii_clk_sfp0       ),//input
    .ch3_rx_rstn          (p3_rx_rstn_sync_sfp0    ),//input
    .ch3_gmii_rxd         (p3_gmii_rxd_sfp0        ),// input  [7:0]               
    .ch3_gmii_rx_dv       (p3_gmii_rx_dv_sfp0      ),// input                      
    .ch3_gmii_rx_er       (p3_gmii_rx_er_sfp0      ),// input                      
//gmii_tx
//ch0
    .ch0_gmii_tx_clk      (p0_sgmii_clk_u2         ),// input
    .ch0_gmii_txd         (p0_gmii_txd_u2          ),// output [7:0]      
    .ch0_gmii_tx_en       (p0_gmii_tx_en_u2        ),// output            
    .ch0_gmii_tx_er       (p0_gmii_tx_er_u2        ),// output            
//ch1                                                             
    .ch1_gmii_tx_clk      (p1_sgmii_clk_u2         ),// input
    .ch1_gmii_txd         (p1_gmii_txd_u2          ),// output [7:0]                      
    .ch1_gmii_tx_en       (p1_gmii_tx_en_u2        ),// output                            
    .ch1_gmii_tx_er       (p1_gmii_tx_er_u2        ),// output                            
//ch2                                                            
    .ch2_gmii_tx_clk      (p2_sgmii_clk_u2         ),// input 
    .ch2_gmii_txd         (p2_gmii_txd_u2          ),// output [7:0]                      
    .ch2_gmii_tx_en       (p2_gmii_tx_en_u2        ),// output                            
    .ch2_gmii_tx_er       (p2_gmii_tx_er_u2        ),// output                 
//ch3
    .ch3_gmii_tx_clk      (p3_sgmii_clk_u2         ),// input
    .ch3_gmii_txd         (p3_gmii_txd_u2          ),// output [7:0]           
    .ch3_gmii_tx_en       (p3_gmii_tx_en_u2        ),// output                 
    .ch3_gmii_tx_er       (p3_gmii_tx_er_u2        ) // output                 
);

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
endmodule


// -----------------------------------------------------------------------------
// LINK_ATTRIB_DIAG_LITE: diagnostics-only GMII DV-segment monitor.
// A segment is one contiguous gmii_rx_dv assertion interval.  This logic never
// drives the bridge, parser, DDR, HDMI, HSST, or QSGMII datapath.
// -----------------------------------------------------------------------------
module gmii_frame_shape_monitor_lite (
    input             clk,
    input             rst_n,
    input             gmii_rx_dv,
    input             gmii_rx_er,
    output reg [31:0] segment_count,
    output reg [31:0] byte_count,
    output reg [31:0] er_segment_count,
    output reg [31:0] er_cycle_count,
    output reg [31:0] short_segment_count,
    output reg [15:0] last_segment_len,
    output reg [15:0] min_segment_len,
    output reg [15:0] max_segment_len
);
reg        dv_d1;
reg        segment_er_seen;
reg [15:0] cur_segment_len;
wire       dv_rise = gmii_rx_dv && !dv_d1;
wire       dv_fall = !gmii_rx_dv && dv_d1;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        dv_d1               <= 1'b0;
        segment_er_seen     <= 1'b0;
        cur_segment_len     <= 16'd0;
        segment_count       <= 32'd0;
        byte_count          <= 32'd0;
        er_segment_count    <= 32'd0;
        er_cycle_count      <= 32'd0;
        short_segment_count <= 32'd0;
        last_segment_len    <= 16'd0;
        min_segment_len     <= 16'hffff;
        max_segment_len     <= 16'd0;
    end else begin
        dv_d1 <= gmii_rx_dv;
        if(dv_rise) begin
            segment_count   <= segment_count + 32'd1;
            byte_count      <= byte_count + 32'd1;
            cur_segment_len <= 16'd1;
            segment_er_seen <= gmii_rx_er;
            if(gmii_rx_er)
                er_cycle_count <= er_cycle_count + 32'd1;
        end else if(gmii_rx_dv) begin
            byte_count      <= byte_count + 32'd1;
            cur_segment_len <= cur_segment_len + 16'd1;
            if(gmii_rx_er) begin
                segment_er_seen <= 1'b1;
                er_cycle_count  <= er_cycle_count + 32'd1;
            end
        end
        if(dv_fall) begin
            last_segment_len <= cur_segment_len;
            if(cur_segment_len < 16'd64)
                short_segment_count <= short_segment_count + 32'd1;
            if(segment_er_seen)
                er_segment_count <= er_segment_count + 32'd1;
            if(cur_segment_len < min_segment_len)
                min_segment_len <= cur_segment_len;
            if(cur_segment_len > max_segment_len)
                max_segment_len <= cur_segment_len;
            cur_segment_len <= 16'd0;
            segment_er_seen <= 1'b0;
        end
    end
end
endmodule

