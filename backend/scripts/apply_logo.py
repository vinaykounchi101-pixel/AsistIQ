import os
import shutil
from PIL import Image

def main():
    src_img_path = r"C:\Users\Vinay\.gemini\antigravity-ide\brain\3c42aab3-9aea-4229-a556-db9e30dafb54\.user_uploaded\media_1790073541924.png"
    if not os.path.exists(src_img_path):
        print(f"Error: Source image not found at {src_img_path}")
        return

    img = Image.open(src_img_path).convert("RGBA")

    # Target folders
    os.makedirs("client/assets/images", exist_ok=True)
    os.makedirs("client/assets/icons", exist_ok=True)
    os.makedirs("client/web/icons", exist_ok=True)

    # 1. Main Flutter UI asset logos
    img.save("client/assets/images/logo.png", "PNG")
    img.save("client/assets/icons/logo.png", "PNG")
    print("Saved client/assets/images/logo.png")

    # 2. Web Favicon & Icons
    img.resize((32, 32), Image.Resampling.LANCZOS).save("client/web/favicon.png", "PNG")
    img.resize((192, 192), Image.Resampling.LANCZOS).save("client/web/icons/Icon-192.png", "PNG")
    img.resize((512, 512), Image.Resampling.LANCZOS).save("client/web/icons/Icon-512.png", "PNG")
    img.resize((192, 192), Image.Resampling.LANCZOS).save("client/web/icons/Icon-maskable-192.png", "PNG")
    img.resize((512, 512), Image.Resampling.LANCZOS).save("client/web/icons/Icon-maskable-512.png", "PNG")
    print("Saved Web icons and favicon")

    # 3. Windows app icon (.ico)
    ico_path = "client/windows/runner/resources/app_icon.ico"
    if os.path.exists(os.path.dirname(ico_path)):
        img.resize((256, 256), Image.Resampling.LANCZOS).save(
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
            img.resize(size, Image.Resampling.LANCZOS).save(os.path.join(folder, "ic_launcher.png"), "PNG")
            print(f"Saved Android {dirname}/ic_launcher.png")

    print("All branding assets updated successfully!")

if __name__ == "__main__":
    main()
