`timescale 1ns/1ps
/*//////////////////////////////////////////////////////////////////////////////////////////
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
*//////////////////////////////////////////////////////////////////////////////////////////
`define UD #1 
module reg_ctrl#(
	parameter MDC_120MS    = 1000_000                  //
)(
    input                       i_clk                  ,//
    input                       reset_n_done           ,

    input                       ready                  ,
    output  reg                 start                  ,
    output  reg [1:0]           opcode                 ,
    output  reg [4:0]           phy_addr               ,
    output  reg [4:0]           reg_addr               ,
    output  reg [15:0]          write_data             ,
    input       [15:0]          read_data              ,// 
    input                       read_data_en           ,// 
    output  reg                 init_done               //
);
//////////////////////////////////////////////////////////////////////////////////////////
parameter   INIT  =   2'b00    ;
parameter   IDLE  =   2'b01    ;
parameter   S1    =   2'b10    ;
reg [1:0]           state_c         ;
reg [1:0]           state_n         ;  
reg                 reset_n_done_r  ;
reg                 reset_n         ;
wire                init2idle       ;
wire                idle2s1         ;
wire                s12idle         ;
reg [3:0]           cnt0            ;
reg [6:0]           cnt1            ;
reg                 start_init      ;
reg [1:0]           opcode_init     ;
reg [4:0]           phy_addr_init   ;
reg [4:0]           reg_addr_init   ;
reg [15:0]          write_data_init ;
reg                 start_s1        ;
reg [1:0]           opcode_s1       ;
reg [4:0]           phy_addr_s1     ;
reg [4:0]           reg_addr_s1     ;
reg [15:0]          write_data_s1   ;
reg [24:0]          cnt2            ;
reg [3:0]           cnt3            ;
reg [6:0]           cnt4            ;
//////////////////////////////////////////////////////////////////////////////////////////
always  @(posedge i_clk)begin
    if(!reset_n_done)begin
        reset_n_done_r  <=  1'b0;
        reset_n         <=  1'b0;
    end  
    else begin
        reset_n_done_r  <=  reset_n_done    ;
        reset_n         <=  reset_n_done_r  ;
    end
end
always@(posedge i_clk)begin
    if(!reset_n)begin
        state_c <= INIT;
    end
    else begin
        state_c <= state_n;
    end
end
always@(*)begin
    case(state_c)
        INIT:begin
            if(init2idle)begin
                state_n = IDLE;
            end
            else begin
                state_n = state_c;
            end
        end
        IDLE:begin
            if(idle2s1)begin
                state_n = S1;
            end
            else begin
                state_n = state_c;
            end
        end
        S1:begin
            if(s12idle)begin
                state_n = IDLE;
            end 
            else begin
                state_n = state_c;
            end
        end
        default:begin
            state_n = IDLE;
        end
    endcase
end
assign init2idle  = state_c==INIT && cnt0==4'd2 && cnt1==7'd109 ;
assign idle2s1    = state_c==IDLE && cnt2==MDC_120MS            ;
assign s12idle    = state_c==S1   && cnt3==4'd2 && cnt4==7'd13   ;
always  @(posedge i_clk)begin
    if(!reset_n)begin
        start      <=  1'b0     ;
        opcode     <=  2'b01    ;
        phy_addr   <=  5'h0     ;
        reg_addr   <=  5'h0     ;
        write_data <=  16'h0    ;
    end
    else if(state_c==INIT)begin
        start      <=  start_init         ;
        opcode     <=  opcode_init        ;
        phy_addr   <=  phy_addr_init      ;
        reg_addr   <=  reg_addr_init      ;
        write_data <=  write_data_init    ;
    end
    else if(state_c==S1)begin
        start      <=  start_s1           ;
        opcode     <=  opcode_s1          ;
        phy_addr   <=  phy_addr_s1        ;
        reg_addr   <=  reg_addr_s1        ;
        write_data <=  write_data_s1      ;
    end
    else begin
        phy_addr   <=  5'h0     ;
        reg_addr   <=  5'h0     ;
        write_data <=  16'h0    ;
    end
