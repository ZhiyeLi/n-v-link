"""Data-only reader for the two supplied Spine setup poses (3.5 / 3.8).

Exports numeric vertices/UVs for offline image preparation. No Spine runtime or
original animation code is included in the game. Format checked against the
official SkeletonBinary declarations saved under sources/prts/reference.
"""
import json
import math
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]


class Reader:
    def __init__(self, data): self.data, self.p, self.strings = data, 0, []
    def byte(self):
        result = self.data[self.p]; self.p += 1
        return result
    def var(self):
        result = shift = 0
        while True:
            value = self.byte(); result |= (value & 127) << shift
            if value < 128: return result
            shift += 7
            assert shift < 35
    def number(self, fmt='f'):
        size = struct.calcsize('>' + fmt)
        value = struct.unpack_from('>' + fmt, self.data, self.p)[0]; self.p += size
        return value
    def floats(self, count): return [self.number() for _ in range(count)]
    def string(self):
        size = self.var()
        if size == 0: return None
        value = self.data[self.p:self.p + size - 1].decode('utf-8'); self.p += size - 1
        return value
    def ref(self):
        if not self.new: return self.string()
        i = self.var(); return self.strings[i - 1] if i else None
    def shorts(self): return [self.number('H') for _ in range(self.var())]


def affine(rotation, x, y, sx=1, sy=1, shearx=0, sheary=0):
    a, b = math.radians(rotation + shearx), math.radians(rotation + 90 + sheary)
    return [math.cos(a)*sx, math.sin(a)*sx, math.cos(b)*sy, math.sin(b)*sy, x, y]


def point(m, x, y): return [m[0]*x + m[2]*y + m[4], m[1]*x + m[3]*y + m[5]]


def compose(p, c):
    return [p[0]*c[0]+p[2]*c[1], p[1]*c[0]+p[3]*c[1], p[0]*c[2]+p[2]*c[3], p[1]*c[2]+p[3]*c[3], *point(p,c[4],c[5])]


def atlas(path):
    regions = {}; current = None
    for line in path.read_text().splitlines():
        if not line.strip(): continue
        if not line.startswith(' ') and ':' not in line and not line.endswith('.png'):
            current = line; regions[current] = {}
        elif current and ':' in line:
            k,v = line.strip().split(':',1); regions[current][k] = v.strip()
    return regions


def extract(folder, name):
    base = ROOT / 'sources/prts' / folder
    r = Reader((base / (name + '.skel')).read_bytes())
    hash_, version = r.string(), r.string(); r.new = version.startswith('3.8')
    r.floats(4 if r.new else 2)
    extra = r.byte()
    if extra:
        r.number(); r.string()
        if r.new: r.string()
    if r.new: r.strings = [r.string() for _ in range(r.var())]
    bones = []
    for i in range(r.var()):
        label = r.string(); parent = r.var() if i else -1
        rotation,x,y,sx,sy,shx,shy,length = r.floats(8)
        mode = r.var()
        if r.new: r.byte()
        if extra: r.number('I')
        local = affine(rotation,x,y,sx,sy,shx,shy)
        world = compose(bones[parent]['world'],local) if parent >= 0 else local
        bones.append(dict(name=label,parent=parent,world=world,length=length,mode=mode))
    slots = []
    for _ in range(r.var()):
        label, bone = r.string(), r.var()
        color = r.number('I')
        dark = r.number('I') if r.new else 0xffffffff
        attachment,blend = r.ref(),r.var()
        slots.append(dict(name=label,bone=bone,attachment=attachment,color=color,blend=blend))
    for kind in range(3):
        for _ in range(r.var()):
            r.string(); r.var()
            if r.new: r.byte()
            for _ in range(r.var()): r.var()
            r.var()
            if kind == 0:
                r.number()
                if r.new: r.number()
                r.byte()
                if r.new: r.byte(); r.byte(); r.byte()
            elif kind == 1:
                r.byte(); r.byte(); r.floats(10)
            else:
                r.var(); r.var(); r.var(); r.floats(5)
    regions = atlas(base / (name + '.atlas'))
    attachments = []

    def vertices(count, bone):
        if not r.byte():
            return [point(bones[bone]['world'], *r.floats(2)) for _ in range(count)]
        result = []
        for _ in range(count):
            x=y=0
            for _ in range(r.var()):
                index=r.var(); vx,vy,w = r.floats(3)
                px,py = point(bones[index]['world'], vx,vy)
                x += px*w; y += py*w
            result.append([x,y])
        return result

    # Default skin (the only skin used for these two examples).
    for _ in range(r.var()):
        slot_index = r.var()
        for _ in range(r.var()):
            attachment = r.ref(); label = r.ref() or attachment; kind = r.byte()
            slot = slots[slot_index]
            path = r.ref() or label
            if kind == 0:
                rotation,x,y,sx,sy,w,h = r.floats(7); color = r.number('I')
                m = compose(bones[slot['bone']]['world'],affine(rotation,x,y,sx,sy))
                pts = [point(m,-w/2,-h/2),point(m,w/2,-h/2),point(m,w/2,h/2),point(m,-w/2,h/2)]
                uv = [[0,1],[1,1],[1,0],[0,0]]; triangles=[0,1,2,2,3,0]
            elif kind == 2:
                color=r.number('I'); count=r.var()
                uv=[r.floats(2) for _ in range(count)]; triangles=r.shorts()
                pts=vertices(count,slot['bone']); r.var()
                if extra: r.shorts(); r.floats(2)
            else:
                raise ValueError(('unsupported setup attachment',kind,label,r.p))
            if attachment != slot['attachment']: continue
            region=regions[path]
            rx,ry=[int(x) for x in region['xy'].split(',')]
            rw,rh=[int(x) for x in region['size'].split(',')]
            if region['rotate']=='true':
                uv=[[rx+v*rh,ry+(1-u)*rw] for u,v in uv]
            else: uv=[[rx+u*rw,ry+v*rh] for u,v in uv]
            attachments.append(dict(name=label,slot=slot['name'],bone=slot['bone'],vertices=[[x,-y] for x,y in pts],uv=uv,triangles=triangles,color=color))
    out=dict(version=version,bones=bones,slots=slots,attachments=attachments,atlas=name+'.png')
    (base/'setup.json').write_text(json.dumps(out,indent=2),encoding='utf-8')
    print(folder,version,'bones',[(i,b['name']) for i,b in enumerate(bones)])
    print('Attachments:',[a['name'] for a in attachments])


if __name__=='__main__':
    extract('exusiai','char_103_angel')
    extract('slug','enemy_1007_slime')
