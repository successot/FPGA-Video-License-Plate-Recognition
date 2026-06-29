`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
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
//////////////////////////////////////////////////////////////////////////////////
module led_test(
    input          clk          ,
    input          rstn         ,
    input  [7:0]   done         ,
    input  [7:0]   link         ,
//speed
    input  [1:0]   u2_ch0_speed ,
    input  [1:0]   u2_ch1_speed ,
    input  [1:0]   u2_ch2_speed ,
    input  [1:0]   u2_ch3_speed ,
    input  [1:0]   u10_ch0_speed,
    input  [1:0]   u10_ch1_speed,
    input  [1:0]   u10_ch2_speed,
    input  [1:0]   u10_ch3_speed,
//phy_led
    output [2:0]   u2_ch0_led   ,
    output [2:0]   u2_ch1_led   ,
    output [2:0]   u2_ch2_led   ,
    output [2:0]   u2_ch3_led   ,
    output [2:0]   u10_ch0_led  ,
    output [2:0]   u10_ch1_led  ,
    output [2:0]   u10_ch2_led  ,
    output [2:0]   u10_ch3_led  , 
//LED   
    output [7:0]   led
);

//reg and wire

    reg [25:0] led_light_cnt    ;
    reg        led_status       ;
    
//time counter
    always @(posedge clk)
    begin
        if(!rstn)
            led_light_cnt <=  26'd0;
        else if(led_light_cnt == 26'd9_999_999)
            led_light_cnt <=  26'd0;
        else
            led_light_cnt <=  led_light_cnt + 26'd1; 
    end
    
//led status change
    always @(posedge clk)
    begin
        if(!rstn)
            led_status <=  1'b0;
        else if(led_light_cnt == 26'd9_999_999)
            led_status <=  ~led_status;
    end
//led
    assign led[0] = done[0];
    assign led[1] = done[1];
    assign led[2] = done[2];
    assign led[3] = done[3];
    assign led[4] = done[4];
    assign led[5] = done[5];
    assign led[6] = done[6];
    assign led[7] = done[7];
//////////////////////////////////////////////////////////////////////////////////
assign u10_ch0_led  = (u10_ch0_speed==2'b10&&link[0])?{led_status,2'b01}:3'b100;
assign u10_ch1_led  = (u10_ch1_speed==2'b10&&link[1])?{led_status,2'b01}:3'b100;
assign u10_ch2_led  = (u10_ch2_speed==2'b10&&link[2])?{led_status,2'b01}:3'b100;
assign u10_ch3_led  = (u10_ch3_speed==2'b10&&link[3])?{led_status,2'b01}:3'b100;
assign u2_ch0_led   = (u2_ch0_speed==2'b10 &&link[4])?{led_status,2'b01}:3'b100;
assign u2_ch1_led   = (u2_ch1_speed==2'b10 &&link[5])?{led_status,2'b01}:3'b100;
assign u2_ch2_led   = (u2_ch2_speed==2'b10 &&link[6])?{led_status,2'b01}:3'b100;
assign u2_ch3_led   = (u2_ch3_speed==2'b10 &&link[7])?{led_status,2'b01}:3'b100;
//////////////////////////////////////////////////////////////////////////////////
endmodule
