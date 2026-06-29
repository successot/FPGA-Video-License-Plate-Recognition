
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
os.environ["OMP_NUM_THREADS"] = "4"
os.environ["MKL_NUM_THREADS"] = "4"

import io
import csv
import json
import math
import random
import contextlib
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

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


CONFIG = {
    "stage_name": "ocr_round6_3a_tiny_province_repair",

    # clean pools
    "train_manifests": {
        "train": r"./data/path_placeholder",
        "val": r"./data/path_placeholder",
    },
    "val_manifests": {
        "train": r"./data/path_placeholder",
        "val": r"./data/path_placeholder",
    },

    # reuse round6.2 mined candidates, but keep only tiny province repair buckets
    "hard_train_manifest": r"./data/path_placeholder",
    "hard_val_manifest": r"./data/path_placeholder",
    "hard_analysis_csv": r"./data/path_placeholder",

    "charset_txt": r"./data/path_placeholder",

    # continue from round6.3 best, not from C
    "init_ckpt": r"./data/path_placeholder",
    "save_dir": r"./data/path_placeholder",

    "img_h": 48,
    "img_w": 320,
    "batch_size": 128,
    "epochs": 2,
    "num_workers": 4,
    "device": "cuda" if torch.cuda.is_available() else "cpu",
    "seed": 42,
    "use_amp": True,

    # ultra-light polish
    "lr": 2.5e-6,
    "min_lr": 5.0e-7,
    "warmup_epochs": 1,
    "weight_decay": 5e-5,
    "grad_clip_norm": 5.0,
    "early_stop_patience": 1,
    "min_delta": 2e-5,

    # almost all clean, tiny hard
    "clean_train_total_per_epoch": 119000,
    "hard_train_total_per_epoch": 600,
    "clean_val_total": 12000,
    "hard_val_total": 240,

    "clean_train_ratio": {"train": 0.7, "val": 0.3},
    "clean_val_ratio": {"train": 0.7, "val": 0.3},
    "hard_train_ratio": {"train": 0.7, "val": 0.3},
    "hard_val_ratio": {"train": 0.7, "val": 0.3},

    "clean_max_wan_ratio": 0.56,
    "hard_max_wan_ratio": 0.48,

    # only two categories
    "hard_category_ratio": {
        "province_to_wan_targeted": 0.84,
        "wan_stabilizer": 0.16,
    },

    # very mild weights
    "hard_sample_weight": 1.02,
    "non_wan_weight": 1.03,
    "wan_weight": 0.995,
    "province_to_wan_weight": 1.12,
    "wan_stabilizer_weight": 1.01,
    "max_sample_weight": 1.35,

    # very mild aug
    "augment": True,
    "aug_brightness": (0.78, 1.22),
    "aug_contrast": (0.78, 1.22),
    "aug_color": (0.88, 1.06),
    "aug_affine_prob": 0.14,
    "aug_blur_prob": 0.10,
    "aug_downup_prob": 0.10,
    "aug_jpeg_prob": 0.10,
    "aug_occlude_prob": 0.06,
    "aug_noise_prob": 0.08,
    "aug_perspective_prob": 0.04,
}


@dataclass
class SampleItem:
    img_path: str
    label: str
    source: str
    split_name: str
    category: Optional[str] = None
    pos: Optional[int] = None
    gt_first: Optional[str] = None
    pred: Optional[str] = None
    confidence: Optional[float] = None


def seed_everything(seed: int = 42) -> None:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)


def ensure_dir(path: str) -> None:
    Path(path).mkdir(parents=True, exist_ok=True)


def normalize_ratio(ratio: Dict[str, float]) -> Dict[str, float]:
    s = float(sum(ratio.values()))
    if s <= 0:
        raise ValueError(f"ratio sum <= 0: {ratio}")
    return {k: v / s for k, v in ratio.items()}


def make_counts(total: int, ratio: Dict[str, float]) -> Dict[str, int]:
    ratio = normalize_ratio(ratio)
    counts = {k: int(total * v) for k, v in ratio.items()}
    remain = total - sum(counts.values())
    order = sorted(ratio.keys(), key=lambda x: total * ratio[x] - counts[x], reverse=True)
    for i in range(remain):
        counts[order[i % len(order)]] += 1
    return counts


