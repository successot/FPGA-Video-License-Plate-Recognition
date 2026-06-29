import os
import csv
import time
import random
import contextlib
from pathlib import Path
from typing import List

import numpy as np
from PIL import Image, ImageOps, ImageFile
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
    "val_txt":   r"./data/path_placeholder",
    "save_dir":  r"./data/path_placeholder",

    "img_size": 416,
    "batch_size": 16,
    "epochs": 80,
    "lr": 1e-3,
    "weight_decay": 1e-4,
    "num_workers": 4,
    "device": "cuda" if torch.cuda.is_available() else "cpu",
    "pretrained_backbone": True,

    "freeze_backbone_epochs": 5,
    "early_stop_patience": 10,
    "min_delta": 1e-4,
    "use_amp": True,

    "score_thresh": 0.25,
    "nms_iou_thresh": 0.50,

    "hflip_prob": 0.0,
    "color_jitter": True,

    "num_classes": 1,
    "class_names": ["plate"],

    # 更贴合 CCPD 宽高比的 anchors
    "anchors": [
        [(40, 12), (56, 16), (72, 20)],
        [(96, 28), (128, 36), (160, 44)],
        [(192, 52), (240, 64), (300, 80)],
    ],
    "strides": [8, 16, 32],
}


def seed_everything(seed=42):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)

def ensure_dir(path):
    Path(path).mkdir(parents=True, exist_ok=True)

def xywhn_to_xyxy(boxes, w, h):
    if len(boxes) == 0:
        return np.zeros((0, 4), dtype=np.float32)
    boxes = boxes.copy()
    boxes[:, 0] *= w
    boxes[:, 1] *= h
    boxes[:, 2] *= w
    boxes[:, 3] *= h
    x1 = boxes[:, 0] - boxes[:, 2] / 2
    y1 = boxes[:, 1] - boxes[:, 3] / 2
    x2 = boxes[:, 0] + boxes[:, 2] / 2
    y2 = boxes[:, 1] + boxes[:, 3] / 2
    return np.stack([x1, y1, x2, y2], axis=1).astype(np.float32)

def xyxy_to_cxcywh(boxes):
    cx = (boxes[:, 0] + boxes[:, 2]) / 2
    cy = (boxes[:, 1] + boxes[:, 3]) / 2
    w = (boxes[:, 2] - boxes[:, 0]).clamp(min=1e-6)
    h = (boxes[:, 3] - boxes[:, 1]).clamp(min=1e-6)
    return torch.stack([cx, cy, w, h], dim=1)

def box_iou_xyxy(box1, box2):
    if box1.numel() == 0 or box2.numel() == 0:
        return torch.zeros((box1.shape[0], box2.shape[0]), device=box1.device)
    area1 = ((box1[:, 2] - box1[:, 0]).clamp(min=0) *
             (box1[:, 3] - box1[:, 1]).clamp(min=0))
    area2 = ((box2[:, 2] - box2[:, 0]).clamp(min=0) *
             (box2[:, 3] - box2[:, 1]).clamp(min=0))
    lt = torch.max(box1[:, None, :2], box2[:, :2])
    rb = torch.min(box1[:, None, 2:], box2[:, 2:])
    wh = (rb - lt).clamp(min=0)
    inter = wh[..., 0] * wh[..., 1]
    union = area1[:, None] + area2 - inter + 1e-7
    return inter / union

def wh_iou(wh1, wh2):
    inter = torch.min(wh1[:, None, 0], wh2[None, :, 0]) * torch.min(wh1[:, None, 1], wh2[None, :, 1])
    area1 = wh1[:, 0:1] * wh1[:, 1:2]
    area2 = wh2[:, 0] * wh2[:, 1]
    union = area1 + area2 - inter + 1e-7
    return inter / union

