import os
import csv
import random
import contextlib
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
import matplotlib.pyplot as plt
from tqdm import tqdm


CONFIG = {
    "train_txt": r"./data/path_placeholder",
    "val_txt":r"./data/path_placeholder",
    "charset_txt": r"./data/path_placeholder",
    "save_dir": "runs/ccpd_ocr_fixed",

    "img_h": 48,
    "img_w": 320,
    "batch_size": 64,
    "epochs": 80,
    "lr": 1e-3,
    "weight_decay": 1e-4,
    "num_workers": 4,
    "device": "cuda" if torch.cuda.is_available() else "cpu",
    "pretrained_backbone": True,

    "freeze_backbone_epochs": 3,
    "early_stop_patience": 10,
    "min_delta": 1e-4,
    "use_amp": True,

    "augment": True,
    "brightness_contrast": True,
}


def seed_everything(seed=42):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)


def ensure_dir(path):
    Path(path).mkdir(parents=True, exist_ok=True)


def draw_curves(history, save_path):
    e = list(range(1, len(history["train_loss"]) + 1))
    plt.figure(figsize=(12, 4))

    plt.subplot(1, 3, 1)
    plt.plot(e, history["train_loss"], label="train")
    plt.plot(e, history["val_loss"], label="val")
    plt.legend()
    plt.title("Loss")

    plt.subplot(1, 3, 2)
    plt.plot(e, history["val_acc"], label="val_acc")
    plt.legend()
    plt.title("Sequence Accuracy")

    plt.subplot(1, 3, 3)
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
        self.chars = [self.blank] + chars
        self.char2id = {c: i for i, c in enumerate(self.chars)}
        self.id2char = {i: c for i, c in enumerate(self.chars)}

    def encode(self, text):
        return [self.char2id[c] for c in text if c in self.char2id]

    def decode_ctc(self, ids):
        prev = None
        out = []
        for i in ids:
            if i != 0 and i != prev:
                out.append(self.id2char[i])
            prev = i
        return "".join(out)


class CCPDOCRDataset(Dataset):
    def __init__(self, txt_file, charset: Charset, img_h=48, img_w=320, augment=False):
        self.txt_file = Path(txt_file)
        self.root = self.txt_file.parent
        self.charset = charset
        self.img_h = img_h
        self.img_w = img_w
        self.augment = augment

        with open(txt_file, "r", encoding="utf-8") as f:
            lines = [x.strip() for x in f.readlines() if x.strip()]

        self.samples = []
        for line in lines:
            if "\t" not in line:
                continue
            path_str, text = line.split("\t", 1)
            p = Path(path_str)
            if not p.is_absolute():
                p = (self.root / path_str).resolve()
            text = text.strip()
            encoded = self.charset.encode(text)
            if len(encoded) == 0:
                continue
            self.samples.append((p, text))

        self.to_tensor = transforms.ToTensor()
        self.normalize = transforms.Normalize(mean=[0.5, 0.5, 0.5], std=[0.5, 0.5, 0.5])
        self.color_jitter = transforms.ColorJitter(brightness=0.15, contrast=0.15, saturation=0.08, hue=0.02)

    def __len__(self):
        return len(self.samples)

    def max_label_len(self):
        if len(self.samples) == 0:
            return 0
        return max(len(t[1]) for t in self.samples)

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

    def __getitem__(self, idx):
        img_path, text = self.samples[idx]
        im = Image.open(img_path).convert("RGB")

        if self.augment and random.random() < 0.5:
            im = self.color_jitter(im)

        im = self._resize_pad(im)
        x = self.normalize(self.to_tensor(im))
        y = torch.tensor(self.charset.encode(text), dtype=torch.long)
        return x, y, text


def collate_fn(batch):
    images = [b[0] for b in batch]
    labels = [b[1] for b in batch]
    texts = [b[2] for b in batch]
    label_lengths = torch.tensor([len(x) for x in labels], dtype=torch.long)
    labels_concat = torch.cat(labels, dim=0) if len(labels) > 0 else torch.tensor([], dtype=torch.long)
    return torch.stack(images, dim=0), labels_concat, label_lengths, texts


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
            x = torch.zeros(1, 3, 48, 320)
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
        logits = logits.permute(2, 0, 1)
        return logits


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
    for images, labels_concat, label_lengths, _ in pbar:
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
        pbar.set_postfix({"loss": f"{loss.item():.4f}", "T": int(logits.shape[0]), "lr": f"{optimizer.param_groups[0]['lr']:.2e}"})

    return total_loss / max(n, 1)


@torch.no_grad()
def evaluate(model, loader, ctc_loss, charset, device):
    model.eval()
    total_loss = 0.0
    n = 0
    correct = 0
    total = 0

    for images, labels_concat, label_lengths, gt_texts in tqdm(loader, desc="Val", leave=False):
        images = images.to(device, non_blocking=True)
        labels_concat = labels_concat.to(device)
        label_lengths = label_lengths.to(device)

        logits = model(images)
        log_probs = F.log_softmax(logits, dim=-1)
        input_lengths = torch.full((images.shape[0],), logits.shape[0], dtype=torch.long, device=device)
        loss = ctc_loss(log_probs, labels_concat, input_lengths, label_lengths)

        total_loss += loss.item()
        n += 1

        pred_texts = greedy_decode(logits, charset)
        for p, g in zip(pred_texts, gt_texts):
            if p == g:
                correct += 1
            total += 1

    return {"val_loss": total_loss / max(n, 1), "acc": correct / max(total, 1)}


