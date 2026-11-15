"""Draw simple single-color glyph icons for Forever Names.

White shapes on transparency; the addon tints them with SetVertexColor so they
read like font glyphs in any color. Drawn at 512 px, downsampled to 64 px.
"""
import math
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'Media', 'Glyphs')
S = 512
W = (255, 255, 255, 255)


def canvas():
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def star_points(cx, cy, outer, inner, n, rot=-90):
    pts = []
    for i in range(n * 2):
        r = outer if i % 2 == 0 else inner
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def heart(d):
    # Two circles plus a point, the classic heart silhouette.
    r = 118
    d.ellipse((136 - r + 0, 190 - r, 136 + r, 190 + r), fill=W)
    d.ellipse((376 - r, 190 - r, 376 + r, 190 + r), fill=W)
    d.polygon([(30, 236), (482, 236), (256, 470)], fill=W)
    d.polygon([(22, 200), (490, 200), (256, 470)], fill=W)


def star(d):
    d.polygon(star_points(256, 272, 240, 100, 5), fill=W)


def sparkle(d):
    d.polygon(star_points(256, 256, 240, 58, 4, rot=-90), fill=W)


def diamond(d):
    d.polygon([(256, 24), (440, 256), (256, 488), (72, 256)], fill=W)


def dot(d):
    d.ellipse((96, 96, 416, 416), fill=W)


def ring(d):
    d.ellipse((64, 64, 448, 448), fill=W)
    d.ellipse((150, 150, 362, 362), fill=(0, 0, 0, 0))


def crown(d):
    d.polygon([(40, 400), (40, 150), (150, 270), (256, 90), (362, 270), (472, 150), (472, 400)], fill=W)
    d.rectangle((40, 420, 472, 468), fill=W)


def shield(d):
    d.polygon([(256, 30), (450, 90), (430, 290), (256, 486), (82, 290), (62, 90)], fill=W)


def person(d):
    d.ellipse((176, 40, 336, 200), fill=W)
    d.pieslice((96, 230, 416, 560), 180, 360, fill=W)


def party(d):
    # Two figures: one in front, one behind.
    d.ellipse((252, 70, 392, 210), fill=W)
    d.pieslice((190, 236, 454, 520), 180, 360, fill=W)
    d.ellipse((96, 110, 236, 250), fill=W)
    d.pieslice((34, 276, 298, 560), 180, 360, fill=W)


def flower(d):
    for i in range(5):
        a = math.radians(-90 + i * 72)
        cx, cy = 256 + 130 * math.cos(a), 256 + 130 * math.sin(a)
        d.ellipse((cx - 104, cy - 104, cx + 104, cy + 104), fill=W)
    d.ellipse((196, 196, 316, 316), fill=(0, 0, 0, 0))


def moon(d):
    d.ellipse((50, 40, 470, 460), fill=W)
    d.ellipse((170, 10, 540, 380), fill=(0, 0, 0, 0))


def sun(d):
    d.ellipse((150, 150, 362, 362), fill=W)
    for i in range(8):
        a = math.radians(i * 45)
        tip = (256 + 240 * math.cos(a), 256 + 240 * math.sin(a))
        left = (256 + 150 * math.cos(a - 0.28), 256 + 150 * math.sin(a - 0.28))
        right = (256 + 150 * math.cos(a + 0.28), 256 + 150 * math.sin(a + 0.28))
        d.polygon([tip, left, right], fill=W)


def leaf(d):
    # Lens (intersection of two circles), a thin vein, a short stem; tilted.
    a = Image.new('L', (S, S), 0); ImageDraw.Draw(a).ellipse((-90, -20, 400, 470), fill=255)
    b = Image.new('L', (S, S), 0); ImageDraw.Draw(b).ellipse((112, -20, 602, 470), fill=255)
    from PIL import ImageChops
    mask = ImageChops.multiply(a, b)
    g = ImageDraw.Draw(mask)
    g.line([(256, 70), (256, 400)], fill=0, width=18)
    g.rectangle((246, 400, 266, 500), fill=255)
    img = Image.new('RGBA', (S, S), (255, 255, 255, 0))
    img.putalpha(mask)
    return img.rotate(-35, resample=Image.BICUBIC, center=(256, 256))


