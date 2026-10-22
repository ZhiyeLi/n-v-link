"""Inspect local Flash data for migration facts; does not execute the supplied game.

All extracted reference material stays under sources/n14_reference.
The new game implementation is authored separately.
"""
import json
from pathlib import Path
import re
import struct
import zipfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "sources" / "n14_reference"
OPS = {0:"End", 4:"NextFrame", 6:"Play", 7:"Stop", 10:"Add", 11:"Subtract",
       12:"Multiply",13:"Divide",14:"Equals",15:"Less",16:"And",17:"Or",18:"Not",
       23:"Pop",24:"ToInteger",28:"GetVariable",29:"SetVariable",32:"SetTarget2",
       33:"StringAdd",38:"Trace",48:"Random",52:"GetTime",60:"DefineLocal",
       61:"CallFunction",62:"Return",63:"Modulo",64:"NewObject",65:"DefineLocal2",
       66:"InitArray",67:"InitObject",68:"TypeOf",71:"Add2",72:"Less2",73:"Equals2",
       74:"ToNumber",75:"ToString",76:"PushDuplicate",77:"StackSwap",78:"GetMember",
       79:"SetMember",80:"Increment",81:"Decrement",82:"CallMethod",83:"NewMethod",
       96:"BitAnd",97:"BitOr",98:"BitXor",99:"BitLShift",100:"BitRShift",
       101:"BitURShift",102:"StrictEquals",103:"Greater",135:"StoreRegister",
       136:"ConstantPool",142:"DefineFunction2",150:"Push",153:"Jump",155:"DefineFunction",
       157:"If",158:"Call",159:"GotoFrame2"}


def read_reference():
    with zipfile.ZipFile(ROOT / "n_v1pc.zip") as archive:
        exe = archive.read("n_v14.exe")
    size = struct.unpack_from("<I", exe, len(exe)-4)[0]
    swf = exe[-size-8:-8]
    assert swf[:3] in (b"CWS", b"FWS"), "Unrecognized Flash projector"
    raw = b"FWS" + swf[3:8] + zlib.decompress(swf[8:]) if swf[:3] == b"CWS" else swf
    assert len(raw) == struct.unpack_from("<I",raw,4)[0]
    return raw


def cstring(data, offset):
    end = data.index(0, offset)
    return data[offset:end].decode("latin1"), end+1


def pushes(payload, pool):
    values = []
    p = 0
    while p < len(payload):
        kind = payload[p]; p += 1
        if kind == 0:
            value,p = cstring(payload,p)
        elif kind == 1:
            value = struct.unpack_from("<f",payload,p)[0]; p += 4
        elif kind in (2,3): value = None
        elif kind == 4:
            value = {"register":payload[p]}; p += 1
        elif kind == 5:
            value = bool(payload[p]); p += 1
        elif kind == 6:
            value = struct.unpack("<d",payload[p+4:p+8]+payload[p:p+4])[0]; p += 8
        elif kind == 7:
            value = struct.unpack_from("<i",payload,p)[0]; p += 4
        elif kind in (8,9):
            index = payload[p] if kind == 8 else struct.unpack_from("<H",payload,p)[0]
            p += 1 if kind == 8 else 2
            value = pool[index] if index < len(pool) else {"constant":index}
        else: raise ValueError(kind)
        values.append(value)
    return values


def short(value):
    if isinstance(value,str) and len(value)>180:
        return value[:50]+f"... [{len(value)} chars]"
    return value


def actions(data, pool=None):
    pool = list(pool or [])
    p=0; result=[]
    while p < len(data):
        start=p; op=data[p]; p+=1
        length=0
        if op>=128:
            length=struct.unpack_from("<H",data,p)[0]; p+=2
        body=data[p:p+length]; p+=length
        item={"offset":start,"op":OPS.get(op,hex(op))}
        if op==136:
            count=struct.unpack_from("<H",body)[0]; q=2; pool=[]
            for _ in range(count):
                v,q=cstring(body,q);pool.append(v)
            item["values"]=pool
        elif op==150: item["values"]=pushes(body,pool)
        elif op==135: item["register"]=body[0]
        elif op in (153,157): item["target"]=p+struct.unpack("<h",body)[0]
        elif op in (142,155):
            name,q=cstring(body,0); count=struct.unpack_from("<H",body,q)[0]; q+=2
            if op==142:
                item["register_count"]=body[q]; item["flags"]=struct.unpack_from("<H",body,q+1)[0];q+=3
            params=[]
            for _ in range(count):
                reg=body[q] if op==142 else None
                if op==142:q+=1
                value,q=cstring(body,q);params.append([reg,value])
            size=struct.unpack_from("<H",body,q)[0]
            item.update(name=name,params=params,body=actions(data[p:p+size],pool))
            p+=size
        result.append(item)
        if op==0:break
    return result


def tags(raw, start):
    p=start
    while p+2 <=len(raw):
        header=struct.unpack_from("<H",raw,p)[0];p+=2
        kind=header>>6;length=header&63
        if length==63:
            length=struct.unpack_from("<I",raw,p)[0];p+=4
        body=raw[p:p+length];p+=length
        if kind==12:yield actions(body)
        elif kind==59:yield actions(body[2:])
        elif kind==39:yield from tags(body,4)
        if kind==0:break


def dump(items, lines, depth=0):
    for item in items:
        show={k:v for k,v in item.items() if k!='body'}
        if 'values' in show: show['values']=[short(v) for v in show['values']]
        lines.append('  '*depth+json.dumps(show,ensure_ascii=True))
        if 'body' in item:dump(item['body'],lines,depth+1)


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    raw=read_reference()
    header=8+(5+4*(raw[8]>>3)+7)//8
    blocks=list(tags(raw,header+4))
    (OUT/'actions.json').write_text(json.dumps(blocks,ensure_ascii=True),encoding='utf-8')
    lines=[]
    for i,block in enumerate(blocks):
        lines.append(f'BLOCK {i}');dump(block,lines)
    (OUT/'actions.txt').write_text('\n'.join(lines),encoding='utf-8')
    print(f'Inspected {len(blocks)} action blocks; reference output in {OUT.relative_to(ROOT)}')


if __name__=='__main__':main()
