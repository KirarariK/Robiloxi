#!/usr/bin/env python3
"""
Procedural Blade Concord Animation Showcase clip renderer.

Honest offline stand-in when Roblox Studio is unavailable:
- Parses StyleParams from AnimationSets.lua
- Approximates KeyframeFactory.sampleJoints phases (Idle/Guard/Antici/Contact/Follow)
- Draws a 3/4 stick fighter + energy saber + Showcase HUD labels
- Cycles DEMO_CLIPS for all 32 sets (same order/holds as AnimationShowcase.lua)

Usage:
  python3 tools/render_anim_showcase_clip.py -o media/anim-showcase-clip.mp4
"""

from __future__ import annotations

import argparse
import math
import os
import re
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# --- timings mirror AnimationShowcase.clipHold + CombatConfig ---
LIGHT = {"Startup": 0.18, "Active": 0.12, "Recovery": 0.28}
HEAVY = {"Startup": 0.38, "Active": 0.16, "Recovery": 0.48}
DEMO_CLIPS = [
    "Idle",
    "StartupLight",
    "ActiveLight",
    "RecoveryLight",
    "Guard",
    "StartupHeavy",
    "ActiveHeavy",
    "RecoveryHeavy",
]
SET_GAP = 0.25

# Theme.lua
INK = (12, 14, 22)
INK_SOFT = (22, 26, 38)
ACCENT = (88, 196, 255)
ACCENT_HOT = (255, 168, 72)
SABER = (120, 210, 255)
FLOOR = (28, 32, 48)
BONE = (220, 228, 240)
LABEL_BG = (12, 14, 22, 200)


@dataclass
class Style:
    id: str
    index: int
    display_name: str
    form_id: str
    rarity: str
    anticipation: float
    swing_arc: float
    plane_bias: float
    follow_through: float
    guard_pitch: float
    idle_lean: float
    torso_twist: float
    offhand: float
    tempo: float
    double_beat: bool


def clip_hold(clip_name: str) -> float:
    if clip_name == "Idle":
        return 0.55
    if clip_name == "Guard":
        return 0.45
    if clip_name == "StartupLight":
        return LIGHT["Startup"] + 0.02
    if clip_name == "ActiveLight":
        return LIGHT["Active"] + 0.02
    if clip_name == "RecoveryLight":
        return LIGHT["Recovery"] + 0.02
    if clip_name == "StartupHeavy":
        return HEAVY["Startup"] + 0.02
    if clip_name == "ActiveHeavy":
        return HEAVY["Active"] + 0.02
    if clip_name == "RecoveryHeavy":
        return HEAVY["Recovery"] + 0.02
    return 0.4


def smoothstep(t: float) -> float:
    x = max(0.0, min(1.0, t))
    return x * x * (3.0 - 2.0 * x)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def clamp(v: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, v))


def parse_sets(lua_path: Path) -> list[Style]:
    text = lua_path.read_text(encoding="utf-8")
    # Split on table entries that have id =
    blocks = re.split(r"\n\t\{\n", text)
    sets: list[Style] = []
    for block in blocks:
        mid = re.search(r'id\s*=\s*"([^"]+)"', block)
        if not mid:
            continue
        sid = mid.group(1)
        if sid.startswith("Concord_") is False and "_Common_" not in sid and "_Rare_" not in sid and "_Epic_" not in sid and "_Legendary_" not in sid:
            # still accept all animation set ids
            pass
        name = re.search(r'displayName\s*=\s*"([^"]+)"', block)
        idx = re.search(r"index\s*=\s*(\d+)", block)
        form = re.search(r'formId\s*=\s*"([^"]+)"', block)
        rarity = re.search(r'rarity\s*=\s*"([^"]+)"', block)
        style_m = re.search(r"style\s*=\s*style\(\{([\s\S]*?)\}\)", block)
        if not (name and idx and style_m):
            continue
        body = style_m.group(1)

        def num(key: str, default: float) -> float:
            m = re.search(rf"{key}\s*=\s*(-?[0-9.]+)", body)
            return float(m.group(1)) if m else default

        double = "doubleBeat = true" in body.replace(" ", "")
        sets.append(
            Style(
                id=sid,
                index=int(idx.group(1)),
                display_name=name.group(1),
                form_id=form.group(1) if form else "Concord",
                rarity=rarity.group(1) if rarity else "Special",
                anticipation=num("anticipation", 0.85),
                swing_arc=num("swingArc", 1.15),
                plane_bias=num("planeBias", 0.45),
                follow_through=num("followThrough", 0.55),
                guard_pitch=num("guardPitch", -0.55),
                idle_lean=num("idleLean", 0.04),
                torso_twist=num("torsoTwist", 0.22),
                offhand=num("offhand", 0.35),
                tempo=num("tempo", 1.0),
                double_beat=double,
            )
        )
    sets.sort(key=lambda s: s.index)
    if len(sets) < 20:
        raise SystemExit(f"Expected ≥20 sets, parsed {len(sets)} from {lua_path}")
    return sets