end
always  @(posedge i_clk)begin
    if(!reset_n)begin
        start_init   <=  1'b0   ;
    end
    else if(state_c==INIT&&cnt0==4'd14)begin
        start_init   <=  1'b1   ;
    end
    else begin
        start_init   <=  1'b0   ;
    end
end

always @(posedge i_clk)begin
    if(!reset_n|!ready)begin
        cnt0 <= 0;
    end
    else if(state_c==INIT&&ready)begin
         if(cnt0==4'd15)begin
             cnt0 <= cnt0;
         end
         else begin
             cnt0 <= cnt0 + 1;
         end
     end
 end
 
 always @(posedge i_clk)begin
     if(!reset_n)begin
         cnt1 <= 0;
     end
     else if(cnt0==4'd1)begin
          if(cnt1==7'd109)begin
              cnt1 <= 0;
          end
          else begin
              cnt1 <= cnt1 + 1;
          end
      end
  end
always  @(posedge i_clk)begin
    if(!reset_n)begin
        opcode_init   <=  2'b01   ;//
    end
    else if(state_c==INIT&&cnt1==7'd4)begin
        opcode_init   <=  2'b10   ;//
    end
    else if(state_c==INIT&&cnt1==7'd68)begin
        opcode_init   <=  2'b10   ;//
    end
    else if(state_c==INIT&&cnt1==7'd76)begin
        opcode_init   <=  2'b10   ;//
    end
    else begin
        opcode_init   <=  2'b01   ;//
    end
end  
always@(posedge i_clk)begin
    if(!reset_n)begin
         phy_addr_init   <=  5'h0     ;
         reg_addr_init   <=  5'h0     ;
         write_data_init <=  16'h0    ;
    end   
    else begin
    case(cnt1)//
     7'd1  :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'ha000 ; end//
     7'd2  :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h0    ; end//
     7'd3  :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'ha000 ; end//
     7'd4  :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  end//
     7'd5  :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h41   ; end//
     7'd6  :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h33   ; end//
     7'd7  :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h42   ; end//
     7'd8  :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h66   ; end//
     7'd9  :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h43   ; end//
     7'd10 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'haa   ; end//
     7'd11 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h44   ; end//
     7'd12 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'hd0d  ; end//
     7'd13 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h57   ; end//
     7'd14 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h234f ; end//
     7'd15 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'ha040 ; end//
     7'd16 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'hbb00 ; end//
     7'd17 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'ha041 ; end//
     7'd18 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'hbb00 ; end//
     7'd19 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'ha042 ; end//
     7'd20 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'hbb00 ; end//
     7'd21 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'ha043 ; end//
     7'd22 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'hbb00 ; end//
     7'd23 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'ha044 ; end//
     7'd24 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'hbb00 ; end//
     7'd25 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'ha045 ; end//
     7'd26 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'hbb00 ; end//
     7'd27 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'ha046 ; end//
     7'd28 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'hbb00 ; end//
     7'd29 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'ha047 ; end//
     7'd30 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'hbb00 ; end//
     7'd31 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h0  ;  write_data_init<= 16'h9140 ; end//
     7'd32 :begin  phy_addr_init<= 5'h1 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h41   ; end//
     7'd33 :begin  phy_addr_init<= 5'h1 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h33   ; end//
     7'd34 :begin  phy_addr_init<= 5'h1 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h42   ; end//
     7'd35 :begin  phy_addr_init<= 5'h1 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h66   ; end//
     7'd36 :begin  phy_addr_init<= 5'h1 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h43   ; end//
     7'd37 :begin  phy_addr_init<= 5'h1 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'haa   ; end//
     7'd38 :begin  phy_addr_init<= 5'h1 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h44   ; end//
     7'd39 :begin  phy_addr_init<= 5'h1 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'hd0d  ; end//
     7'd40 :begin  phy_addr_init<= 5'h1 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h57   ; end//
     7'd41 :begin  phy_addr_init<= 5'h1 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h234f ; end//
     7'd42 :begin  phy_addr_init<= 5'h1 ;  reg_addr_init<= 5'h0  ;  write_data_init<= 16'h9140 ; end//
     7'd43 :begin  phy_addr_init<= 5'h2 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h41   ; end//
     7'd44 :begin  phy_addr_init<= 5'h2 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h33   ; end//
     7'd45 :begin  phy_addr_init<= 5'h2 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h42   ; end//
     7'd46 :begin  phy_addr_init<= 5'h2 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h66   ; end//
     7'd47 :begin  phy_addr_init<= 5'h2 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h43   ; end//
     7'd48 :begin  phy_addr_init<= 5'h2 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'haa   ; end//
     7'd49 :begin  phy_addr_init<= 5'h2 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h44   ; end//
     7'd50 :begin  phy_addr_init<= 5'h2 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'hd0d  ; end//
     7'd51 :begin  phy_addr_init<= 5'h2 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h57   ; end//
     7'd52 :begin  phy_addr_init<= 5'h2 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h234f ; end//
     7'd53 :begin  phy_addr_init<= 5'h2 ;  reg_addr_init<= 5'h0  ;  write_data_init<= 16'h9140 ; end// 
     7'd54 :begin  phy_addr_init<= 5'h3 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h41   ; end//
     7'd55 :begin  phy_addr_init<= 5'h3 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h33   ; end//
     7'd56 :begin  phy_addr_init<= 5'h3 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h42   ; end//
     7'd57 :begin  phy_addr_init<= 5'h3 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h66   ; end//
     7'd58 :begin  phy_addr_init<= 5'h3 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h43   ; end//
     7'd59 :begin  phy_addr_init<= 5'h3 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'haa   ; end//
     7'd60 :begin  phy_addr_init<= 5'h3 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h44   ; end//
     7'd61 :begin  phy_addr_init<= 5'h3 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'hd0d  ; end//
     7'd62 :begin  phy_addr_init<= 5'h3 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h57   ; end//
     7'd63 :begin  phy_addr_init<= 5'h3 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h234f ; end//
     7'd64 :begin  phy_addr_init<= 5'h3 ;  reg_addr_init<= 5'h0  ;  write_data_init<= 16'h9140 ; end//
     7'd65 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'ha000 ; end//
     7'd66 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h2    ; end//
     7'd67 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'ha000 ; end//
     7'd68 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  end//
     7'd69 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h3    ; end//
     7'd70 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h4f80 ; end//
     7'd71 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'he    ; end//
     7'd72 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h4f80 ; end//
     7'd73 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'ha000 ; end//
     7'd74 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h3    ; end//
     7'd75 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'ha000 ; end//
     7'd76 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  end//
     7'd77 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h3    ; end//
     7'd78 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h2420 ; end//
     7'd79 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'he    ; end//
     7'd80 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h24a0 ; end//
     7'd81 :begin  phy_addr_init<= 5'h1 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h3    ; end//
     7'd82 :begin  phy_addr_init<= 5'h1 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h2420 ; end//
     7'd83 :begin  phy_addr_init<= 5'h1 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'he    ; end//
     7'd84 :begin  phy_addr_init<= 5'h1 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h24a0 ; end//
     7'd85 :begin  phy_addr_init<= 5'h2 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h3    ; end//
     7'd86 :begin  phy_addr_init<= 5'h2 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h2420 ; end//
     7'd87 :begin  phy_addr_init<= 5'h2 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'he    ; end//
     7'd88 :begin  phy_addr_init<= 5'h2 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h24a0 ; end//
     7'd89 :begin  phy_addr_init<= 5'h3 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h3    ; end//
     7'd90 :begin  phy_addr_init<= 5'h3 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h2420 ; end//
     7'd91 :begin  phy_addr_init<= 5'h3 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'he    ; end//
     7'd92 :begin  phy_addr_init<= 5'h3 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'h24a0 ; end// 
     7'd93 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'ha08e ; end//
     7'd94 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'hf10  ; end//
     7'd95 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h1be  ; end//
     7'd96 :begin  phy_addr_init<= 5'h0 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'hb01f ; end//
     7'd97 :begin  phy_addr_init<= 5'h1 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'ha08e ; end//
     7'd98 :begin  phy_addr_init<= 5'h1 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'hf10  ; end//
     7'd99 :begin  phy_addr_init<= 5'h1 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h1be  ; end//
     7'd100:begin  phy_addr_init<= 5'h1 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'hb01f ; end//
     7'd101:begin  phy_addr_init<= 5'h2 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'ha08e ; end//
     7'd102:begin  phy_addr_init<= 5'h2 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'hf10  ; end//
     7'd103:begin  phy_addr_init<= 5'h2 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h1be  ; end//
     7'd104:begin  phy_addr_init<= 5'h2 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'hb01f ; end//
     7'd105:begin  phy_addr_init<= 5'h3 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'ha08e ; end//
     7'd106:begin  phy_addr_init<= 5'h3 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'hf10  ; end//
     7'd107:begin  phy_addr_init<= 5'h3 ;  reg_addr_init<= 5'h1e ;  write_data_init<= 16'h1be  ; end//
     7'd108:begin  phy_addr_init<= 5'h3 ;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'hb01f ; end//                               
    default:begin  phy_addr_init<= 5'h1f;  reg_addr_init<= 5'h1f ;  write_data_init<= 16'hffff ; end//        
    endcase
    end      
end	
//init_done
always  @(posedge i_clk)begin
    if(!reset_n)begin
        init_done<=1'b0;
    end
    else if(state_c!=INIT)begin
        init_done<=1'b1;
    end
    else begin
        init_done<=init_done;
    end
end
always @(posedge i_clk)begin
    if(!reset_n)begin
        cnt2 <= 25'd0;
    end
    else if(state_c==IDLE && ready)begin
         if(cnt2==MDC_120MS)begin
             cnt2 <= 25'd0;
         end
         else begin
             cnt2 <= cnt2 + 25'd1;
         end
     end
 end
always @(posedge i_clk)begin
    if(!reset_n|!ready|state_c==IDLE)begin
        cnt3 <= 0;
    end
    else if(state_c==S1&&ready)begin
         if(cnt3==4'd15)begin
             cnt3 <= cnt3;
         end
         else begin
             cnt3 <= cnt3 + 1;
         end
     end
 end
 always @(posedge i_clk)begin
     if(!reset_n|state_c==IDLE)begin
         cnt4 <= 0;
     end
     else if(cnt3==4'd1)begin
          if(cnt4==7'd13)begin
              cnt4 <= 0;
          end
          else begin
              cnt4 <= cnt4 + 1;
          end
      end
  end
always  @(posedge i_clk)begin
    if(!reset_n)begin
        start_s1   <=  1'b0   ;
    end
    else if(state_c==S1&&cnt3==4'd14)begin
        start_s1   <=  1'b1   ;
    end
    else begin
        start_s1   <=  1'b0   ;
    end
end
always@(posedge i_clk)begin
    if(!reset_n)begin   
         opcode_s1     <=  2'b01    ;//
         phy_addr_s1   <=  5'h0     ;
         reg_addr_s1   <=  5'h0     ;
         write_data_s1 <=  16'h0    ;
    end   
    else begin
         case(cnt4)                    
              7'd1  :begin opcode_s1<=2'b01; phy_addr_s1<=5'h0; reg_addr_s1<=5'h1e; write_data_s1<=16'ha000 ; end//
              7'd2  :begin opcode_s1<=2'b01; phy_addr_s1<=5'h0; reg_addr_s1<=5'h1f; write_data_s1<=16'h0    ; end                            
              7'd3  :begin opcode_s1<=2'b10; phy_addr_s1<=5'h0; reg_addr_s1<=  5'h11;  end//
              7'd4  :begin opcode_s1<=2'b10; phy_addr_s1<=5'h1; reg_addr_s1<=  5'h11;  end//
              7'd5  :begin opcode_s1<=2'b10; phy_addr_s1<=5'h2; reg_addr_s1<=  5'h11;  end//
              7'd6  :begin opcode_s1<=2'b10; phy_addr_s1<=5'h3; reg_addr_s1<=  5'h11;  end//                        
              7'd7  :begin opcode_s1<=2'b01; phy_addr_s1<=5'h0; reg_addr_s1<=5'h1e; write_data_s1<=16'ha000 ; end//
              7'd8  :begin opcode_s1<=2'b01; phy_addr_s1<=5'h0; reg_addr_s1<=5'h1f; write_data_s1<=16'h2    ; end                          
              7'd9  :begin opcode_s1<=2'b10; phy_addr_s1<=5'h0; reg_addr_s1<=  5'h11;  end//
              7'd10 :begin opcode_s1<=2'b10; phy_addr_s1<=5'h1; reg_addr_s1<=  5'h11;  end//
              7'd11 :begin opcode_s1<=2'b10; phy_addr_s1<=5'h2; reg_addr_s1<=  5'h11;  end//
              7'd12 :begin opcode_s1<=2'b10; phy_addr_s1<=5'h3; reg_addr_s1<=  5'h11;  end//

             default:begin opcode_s1<=2'b11; phy_addr_s1<=5'h1f; reg_addr_s1<=5'h1f; write_data_s1<=16'hffff ;end
         endcase
    end      
end	 
///////////////////////////////////////////////////////////////////////////////////////////////////////////
endmodule

