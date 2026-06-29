`timescale 1ns/1ps
/*//////////////////////////////////////////////////////////////////
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
*//////////////////////////////////////////////////////////////////
`define UD #1 
module reset_n_delay#(
	parameter RSTN_20MS    = 1000_000        ,//
    parameter RSTN_120MS   = 6000_000         //  
)(
    input               i_clk                ,//
    input               i_rst_n              ,
    //∆‰À˚–≈∫≈
    output wire         reset_n_out          ,//
    output wire         reset_n_done          //
);
localparam RSTN_CNT=RSTN_20MS+RSTN_120MS;

reg [31:0]  cnt =0;
always @(posedge i_clk)begin
    if(!i_rst_n)begin
        cnt <= 32'd0;
    end
    else if(cnt==RSTN_CNT)begin
             cnt <= cnt;
         end
         else begin
             cnt <= cnt + 32'd1;
         end
 end

assign  reset_n_out     = (cnt<RSTN_20MS)?1'b0 : 1'b1   ;
assign  reset_n_done    = (cnt<RSTN_CNT )?1'b0 : 1'b1   ;

//////////////////////////////////////////////////////////////////
endmodule

