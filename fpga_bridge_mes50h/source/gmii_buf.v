`default_nettype wire
`timescale 1ns / 1ps
/*////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Company:Meyesemi 
// Engineer: Will
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
module gmii_buf(
//gmii_rx
    //ch0
    input                       ch0_gmii_rx_clk      ,
    input                       ch0_rx_rstn          ,
    input  [7:0]                ch0_gmii_rxd         ,
    input                       ch0_gmii_rx_dv       ,
    input                       ch0_gmii_rx_er       ,
    //ch1
    input                       ch1_gmii_rx_clk      ,
    input                       ch1_rx_rstn          ,
    input  [7:0]                ch1_gmii_rxd         ,
    input                       ch1_gmii_rx_dv       ,
    input                       ch1_gmii_rx_er       ,
    //ch2
    input                       ch2_gmii_rx_clk      ,
    input                       ch2_rx_rstn          ,
    input  [7:0]                ch2_gmii_rxd         ,
    input                       ch2_gmii_rx_dv       ,
    input                       ch2_gmii_rx_er       ,
    //ch3
    input                       ch3_gmii_rx_clk      ,
    input                       ch3_rx_rstn          ,
    input  [7:0]                ch3_gmii_rxd         ,
    input                       ch3_gmii_rx_dv       ,
    input                       ch3_gmii_rx_er       ,

//gmii_tx
    //ch0
    input                       ch0_gmii_tx_clk      ,   
    output  [7:0]               ch0_gmii_txd         ,
    output                      ch0_gmii_tx_en       ,
    output                      ch0_gmii_tx_er       ,
    //ch1
    input                       ch1_gmii_tx_clk      ,    
    output  [7:0]               ch1_gmii_txd         ,
    output                      ch1_gmii_tx_en       ,
    output                      ch1_gmii_tx_er       , 
    //ch2
    input                       ch2_gmii_tx_clk      ,   
    output  [7:0]               ch2_gmii_txd         ,
    output                      ch2_gmii_tx_en       ,
    output                      ch2_gmii_tx_er       , 
    //ch3
    input                       ch3_gmii_tx_clk      ,   
    output  [7:0]               ch3_gmii_txd         ,
    output                      ch3_gmii_tx_en       ,
    output                      ch3_gmii_tx_er       
);
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire  [9:0]  wr_data_0 , wr_data_1,  wr_data_2,  wr_data_3 ;
wire         wr_en_0   , wr_en_1  ,  wr_en_2  ,  wr_en_3   ;
wire         rd_empty_0, rd_empty_1, rd_empty_2, rd_empty_3;
wire  [9:0]  rd_data_0 , rd_data_1 , rd_data_2 , rd_data_3 ;
wire         rd_en_0   , rd_en_1   , rd_en_2   , rd_en_3   ;
reg          rd_en_0_d1, rd_en_1_d1, rd_en_2_d1, rd_en_3_d1;
reg          rd_en_0_d2, rd_en_1_d2, rd_en_2_d2, rd_en_3_d2;
reg          ch0_rx_rstn_d1,ch1_rx_rstn_d1,ch2_rx_rstn_d1,ch3_rx_rstn_d1;
reg          ch0_tx_rstn,ch1_tx_rstn,ch2_tx_rstn,ch3_tx_rstn;
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
always  @(posedge ch0_gmii_tx_clk)begin
    ch0_rx_rstn_d1 <= ch0_rx_rstn ;
    ch0_tx_rstn <= ch0_rx_rstn_d1 ;
end
always  @(posedge ch1_gmii_tx_clk)begin
    ch1_rx_rstn_d1 <= ch1_rx_rstn ;
    ch1_tx_rstn <= ch1_rx_rstn_d1 ;
end
always  @(posedge ch2_gmii_tx_clk)begin
    ch2_rx_rstn_d1 <= ch2_rx_rstn ;
    ch2_tx_rstn <= ch2_rx_rstn_d1 ;
end
always  @(posedge ch3_gmii_tx_clk)begin
    ch3_rx_rstn_d1 <= ch3_rx_rstn ;
    ch3_tx_rstn <= ch3_rx_rstn_d1 ;
end

//wr//////////////////////////////////////////////////////////////////////////////////////////////////////////////
assign wr_data_0 = {ch0_gmii_rx_dv,ch0_gmii_rxd,1'b0} ; // CLEAN: do not forward RX_ER as TX_ER
assign wr_data_1 = {ch1_gmii_rx_dv,ch1_gmii_rxd,1'b0} ; // CLEAN: do not forward RX_ER as TX_ER
assign wr_data_2 = {ch2_gmii_rx_dv,ch2_gmii_rxd,1'b0} ; // CLEAN: do not forward RX_ER as TX_ER
assign wr_data_3 = {ch3_gmii_rx_dv,ch3_gmii_rxd,1'b0} ; // CLEAN: do not forward RX_ER as TX_ER

assign wr_en_0   =  ch0_gmii_rx_dv ;
assign wr_en_1   =  ch1_gmii_rx_dv ;
assign wr_en_2   =  ch2_gmii_rx_dv ;
assign wr_en_3   =  ch3_gmii_rx_dv ;
//rd//////////////////////////////////////////////////////////////////////////////////////////////////////////////
assign  rd_en_0 = ~rd_empty_0 ;
assign  rd_en_1 = ~rd_empty_1 ;
assign  rd_en_2 = ~rd_empty_2 ;
assign  rd_en_3 = ~rd_empty_3 ;

always  @(posedge ch0_gmii_tx_clk)begin
    rd_en_0_d1 <= rd_en_0    ;
    rd_en_0_d2 <= rd_en_0_d1 ;
end
always  @(posedge ch1_gmii_tx_clk)begin
    rd_en_1_d1 <= rd_en_1 ;
    rd_en_1_d2 <= rd_en_1_d1 ;
end
always  @(posedge ch2_gmii_tx_clk)begin
    rd_en_2_d1 <= rd_en_2 ;
    rd_en_2_d2 <= rd_en_2_d1 ;
end
always  @(posedge ch3_gmii_tx_clk)begin
    rd_en_3_d1 <= rd_en_3 ;
    rd_en_3_d2 <= rd_en_3_d1 ;
end
//ch0////////////////////////////////////////////////////////////////////////////////////////////////////////////
fifo_0 fifo_ch0 (
  //wr
  .wr_clk       ( ch0_gmii_rx_clk     ),// input
  .wr_rst       (~ch0_rx_rstn         ),// input 
  .wr_data      ( wr_data_0           ),// input [9:0]
  .wr_en        ( wr_en_0             ),// input
  .wr_full      (                     ),// output
  .almost_full  (                     ),// output
  //rd
  .rd_clk       ( ch0_gmii_tx_clk     ),// input
  .rd_rst       (~ch0_tx_rstn         ),// input 
  .rd_data      ( rd_data_0           ),// output [9:0]
  .rd_en        ( rd_en_0             ),// input
  .rd_empty     ( rd_empty_0          ),// output
  .almost_empty (                     ) // output
);
//ch1////////////////////////////////////////////////////////////////////////////////////////////////////////////
fifo_0 fifo_ch1 (
  //wr
  .wr_clk       ( ch1_gmii_rx_clk     ),// input
  .wr_rst       (~ch1_rx_rstn         ),// input 
  .wr_data      ( wr_data_1           ),// input [9:0]
  .wr_en        ( wr_en_1             ),// input
  .wr_full      (                     ),// output
  .almost_full  (                     ),// output
  //rd
  .rd_clk       ( ch1_gmii_tx_clk     ),// input
  .rd_rst       (~ch1_tx_rstn         ),// input  
  .rd_data      ( rd_data_1           ),// output [9:0]
  .rd_en        ( rd_en_1             ),// input
  .rd_empty     ( rd_empty_1          ),// output
  .almost_empty (                     ) // output
);
//ch2////////////////////////////////////////////////////////////////////////////////////////////////////////////
fifo_0 fifo_ch2 (
  //wr
  .wr_clk       ( ch2_gmii_rx_clk     ),// input
  .wr_rst       (~ch2_rx_rstn         ),// input  
  .wr_data      ( wr_data_2           ),// input [9:0]
  .wr_en        ( wr_en_2             ),// input
  .wr_full      (                     ),// output
  .almost_full  (                     ),// output
  //rd
  .rd_clk       ( ch2_gmii_tx_clk     ),// input
  .rd_rst       (~ch2_tx_rstn         ),// input 
  .rd_data      ( rd_data_2           ),// output [9:0]
  .rd_en        ( rd_en_2             ),// input
  .rd_empty     ( rd_empty_2          ),// output
  .almost_empty (                     ) // output
);
//ch3////////////////////////////////////////////////////////////////////////////////////////////////////////////
fifo_0 fifo_ch3 (
  //wr
  .wr_clk       ( ch3_gmii_rx_clk     ),// input
  .wr_rst       (~ch3_rx_rstn         ),// input 
  .wr_data      ( wr_data_3           ),// input [9:0]
  .wr_en        ( wr_en_3             ),// input
  .wr_full      (                     ),// output
  .almost_full  (                     ),// output
  //rd
  .rd_clk       ( ch3_gmii_tx_clk     ),// input
  .rd_rst       (~ch3_tx_rstn         ),// input   
  .rd_data      ( rd_data_3           ),// output [9:0]
  .rd_en        ( rd_en_3             ),// input
  .rd_empty     ( rd_empty_3          ),// output
  .almost_empty (                     ) // output
);
//out////////////////////////////////////////////////////////////////////////////////////////////////////////////
assign {ch0_gmii_tx_en,ch0_gmii_txd,ch0_gmii_tx_er} =  rd_en_0_d2?rd_data_0:10'h0;
assign {ch1_gmii_tx_en,ch1_gmii_txd,ch1_gmii_tx_er} =  rd_en_1_d2?rd_data_1:10'h0;
assign {ch2_gmii_tx_en,ch2_gmii_txd,ch2_gmii_tx_er} =  rd_en_2_d2?rd_data_2:10'h0;
assign {ch3_gmii_tx_en,ch3_gmii_txd,ch3_gmii_tx_er} =  rd_en_3_d2?rd_data_3:10'h0;
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
endmodule

