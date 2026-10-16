#!/usr/bin/env python3
"""Directed real-CPU course protocol/cache cases using the lockstep simulator."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build',type=Path,default=Path('/tmp/opencode/course-sync-final'))
    args=parser.parse_args()
    out=args.build.resolve()
    identities=json.loads((out/'inputs.json').read_text())
    for name,digest in identities.items():
        if hashlib.sha256(Path(name).read_bytes()).hexdigest()!=digest:
            raise ValueError(f'stale lockstep binary: {name}')
    def add(rd,rs,imm):return ((imm&4095)<<20)|(rs<<15)|(rd<<7)|0x13
    def lui(rd,upper):return (upper<<12)|(rd<<7)|0x37
    def load(rd,rs,offset=0,kind=2):return ((offset&4095)<<20)|(rs<<15)|(kind<<12)|(rd<<7)|3
    def store(rs,base,offset=0,kind=2):
        imm=offset&4095
        return ((imm>>5)<<25)|(rs<<20)|(base<<15)|(kind<<12)|((imm&31)<<7)|0x23
    tests=[]
    def case(name,body,expected,data=None,retired=None):
        tests.append((name,body+[lui(5,0x80000),store(10,5),0x6f],expected,data or {},len(body)+2 if retired is None else retired))
    case('legal_addi_255',[add(10,0,255)],255)
    case('full_32bit_exit',[lui(10,0xdeadc),add(10,10,-273)],0xdeadbeef)
    for name,upper,offset in (('course_stack',0x40,-16),('ram_last_line',0x10000,-32)):
        case(name,[lui(11,upper),add(11,11,offset),add(12,0,77),store(12,11),load(10,11)],77)
    case('byte_sign_extension',[lui(11,1),add(12,0,128),store(12,11,1,0),load(10,11,1,0)],0xffffff80)
    body=[lui(11,1)]+[load(r+12,11,r<<6) for r in range(8)]+[add(10,0,0)]
    body += [((r+12)<<20)|(10<<15)|(10<<7)|0x33 for r in range(8)]
    case('eight_cold_loads',body,36,{0x1000+(r<<6):r+1 for r in range(8)})
    body=[]
    for r in range(8):body += [lui(11,1+(r<<1)),add(12,0,r+1),store(12,11)]
    body.append(add(10,0,0))
    for r in range(8):body += [lui(11,1+(r<<1)),load(12,11),(12<<20)|(10<<15)|(10<<7)|0x33]
    case('dirty_same_set_eviction',body,36)
    body=[add(10,0,7),lui(5,0x80000),add(6,0,3),
        (1<<25)|(6<<20)|(6<<15)|(4<<12)|(7<<7)|0x33,
        (7<<20)|(7<<15)|(12<<7)|0x63,store(6,5),add(10,0,123)]
    case('wrong_path_exit',body,7,retired=7)
    directory=out/'smoke';directory.mkdir(exist_ok=True)
    rows=[]
    for name,instructions,expected,data,retired in tests:
        image=directory/f'{name}.data'
        memory={i<<2:word for i,word in enumerate(instructions)}|data
        image.write_text('\n'.join(f'@{addr:08x}\n'+' '.join(f'{(word>>(b<<3))&255:02x}' for b in range(4))
            for addr,word in sorted(memory.items()))+'\n')
        run=subprocess.run([str(out/'obj/Vcourse_sync_top'),str(image),str(expected),str(retired)],capture_output=True,text=True,timeout=60)
        rows.append(dict(case=name,passed=run.returncode==0,stdout=run.stdout,stderr=run.stderr))
        print(name,run.stdout+run.stderr,flush=True)
        if run.returncode:break
    passed=len(rows)==len(tests) and all(r['passed'] for r in rows)
    (out/'smoke-report.json').write_text(json.dumps(dict(passed=passed,rows=rows),indent=2)+'\n')
    if not passed:raise SystemExit(1)


if __name__=='__main__':main()
