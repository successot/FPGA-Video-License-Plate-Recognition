#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
os.environ["OMP_NUM_THREADS"] = "1"

import io
import csv
import math
import random
import contextlib
from pathlib import Path
from typing import List, Optional

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
    "stage_name": "round5_boost_ultra_conservative",

    # 数据
    "train_manifests": {
        "train": r"./data/path_placeholder",
        "val": r"./data/path_placeholder",
    },
    "val_manifests": {
        "train": r"./data/path_placeholder",
        "val": r"./data/path_placeholder",
    },

    "charset_txt": r"./data/path_placeholder",
    "init_ckpt": r"./data/path_placeholder",
    "save_dir": r"./data/path_placeholder",

    "img_h": 48,
    "img_w": 320,

    "batch_size": 64,
    "epochs": 8,

    # 极保守 lr
    "head_lr": 1e-5,
    "backbone_lr": 3e-6,
    "min_lr": 1e-6,
    "weight_decay": 1e-5,
    "grad_clip_norm": 3.0,

    # 不用 warm restart
    "use_warm_restart": False,

    "num_workers": 4,
    "device": "cuda" if torch.cuda.is_available() else "cpu",
    "seed": 42,
    "pretrained_backbone": False,

    # 先冻 backbone 两轮
    "freeze_backbone_epochs": 2,

    "early_stop_patience": 4,
    "min_delta": 5e-5,
    "use_amp": True,

    # 每轮抽样规模也保守一些
    "train_total_samples_per_epoch": 80000,
    "train_source_ratio_start": {"train": 0.7, "val": 0.3},
    "train_source_ratio_end":   {"train": 0.7, "val": 0.3},
    "curriculum_transition_epochs": 1,

    "val_total_samples": 20000,
    "val_source_ratio": {"train": 0.7, "val": 0.3},

    # 先全部关掉
    "use_focal_ctc": False,
    "focal_gamma": 2.0,

    "use_ohem": False,
    "ohem_ratio": 0.7,

    "use_mixup": False,
    "mixup_alpha": 0.2,
    "mixup_prob": 0.3,

    "use_spec_augment": False,
    "spec_time_mask_num": 2,
    "spec_time_mask_width": 3,
    "spec_freq_mask_num": 1,
    "spec_freq_mask_width": 8,

    "use_swa": False,
    "swa_start_epoch": 25,
    "swa_lr": 5e-5,

    "use_constrained_decode": True,
    "use_beam_during_train": False,
    "use_beam_at_final": True,
    "eval_init_ckpt_before_train": True,

    # 极保守：先不增强
    "augment": False,
    "aug_brightness": (0.9, 1.1),
    "aug_contrast": (0.9, 1.1),
    "aug_color": (0.95, 1.05),
    "aug_affine_prob": 0.0,
    "aug_blur_prob": 0.0,
    "aug_downup_prob": 0.0,
    "aug_jpeg_prob": 0.0,
    "aug_occlude_prob": 0.0,
    "aug_noise_prob": 0.0,
    "aug_perspective_prob": 0.0,
    "aug_erode_dilate_prob": 0.0,
    "aug_cutout_prob": 0.0,
    "aug_shadow_prob": 0.0,
}


def seed_everything(seed=42):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)


def ensure_dir(path):
    Path(path).mkdir(parents=True, exist_ok=True)


def validate_config(cfg):
    train_manifest_keys = set(cfg["train_manifests"].keys())
    val_manifest_keys = set(cfg["val_manifests"].keys())
    train_ratio_start_keys = set(cfg["train_source_ratio_start"].keys())
    train_ratio_end_keys = set(cfg["train_source_ratio_end"].keys())
    val_ratio_keys = set(cfg["val_source_ratio"].keys())

    if train_manifest_keys != train_ratio_start_keys:
        raise ValueError(
            f"train_manifests keys 与 train_source_ratio_start keys 不一致: "
            f"{train_manifest_keys} vs {train_ratio_start_keys}"
        )
    if train_manifest_keys != train_ratio_end_keys:
        raise ValueError(
            f"train_manifests keys 与 train_source_ratio_end keys 不一致: "
            f"{train_manifest_keys} vs {train_ratio_end_keys}"
        )
    if val_manifest_keys != val_ratio_keys:
        raise ValueError(
            f"val_manifests keys 与 val_source_ratio keys 不一致: "
            f"{val_manifest_keys} vs {val_ratio_keys}"
        )


