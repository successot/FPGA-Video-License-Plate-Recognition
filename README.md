# FPGA Video Pipeline and License Plate Recognition System

本项目是一个面向智能交通场景的车牌识别视觉系统，结合 FPGA 实时视频处理能力与深度学习车牌识别模型，实现从摄像头图像采集、网络传输、视频缓存显示，到车牌检测与 OCR 识别的完整流程。

项目由 FPGA 视频链路工程和 Python 深度学习训练工程两部分组成。FPGA 端负责 OV5640 摄像头图像采集、RGB565 图像流处理、DDR3 帧缓存、UDP/RGMII 网络传输、多路视频接收以及 HDMI 显示输出；算法端提供车牌检测模型和车牌字符识别模型的训练代码，并包含适用于 RK3568 平台的部署程序与模型权重。

## Features

* OV5640 摄像头图像采集与 I2C 初始化配置
* RGB565 视频流捕获、缓存与显示
* DDR3 帧缓存读写控制
* UDP/RGMII 图像数据传输
* 多路 GMII/QSGMII/SFP 视频链路接收
* HDMI 实时视频输出
* FPGA 端车牌候选区域预处理与动态框选显示
* 基于 PyTorch 的车牌检测模型训练
* 基于 CTC OCR 的车牌字符识别训练
* RK3568 端车牌识别部署程序
* 适用于智能交通、边缘视觉、FPGA 图像处理等场景

## Project Structure

```text
.
├── fpga_camera_udp/
│   ├── rtl/                  # 摄像头采集、LCD 显示、DDR3、UDP 发送等 Verilog 模块
│   ├── constraints/          # FPGA 管脚与时序约束
│   ├── ipcore/               # PLL、DDR3、FIFO 等 IP 配置或封装
│   └── project/              # FPGA 工程配置文件
│
├── fpga_video_bridge/
│   ├── atk_frontend/         # 前端摄像头采集与 UDP 输出工程
│   ├── ethernet_bridge/      # 以太网/QSGMII/SFP 桥接工程
│   └── hp_receiver/          # 后端多路接收、DDR3 缓存与 HDMI 显示工程
│
├── fpga_hdmi_plate_overlay/
│   ├── source/               # 后端视频接收与 HDMI 显示核心源码
│   ├── source/plate/         # 车牌候选区域检测、形态学处理和框选叠加模块
│   ├── constraints/          # 约束文件
│   └── ipcore/               # 高速接口、DDR3、FIFO 等 IP
│
└── license_plate_recognition/
    ├── detector_train/       # 车牌检测训练代码
    ├── ocr_train/            # 车牌 OCR 多轮训练代码
    ├── weights/              # 训练得到的检测与 OCR 权重
    └── rk3568_app/           # RK3568 平台部署程序
```

## System Pipeline

```text
OV5640 Camera
      │
      ▼
FPGA Image Capture
      │
      ├── LCD Local Preview
      │
      └── UDP/RGMII Video Stream
              │
              ▼
 Ethernet / QSGMII / SFP Bridge
              │
              ▼
FPGA Multi-channel Receiver
              │
              ▼
DDR3 Frame Buffer
              │
              ▼
HDMI Display + Plate Region Overlay
              │
              ▼
License Plate Detection and OCR Recognition
```

## AI Training Modules

The license plate recognition part contains two main training pipelines:

1. **Plate Detector**

   The detector is trained to locate the license plate region in an input image. It uses a lightweight CNN backbone and bounding-box regression head, making it suitable for embedded deployment.

2. **Plate OCR**

   The OCR model uses a MobileNetV3-based feature extractor and CTC decoding to recognize license plate characters. Multiple training rounds are included for baseline training, fine-tuning, hard-sample mining, and province-character correction.

## Deployment

The project includes an RK3568 executable for edge-side deployment. The recommended deployment flow is:

1. Capture or receive video frames from the FPGA video pipeline.
2. Run plate detection to locate candidate plate regions.
3. Crop and preprocess the plate region.
4. Run OCR recognition.
5. Display or transmit the recognition result.

## Notes

* Large model weights should be stored with Git LFS or uploaded to GitHub Releases.
* FPGA build caches, logs, temporary reports, and generated intermediate files are not included in the source repository.
* Some FPGA IP cores may need to be regenerated with the corresponding FPGA development toolchain.
* Dataset files are not included. Training scripts require users to prepare image lists, labels, and charset files according to the documented format.

## Applications

* Intelligent transportation systems
* License plate recognition terminals
* FPGA-based real-time video processing
* Edge AI visual recognition
* Multi-board FPGA video transmission experiments
* Embedded vision course projects or research prototypes
