#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
os.environ["OMP_NUM_THREADS"] = "1"

import csv
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageFile
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


CONFIG = {
    "stage_name": "round6_tiny_refine_from_round5_best",

    # ===== 数据 =====
    "train_manifests": {
        "train": r"./data/path_placeholder",
        "val": r"./data/path_placeholder",
    },
    "val_manifests": {
        "train": r"./data/path_placeholder",
        "val": r"./data/path_placeholder",
    },

    "charset_txt": r"./data/path_placeholder",

    # ===== 起点：用你当前最好的 best.pt =====
    "init_ckpt": r"./data/path_placeholder",
    "save_dir": r"./data/path_placeholder",

    "img_h": 48,
    "img_w": 320,

    # ===== 稳定优先 =====
    "batch_size": 64,
    "epochs": 6,

    "head_lr": 3e-6,
    "backbone_lr": 1e-6,
    "min_lr": 5e-7,
    "weight_decay": 1e-5,
    "grad_clip_norm": 3.0,

    "num_workers": 2,  # 更稳一点
    "device": "cuda" if torch.cuda.is_available() else "cpu",
    "seed": 42,

    "freeze_backbone_epochs": 2,
    "early_stop_patience": 3,
    "min_delta": 5e-5,

    # 为了稳定，这版直接关 AMP
    "use_amp": False,

    "train_total_samples_per_epoch": 60000,
    "train_source_ratio": {"train": 0.7, "val": 0.3},

    "val_total_samples": 20000,
    "val_source_ratio": {"train": 0.7, "val": 0.3},

    # 训练中只 greedy
    "use_constrained_decode": True,
    "beam_width": 5,

    # 不做复杂增强
    "augment": False,
}


def seed_everything(seed=42):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)


def ensure_dir(path):
    Path(path).mkdir(parents=True, exist_ok=True)


def validate_config(cfg):
    train_keys = set(cfg["train_manifests"].keys())
    val_keys = set(cfg["val_manifests"].keys())
    train_ratio_keys = set(cfg["train_source_ratio"].keys())
    val_ratio_keys = set(cfg["val_source_ratio"].keys())

    if train_keys != train_ratio_keys:
        raise ValueError(
            f"train_manifests keys 与 train_source_ratio keys 不一致: {train_keys} vs {train_ratio_keys}"
        )
    if val_keys != val_ratio_keys:
        raise ValueError(
            f"val_manifests keys 与 val_source_ratio keys 不一致: {val_keys} vs {val_ratio_keys}"
        )


def check_paths_exist(cfg):
    must_exist = [
        cfg["charset_txt"],
        cfg["init_ckpt"],
        *cfg["train_manifests"].values(),
        *cfg["val_manifests"].values(),
    ]
    for p in must_exist:
        if not os.path.exists(p):
            raise FileNotFoundError(f"找不到文件: {p}")


def make_source_counts(total, ratio_dict):
    total_r = sum(ratio_dict.values())
    if total_r <= 0:
        return {k: 0 for k in ratio_dict}

    ratios = {k: v / total_r for k, v in ratio_dict.items()}
    counts = {k: int(total * v) for k, v in ratios.items()}

    remain = total - sum(counts.values())
    keys = sorted(
        ratios.keys(),
        key=lambda x: total * ratios[x] - counts[x],
        reverse=True
    )
    for i in range(remain):
        counts[keys[i % len(keys)]] += 1
    return counts


def choose_samples(samples, n, rng):
    if n <= 0 or len(samples) == 0:
        return []
    if n <= len(samples):
        return [samples[i] for i in rng.sample(range(len(samples)), n)]
    return [samples[rng.randrange(len(samples))] for _ in range(n)]


class Charset:
    def __init__(self, charset_txt):
        with open(charset_txt, "r", encoding="utf-8") as f:
            chars = [x.strip() for x in f.readlines() if x.strip()]

        self.blank = "<blank>"
        self.base_chars = chars
        self.chars = [self.blank] + chars
        self.char2id = {c: i for i, c in enumerate(self.chars)}
        self.id2char = {i: c for i, c in enumerate(self.chars)}

        self.provinces = set("京津沪渝冀豫云辽黑湘皖鲁新苏浙赣鄂桂甘晋蒙陕吉闽贵粤川青藏琼宁")
        self.letters = set("ABCDEFGHJKLMNPQRSTUVWXYZ")
        self.alphanums = self.letters | set("0123456789")
        self.new_energy_last = set("DF")
        self.special_suffix = set("学警港澳挂领使")

    def encode(self, text):
        return [self.char2id[c] for c in text if c in self.char2id]

    def decode_ctc(self, ids):
        prev, out = None, []
        for i in ids:
            if i != 0 and i != prev:
                out.append(self.id2char.get(i, "?"))
            prev = i
        return "".join(out)


def read_manifest(txt_path, charset, source):
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
            if not (7 <= len(label) <= 9):
                continue
            if not all(c in charset.char2id for c in label):
                continue

            samples.append((str(p), label, source))

    return samples