def phase_for_clip(clip: str) -> tuple[str, bool]:
    heavy = "Heavy" in clip
    if clip == "Idle":
        return "Idle", False
    if clip == "Guard":
        return "Guard", False
    if clip.startswith("Startup"):
        return "Antici", heavy
    if clip.startswith("Active"):
        return "Contact", heavy
    if clip.startswith("Recovery"):
        return "Follow", heavy
    return "Idle", False


@dataclass
class Pose2D:
    # normalized angles (radians) for drawing
    torso_yaw: float
    torso_lean: float
    r_shoulder: float
    r_elbow: float
    l_shoulder: float
    l_elbow: float
    hip_shift: float
    blade_tip_bias: float  # extra tip swing


def sample_pose(style: Style, phase: str, alpha: float, heavy: bool) -> Pose2D:
    """2D projection approximating KeyframeFactory.sampleJoints style response."""
    a = clamp(alpha, 0.0, 1.0)
    ant = min(style.anticipation * (1.12 if heavy else 1.0), 1.08)
    arc = min(style.swing_arc * (1.12 if heavy else 1.0), 1.45)
    plane = style.plane_bias
    twist = style.torso_twist
    off = style.offhand
    lean = style.idle_lean
    guard = style.guard_pitch
    ft = style.follow_through

    if phase == "Idle":
        bob = math.sin(a * math.pi * 2)
        breath = math.sin(a * math.pi * 2)
        sway = math.sin(a * math.pi * 2 + 1.15)
        return Pose2D(
            torso_yaw=lean * 0.25 + sway * 0.04,
            torso_lean=lean * 0.35 + breath * 0.03,
            r_shoulder=-0.55 + bob * 0.08 + lean * 0.2,
            r_elbow=-0.9,
            l_shoulder=-0.35 - off * 0.25,
            l_elbow=-0.85,
            hip_shift=sway * 0.02,
            blade_tip_bias=bob * 0.05,
        )

    if phase == "Guard":
        g = smoothstep(a)
        return Pose2D(
            torso_yaw=-twist * 0.35 * g,
            torso_lean=0.08 * g,
            r_shoulder=lerp(-0.55, guard * 1.1 - 0.35, g),
            r_elbow=lerp(-0.9, -1.35, g),
            l_shoulder=lerp(-0.35, -0.75 - off * 0.2, g),
            l_elbow=lerp(-0.85, -1.1, g),
            hip_shift=-twist * 0.05 * g,
            blade_tip_bias=lerp(0.0, -0.35 + plane * 0.2, g),
        )

    if phase == "Antici":
        e = smoothstep(a)
        chamber = -0.9 - ant * 0.55 * plane
        yaw_back = -0.55 - ant * 0.4 * (1 - plane)
        return Pose2D(
            torso_yaw=-twist * 0.55 * ant * e,
            torso_lean=-0.12 * ant * e,
            r_shoulder=lerp(-0.55, chamber, e),
            r_elbow=lerp(-0.9, -1.45, e),
            l_shoulder=lerp(-0.35, -0.25 + off * 0.15, e),
            l_elbow=lerp(-0.85, -0.7, e),
            hip_shift=0.06 * ant * e,
            blade_tip_bias=lerp(0.0, yaw_back, e),
        )

    if phase == "Contact":
        e = smoothstep(a)
        # swing through contact; doubleBeat = second peak
        beat = e
        if style.double_beat:
            beat = smoothstep(a * 2.0) if a < 0.5 else smoothstep((a - 0.5) * 2.0)
        swing = -0.2 + arc * 1.35 * beat
        vert = plane * 0.55
        return Pose2D(
            torso_yaw=twist * 0.65 * beat,
            torso_lean=0.1 * beat,
            r_shoulder=lerp(-1.2, swing - vert, beat),
            r_elbow=lerp(-1.4, -0.55, beat),
            l_shoulder=lerp(-0.3, -0.55 - off * 0.25, beat),
            l_elbow=lerp(-0.7, -1.0, beat),
            hip_shift=-0.08 * beat,
            blade_tip_bias=lerp(-0.5, 0.95 * arc, beat) + (0.25 if style.double_beat and a > 0.5 else 0.0),
        )

    # Follow / recovery
    e = smoothstep(a)
    return Pose2D(
        torso_yaw=twist * 0.25 * (1 - e) * ft,
        torso_lean=0.05 * (1 - e),
        r_shoulder=lerp(0.55, -0.55 + ft * 0.15, e),
        r_elbow=lerp(-0.6, -0.9, e),
        l_shoulder=lerp(-0.6, -0.35, e),
        l_elbow=lerp(-1.0, -0.85, e),
        hip_shift=lerp(-0.06, 0.0, e),
        blade_tip_bias=lerp(0.7 * arc * ft, 0.05, e),
    )