def bbox_ciou(pred_boxes, target_boxes):
    inter_x1 = torch.max(pred_boxes[:, 0], target_boxes[:, 0])
    inter_y1 = torch.max(pred_boxes[:, 1], target_boxes[:, 1])
    inter_x2 = torch.min(pred_boxes[:, 2], target_boxes[:, 2])
    inter_y2 = torch.min(pred_boxes[:, 3], target_boxes[:, 3])
    inter = (inter_x2 - inter_x1).clamp(min=0) * (inter_y2 - inter_y1).clamp(min=0)

    area_p = (pred_boxes[:, 2] - pred_boxes[:, 0]).clamp(min=0) * (pred_boxes[:, 3] - pred_boxes[:, 1]).clamp(min=0)
    area_t = (target_boxes[:, 2] - target_boxes[:, 0]).clamp(min=0) * (target_boxes[:, 3] - target_boxes[:, 1]).clamp(min=0)
    union = area_p + area_t - inter + 1e-7
    iou = inter / union

    px = (pred_boxes[:, 0] + pred_boxes[:, 2]) / 2
    py = (pred_boxes[:, 1] + pred_boxes[:, 3]) / 2
    tx = (target_boxes[:, 0] + target_boxes[:, 2]) / 2
    ty = (target_boxes[:, 1] + target_boxes[:, 3]) / 2
    rho2 = (px - tx) ** 2 + (py - ty) ** 2

    cx1 = torch.min(pred_boxes[:, 0], target_boxes[:, 0])
    cy1 = torch.min(pred_boxes[:, 1], target_boxes[:, 1])
    cx2 = torch.max(pred_boxes[:, 2], target_boxes[:, 2])
    cy2 = torch.max(pred_boxes[:, 3], target_boxes[:, 3])
    c2 = ((cx2 - cx1) ** 2 + (cy2 - cy1) ** 2).clamp(min=1e-7)

    pw = (pred_boxes[:, 2] - pred_boxes[:, 0]).clamp(min=1e-7)
    ph = (pred_boxes[:, 3] - pred_boxes[:, 1]).clamp(min=1e-7)
    tw = (target_boxes[:, 2] - target_boxes[:, 0]).clamp(min=1e-7)
    th = (target_boxes[:, 3] - target_boxes[:, 1]).clamp(min=1e-7)
    v = (4 / np.pi ** 2) * (torch.atan(tw / th) - torch.atan(pw / ph)) ** 2
    with torch.no_grad():
        alpha = v / (1 - iou + v + 1e-7)
    return iou - (rho2 / c2) - alpha * v

def nms_xyxy(boxes, scores, iou_thresh=0.5):
    keep = []
    idxs = scores.argsort(descending=True)
    while idxs.numel() > 0:
        i = idxs[0]
        keep.append(i.item())
        if idxs.numel() == 1:
            break
        ious = box_iou_xyxy(boxes[i].unsqueeze(0), boxes[idxs[1:]])[0]
        idxs = idxs[1:][ious < iou_thresh]
    return keep

def draw_curves(history, save_path):
    epochs = list(range(1, len(history["train_loss"]) + 1))
    plt.figure(figsize=(12, 4))
    plt.subplot(1, 3, 1); plt.plot(epochs, history["train_loss"], label="train"); plt.plot(epochs, history["val_loss"], label="val"); plt.legend(); plt.title("Loss")
    plt.subplot(1, 3, 2); plt.plot(epochs, history["val_precision"], label="P"); plt.plot(epochs, history["val_recall"], label="R"); plt.plot(epochs, history["val_f1"], label="F1"); plt.legend(); plt.title("Metrics")
    plt.subplot(1, 3, 3); plt.plot(epochs, history["lr"], label="lr"); plt.legend(); plt.title("LR")
    plt.tight_layout(); plt.savefig(save_path, dpi=150); plt.close()

def save_history_csv(history, save_path):
    keys = list(history.keys())
    with open(save_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f); writer.writerow(keys); writer.writerows(zip(*(history[k] for k in keys)))


