from pathlib import Path

from PIL import Image

src = Path(__file__).resolve().parents[1] / "assets" / "branding" / "logo-icon.png"
img = Image.open(src).convert("RGBA")
w, h = img.size
side = min(w, h)
left = (w - side) // 2
top = (h - side) // 2
square = img.crop((left, top, left + side, top + side))


def save_resized(path: Path, size: int) -> None:
    out = square.resize((size, size), Image.Resampling.LANCZOS)
    path.parent.mkdir(parents=True, exist_ok=True)
    out.save(path, "PNG")
    print(f"wrote {path} ({size}x{size})")


root = Path(__file__).resolve().parents[1]
android = root / "android" / "app" / "src" / "main" / "res"
android_sizes = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
for folder, size in android_sizes.items():
    save_resized(android / folder / "ic_launcher.png", size)

ios = root / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
ios_files = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}
for name, size in ios_files.items():
    save_resized(ios / name, size)

launch_dir = root / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"
launch_specs = {
    "LaunchImage.png": (200, 80),
    "LaunchImage@2x.png": (400, 160),
    "LaunchImage@3x.png": (600, 240),
}
bg = (255, 255, 255, 255)
for name, (canvas, logo_size) in launch_specs.items():
    canvas_img = Image.new("RGBA", (canvas, canvas), bg)
    logo = square.resize((logo_size, logo_size), Image.Resampling.LANCZOS)
    x = (canvas - logo_size) // 2
    y = (canvas - logo_size) // 2
    canvas_img.alpha_composite(logo, (x, y))
    canvas_img.save(launch_dir / name, "PNG")
    print(f"wrote launch {name}")

save_resized(root / "assets" / "branding" / "app-icon-512.png", 512)
print("done")
