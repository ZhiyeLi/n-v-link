"""Compact symbolic display of local reference instructions for parameter auditing."""
import json
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
BLOCKS=json.loads((ROOT/'sources/n14_reference/actions.json').read_text())


def describe(body):
    stack=[];lines=[]
    def pop():return stack.pop() if stack else '?'
    binaries={'Add':'+','Add2':'+','Subtract':'-','Multiply':'*','Divide':'/','Equals':'==',
              'Equals2':'==','StrictEquals':'===','Less':'<','Less2':'<','Greater':'>',
              'And':'&&','Or':'||','Modulo':'%','BitAnd':'&','BitOr':'|','BitLShift':'<<',
              'BitRShift':'>>','BitURShift':'>>>'}
    for x in body:
        op=x['op'];s=''
        if op=='Push':
            for v in x['values']:
                stack.append('r'+str(v['register']) if isinstance(v,dict) else repr(v)[:140])
        elif op=='GetVariable':stack.append(pop().strip("'"))
        elif op=='GetMember':
            key=pop();obj=pop();stack.append(obj+'['+key+']')
        elif op in ('SetVariable','DefineLocal'):
            val=pop();key=pop();s=f'{key} = {val}'
        elif op=='SetMember':
            val=pop();key=pop();obj=pop();s=f'{obj}[{key}] = {val}'
        elif op=='StoreRegister':
            s=f'r{x["register"]} = {stack[-1] if stack else "?"}'
        elif op=='Pop':
            val=pop()
            if '(' in val:s=val
        elif op in binaries:
            b=pop();a=pop();stack.append(f'({a} {binaries[op]} {b})')
        elif op=='Not':stack.append('!'+pop())
        elif op in ('Increment','Decrement'):
            stack.append('('+pop()+(' + 1)' if op=='Increment' else ' - 1)'))
        elif op=='PushDuplicate':stack.append(stack[-1])
        elif op=='StackSwap':stack[-1],stack[-2]=stack[-2],stack[-1]
        elif op=='If':s=f'if ({pop()}) goto {x["target"]}'
        elif op=='Jump':s=f'goto {x["target"]}'
        elif op=='Return':s='return '+pop()
        elif op in ('CallMethod','NewMethod','NewObject','CallFunction'):
            name=pop();obj=pop() if op in ('CallMethod','NewMethod') else ''
            n=pop()
            try:args=[pop() for _ in range(int(float(n)))]
            except ValueError:args=['?']
            stack.append((obj+'.' if obj else '')+name+'('+', '.join(args)+')')
        elif op=='GetTime':stack.append('GetTime()')
        elif op=='End':pass
        else:s=op
        if s:lines.append(f'{x["offset"]:4} {s}')
    return '\n'.join(lines)


def main():
    term=sys.argv[1]
    output=[]
    for block in BLOCKS:
        for i,x in enumerate(block):
            if 'body' not in x:continue
            name=x['name'] or str(block[i-1].get('values',['?'])[-1])
            if term in name:
                output.append(name+' '+str(x['params'])+'\n'+describe(x['body']))
    print('\n\n'.join(output))


if __name__=='__main__':main()