def amp_autocast_ctx(enabled: bool):
    @contextlib.contextmanager
    def _ctx():
        if not enabled:
            yield
            return

        if hasattr(torch, "amp") and hasattr(torch.amp, "autocast"):
            try:
                with torch.amp.autocast("cuda"):
                    yield
                return
            except TypeError:
                pass

        with torch.cuda.amp.autocast():
            yield

    return _ctx()


def create_grad_scaler(enabled: bool):
    if not enabled:
        return None

    if hasattr(torch, "amp") and hasattr(torch.amp, "GradScaler"):
        try:
            return torch.amp.GradScaler("cuda", enabled=True)
        except TypeError:
            pass

    return torch.cuda.amp.GradScaler(enabled=True)


def get_amp_ctx_and_scaler(device, use_amp):
    enabled = device.startswith("cuda") and use_amp

    @contextlib.contextmanager
    def ctx():
        with amp_autocast_ctx(enabled):
            yield

    scaler = create_grad_scaler(enabled)
    return ctx, scaler, enabled


class Charset:
    def __init__(self, charset_txt):
        with open(charset_txt, "r", encoding="utf-8") as f:
            chars = [x.strip() for x in f.readlines() if x.strip()]
        self.blank = "<blank>"
        self.base_chars = chars
        self.chars = [self.blank] + chars
        self.char2id = {c: i for i, c in enumerate(self.chars)}
        self.id2char = {i: c for i, c in enumerate(self.chars)}
        self._build_position_sets()

    def _build_position_sets(self):
        self.provinces = set("京津沪渝冀豫云辽黑湘皖鲁新苏浙赣鄂桂甘晋蒙陕吉闽贵粤川青藏琼宁")
        self.letters = set("ABCDEFGHJKLMNPQRSTUVWXYZ")
        self.alphanums = self.letters | set("0123456789")
        self.new_energy_last = set("DF")
        self.special_suffix = set("学警港澳挂领使")

    def encode(self, text: str) -> List[int]:
        return [self.char2id[c] for c in text if c in self.char2id]

    def decode_ctc(self, ids) -> str:
        prev, out = None, []
        for i in ids:
            if i != 0 and i != prev:
                out.append(self.id2char.get(i, "?"))
            prev = i
        return "".join(out)


def read_manifest(txt_path: str, charset: Charset, source: str):
    root = Path(txt_path).parent
    samples = []
    if not os.path.exists(txt_path):
        print(f"[WARN] Manifest 不存在: {txt_path}")
        return samples

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


def interpolate_ratio(ratio_start, ratio_end, epoch, transition_epochs):
    if epoch >= transition_epochs:
        return dict(ratio_end)
    t = epoch / max(transition_epochs, 1)
    result = {}
    all_keys = set(list(ratio_start.keys()) + list(ratio_end.keys()))
    for k in all_keys:
        s = ratio_start.get(k, 0.0)
        e = ratio_end.get(k, 0.0)
        result[k] = s + (e - s) * t
    return result


def make_source_counts(total, ratio_dict):
    total_r = sum(ratio_dict.values())
    if total_r <= 0:
        return {k: 0 for k in ratio_dict}
    ratios = {k: v / total_r for k, v in ratio_dict.items()}
    counts = {k: int(total * v) for k, v in ratios.items()}
    remain = total - sum(counts.values())
    keys = sorted(ratios.keys(), key=lambda x: total * ratios[x] - counts[x], reverse=True)
    for i in range(remain):
        counts[keys[i % len(keys)]] += 1
    return counts


def choose_samples(samples, n, rng):
    if n <= 0 or len(samples) == 0:
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


