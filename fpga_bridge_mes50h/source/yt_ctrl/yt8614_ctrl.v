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
module yt8614_ctrl#(
	parameter RSTN_20MS    = 2000_000          ,
    parameter RSTN_120MS   = 12000_000         ,
    parameter MDC_120MS    = 1000_000           
)(
    input               i_clk                  ,
    input               i_rst_n                ,
    output              reset_n_out            ,
    output              reset_n_done           ,
    output              mdc                    ,
    inout               mdio                      
);
//////////////////////////////////////////////////////////////////
reset_n_delay#(
    .RSTN_120MS      (RSTN_120MS      ),
    .RSTN_20MS       (RSTN_20MS       )
)u_reset_n_delay(
    .i_clk          (i_clk          ),// input
    .i_rst_n        (i_rst_n        ),// input
    .reset_n_out    (reset_n_out    ),// output
    .reset_n_done   (reset_n_done   ) // output
);
//////////////////////////////////////////////////////////////////
wire               start          ; 
wire [1:0]         opcode         ; 
wire [4:0]         phy_addr       ; 
wire [4:0]         reg_addr       ; 
wire [15:0]        write_data     ; 
wire [15:0]        read_data      /*synthesis PAP_MARK_DEBUG="1"*/; 
wire               read_data_en   /*synthesis PAP_MARK_DEBUG="1"*/; 
wire               ready          ; 

mdio_master_driver u_mdio_master_driver(
    .clk            (i_clk          ),// input 50M
    .rstn           (i_rst_n        ),// input
    .reset_n_done   (reset_n_done   ),// input
    .mdc            (mdc            ),// output
    .mdio           (mdio           ),// inout
    .start          (start          ),// input
    .opcode         (opcode         ),// input[1:0]
    .phy_addr       (phy_addr       ),// input[4:0]
    .reg_addr       (reg_addr       ),// input[4:0]
    .write_data     (write_data     ),// input[15:0]
    .read_data      (read_data      ),// output[15:0]
    .read_data_en   (read_data_en   ),// output
    .ready          (ready          ) // output         
);
reg_ctrl u_reg_ctrl(
    .i_clk          (mdc            ),// input 
    .reset_n_done   (reset_n_done   ),// input
    .ready          (ready          ),// input
    .start          (start          ),// output
    .opcode         (opcode         ),// output
    .phy_addr       (phy_addr       ),// output
    .reg_addr       (reg_addr       ),// output
    .write_data     (write_data     ),// output
    .read_data      (read_data      ),// input[15:0]
    .read_data_en   (read_data_en   ) // input
);
//////////////////////////////////////////////////////////////////
endmodule