class CCPDDetDataset(Dataset):
    def __init__(self, txt_file, img_size=416, augment=False, hflip_prob=0.0, color_jitter=True):
        self.txt_file = Path(txt_file)
        self.root = self.txt_file.parent
        self.img_size = img_size
        self.augment = augment
        self.hflip_prob = hflip_prob
        self.color_jitter = color_jitter

        with open(txt_file, "r", encoding="utf-8") as f:
            lines = [x.strip() for x in f.readlines() if x.strip()]
        self.image_paths = [((self.root / x).resolve() if not Path(x).is_absolute() else Path(x)) for x in lines]

        self.jitter = transforms.ColorJitter(brightness=0.15, contrast=0.15, saturation=0.10, hue=0.02)
        self.to_tensor = transforms.ToTensor()
        self.normalize = transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])

    def _label_path(self, img_path: Path) -> Path:
        img_str = img_path.as_posix()
        return Path(os.path.splitext(img_str.replace("/images/", "/labels/"))[0] + ".txt")

    def _read_label(self, label_path: Path, orig_w: int, orig_h: int):
        if not label_path.exists():
            return np.zeros((0, 4), dtype=np.float32), np.zeros((0,), dtype=np.int64)
        classes, boxes_n = [], []
        with open(label_path, "r", encoding="utf-8") as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) != 5:
                    continue
                cls, cx, cy, bw, bh = parts
                classes.append(int(float(cls)))
                boxes_n.append([float(cx), float(cy), float(bw), float(bh)])
        if len(boxes_n) == 0:
            return np.zeros((0, 4), dtype=np.float32), np.zeros((0,), dtype=np.int64)
        boxes_n = np.array(boxes_n, dtype=np.float32)
        return xywhn_to_xyxy(boxes_n, orig_w, orig_h), np.array(classes, dtype=np.int64)

    def _letterbox(self, image: Image.Image, boxes_xyxy: np.ndarray):
        target = self.img_size
        orig_w, orig_h = image.size
        scale = min(target / orig_w, target / orig_h)
        new_w = int(round(orig_w * scale)); new_h = int(round(orig_h * scale))
        resized = image.resize((new_w, new_h), Image.BILINEAR)
        canvas = Image.new("RGB", (target, target), (114, 114, 114))
        pad_x = (target - new_w) // 2; pad_y = (target - new_h) // 2
        canvas.paste(resized, (pad_x, pad_y))
        if len(boxes_xyxy) > 0:
            boxes_xyxy = boxes_xyxy.copy()
            boxes_xyxy[:, [0, 2]] = boxes_xyxy[:, [0, 2]] * scale + pad_x
            boxes_xyxy[:, [1, 3]] = boxes_xyxy[:, [1, 3]] * scale + pad_y
            boxes_xyxy[:, [0, 2]] = boxes_xyxy[:, [0, 2]].clip(0, target - 1)
            boxes_xyxy[:, [1, 3]] = boxes_xyxy[:, [1, 3]].clip(0, target - 1)
        return canvas, boxes_xyxy

    def __len__(self): return len(self.image_paths)

    def __getitem__(self, idx):
        img_path = self.image_paths[idx]
        image = Image.open(img_path).convert("RGB")
        orig_w, orig_h = image.size
        boxes_xyxy, classes = self._read_label(self._label_path(img_path), orig_w, orig_h)
        image, boxes_xyxy = self._letterbox(image, boxes_xyxy)

        if self.augment:
            if self.color_jitter: image = self.jitter(image)
            if random.random() < self.hflip_prob:
                image = ImageOps.mirror(image)
                if len(boxes_xyxy) > 0:
                    x1 = boxes_xyxy[:, 0].copy(); x2 = boxes_xyxy[:, 2].copy()
                    boxes_xyxy[:, 0] = self.img_size - x2; boxes_xyxy[:, 2] = self.img_size - x1

        image = self.normalize(self.to_tensor(image))
        target = {"boxes": torch.tensor(boxes_xyxy, dtype=torch.float32), "labels": torch.tensor(classes, dtype=torch.long), "path": str(img_path)}
        return image, target

