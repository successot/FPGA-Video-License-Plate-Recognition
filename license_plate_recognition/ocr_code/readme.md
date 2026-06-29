train_ocr_round1.py
最早的基础 OCR 训练脚本。最初完整训练代码，不是后期最优。

train_ocr_round2.py
第二轮修正版训练，依赖上一轮权重。

train_ocr_round4.py
最佳完整训练代码。

train_ocr_round5_v2.py
Round5 保守增强版，逻辑也较完整，从Round4 best 权重继续精调。

train_ocr_round5_swa.py
Round5 + SWA，对照增强版，也是从 Round4 best 权重开始。

train_ocr_round6.py
Round6 tiny refine，从 Round5 best 继续微调。

train_ocr_round6_1.py
对应你保存的 6.1 权重，是继续微调脚本。

train_ocr_round6_3.py
对应 6.3，是继续微调脚本。

train_ocr_round6_3a.py
对应 6.3a，是非常小步的省份修复微调脚本,修复对皖字的依赖。