def resize_pad(im, img_h, img_w):
    im = im.convert("RGB")
    scale = min(img_w / im.width, img_h / im.height)
    nw = max(1, int(round(im.width * scale)))
    nh = max(1, int(round(im.height * scale)))
    rs = im.resize((nw, nh), Image.BILINEAR)
    canvas = Image.new("RGB", (img_w, img_h), (127, 127, 127))
    canvas.paste(rs, ((img_w - nw) // 2, (img_h - nh) // 2))
    return canvas


class OCRDataset(Dataset):
    def __init__(self, samples, charset, img_h, img_w):
        self.samples = samples
        self.charset = charset
        self.img_h = img_h
        self.img_w = img_w
        self.to_tensor = transforms.ToTensor()
        self.normalize = transforms.Normalize([0.5] * 3, [0.5] * 3)

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        path, text, source = self.samples[idx]
        im = Image.open(path).convert("RGB")
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


def build_epoch_data(sources, total, ratio, charset, cfg, seed, shuffle):
    counts = make_source_counts(total, ratio)
    rng = random.Random(seed)
    epoch_samples = []

    for src, cnt in counts.items():
        if src in sources and sources[src]:
            epoch_samples.extend(choose_samples(sources[src], cnt, rng))

    rng.shuffle(epoch_samples)

    ds = OCRDataset(epoch_samples, charset, cfg["img_h"], cfg["img_w"])
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

    def forward(self, x):
        feat = self.backbone(x)
        feat = self.reduce(feat)
        feat = feat.mean(dim=2)
        logits = self.classifier(feat)
        return logits.permute(2, 0, 1)


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
    return torch.optim.AdamW(
        [
            {"params": head_params, "lr": cfg["head_lr"], "weight_decay": cfg["weight_decay"]},
            {"params": backbone_params, "lr": cfg["backbone_lr"], "weight_decay": cfg["weight_decay"]},
        ]
    )


@torch.no_grad()
def greedy_decode(logits, charset):
    pred = logits.argmax(dim=-1).permute(1, 0)
    return [charset.decode_ctc(seq.tolist()) for seq in pred]


class ConstrainedCTCDecoder:
    def __init__(self, charset, beam_width=5):
        self.charset = charset
        self.beam_width = beam_width

    def decode_batch(self, logits_tbc, use_constraint=True):
        probs = logits_tbc.softmax(dim=-1).detach().cpu().numpy()
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


class EarlyStopper:
    def __init__(self, patience=3, min_delta=1e-4):
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


def train_one_epoch(model, loader, optimizer, loss_fn, device, cfg):
    model.train()
    total_loss, n = 0.0, 0

    for images, labels_cat, label_lengths, _, _ in loader:
        images = images.to(device, non_blocking=True)
        labels_cat = labels_cat.to(device)
        label_lengths = label_lengths.to(device)

        optimizer.zero_grad(set_to_none=True)
        logits = model(images)

        # 强制 float32，规避 CTC half 问题
        log_probs = F.log_softmax(logits.float(), dim=-1)
        input_lengths = torch.full(
            (images.shape[0],),
            logits.shape[0],
            dtype=torch.long,
            device=device
        )
        loss_per_sample = loss_fn(log_probs, labels_cat, input_lengths, label_lengths)
        loss = loss_per_sample.mean()

        loss.backward()
        nn.utils.clip_grad_norm_(model.parameters(), cfg["grad_clip_norm"])
        optimizer.step()

        total_loss += loss.item()
        n += 1

    return total_loss / max(n, 1)


@torch.no_grad()
def evaluate(model, loader, charset, device, beam_decoder=None, use_beam=False):
    model.eval()
    ctc_loss_fn = nn.CTCLoss(blank=0, reduction="mean", zero_infinity=True)

    total_loss, n = 0.0, 0
    correct, total = 0, 0
    char_correct, char_total = 0, 0
    src_stats = {}

    for images, labels_cat, label_lengths, texts, sources in loader:
        images = images.to(device, non_blocking=True)
        labels_cat_d = labels_cat.to(device)
        label_lengths_d = label_lengths.to(device)

        logits = model(images)
        log_probs = F.log_softmax(logits.float(), dim=-1)
        input_lengths = torch.full(
            (images.shape[0],),
            logits.shape[0],
            dtype=torch.long,
            device=device
        )
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
        "decode_mode": "beam" if use_beam else "greedy",
        "val_loss": total_loss / max(n, 1),
        "acc": correct / max(total, 1),
        "char_acc": char_correct / max(char_total, 1),
        "src_acc": {s: d["correct"] / max(d["total"], 1) for s, d in src_stats.items()},
        "src_total": {s: d["total"] for s, d in src_stats.items()},
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


def main():
    cfg = CONFIG
    validate_config(cfg)
    check_paths_exist(cfg)
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
        pretrained=False,
        img_h=cfg["img_h"],
        img_w=cfg["img_w"],
    ).to(device)

    load_checkpoint(model, cfg["init_ckpt"], device)

    with torch.no_grad():
        T = model(torch.zeros(1, 3, cfg["img_h"], cfg["img_w"]).to(device)).shape[0]
    print(f"CTC T = {T}")

    if cfg["freeze_backbone_epochs"] > 0:
        model.set_backbone_trainable(False)
        print(f"前 {cfg['freeze_backbone_epochs']} 个 epoch 冻结 backbone")

    optimizer = build_optimizer(model, cfg)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(
        optimizer,
        T_max=cfg["epochs"],
        eta_min=cfg["min_lr"]
    )

    loss_fn = nn.CTCLoss(blank=0, reduction="none", zero_infinity=True)
    stopper = EarlyStopper(cfg["early_stop_patience"], cfg["min_delta"])
    beam_decoder = ConstrainedCTCDecoder(charset, beam_width=cfg["beam_width"])

    history_keys = [
        "train_loss", "val_loss", "val_acc", "val_char_acc",
        "lr_head", "lr_backbone", "composite",
        "val_train_acc", "val_val_acc",
    ]
    history = {k: [] for k in history_keys}

    best_metric, best_epoch = -1.0, -1

    print("\n============================================================")
    print(f"开始 Tiny Refine ({cfg['epochs']} epochs)")
    print(f"init_ckpt={cfg['init_ckpt']}")
    print(f"head_lr={cfg['head_lr']}, backbone_lr={cfg['backbone_lr']}")
    print("============================================================")

    for epoch in range(1, cfg["epochs"] + 1):
        if epoch == cfg["freeze_backbone_epochs"] + 1 and cfg["freeze_backbone_epochs"] > 0:
            model.set_backbone_trainable(True)
            print("Backbone 解冻")

        _, train_loader, train_counts = build_epoch_data(
            train_sources,
            cfg["train_total_samples_per_epoch"],
            cfg["train_source_ratio"],
            charset,
            cfg,
            seed=cfg["seed"] + epoch * 100,
            shuffle=True,
        )
        _, val_loader, val_counts = build_epoch_data(
            val_sources,
            cfg["val_total_samples"],
            cfg["val_source_ratio"],
            charset,
            cfg,
            seed=cfg["seed"] + 9999,
            shuffle=False,
        )

        print(f"\nEpoch {epoch}/{cfg['epochs']}")
        print(f"  Train: {train_counts}")
        print(f"  Val:   {val_counts}")

        train_loss = train_one_epoch(model, train_loader, optimizer, loss_fn, device, cfg)
        metrics = evaluate(model, val_loader, charset, device, beam_decoder=None, use_beam=False)

        scheduler.step()

        composite = 0.0
        if len(metrics["src_acc"]) > 0:
            composite = sum(metrics["src_acc"].values()) / len(metrics["src_acc"])

        lr_head = optimizer.param_groups[0]["lr"]
        lr_backbone = optimizer.param_groups[1]["lr"]

        history["train_loss"].append(train_loss)
        history["val_loss"].append(metrics["val_loss"])
        history["val_acc"].append(metrics["acc"])
        history["val_char_acc"].append(metrics["char_acc"])
        history["lr_head"].append(lr_head)
        history["lr_backbone"].append(lr_backbone)
        history["composite"].append(composite)
        history["val_train_acc"].append(metrics["src_acc"].get("train", 0.0))
        history["val_val_acc"].append(metrics["src_acc"].get("val", 0.0))

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
            print(f"  新最佳! composite={composite:.4f}")

        draw_curves(history, save_dir / "curves.png")
        save_csv(history, save_dir / "history.csv")

        if stop:
            print(f"\n[Early Stop] 连续 {cfg['early_stop_patience']} 轮无提升")
            break

    best_ckpt_path = str(save_dir / "best.pt")
    if os.path.exists(best_ckpt_path):
        print("\n===== best.pt 最终 Beam 评估 =====")
        best_model = MobileNetV3SmallCTC(
            num_chars=len(charset.chars),
            pretrained=False,
            img_h=cfg["img_h"],
            img_w=cfg["img_w"],
        ).to(device)
        load_checkpoint(best_model, best_ckpt_path, device)

        _, final_val_loader, final_val_counts = build_epoch_data(
            val_sources,
            cfg["val_total_samples"],
            cfg["val_source_ratio"],
            charset,
            cfg,
            seed=cfg["seed"] + 9999,
            shuffle=False,
        )
        beam_metrics = evaluate(
            best_model,
            final_val_loader,
            charset,
            device,
            beam_decoder=beam_decoder,
            use_beam=True
        )

        print(f"  Val: {final_val_counts}")
        print(f"  decode_mode={beam_metrics['decode_mode']}")
        print(f"  loss={beam_metrics['val_loss']:.4f} acc={beam_metrics['acc']:.4f} char_acc={beam_metrics['char_acc']:.4f}")
        for src, acc in beam_metrics["src_acc"].items():
            print(f"    {src}: {acc:.4f} ({beam_metrics['src_total'].get(src, 0)} samples)")

    print("\n训练结束")
    print(f"best_epoch={best_epoch}, best_metric={best_metric:.4f}")


if __name__ == "__main__":
    main()