def collate_fn(batch):
    images, targets = zip(*batch)
    return torch.stack(images, dim=0), list(targets)


class ConvBNAct(nn.Module):
    def __init__(self, in_ch, out_ch, k=3, s=1, p=None, groups=1, act=True):
        super().__init__()
        if p is None: p = k // 2
        self.conv = nn.Conv2d(in_ch, out_ch, k, s, p, groups=groups, bias=False)
        self.bn = nn.BatchNorm2d(out_ch)
        self.act = nn.Hardswish(inplace=True) if act else nn.Identity()
    def forward(self, x): return self.act(self.bn(self.conv(x)))

class DWConv(nn.Module):
    def __init__(self, in_ch, out_ch, k=3, s=1, act=True):
        super().__init__()
        self.dw = ConvBNAct(in_ch, in_ch, k=k, s=s, groups=in_ch, act=act)
        self.pw = ConvBNAct(in_ch, out_ch, k=1, s=1, p=0, act=act)
    def forward(self, x): return self.pw(self.dw(x))

class MobileNetV3SmallBackbone(nn.Module):
    def __init__(self, pretrained=True, img_size=416):
        super().__init__()
        weights = MobileNet_V3_Small_Weights.DEFAULT if pretrained else None
        base = mobilenet_v3_small(weights=weights)
        self.features = base.features
        self.out_indices = [3, 8, 12]
        self.out_channels = self._infer_out_channels(img_size)

    def _infer_out_channels(self, img_size):
        chans = []
        with torch.no_grad():
            x = torch.zeros(1, 3, img_size, img_size)
            for i, layer in enumerate(self.features):
                x = layer(x)
                if i in self.out_indices: chans.append(x.shape[1])
        return chans

    def forward(self, x):
        outs = []
        for i, layer in enumerate(self.features):
            x = layer(x)
            if i in self.out_indices: outs.append(x)
        return outs

class LightFPN(nn.Module):
    def __init__(self, in_channels, out_channels=96):
        super().__init__()
        c3_ch, c4_ch, c5_ch = in_channels
        self.lateral_c3 = ConvBNAct(c3_ch, out_channels, k=1, s=1, p=0)
        self.lateral_c4 = ConvBNAct(c4_ch, out_channels, k=1, s=1, p=0)
        self.lateral_c5 = ConvBNAct(c5_ch, out_channels, k=1, s=1, p=0)
        self.smooth_p3 = DWConv(out_channels, out_channels, 3, 1)
        self.smooth_p4 = DWConv(out_channels, out_channels, 3, 1)
        self.smooth_p5 = DWConv(out_channels, out_channels, 3, 1)
    def forward(self, feats):
        c3, c4, c5 = feats
        p5 = self.lateral_c5(c5)
        p4 = self.lateral_c4(c4) + F.interpolate(p5, size=c4.shape[-2:], mode="nearest")
        p3 = self.lateral_c3(c3) + F.interpolate(p4, size=c3.shape[-2:], mode="nearest")
        return [self.smooth_p3(p3), self.smooth_p4(p4), self.smooth_p5(p5)]

class DetectHead(nn.Module):
    def __init__(self, in_channels=96, num_anchors=3, num_classes=1):
        super().__init__()
        self.num_anchors = num_anchors
        self.num_classes = num_classes
        self.pred_dim = 5 + num_classes
        self.stems = nn.ModuleList([DWConv(in_channels, in_channels, 3, 1) for _ in range(3)])
        self.pred_layers = nn.ModuleList([nn.Conv2d(in_channels, num_anchors * self.pred_dim, 1) for _ in range(3)])
        self._init_bias()
    def _init_bias(self):
        for pred in self.pred_layers:
            b = pred.bias.view(self.num_anchors, -1)
            b.data[:, 4] = -4.0
            if self.num_classes > 0: b.data[:, 5:] = -2.2
            pred.bias = torch.nn.Parameter(b.view(-1), requires_grad=True)
    def forward(self, feats):
        return [pred(stem(feat)) for feat, stem, pred in zip(feats, self.stems, self.pred_layers)]