class AdvancedOCRDataset(Dataset):
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
        q = rng.randint(25, 80)
        buf = io.BytesIO()
        im.save(buf, format="JPEG", quality=q)
        buf.seek(0)
        return Image.open(buf).convert("RGB")

    def _down_up(self, im, rng):
        w, h = im.size
        s = rng.uniform(0.35, 0.8)
        nw, nh = max(6, int(w * s)), max(3, int(h * s))
        return im.resize((nw, nh), Image.BILINEAR).resize((w, h), Image.BILINEAR)

    def _affine(self, im, rng):
        return transforms.functional.affine(
            im,
            angle=rng.uniform(-6, 6),
            translate=(
                int(im.width * rng.uniform(-0.06, 0.06)),
                int(im.height * rng.uniform(-0.10, 0.10))
            ),
            scale=rng.uniform(0.88, 1.10),
            shear=[rng.uniform(-5, 5), 0.0],
            interpolation=transforms.InterpolationMode.BILINEAR,
            fill=127,
        )

    def _perspective(self, im, rng):
        w, h = im.size
        mw, mh = int(w * rng.uniform(0.02, 0.10)), int(h * rng.uniform(0.02, 0.12))
        src = [(0, 0), (w, 0), (w, h), (0, h)]
        dst = [
            (rng.randint(0, mw), rng.randint(0, mh)),
            (w - rng.randint(0, mw), rng.randint(0, mh)),
            (w - rng.randint(0, mw), h - rng.randint(0, mh)),
            (rng.randint(0, mw), h - rng.randint(0, mh)),
        ]
        return transforms.functional.perspective(
            im, src, dst,
            interpolation=transforms.InterpolationMode.BILINEAR,
            fill=127
        )

    def _occlude(self, im, rng):
        w, h = im.size
        if w < 20 or h < 10:
            return im
        im = im.copy()
        bw = max(3, int(w * rng.uniform(0.04, 0.14)))
        x0 = rng.randint(0, max(0, w - bw))
        color = tuple(rng.randint(40, 200) for _ in range(3))
        overlay = Image.new("RGB", (bw, h), color)
        im.paste(overlay, (x0, 0))
        return im

    def _add_noise(self, im, rng):
        arr = np.array(im, dtype=np.float32)
        noise = np.random.normal(0, rng.uniform(5, 30), arr.shape).astype(np.float32)
        return Image.fromarray(np.clip(arr + noise, 0, 255).astype(np.uint8))

    def _cutout(self, im, rng):
        im = im.copy()
        w, h = im.size
        cw = int(w * rng.uniform(0.05, 0.15))
        ch = int(h * rng.uniform(0.15, 0.40))
        x0 = rng.randint(0, max(0, w - cw))
        y0 = rng.randint(0, max(0, h - ch))
        color = tuple(rng.randint(80, 180) for _ in range(3))
        overlay = Image.new("RGB", (cw, ch), color)
        im.paste(overlay, (x0, y0))
        return im

    def _shadow(self, im, rng):
        im = im.copy()
        w, h = im.size
        arr = np.array(im, dtype=np.float32)
        split = rng.randint(int(w * 0.2), int(w * 0.8))
        factor = rng.uniform(0.4, 0.75)
        if rng.random() < 0.5:
            arr[:, :split, :] *= factor
        else:
            arr[:, split:, :] *= factor
        return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))

    def _augment(self, im, source, rng):
        c = self.cfg
        im = im.convert("RGB")

        if rng.random() < 0.92:
            im = ImageEnhance.Brightness(im).enhance(rng.uniform(*c["aug_brightness"]))
        if rng.random() < 0.92:
            im = ImageEnhance.Contrast(im).enhance(rng.uniform(*c["aug_contrast"]))
        if rng.random() < 0.45:
            im = ImageEnhance.Color(im).enhance(rng.uniform(*c["aug_color"]))

        if rng.random() < c["aug_affine_prob"]:
            im = self._affine(im, rng)
        if rng.random() < c["aug_perspective_prob"]:
            im = self._perspective(im, rng)

        if rng.random() < c["aug_blur_prob"]:
            im = im.filter(ImageFilter.GaussianBlur(radius=rng.uniform(0.3, 1.8)))
        if rng.random() < c["aug_downup_prob"]:
            im = self._down_up(im, rng)
        if rng.random() < c["aug_jpeg_prob"]:
            im = self._jpeg_degrade(im, rng)
        if rng.random() < c["aug_noise_prob"]:
            im = self._add_noise(im, rng)
        if rng.random() < c.get("aug_erode_dilate_prob", 0):
            if rng.random() < 0.5:
                im = im.filter(ImageFilter.MinFilter(3))
            else:
                im = im.filter(ImageFilter.MaxFilter(3))

        if rng.random() < c["aug_occlude_prob"]:
            im = self._occlude(im, rng)
        if rng.random() < c.get("aug_cutout_prob", 0):
            im = self._cutout(im, rng)
        if rng.random() < c.get("aug_shadow_prob", 0):
            im = self._shadow(im, rng)

        return im

    def __getitem__(self, idx):
        path, text, source = self.samples[idx]
        im = Image.open(path).convert("RGB")
        if self.augment:
            im = self._augment(im, source, random.Random())
        im = resize_pad(im, self.img_h, self.img_w)
        x = self.normalize(self.to_tensor(im))
        y = torch.tensor(self.charset.encode(text), dtype=torch.long)
        return x, y, text, source


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