def flag(d):
    d.rectangle((90, 40, 130, 480), fill=W)
    d.polygon([(130, 50), (440, 130), (130, 250)], fill=W)


def check(d):
    d.line([(70, 270), (200, 400), (450, 110)], fill=W, width=86, joint='curve')


def note(d):
    d.ellipse((70, 330, 250, 470), fill=W)
    d.rectangle((210, 60, 250, 400), fill=W)
    d.polygon([(250, 60), (430, 130), (430, 200), (250, 130)], fill=W)


def teardrop(cx, cy, r, tip_y, lean, steps=40):
    """Round bottom, curved sides meeting at a leaning tip (y grows down)."""
    def bezier(p0, p1, p2, n):
        return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
                 (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1])
                for t in (i / n for i in range(n + 1))]
    tip = (cx + lean, tip_y)
    height = cy - tip_y
    right = bezier((cx + r, cy), (cx + r * 1.05, cy - height * 0.55), tip, steps)
    left = bezier(tip, (cx - r * 0.85, cy - height * 0.4), (cx - r, cy), steps)
    bottom = [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in range(180, -1, -6)]
    return right + left + bottom


def fire(d):
    # A main flame with two smaller tongues, and a hollow core.
    d.polygon(teardrop(262, 340, 150, 14, 30), fill=W)
    d.polygon(teardrop(160, 378, 92, 150, -46), fill=W)
    d.polygon(teardrop(356, 384, 86, 176, 40), fill=W)
    d.polygon(teardrop(254, 404, 72, 236, -14), fill=(0, 0, 0, 0))


def swords(d):
    # Two blades crossed at the middle; each has a guard and a pommel.
    def sword():
        img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        g = ImageDraw.Draw(img)
        g.polygon([(256, 20), (286, 70), (286, 360), (226, 360), (226, 70)], fill=W)   # blade and tip
        g.rounded_rectangle((170, 356, 342, 392), radius=14, fill=W)                  # guard
        g.rectangle((240, 392, 272, 452), fill=W)                                     # grip
        g.ellipse((226, 444, 286, 504), fill=W)                                        # pommel
        return img
    left = sword().rotate(40, resample=Image.BICUBIC, center=(256, 256))
    right = sword().rotate(-40, resample=Image.BICUBIC, center=(256, 256))
    left.alpha_composite(right)
    return left


def exclaim(d):
    # A bold exclamation mark: a bar that narrows toward the bottom, then a dot.
    d.polygon([(176, 90), (336, 90), (292, 340), (220, 340)], fill=W)
    d.ellipse((176, 10, 336, 170), fill=W)
    d.ellipse((196, 382, 316, 502), fill=W)


GLYPHS = {
    'heart': heart, 'star': star, 'sparkle': sparkle, 'diamond': diamond, 'dot': dot, 'ring': ring,
    'crown': crown, 'shield': shield, 'person': person, 'party': party, 'flower': flower, 'moon': moon,
    'sun': sun, 'leaf': leaf, 'flag': flag, 'check': check, 'note': note, 'fire': fire, 'swords': swords,
    'exclaim': exclaim,
}


# Trainer icons (1.20.0): one per profession, shaped after its WoW icon, and a
# book for class trainers. Not in the relationship glyph picker.
def rotated(draw_fn, angle):
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(img))
    return img.rotate(angle, resample=Image.BICUBIC, center=(256, 256))