class PlateDetector(nn.Module):
    def __init__(self, cfg):
        super().__init__()
        self.num_classes = cfg["num_classes"]; self.anchors = cfg["anchors"]; self.strides = cfg["strides"]; self.img_size = cfg["img_size"]
        self.backbone = MobileNetV3SmallBackbone(pretrained=cfg["pretrained_backbone"], img_size=cfg["img_size"])
        self.neck = LightFPN(self.backbone.out_channels, out_channels=96)
        self.head = DetectHead(96, 3, self.num_classes)
    def forward(self, x): return self.head(self.neck(self.backbone(x)))
    def set_backbone_trainable(self, trainable: bool):
        for p in self.backbone.parameters(): p.requires_grad = trainable

    @torch.no_grad()
    def decode_predictions(self, preds, score_thresh=0.25, nms_iou_thresh=0.5):
        device = preds[0].device
        batch_outputs = [[] for _ in range(preds[0].shape[0])]
        for level, pred in enumerate(preds):
            bs, _, h, w = pred.shape
            stride = self.strides[level]
            anchors = torch.tensor(self.anchors[level], dtype=pred.dtype, device=device)
            na = anchors.shape[0]; pred_dim = 5 + self.num_classes
            pred = pred.view(bs, na, pred_dim, h, w).permute(0, 1, 3, 4, 2).contiguous()
            yv, xv = torch.meshgrid(torch.arange(h, device=device), torch.arange(w, device=device), indexing="ij")
            grid = torch.stack((xv, yv), dim=-1).view(1, 1, h, w, 2).float()
            anchor_wh = anchors.view(1, na, 1, 1, 2)
            obj = pred[..., 4].sigmoid()
            cls_prob = pred[..., 5:].sigmoid()
            cls_score, cls_id = cls_prob.max(dim=-1)
            score = obj * cls_score
            centers = (torch.sigmoid(pred[..., 0:2]) + grid) * stride
            wh = torch.exp(pred[..., 2:4]).clamp(max=6.0) * anchor_wh
            x1y1 = centers - wh / 2; x2y2 = centers + wh / 2
            boxes = torch.cat([x1y1, x2y2], dim=-1)
            for b in range(bs):
                boxes_b = boxes[b].view(-1, 4); scores_b = score[b].view(-1); cls_b = cls_id[b].view(-1).float()
                keep = scores_b > score_thresh
                boxes_b = boxes_b[keep]; scores_b = scores_b[keep]; cls_b = cls_b[keep]
                if boxes_b.numel() == 0:
                    batch_outputs[b].append(torch.zeros((0, 6), device=device)); continue
                keep_idx = nms_xyxy(boxes_b, scores_b, iou_thresh=nms_iou_thresh)
                batch_outputs[b].append(torch.cat([boxes_b[keep_idx], scores_b[keep_idx, None], cls_b[keep_idx, None]], dim=1))
        final_outs = []
        for outs in batch_outputs:
            final_outs.append(torch.cat(outs, dim=0) if outs else torch.zeros((0, 6), device=device))
        return final_outs