class OCRBackbone(nn.Module):
    def __init__(self, pretrained=False, out_index=8, img_h=48, img_w=320):
        super().__init__()
        weights = MobileNet_V3_Small_Weights.DEFAULT if pretrained else None
        base = mobilenet_v3_small(weights=weights)
        self.features = base.features
        self.out_index = out_index
        self.out_channels = self._infer(img_h, img_w)

    def _infer(self, h, w):
        with torch.no_grad():
            x = torch.zeros(1, 3, h, w)
            for i, layer in enumerate(self.features):
                x = layer(x)
                if i == self.out_index:
                    return x.shape[1]
        raise RuntimeError("无法推断 backbone 输出通道数")

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
            nn.Dropout2d(0.05),
        )
        self.classifier = nn.Conv1d(256, num_chars, kernel_size=1)

    def set_backbone_trainable(self, trainable):
        for p in self.backbone.parameters():
            p.requires_grad = trainable

    def forward(self, x, spec_augment=False, cfg=None):
        feat = self.backbone(x)
        feat = self.reduce(feat)

        if spec_augment and self.training and cfg is not None:
            feat = self._spec_augment(feat, cfg)

        feat = feat.mean(dim=2)
        logits = self.classifier(feat)
        return logits.permute(2, 0, 1)

    def _spec_augment(self, feat, cfg):
        _, C, _, T = feat.shape

        for _ in range(cfg.get("spec_time_mask_num", 2)):
            t_width = random.randint(1, cfg.get("spec_time_mask_width", 3))
            t_start = random.randint(0, max(0, T - t_width))
            feat[:, :, :, t_start:t_start + t_width] = 0.0

        for _ in range(cfg.get("spec_freq_mask_num", 1)):
            f_width = random.randint(1, min(cfg.get("spec_freq_mask_width", 8), C))
            f_start = random.randint(0, max(0, C - f_width))
            feat[:, f_start:f_start + f_width, :, :] = 0.0

        return feat


class FocalCTCLoss(nn.Module):
    def __init__(self, blank=0, gamma=2.0, zero_infinity=True):
        super().__init__()
        self.gamma = gamma
        self.ctc = nn.CTCLoss(blank=blank, reduction="none", zero_infinity=zero_infinity)

    def forward(self, log_probs, targets, input_lengths, target_lengths):
        loss_per_sample = self.ctc(log_probs, targets, input_lengths, target_lengths)
        p = torch.exp(-loss_per_sample)
        focal_weight = (1.0 - p) ** self.gamma
        return focal_weight * loss_per_sample


def mixup_batch(images, labels_cat, label_lengths, alpha=0.2):
    bs = images.shape[0]
    lam = np.random.beta(alpha, alpha) if alpha > 0 else 1.0
    lam = max(lam, 1.0 - lam)
    indices = torch.randperm(bs, device=images.device)
    mixed_images = lam * images + (1.0 - lam) * images[indices]
    return mixed_images, indices, lam


class ConstrainedCTCDecoder:
    def __init__(self, charset: Charset, beam_width: int = 5):
        self.charset = charset
        self.beam_width = beam_width

    def decode_batch(self, logits_tbc: torch.Tensor, use_constraint: bool = True):
        probs = logits_tbc.softmax(dim=-1).cpu().numpy()
        _, B, _ = probs.shape
        texts, confs = [], []
        for b in range(B):
            text, conf = self._beam_search_single(probs[:, b, :], use_constraint)
            texts.append(text)
            confs.append(conf)
        return texts, confs

    def _beam_search_single(self, probs_tc, use_constraint):
        T, C = probs_tc.shape
        beams = [("", -1, 0.0)]
        for t in range(T):
            new_beams = {}
            for prefix, last_id, score in beams:
                for c in range(C):
                    log_p = math.log(probs_tc[t, c] + 1e-12)
                    new_score = score + log_p

                    if c == 0:
                        key = (prefix, -1)
                    elif c == last_id:
                        key = (prefix, c)
                    else:
                        new_char = self.charset.id2char.get(c, "?")
                        new_prefix = prefix + new_char
                        if use_constraint and not self._is_valid_prefix(new_prefix):
                            continue
                        key = (new_prefix, c)

                    if key not in new_beams or new_beams[key] < new_score:
                        new_beams[key] = new_score

            sorted_beams = sorted(new_beams.items(), key=lambda x: x[1], reverse=True)
            beams = [(k[0], k[1], v) for (k, v) in sorted_beams[:self.beam_width]]

        if not beams:
            return "", 0.0
        best = max(beams, key=lambda x: x[2])
        avg_score = best[2] / max(T, 1)
        return best[0], float(math.exp(avg_score))

    def _is_valid_prefix(self, prefix):
        cs = self.charset
        n = len(prefix)
        if n == 0:
            return True
        if n == 1:
            return prefix[0] in cs.provinces
        if n == 2:
            return prefix[0] in cs.provinces and prefix[1] in cs.letters
        if n <= 7:
            return (
                prefix[0] in cs.provinces and
                prefix[1] in cs.letters and
                all(c in cs.alphanums or c in cs.special_suffix for c in prefix[2:])
            )
        if n <= 9:
            return (
                prefix[0] in cs.provinces and
                prefix[1] in cs.letters and
                all(c in cs.alphanums or c in cs.special_suffix or c in cs.new_energy_last for c in prefix[2:])
            )
        return False


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


