"""Minimal GLB read/modify/write: keeps every node, skin and animation as-is,
lets us replace accessors (indices, inverse binds), images and materials."""
import json, struct
import numpy as np

COMP = {5126: np.float32, 5123: np.uint16, 5121: np.uint8, 5125: np.uint32, 5122: np.int16, 5120: np.int8}
NCOMP = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


class GLB:
    def __init__(self, path):
        d = open(path, 'rb').read()
        assert d[:4] == b'glTF'
        jl = struct.unpack('<I', d[12:16])[0]
        self.j = json.loads(d[20:20 + jl])
        o = 20 + jl
        bl = struct.unpack('<I', d[o:o + 4])[0]
        self.bin = d[o + 8:o + 8 + bl]
        # each bufferView becomes its own bytes blob; we repack on save
        self.views = []
        for bv in self.j['bufferViews']:
            s = bv.get('byteOffset', 0)
            self.views.append(bytes(self.bin[s:s + bv['byteLength']]))

    # ---- accessors
    def read(self, ai):
        a = self.j['accessors'][ai]
        dt = np.dtype(COMP[a['componentType']])
        nc = NCOMP[a['type']]
        bv = self.j['bufferViews'][a['bufferView']]
        blob = self.views[a['bufferView']]
        stride = bv.get('byteStride', 0) or dt.itemsize * nc
        off = a.get('byteOffset', 0)
        out = np.empty((a['count'], nc), dtype=dt)
        raw = np.frombuffer(blob, dtype=np.uint8)
        for k in range(nc):
            idx = off + np.arange(a['count']) * stride + k * dt.itemsize
            out[:, k] = np.frombuffer(raw[(idx[:, None] + np.arange(dt.itemsize)).ravel()].tobytes(), dtype=dt)
        if a.get('normalized'):
            pass
        return out

    def add_view(self, data, target=None):
        self.views.append(bytes(data))
        bv = {'buffer': 0, 'byteLength': len(data)}
        if target:
            bv['target'] = target
        self.j['bufferViews'].append(bv)
        return len(self.j['bufferViews']) - 1

    def add_accessor(self, arr, atype, ctype, target=None, minmax=False):
        arr = np.ascontiguousarray(arr.astype(COMP[ctype]))
        vi = self.add_view(arr.tobytes(), target)
        a = {'bufferView': vi, 'componentType': ctype, 'count': int(arr.shape[0]), 'type': atype}
        if minmax:
            flat = arr.reshape(arr.shape[0], -1)
            a['min'] = flat.min(0).tolist()
            a['max'] = flat.max(0).tolist()
        self.j['accessors'].append(a)
        return len(self.j['accessors']) - 1

    # ---- images
    def image_bytes(self, ii):
        return self.views[self.j['images'][ii]['bufferView']]

    def set_image(self, ii, png_bytes):
        im = self.j['images'][ii]
        im['bufferView'] = self.add_view(png_bytes)
        im['mimeType'] = 'image/png'

    # ---- save: repack only the bufferViews still referenced
    def save(self, path):
        j = self.j
        used = set()
        for a in j['accessors']:
            if 'bufferView' in a:
                used.add(a['bufferView'])
        for im in j.get('images', []):
            if 'bufferView' in im:
                used.add(im['bufferView'])
        remap, blob, new_views = {}, bytearray(), []
        for i, bv in enumerate(j['bufferViews']):
            if i not in used:
                continue
            while len(blob) % 4:
                blob.append(0)
            nb = dict(bv)
            nb['byteOffset'] = len(blob)
            nb['buffer'] = 0
            nb['byteLength'] = len(self.views[i])
            blob += self.views[i]
            remap[i] = len(new_views)
            new_views.append(nb)
        for a in j['accessors']:
            if 'bufferView' in a:
                a['bufferView'] = remap[a['bufferView']]
        for im in j.get('images', []):
            if 'bufferView' in im:
                im['bufferView'] = remap[im['bufferView']]
        j['bufferViews'] = new_views
        while len(blob) % 4:
            blob.append(0)
        j['buffers'] = [{'byteLength': len(blob)}]
        js = json.dumps(j, separators=(',', ':')).encode()
        while len(js) % 4:
            js += b' '
        total = 12 + 8 + len(js) + 8 + len(blob)
        with open(path, 'wb') as f:
            f.write(struct.pack('<4sII', b'glTF', 2, total))
            f.write(struct.pack('<I4s', len(js), b'JSON'))
            f.write(js)
            f.write(struct.pack('<I4s', len(blob), b'BIN\x00'))
            f.write(blob)
        # reload views so the object stays usable
        self.__init__(path)
