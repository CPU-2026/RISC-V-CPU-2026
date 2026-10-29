#!/usr/bin/env python3
"""Production ISSUE_WIDTH configuration and unchanged 1/2-lane RTL behavior.

Use an immutable --before snapshot for real old/new independent-ISA comparisons.
Four-width package support includes integrated core startup; full four-lane ISA
qualification and PPA are separate from this configuration checker.
"""
import argparse
import fcntl
import hashlib
import importlib.util
import itertools
import json
import os
from pathlib import Path
import resource
import subprocess
import sys

from build import read_sources
from fakeram import with_ram_source
from sv_frontend import convert_sources

ROOT=Path(__file__).resolve().parents[1]
WORKSPACE=ROOT.parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text())
def save(p,x):
    p.parent.mkdir(parents=True,exist_ok=True);q=p.with_suffix(p.suffix+'.tmp')
    q.write_text(json.dumps(x,indent=2)+'\n');q.replace(p)
def intact(inputs):return all(Path(p).is_file() and sha(Path(p))==h for p,h in inputs.items())
def staged_checker(folder,source,public):
    folder.mkdir(parents=True,exist_ok=True)
    original=source/'scripts/check_rename_width.py';text=original.read_text()
    old="'--assert', '--unroll-count', '1024',";assert text.count(old)==1
    text=text.replace(old,"'--assert', '--unroll-count', '1024', '--unroll-stmts', '100000',")
    if public:
        old="('RENAME_WIDTH', rename)";assert text.count(old)==1;text=text.replace(old,"('ISSUE_WIDTH', rename)")
    path=folder/'checker.py'
    if path.exists():assert path.read_text()==text
    else:path.write_text(text)
    spec=importlib.util.spec_from_file_location('issue_width_rtl_checker',path)
    checker=importlib.util.module_from_spec(spec);spec.loader.exec_module(checker)
    checker.ROOT=source;checker.SOFTWARE=WORKSPACE/'RV32IM_Simulator'
    return checker

def units(out):
    folder=out/'units';folder.mkdir(parents=True,exist_ok=True)
    pkg=ROOT/'verilog/rtl/common/rv32_pkg.sv';guard=ROOT/'verilog/rtl/common/rv32_issue_config.sv'
    tb=ROOT/'scripts/tests/issue_config_tb.sv';supported_four=ROOT/'scripts/tests/four_issue_config_tb.sv'
    rtl=with_ram_source(read_sources(ROOT/'verilog/filelist.f'))
    inputs={str(p):sha(p) for p in [*rtl,tb,supported_four,Path(__file__)]};rows=[]
    report=folder/'report.json'
    if report.exists():
        old=read(report)
        if old.get('passed') and old['inputs']==inputs and intact(inputs):return old
    def run(name,files,defines,negative=None,top='tb_issue_config'):
        work=folder/name;work.mkdir(exist_ok=True)
        command=['verilator','--binary','--timing','--assert','--unroll-count','1024','--unroll-stmts','100000',
            '-Wno-fatal','-j','2','--top-module',top,'--Mdir',str(work/'obj'),*defines,*map(str,files)]
        with (work/'build.log').open('w') as log:subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,check=True)
        text=(work/'build.log').read_text();assert '%Warning-UNOPTFLAT' not in text and '%Warning-LATCH' not in text
        result=subprocess.run([str(work/'obj'/('V'+top))],capture_output=True,text=True,timeout=60)
        text=result.stdout+result.stderr;(work/'run.log').write_text(text)
        if negative:assert result.returncode!=0 and negative in text,text
        else:assert result.returncode==0 and 'PASS issue-width configuration' in text,text
        rows.append(dict(name=name,passed=True,negative=bool(negative),exit_code=result.returncode,output=text))
        print('PASS',name,flush=True)
    configurations=[('default',[],1),*[(f'public-{w}',[f'-DCPU_ISSUE_WIDTH={w}'],w) for w in (1,2,4)],
        *[(f'legacy-{w}',[f'-DCPU_RENAME_WIDTH={w}'],w) for w in (1,2,4)],
        ('matching-aliases',['-DCPU_ISSUE_WIDTH=2','-DCPU_RENAME_WIDTH=2'],2)]
    for name,defines,width in configurations:
        defines=[*defines,f'-DEXPECT_ISSUE_WIDTH={width}'];run(name,[pkg,guard,tb],defines)
        converted,manifest=convert_sources(str(Path.home()/'.local/bin/sv2v'),[pkg,guard,tb],folder/(name+'-sv2v'),
            top='tb_issue_config',defines=tuple(x.removeprefix('-D') for x in defines))
        run(name+'-converted',[converted],[])
    for name,defines,diagnostic in [
        ('conflicting-aliases',['-DCPU_ISSUE_WIDTH=1','-DCPU_RENAME_WIDTH=2'],'conflicts with legacy'),
        ('invalid-zero',['-DCPU_ISSUE_WIDTH=0'],'must be 1, 2 or 4'),
        ('invalid-three',['-DCPU_ISSUE_WIDTH=3'],'must be 1, 2 or 4')]:
        run(name,[pkg,guard,tb],[*defines,'-DEXPECT_ISSUE_WIDTH=1'],diagnostic)
    run('four-core-integrated',[*rtl,supported_four],['-DCPU_ISSUE_WIDTH=4','-DCPU_DECODE_WIDTH=4'],
        top='tb_four_issue_config')
    assert intact(inputs)
    result=dict(passed=True,inputs=inputs,inputs_unchanged=True,rows=rows,
        scope='1/2/4 configuration/type contracts native/sv2v, conflict/invalid rejection and integrated four-core startup; not full ISA or PPA qualification')
    save(report,result);return result