def load_checkpoint(model, path, device):
    ckpt = torch.load(path, map_location=device)
    state = ckpt.get("model", ckpt) if isinstance(ckpt, dict) else ckpt
    ms = model.state_dict()
    loaded, skipped = 0, 0
    for k, v in state.items():
        if k in ms and ms[k].shape == v.shape:
            ms[k] = v
            loaded += 1
        else:
            skipped += 1
    model.load_state_dict(ms, strict=False)
    print(f"[Checkpoint] loaded={loaded}, skipped={skipped}")
    if skipped > 0:
        print(f"[WARNING] {skipped} keys skipped!")
    return ckpt


def build_optimizer(model, cfg):
    head_params = list(model.reduce.parameters()) + list(model.classifier.parameters())
    backbone_params = list(model.backbone.parameters())

    optimizer = torch.optim.AdamW(
        [
            {
                "params": head_params,
                "lr": cfg["head_lr"],
                "weight_decay": cfg["weight_decay"],
            },
            {
                "params": backbone_params,
                "lr": cfg["backbone_lr"],
                "weight_decay": cfg["weight_decay"],
            },
        ]
    )
    return optimizer


def build_epoch_data(sources, total, ratio, charset, cfg, seed, augment, shuffle):
    counts = make_source_counts(total, ratio)
    rng = random.Random(seed)
    epoch = []
    for src, cnt in counts.items():
        if src in sources and sources[src]:
            epoch.extend(choose_samples(sources[src], cnt, rng))
    rng.shuffle(epoch)

    ds = AdvancedOCRDataset(epoch, charset, cfg["img_h"], cfg["img_w"], augment, cfg)
    loader = DataLoader(
        ds,
        batch_size=cfg["batch_size"],
        shuffle=shuffle,
        num_workers=cfg["num_workers"],
        pin_memory=True,
        collate_fn=collate_fn,
        drop_last=augment
    )
    return ds, loader, counts


