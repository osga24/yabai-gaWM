from pathlib import Path
import json,subprocess,os
import tempfile,shutil
repo=Path(__file__).resolve().parents[1]
_temp=tempfile.TemporaryDirectory(prefix="gawm-test-")
base=Path(_temp.name)
shutil.copy2(repo/"src/wm-compat/main.m",base/"main.m")
stub=base/'fake-yabai'
stub.write_text('''#!/usr/bin/python3
import sys,json,os
from pathlib import Path
p=Path(os.environ['WM_TEST_STATE']);d=json.loads(p.read_text());a=sys.argv[2:]
if a[0]=='query':
 print(json.dumps({'type':'bsp'} if a[1]=='--spaces' else d['window']))
elif '--resize' in a:
 handle=a[-1].split(':');d.setdefault('calls',[]).append(a[-1]);x=int(handle[1]);y=int(handle[2]);f=d['window']['frame']
 if not d.get('blocked'):
  sign=-1 if d.get('reverse') else 1
  f['w']+=sign*(x if handle[0]=='right' else -x if handle[0]=='left' else 0)
  f['h']+=sign*(y if handle[0]=='bottom' else -y if handle[0]=='top' else 0)
 p.write_text(json.dumps(d))
''');stub.chmod(0o755)
binary=base/'wm-test'
subprocess.run(['xcrun','clang','-O2','-fobjc-arc',f'-DYABAI_PATH=@"{stub}"',str(base/'main.m'),'-framework','Cocoa','-o',str(binary)],check=True)
for axis in ['vertical','horizontal']:
 for child in ['first_child','second_child']:
  for delta in [-50,50]:
   p=base/'state.json';w={'id':42,'space':1,'split-type':axis,'split-child':child,'frame':{'w':600,'h':400}}
   p.write_text(json.dumps({'window':w}));r=subprocess.run([str(binary),'resize',str(delta)],env={**os.environ,'WM_TEST_STATE':str(p)},capture_output=True)
   d=json.loads(p.read_text());key='w' if axis=='vertical' else 'h';assert r.returncode==0,(r.stderr,d);assert d['window']['frame'][key]==w['frame'][key]+delta
for mode in ['blocked','reverse']:
 p.write_text(json.dumps({'window':{'id':42,'space':1,'split-type':'vertical','split-child':'second_child','frame':{'w':600,'h':400}},mode:True}))
 r=subprocess.run([str(binary),'resize','-50'],env={**os.environ,'WM_TEST_STATE':str(p)},capture_output=True)
 d=json.loads(p.read_text());assert r.returncode!=0;assert d['window']['frame']['w']==600
 assert len(d['calls'])==(2 if mode=='reverse' else 1)
print('Passed 10 behavioral cases: both axes/children, grow/shrink, no-op limit, inverse recovery.')
