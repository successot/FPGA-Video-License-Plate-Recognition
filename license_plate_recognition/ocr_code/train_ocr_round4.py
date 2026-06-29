#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""

解冻 backbone 时不重建 optimizer / scheduler，避免 lr_scheduler.step() warning
保留 CTC、AMP、梯度裁剪、字符级准确率、多源采样等逻辑
"""

import os
import io
import csv
import json
import math
import random
import contextlib
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
from PIL import Image, ImageFile, ImageFilter, ImageEnhance
ImageFile.LOAD_TRUNCATED_IMAGES = True

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import Dataset, DataLoader
from torchvision.models import mobilenet_v3_small, MobileNet_V3_Small_Weights
from torchvision import transforms

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from tqdm import tqdm


# ===================== 配置区 =====================
CONFIG = {
    "stage_name": "round4_fix_train_val",

    # ====== 数据集 ======
    # 这里统一使用 train / val 作为 source 名
    "train_manifests": {
        "train": r"./data/path_placeholder",
        "val": r"./data/path_placeholder",
    },
    "val_manifests": {
        "train": r"./data/path_placeholder",
        "val": r"./data/path_placeholder",
    },

    "charset_txt": r"./data/path_placeholder",

    # 初始化 checkpoint
    "init_ckpt": r"./data/path_placeholder",

    "save_dir": r"./data/path_placeholder",

    # 输入尺寸
    "img_h": 48,
    "img_w": 320,

    "batch_size": 64,
    "epochs": 25,

    # 学习率策略
    "lr": 3e-4,
    "min_lr": 1e-6,
    "warmup_epochs": 2,
    "weight_decay": 1e-4,
    "grad_clip_norm": 5.0,

    "num_workers": 4,
    "device": "cuda" if torch.cuda.is_available() else "cpu",
    "seed": 42,
    "pretrained_backbone": False,
    "freeze_backbone_epochs": 3,    # 前 3 个 epoch 冻结 backbone
    "early_stop_patience": 8,
    "min_delta": 1e-4,
    "use_amp": True,

    # 训练集每个 epoch 的采样规模与配比（source=train/val）
    "train_total_samples_per_epoch": 160000,
    "train_source_ratio": {"train": 0.7, "val": 0.3},

    # 验证集采样规模与配比（source=train/val）
    "val_total_samples": 40000,
    "val_source_ratio": {"train": 0.7, "val": 0.3},

    # 数据增强
    "augment": True,
    "aug_brightness": (0.6, 1.4),
    "aug_contrast": (0.6, 1.4),
    "aug_color": (0.7, 1.2),
    "aug_affine_prob": 0.4,
    "aug_blur_prob": 0.3,
    "aug_downup_prob": 0.35,
    "aug_jpeg_prob": 0.3,
    "aug_occlude_prob": 0.15,
    "aug_noise_prob": 0.2,
    "aug_erode_dilate_prob": 0.1,
    "aug_perspective_prob": 0.15,

    # 保存与监控策略
    # 可选: composite / val_acc / train_acc / overall_acc
    "save_best_by": "composite",
    # composite = (1 - val_acc_weight) * train_acc + val_acc_weight * val_acc
    "val_acc_weight": 0.7,
}
# ==================================================


def seed_everything(seed=42):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)


def ensure_dir(path):
    Path(path).mkdir(parents=True, exist_ok=True)


# ========== 字符集 ==========
class Charset:
    def __init__(self, charset_txt):
        with open(charset_txt, "r", encoding="utf-8") as f:
            chars = [x.strip() for x in f.readlines() if x.strip()]
        self.blank = "<blank>"
        self.base_chars = chars
        self.chars = [self.blank] + chars
        self.char2id = {c: i for i, c in enumerate(self.chars)}
        self.id2char = {i: c for i, c in enumerate(self.chars)}

    def encode(self, text: str) -> List[int]:
        return [self.char2id[c] for c in text if c in self.char2id]

    def decode_ctc(self, ids) -> str:
        prev = None
        out = []
        for i in ids:
            if i != 0 and i != prev:
                out.append(self.id2char.get(i, "?"))
            prev = i
        return "".join(out)


# ========== 数据加载 ==========
def read_manifest(txt_path: str, charset: Charset, source: str):
    root = Path(txt_path).parent
    samples = []
    with open(txt_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or "\t" not in line:
                continue
            path_str, label = line.split("\t", 1)
            p = Path(path_str)
            if not p.is_absolute():
                p = (root / path_str).resolve()
            label = label.strip().upper().replace(" ", "")
            if not p.exists():
                continue
            if all(c in charset.char2id for c in label) and 7 <= len(label) <= 9:
                samples.append((p, label, source))
    return samples


def make_source_counts(total, ratio_dict):
    ratios = {k: v / sum(ratio_dict.values()) for k, v in ratio_dict.items()}
    counts = {k: int(total * v) for k, v in ratios.items()}
    remain = total - sum(counts.values())
    keys = sorted(ratios.keys(), key=lambda x: total * ratios[x] - counts[x], reverse=True)
    for i in range(remain):
        counts[keys[i % len(keys)]] += 1
    return counts


def choose_samples(samples, n, rng):
    if n <= 0:
        return []
    if n <= len(samples):
        return [samples[i] for i in rng.sample(range(len(samples)), n)]
    return [samples[rng.randrange(len(samples))] for _ in range(n)]


def resize_pad(im, img_h, img_w):
    im = im.convert("RGB")
    scale = min(img_w / im.width, img_h / im.height)
    nw = max(1, int(round(im.width * scale)))
    nh = max(1, int(round(im.height * scale)))
    rs = im.resize((nw, nh), Image.BILINEAR)
    canvas = Image.new("RGB", (img_w, img_h), (127, 127, 127))
    canvas.paste(rs, ((img_w - nw) // 2, (img_h - nh) // 2))
    return canvas


class AugmentedOCRDataset(Dataset):
    def __init__(self, samples, charset, img_h, img_w, augment, cfg):
        self.samples = samples
        self.charset = charset
        self.img_h = img_h
        self.img_w = img_w
        self.augment = augment
        self.cfg = cfg
        self.to_tensor = transforms.ToTensor()
        self.normalize = transforms.Normalize([0.5] * 3, [0.5] * 3)

    def __len__(self):
        return len(self.samples)

    def _jpeg_degrade(self, im, rng):
        quality = rng.randint(30, 85)
        buf = io.BytesIO()
        im.save(buf, format="JPEG", quality=quality)
        buf.seek(0)
        return Image.open(buf).convert("RGB")

    def _down_up(self, im, rng):
        w, h = im.size
        scale = rng.uniform(0.4, 0.85)
        nw, nh = max(8, int(w * scale)), max(4, int(h * scale))
        return im.resize((nw, nh), Image.BILINEAR).resize((w, h), Image.BILINEAR)

    def _affine(self, im, rng):
        angle = rng.uniform(-5.0, 5.0)
        shear = rng.uniform(-4.0, 4.0)
        tx = rng.uniform(-0.05, 0.05) * im.width
        ty = rng.uniform(-0.08, 0.08) * im.height
        return transforms.functional.affine(
            im,
            angle=angle,
            translate=(int(round(tx)), int(round(ty))),
            scale=rng.uniform(0.90, 1.08),
            shear=[shear, 0.0],
            interpolation=transforms.InterpolationMode.BILINEAR,
            fill=127,
        )

    def _occlude(self, im, rng):
        w, h = im.size
        if w < 20 or h < 10:
            return im
        im = im.copy()
        band_w = max(3, int(w * rng.uniform(0.04, 0.12)))
        x0 = rng.randint(0, max(0, w - band_w))
        color = tuple(rng.randint(60, 180) for _ in range(3))
        overlay = Image.new("RGB", (band_w, h), color)
        im.paste(overlay, (x0, 0))
        return im

    def _add_noise(self, im, rng):
        arr = np.array(im, dtype=np.float32)
        noise = np.random.normal(0, rng.uniform(5, 25), arr.shape).astype(np.float32)
        arr = np.clip(arr + noise, 0, 255).astype(np.uint8)
        return Image.fromarray(arr)

    def _perspective(self, im, rng):
        w, h = im.size
        margin_w = int(w * rng.uniform(0.02, 0.08))
        margin_h = int(h * rng.uniform(0.02, 0.10))
        startpoints = [(0, 0), (w, 0), (w, h), (0, h)]
        endpoints = [
            (rng.randint(0, margin_w), rng.randint(0, margin_h)),
            (w - rng.randint(0, margin_w), rng.randint(0, margin_h)),
            (w - rng.randint(0, margin_w), h - rng.randint(0, margin_h)),
            (rng.randint(0, margin_w), h - rng.randint(0, margin_h)),
        ]
        return transforms.functional.perspective(
            im,
            startpoints,
            endpoints,
            interpolation=transforms.InterpolationMode.BILINEAR,
            fill=127,
        )

    def _erode_dilate(self, im, rng):
        if rng.random() < 0.5:
            return im.filter(ImageFilter.MinFilter(3))
        return im.filter(ImageFilter.MaxFilter(3))

    def _augment(self, im, source, rng):
        c = self.cfg

        if rng.random() < 0.9:
            im = ImageEnhance.Brightness(im).enhance(rng.uniform(*c["aug_brightness"]))
        if rng.random() < 0.9:
            im = ImageEnhance.Contrast(im).enhance(rng.uniform(*c["aug_contrast"]))
        if rng.random() < 0.4:
            im = ImageEnhance.Color(im).enhance(rng.uniform(*c["aug_color"]))

        if rng.random() < c["aug_affine_prob"]:
            im = self._affine(im, rng)
        if rng.random() < c["aug_perspective_prob"]:
            im = self._perspective(im, rng)

        if rng.random() < c["aug_blur_prob"]:
            radius = rng.uniform(0.3, 1.5)
            im = im.filter(ImageFilter.GaussianBlur(radius=radius))
        if rng.random() < c["aug_downup_prob"]:
            im = self._down_up(im, rng)
        if rng.random() < c["aug_jpeg_prob"]:
            im = self._jpeg_degrade(im, rng)
        if rng.random() < c["aug_noise_prob"]:
            im = self._add_noise(im, rng)
        if rng.random() < c["aug_erode_dilate_prob"]:
            im = self._erode_dilate(im, rng)

        if rng.random() < c["aug_occlude_prob"]:
            im = self._occlude(im, rng)

        return im

    def __getitem__(self, idx):
        img_path, text, source = self.samples[idx]
        im = Image.open(img_path).convert("RGB")
        if self.augment:
            rng = random.Random()
            im = self._augment(im, source, rng)
        im = resize_pad(im, self.img_h, self.img_w)
        x = self.normalize(self.to_tensor(im))
        y = torch.tensor(self.charset.encode(text), dtype=torch.long)
        return x, y, text, source

    def max_label_len(self):
        return max(len(s[1]) for s in self.samples) if self.samples else 0


def collate_fn(batch):
    images, labels, texts, sources = [], [], [], []
    for x, y, t, s in batch:
        images.append(x)
        labels.append(y)
        texts.append(t)
        sources.append(s)
    label_lengths = torch.tensor([len(y) for y in labels], dtype=torch.long)
    labels_cat = torch.cat(labels) if labels else torch.tensor([], dtype=torch.long)
    return torch.stack(images), labels_cat, label_lengths, texts, sources


# ========== 模型 ==========
class OCRBackbone(nn.Module):
    def __init__(self, pretrained=False, out_index=8, img_h=48, img_w=320):
        super().__init__()
        weights = MobileNet_V3_Small_Weights.DEFAULT if pretrained else None
        base = mobilenet_v3_small(weights=weights)
        self.features = base.features
        self.out_index = out_index
        self.out_channels = self._infer(img_h, img_w)

    def _infer(self, img_h, img_w):
        with torch.no_grad():
            x = torch.zeros(1, 3, img_h, img_w)
            for i, layer in enumerate(self.features):
                x = layer(x)
                if i == self.out_index:
                    return x.shape[1]
        raise RuntimeError("Failed to infer backbone output channels.")

    def forward(self, x):
        for i, layer in enumerate(self.features):
            x = layer(x)
            if i == self.out_index:
                return x
        return x


class MobileNetV3SmallCTC(nn.Module):
    def __init__(self, num_chars, pretrained=False, img_h=48, img_w=320):
        super().__init__()
        self.backbone = OCRBackbone(pretrained=pretrained, out_index=8, img_h=img_h, img_w=img_w)
        self.reduce = nn.Sequential(
            nn.Conv2d(self.backbone.out_channels, 256, 1, 1, 0, bias=False),
            nn.BatchNorm2d(256),
            nn.Hardswish(inplace=True),
            nn.Dropout2d(0.10),
        )
        self.classifier = nn.Conv1d(256, num_chars, kernel_size=1)

    def set_backbone_trainable(self, trainable: bool):
        for p in self.backbone.parameters():
            p.requires_grad = trainable

    def forward(self, x):
        feat = self.backbone(x)
        feat = self.reduce(feat)
        feat = feat.mean(dim=2)
        logits = self.classifier(feat)
        return logits.permute(2, 0, 1)  # [T, B, C]


# ========== 训练辅助 ==========
@torch.no_grad()
def greedy_decode(logits, charset):
    pred = logits.argmax(dim=-1).permute(1, 0)
    return [charset.decode_ctc(seq.tolist()) for seq in pred]


class EarlyStopper:
    def __init__(self, patience=8, min_delta=1e-4):
        self.patience = patience
        self.min_delta = min_delta
        self.best = -float("inf")
        self.bad = 0

    def step(self, metric):
        if metric > self.best + self.min_delta:
            self.best = metric
            self.bad = 0
            return False, True
        self.bad += 1
        return self.bad >= self.patience, False


def get_lr_scheduler(optimizer, cfg):
    warmup = cfg["warmup_epochs"]
    total = cfg["epochs"]
    min_lr = cfg["min_lr"]
    base_lr = cfg["lr"]

    def lr_lambda(epoch):
        if epoch < warmup:
            return (epoch + 1) / warmup
        progress = (epoch - warmup) / max(total - warmup, 1)
        cosine = 0.5 * (1 + math.cos(math.pi * progress))
        return max(min_lr / base_lr, cosine)

    return torch.optim.lr_scheduler.LambdaLR(optimizer, lr_lambda)


# ========== AMP 兼容层 ==========
def _amp_autocast():
    if hasattr(torch.amp, "autocast"):
        try:
            return torch.amp.autocast("cuda")
        except (TypeError, AttributeError):
            pass
    return torch.cuda.amp.autocast()


def _amp_grad_scaler(enabled):
    if hasattr(torch.amp, "GradScaler"):
        try:
            return torch.amp.GradScaler("cuda", enabled=enabled)
        except (TypeError, AttributeError):
            pass
    return torch.cuda.amp.GradScaler(enabled=enabled)


def get_amp_context_and_scaler(device, use_amp=True):
    enabled = device.startswith("cuda") and use_amp

    @contextlib.contextmanager
    def autocast_ctx():
        if enabled:
            with _amp_autocast():
                yield
        else:
            yield

    scaler = _amp_grad_scaler(enabled) if enabled else None
    return autocast_ctx, scaler, enabled


def load_checkpoint_strict(model, ckpt_path, device):
    ckpt = torch.load(ckpt_path, map_location=device)
    state = ckpt.get("model", ckpt) if isinstance(ckpt, dict) else ckpt
    model_state = model.state_dict()

    loaded, skipped, shape_mismatch = [], [], []
    for k, v in state.items():
        if k in model_state:
            if model_state[k].shape == v.shape:
                model_state[k] = v
                loaded.append(k)
            else:
                shape_mismatch.append(
                    f"  {k}: ckpt={list(v.shape)} vs model={list(model_state[k].shape)}"
                )
                skipped.append(k)
        else:
            skipped.append(k)

    model.load_state_dict(model_state, strict=False)

    print(f"\n[Checkpoint] 加载: {ckpt_path}")
    print(f"  成功加载: {len(loaded)} keys")
    print(f"  跳过: {len(skipped)} keys")
    if shape_mismatch:
        print("  ★ Shape 不匹配:")
        for s in shape_mismatch:
            print(s)
        print("  ★ 请确认 img_w 与训练时一致！")

    return ckpt


def build_epoch_data(source_samples, total, ratio_dict, charset, cfg, seed, augment, shuffle):
    counts = make_source_counts(total, ratio_dict)
    rng = random.Random(seed)
    epoch_samples = []

    for src, cnt in counts.items():
        if src not in source_samples:
            print(f"  [WARN] source '{src}' not found, skipping")
            continue
        chosen = choose_samples(source_samples[src], cnt, rng)
        epoch_samples.extend(chosen)

    rng.shuffle(epoch_samples)

    ds = AugmentedOCRDataset(
        epoch_samples, charset, cfg["img_h"], cfg["img_w"], augment, cfg
    )
    loader = DataLoader(
        ds,
        batch_size=cfg["batch_size"],
        shuffle=shuffle,
        num_workers=cfg["num_workers"],
        pin_memory=True,
        collate_fn=collate_fn,
        drop_last=False,
    )
    return ds, loader, counts


def train_one_epoch(model, loader, optimizer, scaler, autocast_ctx, ctc_loss, device, cfg, amp_enabled):
    model.train()
    total_loss = 0.0
    n = 0

    for images, labels_cat, label_lengths, _, _ in tqdm(loader, desc="Train", leave=False):
        images = images.to(device, non_blocking=True)
        labels_cat = labels_cat.to(device)
        label_lengths = label_lengths.to(device)

        optimizer.zero_grad(set_to_none=True)

        with autocast_ctx():
            logits = model(images)
            log_probs = F.log_softmax(logits, dim=-1)
            input_lengths = torch.full(
                (images.shape[0],), logits.shape[0], dtype=torch.long, device=device
            )
            loss = ctc_loss(log_probs, labels_cat, input_lengths, label_lengths)

        if amp_enabled and scaler is not None:
            scaler.scale(loss).backward()
            scaler.unscale_(optimizer)
            nn.utils.clip_grad_norm_(model.parameters(), cfg["grad_clip_norm"])
            scaler.step(optimizer)
            scaler.update()
        else:
            loss.backward()
            nn.utils.clip_grad_norm_(model.parameters(), cfg["grad_clip_norm"])
            optimizer.step()

        total_loss += loss.item()
        n += 1

    return total_loss / max(n, 1)


@torch.no_grad()
def evaluate(model, loader, ctc_loss, charset, device, amp_enabled):
    model.eval()
    total_loss, n = 0.0, 0
    correct, total = 0, 0
    char_correct, char_total = 0, 0
    src_stats = {}

    for images, labels_cat, label_lengths, texts, sources in tqdm(loader, desc="Val", leave=False):
        images = images.to(device, non_blocking=True)
        labels_cat = labels_cat.to(device)
        label_lengths = label_lengths.to(device)

        if amp_enabled:
            with _amp_autocast():
                logits = model(images)
        else:
            logits = model(images)

        log_probs = F.log_softmax(logits.float(), dim=-1)
        input_lengths = torch.full(
            (images.shape[0],), logits.shape[0], dtype=torch.long, device=device
        )
        loss = ctc_loss(log_probs, labels_cat, input_lengths, label_lengths)

        preds = greedy_decode(logits, charset)

        for pred, gt, src in zip(preds, texts, sources):
            total += 1
            if src not in src_stats:
                src_stats[src] = {
                    "correct": 0,
                    "total": 0,
                    "char_correct": 0,
                    "char_total": 0
                }
            src_stats[src]["total"] += 1

            if pred == gt:
                correct += 1
                src_stats[src]["correct"] += 1

            for i in range(min(len(pred), len(gt))):
                char_total += 1
                src_stats[src]["char_total"] += 1
                if pred[i] == gt[i]:
                    char_correct += 1
                    src_stats[src]["char_correct"] += 1

            extra = abs(len(pred) - len(gt))
            char_total += extra
            src_stats[src]["char_total"] += extra

        total_loss += loss.item()
        n += 1

    overall_acc = correct / max(total, 1)
    overall_char_acc = char_correct / max(char_total, 1)

    src_acc = {}
    src_char_acc = {}
    for src, s in src_stats.items():
        src_acc[src] = s["correct"] / max(s["total"], 1)
        src_char_acc[src] = s["char_correct"] / max(s["char_total"], 1)

    return {
        "val_loss": total_loss / max(n, 1),
        "acc": overall_acc,
        "char_acc": overall_char_acc,
        "src_acc": src_acc,
        "src_char_acc": src_char_acc,
        "src_total": {src: s["total"] for src, s in src_stats.items()},
    }


def compute_composite_metric(metrics, cfg):
    val_w = cfg.get("val_acc_weight", 0.7)
    train_acc = metrics["src_acc"].get("train", 0.0)
    val_acc = metrics["src_acc"].get("val", 0.0)
    return (1.0 - val_w) * train_acc + val_w * val_acc


def get_monitor_metric(metrics, cfg):
    mode = cfg.get("save_best_by", "composite")

    if mode == "composite":
        return compute_composite_metric(metrics, cfg), "composite"
    if mode == "val_acc":
        return metrics["src_acc"].get("val", 0.0), "val_acc"
    if mode == "train_acc":
        return metrics["src_acc"].get("train", 0.0), "train_acc"
    if mode == "overall_acc":
        return metrics["acc"], "overall_acc"

    raise ValueError(f"Unsupported save_best_by: {mode}")


def draw_curves(history, save_path):
    e = list(range(1, len(history["train_loss"]) + 1))
    fig, axes = plt.subplots(1, 6, figsize=(24, 4))

    axes[0].plot(e, history["train_loss"], label="train")
    axes[0].plot(e, history["val_loss"], label="val")
    axes[0].legend()
    axes[0].set_title("Loss")

    axes[1].plot(e, history["overall_acc"], label="overall")
    axes[1].plot(e, history["src_train_acc"], label="train_src")
    axes[1].plot(e, history["src_val_acc"], label="val_src")
    axes[1].legend()
    axes[1].set_title("Accuracy")

    axes[2].plot(e, history["char_acc"], label="char_acc")
    axes[2].legend()
    axes[2].set_title("Char Accuracy")

    axes[3].plot(e, history["lr"], label="lr")
    axes[3].legend()
    axes[3].set_title("LR")

    axes[4].plot(e, history["composite"], label="composite")
    axes[4].legend()
    axes[4].set_title("Composite")

    axes[5].plot(e, history["monitor_metric"], label="monitor")
    axes[5].legend()
    axes[5].set_title("Monitor Metric")

    plt.tight_layout()
    plt.savefig(save_path, dpi=150)
    plt.close()


def save_history_csv(history, save_path):
    keys = list(history.keys())
    with open(save_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(keys)
        n = len(history[keys[0]])
        for i in range(n):
            writer.writerow([history[k][i] if i < len(history[k]) else "" for k in keys])


def main():
    cfg = CONFIG
    seed_everything(cfg["seed"])
    ensure_dir(cfg["save_dir"])
    device = cfg["device"]

    charset = Charset(cfg["charset_txt"])
    print(f"字符集: {len(charset.chars)} 字符（含 blank）")

    # 读取训练数据
    train_sources = {}
    for src, path in cfg["train_manifests"].items():
        samples = read_manifest(path, charset, src)
        train_sources[src] = samples
        print(f"训练集 [{src}]: {len(samples)} 样本")

    # 读取验证数据
    val_sources = {}
    for src, path in cfg["val_manifests"].items():
        samples = read_manifest(path, charset, src)
        val_sources[src] = samples
        print(f"验证集 [{src}]: {len(samples)} 样本")

    # 构建模型
    model = MobileNetV3SmallCTC(
        num_chars=len(charset.chars),
        pretrained=cfg["pretrained_backbone"],
        img_h=cfg["img_h"],
        img_w=cfg["img_w"],
    ).to(device)

    # 加载 checkpoint
    if cfg["init_ckpt"]:
        load_checkpoint_strict(model, cfg["init_ckpt"], device)

    # 验证 CTC 时间步
    with torch.no_grad():
        dummy = torch.zeros(1, 3, cfg["img_h"], cfg["img_w"]).to(device)
        T = model(dummy).shape[0]
    print(f"\nCTC 时间步 T = {T}")

    # 冻结 backbone
    if cfg["freeze_backbone_epochs"] > 0:
        model.set_backbone_trainable(False)
        print(f"冻结 backbone 前 {cfg['freeze_backbone_epochs']} 个 epoch")

    # 重点修复:
    # optimizer 从一开始就绑定全部参数；冻结参数不会产生梯度，也不会更新
    # 解冻时只改 requires_grad，不重建 optimizer/scheduler
    optimizer = torch.optim.AdamW(
        model.parameters(),
        lr=cfg["lr"],
        weight_decay=cfg["weight_decay"]
    )
    scheduler = get_lr_scheduler(optimizer, cfg)
    ctc_loss = nn.CTCLoss(blank=0, zero_infinity=True)
    autocast_ctx, scaler, amp_enabled = get_amp_context_and_scaler(device, cfg["use_amp"])
    stopper = EarlyStopper(cfg["early_stop_patience"], cfg["min_delta"])

    history = {
        "train_loss": [],
        "val_loss": [],
        "overall_acc": [],
        "char_acc": [],
        "src_train_acc": [],
        "src_val_acc": [],
        "lr": [],
        "composite": [],
        "monitor_metric": [],
    }

    best_metric = -1.0
    best_epoch = -1
    best_monitor_name = cfg["save_best_by"]

    for epoch in range(1, cfg["epochs"] + 1):
        print(f"\n{'=' * 60}")
        print(f"  Epoch {epoch}/{cfg['epochs']}")
        print(f"{'=' * 60}")

        # 解冻 backbone
        if epoch == cfg["freeze_backbone_epochs"] + 1 and cfg["freeze_backbone_epochs"] > 0:
            model.set_backbone_trainable(True)
            print("★ Backbone 解冻！")

        # 记录本 epoch 实际使用的 lr
        lr_now = optimizer.param_groups[0]["lr"]

        # 构建 epoch 数据
        _, train_loader, train_counts = build_epoch_data(
            train_sources,
            cfg["train_total_samples_per_epoch"],
            cfg["train_source_ratio"],
            charset,
            cfg,
            seed=cfg["seed"] + epoch * 997,
            augment=True,
            shuffle=True,
        )
        _, val_loader, val_counts = build_epoch_data(
            val_sources,
            cfg["val_total_samples"],
            cfg["val_source_ratio"],
            charset,
            cfg,
            seed=cfg["seed"] + 77777,
            augment=False,
            shuffle=False,
        )
        print(f"  Train: {train_counts}")
        print(f"  Val:   {val_counts}")

        # 训练
        train_loss = train_one_epoch(
            model, train_loader, optimizer, scaler, autocast_ctx,
            ctc_loss, device, cfg, amp_enabled
        )

        # 验证
        metrics = evaluate(model, val_loader, ctc_loss, charset, device, amp_enabled)

        # 统计监控指标
        composite = compute_composite_metric(metrics, cfg)
        monitor_metric, monitor_name = get_monitor_metric(metrics, cfg)

        history["train_loss"].append(train_loss)
        history["val_loss"].append(metrics["val_loss"])
        history["overall_acc"].append(metrics["acc"])
        history["char_acc"].append(metrics["char_acc"])
        history["src_train_acc"].append(metrics["src_acc"].get("train", 0.0))
        history["src_val_acc"].append(metrics["src_acc"].get("val", 0.0))
        history["lr"].append(lr_now)
        history["composite"].append(composite)
        history["monitor_metric"].append(monitor_metric)

        print(
            f"  train_loss={train_loss:.4f} val_loss={metrics['val_loss']:.4f}\n"
            f"  overall_acc={metrics['acc']:.4f} char_acc={metrics['char_acc']:.4f}\n"
            f"  train_acc={metrics['src_acc'].get('train', 0.0):.4f} "
            f"val_acc={metrics['src_acc'].get('val', 0.0):.4f}\n"
            f"  composite={composite:.4f} {monitor_name}={monitor_metric:.4f} lr={lr_now:.2e}"
        )

        ckpt = {
            "epoch": epoch,
            "model": model.state_dict(),
            "cfg": cfg,
            "charset": charset.chars,
            "history": history,
            "metrics": {
                "overall_acc": metrics["acc"],
                "char_acc": metrics["char_acc"],
                "src_acc": metrics["src_acc"],
                "src_char_acc": metrics["src_char_acc"],
                "composite": composite,
                "monitor_metric": monitor_metric,
                "monitor_name": monitor_name,
            },
        }

        save_dir = Path(cfg["save_dir"])
        torch.save(ckpt, save_dir / "last.pt")

        stop, improved = stopper.step(monitor_metric)
        if improved:
            best_metric = monitor_metric
            best_epoch = epoch
            best_monitor_name = monitor_name
            torch.save(ckpt, save_dir / "best.pt")
            print(f"  ★ 新最佳! {monitor_name}={monitor_metric:.4f}")

        draw_curves(history, save_dir / "curves.png")
        save_history_csv(history, save_dir / "history.csv")

        if stop:
            print(f"\n[Early Stop] 连续 {cfg['early_stop_patience']} 轮无提升")
            break

        # 在 epoch 末尾再 step，一次 epoch 对应一次 lr 更新
        scheduler.step()

    summary = {
        "save_dir": cfg["save_dir"],
        "init_ckpt": cfg["init_ckpt"],
        "img_h": cfg["img_h"],
        "img_w": cfg["img_w"],
        "best_epoch": best_epoch,
        "best_monitor_name": best_monitor_name,
        "best_metric": best_metric,
        "final_epoch": len(history["train_loss"]),
        "final_metrics": {
            "train_loss": history["train_loss"][-1] if history["train_loss"] else None,
            "val_loss": history["val_loss"][-1] if history["val_loss"] else None,
            "overall_acc": history["overall_acc"][-1] if history["overall_acc"] else None,
            "char_acc": history["char_acc"][-1] if history["char_acc"] else None,
            "train_acc": history["src_train_acc"][-1] if history["src_train_acc"] else None,
            "val_acc": history["src_val_acc"][-1] if history["src_val_acc"] else None,
            "composite": history["composite"][-1] if history["composite"] else None,
            "monitor_metric": history["monitor_metric"][-1] if history["monitor_metric"] else None,
        },
        "train_source_ratio": cfg["train_source_ratio"],
        "val_source_ratio": cfg["val_source_ratio"],
        "train_total_per_epoch": cfg["train_total_samples_per_epoch"],
        "val_total_samples": cfg["val_total_samples"],
    }

    with open(save_dir / "run_summary.json", "w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)

    print("\n训练完成！")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