def main():
    cfg = CONFIG.copy()
    seed_everything(42)
    ensure_dir(cfg["save_dir"])

    if cfg["device"].startswith("cuda"):
        torch.backends.cudnn.benchmark = True

    device = cfg["device"]
    print(f"Using device: {device}")

    charset = Charset(cfg["charset_txt"])

    train_set = CCPDOCRDataset(cfg["train_txt"], charset, img_h=cfg["img_h"], img_w=cfg["img_w"], augment=cfg["augment"])
    val_set = CCPDOCRDataset(cfg["val_txt"], charset, img_h=cfg["img_h"], img_w=cfg["img_w"], augment=False)

    print(f"Train samples: {len(train_set)}")
    print(f"Val samples  : {len(val_set)}")
    print(f"Max label len(train): {train_set.max_label_len()}")

    train_loader = DataLoader(
        train_set,
        batch_size=cfg["batch_size"],
        shuffle=True,
        num_workers=cfg["num_workers"],
        pin_memory=device.startswith("cuda"),
        persistent_workers=cfg["num_workers"] > 0,
        collate_fn=collate_fn,
    )
    val_loader = DataLoader(
        val_set,
        batch_size=cfg["batch_size"],
        shuffle=False,
        num_workers=cfg["num_workers"],
        pin_memory=device.startswith("cuda"),
        persistent_workers=cfg["num_workers"] > 0,
        collate_fn=collate_fn,
    )

    model = MobileNetV3SmallCTC(num_chars=len(charset.chars), pretrained=cfg["pretrained_backbone"]).to(device)
    model.set_backbone_trainable(False if cfg["freeze_backbone_epochs"] > 0 else True)

    with torch.no_grad():
        dummy = torch.zeros(1, 3, cfg["img_h"], cfg["img_w"]).to(device)
        logits = model(dummy)
        T = logits.shape[0]
        print(f"CTC time steps T = {T}")

        max_len = train_set.max_label_len()
        if T < max_len:
            raise RuntimeError(
                f"CTC 时间步不足：T={T} < max_label_len={max_len}。"
                f"请进一步增大 img_w 或提高输出特征分辨率。"
            )

    optimizer = torch.optim.AdamW(
        [p for p in model.parameters() if p.requires_grad],
        lr=cfg["lr"],
        weight_decay=cfg["weight_decay"],
    )
    scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode="max", factor=0.5, patience=2)
    ctc_loss = nn.CTCLoss(blank=0, zero_infinity=True)
    autocast_ctx, scaler = get_amp_context_and_scaler(device, cfg["use_amp"])
    stopper = EarlyStopper(cfg["early_stop_patience"], cfg["min_delta"])

    history = {"train_loss": [], "val_loss": [], "val_acc": [], "lr": []}
    best_path = os.path.join(cfg["save_dir"], "best.pt")
    last_path = os.path.join(cfg["save_dir"], "last.pt")
    curves_path = os.path.join(cfg["save_dir"], "training_curves.png")
    csv_path = os.path.join(cfg["save_dir"], "history.csv")
    best_acc = -1.0

    for epoch in range(1, cfg["epochs"] + 1):
        if epoch == cfg["freeze_backbone_epochs"] + 1:
            print(f"[Info] Unfreeze backbone at epoch {epoch}")
            model.set_backbone_trainable(True)
            optimizer = torch.optim.AdamW(
                [p for p in model.parameters() if p.requires_grad],
                lr=cfg["lr"],
                weight_decay=cfg["weight_decay"],
            )
            scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode="max", factor=0.5, patience=2)

        train_loss = train_one_epoch(model, train_loader, optimizer, scaler, autocast_ctx, ctc_loss, device)
        metrics = evaluate(model, val_loader, ctc_loss, charset, device)
        scheduler.step(metrics["acc"])

        history["train_loss"].append(train_loss)
        history["val_loss"].append(metrics["val_loss"])
        history["val_acc"].append(metrics["acc"])
        history["lr"].append(optimizer.param_groups[0]["lr"])

        draw_curves(history, curves_path)
        save_history_csv(history, csv_path)

        ckpt = {
            "epoch": epoch,
            "model": model.state_dict(),
            "optimizer": optimizer.state_dict(),
            "cfg": cfg,
            "history": history,
            "charset": charset.chars,
        }
        torch.save(ckpt, last_path)

        stop, improved = stopper.step(metrics["acc"])
        if improved:
            best_acc = metrics["acc"]
            torch.save(ckpt, best_path)

        print(
            f"Epoch [{epoch:03d}/{cfg['epochs']}] "
            f"train_loss={train_loss:.4f} "
            f"val_loss={metrics['val_loss']:.4f} "
            f"seq_acc={metrics['acc']:.4f} "
            f"best_acc={best_acc:.4f} "
            f"lr={optimizer.param_groups[0]['lr']:.2e}"
        )

        if stop:
            print(f"[Early Stop] 验证准确率连续 {cfg['early_stop_patience']} 轮没有提升，训练结束。")
            break


if __name__ == "__main__":
    main()