class Charset:
    def __init__(self, charset_txt: str):
        with open(charset_txt, "r", encoding="utf-8") as f:
            chars = [x.strip() for x in f.readlines() if x.strip()]
        self.blank = "<blank>"
        self.chars = [self.blank] + chars
        self.char2id = {c: i for i, c in enumerate(self.chars)}
        self.id2char = {i: c for i, c in enumerate(self.chars)}

    def encode(self, text: str) -> List[int]:
        return [self.char2id[c] for c in text]

    def decode_ctc(self, ids: List[int]) -> str:
        prev = None
        out = []
        for i in ids:
            if i != 0 and i != prev:
                out.append(self.id2char.get(i, "?"))
            prev = i
        return "".join(out)


def validate_config(cfg: Dict) -> None:
    for key in ["train_manifests", "val_manifests"]:
        if set(cfg[key].keys()) != {"train", "val"}:
            raise ValueError(f"{key} must have keys train/val")
    for p in [
        cfg["hard_train_manifest"],
        cfg["hard_val_manifest"],
        cfg["hard_analysis_csv"],
        cfg["init_ckpt"],
        cfg["charset_txt"],
    ]:
        if not os.path.exists(p):
            raise FileNotFoundError(p)


def resolve_maybe_relative(manifest_path: str, path_str: str) -> str:
    p = Path(path_str)
    if not p.is_absolute():
        p = (Path(manifest_path).parent / p).resolve()
    return str(p)


def keep_round6_3a_row(row: Dict) -> bool:
    cat = row.get("category") or ""
    if cat == "province_to_wan_targeted":
        return True
    if cat == "wan_stabilizer":
        # keep only modest-confidence stabilizers, avoid over-correcting
        try:
            conf = float(row.get("confidence", 0.0) or 0.0)
        except Exception:
            conf = 0.0
        return conf <= 0.72
    return False


