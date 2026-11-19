"""Generate seamless, neutral PBR maps for BVM's raised square stud material.
Requires Pillow and numpy. Maps are art assets, not collision geometry.
"""
from pathlib import Path
import numpy as np
from PIL import Image

out = Path(__file__).resolve().parents[1] / 'assets/materials/studded'
out.mkdir(parents=True, exist_ok=True)
resolution = 256
axis = (np.arange(resolution) + 0.5) / resolution - 0.5
x, y = np.meshgrid(axis, axis)
# Rounded-square signed distance, repeated once per tile with a wide flat border.
qx, qy = np.abs(x) - 0.235, np.abs(y) - 0.235
distance = np.sqrt(np.maximum(qx, 0)**2 + np.maximum(qy, 0)**2) + np.minimum(np.maximum(qx, qy), 0) - 0.035
bevel = np.clip(-distance / 0.045, 0, 1)
height = 0.055 * bevel**2 * (3 - 2 * bevel)
dy, dx = np.gradient(height, 1 / resolution)
normal = np.stack((-dx, dy, np.ones_like(dx)), axis=-1)
normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
Image.fromarray(np.uint8(np.clip(normal * 0.5 + 0.5, 0, 1) * 255)).save(out / 'StudsNormal.png')
# Neutral grayscale keeps every part's authored Color; fine contact shadow adds depth.
contact = np.exp(-((distance - 0.012) / 0.017)**2)
color = np.clip(0.93 + 0.065 * bevel - 0.18 * contact, 0, 1)
Image.fromarray(np.uint8(np.repeat(color[..., None], 3, axis=-1) * 255)).save(out / 'StudsColor.png')
Image.new('RGB', (16, 16), (155, 155, 155)).save(out / 'StudsRoughness.png')
print(out)
