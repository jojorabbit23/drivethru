"""Recolour to the Drive Thru palette, decimate and clean up the two FPS-hands GLBs.
Rigs, skins and animations are kept byte-for-byte; only index buffers, vertex
attributes (compacted), inverse binds (pistol fix), textures and materials change.

  python3 process.py            # writes out/aks74u_hands.glb, out/pistol43_hands.glb
"""
import io, json, os, sys
import numpy as np
from PIL import Image
import glbtool

HERE = os.path.dirname(os.path.abspath(__file__))
DEC = os.path.join(HERE, 'dec')
OUT = os.path.join(HERE, 'out')

# core/palette.gd
MIDNIGHT = (16, 28, 44); BLUE_SLATE = (36, 56, 75); CHARCOAL = (39, 45, 50); CONCRETE = (98, 109, 115)
OX_TEAL = (40, 126, 131); E_TEAL = (101, 201, 194); BURNT = (201, 107, 53); AMBER = (243, 163, 77); CHALK = (233, 225, 209)
SKIN = (173, 125, 85)   # the skin swatch already used by weapons/knife/cleatimus_arms_atlas.png

# which simplified level to keep per mesh (triangle counts from Godot's generate_lods)
TARGET = {'aks': {0: 3056, 1: 2761, 2: 328, 3: 163},
          'pis': {0: 2736, 1: 256, 2: 2025}}


# ------------------------------------------------------------------ colour
def lum(rgb):
    return (rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114) / 255.0


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def ramp(L, base, ref, contrast=1.0):
    """Keep the texture's light/dark detail, but in one palette hue."""
    base = np.array(base, float)
    dark = (base * 0.4) * 0.6 + np.array(MIDNIGHT, float) * 0.4
    light = base * 0.55 + np.array(CHALK, float) * 0.45
    l = 1 + (L / max(ref, 1e-3) - 1) * contrast
    lo = np.clip((l - 0.25) / 0.75, 0, 1)[..., None]
    hi = np.clip((l - 1.0) / 1.0, 0, 1)[..., None]
    return np.where((l < 1)[..., None], dark + (base - dark) * lo, base + (light - base) * hi)


def ref_of(L, mask):
    v = L[mask]
    return float(np.median(v)) if v.size else 0.5


def uv_grid(h, w):
    v, u = np.mgrid[0:h, 0:w]
    return (u + 0.5) / w, (v + 0.5) / h


def blend(*layers):
    """layers: (weight HxW, colour HxWx3). Weights are normalised."""
    tot = sum(w for w, _ in layers) + 1e-6
    return sum(w[..., None] * c for w, c in layers) / tot[..., None]


def recolour_aks_arms(rgb):
    h, w, _ = rgb.shape
    u, v = uv_grid(h, w)
    L = lum(rgb)
    glove = v < 0.40
    cuff = (v >= 0.865) & (u < 0.80)
    gear = (u >= 0.80) & (v >= 0.68)
    sleeve = ~glove & ~cuff & ~gear
    pad = 1 - smooth(0.10, 0.22, L)                       # black padding on the glove
    out = np.zeros_like(rgb, float)
    g = blend((1 - pad, ramp(L, OX_TEAL, ref_of(L, glove & (L > 0.22)), 0.8)),
              (pad, ramp(L, CHARCOAL, ref_of(L, glove & (L < 0.12)), 0.9)))
    strap = 1 - smooth(0.035, 0.07, L)                    # zips/straps on the sleeve
    s = blend((1 - strap, ramp(L, BURNT, ref_of(L, sleeve), 0.3)),
              (strap, ramp(L, CHARCOAL, 0.05, 0.8)))
    out[glove] = g[glove]
    out[sleeve] = s[sleeve]
    out[cuff] = ramp(L, CHARCOAL, ref_of(L, cuff), 0.8)[cuff]
    out[gear] = ramp(L, CHARCOAL, ref_of(L, gear), 0.9)[gear]
    return out


def recolour_pistol_arms(rgb):
    h, w, _ = rgb.shape
    u, v = uv_grid(h, w)
    L = lum(rgb)
    glove = v < 0.42
    band = (v >= 0.42) & (v < 0.505)
    skin = v >= 0.505
    worn = smooth(0.38, 0.52, L)                           # tan finger tips / palm patches
    black = 1 - smooth(0.05, 0.11, L)
    leather = np.clip(1 - worn - black, 0, 1)
    g = blend((leather, ramp(L, OX_TEAL, ref_of(L, glove & (L > 0.11) & (L < 0.38)), 0.8)),
              (worn, ramp(L, CONCRETE, ref_of(L, glove & (L > 0.52)), 0.7)),
              (black, ramp(L, CHARCOAL, 0.06, 0.8)))
    out = np.zeros_like(rgb, float)
    out[glove] = g[glove]
    out[band] = ramp(L, CHARCOAL, ref_of(L, band), 0.9)[band]
    out[skin] = ramp(L, SKIN, ref_of(L, skin), 0.8)[skin]
    return out


