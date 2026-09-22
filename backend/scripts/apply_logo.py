import os
from PIL import Image

def process_logo():
    src_path = r"C:\Users\Vinay\.gemini\antigravity-ide\brain\3c42aab3-9aea-4229-a556-db9e30dafb54\.user_uploaded\media_1790075798774.png"
    if not os.path.exists(src_path):
        print(f"File not found: {src_path}")
        return

    img = Image.open(src_path).convert("RGBA")
    width, height = img.size
    pixels = img.load()

    # Create transparent image
    out_img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    out_pixels = out_img.load()

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            # Detect background (cream / grid lines): R > 200 and G > 200 and B > 190 and small color saturation difference
            is_bg = (r > 200 and g > 200 and b > 190) or (r > 215 and g > 215 and abs(r - g) < 25 and abs(g - b) < 25)
            if is_bg:
                out_pixels[x, y] = (0, 0, 0, 0)
            else:
                out_pixels[x, y] = (r, g, b, 255)

    # Crop to bounding box of non-transparent pixels
    bbox = out_img.getbbox()
    if bbox:
        cropped = out_img.crop(bbox)
    else:
        cropped = out_img

    # Create square canvas with padding
    max_dim = max(cropped.width, cropped.height)
    padding = int(max_dim * 0.15)
    canvas_size = max_dim + padding * 2
    square_img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    
    offset_x = (canvas_size - cropped.width) // 2
    offset_y = (canvas_size - cropped.height) // 2
    square_img.paste(cropped, (offset_x, offset_y), cropped)

    # Target folders
    os.makedirs("client/assets/images", exist_ok=True)
    os.makedirs("client/assets/icons", exist_ok=True)
    os.makedirs("client/web/icons", exist_ok=True)

    # 1. Main Flutter UI asset logos
    square_img.save("client/assets/images/logo.png", "PNG")
    square_img.save("client/assets/icons/logo.png", "PNG")
    print("Saved client/assets/images/logo.png")

    # 2. Web Favicon & Icons
    square_img.resize((32, 32), Image.Resampling.LANCZOS).save("client/web/favicon.png", "PNG")
    square_img.resize((192, 192), Image.Resampling.LANCZOS).save("client/web/icons/Icon-192.png", "PNG")
    square_img.resize((512, 512), Image.Resampling.LANCZOS).save("client/web/icons/Icon-512.png", "PNG")
    square_img.resize((192, 192), Image.Resampling.LANCZOS).save("client/web/icons/Icon-maskable-192.png", "PNG")
    square_img.resize((512, 512), Image.Resampling.LANCZOS).save("client/web/icons/Icon-maskable-512.png", "PNG")
    print("Saved Web icons and favicon")

    # 3. Windows app icon (.ico)
    ico_path = "client/windows/runner/resources/app_icon.ico"
    if os.path.exists(os.path.dirname(ico_path)):
        square_img.resize((256, 256), Image.Resampling.LANCZOS).save(
            ico_path,
            format="ICO",
            sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
        )
        print("Saved Windows app_icon.ico")

    # 4. Android launcher icons
    mipmap_dirs = {
        "mipmap-mdpi": (48, 48),
        "mipmap-hdpi": (72, 72),
        "mipmap-xhdpi": (96, 96),
        "mipmap-xxhdpi": (144, 144),
        "mipmap-xxxhdpi": (192, 192),
    }
    for dirname, size in mipmap_dirs.items():
        folder = os.path.join("client/android/app/src/main/res", dirname)
        if os.path.exists(folder):
            square_img.resize(size, Image.Resampling.LANCZOS).save(os.path.join(folder, "ic_launcher.png"), "PNG")
            print(f"Saved Android {dirname}/ic_launcher.png")

    print("All branding assets updated successfully!")

if __name__ == "__main__":
    process_logo()
