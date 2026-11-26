"""Blender script: render the pond without its koi, as backgrounds for the pixel pond.

    Blender -b pond.blend --python render_plates.py -- <out dir>

Writes plate_flora.png (pads and lilies, no koi) and plate_water.png (water and bed only)
at half the scene's resolution. The .blend file is not saved.
"""
import bpy, sys

out = sys.argv[sys.argv.index('--') + 1]
sc = bpy.context.scene
sc.render.resolution_percentage = 50
sc.cycles.samples = 128
sc.cycles.use_denoising = True
sc.render.image_settings.file_format = 'PNG'


def hide(names):
    for o in bpy.data.objects:
        if o.type == 'MESH' and not o.name.startswith('Icosphere'):
            o.hide_render = o.name in names


koi = {'Koi beni', 'Koi kohaku', 'Koi showa'}
flora = {'Pad 0', 'Pad 1', 'Pad 2', 'Pad 3', 'Lily pink', 'Lily white'}

hide(koi)
sc.render.filepath = out + '/plate_flora.png'
bpy.ops.render.render(write_still=True)

hide(koi | flora)
sc.render.filepath = out + '/plate_water.png'
bpy.ops.render.render(write_still=True)
