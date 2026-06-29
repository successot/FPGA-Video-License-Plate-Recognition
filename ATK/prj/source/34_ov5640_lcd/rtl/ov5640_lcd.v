

module ov5640_lcd(
    input             sys_clk          ,
    input             sys_rst_n        ,
    //lcdӿ                         
    output            lcd_hs           ,  
    output            lcd_vs           ,  
    output            lcd_de           ,  
    inout  [23:0]     lcd_rgb          ,  
    output            lcd_bl           ,  
    output            lcd_rst          ,  
    output            lcd_pclk         ,  
    //ͷӿ                       
    input             cam_pclk         ,  
    input             cam_vsync        ,  
    input             cam_href         ,  
    input  [7:0]      cam_data         ,  
    output            cam_rst_n        ,  
    output            cam_pwdn         ,  
    output            cam_scl          ,  
    inout             cam_sda          ,  
    //DDR3ӿ
    input             pad_loop_in      ,  
    input             pad_loop_in_h    ,  
    output            pad_rstn_ch0     ,  
    output            pad_ddr_clk_w    ,  
    output            pad_ddr_clkn_w   ,  
    output            pad_csn_ch0      ,  
    output [15:0]     pad_addr_ch0     ,  
    inout  [16-1:0]   pad_dq_ch0       ,  
    inout  [16/8-1:0] pad_dqs_ch0      ,  
    inout  [16/8-1:0] pad_dqsn_ch0     ,  
    output [16/8-1:0] pad_dm_rdqs_ch0  ,  
    output            pad_cke_ch0      ,  
    output            pad_odt_ch0      ,  
    output            pad_rasn_ch0     ,  
    output            pad_casn_ch0     ,  
    output            pad_wen_ch0      ,  
    output [2:0]      pad_ba_ch0       ,  
    output            pad_loop_out     ,  
    output            pad_loop_out_h   ,  
	input        	  eth_rxc,
	input        	  eth_rx_ctl,
	input  [3:0] 	  eth_rxd,
	output       	  eth_txc,
	output       	  eth_tx_ctl,
	output [3:0] 	  eth_txd,
	output       	  eth_rst_n
   );

//parameter define
parameter APP_ADDR_MIN = 28'd0        ; 
parameter BURST_LENGTH = 8'd64        ; 

//wire define
wire        sys_init_done   ; 
wire        rst_n           ;  
//PLL
wire        clk_50m         ;  
wire        clk_100m        ;  
wire        clk_locked      ;
//ͷֱ
wire [12:0] h_disp          ;  
wire [12:0] v_disp          ;  
wire [12:0] total_h_pixel   ;  
wire [12:0] total_v_pixel   ;  
wire [27:0] ddr3_addr_max   ;  
//OV5640
wire        cam_init_done   ;  
wire        cmos_frame_vsync;  
wire        cmos_frame_href ;  
wire        cmos_frame_valid;  
wire [15:0] wr_data         ;  
//LCD                       
wire        lcd_clk         ;  
wire [15:0] lcd_id          ;  
wire        out_vsync       ;  
wire        rdata_req       ;  
//DDR3
wire [15:0] rd_data         ;  
wire        fram_done       ;  
wire        ddr_init_done   ;  

wire        pp_valid;
wire        pp_href;
wire        pp_vsync;
wire [15:0] pp_data;
wire [2:0]  pp_active_mode;
wire        pp_stat_valid;
wire        eth_transfer_flag;
wire [2:0]  eth_manual_mode;
reg  [2:0]  eth_manual_mode_cam_d0;
reg  [2:0]  eth_manual_mode_cam_d1;
wire [2:0]  selected_manual_mode;


wire        lcd_frame_start_udp;
wire        lcd_rgb565_udp_valid;
wire [15:0] lcd_rgb565_udp_data;
reg  [2:0]  pp_active_mode_lcd_d0;
reg  [2:0]  pp_active_mode_lcd_d1;
wire [2:0]  udp_lcd_mode;

always @(posedge cam_pclk or negedge rst_n) begin
    if(!rst_n) begin
        eth_manual_mode_cam_d0 <= 3'd3;
        eth_manual_mode_cam_d1 <= 3'd3;
    end else begin
        eth_manual_mode_cam_d0 <= eth_manual_mode;
        eth_manual_mode_cam_d1 <= eth_manual_mode_cam_d0;
    end