def anvil(d):
    # Blacksmithing: an anvil with its horn, and a hammer above.
    d.polygon([(40, 250), (150, 250), (180, 230), (470, 230), (470, 300), (380, 300),
               (330, 360), (180, 360), (150, 300), (110, 300)], fill=W)
    d.rectangle((210, 360, 300, 410), fill=W)
    d.rounded_rectangle((140, 410, 370, 470), radius=10, fill=W)
    d.rounded_rectangle((250, 40, 420, 120), radius=16, fill=W)    # hammer head
    d.rectangle((150, 66, 260, 94), fill=W)                      # handle


def flask(d):
    # Alchemy: a round-bottom flask, its liquid line cut out.
    d.rectangle((200, 40, 312, 76), fill=W)                      # lip
    d.rectangle((222, 76, 290, 200), fill=W)                     # neck
    d.ellipse((96, 160, 416, 480), fill=W)
    d.line([(120, 300), (392, 300)], fill=(0, 0, 0, 0), width=16)


def wand(d):
    # Enchanting: a rod with a four-point spark at its tip.
    def rod(g):
        g.rounded_rectangle((232, 200, 280, 500), radius=20, fill=W)
    img = rotated(rod, -40)
    g = ImageDraw.Draw(img)
    g.polygon(star_points(330, 170, 160, 40, 4), fill=W)
    return img


def gear(d):
    # Engineering: a cog.
    teeth = 9
    pts = []
    for i in range(teeth * 4):
        a = math.radians(i * 360 / (teeth * 4))
        r = 230 if (i % 4) in (1, 2) else 170
        pts.append((256 + r * math.cos(a), 256 + r * math.sin(a)))
    d.polygon(pts, fill=W)
    d.ellipse((186, 186, 326, 326), fill=(0, 0, 0, 0))


def pick(d):
    # Mining: a pickaxe, its curved head across the handle.
    def tool(g):
        g.rounded_rectangle((230, 120, 282, 500), radius=20, fill=W)
        g.chord((30, 70, 482, 330), 195, 345, fill=W)
        g.chord((70, 150, 442, 360), 195, 345, fill=(0, 0, 0, 0))
        g.rounded_rectangle((206, 100, 306, 170), radius=16, fill=W)
    return rotated(tool, 30)


def herb(d):
    # Herbalism: a sprig with three leaves.
    d.line([(256, 490), (256, 150)], fill=W, width=30)
    for cx, cy, angle in ((256, 120, 0), (170, 250, 40), (342, 250, -40), (190, 380, 40), (322, 380, -40)):
        leaf_img = Image.new('L', (S, S), 0)
        ImageDraw.Draw(leaf_img).ellipse((cx - 50, cy - 95, cx + 50, cy + 95), fill=255)
        leaf_img = leaf_img.rotate(angle, resample=Image.BICUBIC, center=(cx, cy + 60))
        d.bitmap((0, 0), leaf_img, fill=W)


def knife(d):
    # Skinning: a skinning knife with a curved belly.
    def tool(g):
        g.polygon([(226, 290), (196, 200), (206, 120), (256, 56), (306, 30), (290, 130), (286, 290)], fill=W)
        g.rounded_rectangle((186, 280, 326, 316), radius=12, fill=W)       # guard
        g.rounded_rectangle((226, 316, 286, 490), radius=22, fill=W)       # grip
    return rotated(tool, -30)


def hide(d):
    # Leatherworking: a stretched hide.
    d.polygon([(110, 60), (200, 110), (312, 110), (402, 60), (380, 190), (450, 260), (380, 330),
               (402, 452), (312, 402), (200, 402), (110, 452), (132, 330), (62, 260), (132, 190)], fill=W)


def spool(d):
    # Tailoring: a spool of thread and a needle.
    d.rounded_rectangle((90, 60, 370, 110), radius=16, fill=W)
    d.rounded_rectangle((90, 402, 370, 452), radius=16, fill=W)
    d.rectangle((130, 110, 330, 402), fill=W)
    for y in range(140, 400, 44):
        d.line([(130, y), (330, y + 20)], fill=(0, 0, 0, 0), width=8)
    d.polygon([(420, 40), (446, 40), (446, 420), (433, 480), (420, 420)], fill=W)
    d.ellipse((424, 60, 442, 110), fill=(0, 0, 0, 0))