def build_targets(preds, targets, anchors, strides, num_classes, device):
    bs = preds[0].shape[0]
    level_targets = []
    shapes = [(pred.shape[2], pred.shape[3]) for pred in preds]
    for level, pred in enumerate(preds):
        _, _, h, w = pred.shape; na = len(anchors[level])
        level_targets.append({
            "obj_t": torch.zeros((bs, na, h, w), device=device),
            "cls_t": torch.zeros((bs, na, h, w, num_classes), device=device),
            "box_t": torch.zeros((bs, na, h, w, 4), device=device),
            "pos_mask": torch.zeros((bs, na, h, w), device=device, dtype=torch.bool),
        })

    all_anchors = []
    for li, anc_level in enumerate(anchors):
        for ai, (aw, ah) in enumerate(anc_level):
            all_anchors.append([li, ai, aw, ah])
    all_anchors = torch.tensor(all_anchors, dtype=torch.float32, device=device)

    for b, tgt in enumerate(targets):
        gt_boxes = tgt["boxes"].to(device); gt_labels = tgt["labels"].to(device)
        if gt_boxes.numel() == 0: continue
        gt_cxcywh = xyxy_to_cxcywh(gt_boxes); gt_wh = gt_cxcywh[:, 2:4]; anchor_wh = all_anchors[:, 2:4]
        ious = wh_iou(gt_wh, anchor_wh); best_idx = ious.argmax(dim=1)
        for gi in range(gt_boxes.shape[0]):
            level_id = int(all_anchors[best_idx[gi], 0].item()); anchor_id = int(all_anchors[best_idx[gi], 1].item())
            stride = strides[level_id]; h, w = shapes[level_id]
            cx = gt_cxcywh[gi, 0] / stride; cy = gt_cxcywh[gi, 1] / stride
            gx = int(torch.clamp(torch.floor(cx), 0, w - 1)); gy = int(torch.clamp(torch.floor(cy), 0, h - 1))
            level_targets[level_id]["obj_t"][b, anchor_id, gy, gx] = 1.0
            level_targets[level_id]["box_t"][b, anchor_id, gy, gx] = gt_boxes[gi]
            level_targets[level_id]["pos_mask"][b, anchor_id, gy, gx] = True
            cls = int(gt_labels[gi].item())
            if 0 <= cls < num_classes: level_targets[level_id]["cls_t"][b, anchor_id, gy, gx, cls] = 1.0
    return level_targets

def compute_loss(preds, targets, cfg, device):
    level_targets = build_targets(preds, targets, cfg["anchors"], cfg["strides"], cfg["num_classes"], device)
    bce = nn.BCEWithLogitsLoss(reduction="none")
    total_box = torch.tensor(0.0, device=device); total_obj = torch.tensor(0.0, device=device); total_cls = torch.tensor(0.0, device=device)
    for level, pred in enumerate(preds):
        bs, _, h, w = pred.shape; anchors = torch.tensor(cfg["anchors"][level], dtype=pred.dtype, device=device)
        stride = cfg["strides"][level]; na = anchors.shape[0]; pred_dim = 5 + cfg["num_classes"]
        pred = pred.view(bs, na, pred_dim, h, w).permute(0, 1, 3, 4, 2).contiguous()
        obj_t = level_targets[level]["obj_t"]; cls_t = level_targets[level]["cls_t"]; box_t = level_targets[level]["box_t"]; pos_mask = level_targets[level]["pos_mask"]
        obj_logits = pred[..., 4]; obj_loss_all = bce(obj_logits, obj_t)
        pos_loss = obj_loss_all[pos_mask].mean() if pos_mask.any() else torch.tensor(0.0, device=device)
        neg_loss = obj_loss_all[~pos_mask].mean() if (~pos_mask).any() else torch.tensor(0.0, device=device)
        total_obj = total_obj + pos_loss + 0.25 * neg_loss
        if cfg["num_classes"] > 0 and pos_mask.any():
            total_cls = total_cls + bce(pred[..., 5:][pos_mask], cls_t[pos_mask]).mean()
        if pos_mask.any():
            yv, xv = torch.meshgrid(torch.arange(h, device=device), torch.arange(w, device=device), indexing="ij")
            grid = torch.stack((xv, yv), dim=-1).view(1, 1, h, w, 2).float(); anchor_wh = anchors.view(1, na, 1, 1, 2)
            centers = (torch.sigmoid(pred[..., 0:2]) + grid) * stride
            wh = torch.exp(pred[..., 2:4]).clamp(max=6.0) * anchor_wh
            pred_boxes = torch.empty((bs, na, h, w, 4), device=device)
            pred_boxes[..., 0:2] = centers - wh / 2; pred_boxes[..., 2:4] = centers + wh / 2
            ciou = bbox_ciou(pred_boxes[pos_mask], box_t[pos_mask]); total_box = total_box + (1.0 - ciou).mean()
    total = 5.0 * total_box + total_obj + 0.5 * total_cls
    return total, {"loss": total.detach().item(), "box": total_box.detach().item(), "obj": total_obj.detach().item(), "cls": total_cls.detach().item()}