def lint(out):
    folder=out/'lint';folder.mkdir(parents=True,exist_ok=True)
    rtl=with_ram_source(read_sources(ROOT/'verilog/filelist.f'));inputs={str(p):sha(p) for p in rtl};rows=[]
    report=folder/'report.json'
    if report.exists():
        old=read(report)
        if old.get('passed') and old['inputs']==inputs and intact(inputs):return old
    configurations=[]
    for f,d,i,c in itertools.product((1,2),repeat=4):
        configurations.append((f'f{f}d{d}i{i}c{c}',[f'-DCPU_{key}_WIDTH={value}' for key,value in
            [('FETCH',f),('DECODE',d),('ISSUE',i),('COMMIT',c)]]))
    configurations += [('local-legacy-two',['-GRENAME_WIDTH=2']),('local-public-two',['-GISSUE_WIDTH=2'])]
    for name,defines in configurations:
        result=subprocess.run(['verilator','--lint-only','--assert','--unroll-count','1024','--unroll-stmts','100000',
            '-Wno-fatal','--top-module','student_top',*defines,*map(str,rtl)],capture_output=True,text=True,timeout=120)
        text=result.stdout+result.stderr;(folder/(name+'.log')).write_text(text)
        assert result.returncode==0 and '%Warning-UNOPTFLAT' not in text and '%Warning-LATCH' not in text,text[-12000:]
        rows.append(dict(name=name,passed=True));print('PASS lint',name,flush=True)
    assert intact(inputs);result=dict(passed=True,inputs=inputs,inputs_unchanged=True,rows=rows)
    save(report,result);return result

def real_rtl(out,before,directed):
    results={}
    for width in (1,2):
        for mode,source,public,pattern in [('before',before,False,'*'),('public',ROOT,True,'*'),('legacy',ROOT,False,'perf_*')]:
            name=f'{mode}-{width}';folder=out/'rtl'/name;report=folder/'report.json'
            if report.exists() and read(report).get('passed'):
                r=read(report);assert intact(r['inputs'])
                assert sha(folder/f'rename-{width}/obj/Vdecode_course_top')==r['profiles'][0]['binary_sha256']
            else:
                checker=staged_checker(out/'harness'/name,source,public)
                options=argparse.Namespace(out=folder,pattern=pattern,directed_report=directed,software_report=None,
                    baseline_binary=None,fetch_width=2,decode_width=width,commit_width=2,rename_width=[width],
                    jobs=2,case_jobs=1,skip_build=False)
                checker.run(options);r=read(report)
            assert r['passed'] and len(r['profiles'][0]['directed'])==18
            results[name]=r
        old=results[f'before-{width}']['profiles'][0];new=results[f'public-{width}']['profiles'][0]
        assert len(old['rows'])==25 and old['rows']==new['rows'] and old['directed']==new['directed']
        legacy=results[f'legacy-{width}']['profiles'][0]
        assert legacy['rows']==[r for r in new['rows'] if r['case'].startswith('perf_')]
        assert legacy['directed']==new['directed']
        print('PASS exact old/public/legacy cycles/events/retirements/trace width',width,flush=True)
    return dict(passed=True,old_new_full25_and_directed_exact=True,legacy_six_perf_and_directed_exact=True,
        reports={name:sha(out/'rtl'/name/'report.json') for name in results})

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before',type=Path,default=Path('/tmp/opencode/issue-width-production-20261026/before'))
    parser.add_argument('--out',type=Path,default=Path('/tmp/opencode/issue-width-production-20261026/checks'))
    parser.add_argument('--phase',choices=('all','units','lint','rtl'),default='all')
    parser.add_argument('--directed-report',type=Path,default=Path('/tmp/opencode/wide4-bringup-20261026/directed-images/report.json'))
    args=parser.parse_args();out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
    resource.setrlimit(resource.RLIMIT_CORE,(0,0));os.sched_setaffinity(0,sorted(os.sched_getaffinity(0))[:2])
    lock=Path('/tmp/opencode/load-abc-20261021/heavy-job.lock');lock.parent.mkdir(parents=True,exist_ok=True)
    with lock.open('a') as guard:
        fcntl.flock(guard,fcntl.LOCK_EX)
        if os.getpriority(os.PRIO_PROCESS,0)<10:os.nice(10-os.getpriority(os.PRIO_PROCESS,0))
        job=dict(status='running',four_core_implemented=True,stages={});save(out/'report.json',job)
        try:
            for name in ('units','lint','rtl') if args.phase=='all' else (args.phase,):
                job['current_stage']=name;save(out/'report.json',job)
                if name=='units':result=units(out)
                elif name=='lint':result=lint(out)
                else:result=real_rtl(out,args.before.resolve(),args.directed_report.resolve())
                job['stages'][name]=result;save(out/'report.json',job)
            job.update(status='complete',passed=True,current_stage=None);save(out/'report.json',job)
        except Exception as error:
            job.update(status='failed',passed=False,error=str(error));save(out/'report.json',job);raise

if __name__=='__main__':main()