def recolour_pistol_sleeve(rgb):
    L = lum(rgb)
    black = 1 - smooth(0.05, 0.10, L)
    return blend((1 - black, ramp(L, BURNT, ref_of(L, L > 0.1), 0.6)),
                 (black, ramp(L, CHARCOAL, 0.06, 0.8)))


def recolour_glock(rgb):
    L = lum(rgb)
    mx = rgb.max(-1) / 255.0
    mn = rgb.min(-1) / 255.0
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-3), 0)
    accent = smooth(0.35, 0.55, sat) * smooth(0.15, 0.3, mx)
    return blend((1 - accent, ramp(L, CONCRETE, ref_of(L, L > 0.02) * 1.6, 0.85)),
                 (accent, ramp(L, BURNT, ref_of(L, accent > 0.5), 0.7)))


def png(arr):
    b = io.BytesIO()
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(b, 'PNG', optimize=True)
    return b.getvalue()


def load_image(g, ii, size, mode='RGB'):
    im = Image.open(io.BytesIO(g.image_bytes(ii))).convert(mode)
    return np.asarray(im.resize(size, Image.LANCZOS)).astype(float)


def srgb_to_linear(c):
    c = np.array(c, float) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4).tolist()


# ------------------------------------------------------------- decimation
def apply_lod(g, tag, mi, tris):
    j = g.j
    pr = j['meshes'][mi]['primitives'][0]
    at = pr['attributes']
    base = os.path.join(DEC, '%s_%d' % (tag, mi))
    info = json.load(open(base + '.lods.json'))
    lod = [l for l in info['lods'] if l['tris'] == tris][0]
    idx = np.fromfile(lod['file'], dtype='<u4').astype(np.int64)
    vc = info['verts_before']
    if info['verts_after'] != vc:
        # Godot split some vertices by normal; map each extra back to the original
        # vertex with the same position and UV (skin weights come from that one)
        after = np.fromfile(base + '.verts_after', dtype='<f4').reshape(-1, 5)
        P = np.fromfile(base + '.pos', dtype='<f4').reshape(-1, 3)
        U = np.fromfile(base + '.uv', dtype='<f4').reshape(-1, 2)
        assert np.allclose(after[:vc, :3], P, atol=1e-5), 'original vertices moved'
        key = {}
        for i in range(vc):
            key.setdefault((tuple(np.round(P[i], 5)), tuple(np.round(U[i], 5))), i)
        remap = np.arange(len(after))
        for k in range(vc, len(after)):
            kk = (tuple(np.round(after[k, :3], 5)), tuple(np.round(after[k, 3:], 5)))
            if kk in key:
                remap[k] = key[kk]
            else:   # fall back: nearest original position
                remap[k] = int(np.argmin(((P - after[k, :3]) ** 2).sum(1)))
        idx = remap[idx]
    # drop degenerate triangles produced by the remap
    t = idx.reshape(-1, 3)
    t = t[(t[:, 0] != t[:, 1]) & (t[:, 1] != t[:, 2]) & (t[:, 0] != t[:, 2])]
    kept, inv = np.unique(t.ravel(), return_inverse=True)
    for name, ai in list(at.items()):
        a = j['accessors'][ai]
        arr = g.read(ai)[kept]
        nai = g.add_accessor(arr, a['type'], a['componentType'], 34962, minmax=(name == 'POSITION'))
        if a.get('normalized'):
            j['accessors'][nai]['normalized'] = True
        at[name] = nai
    pr['indices'] = g.add_accessor(inv.reshape(-1, 1).astype(np.uint32), 'SCALAR',
                                   5123 if len(kept) < 65536 else 5125, 34963)
    return len(t), len(kept)


# ------------------------------------------------------------------ build
def credit(g, note):
    ex = g.j['asset'].setdefault('extras', {})
    ex['modifications'] = note


def build_aks():
    g = glbtool.GLB(os.path.join(HERE, 'src/aks74u.glb'))
    j = g.j
    # textures: 0 arms base, 1 arms roughness, 2 arms normal, 3 gun ORM, 4 gun normal
    g.set_image(0, png(recolour_aks_arms(load_image(g, 0, (512, 1024)))))
    g.set_image(1, png(load_image(g, 1, (512, 1024))))
    g.set_image(2, png(load_image(g, 2, (512, 1024))))
    g.set_image(3, png(load_image(g, 3, (512, 512))))
    g.set_image(4, png(load_image(g, 4, (512, 512))))
    m = j['materials']
    m[1]['pbrMetallicRoughness']['baseColorFactor'] = srgb_to_linear(CONCRETE) + [1.0]
    wood = tuple(int(c * 0.6) for c in BURNT)
    m[2]['pbrMetallicRoughness']['baseColorFactor'] = srgb_to_linear(wood) + [1.0]
    m[2]['pbrMetallicRoughness']['roughnessFactor'] = 0.7
    m[3]['pbrMetallicRoughness']['baseColorFactor'] = srgb_to_linear(AMBER) + [1.0]
    m[3]['pbrMetallicRoughness']['metallicFactor'] = 0.8
    m[3]['pbrMetallicRoughness']['roughnessFactor'] = 0.45
    stats = {}
    for mi, tris in TARGET['aks'].items():
        stats[j['meshes'][mi]['name']] = apply_lod(g, 'aks', mi, tris)
    credit(g, 'Recoloured to The Drive Thru palette, decimated to ~31% triangles, textures downscaled (The Drive Thru project).')
    os.makedirs(OUT, exist_ok=True)
    g.save(os.path.join(OUT, 'aks74u_hands.glb'))
    return stats