def load_hard_meta(csv_path: str) -> Dict[str, Dict]:
    meta = {}
    with open(csv_path, "r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if not keep_round6_3a_row(row):
                continue
            key = str(Path(row["img_path"]).resolve())
            pos = None
            if row.get("pos") not in (None, "", "nan"):
                try:
                    pos = int(float(row["pos"]))
                except Exception:
                    pos = None
            meta[key] = {
                "category": row.get("category") or None,
                "pos": pos,
                "gt": row.get("gt") or None,
                "pred": row.get("pred") or None,
                "split": row.get("split") or None,
                "confidence": float(row.get("confidence", 0.0) or 0.0),
            }
    return meta


def read_manifest(
    manifest_path: str,
    charset: Charset,
    source: str,
    split_name: str,
    hard_meta: Optional[Dict[str, Dict]] = None,
) -> List[SampleItem]:
    items: List[SampleItem] = []
    with open(manifest_path, "r", encoding="utf-8") as f:
        for raw in f:
            raw = raw.strip()
            if not raw or "\t" not in raw:
                continue
            img_path_str, label = raw.split("\t", 1)
            img_path = resolve_maybe_relative(manifest_path, img_path_str)
            label = label.strip().upper().replace(" ", "")
            if not os.path.exists(img_path):
                continue
            if not (7 <= len(label) <= 9):
                continue
            if not all(c in charset.char2id for c in label):
                continue

            if hard_meta is not None:
                m = hard_meta.get(str(Path(img_path).resolve()))
                if m is None:
                    continue
            else:
                m = {}

            items.append(
                SampleItem(
                    img_path=img_path,
                    label=label,
                    source=source,
                    split_name=split_name,
                    category=m.get("category"),
                    pos=m.get("pos"),
                    gt_first=label[0] if label else None,
                    pred=m.get("pred"),
                    confidence=m.get("confidence"),
                )
            )
    return items


def split_by_wan(items: List[SampleItem]) -> Tuple[List[SampleItem], List[SampleItem]]:
    wan, non_wan = [], []
    for x in items:
        if x.label and x.label[0] == "皖":
            wan.append(x)
        else:
            non_wan.append(x)
    return wan, non_wan


def choose_with_replacement(items: List[SampleItem], n: int, rng: random.Random) -> List[SampleItem]:
    if n <= 0 or len(items) == 0:
        return []
    if n <= len(items):
        idx = rng.sample(range(len(items)), n)
        return [items[i] for i in idx]
    return [items[rng.randrange(len(items))] for _ in range(n)]


def choose_bias_controlled(items: List[SampleItem], n: int, rng: random.Random, max_wan_ratio: float) -> List[SampleItem]:
    if n <= 0 or len(items) == 0:
        return []
    wan, non_wan = split_by_wan(items)
    want_wan = int(round(n * max_wan_ratio))
    want_non_wan = n - want_wan
    chosen_non = choose_with_replacement(non_wan, want_non_wan, rng)
    chosen_wan = choose_with_replacement(wan, want_wan, rng)
    chosen = chosen_non + chosen_wan
    if len(chosen) < n:
        fallback = non_wan if len(non_wan) >= len(wan) else wan
        chosen.extend(choose_with_replacement(fallback, n - len(chosen), rng))
    rng.shuffle(chosen)
    return chosen[:n]


def sample_clean_epoch(split_to_items, total, split_ratio, rng, max_wan_ratio):
    counts = make_counts(total, split_ratio)
    out = []
    for split_name, cnt in counts.items():
        out.extend(choose_bias_controlled(split_to_items.get(split_name, []), cnt, rng, max_wan_ratio))
    rng.shuffle(out)
    return out


def sample_hard_epoch(split_to_items, total, split_ratio, category_ratio, rng, max_wan_ratio):
    split_counts = make_counts(total, split_ratio)
    out = []
    for split_name, split_cnt in split_counts.items():
        items = split_to_items.get(split_name, [])
        if not items or split_cnt <= 0:
            continue

        cat_pool = {cat: [] for cat in category_ratio.keys()}
        cat_pool["other"] = []
        for x in items:
            if x.category in cat_pool:
                cat_pool[x.category].append(x)
            else:
                cat_pool["other"].append(x)

        cat_counts = make_counts(split_cnt, category_ratio)
        used = 0
        for cat_name, cnt in cat_counts.items():
            out.extend(choose_bias_controlled(cat_pool.get(cat_name, []), cnt, rng, max_wan_ratio))
            used += cnt
        if used < split_cnt:
            out.extend(choose_bias_controlled(items, split_cnt - used, rng, max_wan_ratio))

    rng.shuffle(out)
    return out[:total]


def resize_pad(im: Image.Image, img_h: int, img_w: int) -> Image.Image:
    im = im.convert("RGB")
    scale = min(img_w / im.width, img_h / im.height)
    nw = max(1, int(round(im.width * scale)))
    nh = max(1, int(round(im.height * scale)))
    rs = im.resize((nw, nh), Image.BILINEAR)
    canvas = Image.new("RGB", (img_w, img_h), (127, 127, 127))
    canvas.paste(rs, ((img_w - nw) // 2, (img_h - nh) // 2))
    return canvas


class OCRDataset(Dataset):
    def __init__(self, items: List[SampleItem], charset: Charset, img_h: int, img_w: int, augment: bool, cfg: Dict):
        self.items = items
        self.charset = charset
        self.img_h = img_h
        self.img_w = img_w
        self.augment = augment
        self.cfg = cfg
        self.to_tensor = transforms.ToTensor()
        self.normalize = transforms.Normalize([0.5] * 3, [0.5] * 3)

    def __len__(self):
        return len(self.items)

    def _jpeg_degrade(self, im, rng):
        quality = rng.randint(55, 92)
        buf = io.BytesIO()
        im.save(buf, format="JPEG", quality=quality)
        buf.seek(0)
        return Image.open(buf).convert("RGB")

    def _down_up(self, im, rng):
        w, h = im.size
        scale = rng.uniform(0.65, 0.92)
        nw, nh = max(8, int(w * scale)), max(4, int(h * scale))
        return im.resize((nw, nh), Image.BILINEAR).resize((w, h), Image.BILINEAR)

    def _affine(self, im, rng):
        return transforms.functional.affine(
            im,
            angle=rng.uniform(-2.5, 2.5),
            translate=(int(im.width * rng.uniform(-0.025, 0.025)), int(im.height * rng.uniform(-0.04, 0.04))),
            scale=rng.uniform(0.97, 1.03),
            shear=[rng.uniform(-2.0, 2.0), 0.0],
            interpolation=transforms.InterpolationMode.BILINEAR,
            fill=127,
        )

    def _perspective(self, im, rng):
        w, h = im.size
        mw, mh = int(w * 0.03), int(h * 0.03)
        src = [(0, 0), (w, 0), (w, h), (0, h)]
        dst = [
            (rng.randint(0, mw), rng.randint(0, mh)),
            (w - rng.randint(0, mw), rng.randint(0, mh)),
            (w - rng.randint(0, mw), h - rng.randint(0, mh)),
            (rng.randint(0, mw), h - rng.randint(0, mh)),
        ]
        return transforms.functional.perspective(im, src, dst, interpolation=transforms.InterpolationMode.BILINEAR, fill=127)

    def _occlude(self, im, rng):
        w, h = im.size
        band_w = max(3, int(w * rng.uniform(0.04, 0.08)))
        x0 = rng.randint(0, max(0, w - band_w))
        overlay = Image.new("RGB", (band_w, h), tuple(rng.randint(90, 165) for _ in range(3)))
        im = im.copy()
        im.paste(overlay, (x0, 0))
        return im

    def _add_noise(self, im, rng):
        arr = np.array(im, dtype=np.float32)
        sigma = rng.uniform(2.5, 8.0)
        noise = np.random.normal(0, sigma, arr.shape).astype(np.float32)
        return Image.fromarray(np.clip(arr + noise, 0, 255).astype(np.uint8))

    def _augment(self, im, rng):
        c = self.cfg
        if rng.random() < 0.78:
            im = ImageEnhance.Brightness(im).enhance(rng.uniform(*c["aug_brightness"]))
        if rng.random() < 0.78:
            im = ImageEnhance.Contrast(im).enhance(rng.uniform(*c["aug_contrast"]))
        if rng.random() < 0.15:
            im = ImageEnhance.Color(im).enhance(rng.uniform(*c["aug_color"]))
        if rng.random() < c["aug_affine_prob"]:
            im = self._affine(im, rng)
        if rng.random() < c["aug_perspective_prob"]:
            im = self._perspective(im, rng)
        if rng.random() < c["aug_blur_prob"]:
            im = im.filter(ImageFilter.GaussianBlur(radius=rng.uniform(0.2, 0.7)))
        if rng.random() < c["aug_downup_prob"]:
            im = self._down_up(im, rng)
        if rng.random() < c["aug_jpeg_prob"]:
            im = self._jpeg_degrade(im, rng)
        if rng.random() < c["aug_noise_prob"]:
            im = self._add_noise(im, rng)
        if rng.random() < c["aug_occlude_prob"]:
            im = self._occlude(im, rng)
        return im

    def __getitem__(self, idx: int):
        item = self.items[idx]
        try:
            im = Image.open(item.img_path).convert("RGB")
        except Exception:
            im = Image.new("RGB", (self.img_w, self.img_h), (127, 127, 127))
        if self.augment:
            im = self._augment(im, random.Random())
        im = resize_pad(im, self.img_h, self.img_w)
        x = self.normalize(self.to_tensor(im))
        y = torch.tensor(self.charset.encode(item.label), dtype=torch.long)
        return x, y, item


def collate_fn(batch):
    images, labels, items = [], [], []
    for x, y, item in batch:
        images.append(x)
        labels.append(y)
        items.append(item)
    label_lengths = torch.tensor([len(y) for y in labels], dtype=torch.long)
    labels_cat = torch.cat(labels) if labels else torch.tensor([], dtype=torch.long)
    return torch.stack(images), labels_cat, label_lengths, items


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
        raise RuntimeError("failed to infer output channels")

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

    def forward(self, x):
        feat = self.backbone(x)
        feat = self.reduce(feat)
        feat = feat.mean(dim=2)
        logits = self.classifier(feat)
        return logits.permute(2, 0, 1)


def _amp_autocast():
    if hasattr(torch.amp, "autocast"):
        try:
            return torch.amp.autocast("cuda")
        except TypeError:
            pass
    return torch.cuda.amp.autocast()


def _amp_grad_scaler(enabled: bool):
    if hasattr(torch.amp, "GradScaler"):
        try:
            return torch.amp.GradScaler("cuda", enabled=enabled)
        except TypeError:
            pass
    return torch.cuda.amp.GradScaler(enabled=enabled)


def get_amp_context_and_scaler(device: str, use_amp: bool):
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


def load_checkpoint_strict(model: nn.Module, ckpt_path: str, device: str):
    ckpt = torch.load(ckpt_path, map_location=device)
    state = ckpt.get("model", ckpt) if isinstance(ckpt, dict) else ckpt
    model_state = model.state_dict()
    loaded, skipped = 0, 0
    for k, v in state.items():
        if k in model_state and model_state[k].shape == v.shape:
            model_state[k] = v
            loaded += 1
        else:
            skipped += 1
    model.load_state_dict(model_state, strict=False)
    print(f"[Checkpoint] loaded={loaded}, skipped={skipped}, from={ckpt_path}")


def get_scheduler(optimizer, cfg):
    warmup = cfg["warmup_epochs"]
    total = cfg["epochs"]
    min_lr = cfg["min_lr"]
    base_lr = cfg["lr"]

    def lr_lambda(epoch_idx):
        if epoch_idx < warmup:
            return float(epoch_idx + 1) / max(warmup, 1)
        progress = (epoch_idx - warmup) / max(total - warmup, 1)
        cosine = 0.5 * (1.0 + math.cos(math.pi * progress))
        return max(min_lr / base_lr, cosine)

    return torch.optim.lr_scheduler.LambdaLR(optimizer, lr_lambda)


@torch.no_grad()
def greedy_decode(logits: torch.Tensor, charset: Charset):
    pred = logits.argmax(dim=-1).permute(1, 0)
    return [charset.decode_ctc(seq.tolist()) for seq in pred]


def build_sample_weights(items: List[SampleItem], cfg: Dict) -> torch.Tensor:
    weights = []
    for x in items:
        w = 1.0
        if x.source.startswith("hard"):
            w *= cfg["hard_sample_weight"]
        if x.label and x.label[0] != "皖":
            w *= cfg["non_wan_weight"]
        else:
            w *= cfg["wan_weight"]

        if x.category == "province_to_wan_targeted":
            w *= cfg["province_to_wan_weight"]
        elif x.category == "wan_stabilizer":
            w *= cfg["wan_stabilizer_weight"]

        weights.append(min(float(w), float(cfg["max_sample_weight"])))
    return torch.tensor(weights, dtype=torch.float32)


def train_one_epoch(model, loader, optimizer, scaler, autocast_ctx, ctc_loss_per_sample, device, cfg, amp_enabled):
    model.train()
    total_loss = 0.0
    n_batches = 0
    for images, labels_cat, label_lengths, items in tqdm(loader, desc="Train", leave=False):
        images = images.to(device, non_blocking=True)
        labels_cat = labels_cat.to(device)
        label_lengths = label_lengths.to(device)
        batch_weights = build_sample_weights(items, cfg).to(device)
        optimizer.zero_grad(set_to_none=True)

        with autocast_ctx():
            logits = model(images)
            log_probs = F.log_softmax(logits, dim=-1)
            input_lengths = torch.full((images.shape[0],), logits.shape[0], dtype=torch.long, device=device)
            loss_vec = ctc_loss_per_sample(log_probs, labels_cat, input_lengths, label_lengths)
            loss = (loss_vec * batch_weights).sum() / batch_weights.sum().clamp_min(1.0)

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

        total_loss += float(loss.item())
        n_batches += 1
    return total_loss / max(n_batches, 1)


@torch.no_grad()
def evaluate(model, loader, ctc_loss_per_sample, charset, device):
    model.eval()
    total_loss = 0.0
    n_batches = 0
    plate_correct = 0
    plate_total = 0
    char_correct = 0
    char_total = 0
    first_char_correct = 0
    pred_wan = 0
    gt_wan = 0
    nonwan_to_wan = 0
    src_stats = {}

    for images, labels_cat, label_lengths, items in tqdm(loader, desc="Val", leave=False):
        images = images.to(device, non_blocking=True)
        labels_cat = labels_cat.to(device)
        label_lengths = label_lengths.to(device)

        logits = model(images)
        log_probs = F.log_softmax(logits.float(), dim=-1)
        input_lengths = torch.full((images.shape[0],), logits.shape[0], dtype=torch.long, device=device)
        loss = ctc_loss_per_sample(log_probs, labels_cat, input_lengths, label_lengths).mean()
        preds = greedy_decode(logits, charset)

        for pred, item in zip(preds, items):
            gt = item.label
            src = item.source
            src_stats.setdefault(src, {"correct":0,"total":0,"pred_wan":0,"gt_wan":0,"nonwan_to_wan":0})
            plate_total += 1
            src_stats[src]["total"] += 1
            exact = int(pred == gt)
            plate_correct += exact
            src_stats[src]["correct"] += exact

            gt0 = gt[0] if gt else ""
            pred0 = pred[0] if pred else ""
            if gt0 == pred0:
                first_char_correct += 1
            if gt0 == "皖":
                gt_wan += 1
                src_stats[src]["gt_wan"] += 1
            if pred0 == "皖":
                pred_wan += 1
                src_stats[src]["pred_wan"] += 1
            if gt0 != "皖" and pred0 == "皖":
                nonwan_to_wan += 1
                src_stats[src]["nonwan_to_wan"] += 1

            min_len = min(len(pred), len(gt))
            for i in range(min_len):
                char_total += 1
                if pred[i] == gt[i]:
                    char_correct += 1
            char_total += abs(len(pred) - len(gt))

        total_loss += float(loss.item())
        n_batches += 1

    acc = plate_correct / max(plate_total, 1)
    char_acc = char_correct / max(char_total, 1)
    first_char_acc = first_char_correct / max(plate_total, 1)
    pred_wan_rate = pred_wan / max(plate_total, 1)
    gt_wan_rate = gt_wan / max(plate_total, 1)
    nonwan_to_wan_rate = nonwan_to_wan / max(plate_total, 1)
    anti_bias_score = max(0.0, 1.0 - nonwan_to_wan_rate)

    selection_metric = (
        0.78 * acc +
        0.08 * char_acc +
        0.10 * first_char_acc +
        0.04 * anti_bias_score
    )

    src_metrics = {}
    for src, s in src_stats.items():
        src_metrics[src] = {
            "acc": s["correct"] / max(s["total"], 1),
            "pred_wan_rate": s["pred_wan"] / max(s["total"], 1),
            "gt_wan_rate": s["gt_wan"] / max(s["total"], 1),
            "nonwan_to_wan_rate": s["nonwan_to_wan"] / max(s["total"], 1),
        }

    return {
        "val_loss": total_loss / max(n_batches, 1),
        "acc": acc,
        "char_acc": char_acc,
        "first_char_acc": first_char_acc,
        "pred_wan_rate": pred_wan_rate,
        "gt_wan_rate": gt_wan_rate,
        "nonwan_to_wan_rate": nonwan_to_wan_rate,
        "selection_metric": selection_metric,
        "src_metrics": src_metrics,
    }


class EarlyStopper:
    def __init__(self, patience, min_delta):
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


def build_loader(items, charset, cfg, augment, shuffle):
    ds = OCRDataset(items, charset, cfg["img_h"], cfg["img_w"], augment, cfg)
    return DataLoader(
        ds,
        batch_size=cfg["batch_size"],
        shuffle=shuffle,
        num_workers=cfg["num_workers"],
        pin_memory=True,
        collate_fn=collate_fn,
        drop_last=False,
    )


def draw_curves(history, save_path):
    epochs = list(range(1, len(history["train_loss"]) + 1))
    fig, axes = plt.subplots(1, 6, figsize=(24, 4))

    axes[0].plot(epochs, history["train_loss"], label="train")
    axes[0].plot(epochs, history["val_loss"], label="val")
    axes[0].legend(); axes[0].set_title("Loss")

    axes[1].plot(epochs, history["val_acc"], label="plate_acc")
    axes[1].plot(epochs, history["first_char_acc"], label="first_char_acc")
    axes[1].legend(); axes[1].set_title("Accuracy")

    axes[2].plot(epochs, history["char_acc"], label="char_acc")
    axes[2].legend(); axes[2].set_title("Char Acc")

    axes[3].plot(epochs, history["gt_wan_rate"], label="gt_wan_rate")
    axes[3].plot(epochs, history["pred_wan_rate"], label="pred_wan_rate")
    axes[3].legend(); axes[3].set_title("Wan Rate")

    axes[4].plot(epochs, history["nonwan_to_wan_rate"], label="nonwan->wan")
    axes[4].legend(); axes[4].set_title("Bias Error")

    axes[5].plot(epochs, history["selection_metric"], label="selection_metric")
    axes[5].plot(epochs, history["lr"], label="lr")
    axes[5].legend(); axes[5].set_title("Selection/LR")

    plt.tight_layout()
    plt.savefig(save_path, dpi=150)
    plt.close()


def save_history_csv(history, save_path):
    keys = list(history.keys())
    max_len = max(len(v) for v in history.values())
    with open(save_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(keys)
        for i in range(max_len):
            writer.writerow([history[k][i] if i < len(history[k]) else "" for k in keys])


def src_summary_str(src_metrics):
    parts = []
    for k in sorted(src_metrics.keys()):
        s = src_metrics[k]
        parts.append(
            f"{k}: acc={s['acc']:.4f}, pred_wan={s['pred_wan_rate']:.4f}, "
            f"gt_wan={s['gt_wan_rate']:.4f}, nonwan_to_wan={s['nonwan_to_wan_rate']:.4f}"
        )
    return "\n  ".join(parts)


def main():
    cfg = CONFIG
    validate_config(cfg)
    seed_everything(cfg["seed"])
    ensure_dir(cfg["save_dir"])
    device = cfg["device"]

    charset = Charset(cfg["charset_txt"])
    hard_meta = load_hard_meta(cfg["hard_analysis_csv"])
    print(f"charset size (with blank): {len(charset.chars)}")
    print(f"filtered hard meta rows kept: {len(hard_meta)}")

    clean_train_pools = {split: read_manifest(path, charset, source=f"clean_{split}", split_name=split)
                         for split, path in cfg["train_manifests"].items()}
    clean_val_pools = {split: read_manifest(path, charset, source=f"clean_{split}", split_name=split)
                       for split, path in cfg["val_manifests"].items()}
    hard_train_pools = {
        "train": read_manifest(cfg["hard_train_manifest"], charset, source="hard_train", split_name="train", hard_meta=hard_meta),
        "val": read_manifest(cfg["hard_val_manifest"], charset, source="hard_val", split_name="val", hard_meta=hard_meta),
    }
    hard_val_pools = {
        "train": read_manifest(cfg["hard_train_manifest"], charset, source="hard_train", split_name="train", hard_meta=hard_meta),
        "val": read_manifest(cfg["hard_val_manifest"], charset, source="hard_val", split_name="val", hard_meta=hard_meta),
    }

    print(f"clean train pools: train={len(clean_train_pools['train'])}, val={len(clean_train_pools['val'])}")
    print(f"clean val pools:   train={len(clean_val_pools['train'])}, val={len(clean_val_pools['val'])}")
    print(f"hard pools:        train={len(hard_train_pools['train'])}, val={len(hard_train_pools['val'])}")

    cat_counts = {}
    for split_name, pool in hard_train_pools.items():
        for x in pool:
            key = f"{x.category}__{split_name}"
            cat_counts[key] = cat_counts.get(key, 0) + 1
    print(f"filtered hard categories: {json.dumps(cat_counts, ensure_ascii=False)}")

    model = MobileNetV3SmallCTC(num_chars=len(charset.chars), pretrained=False, img_h=cfg["img_h"], img_w=cfg["img_w"]).to(device)
    load_checkpoint_strict(model, cfg["init_ckpt"], device)

    with torch.no_grad():
        dummy = torch.zeros(1, 3, cfg["img_h"], cfg["img_w"]).to(device)
        T = model(dummy).shape[0]
    print(f"CTC time steps T = {T}")

    optimizer = torch.optim.AdamW(model.parameters(), lr=cfg["lr"], weight_decay=cfg["weight_decay"])
    scheduler = get_scheduler(optimizer, cfg)
    ctc_loss_per_sample = nn.CTCLoss(blank=0, reduction="none", zero_infinity=True)
    autocast_ctx, scaler, amp_enabled = get_amp_context_and_scaler(device, cfg["use_amp"])
    stopper = EarlyStopper(cfg["early_stop_patience"], cfg["min_delta"])

    history = {k: [] for k in [
        "train_loss","val_loss","val_acc","char_acc","first_char_acc",
        "gt_wan_rate","pred_wan_rate","nonwan_to_wan_rate","selection_metric","lr"
    ]}

    best_metric = -1.0
    best_epoch = -1

    for epoch in range(1, cfg["epochs"] + 1):
        print("\n" + "=" * 72)
        print(f"Epoch {epoch}/{cfg['epochs']}")
        print("=" * 72)

        rng = random.Random(cfg["seed"] + epoch * 9973)

        clean_train_items = sample_clean_epoch(clean_train_pools, cfg["clean_train_total_per_epoch"], cfg["clean_train_ratio"], rng, cfg["clean_max_wan_ratio"])
        hard_train_items = sample_hard_epoch(hard_train_pools, cfg["hard_train_total_per_epoch"], cfg["hard_train_ratio"], cfg["hard_category_ratio"], rng, cfg["hard_max_wan_ratio"])
        train_items = clean_train_items + hard_train_items
        rng.shuffle(train_items)

        clean_val_items = sample_clean_epoch(clean_val_pools, cfg["clean_val_total"], cfg["clean_val_ratio"], rng, cfg["clean_max_wan_ratio"])
        hard_val_items = sample_hard_epoch(hard_val_pools, cfg["hard_val_total"], cfg["hard_val_ratio"], cfg["hard_category_ratio"], rng, cfg["hard_max_wan_ratio"])
        val_items = clean_val_items + hard_val_items
        rng.shuffle(val_items)

        print(f"train mix: clean={len(clean_train_items)}, hard={len(hard_train_items)}, total={len(train_items)}")
        print(f"val mix:   clean={len(clean_val_items)}, hard={len(hard_val_items)}, total={len(val_items)}")

        train_loader = build_loader(train_items, charset, cfg, augment=cfg["augment"], shuffle=True)
        val_loader = build_loader(val_items, charset, cfg, augment=False, shuffle=False)

        train_loss = train_one_epoch(model, train_loader, optimizer, scaler, autocast_ctx, ctc_loss_per_sample, device, cfg, amp_enabled)
        metrics = evaluate(model, val_loader, ctc_loss_per_sample, charset, device)
        scheduler.step()
        lr_now = optimizer.param_groups[0]["lr"]

        history["train_loss"].append(train_loss)
        history["val_loss"].append(metrics["val_loss"])
        history["val_acc"].append(metrics["acc"])
        history["char_acc"].append(metrics["char_acc"])
        history["first_char_acc"].append(metrics["first_char_acc"])
        history["gt_wan_rate"].append(metrics["gt_wan_rate"])
        history["pred_wan_rate"].append(metrics["pred_wan_rate"])
        history["nonwan_to_wan_rate"].append(metrics["nonwan_to_wan_rate"])
        history["selection_metric"].append(metrics["selection_metric"])
        history["lr"].append(lr_now)

        print(
            f"train_loss={train_loss:.4f} val_loss={metrics['val_loss']:.4f}\n"
            f"plate_acc={metrics['acc']:.4f} char_acc={metrics['char_acc']:.4f} first_char_acc={metrics['first_char_acc']:.4f}\n"
            f"gt_wan_rate={metrics['gt_wan_rate']:.4f} pred_wan_rate={metrics['pred_wan_rate']:.4f} nonwan_to_wan_rate={metrics['nonwan_to_wan_rate']:.4f}\n"
            f"selection_metric={metrics['selection_metric']:.4f} lr={lr_now:.2e}\n"
            f"  {src_summary_str(metrics['src_metrics'])}"
        )

        ckpt = {"epoch": epoch, "model": model.state_dict(), "cfg": cfg, "charset": charset.chars, "metrics": metrics, "history": history}
        save_dir = Path(cfg["save_dir"])
        torch.save(ckpt, save_dir / "last.pt")

        stop, improved = stopper.step(metrics["selection_metric"])
        if improved:
            best_metric = metrics["selection_metric"]
            best_epoch = epoch
            torch.save(ckpt, save_dir / "best.pt")
            print(f"★ new best: selection_metric={best_metric:.4f}")

        draw_curves(history, str(save_dir / "curves.png"))
        save_history_csv(history, str(save_dir / "history.csv"))
        if stop:
            print(f"[Early Stop] no improvement for {cfg['early_stop_patience']} epochs")
            break

    summary = {
        "best_epoch": best_epoch,
        "best_selection_metric": best_metric,
        "final_epoch": len(history["train_loss"]),
        "final_plate_acc": history["val_acc"][-1] if history["val_acc"] else None,
        "final_char_acc": history["char_acc"][-1] if history["char_acc"] else None,
        "final_first_char_acc": history["first_char_acc"][-1] if history["first_char_acc"] else None,
        "final_gt_wan_rate": history["gt_wan_rate"][-1] if history["gt_wan_rate"] else None,
        "final_pred_wan_rate": history["pred_wan_rate"][-1] if history["pred_wan_rate"] else None,
        "final_nonwan_to_wan_rate": history["nonwan_to_wan_rate"][-1] if history["nonwan_to_wan_rate"] else None,
        "notes": {
            "round6_3a_tiny_province_repair": [
                "base checkpoint is round6.3 best",
                "only province_to_wan_targeted + small wan_stabilizer are kept",
                "tail/nonfirst/multi-char buckets are fully paused",
                "goal is to preserve round6.3 overall gains while repairing province confusion",
            ]
        },
    }
    with open(Path(cfg["save_dir"]) / "run_summary.json", "w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)

    print("training finished")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
