#!/usr/bin/env python3
import sys
import cv2
import numpy as np

# Allowed scheme types
SCHEMES = [
    "scheme-content",
    "scheme-expressive",
    "scheme-fidelity",
    "scheme-fruit-salad",
    "scheme-monochrome",
    "scheme-neutral",
    "scheme-rainbow",
    "scheme-tonal-spot"
]

def image_colorfulness(image):
    # Based on Hasler and Süsstrunk's colorfulness metric
    (B, G, R) = cv2.split(image.astype("float"))
    rg = np.absolute(R - G)
    yb = np.absolute(0.5 * (R + G) - B)
    std_rg = np.std(rg)
    std_yb = np.std(yb)
    mean_rg = np.mean(rg)
    mean_yb = np.mean(yb)
    colorfulness = np.sqrt(std_rg ** 2 + std_yb ** 2) + (0.3 * np.sqrt(mean_rg ** 2 + mean_yb ** 2))
    return colorfulness

def pick_scheme(colorfulness, mean_sat=0.0, p90_sat=0.0):
    # Truly achromatic / monochrome / black & white / dark grayscale:
    # Extremely low saturation across almost all pixels.
    if mean_sat < 18 or (colorfulness < 12 and p90_sat < 30):
        return "scheme-monochrome"
    # Low colorfulness or muted tones, but has some noticeable saturation
    elif (colorfulness < 24 and mean_sat < 40) or mean_sat < 30:
        return "scheme-neutral"
    # High colorfulness
    elif colorfulness > 55:
        return "scheme-expressive"
    else:
        return "scheme-tonal-spot"

def load_and_resize_image(img_path, max_dim=128):
    img = cv2.imread(img_path)
    if img is None:
        return None
    h, w = img.shape[:2]
    if max(h, w) > max_dim:
        scale = max_dim / max(h, w)
        img = cv2.resize(img, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)
    return img

def main():
    colorfulness_mode = False
    args = sys.argv[1:]
    if '--colorfulness' in args:
        colorfulness_mode = True
        args.remove('--colorfulness')
    if len(args) < 1:
        print("scheme-tonal-spot")
        sys.exit(1)
    img_path = args[0]
    img = load_and_resize_image(img_path)
    if img is None:
        print("scheme-tonal-spot")
        sys.exit(1)
    colorfulness = image_colorfulness(img)
    if colorfulness_mode:
        print(f"{colorfulness}")
    else:
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
        mean_sat = float(np.mean(hsv[:, :, 1]))
        p90_sat = float(np.percentile(hsv[:, :, 1], 90))
        scheme = pick_scheme(colorfulness, mean_sat, p90_sat)
        print(scheme)

if __name__ == "__main__":
    main()
