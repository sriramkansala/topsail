"""Gather the pond's source art into build/assets for the pixel renderer.

    python prepare.py <koi-pond-blender folder> <plates folder> [out folder]

Reads the original render, the koi-free plates (render_plates.py) and the koi cut-outs, and
writes small copies the browser loads, plus a body mask that tells the koi's body from its
fins (the fins are drawn as translucent water, the body as solid colour).
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageFilter

src, plates = sys.argv[1], sys.argv[2]
out = sys.argv[3] if len(sys.argv) > 3 else os.path.join(os.path.dirname(__file__), 'build', 'assets')
os.makedirs(out, exist_ok=True)

# Backgrounds: the original render (for the pipeline strip) and both plates, 1300 x 520.
Image.open(os.path.join(src, 'renders', 'koi-pond-blender.png')).convert('RGB') \
    .resize((1300, 520), Image.LANCZOS).save(os.path.join(out, 'render.png'))
for name in ('plate_flora', 'plate_water'):
    Image.open(os.path.join(plates, name + '.png')).convert('RGB').save(os.path.join(out, name + '.png'))

# Koi: all three cut-outs share one pose. Crop to it (the body's axis is the crop's middle row),
# then shrink with premultiplied alpha so the edges don't go dark.
BOX = (23, 79, 1001, 400)
W = 256
koi = {}
for name in ('kohaku', 'showa', 'beni'):
    im = Image.open(os.path.join(src, 'sprites', f'koi_{name}.png')).convert('RGBA').crop(BOX)
    h = round(im.height * W / im.width)
    small = im.convert('RGBa').resize((W, h), Image.LANCZOS).convert('RGBA')
    small.save(os.path.join(out, f'koi_{name}.png'))
    koi[name] = np.asarray(small).astype(np.float32) / 255

# Body mask from the beni (orange all over, so its body is the saturated part). Per column the
# body is one span; fill it, smooth it a little, and drop the fins and the tail.
a = koi['beni']
mx, mn = a[..., :3].max(-1), a[..., :3].min(-1)
sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
body = (a[..., 3] > 0.5) & (sat > 0.35)
mask = np.zeros(body.shape, np.uint8)
for x in range(body.shape[1]):
    ys = np.nonzero(body[:, x])[0]
    if len(ys) > 2:
        mask[ys.min():ys.max() + 1, x] = 255
mask_img = Image.fromarray(mask, 'L').filter(ImageFilter.MedianFilter(5))
# The tail's tinted lobe can read as body: keep only the largest piece.
from scipy import ndimage
lab, n = ndimage.label(np.asarray(mask_img) > 127)
if n > 1:
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    mask_img = Image.fromarray(((lab == 1 + int(np.argmax(sizes))) * 255).astype(np.uint8), 'L')
mask_img.save(os.path.join(out, 'koi_body.png'))

meta = {'koi': {'width': W, 'height': h, 'axisY': h / 2}}
with open(os.path.join(out, 'meta.json'), 'w') as f:
    json.dump(meta, f)
print('wrote', sorted(os.listdir(out)), meta)
