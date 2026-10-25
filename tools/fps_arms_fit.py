#!/usr/bin/env python3
"""Solve how the shared AKS hand sits inside each weapon's old hand frame.

Semantic start (default for the long guns and blades): plain multi-start ICP
can settle on a hand that overlaps the old one but is turned round (fingers
backwards). So each fit starts from the hand's grip frame (knuckle line index
to pinky, palm facing the object) laid on the weapon's grip frame: for long
guns from the grip/fore-end directions in camera space at rest, for the knife
and dagger from the old PSX hand's own finger bones. ICP then only refines
(tools/fps_arms_frames_export.gd writes frames.json first).

  godot --headless --path . --script res://tools/fps_arms_fit_export.gd -- /tmp/fit
  python3 tools/fps_arms_fit.py /tmp/fit

Trimmed ICP (multi-start over the 24 axis-aligned rotations) lays the AKS
hand's vertices (in its hand-bone frame) onto the old hand mesh (in the old
hand's frame). Prints FITS entries for weapons/fps_arms/fps_arms.gd:
position and Euler rotation (degrees, Godot YXZ order) of the AKS hand bone in
the old hand's frame, plus the residual and the old/new size ratio.
"""
import itertools, math, os, sys
import numpy as np
from scipy.spatial import cKDTree
from scipy.spatial.transform import Rotation

PAIRS = {  # weapon: [(aks cloud, old cloud)] for right, left
    'pump': [('aks_r', 'pump_r'), ('aks_l', 'pump_l')],
    # Pistol 43 rig, used at 1.7x (FITS "scale"): its hands are ~0.6x our pistols'
    'pistol': [('aks_r_p43', 'pistol_r', 1.7), ('aks_l_p43', 'pistol_l', 1.7)],   # right hand: use fps_arms_gun_fit.gd
    'crop_duster': [('aks_r', 'crop_r'), ('aks_l', 'crop_l')],
    'knife': [('aks_r_fist', 'knife_r'), ('aks_l', 'knife_l')],
    'dagger': [('aks_r_fist', 'dagger_r'), ('aks_l', 'knife_l')],
}


def load(d, name):
    return np.fromfile(os.path.join(d, name + '.f32'), dtype='<f4').reshape(-1, 3).astype(float)


def hand_core(old, size):
    """The glove part of an old hand mesh: the densest blob of hand-sized radius."""
    tree = cKDTree(old)
    dens = np.array([len(x) for x in tree.query_ball_point(old, size * 0.35)])
    seeds = old[dens >= np.percentile(dens, 80)]
    centre = np.median(seeds, axis=0)
    keep = np.linalg.norm(old - centre, axis=1) < size * 0.9
    return old[keep], centre


def axis_rotations():
    mats = []
    for perm in itertools.permutations(range(3)):
        for signs in itertools.product([1, -1], repeat=3):
            m = np.zeros((3, 3))
            for i in range(3):
                m[i, perm[i]] = signs[i]
            if np.linalg.det(m) > 0:
                mats.append(m)
    return mats


def icp(src, dst_tree, dst, R, t, iters=60, keep=0.75):
    for _ in range(iters):
        moved = src @ R.T + t
        d, idx = dst_tree.query(moved)
        cut = np.quantile(d, keep)
        m = d <= cut
        a, b = src[m], dst[idx[m]]
        ca, cb = a.mean(0), b.mean(0)
        H = (a - ca).T @ (b - cb)
        U, _, Vt = np.linalg.svd(H)
        D = np.diag([1, 1, np.sign(np.linalg.det(Vt.T @ U.T))])
        R = Vt.T @ D @ U.T
        t = cb - R @ ca
    moved = src @ R.T + t
    d, _ = dst_tree.query(moved)
    return R, t, float(np.sqrt(np.mean(np.sort(d)[: int(len(d) * keep)] ** 2)))