end

assign selected_manual_mode = eth_manual_mode_cam_d1;


always @(posedge lcd_clk or negedge rst_n) begin
    if(!rst_n) begin
        pp_active_mode_lcd_d0 <= 3'd3;
        pp_active_mode_lcd_d1 <= 3'd3;
    end else begin
        pp_active_mode_lcd_d0 <= pp_active_mode;
        pp_active_mode_lcd_d1 <= pp_active_mode_lcd_d0;
    end
end

assign udp_lcd_mode = pp_active_mode_lcd_d1;



assign  rst_n = sys_rst_n & clk_locked;


assign  sys_init_done = ddr_init_done & cam_init_done;


pll_clk  u_pll_clk(
    .pll_rst        (~sys_rst_n  ),
    .clkin1         (sys_clk     ),
    .clkout0        (clk_50m     ),
    .clkout1        (clk_100m    ),
    .pll_lock       (clk_locked  )
);


picture_size u_picture_size (
    .rst_n              (rst_n         ),
    .clk                (clk_50m       ),    
    .ID_lcd             (lcd_id        ), 
                        
    .cmos_h_pixel       (h_disp        ), 
    .cmos_v_pixel       (v_disp        ), 
    .total_h_pixel      (total_h_pixel ), 
    .total_v_pixel      (total_v_pixel ), 
    .sdram_max_addr     (ddr3_addr_max )  
    );

video_preprocess_top u_video_preprocess_top(	
    .clk          (cam_pclk),	
    .rst_n        (rst_n),	
    .in_valid     (cmos_frame_valid),	
    .in_href      (cmos_frame_href),	
    .in_vsync     (cmos_frame_vsync),	
    .in_rgb565    (wr_data),	
    .manual_mode  (selected_manual_mode),	
    .out_valid    (pp_valid),	
    .out_href     (pp_href),	
    .out_vsync    (pp_vsync),	
    .out_rgb565   (pp_data),	
    .active_mode  (pp_active_mode),	
    .stat_valid   (pp_stat_valid)	
);	
	

	
//ov5640 
ov5640_dri u_ov5640_dri(
    .clk               (clk_50m         ),
    .rst_n             (rst_n           ),
								        
    .cam_pclk          (cam_pclk        ),
    .cam_vsync         (cam_vsync       ),
    .cam_href          (cam_href        ),
    .cam_data          (cam_data        ),
    .cam_rst_n         (cam_rst_n       ),
    .cam_pwdn          (cam_pwdn        ),
    .cam_scl           (cam_scl         ),
    .cam_sda           (cam_sda         ),
    
    .capture_start     (sys_init_done   ),
    .cam_init_done     (cam_init_done   ),
    .cmos_h_pixel      (h_disp          ),
    .cmos_v_pixel      (v_disp          ),
    .total_h_pixel     (total_h_pixel   ),
    .total_v_pixel     (total_v_pixel   ),
    .cmos_frame_vsync  (cmos_frame_vsync),
    .cmos_frame_href   (cmos_frame_href ),
    .cmos_frame_valid  (cmos_frame_valid),
    .cmos_frame_data   (wr_data         )
    );

