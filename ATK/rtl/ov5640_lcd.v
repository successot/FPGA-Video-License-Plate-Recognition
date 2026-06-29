

module ov5640_lcd(
    input             sys_clk          ,
    input             sys_rst_n        ,
    //lcdӿ                         
    output            lcd_hs           ,  //LCD ͬź
    output            lcd_vs           ,  //LCD ͬź
    output            lcd_de           ,  //LCD ʹ
    inout  [23:0]     lcd_rgb          ,  //LCD ɫ
    output            lcd_bl           ,  //LCD ź
    output            lcd_rst          ,  //LCD λź
    output            lcd_pclk         ,  //LCD ʱ
    //ͷӿ                       
    input             cam_pclk         ,  //cmos ʱ
    input             cam_vsync        ,  //cmos ͬź
    input             cam_href         ,  //cmos ͬź
    input  [7:0]      cam_data         ,  //cmos 
    output            cam_rst_n        ,  //cmos λźţ͵ƽЧ
    output            cam_pwdn         ,  //Դģʽѡ 0ģʽ 1Դģʽ
    output            cam_scl          ,  //cmos SCCB_SCL
    inout             cam_sda          ,  //cmos SCCB_SDA
    //DDR3ӿ
    input             pad_loop_in      ,  //λ¶Ȳ
    input             pad_loop_in_h    ,  //λ¶Ȳ
    output            pad_rstn_ch0     ,  //Memoryλ
    output            pad_ddr_clk_w    ,  //Memoryʱ
    output            pad_ddr_clkn_w   ,  //MemoryʱӸ
    output            pad_csn_ch0      ,  //MemoryƬѡ
    output [15:0]     pad_addr_ch0     ,  //Memoryַ
    inout  [16-1:0]   pad_dq_ch0       ,  //
    inout  [16/8-1:0] pad_dqs_ch0      ,  //ʱ
    inout  [16/8-1:0] pad_dqsn_ch0     ,  //ʱӸ
    output [16/8-1:0] pad_dm_rdqs_ch0  ,  //Mask
    output            pad_cke_ch0      ,  //Memoryʱʹ
    output            pad_odt_ch0      ,  //On Die Terminati
    output            pad_rasn_ch0     ,  //еַstrobe
    output            pad_casn_ch0     ,  //еַstrobe
    output            pad_wen_ch0      ,  //дʹ
    output [2:0]      pad_ba_ch0       ,  //Bankַ
    output            pad_loop_out     ,  //λ¶Ȳ
    output            pad_loop_out_h   ,    //λ¶Ȳ
	input        	  eth_rxc,
	input        	  eth_rx_ctl,
	input  [3:0] 	  eth_rxd,
	output       	  eth_txc,
	output       	  eth_tx_ctl,
	output [3:0] 	  eth_txd,
	output       	  eth_rst_n
   );

//parameter define
parameter APP_ADDR_MIN = 28'd0        ; //ddr3дʼַһ16bitΪһλ
parameter BURST_LENGTH = 8'd64        ; //ddr3дͻȣ64128bit

//wire define
wire        sys_init_done   ;  //ϵͳʼ(DDR3ʼ+ͷʼ)
wire        rst_n           ;  //ȫָλ 
//PLL
wire        clk_50m         ;  //output 50M
wire        clk_100m        ;  //output 100M
wire        clk_locked      ;
//ͷֱ
wire [12:0] h_disp          ;  //ov5640ˮƽֱ
wire [12:0] v_disp          ;  //ov5640ֱֱ
wire [12:0] total_h_pixel   ;  //ˮƽشС
wire [12:0] total_v_pixel   ;  //ֱشС
wire [27:0] ddr3_addr_max   ;  //DDR3дַ
//OV5640
wire        cam_init_done   ;  //ͷʼ
wire        cmos_frame_vsync;  //֡Чź
wire        cmos_frame_href ;  //Чź
wire        cmos_frame_valid;  //Чʹź
wire [15:0] wr_data         ;  //OV5640дDDR3ģ
//LCD                       
wire        lcd_clk         ;  //ƵLCD ʱ
wire [15:0] lcd_id          ;  //LCDID
wire        out_vsync       ;  //LCDź
wire        rdata_req       ;  //
//DDR3
wire [15:0] rd_data         ;  //DDR3ģ
wire        fram_done       ;  //DDRѾһ֡־
wire        ddr_init_done   ;  //ddr3ʼ

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

