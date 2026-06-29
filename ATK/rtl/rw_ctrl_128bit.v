

`timescale 1ps/1ps

module rw_ctrl_128bit 
 (
    input                 clk              , //时钟
    input                 rst_n            , //复位
    input                 ddr_init_done    , //DDR初始化完成
    output      [32-1:0]  axi_awaddr       , //写地址
    output reg  [7:0   ]  axi_awlen        , //写突发长度
    output wire [2:0   ]  axi_awsize       , //写突发大小
    output wire [1:0   ]  axi_awburst      , //写突发类型
    output                axi_awlock       , //写锁定类型
    input                 axi_awready      , //写地址准备信号
    output reg            axi_awvalid      , //写地址有效信号
    output                axi_awurgent     , //写紧急信号,1:Write address指令优先执行
    output                axi_awpoison     , //写抑制信号,1:Write address指令无效
    output wire [15:0  ]  axi_wstrb        , //写选通
    output reg            axi_wvalid       , //写数据有效信号
    input                 axi_wready       , //写数据准备信号
    output reg            axi_wlast        , //最后一次写信号
    output wire           axi_bready       , //写回应准备信号
    output      [32-1:0]  axi_araddr       , //读地址
    output reg  [7:0   ]  axi_arlen        , //读突发长度
    output wire [2:0   ]  axi_arsize       , //读突发大小
    output wire [1:0   ]  axi_arburst      , //读突发类型
    output wire           axi_arlock       , //读锁定类型
    output wire           axi_arpoison     , //读抑制信号,1:Read address指令无效
    output wire           axi_arurgent     , //读紧急信号,1:Read address指令优先执行
    input                 axi_arready      , //读地址准备信号
    output reg            axi_arvalid      , //读地址有效信号
    input                 axi_rlast        , //最后一次读信号
    input                 axi_rvalid       , //读数据有效信号
    output wire           axi_rready       , //读数据准备信号
    output reg            wrfifo_en_ctrl   , //写FIFO数据读使能控制位
    output reg            fram_done        ,
    input       [10:0  ]  wfifo_rcount     , //写端口FIFO中的数据量
    input       [10:0  ]  rfifo_wcount     , //读端口FIFO中的数据量
    input                 rd_load          , //输出源更新信号
    input                 wr_load          , //输入源更新信号
    input       [27:0  ]  app_addr_rd_min  , //读DDR3的起始地址
    input       [27:0  ]  app_addr_rd_max  , //读DDR3的结束地址
    input       [7:0   ]  rd_bust_len      , //从DDR3中读数据时的突发长度
    input       [27:0  ]  app_addr_wr_min  , //写DDR3的起始地址
    input       [27:0  ]  app_addr_wr_max  , //写DDR3的结束地址
    input       [7:0   ]  wr_bust_len      , //从DDR3中写数据时的突发长度
    input                 ddr3_read_valid  , //DDR3 读使能
    input                 ddr3_pingpang_en   //DDR3 乒乓操作使能
);

//localparam define
localparam IDLE        = 4'd1; //空闲状态
localparam DDR3_DONE   = 4'd2; //DDR3初始化完成状态
localparam WRITE_ADDR  = 4'd3; //写地址
localparam WRITE_DATA  = 4'd4; //写数据
localparam READ_ADDR   = 4'd5; //读地址
localparam READ_DATA   = 4'd6; //读数据

//reg define
reg        init_start  ; //初始化完成信号
reg        wr_end_d0   ;
reg        wr_end_d1   ;
reg        rd_end_d0   ;
reg        rd_end_d1   ;
reg [31:0] axi_awaddr_n; //写地址计数
reg        wr_end      ; //一帧图像写结束信号
reg [31:0] init_addr   ; //突发长度计数器
reg [27:0] lenth_cnt   ; //对突发写长度进行计数
reg [31:0] axi_araddr_n; //读地址计数
reg        rd_end      ; //一帧图像读结束信号
reg [1:0 ] raddr_page  ; //ddr3读地址切换信号
reg [1:0 ] waddr_page  ; //ddr3写地址切换信号
reg        rd_load_d0  ;
reg        rd_load_d1  ;
reg        wr_load_d0  ;
reg        wr_load_d1  ;
reg        wr_rst      ; //输入源帧复位标志
reg        rd_rst      ; //输出源帧复位标志
reg        raddr_rst_h ; //输出源的帧复位脉冲
reg [3:0 ] state_cnt   ; //状态计数器

//wire define
wire       wr_end_r     ;
wire       rd_end_r     ;
wire[27:0] lenth_cnt_max; //最大突发次数

//*****************************************************
//**                    main code
//*****************************************************

assign  axi_awlock   = 1'b0      ;
assign  axi_awurgent = 1'b0      ;
assign  axi_awpoison = 1'b0      ;
assign  axi_bready   = 1'b1      ;
assign  axi_wstrb    = {16{1'b1}};
assign  axi_awsize   = 3'b100    ;
assign  axi_awburst  = 2'd1      ;
assign  axi_arlock   = 1'b0      ;
assign  axi_arurgent = 1'b0      ;
assign  axi_arpoison = 1'b0      ;
assign  axi_arsize   = 3'b100    ;
assign  axi_arburst  = 2'd1      ;
assign  axi_rready   = 1'b1      ;

//读/写结束信号上升沿
assign wr_end_r=wr_end_d0&&(~wr_end_d1);
assign rd_end_r=rd_end_d0&&(~rd_end_d1);

//乒乓操作
assign axi_araddr=ddr3_pingpang_en?{4'b0,raddr_page,axi_araddr_n[24:0],1'b0}:{6'b0,axi_araddr_n[24:0],1'b0};
assign axi_awaddr=ddr3_pingpang_en?{4'b0,waddr_page,axi_awaddr_n[24:0],1'b0}:{6'b0,axi_awaddr_n[24:0],1'b0};

//计算最大突发次数
assign lenth_cnt_max = app_addr_wr_max / (wr_bust_len * 8);

//稳定ddr3初始化信号
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
        init_start <= 1'b0;
    else if (ddr_init_done)
        init_start <= ddr_init_done;
    else
        init_start <= init_start;
end

//对异步信号进行打拍处理
always @(posedge clk or negedge rst_n)  begin
    if(~rst_n)begin
        wr_end_d0<= 0;
        wr_end_d1<= 0;
        rd_end_d0<= 0;
        rd_end_d1<= 0;
    end   
    else begin
        wr_end_d0<= wr_end;
        wr_end_d1<= wr_end_d0;
        rd_end_d0<= rd_end;
        rd_end_d1<= rd_end_d0;
    end
end

//写地址模块
always @(posedge clk or negedge rst_n)
begin
    if (!rst_n) begin
        axi_awaddr_n <= app_addr_wr_min;
        axi_awlen    <= 8'b0;
        axi_awvalid  <= 1'b0;
        wr_end       <= 1'b0;
    end
    else if(wr_rst)begin
        axi_awaddr_n <= app_addr_wr_min;
        wr_end <= 1'b0;
    end 
    else if(init_start) begin
        axi_awlen <= wr_bust_len - 1;
        if (axi_awaddr_n < app_addr_wr_max - wr_bust_len * 5'd8) begin
                wr_end <= 1'b0;
            if(axi_awvalid && axi_awready)begin
                axi_awvalid <= 1'b0;
                axi_awaddr_n <= axi_awaddr_n + wr_bust_len * 5'd8;//wr_bust_len*128/16
            end
            else if(state_cnt == WRITE_ADDR && axi_awready)begin
                axi_awvalid <= 1'b1;
                wr_end <= 1'b0;
            end
        end
        else if(axi_awaddr_n == app_addr_wr_max - wr_bust_len * 5'd8) begin
            if(axi_awvalid && axi_awready) begin
                axi_awvalid <= 1'b0;
                axi_awaddr_n <= app_addr_wr_min; 
                wr_end <= 1'b1;
            end
            else if(state_cnt == WRITE_ADDR && axi_awready)begin
                axi_awvalid <= 1'b1;
            end
        end
        else
            axi_awvalid <= 1'b0;
    end 
    else begin
            axi_awaddr_n   <= axi_awaddr_n;
            axi_awlen      <= 8'b0;
            axi_awvalid    <= 1'b0;
    end
end

//写数据模块
always @(posedge clk or negedge rst_n)
begin
    if (!rst_n) begin
        axi_wvalid <= 1'b0    ;
        axi_wlast  <= 1'b0    ;
        init_addr  <= 32'd0 ; 
        lenth_cnt  <= 28'd0   ;
    end
    else begin
        if(init_start) begin
            if(lenth_cnt < lenth_cnt_max)begin
                if(axi_wvalid && axi_wready && init_addr < wr_bust_len - 2'd2) begin
                    init_addr <= init_addr + 1'b1;
                    wrfifo_en_ctrl <= 1'b0;
                end
                else if(axi_wvalid && axi_wready && init_addr == wr_bust_len - 2'd2) begin
                    axi_wlast  <= 1'b1;
                    wrfifo_en_ctrl<= 1'b1;
                    init_addr  <= init_addr + 1'b1;
                end
                else if(axi_wvalid && axi_wready && init_addr == wr_bust_len - 2'd1) begin
                    axi_wvalid <= 1'b0;
                    axi_wlast  <= 1'b0;
                    wrfifo_en_ctrl <= 1'b0;
                    lenth_cnt  <= lenth_cnt+1'b1;
                    init_addr  <= 32'd0;
                end
                else if(state_cnt == WRITE_DATA && axi_wready)
                    axi_wvalid <= 1'b1;
                else begin
                    lenth_cnt <= lenth_cnt;
                end
            end
            else begin
                axi_wvalid <= 1'b0   ;
                axi_wlast  <= 1'b0   ;
                init_addr  <= init_addr;
                lenth_cnt  <= 28'd0;
                
            end
        end
        else begin
            axi_wvalid <= 1'b0   ;
            axi_wlast  <= 1'b0   ;
            init_addr  <= 32'd0;
            lenth_cnt  <= 28'd0   ;
        end
    end
end

//读地址模块
always @(posedge clk or negedge rst_n)
begin
    if (!rst_n) begin
      axi_araddr_n <= app_addr_rd_min;
      axi_arlen    <= 8'b0;
      axi_arvalid  <= 1'b0;
      rd_end       <= 1'b0;
    end
    else if(raddr_rst_h)
        axi_araddr_n <= app_addr_rd_min;
    else if(init_start) begin
        axi_arlen <= rd_bust_len - 1'b1;
        if (axi_araddr_n < app_addr_rd_max - rd_bust_len * 5'd8) begin
            rd_end <= 1'b0;
            if(axi_arready && axi_arvalid)begin
                axi_arvalid <= 1'b0;
                axi_araddr_n <= axi_araddr_n + rd_bust_len * 5'd8;
            end
            else if(axi_arready && state_cnt == READ_ADDR)begin
                rd_end <= 1'b0;
                axi_arvalid <= 1'b1;
            end
        end
        else if(axi_araddr_n == app_addr_rd_max - rd_bust_len * 5'd8) begin
            if(axi_arready && axi_arvalid)begin
                axi_arvalid <= 1'b0;
                axi_araddr_n <= app_addr_rd_min;
                rd_end <= 1'b1;
            end
            else if(axi_arready && state_cnt==READ_ADDR)
                axi_arvalid <= 1'b1;
        end
        else
            axi_arvalid <= 1'b0;
    end
    else begin
            axi_araddr_n <= app_addr_rd_min;
            axi_arlen    <= 8'b0;
            axi_arvalid  <= 1'b0;
    end     
end

//对信号进行打拍处理
always @(posedge clk or negedge rst_n)  begin
    if(~rst_n)begin
        rd_load_d0 <= 0;
        rd_load_d1 <= 0;
        wr_load_d0 <= 0;
        wr_load_d1 <= 0;
    end   
    else begin
        rd_load_d0 <= rd_load;
        rd_load_d1 <= rd_load_d0;
        wr_load_d0 <= wr_load;
        wr_load_d1 <= wr_load_d0;
    end    
end

//对输入源做个帧复位标志
always @(posedge clk or negedge rst_n)  begin
    if(~rst_n)
        wr_rst <= 0;
    else if(wr_load_d0 && !wr_load_d1)
        wr_rst <= 1;
    else
        wr_rst <= 0;
end

//对输出源做个帧复位标志 
always @(posedge clk or negedge rst_n)  begin
    if(~rst_n)
        rd_rst <= 0;
    else if(!rd_load_d0 && rd_load_d1)
        rd_rst <= 1;
    else
        rd_rst <= 0;
end

//对输出源的读地址做个帧复位脉冲 
always @(posedge clk or negedge rst_n)  begin
    if(~rst_n)
        raddr_rst_h <= 1'b0;
    else if(rd_load_d0 && !rd_load_d1)
        raddr_rst_h <= 1'b1;
    else if(axi_araddr_n == app_addr_rd_min)
        raddr_rst_h <= 1'b0;
    else
        raddr_rst_h <= raddr_rst_h;
end

//对输出源帧的读地址高位切换
always @(posedge clk or negedge rst_n)  begin
    if(~rst_n)
        raddr_page <= 2'b0;
    else if( rd_end_r)
        raddr_page <= waddr_page + 2;
    else
        raddr_page <= raddr_page;
end

//对输入源帧的写地址高位切换
always @(posedge clk or negedge rst_n)  begin
    if(~rst_n) begin
        waddr_page <= 2'b1;
        fram_done<= 1'b0;
    end
    else if( wr_end_r)begin
        fram_done<= 1'b1;
        waddr_page <= waddr_page + 1 ;
    end
    else
        waddr_page <= waddr_page;
end

//DDR3读写逻辑实现
always @(posedge clk or negedge rst_n) begin
    if(~rst_n)
        state_cnt    <= IDLE;
    else begin
        case(state_cnt)
            IDLE:begin
                if(init_start)
                    state_cnt <= DDR3_DONE ;
                else
                    state_cnt <= IDLE;
            end
            DDR3_DONE:begin
                //当帧复位到来时，对寄存器进行复位
                if(wr_rst)
                    state_cnt <= DDR3_DONE;
                //当读到结束地址对寄存器复位
                else if(wfifo_rcount >= wr_bust_len)
                    state_cnt <= WRITE_ADDR;   //跳到写操作
                //当帧复位到来时，对寄存器进行复位
                else if(raddr_rst_h)
                    state_cnt <= DDR3_DONE;
                //当rfifo存储数据少于一次突发长度时,并且ddr已经写入了1帧数据
                else if(rfifo_wcount < rd_bust_len && ddr3_read_valid && fram_done )
                    state_cnt <= READ_ADDR;   //跳到读操作
                else
                    state_cnt <= state_cnt;
            end
            WRITE_ADDR:begin
                if(axi_awvalid && axi_awready)
                    state_cnt <= WRITE_DATA;  //跳到写数据操作
                else
                    state_cnt <= state_cnt;   //条件不满足，保持当前值
            end
            WRITE_DATA: begin
                //写到设定的长度跳到等待状态
                if(axi_wvalid && axi_wready && init_addr == wr_bust_len - 1)
                    state_cnt <= DDR3_DONE;  //写到设定的长度跳到等待状态
                else
                    state_cnt <= state_cnt;  //写条件不满足，保持当前值
            end
            READ_ADDR:begin
                if(axi_arvalid && axi_arready)
                    state_cnt <= READ_DATA;
                else
                    state_cnt <= state_cnt;
            end
            READ_DATA:begin                   //读到设定的地址长度
                if(axi_rlast)
                    state_cnt <= DDR3_DONE;   //则跳到空闲状态
                else                          //若MIG没准备好,则保持原值
                    state_cnt   <= state_cnt; //则跳到空闲状态
            end
            default:begin
                state_cnt    <= IDLE;
            end
        endcase
    end
end

endmodule