def rot(p: tuple[float, float], origin: tuple[float, float], ang: float) -> tuple[float, float]:
    s, c = math.sin(ang), math.cos(ang)
    x, y = p[0] - origin[0], p[1] - origin[1]
    return origin[0] + c * x - s * y, origin[1] + s * x + c * y


def limb(
    draw: ImageDraw.ImageDraw,
    a: tuple[float, float],
    length: float,
    ang: float,
    width: int,
    color: tuple[int, int, int],
) -> tuple[float, float]:
    b = (a[0] + math.sin(ang) * length, a[1] + math.cos(ang) * length)
    draw.line([a, b], fill=color, width=width)
    return b


def form_color(form: str) -> tuple[int, int, int]:
    return {
        "Astra": (255, 196, 90),
        "Duelant": (120, 190, 255),
        "Aegis": (110, 210, 160),
        "Zephyr": (180, 160, 255),
        "Concord": ACCENT,
    }.get(form, ACCENT)


def draw_frame(
    size: tuple[int, int],
    style: Style,
    clip: str,
    alpha: float,
    set_i: int,
    total: int,
    t_global: float,
    font_lg,
    font_md,
    font_sm,
    trail: list[tuple[float, float]],
) -> Image.Image:
    w, h = size
    img = Image.new("RGB", size, INK)
    draw = ImageDraw.Draw(img)

    # atmosphere gradient
    for y in range(h):
        k = y / h
        r = int(INK[0] + (INK_SOFT[0] - INK[0]) * k * 0.7)
        g = int(INK[1] + (36 - INK[1]) * k * 0.5)
        b = int(INK[2] + (58 - INK[2]) * k * 0.6)
        draw.line([(0, y), (w, y)], fill=(r, g, b))

    # duel ring floor ellipse
    cx, cy = w * 0.52, h * 0.72
    draw.ellipse([cx - 260, cy - 48, cx + 260, cy + 48], outline=FLOOR, width=3)
    draw.ellipse([cx - 180, cy - 30, cx + 180, cy + 30], outline=(40, 48, 70), width=2)

    phase, heavy = phase_for_clip(clip)
    pose = sample_pose(style, phase, alpha, heavy)

    # root (slight 3/4 offset)
    root = (cx + pose.hip_shift * 140, cy - 18)
    pelvis = (root[0], root[1] - 20)
    chest = (
        pelvis[0] + math.sin(pose.torso_yaw) * 18,
        pelvis[1] - 95 + pose.torso_lean * 40,
    )
    head = (chest[0] + math.sin(pose.torso_yaw) * 8, chest[1] - 52)

    # legs
    limb(draw, pelvis, 70, 0.22 + pose.hip_shift, 7, BONE)
    limb(draw, pelvis, 70, -0.22 - pose.hip_shift, 7, BONE)
    # torso
    draw.line([pelvis, chest], fill=BONE, width=10)
    draw.ellipse([head[0] - 16, head[1] - 18, head[0] + 16, head[1] + 18], outline=BONE, width=3)

    # arms
    r_elbow_p = limb(draw, chest, 48, pose.r_shoulder, 7, BONE)
    r_hand = limb(draw, r_elbow_p, 42, pose.r_shoulder + pose.r_elbow * 0.55, 6, BONE)
    l_elbow_p = limb(draw, chest, 46, pose.l_shoulder + math.pi * 0.05, 6, (190, 200, 215))
    limb(draw, l_elbow_p, 40, pose.l_shoulder + pose.l_elbow * 0.5, 5, (190, 200, 215))

    # energy saber from right hand
    blade_ang = pose.r_shoulder + pose.r_elbow * 0.35 + pose.blade_tip_bias
    blade_len = 155 if not heavy else 170
    tip = (r_hand[0] + math.sin(blade_ang) * blade_len, r_hand[1] + math.cos(blade_ang) * blade_len)
    glow = form_color(style.form_id)
    # trail during Active
    if phase == "Contact":
        trail.append(tip)
        if len(trail) > 14:
            del trail[:-14]
    else:
        trail.clear()
    if len(trail) >= 2:
        for i in range(1, len(trail)):
            alpha_t = i / len(trail)
            col = (
                int(glow[0] * alpha_t),
                int(glow[1] * alpha_t),
                int(glow[2] * alpha_t),
            )
            draw.line([trail[i - 1], trail[i]], fill=col, width=max(2, int(10 * alpha_t)))
    # blade core
    draw.line([r_hand, tip], fill=glow, width=8)
    draw.line([r_hand, tip], fill=(240, 250, 255), width=3)
    # hilt
    hilt_end = (r_hand[0] - math.sin(blade_ang) * 18, r_hand[1] - math.cos(blade_ang) * 18)
    draw.line([hilt_end, r_hand], fill=(90, 95, 110), width=6)

    # Billboard-like label above head
    bill_w, bill_h = 340, 64
    bx, by = head[0] - bill_w / 2, head[1] - 78
    draw.rounded_rectangle([bx, by, bx + bill_w, by + bill_h], radius=10, fill=INK, outline=ACCENT, width=2)
    title = f"{set_i} / {total}  ·  {style.display_name}"
    sub = f"{style.id}  ·  {clip}"
    draw.text((bx + 12, by + 8), title[:48], fill=(235, 240, 250), font=font_md)
    draw.text((bx + 12, by + 34), sub[:52], fill=ACCENT, font=font_sm)

    # HUD banner
    draw.rounded_rectangle([24, 22, w - 24, 92], radius=12, fill=INK_SOFT, outline=ACCENT, width=2)
    draw.text((40, 32), "Blade Concord — SHOWCASE", fill=ACCENT, font=font_lg)
    status = f"Set {set_i}/{total} · {style.display_name} · clip {clip} · P quitter"
    draw.text((40, 62), status[:90], fill=(200, 210, 225), font=font_sm)

    # watermark honesty
    draw.text(
        (24, h - 36),
        "PROCEDURAL PREVIEW (Studio unavailable) — StyleParams → 2D pose approx",
        fill=(120, 130, 150),
        font=font_sm,
    )
    # progress bar
    prog = ((set_i - 1) + alpha_clip_progress(clip, alpha)) / total
    draw.rectangle([24, h - 18, w - 24, h - 10], fill=(30, 34, 48))
    draw.rectangle([24, h - 18, 24 + int((w - 48) * prog), h - 10], fill=ACCENT_HOT)

    # phase chip
    chip = f"{phase}{' · HEAVY' if heavy else ''}"
    draw.rounded_rectangle([w - 210, 110, w - 24, 142], radius=8, fill=INK, outline=glow, width=1)
    draw.text((w - 198, 116), chip, fill=glow, font=font_sm)

    return img


