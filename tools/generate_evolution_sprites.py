"""Original lightweight geometric particle sprites; Pillow only."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import math
out = Path(__file__).resolve().parents[1] / 'assets/vfx/evolution'
out.mkdir(parents=True, exist_ok=True)
scale, side = 3, 256

def canvas(): return Image.new('RGBA', (side*scale, side*scale))
def save(image,name): image.resize((side,side),Image.Resampling.LANCZOS).save(out/name)
glint=canvas();d=ImageDraw.Draw(glint)
d.polygon([(128*scale,36*scale),(141*scale,115*scale),(203*scale,128*scale),(141*scale,141*scale),(128*scale,220*scale),(115*scale,141*scale),(53*scale,128*scale),(115*scale,115*scale)],fill=(255,255,255,245))
save(glint,'Glint.png')
