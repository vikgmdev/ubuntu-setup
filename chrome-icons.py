#!/usr/bin/env python3
"""Generates Chrome-style SVG icons with Google profile photo badges.
Reads profile config from configs/chrome/profiles.conf.
Run standalone to refresh icons after a profile photo change."""

import os, math, base64

def chrome_icon_with_badge(color_light, color_mid, color_dark, center_color, photo_path):
    cx, cy = 64, 64
    R = 58
    r = 22

    has_photo = os.path.exists(photo_path)
    photo_b64 = ""
    if has_photo:
        with open(photo_path, "rb") as f:
            photo_b64 = base64.b64encode(f.read()).decode()

    segments = []
    for i, (angle_start, color) in enumerate([
        (90, color_light),
        (210, color_dark),
        (330, color_mid),
    ]):
        a1 = math.radians(angle_start)
        a2 = math.radians(angle_start + 120)
        swirl = math.radians(30)
        ox1 = cx + R * math.cos(a1)
        oy1 = cy - R * math.sin(a1)
        ox2 = cx + R * math.cos(a2)
        oy2 = cy - R * math.sin(a2)
        ir = r + 2
        ix2 = cx + ir * math.cos(a2)
        iy2 = cy - ir * math.sin(a2)
        sx = cx + ir * math.cos(a1 + swirl)
        sy = cy - ir * math.sin(a1 + swirl)
        segments.append(
            f'  <path d="M {sx:.1f} {sy:.1f} L {ox1:.1f} {oy1:.1f} A {R} {R} 0 0 0 {ox2:.1f} {oy2:.1f} L {ix2:.1f} {iy2:.1f} A {ir} {ir} 0 0 1 {sx:.1f} {sy:.1f} Z" fill="{color}"/>'
        )
    segments_str = "\n".join(segments)

    badge_section = ""
    clip_def = ""
    if has_photo:
        badge_cx, badge_cy = 100, 100
        badge_r = 22
        clip_def = f"""
    <clipPath id="badge-clip">
      <circle cx="100" cy="100" r="20"/>
    </clipPath>"""
        badge_section = f"""
  <circle cx="{badge_cx}" cy="{badge_cy}" r="{badge_r}" fill="white"/>
  <image x="{badge_cx - badge_r + 2}" y="{badge_cy - badge_r + 2}" width="{(badge_r - 2) * 2}" height="{(badge_r - 2) * 2}"
         clip-path="url(#badge-clip)"
         xlink:href="data:image/png;base64,{photo_b64}"/>
  <circle cx="{badge_cx}" cy="{badge_cy}" r="{badge_r - 1}" fill="none" stroke="white" stroke-width="2.5"/>"""

    return f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="128" height="128" viewBox="0 0 128 128">
  <defs>{clip_def}
  </defs>
  <circle cx="{cx}" cy="{cy}" r="{R}" fill="{color_mid}"/>
{segments_str}
  <circle cx="{cx}" cy="{cy}" r="{r}" fill="white"/>
  <circle cx="{cx}" cy="{cy}" r="{r - 5}" fill="{center_color}"/>{badge_section}
</svg>'''


def main():
    home = os.path.expanduser("~")
    script_dir = os.path.dirname(os.path.abspath(__file__))
    config_file = os.path.join(script_dir, "configs", "chrome", "profiles.conf")
    icon_dir = os.path.join(home, ".local", "share", "icons")
    os.makedirs(icon_dir, exist_ok=True)

    with open(config_file) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue

            profile_key, profile_dir, email, label, color_light, color_mid, color_dark = line.split("|")
            photo_path = os.path.join(home, ".config", profile_key, "Default", "Google Profile Picture.png")

            svg = chrome_icon_with_badge(color_light, color_mid, color_dark, color_mid, photo_path)
            out_path = os.path.join(icon_dir, f"{profile_key}.svg")
            with open(out_path, "w") as out:
                out.write(svg)

            status = "with photo" if os.path.exists(photo_path) else "no photo yet"
            print(f"  {profile_key} ({label}): {status}")


if __name__ == "__main__":
    main()
