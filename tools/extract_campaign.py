"""Extract the 100 episode / 500 map dataset from the user-supplied N 1.4 archive.

Only the straight-line data-construction instructions are interpreted. No game
code, networking, native executable, or arbitrary Flash operations are executed.
"""
import hashlib
import json
from pathlib import Path
from inspect_reference import read_reference, tags

ROOT = Path(__file__).resolve().parents[1]


def interpret_data(body, episodes):
    stack = []
    registers = {1: {"episodeList": episodes, "levelList": []}}
    for instruction in body:
        op = instruction["op"]
        if op == "Push":
            for value in instruction["values"]:
                stack.append(registers[value["register"]] if isinstance(value, dict) else value)
        elif op == "NewObject":
            name = stack.pop(); count = int(stack.pop())
            args = [stack.pop() for _ in range(count)]
            if name == "LevelData": obj = {"title": args[0], "raw": args[1]}
            elif name == "EpisodeData": obj = {"title": args[0], "author": args[1], "levels": args[2]}
            elif name == "Array": obj = list(args)
            else: raise ValueError(f"Unexpected constructor: {name}")
            stack.append(obj)
        elif op == "StoreRegister": registers[instruction["register"]] = stack[-1]
        elif op == "Pop": stack.pop()
        elif op == "GetMember":
            key = stack.pop(); obj = stack.pop(); stack.append(obj[key])
        elif op == "SetMember":
            value=stack.pop(); key=stack.pop(); obj=stack.pop(); obj[key]=value
        elif op == "CallMethod":
            name=stack.pop(); obj=stack.pop(); count=int(stack.pop())
            args=[stack.pop() for _ in range(count)]
            if name != "push": raise ValueError(f"Unexpected method: {name}")
            obj.extend(args);stack.append(len(obj))
        elif op in ("End", "Return"): break
        else: raise ValueError(f"Unexpected data operation: {op}")


def main():
    raw = read_reference()
    header=8+(5+4*(raw[8]>>3)+7)//8
    blocks=list(tags(raw,header+4))
    episodes={}
    for block in blocks:
        for i, instruction in enumerate(block):
            if "body" in instruction and i>0:
                names=block[i-1].get("values",[])
                if len(names)==1 and str(names[0]).startswith("BuildGameData_Set"):
                    interpret_data(instruction["body"],episodes)
    assert len(episodes)==100, len(episodes)
    levels=[]
    for index in range(100):
        episode=episodes[index]
        assert len(episode["levels"])==5
        for slot, level in enumerate(episode["levels"]):
            terrain, objects=level["raw"].split("|",1)
            assert len(terrain)==713
            entities=[]
            for obj in objects.split("!"):
                if not obj:continue
                kind,params=obj.split("^",1)
                entities.append({"type":int(kind),"params":[float(v) for v in params.split(",")]})
            assert any(o["type"]==5 for o in entities)
            assert any(o["type"]==11 for o in entities)
            levels.append({"id":f"{index:02d}-{slot}","episode":index,"slot":slot,
                           "title":level["title"],"author":episode["author"],
                           "tiles":terrain,"entities":entities,
                           "raw_sha256":hashlib.sha256(level["raw"].encode("latin1")).hexdigest()})
    out=ROOT/'game'/'data';out.mkdir(parents=True,exist_ok=True)
    doc={"format_version":1,"reference":"N v1.4 (user-supplied n_v1pc.zip)",
         "copyright":"Original maps: Metanet Software Inc. and credited map authors.",
         "columns":31,"rows":23,"tile_size":24,"tile_order":"column-major",
         "levels":levels}
    (out/'campaign.json').write_text(json.dumps(doc,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
    source=ROOT/'sources'/'n14_reference';source.mkdir(parents=True,exist_ok=True)
    (source/'campaign_index.json').write_text(json.dumps([{k:v for k,v in l.items() if k not in ('tiles','entities')} for l in levels],ensure_ascii=False,indent=2),encoding='utf-8')
    print(f'Extracted {len(episodes)} episodes, {len(levels)} original maps.')
    print([(l['id'],l['title']) for l in levels[:5]])


if __name__=='__main__':main()