def alpha_clip_progress(clip: str, alpha: float) -> float:
    # rough weight inside set for progress bar
    weights = {
        "Idle": 0.18,
        "StartupLight": 0.07,
        "ActiveLight": 0.05,
        "RecoveryLight": 0.10,
        "Guard": 0.15,
        "StartupHeavy": 0.13,
        "ActiveHeavy": 0.06,
        "RecoveryHeavy": 0.16,
    }
    order = DEMO_CLIPS
    done = sum(weights.get(c, 0.1) for c in order[: order.index(clip)])
    return done + weights.get(clip, 0.1) * alpha


def load_fonts():
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
    ]
    path = next((p for p in candidates if os.path.exists(p)), None)
    if path:
        return (
            ImageFont.truetype(path, 28),
            ImageFont.truetype(path, 18),
            ImageFont.truetype(path, 14),
        )
    return ImageFont.load_default(), ImageFont.load_default(), ImageFont.load_default()


def render(out_path: Path, fps: int, width: int, height: int, max_sets: int | None) -> dict:
    repo = Path(__file__).resolve().parents[1]
    sets = parse_sets(repo / "src/ReplicatedStorage/BladeConcord/Animation/AnimationSets.lua")
    if max_sets:
        sets = sets[:max_sets]
    total = len(sets)
    fonts = load_fonts()

    # duration estimate
    per_set = sum(clip_hold(c) for c in DEMO_CLIPS) + SET_GAP
    duration = per_set * total

    frame_dir = Path(tempfile.mkdtemp(prefix="bc-anim-"))
    trail: list[tuple[float, float]] = []
    frame_i = 0
    t_global = 0.0

    try:
        for si, style in enumerate(sets, start=1):
            for clip in DEMO_CLIPS:
                hold = clip_hold(clip)
                n = max(1, int(round(hold * fps)))
                for fi in range(n):
                    alpha = (fi + 0.5) / n
                    img = draw_frame(
                        (width, height),
                        style,
                        clip,
                        alpha,
                        si,
                        total,
                        t_global,
                        fonts[0],
                        fonts[1],
                        fonts[2],
                        trail,
                    )
                    img.save(frame_dir / f"f{frame_i:06d}.png")
                    frame_i += 1
                    t_global += 1.0 / fps
            # gap: hold last pose briefly with empty labels progression
            n_gap = max(1, int(round(SET_GAP * fps)))
            for _ in range(n_gap):
                img = draw_frame(
                    (width, height),
                    style,
                    "Idle",
                    0.0,
                    si,
                    total,
                    t_global,
                    fonts[0],
                    fonts[1],
                    fonts[2],
                    trail,
                )
                img.save(frame_dir / f"f{frame_i:06d}.png")
                frame_i += 1
                t_global += 1.0 / fps

        out_path.parent.mkdir(parents=True, exist_ok=True)
        cmd = [
            "ffmpeg",
            "-y",
            "-framerate",
            str(fps),
            "-i",
            str(frame_dir / "f%06d.png"),
            "-c:v",
            "libx264",
            "-pix_fmt",
            "yuv420p",
            "-crf",
            "20",
            "-movflags",
            "+faststart",
            str(out_path),
        ]
        subprocess.run(cmd, check=True, capture_output=True)
    finally:
        shutil.rmtree(frame_dir, ignore_errors=True)

    actual = frame_i / fps
    size = out_path.stat().st_size if out_path.exists() else 0
    return {
        "frames": frame_i,
        "duration_s": actual,
        "planned_s": duration,
        "sets": total,
        "bytes": size,
        "path": str(out_path),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-o", "--output", type=Path, required=True)
    ap.add_argument("--fps", type=int, default=20)
    ap.add_argument("--width", type=int, default=1280)
    ap.add_argument("--height", type=int, default=720)
    ap.add_argument("--max-sets", type=int, default=None, help="Debug: limit set count")
    args = ap.parse_args()
    info = render(args.output, args.fps, args.width, args.height, args.max_sets)
    print(
        f"OK {info['path']} | {info['sets']} sets | {info['frames']} frames | "
        f"{info['duration_s']:.1f}s | {info['bytes']} bytes"
    )


if __name__ == "__main__":
    main()
