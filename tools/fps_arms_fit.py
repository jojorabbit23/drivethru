#!/usr/bin/env python3
"""Solve how the shared AKS hand sits inside each weapon's old hand frame.

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


def fit(aks, old):
    size = np.ptp(aks, axis=0).max()
    core, centre = hand_core(old, size)
    tree = cKDTree(core)
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
    return t, rot, err, ratio


def main(d):
    for weapon, pairs in PAIRS.items():
        out = []
        for side, pair in zip('rl', pairs):
            a, o = pair[0], pair[1]
            scale = pair[2] if len(pair) > 2 else 1.0
            t, rot, err, ratio = fit(load(d, a) * scale, load(d, o))
            out.append('"%s": [Vector3(%.4f, %.4f, %.4f), Vector3(%.1f, %.1f, %.1f)]' % (side, *t, *rot))
            print('# %s %s: rms %.4f m, old/new hand size %.2f' % (weapon, side, err, ratio))
        print('"%s": {%s}' % (weapon, ', '.join(out)))


if __name__ == '__main__':
    main(sys.argv[1])