def cross(d):
    # First Aid: a cross.
    d.rounded_rectangle((196, 60, 316, 452), radius=24, fill=W)
    d.rounded_rectangle((60, 196, 452, 316), radius=24, fill=W)


def hook(d):
    # Fishing: a hook with its barb.
    d.ellipse((222, 26, 290, 94), fill=W)
    d.ellipse((240, 44, 272, 76), fill=(0, 0, 0, 0))
    d.rectangle((240, 90, 272, 340), fill=W)
    d.arc((110, 220, 402, 480), 0, 180, fill=W, width=34)
    d.rectangle((110, 290, 144, 352), fill=W)
    d.polygon([(127, 210), (84, 300), (170, 300)], fill=W)


def pot(d):
    # Cooking: a pot with a lid and handles.
    d.rounded_rectangle((90, 200, 422, 440), radius=40, fill=W)
    d.rounded_rectangle((70, 160, 442, 200), radius=14, fill=W)
    d.ellipse((226, 100, 286, 160), fill=W)
    d.rounded_rectangle((20, 240, 100, 280), radius=16, fill=W)
    d.rounded_rectangle((412, 240, 492, 280), radius=16, fill=W)


def gem(d):
    # Jewelcrafting: a cut gem.
    d.polygon([(130, 90), (382, 90), (480, 200), (256, 470), (32, 200)], fill=W)
    d.line([(32, 200), (480, 200)], fill=(0, 0, 0, 0), width=14)
    d.line([(190, 96), (150, 200), (256, 460)], fill=(0, 0, 0, 0), width=12)
    d.line([(322, 96), (362, 200), (256, 460)], fill=(0, 0, 0, 0), width=12)


def quill(d):
    # Inscription: a feather quill.
    def feather(g):
        g.ellipse((176, 20, 336, 400), fill=W)
        g.line([(256, 60), (256, 500)], fill=(0, 0, 0, 0), width=14)
        g.polygon([(244, 400), (268, 400), (256, 500)], fill=W)
    return rotated(feather, -35)


def book(d):
    # Class trainer: an open book.
    d.polygon([(30, 110), (240, 140), (240, 440), (30, 410)], fill=W)
    d.polygon([(482, 110), (272, 140), (272, 440), (482, 410)], fill=W)
    for y in (200, 260, 320):
        d.line([(70, y - 12), (210, y + 8)], fill=(0, 0, 0, 0), width=14)
        d.line([(442, y - 12), (302, y + 8)], fill=(0, 0, 0, 0), width=14)


GLYPHS.update({
    'trade_anvil': anvil, 'trade_flask': flask, 'trade_wand': wand, 'trade_gear': gear,
    'trade_pick': pick, 'trade_herb': herb, 'trade_knife': knife, 'trade_hide': hide,
    'trade_spool': spool, 'trade_cross': cross, 'trade_hook': hook, 'trade_pot': pot,
    'trade_gem': gem, 'trade_quill': quill, 'trade_book': book,
})


def main():
    os.makedirs(OUT, exist_ok=True)
    sheet = Image.new('RGBA', (len(GLYPHS) * 72 + 8, 80), (40, 30, 20, 255))
    for i, (name, draw) in enumerate(GLYPHS.items()):
        img, d = canvas()
        result = draw(d)
        if isinstance(result, Image.Image):
            img = result
        small = img.resize((64, 64), Image.LANCZOS)
        small.save(os.path.join(OUT, name + '.tga'))
        sheet.alpha_composite(small, (8 + i * 72, 8))
    sheet.save(os.path.join(OUT, '..', 'glyph_sheet.png'))
    print(len(GLYPHS), 'glyphs')


main()