//ddr3
ddr3_top u_ddr3_top(
    .refclk_in             (clk_50m         ),
    .rst_n                 (rst_n           ),
    .app_addr_rd_min       (APP_ADDR_MIN    ),
    .app_addr_rd_max       (ddr3_addr_max   ),
    .rd_bust_len           (BURST_LENGTH    ),
    .app_addr_wr_min       (APP_ADDR_MIN    ),
    .app_addr_wr_max       (ddr3_addr_max   ),
    .wr_bust_len           (BURST_LENGTH    ),
    .ddr3_read_valid       (1'b1            ),
    .ddr3_pingpang_en      (1'b1            ),
    .wr_clk                (cam_pclk        ),
    .rd_clk                (lcd_clk         ),
    .datain_valid          (pp_valid		),
    .datain                (pp_data         ),
    .rdata_req             (rdata_req       ),
    .rd_load               (out_vsync       ),
    .wr_load               (pp_vsync		),
    .fram_done             (fram_done       ),
    .dataout               (rd_data         ),
    .pll_lock              (pll_lock        ),
    .ddr_init_done         (ddr_init_done   ),
    .ddrphy_rst_done       (                ),
    .pad_loop_in           (pad_loop_in     ),
    .pad_loop_in_h         (pad_loop_in_h   ),
    .pad_rstn_ch0          (pad_rstn_ch0    ),
    .pad_ddr_clk_w         (pad_ddr_clk_w   ),
    .pad_ddr_clkn_w        (pad_ddr_clkn_w  ),
    .pad_csn_ch0           (pad_csn_ch0     ),
    .pad_addr_ch0          (pad_addr_ch0    ),
    .pad_dq_ch0            (pad_dq_ch0      ),
    .pad_dqs_ch0           (pad_dqs_ch0     ),
    .pad_dqsn_ch0          (pad_dqsn_ch0    ),
    .pad_dm_rdqs_ch0       (pad_dm_rdqs_ch0 ),
    .pad_cke_ch0           (pad_cke_ch0     ),
    .pad_odt_ch0           (pad_odt_ch0     ),
    .pad_rasn_ch0          (pad_rasn_ch0    ),
    .pad_casn_ch0          (pad_casn_ch0    ),
    .pad_wen_ch0           (pad_wen_ch0     ),
    .pad_ba_ch0            (pad_ba_ch0      ),
    .pad_loop_out          (pad_loop_out    ),
    .pad_loop_out_h        (pad_loop_out_h  )
    
    );  

	

udp_frame_tx_top #(
    .BOARD_MAC(48'h02_00_00_00_00_22),     // ATK 板 MAC
    .BOARD_IP ({8'd192,8'd168,8'd1,8'd10}),// ATK 板 IP = 192.168.1.10

    .DES_MAC  (48'h02_00_00_00_50_01),     // MES50H MAC
    .DES_IP   ({8'd192,8'd168,8'd1,8'd100}),// MES50H IP = 192.168.1.100

    .WIDTH(16'd800),
    .HEIGHT(16'd480),
    .SEND_FRAME_INTERVAL(16'd30)
) u_udp_frame_tx_top (	
    .rst_n          (rst_n),	
    .cam_pclk       (lcd_clk),
    .img_vsync      (lcd_frame_start_udp),
    .img_valid      (lcd_rgb565_udp_valid),
    .img_data       (lcd_rgb565_udp_data),
    .mode           (udp_lcd_mode),	
    .eth_rxc        (eth_rxc),	
    .eth_rx_ctl     (eth_rx_ctl),	
    .eth_rxd        (eth_rxd),	
    .eth_txc        (eth_txc),	
    .eth_tx_ctl     (eth_tx_ctl),	
    .eth_txd        (eth_txd),	
    .eth_rst_n      (eth_rst_n),	
    .transfer_flag  (eth_transfer_flag),	
    .manual_mode    (eth_manual_mode)	
);	
	
	
	
	
	
	
	
//LCDrgb
lcd_rgb_top  u_lcd_rgb_top(
    .sys_clk               (clk_50m       ),
    .clk_100m              (clk_100m      ),
    .sys_rst_n             (rst_n         ),
    .sys_init_done         (sys_init_done ),
 
    .lcd_id                (lcd_id        ), 
    .lcd_hs                (lcd_hs        ), 
    .lcd_vs                (lcd_vs        ), 
    .lcd_de                (lcd_de        ), 
    .lcd_rgb               (lcd_rgb       ), 
    .lcd_bl                (lcd_bl        ), 
    .lcd_rst               (lcd_rst       ), 
    .lcd_pclk              (lcd_pclk      ), 
    .lcd_clk               (lcd_clk       ), 
                                   
    .h_disp                (              ), 
    .v_disp                (              ), 
    .pixel_xpos            (              ),
    .pixel_ypos            (              ), 
    .out_vsync             (out_vsync     ), 
    .data_in               (rd_data       ), 
    .data_req              (rdata_req     ),
    .lcd_frame_start       (lcd_frame_start_udp),
    .lcd_rgb565_valid      (lcd_rgb565_udp_valid),
    .lcd_rgb565_out        (lcd_rgb565_udp_data)
    );

endmodule