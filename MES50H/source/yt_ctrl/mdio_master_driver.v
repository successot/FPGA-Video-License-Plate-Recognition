/*//////////////////////////////////////////////////////////////////////////////////////////////////
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
*///////////////////////////////////////////////////////////////////////////////////////////////////
module	mdio_master_driver(
   input	                  clk             ,
   input	                  rstn            ,
   input                      reset_n_done    ,	
   output                     mdc             ,
   inout	                  mdio            ,
   input                      start           ,
   input        [1:0]         opcode          ,
   input        [4:0]         phy_addr        ,
   input        [4:0]         reg_addr        ,
   input        [15:0]        write_data      ,   
   output reg   [15:0]        read_data       ,
   output reg                 read_data_en    ,
   output reg                 ready
);
///////////////////////////////////////////////////////////////////////////////////////////////////
reg                 mdio_oe         ;
reg                 mdio_out  =1'b0 ;
wire                mdio_in         ;
reg                 start_next      ;
wire                start_edge      ;
reg [1:0]           st_code   =2'h0 ;
reg [1:0]           ta_code   =2'h0 ;
reg [1:0]           op_code   =2'h0 ;
reg [4:0]           regaddr   =5'h0 ;
reg [4:0]           phyaddr   =5'h0 ; 
reg [15:0]          writedata =16'h0;
reg [7:0]           counter   =8'd0 ;
reg [7:0]           state           ;
reg [7:0]           state_next      ;
reg                 reset_n_done_r  ;
reg                 reset_n         ;
///////////////////////////////////////////////////////////////////////////////////////////////////
assign mdio     = mdio_oe ? mdio_out : 1'bz ;//
assign mdio_in  = mdio    ;
GTP_IOCLKDIV#(
    .GRS_EN       ("TRUE" ),
    .DIV_FACTOR   ("5"    ) 
)u_GTP_IOCLKDIV (
    .CLKDIVOUT    (mdc    ),// OUTPUT  
    .CLKIN        (clk    ),// INPUT  
    .RST_N        (rstn   ) // INPUT  
);
always  @(posedge mdc)begin
    reset_n_done_r  <=  reset_n_done  ;
    reset_n <=  reset_n_done_r        ;
end
always @(posedge mdc)begin
	if(!reset_n)begin
		start_next<=0;
	end
	else 
		start_next<=start;
end
assign start_edge= !start_next & start;
parameter PREAMBLE  =   8'b0000_0001 ;//
parameter ST        =	8'b0000_0010 ;//
parameter OP        =   8'b0000_0100 ;//
parameter PHYAD     =   8'b0000_1000 ;//
parameter REGAD     =   8'b0001_0000 ;//
parameter TA        =   8'b0010_0000 ;//
parameter DATA      =   8'b0100_0000 ;// 
parameter IDLE      =   8'b1000_0000 ;//
always @(posedge mdc)
begin
	if(!reset_n)
	begin
		state<=IDLE;
	end 
	else if(start_edge)
		begin
			state<=PREAMBLE;
			
		end
		
	else
		state<=state_next;
end
always @(posedge mdc)
begin
	if(!reset_n)
	begin 
		counter<=8'd0;
	end
	else if(counter==8'd64)
	begin
		counter<=8'd0;
	end
	else if(state!=IDLE)
	begin
		counter<=counter+8'd1;
	end		
end
always @(posedge mdc)
begin
	if(!reset_n)
	begin 
		ready <= 1'b0   ;
	end
	else if(state!=IDLE)
	begin
		ready <= 1'b0   ;
	end
    else begin
        ready <= 1'b1   ;
    end    
end
always @(negedge mdc)
begin
	state_next<=state;
case(state)
	PREAMBLE: 
		begin
			st_code<= 2'b01 ; 
			ta_code<= 2'b10 ;
			op_code<=opcode;//
			regaddr<=reg_addr;
			phyaddr<=phy_addr;
			writedata<=write_data;
			mdio_oe<=1;
			mdio_out<=1;
			if(counter==8'd31)//
				begin
					state_next<=ST;
				end
		end
	ST:
		begin
			mdio_oe<=1;
			mdio_out<=st_code[1];
			st_code<=st_code<<1;
			if(counter==8'd33)//
				begin
					state_next<=OP;
				end
		end
	OP:
		begin
			mdio_oe<=1;
			mdio_out<=op_code[1];
			op_code<=op_code<<1;
			if(counter==8'd35)//
				begin
					state_next<=PHYAD;
				end
		end
	PHYAD:
		begin
			mdio_oe<=1;
			mdio_out<=phyaddr[4];
			phyaddr<=phyaddr<<1;
			if(counter==8'd40)//
				begin
					state_next<=REGAD;
				end
		end
	REGAD:
		begin
			mdio_oe<=1;
			mdio_out<=regaddr[4];
			regaddr<=regaddr<<1;
			if(counter==8'd45)//
				begin
					state_next<=TA;
				end
		end
	TA:
		begin
			if(opcode==2'b10)//
			begin
				mdio_oe<=0;
				if(counter==8'd47)//
				begin
					state_next<=DATA;
				end
			end
			if(opcode==2'b01)//
			begin
				mdio_oe<=1;
				mdio_out<=ta_code[1];
				ta_code<=ta_code<<1;
				if(counter==8'd47)//
				begin
					state_next<=DATA;
				end
			end
		end
	DATA:
		begin
			if(opcode==2'b10)//
			begin
				mdio_oe<=0;
				if(counter==8'd63)//
				begin
					state_next<=IDLE;
				end
			end
			if(opcode==2'b01)//
			begin
				mdio_oe<=1;
				mdio_out<=writedata[15];
				writedata<=writedata<<1;
				if(counter==8'd63)//
				begin
					state_next<=IDLE;
				end
			end
		end
	IDLE:
		begin
			mdio_oe<=0;
				if(counter==8'd64)//
				begin
					state_next<=IDLE;
				end
		end
	default:
		begin
			state_next<=IDLE;
		end	
endcase
end
always @(posedge mdc)
begin
	if(!reset_n|start_edge)
	begin
		read_data<=16'h0;
	end
	else if((state==DATA)&(opcode==2'b10))
	begin
		read_data<={read_data[14:0],mdio_in};
	end
	else 
    begin
		read_data<=read_data;
    end
end

always @(posedge mdc)
begin
	if(!reset_n)
	begin
		read_data_en<=1'b0;
	end
	else if((counter==8'd63)&(opcode==2'b10))
	begin
		read_data_en<=1'b1;
	end
	else 
		read_data_en<=1'b0;
end
///////////////////////////////////////////////////////////////////////////////////////////////////
endmodule	


