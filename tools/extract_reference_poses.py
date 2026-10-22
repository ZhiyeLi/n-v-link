"""Read named animation markers from the user's N 1.4 SWF, without executing it.

Only numeric joint trajectories/labels are exported. Original graphics stay in
the supplied reference archive. Re-run after inspect_reference.py.
"""
import json
import struct
from pathlib import Path
from inspect_reference import read_reference, cstring

ROOT = Path(__file__).resolve().parents[1]


class Bits:
    def __init__(self, data, offset=0):
        self.data, self.bit = data, offset * 8

    def u(self, n):
        value = 0
        for _ in range(n):
            value = (value << 1) | ((self.data[self.bit // 8] >> (7 - self.bit % 8)) & 1)
            self.bit += 1
        return value

    def s(self, n):
        v = self.u(n)
        return v - (1 << n) if n and v & (1 << (n - 1)) else v

    def end(self):
        return (self.bit + 7) // 8


def matrix(data, offset):
    b = Bits(data, offset)
    a, d, c, bb = 1, 1, 0, 0
    if b.u(1):
        n = b.u(5)
        a, d = b.s(n) / 65536, b.s(n) / 65536
    if b.u(1):
        n = b.u(5)
        bb, c = b.s(n) / 65536, b.s(n) / 65536
    n = b.u(5)
    x, y = b.s(n) / 20, b.s(n) / 20
    return [a, bb, c, d, x, y], b.end()


def tags(data, offset):
    while offset + 2 <= len(data):
        h = struct.unpack_from('<H', data, offset)[0]
        offset += 2
        size = h & 63
        if size == 63:
            size = struct.unpack_from('<I', data, offset)[0]
            offset += 4
        yield h >> 6, data[offset:offset + size]
        offset += size
        if h >> 6 == 0:
            break


def timeline(data):
    display, frames, labels = {}, [], {}
    for kind, body in tags(data, 4):
        if kind == 43:
            labels[cstring(body, 0)[0]] = len(frames) + 1
        elif kind == 26:
            flags = body[0]
            depth = struct.unpack_from('<H', body, 1)[0]
            item = dict(display.get(depth, {})) if flags & 1 else {}
            p = 3
            if flags & 2:
                item['id'] = struct.unpack_from('<H', body, p)[0]
                p += 2
            if flags & 4:
                item['matrix'], p = matrix(body, p)
            if flags & 8:
                b = Bits(body, p)
                add, mult, n = b.u(1), b.u(1), b.u(4)
                for _ in range(4 * (add + mult)):
                    b.s(n)
                p = b.end()
            if flags & 16:
                p += 2
            if flags & 32:
                item['name'], p = cstring(body, p)
            display[depth] = item
        elif kind == 28:
            display.pop(struct.unpack_from('<H', body)[0], None)
        elif kind == 1:
            frames.append({str(k): dict(v) for k, v in display.items()})
    return {'labels': labels, 'frames': frames}


def shape(data, rgba):
    b = Bits(data, 2)
    n = b.u(5)
    bounds = [b.s(n) / 20 for _ in range(4)]
    def styles(p):
        fills, lines = [], []
        count = data[p]; p += 1
        if count == 255:
            count = struct.unpack_from('<H', data, p)[0]; p += 2
        for _ in range(count):
            assert data[p] == 0, 'Only solid fills expected'
            p += 1
            fills.append(list(data[p:p + (4 if rgba else 3)]))
            p += 4 if rgba else 3
        count = data[p]; p += 1
        if count == 255:
            count = struct.unpack_from('<H', data, p)[0]; p += 2
        for _ in range(count):
            width = struct.unpack_from('<H', data, p)[0] / 20
            p += 2
            color = list(data[p:p + (4 if rgba else 3)])
            p += 4 if rgba else 3
            lines.append({'width': width, 'color': color})
        return fills, lines, p
    fills, lines, p = styles(b.end())
    b = Bits(data, p)
    nf, nl = b.u(4), b.u(4)
    fill_offset = line_offset = 0
    x = y = f0 = f1 = line = 0
    edges = []
    while True:
        if b.u(1):
            straight = b.u(1)
            n = b.u(4) + 2
            start = [x / 20, y / 20]
            control = None
            if straight:
                if b.u(1):
                    x += b.s(n); y += b.s(n)
                elif b.u(1): y += b.s(n)
                else: x += b.s(n)
            else:
                x += b.s(n); y += b.s(n)
                control = [x / 20, y / 20]
                x += b.s(n); y += b.s(n)
            edges.append([start, control, [x / 20, y / 20], f0, f1, line])
        else:
            flags = b.u(5)
            if not flags: break
            if flags & 1:
                n = b.u(5); x, y = b.s(n), b.s(n)
            if flags & 2:
                f0 = b.u(nf); f0 += fill_offset if f0 else 0
            if flags & 4:
                f1 = b.u(nf); f1 += fill_offset if f1 else 0
            if flags & 8:
                line = b.u(nl); line += line_offset if line else 0
            if flags & 16:
                fill_offset, line_offset = len(fills), len(lines)
                more_fills, more_lines, p = styles(b.end())
                fills.extend(more_fills); lines.extend(more_lines)
                b = Bits(data, p)
                nf, nl = b.u(4), b.u(4)
    return {'bounds': bounds, 'fills': fills, 'lines': lines, 'edges': edges}


def main():
    raw = read_reference()
    start = 8 + (5 + 4 * (raw[8] >> 3) + 7) // 8 + 4
    sprites, exports, drone_shapes = {}, {}, {}
    for kind, body in tags(raw, start):
        if kind == 39:
            sprites[struct.unpack_from('<H', body)[0]] = timeline(body)
        elif kind in (2, 22, 32) and struct.unpack_from('<H', body)[0] in (801, 802):
            drone_shapes[str(struct.unpack_from('<H', body)[0])] = shape(body, kind == 32)
        elif kind == 56:
            p = 2
            for _ in range(struct.unpack_from('<H', body)[0]):
                ident = struct.unpack_from('<H', body, p)[0]
                name, p = cstring(body, p + 2)
                exports[name] = ident
    out = ROOT / 'sources/n14_reference/timelines.json'
    out.write_text(json.dumps({'exports': exports, 'sprites': sprites}), encoding='utf-8')
    markers = []
    for frame in sprites[exports['testNinjaMCm']]['frames'][:104]:
        markers.append({v['name']: [round(x * .2, 4) for x in v['matrix'][4:]] for v in frame.values() if 'name' in v})
    asset = ROOT / 'game/data/n14_animation.json'
    asset.write_text(json.dumps({'source': 'N 1.4 testNinjaMCm; markers scaled by original 20%', 'frames': markers}, separators=(',', ':')), encoding='utf-8')
    (ROOT / 'game/data/n14_drone_shapes.json').write_text(json.dumps(drone_shapes, separators=(',', ':')), encoding='utf-8')
    print('Drone geometry:', {k: [v['bounds'], v['fills'], v['lines'], len(v['edges'])] for k, v in drone_shapes.items()})
    for name, ident in exports.items():
        if any(s in name.lower() for s in ['ninja', 'player', 'drone', 'rag']):
            s = sprites.get(ident, {})
            print(name, ident, s.get('labels'), 'frames:', len(s.get('frames', [])))
            if s.get('frames'):
                print('Named markers:', [v for v in s['frames'][0].values() if 'name' in v])


if __name__ == '__main__':
    main()