@torch.no_grad()
def evaluate_model(model, loader, cfg, device):
    model.eval(); total_loss = 0.0; num_batches = 0; tp = 0; fp = 0; fn = 0
    for images, targets in tqdm(loader, desc="Val", leave=False):
        images = images.to(device, non_blocking=True)
        preds = model(images)
        loss, _ = compute_loss(preds, targets, cfg, device)
        total_loss += loss.item(); num_batches += 1
        dets = model.decode_predictions(preds, score_thresh=cfg["score_thresh"], nms_iou_thresh=cfg["nms_iou_thresh"])
        for i, det in enumerate(dets):
            gt_boxes = targets[i]["boxes"].to(device)
            if gt_boxes.numel() == 0 and det.numel() == 0: continue
            if gt_boxes.numel() == 0 and det.numel() > 0: fp += det.shape[0]; continue
            if gt_boxes.numel() > 0 and det.numel() == 0: fn += gt_boxes.shape[0]; continue
            pred_boxes = det[:, :4]; pred_scores = det[:, 4]; order = pred_scores.argsort(descending=True); pred_boxes = pred_boxes[order]
            matched_gt = torch.zeros(gt_boxes.shape[0], dtype=torch.bool, device=device)
            for pb in pred_boxes:
                ious = box_iou_xyxy(pb.unsqueeze(0), gt_boxes)[0]; max_iou, max_idx = ious.max(dim=0)
                if max_iou >= 0.5 and not matched_gt[max_idx]: tp += 1; matched_gt[max_idx] = True
                else: fp += 1
            fn += (~matched_gt).sum().item()
    precision = tp / max(tp + fp, 1); recall = tp / max(tp + fn, 1); f1 = 2 * precision * recall / max(precision + recall, 1e-9)
    return {"val_loss": total_loss / max(num_batches, 1), "precision": precision, "recall": recall, "f1": f1}

class EarlyStopper:
    def __init__(self, patience=10, min_delta=1e-4): self.patience = patience; self.min_delta = min_delta; self.best = -float("inf"); self.bad_epochs = 0
    def step(self, metric):
        if metric > self.best + self.min_delta: self.best = metric; self.bad_epochs = 0; return False, True
        self.bad_epochs += 1; return self.bad_epochs >= self.patience, False

def get_amp_context_and_scaler(device, use_amp=True):
    enabled = (device.startswith("cuda") and use_amp)
    @contextlib.contextmanager
    def autocast_ctx():
        if enabled:
            with torch.amp.autocast("cuda", enabled=True): yield
        else: yield
    try: scaler = torch.amp.GradScaler("cuda", enabled=enabled)
    except Exception: scaler = torch.cuda.amp.GradScaler(enabled=enabled)
    return autocast_ctx, scaler

def train_one_epoch(model, loader, optimizer, scaler, autocast_ctx, cfg, device, epoch):
    model.train(); total_loss = 0.0; num_batches = 0
    pbar = tqdm(loader, desc=f"Train {epoch}", leave=False)
    for images, targets in pbar:
        images = images.to(device, non_blocking=True); optimizer.zero_grad(set_to_none=True)
        with autocast_ctx():
            preds = model(images); loss, loss_items = compute_loss(preds, targets, cfg, device)
        scaler.scale(loss).backward(); scaler.step(optimizer); scaler.update()
        total_loss += loss.item(); num_batches += 1
        pbar.set_postfix({"loss": f"{loss_items['loss']:.4f}", "lr": f"{optimizer.param_groups[0]['lr']:.2e}"})
    return total_loss / max(num_batches, 1)