def grip_frame(lm):
    """x: knuckle line index->pinky, y: palm facing the object, origin: knuckles."""
    I = np.array(lm['index'][0]); P = np.array(lm['pinky'][0]); W = np.array(lm['wrist'][0])
    tips = np.array(lm['tips']).mean(0)
    x = P - I; x /= np.linalg.norm(x)
    n = np.cross(I - W, P - W); n /= np.linalg.norm(n)
    if np.dot(n, tips - (I + P) / 2) < 0:
        n = -n
    y = n - x * np.dot(n, x); y /= np.linalg.norm(y)
    return np.stack([x, y, np.cross(x, y)], 1), (I + P) / 2


# long guns, in camera space at rest: knuckle line and palm->object direction
LONG_GUN = {'r': ((0.0, -1.0, 0.25), (0.0, 0.0, -1.0)),   # pistol grip: knuckles down the raked grip, palm forward
            'l': ((0.0, 0.0, 1.0), (0.0, 1.0, 0.0))}       # fore-end: knuckles along it (index forward), palm up


def semantic_start(frames, weapon, side, aks_key):
    H, h0 = grip_frame(frames[aks_key][side])
    e = frames[weapon][side]
    if 'index' in e:                        # knife/dagger: the old PSX hand's own grip frame
        G, g0 = grip_frame(e)
    else:
        rc = np.array(e['ref_in_camera'][:3]).T    # columns: ref axes in camera space
        k, n = (np.array(v, float) for v in LONG_GUN[side])
        k = rc.T @ (k / np.linalg.norm(k)); n = rc.T @ (n / np.linalg.norm(n))
        n = n - k * np.dot(n, k); n /= np.linalg.norm(n)
        G, g0 = np.stack([k, n, np.cross(k, n)], 1), None
    R0 = G @ H.T
    return R0, h0, g0


def angle_between(A, B):
    return math.degrees(Rotation.from_matrix(A @ B.T).magnitude())


def fit(aks, old, start=None):
    size = np.ptp(aks, axis=0).max()
    core, centre = hand_core(old, size)
    tree = cKDTree(core)
    if start is not None:
        R0, h0, g0 = start
        t0 = (g0 - R0 @ h0) if g0 is not None else centre - (aks @ R0.T).mean(0)
        R, t, err = icp(aks, tree, core, R0, t0)
        ratio = np.ptp(core, axis=0).max() / size
        drift = angle_between(R, R0)
        eul = Rotation.from_matrix(R).as_euler('YXZ', degrees=True)
        return t, (eul[1], eul[0], eul[2]), err, ratio, drift
    best = None
    for R0 in axis_rotations():
        t0 = centre - (aks @ R0.T).mean(0)
        R, t, err = icp(aks, tree, core, R0, t0)
        if best is None or err < best[2]:
            best = (R, t, err)
    R, t, err = best
    ratio = np.ptp(core, axis=0).max() / size
    # Godot Basis.from_euler default order is YXZ
    eul = Rotation.from_matrix(R).as_euler('YXZ', degrees=True)
    rot = (eul[1], eul[0], eul[2])
    return t, rot, err, ratio, None


def main(d):
    import json
    fp = os.path.join(d, 'frames.json')
    frames = json.load(open(fp)) if os.path.exists(fp) else {}
    for weapon, pairs in PAIRS.items():
        out = []
        for side, pair in zip('rl', pairs):
            a, o = pair[0], pair[1]
            scale = pair[2] if len(pair) > 2 else 1.0
            start = None
            if weapon in frames and not a.endswith('_p43'):
                start = semantic_start(frames, weapon, side, 'aks_fist' if a.endswith('_fist') else 'aks')
            t, rot, err, ratio, drift = fit(load(d, a) * scale, load(d, o), start)
            out.append('"%s": [Vector3(%.4f, %.4f, %.4f), Vector3(%.1f, %.1f, %.1f)]' % (side, *t, *rot))
            how = 'semantic start, ICP turned it %.1f deg' % drift if drift is not None else 'multi-start ICP'
            print('# %s %s: rms %.4f m, old/new hand size %.2f (%s)' % (weapon, side, err, ratio, how))
        print('"%s": {%s}' % (weapon, ', '.join(out)))


if __name__ == '__main__':
    main(sys.argv[1])
