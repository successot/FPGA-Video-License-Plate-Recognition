# OV5640 LCD UDP FPGA Video Project

本项目是一个基于 FPGA 的 OV5640 摄像头视频采集与 UDP 图像传输工程。系统完成摄像头初始化、RGB565 图像采集、DDR3 帧缓存、LCD 本地显示，以及 RGMII/UDP 视频数据发送，可作为智能交通视觉系统的前端图像采集模块。

## 功能特点

- OV5640 摄像头 SCCB/I2C 初始化
- RGB565 图像采集与时序处理
- DDR3 视频帧缓存读写
- LCD 实时显示输出
- RGMII/GMII 以太网发送链路
- UDP 图像数据封装与发送
- 图像亮度统计、Gamma 调节和调试显示叠加
- 保留完整 FPGA 工程文件、约束文件和 IP 核配置

## 目录结构

```text
.
├── rtl/                  # 摄像头、LCD、DDR3 等基础 RTL 源码
├── prj/
│   ├── ATK_ov5640_lcd_udp.pds                 # FPGA 工程文件
│   ├── ATK_DFPGL22G_ov5640_lcd_udp_total.fdc  # 主约束文件
│   ├── cdc_timing_exceptions.fdc              # CDC/时序例外约束
│   ├── ipcore/                                # PLL、DDR3、FIFO 等 IP 核，已保留
│   └── source/                                # 以太网、UDP、图像预处理等扩展 RTL 源码
└── README.md
```

## 视频链路

```text
OV5640 Camera
      │
      ▼
CMOS Capture / RGB565
      │
      ├── DDR3 Frame Buffer
      │       │
      │       ▼
      │     LCD Display
      │
      └── Video Preprocess
              │
              ▼
        UDP/RGMII Transmit
```

## 使用说明

1. 使用 FPGA 开发工具打开 `prj/ATK_ov5640_lcd_udp.pds`。
2. 确认目标器件、管脚约束和 DDR3 参数与实际硬件一致。
3. 确认 `prj/ipcore/` 下的 PLL、DDR3、FIFO 等 IP 文件完整存在。
4. 重新执行综合、布局布线、时序分析和 bitstream 生成。
5. 如需修改 UDP 目标 IP、MAC、端口或视频模式，请查看 `prj/source/rtl/` 下的以太网与视频预处理相关模块。

## GitHub 版本说明

本仓库版本已移除综合、布局布线、时序报告、bitstream 生成结果、日志和本机缓存文件，仅保留可维护的源码、约束、工程配置和必要 IP 文件。首次拉取后需要在本地重新生成编译结果。