def main():
    cfg = CONFIG.copy(); seed_everything(42); ensure_dir(cfg["save_dir"])
    if cfg["device"].startswith("cuda"): torch.backends.cudnn.benchmark = True
    device = cfg["device"]; print(f"Using device: {device}")

    train_set = CCPDDetDataset(cfg["train_txt"], cfg["img_size"], augment=True, hflip_prob=cfg["hflip_prob"], color_jitter=cfg["color_jitter"])
    val_set = CCPDDetDataset(cfg["val_txt"], cfg["img_size"], augment=False, hflip_prob=0.0, color_jitter=False)
    train_loader = DataLoader(train_set, batch_size=cfg["batch_size"], shuffle=True, num_workers=cfg["num_workers"], pin_memory=device.startswith("cuda"), persistent_workers=cfg["num_workers"] > 0, collate_fn=collate_fn)
    val_loader = DataLoader(val_set, batch_size=max(1, cfg["batch_size"] // 2), shuffle=False, num_workers=cfg["num_workers"], pin_memory=device.startswith("cuda"), persistent_workers=cfg["num_workers"] > 0, collate_fn=collate_fn)

    model = PlateDetector(cfg).to(device)
    model.set_backbone_trainable(False if cfg["freeze_backbone_epochs"] > 0 else True)

    optimizer = torch.optim.AdamW([p for p in model.parameters() if p.requires_grad], lr=cfg["lr"], weight_decay=cfg["weight_decay"])
    scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode="max", factor=0.5, patience=3)
    autocast_ctx, scaler = get_amp_context_and_scaler(device, cfg["use_amp"]); stopper = EarlyStopper(cfg["early_stop_patience"], cfg["min_delta"])

    history = {"train_loss": [], "val_loss": [], "val_precision": [], "val_recall": [], "val_f1": [], "lr": []}
    best_path = os.path.join(cfg["save_dir"], "best.pt"); last_path = os.path.join(cfg["save_dir"], "last.pt"); curves_path = os.path.join(cfg["save_dir"], "training_curves.png"); csv_path = os.path.join(cfg["save_dir"], "history.csv")
    best_f1 = -1.0

    for epoch in range(1, cfg["epochs"] + 1):
        if epoch == cfg["freeze_backbone_epochs"] + 1:
            print(f"[Info] Unfreeze backbone at epoch {epoch}")
            model.set_backbone_trainable(True)
            optimizer = torch.optim.AdamW([p for p in model.parameters() if p.requires_grad], lr=cfg["lr"], weight_decay=cfg["weight_decay"])
            scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode="max", factor=0.5, patience=3)

        train_loss = train_one_epoch(model, train_loader, optimizer, scaler, autocast_ctx, cfg, device, epoch)
        metrics = evaluate_model(model, val_loader, cfg, device); scheduler.step(metrics["f1"])
        history["train_loss"].append(train_loss); history["val_loss"].append(metrics["val_loss"]); history["val_precision"].append(metrics["precision"]); history["val_recall"].append(metrics["recall"]); history["val_f1"].append(metrics["f1"]); history["lr"].append(optimizer.param_groups[0]["lr"])
        draw_curves(history, curves_path); save_history_csv(history, csv_path)
        ckpt = {"epoch": epoch, "model": model.state_dict(), "optimizer": optimizer.state_dict(), "cfg": cfg, "history": history}
        torch.save(ckpt, last_path)
        stop, improved = stopper.step(metrics["f1"])
        if improved: best_f1 = metrics["f1"]; torch.save(ckpt, best_path)
        print(f"Epoch [{epoch:03d}/{cfg['epochs']}] train_loss={train_loss:.4f} val_loss={metrics['val_loss']:.4f} P={metrics['precision']:.4f} R={metrics['recall']:.4f} F1={metrics['f1']:.4f} best_F1={best_f1:.4f} lr={optimizer.param_groups[0]['lr']:.2e}")
        if stop:
            print(f"[Early Stop] val_f1 连续 {cfg['early_stop_patience']} 轮没有提升，训练结束。")
            break

if __name__ == "__main__":
    main()
