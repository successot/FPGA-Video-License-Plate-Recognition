# HP_BMV4 FPGA Multi-Channel Video Receiver

本项目是一个面向智能交通视觉系统的 FPGA 后端视频处理工程，主要用于接收多路以太网视频流，完成 GMII/QSGMII/SFP 接入、DDR3 帧缓存、HDMI 显示输出，并提供车牌候选区域的硬件辅助检测与动态框选显示逻辑。

该工程适合作为完整车牌识别系统中的后端显示与预处理模块，也可以单独用于 FPGA 多路视频接收、DDR3 视频缓存和 HDMI 输出实验。

## Features

- 多路 GMII/QSGMII/SFP 视频流接收
- UDP/视频流解析与通道状态监测
- DDR3 视频帧缓存读写控制
- 多路视频画面拼接与 HDMI 输出
- 车牌候选区域颜色/边缘融合预处理
- Sobel 边缘检测、膨胀、投影和候选框生成
- 动态车牌框叠加显示
- 保留完整 RTL 源码、约束文件、工程文件和 IP 配置/IP 核目录

## Project Structure

```text
.
├── MES50HP.pds                               # 主 FPGA 工程文件
├── constraints/                              # 管脚、时序和接口约束
├── source/                                   # 顶层、多通道接收、DDR/HDMI、车牌处理 RTL
│   ├── plate/                                # 车牌候选区域检测与框选叠加模块
│   └── rtl/                                  # DDR3、HDMI、缓存、I2C/显示等基础模块
│       ├── DDR3_50H/                         # DDR3 IP 配置与生成源码，已保留
│       ├── pll/                              # PLL IP 配置与生成源码，已保留
│       ├── rd_fram_buf/                      # 读帧缓存 IP，已保留
│       └── wr_fram_buf/                      # 写帧缓存 IP，已保留
├── ipcore/                                   # HSST/QSGMII 等高速接口 IP，已保留
└── README.md
```

## System Pipeline

```text
Ethernet / SFP / QSGMII Video Input
        │
        ▼
GMII Video Receive and Monitor
        │
        ▼
DDR3 Frame Buffer
        │
        ▼
Video Readout / Quad Display Composition
        │
        ├── HDMI Output
        │
        └── Plate Region Preprocess and Overlay
```

## Plate Preprocess Modules

`source/plate/` 中包含车牌区域硬件辅助处理模块，主要包括：

- `plate_rgb565_preprocess.v`：RGB565 输入预处理
- `plate_sobel3x3_vertical.v`：垂直边缘提取
- `plate_color_sobel_fuse_aligned.v`：颜色与边缘特征融合
- `plate_mask_dilate_h9_v3.v`：候选掩膜膨胀
- `plate_edge_morph_bbox_project.v`：投影与候选框生成
- `plate_overlay_bbox_dynamic.v`：动态框选叠加显示
- `plate_overlay_box.v`：基础框选显示模块

## How to Build

1. 使用对应 FPGA 工具打开 `MES50HP_F14X_WRAP_FRAMESTART_PUBLISH.pds`。
2. 检查 `constraints/` 中约束文件是否与实际板卡、接口和引脚一致。
3. 确认 `source/rtl/` 和 `ipcore/` 下的 IP 文件完整存在。
4. 在本地重新执行综合、布局布线、时序分析和 bitstream 生成。
5. 如需调整输入通道、分辨率、HDMI 输出或车牌框选阈值，请优先查看 `source/` 和 `source/plate/` 下的顶层参数及模块连接。

## GitHub Source Version

本仓库版本已移除综合、布局布线、时序报告、bitstream、日志、缓存、补丁交接文档和本机路径痕迹，仅保留可维护源码、工程文件、约束文件和必要 IP 内容。首次拉取后需要在本地重新生成实现结果。
