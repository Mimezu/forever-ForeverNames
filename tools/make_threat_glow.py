"""Draw the soft halo Forever Names puts around an enemy's health bar when it
attacks someone else. White on transparency, tinted in the addon; the bar's own
area stays faint so the health still reads through.
"""
import os
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'Media', 'threat_glow.tga')
W, H = 512, 128          # drawn large, saved at 256 x 64
BAR = (96, 48, 416, 80)  # the health bar's place inside the texture


def main():
    halo = Image.new('L', (W, H), 0)
    ImageDraw.Draw(halo).rounded_rectangle(BAR, radius=16, fill=255)
    halo = halo.filter(ImageFilter.GaussianBlur(22))
    # Stronger right at the bar's edge, faint over the bar itself.
    inner = Image.new('L', (W, H), 0)
    ImageDraw.Draw(inner).rounded_rectangle((BAR[0] + 10, BAR[1] + 6, BAR[2] - 10, BAR[3] - 6), radius=10, fill=170)
    inner = inner.filter(ImageFilter.GaussianBlur(6))
    alpha = Image.eval(Image.merge('LA', (halo, inner)).split()[0], lambda v: min(255, int(v * 1.6)))
    alpha = Image.composite(Image.eval(alpha, lambda v: int(v * 0.35)), alpha, inner)
    img = Image.merge('RGBA', (Image.new('L', (W, H), 255),) * 3 + (alpha,))
    img.resize((256, 64), Image.LANCZOS).save(OUT)
    print('wrote', OUT)


main()