def train_one_epoch(model, loader, optimizer, scaler, amp_ctx, loss_fn, device, cfg, amp_on):
    model.train()
    total_loss, n = 0.0, 0
    use_mixup = cfg.get("use_mixup", False)
    use_ohem = cfg.get("use_ohem", False)
    use_spec = cfg.get("use_spec_augment", False)

    for images, labels_cat, label_lengths, _, _ in tqdm(loader, desc="Train", leave=False):
        images = images.to(device, non_blocking=True)
        labels_cat = labels_cat.to(device)
        label_lengths = label_lengths.to(device)

        do_mixup = use_mixup and random.random() < cfg.get("mixup_prob", 0.3)
        if do_mixup:
            mixed_images, mix_indices, lam = mixup_batch(
                images, labels_cat, label_lengths, cfg.get("mixup_alpha", 0.2)
            )
        else:
            mixed_images = images
            lam = 1.0

        optimizer.zero_grad(set_to_none=True)

        with amp_ctx():
            logits = model(mixed_images, spec_augment=use_spec, cfg=cfg)

        log_probs = F.log_softmax(logits.float(), dim=-1)
        input_lengths = torch.full(
            (images.shape[0],), logits.shape[0],
            dtype=torch.long, device=device
        )
        loss_per_sample = loss_fn(log_probs, labels_cat, input_lengths, label_lengths)

        if do_mixup:
            bs = images.shape[0]
            label_list_b = []
            offset = 0
            for i in range(bs):
                length = label_lengths[i].item()
                label_list_b.append(labels_cat[offset:offset + length])
                offset += length

            mix_labels = [label_list_b[mix_indices[i].item()] for i in range(bs)]
            mix_label_lengths = torch.tensor([len(l) for l in mix_labels], dtype=torch.long, device=device)
            mix_labels_cat = torch.cat(mix_labels) if mix_labels else torch.tensor([], dtype=torch.long, device=device)

            loss_per_sample_b = loss_fn(log_probs, mix_labels_cat, input_lengths, mix_label_lengths)
            loss_per_sample = lam * loss_per_sample + (1.0 - lam) * loss_per_sample_b

        if use_ohem:
            k = max(1, int(loss_per_sample.shape[0] * cfg.get("ohem_ratio", 0.7)))
            topk_loss, _ = torch.topk(loss_per_sample, k)
            loss = topk_loss.mean()
        else:
            loss = loss_per_sample.mean()

        if amp_on and scaler is not None:
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
def evaluate(model, loader, charset, device, amp_on, cfg, beam_decoder: Optional[ConstrainedCTCDecoder] = None, force_beam: Optional[bool] = None):
    model.eval()
    ctc_loss_fn = nn.CTCLoss(blank=0, reduction="mean", zero_infinity=True)
    total_loss, n = 0.0, 0
    correct, total = 0, 0
    char_correct, char_total = 0, 0
    src_stats = {}

    if force_beam is None:
        use_beam = beam_decoder is not None and cfg.get("use_constrained_decode", False)
    else:
        use_beam = force_beam and beam_decoder is not None and cfg.get("use_constrained_decode", False)

    for images, labels_cat, label_lengths, texts, sources in tqdm(loader, desc="Val", leave=False):
        images = images.to(device, non_blocking=True)
        labels_cat_d = labels_cat.to(device)
        label_lengths_d = label_lengths.to(device)

        if amp_on:
            with amp_autocast_ctx(True):
                logits = model(images)
        else:
            logits = model(images)

        log_probs = F.log_softmax(logits.float(), dim=-1)
        input_lengths = torch.full((images.shape[0],), logits.shape[0], dtype=torch.long, device=device)
        loss = ctc_loss_fn(log_probs, labels_cat_d, input_lengths, label_lengths_d)

        if use_beam:
            preds, _ = beam_decoder.decode_batch(logits, use_constraint=True)
        else:
            preds = greedy_decode(logits, charset)

        for pred, gt, src in zip(preds, texts, sources):
            total += 1
            if src not in src_stats:
                src_stats[src] = {"correct": 0, "total": 0, "char_correct": 0, "char_total": 0}
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

    return {
        "val_loss": total_loss / max(n, 1),
        "acc": correct / max(total, 1),
        "char_acc": char_correct / max(char_total, 1),
        "src_acc": {s: d["correct"] / max(d["total"], 1) for s, d in src_stats.items()},
        "src_total": {s: d["total"] for s, d in src_stats.items()},
        "decode_mode": "beam" if use_beam else "greedy",
    }


def draw_curves(history, save_path):
    e = list(range(1, len(history["train_loss"]) + 1))
    fig, axes = plt.subplots(1, 5, figsize=(22, 4))

    axes[0].plot(e, history["train_loss"], label="train")
    axes[0].plot(e, history["val_loss"], label="val")
    axes[0].legend()
    axes[0].set_title("Loss")

    axes[1].plot(e, history["val_acc"], label="overall")
    for src in ["train", "val"]:
        key = f"val_{src}_acc"
        if key in history and history[key]:
            axes[1].plot(e, history[key], label=src, alpha=0.7)
    axes[1].legend()
    axes[1].set_title("Plate Acc")

    axes[2].plot(e, history["val_char_acc"], label="char_acc")
    axes[2].legend()
    axes[2].set_title("Char Acc")

    axes[3].plot(e, history["lr_head"], label="head_lr")
    axes[3].plot(e, history["lr_backbone"], label="backbone_lr")
    axes[3].legend()
    axes[3].set_title("LR")

    axes[4].plot(e, history["composite"], label="composite")
    axes[4].legend()
    axes[4].set_title("Composite")

    plt.tight_layout()
    plt.savefig(save_path, dpi=150)
    plt.close()


def save_csv(history, path):
    keys = list(history.keys())
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(keys)
        n = max(len(history[k]) for k in keys)
        for i in range(n):
            w.writerow([history[k][i] if i < len(history[k]) else "" for k in keys])


