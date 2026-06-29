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
import matplotlib.pyplot as plt
from tqdm import tqdm


CONFIG = {
    "stage_name": "round2_corrected_6to4",

    # CCPD OCR manifest（你现有 prepare_ccpd_datasets.py / prepare_ccpd_datasets_v2.py 产物）
    "ccpd_train_txt": r"./data/path_placeholder",
    "ccpd_val_txt": r"./data/path_placeholder",

    # 真实 OCR manifest（由 prepare_real_ocr_dataset_v3.py 生成）
    "real_train_txt": r"./data/path_placeholder",
    "real_val_txt": r"./data/path_placeholder",

    # 必须与旧 best.pt 的字符表顺序一致
    "charset_txt": r"./data/path_placeholder",

    # 这里填“第一轮 8:2 混合训练”的 best.pt 或 best.pth
    "init_ckpt": r"./data/path_placeholder",

    "save_dir": r"runs/ocr_round2_corrected_6to4",

    "img_h": 48,
    "img_w": 352,
    "batch_size": 64,
    "epochs": 20,
    "lr": 3e-4,
    "weight_decay": 1e-4,
    "num_workers": 4,
    "device": "cuda" if torch.cuda.is_available() else "cpu",
    "pretrained_backbone": False,   # 继续训练时不用再单独加载 imagenet 预训练
    "freeze_backbone_epochs": 1,    # 第二轮先冻 1 个 epoch，再全部解冻
    "early_stop_patience": 6,
    "min_delta": 1e-4,
    "use_amp": True,
    "augment": True,
    "seed": 42,

    # 关键：第二轮纠正后的 6:4
    "train_total_samples_per_epoch": 12000,
    "val_total_samples": 2400,
    "train_source_ratio": {"ccpd": 0.6, "real": 0.4},

    # 为了后续比较可比，验证统一固定成 5:5
    "val_source_ratio": {"ccpd": 0.5, "real": 0.5},
}


def seed_everything(seed: int = 42):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)


def ensure_dir(path):
    Path(path).mkdir(parents=True, exist_ok=True)


def draw_curves(history, save_path):
    e = list(range(1, len(history["train_loss"]) + 1))
    plt.figure(figsize=(14, 4))

    plt.subplot(1, 4, 1)
    plt.plot(e, history["train_loss"], label="train")
    plt.plot(e, history["val_loss"], label="val")
    plt.legend()
    plt.title("Loss")

    plt.subplot(1, 4, 2)
    plt.plot(e, history["val_acc"], label="overall")
    plt.legend()
    plt.title("Overall Acc")

    plt.subplot(1, 4, 3)
    plt.plot(e, history["val_ccpd_acc"], label="ccpd")
    plt.plot(e, history["val_real_acc"], label="real")
    plt.legend()
    plt.title("By Source")

    plt.subplot(1, 4, 4)
    plt.plot(e, history["lr"], label="lr")
    plt.legend()
    plt.title("LR")

    plt.tight_layout()
    plt.savefig(save_path, dpi=150)
    plt.close()