// UDP uses the DDR/LCD read-side stream. This avoids saving frames composed
// from a live camera write stream and prevents cross-frame tearing on PC.
wire        lcd_frame_start_udp;
wire        lcd_rgb565_udp_valid;
wire [15:0] lcd_rgb565_udp_data;
reg  [2:0]  pp_active_mode_lcd_d0;
reg  [2:0]  pp_active_mode_lcd_d1;
wire [2:0]  udp_lcd_mode;
//*****************************************************
//**                    main code
//*****************************************************

// 以太网命令 manual_mode 跨到 cam_pclk 视频域。
// eth_manual_mode 变化频率很低，只用于人工切换 raw/gamma/auto/debug 模式，
// 两级同步后送入 video_preprocess_top，避免 eth_rxc/gmii_rx_clk 到 cam_pclk 的直接 CDC 路径。
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

// active_mode comes from cam_pclk; synchronize it into lcd_clk for UDP headers.
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



//ʱλź
assign  rst_n = sys_rst_n & clk_locked;

//ϵͳʼɣDDR3ͷʼ
//DDR3ʼд
assign  sys_init_done = ddr_init_done & cam_init_done;

//PLL IP
pll_clk  u_pll_clk(
    .pll_rst        (~sys_rst_n  ),
    .clkin1         (sys_clk     ),
    .clkout0        (clk_50m     ),
    .clkout1        (clk_100m    ),
    .pll_lock       (clk_locked  )
);

//ͷͼֱģ
picture_size u_picture_size (
    .rst_n              (rst_n         ),
    .clk                (clk_50m       ),    
    .ID_lcd             (lcd_id        ), //LCDID
                        
    .cmos_h_pixel       (h_disp        ), //ͷˮƽֱ
    .cmos_v_pixel       (v_disp        ), //ͷֱֱ  
    .total_h_pixel      (total_h_pixel ), //ˮƽشС
    .total_v_pixel      (total_v_pixel ), //ֱشС
    .sdram_max_addr     (ddr3_addr_max )  //ddr3дַ
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
	
	
	
	
	
	
	
//LCDʾģ
lcd_rgb_top  u_lcd_rgb_top(
    .sys_clk               (clk_50m       ),
    .clk_100m              (clk_100m      ),
    .sys_rst_n             (rst_n         ),
    .sys_init_done         (sys_init_done ),
    //lcdӿ
    .lcd_id                (lcd_id        ), //LCDID 
    .lcd_hs                (lcd_hs        ), //LCD ͬź
    .lcd_vs                (lcd_vs        ), //LCD ͬź
    .lcd_de                (lcd_de        ), //LCD ʹ
    .lcd_rgb               (lcd_rgb       ), //LCD ɫ
    .lcd_bl                (lcd_bl        ), //LCD ź
    .lcd_rst               (lcd_rst       ), //LCD λź
    .lcd_pclk              (lcd_pclk      ), //LCD ʱ
    .lcd_clk               (lcd_clk       ), //LCD ʱ
    //ûӿ                                  
    .h_disp                (              ), //зֱ
    .v_disp                (              ), //ֱ
    .pixel_xpos            (              ),
    .pixel_ypos            (              ), 
    .out_vsync             (out_vsync     ), 
    .data_in               (rd_data       ), //rfifo
    .data_req              (rdata_req     ),
    .lcd_frame_start       (lcd_frame_start_udp),
    .lcd_rgb565_valid      (lcd_rgb565_udp_valid),
    .lcd_rgb565_out        (lcd_rgb565_udp_data)
    );

endmodule