def evaluate_model_with_beam(model, charset, val_sources, device, cfg, amp_on, beam_decoder, tag, seed_offset=0):
    _, val_loader, val_counts = build_epoch_data(
        val_sources,
        cfg["val_total_samples"],
        cfg["val_source_ratio"],
        charset,
        cfg,
        seed=cfg["seed"] + 13579 + seed_offset,
        augment=False,
        shuffle=False,
    )
    metrics = evaluate(model, val_loader, charset, device, amp_on, cfg, beam_decoder, force_beam=True)

    print(f"\n===== {tag} Beam 评估 =====")
    print(f"  Val: {val_counts}")
    print(f"  decode_mode={metrics['decode_mode']}")
    print(f"  acc={metrics['acc']:.4f} char_acc={metrics['char_acc']:.4f}")
    for src, acc in metrics["src_acc"].items():
        print(f"    {src}: {acc:.4f} ({metrics['src_total'].get(src, 0)} samples)")
    return metrics


def load_model_from_ckpt(ckpt_path, charset, cfg, device):
    model = MobileNetV3SmallCTC(
        num_chars=len(charset.chars),
        pretrained=False,
        img_h=cfg["img_h"],
        img_w=cfg["img_w"],
    ).to(device)
    ckpt = torch.load(ckpt_path, map_location=device)
    state = ckpt.get("model", ckpt)
    model.load_state_dict(state, strict=False)
    return model


