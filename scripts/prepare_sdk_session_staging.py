#!/usr/bin/env python3
"""Provision/collect only controlled C credentials in the isolated iOS host."""
import argparse,base64,json,os,stat,subprocess,time,uuid
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('--config',required=True)
parser.add_argument('--device',required=True)
parser.add_argument('--collect',action='store_true')
parser.add_argument('--allow-test-writes',action='store_true')
a=parser.parse_args();assert a.allow_test_writes
assert str(uuid.UUID(a.device)).lower()==a.device.lower()
p=Path(a.config);assert not p.is_symlink() and stat.S_IMODE(p.stat().st_mode)==0o600
c=json.loads(p.read_text());assert c['environmentId']=='squadly-staging-d1fjsdpkc562fa9c' and c['region']=='ap-shanghai'
actor=c['actors']['c']
root=Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.device,'com.example.squadlyIntegrationTest','data'],text=True).strip())/'Documents'
source=root/'sdk-session-staging-fixture.json';output=root/'sdk-session-staging-output.json'
if a.collect:
    assert not output.is_symlink() and stat.S_IMODE(output.stat().st_mode)==0o600
    try:
        value=json.loads(output.read_text());claim=json.loads(base64.urlsafe_b64decode(value['accessToken'].split('.')[1]+'==='))
        assert claim['sub']==actor['userId'] and claim.get('role') in ('user','authenticated') and claim.get('is_system_admin') is not True and claim['exp']>time.time()+60
        actor['jwt']=value['accessToken'];actor['refresh_token']=value['refreshToken'];actor['authenticatedAt']=int(time.time());actor['expires_at']=claim['exp']
        temp=p.with_suffix('.json.tmp');fd=os.open(temp,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
        with os.fdopen(fd,'w')as stream:json.dump(c,stream,ensure_ascii=False,indent=2)
        os.replace(temp,p)
        print('Controlled C SDK refreshed session collected; no credential values reported.')
    finally:
        for path in (source,output):
            if path.exists():path.unlink()
else:
    claim=json.loads(base64.urlsafe_b64decode(actor['jwt'].split('.')[1]+'==='));assert claim['sub']==actor['userId'] and claim.get('role') in ('user','authenticated') and claim.get('is_system_admin') is not True
    assert not source.exists() and not output.exists()
    value={'environmentId':c['environmentId'],'region':c['region'],'publishableKey':c['publishableKey'],'userId':actor['userId'],'deviceId':actor['deviceId'],'accessToken':actor['jwt'],'refreshToken':actor['refresh_token'],'photoGateway':c['photoAcceptance']['workerUrl']}
    for path,data in ((source,json.dumps(value)),(output,'')):
        fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
        with os.fdopen(fd,'w')as stream:stream.write(data)
    print('Controlled C fixture and empty result created mode 0600; no A/B sessions copied or changed.')
