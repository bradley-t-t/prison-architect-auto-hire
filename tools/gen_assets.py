"""Builds every generated file the Auto Hire mod ships.

Outputs, relative to the mod root (the parent of this tools/ folder):
  data/sprites.png                  the Staffing Terminal's two frames
  data/materials.txt                the terminal
  data/language/base-language.txt   names, build-menu text, buttons and the tooltip
  thumbnail.png                     the mod's card image in the game's mod list

Usage: python gen_assets.py

The script, data/scripts/StaffingTerminal.lua, is written by hand and not
touched here.
"""

import os

from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")

# The game measures a sprite sheet in 32-pixel cells; a map tile is two.
CELL = 32
TILE = 64

DESK = (120, 88, 58)
DESK_HI = (150, 114, 78)
DESK_LO = (88, 62, 40)
DARK = (44, 48, 54)
DARK_HI = (66, 71, 78)
SCREEN_IDLE = (28, 92, 60)
SCREEN_BUSY = (30, 84, 150)
SHADOW = (0, 0, 0, 90)

FRAMES = 2
PRICE = 1000

# Object type, its name in the game, and the letter its number takes in the tooltip.
KINDS = [
    ("Guard", "Guards", "A"), ("ArmedGuard", "Armed Guards", "B"), ("DogHandler", "Dog Handlers", "C"),
    ("Sniper", "Snipers", "D"), ("Workman", "Workmen", "E"), ("Cook", "Cooks", "F"),
    ("Janitor", "Janitors", "G"), ("Gardener", "Gardeners", "H"), ("Doctor", "Doctors", "I"),
]


def terminal_sprite(frame):
    """A desk seen from the front with a monitor on it, bottom-aligned in its
    tile. The screen is green with every post filled and blue while hiring."""
    im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([6, 58, 58, 62], fill=SHADOW)
    d.rectangle([8, 40, 55, 60], fill=DESK + (255,))
    d.rectangle([8, 40, 55, 43], fill=DESK_HI + (255,))
    d.rectangle([8, 57, 55, 60], fill=DESK_LO + (255,))
    d.rectangle([28, 34, 35, 40], fill=DARK + (255,))
    d.rectangle([14, 8, 49, 35], fill=DARK + (255,))
    d.rectangle([14, 8, 49, 10], fill=DARK_HI + (255,))
    screen = SCREEN_BUSY if frame else SCREEN_IDLE
    d.rectangle([17, 12, 46, 32], fill=screen + (255,))
    for i, y in enumerate(range(15, 31, 4)):
        lit = tuple(min(255, c + 110) for c in screen)
        d.rectangle([20, y, 23, y + 1], fill=lit + (255,))
        d.rectangle([26, y, 26 + (16 if (i + frame) % 2 else 10), y + 1], fill=lit + (255,))
    d.rectangle([14, 46, 30, 54], fill=DESK_LO + (255,))
    d.rectangle([34, 46, 50, 54], fill=DESK_LO + (255,))
    return im


def build_sprites():
    sheet = Image.new("RGBA", (FRAMES * TILE, TILE), (0, 0, 0, 0))
    for f in range(FRAMES):
        sheet.paste(terminal_sprite(f), (f * TILE, 0))
    return sheet


def build_thumbnail():
    im = Image.new("RGBA", (256, 256), (16, 18, 21, 255))
    big = terminal_sprite(1).resize((240, 240), Image.NEAREST)
    im.paste(big, (8, 8), big)
    return im


def materials_text():
    sprites = ""
    for f in range(FRAMES):
        sprites += f"    BEGIN Sprite         x {2 * f}  y 0  w 2  h 2  RotateType 0  TopAligned false  END\n"
    return f"""BEGIN Object
    Name                 StaffingTerminal
    ConstructionTime     10.0000
    Toughness            200.000
    Price                -{PRICE}
    RenderDepth          1
    Group                StaticObject
    BlockedBy            Wall
    BlockedBy            UtilityStation
    BlockedBy            StaticObject
    MadeOf               Wood
    Properties           StaticObject
    Properties           Scripted
    NumSprites           {FRAMES}
    BEGIN ToolbarSprite  x 0  y 0  w 2  h 2  END
{sprites}END
"""


def language_text():
    popup = ("Keeps your staff at the numbers you set. Click the terminal, pick a kind of staff and set how "
             "many you want. When you have fewer, new ones arrive at the terminal. It never fires anybody. "
             "Arrivals skip the hiring fee and draw wages like any other staff. One terminal covers the "
             "whole prison.")
    rows = [
        ("object_StaffingTerminal", "Staffing Terminal"),
        ("buildtoolbar_popup_obj_StaffingTerminal", popup),
        ("staffing_kind", "Staff: *X"),
        ("staffing_level", "Keep *X, have *Y"),
        ("staffing_less10", "-10"),
        ("staffing_less", "-1"),
        ("staffing_more", "+1"),
        ("staffing_more10", "+10"),
    ]
    rows += [(f"staffing_name_{kind}", name) for kind, name, _ in KINDS]
    summary = "Keeping: " + ", ".join(f"*{letter} {name}" for _, name, letter in KINDS)
    rows.append(("tooltip_StaffingTerminal", summary))
    width = max(len(k) for k, _ in rows) + 4
    return "".join(f"{k:<{width}}{v}\n" for k, v in rows)


def save_image(im, path):
    """Writes a picture unless the file already holds the same pixels: a
    different version of the imaging library packs the same picture into
    different bytes, and that is not a change."""
    if os.path.exists(path):
        with Image.open(path) as old:
            if old.size == im.size and ImageChops.difference(old.convert("RGBA"), im.convert("RGBA")).getbbox() is None:
                return
    im.save(path)


def main():
    os.makedirs(os.path.join(DATA, "language"), exist_ok=True)
    save_image(build_sprites(), os.path.join(DATA, "sprites.png"))
    with open(os.path.join(DATA, "materials.txt"), "w") as f:
        f.write(materials_text())
    with open(os.path.join(DATA, "language", "base-language.txt"), "w") as f:
        f.write(language_text())
    save_image(build_thumbnail(), os.path.join(ROOT, "thumbnail.png"))
    print("wrote sprites.png, materials.txt, base-language.txt, thumbnail.png")


if __name__ == "__main__":
    main()