def main():
    cfg = CONFIG
    validate_config(cfg)
    seed_everything(cfg["seed"])
    ensure_dir(cfg["save_dir"])
    device = cfg["device"]
    save_dir = Path(cfg["save_dir"])

    charset = Charset(cfg["charset_txt"])
    print(f"字符集: {len(charset.chars)} (含 blank)")

    train_sources, val_sources = {}, {}
    for src, path in cfg["train_manifests"].items():
        s = read_manifest(path, charset, src)
        train_sources[src] = s
        print(f"Train [{src}]: {len(s)}")
    for src, path in cfg["val_manifests"].items():
        s = read_manifest(path, charset, src)
        val_sources[src] = s
        print(f"Val   [{src}]: {len(s)}")

    model = MobileNetV3SmallCTC(
        num_chars=len(charset.chars),
        pretrained=cfg["pretrained_backbone"],
        img_h=cfg["img_h"],
        img_w=cfg["img_w"],
    ).to(device)

    if cfg["init_ckpt"]:
        load_checkpoint(model, cfg["init_ckpt"], device)

    with torch.no_grad():
        T = model(torch.zeros(1, 3, cfg["img_h"], cfg["img_w"]).to(device)).shape[0]
    print(f"CTC T = {T}")

    beam_decoder = ConstrainedCTCDecoder(charset, beam_width=5) if cfg.get("use_constrained_decode") else None
    amp_ctx, scaler, amp_on = get_amp_ctx_and_scaler(device, cfg["use_amp"])

    if cfg.get("eval_init_ckpt_before_train", True) and beam_decoder is not None:
        evaluate_model_with_beam(
            model, charset, val_sources, device, cfg, amp_on, beam_decoder, tag="init_ckpt", seed_offset=1
        )

    if cfg["freeze_backbone_epochs"] > 0:
        model.set_backbone_trainable(False)
        print(f"前 {cfg['freeze_backbone_epochs']} 个 epoch 冻结 backbone")

    if cfg.get("use_focal_ctc", False):
        loss_fn = FocalCTCLoss(blank=0, gamma=cfg.get("focal_gamma", 2.0))
        print(f"使用 Focal CTC Loss (gamma={cfg['focal_gamma']})")
    else:
        loss_fn = nn.CTCLoss(blank=0, reduction="none", zero_infinity=True)
        print("使用标准 CTC Loss")

    optimizer = build_optimizer(model, cfg)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(
        optimizer, T_max=cfg["epochs"], eta_min=cfg["min_lr"]
    )

    stopper = EarlyStopper(cfg["early_stop_patience"], cfg["min_delta"])

    history_keys = [
        "train_loss", "val_loss", "val_acc", "val_char_acc",
        "lr_head", "lr_backbone", "composite"
    ]
    for src in list(cfg["train_manifests"].keys()) + list(cfg["val_manifests"].keys()):
        key = f"val_{src}_acc"
        if key not in history_keys:
            history_keys.append(key)
    history = {k: [] for k in history_keys}

    best_metric, best_epoch = -1.0, -1

    print(f"\n{'='*60}")
    print(f"开始 Ultra Conservative Fine-tune ({cfg['epochs']} epochs)")
    print(
        f"head_lr={cfg['head_lr']}, backbone_lr={cfg['backbone_lr']}, "
        f"freeze_backbone_epochs={cfg['freeze_backbone_epochs']}, "
        f"beam_train={cfg['use_beam_during_train']}, beam_final={cfg['use_beam_at_final']}"
    )
    print(f"{'='*60}")

    for epoch in range(1, cfg["epochs"] + 1):
        if epoch == cfg["freeze_backbone_epochs"] + 1 and cfg["freeze_backbone_epochs"] > 0:
            model.set_backbone_trainable(True)
            print("Backbone 解冻")

        current_ratio = interpolate_ratio(
            cfg["train_source_ratio_start"],
            cfg["train_source_ratio_end"],
            epoch - 1,
            cfg["curriculum_transition_epochs"]
        )

        _, train_loader, train_counts = build_epoch_data(
            train_sources,
            cfg["train_total_samples_per_epoch"],
            current_ratio,
            charset,
            cfg,
            seed=cfg["seed"] + epoch * 997,
            augment=cfg["augment"],
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

        ratio_str = " ".join(f"{k}={v:.2f}" for k, v in current_ratio.items())
        print(f"\nEpoch {epoch}/{cfg['epochs']}  ratio: {ratio_str}")
        print(f"  Train: {train_counts}  Val: {val_counts}")

        train_loss = train_one_epoch(
            model, train_loader, optimizer, scaler, amp_ctx,
            loss_fn, device, cfg, amp_on
        )

        metrics = evaluate(
            model,
            val_loader,
            charset,
            device,
            amp_on,
            cfg,
            beam_decoder,
            force_beam=cfg.get("use_beam_during_train", False)
        )

        scheduler.step()

        src_accs = list(metrics["src_acc"].values())
        composite = sum(src_accs) / len(src_accs) if src_accs else 0.0

        lr_head = optimizer.param_groups[0]["lr"]
        lr_backbone = optimizer.param_groups[1]["lr"]

        history["train_loss"].append(train_loss)
        history["val_loss"].append(metrics["val_loss"])
        history["val_acc"].append(metrics["acc"])
        history["val_char_acc"].append(metrics["char_acc"])
        history["lr_head"].append(lr_head)
        history["lr_backbone"].append(lr_backbone)
        history["composite"].append(composite)

        for src, acc in metrics["src_acc"].items():
            key = f"val_{src}_acc"
            if key in history:
                history[key].append(acc)

        print(f"  decode_mode={metrics['decode_mode']}")
        print(f"  loss: train={train_loss:.4f} val={metrics['val_loss']:.4f}")
        print(f"  acc={metrics['acc']:.4f} char_acc={metrics['char_acc']:.4f} composite={composite:.4f}")
        for src, acc in metrics["src_acc"].items():
            print(f"    {src}: {acc:.4f} ({metrics['src_total'].get(src, 0)} samples)")
        print(f"  head_lr={lr_head:.2e} backbone_lr={lr_backbone:.2e}")

        ckpt = {
            "epoch": epoch,
            "model": model.state_dict(),
            "cfg": {k: v for k, v in cfg.items() if not callable(v)},
            "charset": charset.chars,
            "history": history,
            "metrics": {
                "acc": metrics["acc"],
                "composite": composite,
                "src_acc": metrics["src_acc"],
                "decode_mode": metrics["decode_mode"],
            },
        }
        torch.save(ckpt, save_dir / "last.pt")

        stop, improved = stopper.step(composite)
        if improved:
            best_metric = composite
            best_epoch = epoch
            torch.save(ckpt, save_dir / "best.pt")
            print(f"  新最佳! composite={composite:.4f} (greedy)")

        draw_curves(history, save_dir / "curves.png")
        save_csv(history, save_dir / "history.csv")

        if stop:
            print(f"\n[Early Stop] 连续 {cfg['early_stop_patience']} 轮无提升")
            break

    if cfg.get("use_beam_at_final", True) and beam_decoder is not None:
        best_ckpt_path = str(save_dir / "best.pt")
        if os.path.exists(best_ckpt_path):
            best_model = load_model_from_ckpt(best_ckpt_path, charset, cfg, device)
            evaluate_model_with_beam(
                best_model, charset, val_sources, device, cfg, amp_on, beam_decoder, tag="best.pt", seed_offset=2
            )

    print("\n训练结束")
    print(f"best_epoch={best_epoch}, best_metric={best_metric:.4f}")


if __name__ == "__main__":
    main()