def build_pistol():
    g = glbtool.GLB(os.path.join(HERE, 'src/pistol43.glb'))
    j = g.j
    # fix: the Glock's vertices are authored 38.85x too large (the Hands node scale),
    # so scale them down in mesh space through its joints' inverse bind matrices
    K = j['nodes'][[i for i, n in enumerate(j['nodes']) if n.get('name') == 'Hands'][0]]['scale'][0]
    sk = j['skins'][0]
    ibm = g.read(sk['inverseBindMatrices']).reshape(-1, 4, 4).transpose(0, 2, 1).copy()
    S = np.diag([1 / K, 1 / K, 1 / K, 1.0])
    gun_joints = set()
    glock = [mi for mi, mm in enumerate(j['meshes']) if mm['name'].startswith('Glock')][0]
    pr = j['meshes'][glock]['primitives'][0]
    J = g.read(pr['attributes']['JOINTS_0']); W = g.read(pr['attributes']['WEIGHTS_0'])
    gun_joints = set(np.unique(J[W > 0]).tolist())
    for k in gun_joints:
        ibm[k] = ibm[k] @ S
    sk['inverseBindMatrices'] = g.add_accessor(ibm.transpose(0, 2, 1).reshape(-1, 16), 'MAT4', 5126)
    # textures: 0 arms, 1 sleeve, 2 glock base, 3 glock MR, 4 glock emissive (dropped), 5 glock normal
    g.set_image(0, png(recolour_pistol_arms(load_image(g, 0, (512, 512)))))
    g.set_image(1, png(recolour_pistol_sleeve(load_image(g, 1, (512, 512)))))
    g.set_image(2, png(recolour_glock(load_image(g, 2, (1024, 1024)))))
    g.set_image(3, png(load_image(g, 3, (1024, 1024))))
    g.set_image(5, png(load_image(g, 5, (1024, 1024))))
    m = j['materials']
    m[1]['pbrMetallicRoughness']['roughnessFactor'] = 0.85   # fabric sleeve, not glossy
    for mm in m:
        mm.get('extensions', {}).pop('KHR_materials_specular', None)
        mm.get('extensions', {}).pop('KHR_materials_emissive_strength', None)
        if 'extensions' in mm and not mm['extensions']:
            del mm['extensions']
    # only light sources emit (AGENTS.md rule 5): no glowing sights
    m[2].pop('emissiveTexture', None); m[2].pop('emissiveFactor', None)
    # drop the emissive image/texture entirely (texture 4 -> image 4)
    used_tex = set()
    for mm in m:
        for key in ('normalTexture', 'occlusionTexture', 'emissiveTexture'):
            if key in mm: used_tex.add(mm[key]['index'])
        pb = mm.get('pbrMetallicRoughness', {})
        for key in ('baseColorTexture', 'metallicRoughnessTexture'):
            if key in pb: used_tex.add(pb[key]['index'])
    assert 4 not in used_tex
    j['textures'][4]['source'] = 0          # orphaned texture; point at a kept image
    j['images'][4] = dict(j['images'][0])
    j['extensionsUsed'] = [e for e in j.get('extensionsUsed', []) if e not in ('KHR_materials_specular', 'KHR_materials_emissive_strength')]
    if not j['extensionsUsed']:
        del j['extensionsUsed']
    stats = {}
    for mi, tris in TARGET['pis'].items():
        stats[j['meshes'][mi]['name']] = apply_lod(g, 'pis', mi, tris)
    credit(g, 'Recoloured to The Drive Thru palette, Glock bind scale fixed, emissive removed, decimated to ~54% triangles, textures downscaled (The Drive Thru project).')
    g.save(os.path.join(OUT, 'pistol43_hands.glb'))
    return stats


if __name__ == '__main__':
    print('aks', build_aks())
    print('pistol', build_pistol())
    for f in ('aks74u_hands.glb', 'pistol43_hands.glb'):
        print(f, round(os.path.getsize(os.path.join(OUT, f)) / 1e6, 2), 'MB')