def save_history_csv(history, save_path):
    keys = list(history.keys())
    with open(save_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(keys)
        writer.writerows(zip(*(history[k] for k in keys)))


class Charset:
    def __init__(self, charset_txt):
        with open(charset_txt, "r", encoding="utf-8") as f:
            chars = [x.strip() for x in f.readlines() if x.strip()]
        self.blank = "<blank>"
        self.base_chars = chars
        self.chars = [self.blank] + chars
        self.char2id = {c: i for i, c in enumerate(self.chars)}
        self.id2char = {i: c for i, c in enumerate(self.chars)}

    def encode_strict(self, text: str, sample_path: str = ""):
        ids = []
        for ch in text:
            if ch not in self.char2id:
                raise ValueError(f"OOV char '{ch}' in label '{text}' at sample: {sample_path}")
            ids.append(self.char2id[ch])
        if len(ids) == 0:
            raise ValueError(f"Empty encoded label at sample: {sample_path}")
        return ids

    def decode_ctc(self, ids):
        prev = None
        out = []
        for i in ids:
            if i != 0 and i != prev:
                out.append(self.id2char[i])
            prev = i
        return "".join(out)


def read_manifest(txt_file: str, charset: Charset, source_name: str) -> List[Tuple[Path, str, str]]:
    txt_path = Path(txt_file)
    if not txt_path.exists():
        raise FileNotFoundError(f"Manifest not found: {txt_path}")
    root = txt_path.parent
    lines = [x.strip() for x in txt_path.read_text(encoding="utf-8").splitlines() if x.strip()]
    samples = []
    bad_format = 0
    for line in lines:
        if "\t" not in line:
            bad_format += 1
            continue
        path_str, text = line.split("\t", 1)
        p = Path(path_str)
        if not p.is_absolute():
            p = (root / path_str).resolve()
        text = text.strip().upper().replace(" ", "")
        if not p.exists():
            raise FileNotFoundError(f"Image referenced in manifest does not exist: {p}")
        charset.encode_strict(text, str(p))
        samples.append((p, text, source_name))
    if len(samples) == 0:
        raise RuntimeError(f"No valid samples loaded from {txt_file}")
    if bad_format > 0:
        print(f"[WARN] {txt_file}: skipped {bad_format} badly formatted lines (expected path<TAB>label)")
    return samples


def normalize_ratio_dict(ratio_dict: Dict[str, float]) -> Dict[str, float]:
    ratio_dict = {k: float(v) for k, v in ratio_dict.items() if float(v) > 0}
    if not ratio_dict:
        raise ValueError("Empty ratio_dict")
    total = sum(ratio_dict.values())
    if total <= 0:
        raise ValueError("ratio_dict sum must be > 0")
    return {k: v / total for k, v in ratio_dict.items()}


def make_source_counts(total_samples: int, ratio_dict: Dict[str, float]) -> Dict[str, int]:
    ratios = normalize_ratio_dict(ratio_dict)
    keys = list(ratios.keys())
    raw = {k: total_samples * ratios[k] for k in keys}
    counts = {k: int(math.floor(v)) for k, v in raw.items()}
    remain = total_samples - sum(counts.values())
    if remain > 0:
        order = sorted(keys, key=lambda x: raw[x] - counts[x], reverse=True)
        for i in range(remain):
            counts[order[i % len(order)]] += 1
    return counts


def choose_samples(samples: List[Tuple[Path, str, str]], n: int, rng: random.Random):
    if n <= 0:
        return []
    if n <= len(samples):
        idxs = rng.sample(range(len(samples)), n)
        return [samples[i] for i in idxs]
    # 不够时允许有放回采样，避免因真实数据少而报错
    return [samples[rng.randrange(len(samples))] for _ in range(n)]


class OCRMixedDataset(Dataset):
    def __init__(self, samples: List[Tuple[Path, str, str]], charset: Charset, img_h: int, img_w: int, augment: bool):
        self.samples = samples
        self.charset = charset
        self.img_h = img_h
        self.img_w = img_w
        self.augment = augment
        self.to_tensor = transforms.ToTensor()
        self.normalize = transforms.Normalize(mean=[0.5, 0.5, 0.5], std=[0.5, 0.5, 0.5])

    def __len__(self):
        return len(self.samples)

    def max_label_len(self):
        return max(len(t[1]) for t in self.samples) if self.samples else 0

    def _resize_pad(self, im: Image.Image):
        im = im.convert("RGB")
        scale = min(self.img_w / im.width, self.img_h / im.height)
        nw = max(1, int(round(im.width * scale)))
        nh = max(1, int(round(im.height * scale)))
        rs = im.resize((nw, nh), Image.BILINEAR)
        canvas = Image.new("RGB", (self.img_w, self.img_h), (127, 127, 127))
        pad_x = (self.img_w - nw) // 2
        pad_y = (self.img_h - nh) // 2
        canvas.paste(rs, (pad_x, pad_y))
        return canvas

    def _jpeg_degrade(self, im: Image.Image, rng: random.Random):
        quality = rng.randint(45, 90)
        buf = io.BytesIO()
        im.save(buf, format="JPEG", quality=quality)
        buf.seek(0)
        return Image.open(buf).convert("RGB")

    def _down_up(self, im: Image.Image, rng: random.Random):
        w, h = im.size
        scale = rng.uniform(0.55, 0.9)
        nw = max(8, int(round(w * scale)))
        nh = max(8, int(round(h * scale)))
        tmp = im.resize((nw, nh), Image.BILINEAR)
        return tmp.resize((w, h), Image.BILINEAR)

    def _small_affine(self, im: Image.Image, rng: random.Random):
        angle = rng.uniform(-4.0, 4.0)
        shear = rng.uniform(-3.0, 3.0)
        tx = rng.uniform(-0.04, 0.04) * im.width
        ty = rng.uniform(-0.06, 0.06) * im.height
        return transforms.functional.affine(
            im,
            angle=angle,
            translate=(int(round(tx)), int(round(ty))),
            scale=rng.uniform(0.94, 1.04),
            shear=[shear, 0.0],
            interpolation=transforms.InterpolationMode.BILINEAR,
            fill=127,
        )

    def _occlude(self, im: Image.Image, rng: random.Random):
        w, h = im.size
        if w < 20 or h < 10:
            return im
        band_w = max(3, int(w * rng.uniform(0.04, 0.10)))
        x0 = rng.randint(0, max(0, w - band_w))
        overlay = Image.new("RGB", (band_w, h), (rng.randint(80, 160),) * 3)
        im = im.copy()
        im.paste(overlay, (x0, 0))
        return im

    def _augment(self, im: Image.Image, source_name: str, rng: random.Random):
        im = im.convert("RGB")

        if rng.random() < 0.85:
            im = ImageEnhance.Brightness(im).enhance(rng.uniform(0.75, 1.25))
        if rng.random() < 0.85:
            im = ImageEnhance.Contrast(im).enhance(rng.uniform(0.75, 1.25))
        if rng.random() < 0.35:
            im = ImageEnhance.Color(im).enhance(rng.uniform(0.80, 1.15))

        if rng.random() < 0.55:
            im = self._small_affine(im, rng)
        if rng.random() < 0.25:
            im = im.filter(ImageFilter.GaussianBlur(radius=rng.uniform(0.3, 1.0)))
        if rng.random() < 0.30:
            im = self._down_up(im, rng)
        if rng.random() < 0.25:
            im = self._jpeg_degrade(im, rng)
        if rng.random() < 0.18:
            im = self._occlude(im, rng)

        # 真实域在 round3 会占更高比重，这里给真实图再轻微增加裁切扰动
        if source_name == "real" and rng.random() < 0.30:
            w, h = im.size
            dx = int(w * rng.uniform(0.00, 0.05))
            dy = int(h * rng.uniform(0.00, 0.06))
            x1 = min(dx, max(0, w - 2))
            y1 = min(dy, max(0, h - 2))
            x2 = max(x1 + 1, w - rng.randint(0, dx))
            y2 = max(y1 + 1, h - rng.randint(0, dy))
            im = im.crop((x1, y1, x2, y2))
        return im

    def __getitem__(self, idx):
        img_path, text, source_name = self.samples[idx]
        im = Image.open(img_path).convert("RGB")
        if self.augment:
            rng = random.Random((idx + 1) * 1000003 + len(text) * 97)
            im = self._augment(im, source_name, rng)
        im = self._resize_pad(im)
        x = self.normalize(self.to_tensor(im))
        y = torch.tensor(self.charset.encode_strict(text, str(img_path)), dtype=torch.long)
        return x, y, text, source_name


def collate_fn(batch):
    images = [b[0] for b in batch]
    labels = [b[1] for b in batch]
    texts = [b[2] for b in batch]
    sources = [b[3] for b in batch]
    label_lengths = torch.tensor([len(x) for x in labels], dtype=torch.long)
    labels_concat = torch.cat(labels, dim=0) if labels else torch.tensor([], dtype=torch.long)
    return torch.stack(images, dim=0), labels_concat, label_lengths, texts, sources


class OCRBackbone(nn.Module):
    def __init__(self, pretrained=True, out_index=8):
        super().__init__()
        weights = MobileNet_V3_Small_Weights.DEFAULT if pretrained else None
        base = mobilenet_v3_small(weights=weights)
        self.features = base.features
        self.out_index = out_index
        self.out_channels = self._infer_out_channels()

    def _infer_out_channels(self):
        with torch.no_grad():
            x = torch.zeros(1, 3, CONFIG["img_h"], CONFIG["img_w"])
            for i, layer in enumerate(self.features):
                x = layer(x)
                if i == self.out_index:
                    return x.shape[1]
        raise RuntimeError("Failed to infer OCR backbone out_channels")

    def forward(self, x):
        for i, layer in enumerate(self.features):
            x = layer(x)
            if i == self.out_index:
                return x
        return x


class MobileNetV3SmallCTC(nn.Module):
    def __init__(self, num_chars, pretrained=True):
        super().__init__()
        self.backbone = OCRBackbone(pretrained=pretrained, out_index=8)
        self.reduce = nn.Sequential(
            nn.Conv2d(self.backbone.out_channels, 256, 1, 1, 0, bias=False),
            nn.BatchNorm2d(256),
            nn.Hardswish(inplace=True),
            nn.Dropout2d(0.05),
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
        return logits.permute(2, 0, 1)


@torch.no_grad()
def greedy_decode(logits, charset: Charset):
    pred = logits.argmax(dim=-1).permute(1, 0)
    texts = []
    for seq in pred:
        texts.append(charset.decode_ctc(seq.tolist()))
    return texts


class EarlyStopper:
    def __init__(self, patience=8, min_delta=1e-4):
        self.patience = patience
        self.min_delta = min_delta
        self.best = -float("inf")
        self.bad_epochs = 0

    def step(self, metric):
        if metric > self.best + self.min_delta:
            self.best = metric
            self.bad_epochs = 0
            return False, True
        self.bad_epochs += 1
        return self.bad_epochs >= self.patience, False


def get_amp_context_and_scaler(device, use_amp=True):
    enabled = (device.startswith("cuda") and use_amp)

    @contextlib.contextmanager
    def autocast_ctx():
        if enabled:
            with torch.amp.autocast("cuda", enabled=True):
                yield
        else:
            yield

    try:
        scaler = torch.amp.GradScaler("cuda", enabled=enabled)
    except Exception:
        scaler = torch.cuda.amp.GradScaler(enabled=enabled)
    return autocast_ctx, scaler


def train_one_epoch(model, loader, optimizer, scaler, autocast_ctx, ctc_loss, device):
    model.train()
    total_loss = 0.0
    n = 0

    pbar = tqdm(loader, desc="Train", leave=False)
    for images, labels_concat, label_lengths, _, _ in pbar:
        images = images.to(device, non_blocking=True)
        labels_concat = labels_concat.to(device)
        label_lengths = label_lengths.to(device)

        optimizer.zero_grad(set_to_none=True)

        with autocast_ctx():
            logits = model(images)
            log_probs = F.log_softmax(logits, dim=-1)
            input_lengths = torch.full((images.shape[0],), logits.shape[0], dtype=torch.long, device=device)
            loss = ctc_loss(log_probs, labels_concat, input_lengths, label_lengths)

        scaler.scale(loss).backward()
        scaler.step(optimizer)
        scaler.update()

        total_loss += loss.item()
        n += 1
        pbar.set_postfix({"loss": f"{loss.item():.4f}"})

    return total_loss / max(n, 1)


@torch.no_grad()
def evaluate(model, loader, ctc_loss, charset: Charset, device):
    model.eval()
    total_loss = 0.0
    n = 0
    correct = 0
    total = 0
    src_total = {"ccpd": 0, "real": 0}
    src_correct = {"ccpd": 0, "real": 0}

    pbar = tqdm(loader, desc="Val", leave=False)
    for images, labels_concat, label_lengths, texts, sources in pbar:
        images = images.to(device, non_blocking=True)
        labels_concat = labels_concat.to(device)
        label_lengths = label_lengths.to(device)

        logits = model(images)
        log_probs = F.log_softmax(logits, dim=-1)
        input_lengths = torch.full((images.shape[0],), logits.shape[0], dtype=torch.long, device=device)
        loss = ctc_loss(log_probs, labels_concat, input_lengths, label_lengths)

        preds = greedy_decode(logits, charset)
        for pred_text, gt_text, src in zip(preds, texts, sources):
            total += 1
            src_total[src] = src_total.get(src, 0) + 1
            if pred_text == gt_text:
                correct += 1
                src_correct[src] = src_correct.get(src, 0) + 1

        total_loss += loss.item()
        n += 1

    overall_acc = correct / max(total, 1)
    src_acc = {k: (src_correct.get(k, 0) / max(src_total.get(k, 0), 1)) for k in src_total.keys()}
    return total_loss / max(n, 1), overall_acc, src_acc, src_total


def load_checkpoint(model, ckpt_path: str, charset: Charset, device: str):
    path = Path(ckpt_path)
    if not path.exists():
        raise FileNotFoundError(f"Checkpoint not found: {path}")

    ckpt = torch.load(path, map_location=device)
    state = None

    if isinstance(ckpt, dict) and "model" in ckpt:
        state = ckpt["model"]
        if "charset" in ckpt:
            old_charset = ckpt["charset"]
            if old_charset != charset.chars:
                raise ValueError(
                    "Checkpoint charset does not match current charset.txt.\n"
                    "Please keep charset order exactly the same when continuing training."
                )
    elif isinstance(ckpt, dict):
        # 兼容直接保存 state_dict 的情况
        state = ckpt
    else:
        raise TypeError(f"Unsupported checkpoint format: {type(ckpt)}")

    missing, unexpected = model.load_state_dict(state, strict=False)
    if missing or unexpected:
        print("[WARN] load_state_dict strict=False")
        print("[WARN] missing keys:", missing)
        print("[WARN] unexpected keys:", unexpected)
    return ckpt


def build_epoch_loader(source_samples: Dict[str, List[Tuple[Path, str, str]]],
                       total_samples: int,
                       ratio_dict: Dict[str, float],
                       charset: Charset,
                       img_h: int,
                       img_w: int,
                       batch_size: int,
                       num_workers: int,
                       augment: bool,
                       seed: int,
                       shuffle: bool):
    counts = make_source_counts(total_samples, ratio_dict)
    rng = random.Random(seed)
    epoch_samples = []
    actual_counts = {}
    for src_name, count in counts.items():
        if src_name not in source_samples:
            raise KeyError(f"Source '{src_name}' not found in source_samples")
        chosen = choose_samples(source_samples[src_name], count, rng)
        epoch_samples.extend(chosen)
        actual_counts[src_name] = len(chosen)
    rng.shuffle(epoch_samples)

    ds = OCRMixedDataset(epoch_samples, charset, img_h=img_h, img_w=img_w, augment=augment)
    loader = DataLoader(
        ds,
        batch_size=batch_size,
        shuffle=shuffle,
        num_workers=num_workers,
        pin_memory=True,
        collate_fn=collate_fn,
        drop_last=False,
    )
    return ds, loader, actual_counts


def main():
    cfg = CONFIG
    seed_everything(cfg["seed"])
    ensure_dir(cfg["save_dir"])

    device = cfg["device"]
    charset = Charset(cfg["charset_txt"])

    ccpd_train = read_manifest(cfg["ccpd_train_txt"], charset, "ccpd")
    ccpd_val = read_manifest(cfg["ccpd_val_txt"], charset, "ccpd")
    real_train = read_manifest(cfg["real_train_txt"], charset, "real")
    real_val = read_manifest(cfg["real_val_txt"], charset, "real")

    print(f"Loaded train samples: ccpd={len(ccpd_train)}, real={len(real_train)}")
    print(f"Loaded val samples  : ccpd={len(ccpd_val)}, real={len(real_val)}")

    model = MobileNetV3SmallCTC(
        num_chars=len(charset.chars),
        pretrained=cfg["pretrained_backbone"],
    ).to(device)

    if cfg["init_ckpt"]:
        print(f"Loading init_ckpt: {cfg['init_ckpt']}")
        load_checkpoint(model, cfg["init_ckpt"], charset, device)

    with torch.no_grad():
        dummy = torch.zeros(1, 3, cfg["img_h"], cfg["img_w"]).to(device)
        T = model(dummy).shape[0]
    print(f"CTC time steps T = {T}")

    dry_train_ds = OCRMixedDataset(ccpd_train + real_train, charset, cfg["img_h"], cfg["img_w"], augment=False)
    max_label_len = dry_train_ds.max_label_len()
    print(f"Max label length in train set = {max_label_len}")
    if T < max_label_len:
        raise RuntimeError(
            f"CTC time steps T={T} is smaller than max label length={max_label_len}. "
            f"Please increase img_w."
        )

    # 真实域收尾阶段建议直接全量解冻；第二轮可先冻 1~2 个 epoch
    if cfg["freeze_backbone_epochs"] > 0:
        model.set_backbone_trainable(False)
        print(f"Freeze backbone for first {cfg['freeze_backbone_epochs']} epoch(s)")
    else:
        model.set_backbone_trainable(True)

    optimizer = torch.optim.AdamW(
        [p for p in model.parameters() if p.requires_grad],
        lr=cfg["lr"],
        weight_decay=cfg["weight_decay"],
    )

    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(
        optimizer,
        T_max=max(cfg["epochs"], 1),
        eta_min=cfg["lr"] * 0.1,
    )

    ctc_loss = nn.CTCLoss(blank=0, zero_infinity=True)
    autocast_ctx, scaler = get_amp_context_and_scaler(device, use_amp=cfg["use_amp"])
    early_stopper = EarlyStopper(patience=cfg["early_stop_patience"], min_delta=cfg["min_delta"])

    history = {
        "epoch": [],
        "train_loss": [],
        "val_loss": [],
        "val_acc": [],
        "val_ccpd_acc": [],
        "val_real_acc": [],
        "lr": [],
    }

    best_acc = -1.0
    best_epoch = -1
    best_src_acc = {}
    best_val_src_total = {}

    for epoch in range(1, cfg["epochs"] + 1):
        print(f"\n===== Epoch {epoch}/{cfg['epochs']} =====")

        if epoch == cfg["freeze_backbone_epochs"] + 1 and cfg["freeze_backbone_epochs"] > 0:
            model.set_backbone_trainable(True)
            optimizer = torch.optim.AdamW(model.parameters(), lr=cfg["lr"], weight_decay=cfg["weight_decay"])
            scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(
                optimizer,
                T_max=max(cfg["epochs"] - epoch + 1, 1),
                eta_min=cfg["lr"] * 0.1,
            )
            print("Backbone unfrozen.")

        train_ds, train_loader, train_counts = build_epoch_loader(
            source_samples={"ccpd": ccpd_train, "real": real_train},
            total_samples=cfg["train_total_samples_per_epoch"],
            ratio_dict=cfg["train_source_ratio"],
            charset=charset,
            img_h=cfg["img_h"],
            img_w=cfg["img_w"],
            batch_size=cfg["batch_size"],
            num_workers=cfg["num_workers"],
            augment=cfg["augment"],
            seed=cfg["seed"] + epoch * 1009,
            shuffle=True,
        )
        val_ds, val_loader, val_counts = build_epoch_loader(
            source_samples={"ccpd": ccpd_val, "real": real_val},
            total_samples=cfg["val_total_samples"],
            ratio_dict=cfg["val_source_ratio"],
            charset=charset,
            img_h=cfg["img_h"],
            img_w=cfg["img_w"],
            batch_size=cfg["batch_size"],
            num_workers=cfg["num_workers"],
            augment=False,
            seed=cfg["seed"] + 99999 + epoch,
            shuffle=False,
        )

        print(f"Train sampled counts: {train_counts}")
        print(f"Val sampled counts  : {val_counts}")

        train_loss = train_one_epoch(model, train_loader, optimizer, scaler, autocast_ctx, ctc_loss, device)
        val_loss, val_acc, val_src_acc, val_src_total = evaluate(model, val_loader, ctc_loss, charset, device)
        scheduler.step()

        lr_now = optimizer.param_groups[0]["lr"]
        history["epoch"].append(epoch)
        history["train_loss"].append(train_loss)
        history["val_loss"].append(val_loss)
        history["val_acc"].append(val_acc)
        history["val_ccpd_acc"].append(val_src_acc.get("ccpd", 0.0))
        history["val_real_acc"].append(val_src_acc.get("real", 0.0))
        history["lr"].append(lr_now)

        print(
            f"epoch={epoch} train_loss={train_loss:.4f} "
            f"val_loss={val_loss:.4f} val_acc={val_acc:.4f} "
            f"ccpd_acc={val_src_acc.get('ccpd', 0.0):.4f} "
            f"real_acc={val_src_acc.get('real', 0.0):.4f} lr={lr_now:.6g}"
        )

        stop, improved = early_stopper.step(val_acc)
        ckpt = {
            "epoch": epoch,
            "model": model.state_dict(),
            "cfg": cfg,
            "charset": charset.chars,
            "history": history,
            "val_acc": val_acc,
            "val_src_acc": val_src_acc,
            "train_counts": train_counts,
            "val_counts": val_counts,
        }
        torch.save(ckpt, Path(cfg["save_dir"]) / "last.pt")
        torch.save(ckpt, Path(cfg["save_dir"]) / "last.pth")

        if improved:
            best_acc = val_acc
            best_epoch = epoch
            best_src_acc = dict(val_src_acc)
            best_val_src_total = dict(val_src_total)
            torch.save(ckpt, Path(cfg["save_dir"]) / "best.pt")
            torch.save(ckpt, Path(cfg["save_dir"]) / "best.pth")
            print("Saved new best checkpoint.")

        draw_curves(history, Path(cfg["save_dir"]) / "curves.png")
        save_history_csv(history, Path(cfg["save_dir"]) / "history.csv")

        if stop:
            print("Early stopping triggered.")
            break

    run_summary = {
        "save_dir": cfg["save_dir"],
        "init_ckpt": cfg["init_ckpt"],
        "best_epoch": best_epoch,
        "best_acc": best_acc,
        "best_src_acc": best_src_acc,
        "best_val_src_total": best_val_src_total,
        "last_epoch": history["epoch"][-1] if history["epoch"] else 0,
        "train_source_ratio": cfg["train_source_ratio"],
        "val_source_ratio": cfg["val_source_ratio"],
        "train_total_samples_per_epoch": cfg["train_total_samples_per_epoch"],
        "val_total_samples": cfg["val_total_samples"],
        "img_h": cfg["img_h"],
        "img_w": cfg["img_w"],
    }
    with open(Path(cfg["save_dir"]) / "run_summary.json", "w", encoding="utf-8") as f:
        json.dump(run_summary, f, ensure_ascii=False, indent=2)

    print("\nTraining finished.")
    print(json.dumps(run_summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()