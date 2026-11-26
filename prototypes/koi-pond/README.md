# Koi pond (prototype)

An ambient pixel-art koi pond for the notch, made from a Blender render of a koi pond. These are
the browser prototypes; the app's version (night palette only) is `Packages/PondKit` (the
renderer, a port of `pond.js`) and `Topsail/Pond` (its views and art).

- `index.html`: the study. The live pond, the pipeline stage by stage, the koi sprites, the palette.
- `notch.html`: the pond in the island at real size. A: on idle, a koi swims under the notch.
  B: the pond as a page of the open island; click to feed the koi. Day and night palettes.
- `pond.js`: the renderer both pages share.

## The look

Every "pixel" is a cell of a grid turned 45°, so cells are small diamonds. Where two neighbouring
cells differ in colour, a thin ink line runs along their edge, and same-coloured cells merge into
one region. The colours come from 16 entries, stepped through per material as hue ramps (water,
pads, pink and white petals, stamens), with horizontal brush-streak noise, a horizontal smear and
"glitch" row segments, and 4×4 ordered dithering in the grid's own coordinates. Most lone cells
are cleaned up so the water reads as runs, not mesh.

Koi are read from the render's cut-outs as flat colour regions (cream, red, orange, black, fin),
shrunk by majority vote to a size that suits the cell, widened for pixel proportions, bent by a
swimming wave and by their turns, with dithered translucent fins and a shadow on the pond bed.

## Rebuilding the assets

`build/` is not committed: it holds copies of the source art.

```bash
# 1. Render the pond without its koi (Blender 5; needs GPU access, so outside a sandbox)
Blender -b <koi-pond-blender>/pond.blend --python render_plates.py -- <plates dir>

# 2. Gather everything the pages load into build/assets (Pillow, NumPy, SciPy);
#    --app also refreshes the app's copy of the art
python prepare.py <koi-pond-blender> <plates dir> --app ../../Topsail/Pond/Art
```

Then serve this folder over http (the pages read pixels back from canvases, which `file://`
forbids) and open `index.html` or `notch.html`.

The source render's koi model, and one of its two water-lily models, are CC BY (the file names in
its `models/` folder say which); credit them before anything made from them ships publicly.
