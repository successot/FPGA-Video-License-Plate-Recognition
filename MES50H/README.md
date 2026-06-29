# H_U2_S0 Bridge FPGA Project

中间桥接子工程，主要用于 SFP0/QSGMII/以太网链路的数据流转发与接口适配。

主工程文件：

```text
MES50H_CLEAN_SFP0_BRIDGE.pds
```

关键目录：

```text
source/   # 桥接逻辑、端口状态、链路适配 RTL
ipcore/   # DDR3、FIFO、HSST、QSGMII 等 IP，已保留
```
