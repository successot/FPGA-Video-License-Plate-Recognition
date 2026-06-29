

module gmii_to_rgmii(
    //以太网GMII接口
    output             gmii_rx_clk , //GMII接收时钟
    output             gmii_rx_dv  , //GMII接收数据有效信号
    output      [7:0]  gmii_rxd    , //GMII接收数据
    output             gmii_tx_clk , //GMII发送时钟
    input              gmii_tx_en  , //GMII发送数据使能信号
    input       [7:0]  gmii_txd    , //GMII发送数据            
    //以太网RGMII接口   
    input              rgmii_rxc   , //RGMII接收时钟
    input              rgmii_rx_ctl, //RGMII接收数据控制信号
    input       [3:0]  rgmii_rxd   , //RGMII接收数据
    output             rgmii_txc   , //RGMII发送时钟    
    output             rgmii_tx_ctl, //RGMII发送数据控制信号
    output      [3:0]  rgmii_txd     //RGMII发送数据          
    );
//wire
wire   pll_lock  ;
wire   gmii_tx_er;
//*****************************************************
//**                    main code
//*****************************************************
assign gmii_tx_clk = gmii_rx_clk;
//RGMII接收
rgmii_rx u_rgmii_rx(
    .rgmii_rxc        (rgmii_rxc      ),
    .rgmii_rx_ctl     (rgmii_rx_ctl   ),
    .rgmii_rxd        (rgmii_rxd      ),
                      
    .gmii_rx_clk      (gmii_rx_clk    ),
    .gmii_rx_dv       (gmii_rx_dv     ),
    .gmii_rxd         (gmii_rxd       ),
    .gmii_tx_clk_deg  (gmii_tx_clk_deg),
    .pll_lock         (pll_lock       )
    );

//RGMII发送
rgmii_tx u_rgmii_tx(
    .reset            (1'b0           ),

    .gmii_tx_er       (1'b0           ),
    .gmii_tx_clk      (gmii_tx_clk    ),
    .gmii_tx_en       (gmii_tx_en     ),
    .gmii_txd         (gmii_txd       ),
    .gmii_tx_clk_deg  (gmii_tx_clk_deg),
    
    .rgmii_txc        (rgmii_txc      ),
    .rgmii_tx_ctl     (rgmii_tx_ctl   ),
    .rgmii_txd        (rgmii_txd      )
    );

endmodule