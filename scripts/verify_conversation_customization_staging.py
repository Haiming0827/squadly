#!/usr/bin/env python3
"""Ordinary SDK A/B permissions on a new synthetic staging Squad. No token refresh."""
import argparse
import base64
import json
import os
from pathlib import Path
import plistlib
import stat
import subprocess
import time
from urllib.error import HTTPError
from urllib.request import Request, build_opener, HTTPRedirectHandler
import uuid

parser=argparse.ArgumentParser()
parser.add_argument('--config',required=True)
parser.add_argument('--fixture-file',required=True)
parser.add_argument('--report',required=True)
parser.add_argument('--allow-test-writes',action='store_true')
args=parser.parse_args()
assert args.allow_test_writes
assert not Path(args.report).exists(), 'Use a fresh evidence path'
path=Path(args.config)
assert not path.is_symlink() and stat.S_IMODE(path.stat().st_mode)==0o600
config=json.loads(path.read_text())
assert config['environmentId']=='squadly-staging-d1fjsdpkc562fa9c' and config['region']=='ap-shanghai'
base='https://'+config['environmentId']+'.api.tcloudbasegateway.com/v1/rdb/rest/'
actors={}
for alias,device in [('a','370493B7-843A-47ED-AE82-7CB75E21691E'),('b','DA33717A-0E70-4727-8623-A22CED1A5432')]:
    root=Path(subprocess.check_output(['xcrun','simctl','get_app_container',device,'com.squadly.squadly','data'],text=True).strip())
    prefs=plistlib.loads((root/'Library/Preferences/com.squadly.squadly.plist').read_bytes())
    sdk=json.loads(prefs['flutter.credentials_'+config['environmentId']])
    token=sdk['access_token']
    claim=json.loads(base64.urlsafe_b64decode(token.split('.')[1]+'==='))
    assert sdk['user']['id']==config['actors'][alias]['userId']==claim['sub']
    assert claim.get('role') in ('user','authenticated') and claim.get('is_system_admin') is not True
    assert claim['exp']>time.time()+300, 'Reopen the actual App to renew its SDK session; token values redacted'
    actors[alias]={'token':token,'id':claim['sub']}
class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self,*unused): return None
opener=build_opener(NoRedirect())
checks=[]
def check(label,condition):
    checks.append({'check':label,'passed':bool(condition)})
    if not condition: raise RuntimeError('Customization check failed: '+label+'; response redacted')
    print(label+': pass',flush=True)
def request(path,alias='a',body=None,method=None):
    token=config['publishableKey'] if alias=='anonymous' else actors[alias]['token']
    req=Request(base+path,headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'},method=method or ('POST' if body is not None else 'GET'),data=None if body is None else json.dumps(body).encode())
    try:
        with opener.open(req,timeout=40) as response: return response.status,json.loads(response.read())
    except HTTPError as error:
        try: value=json.loads(error.read(65536))
        except ValueError: value=None
        return error.code,value

def rpc(name,body,alias='a'): return request('rpc/'+name,alias,body)
def ok(result,label):
    code,value=result
    check(label,code==200 and not(isinstance(value,dict) and value.get('error')))
    return value

def pref(alias,squad): return next(v for v in ok(rpc('get_conversation_preferences',{},alias),alias+'_load_preferences') if v['squad_id']==squad)
fixture=None
try:
    if Path(args.fixture_file).exists():
        fixture=json.loads(Path(args.fixture_file).read_text())
        assert fixture['environmentId']==config['environmentId'] and fixture['createdByThisScript'] is True
        squad=fixture['squadId']
        rows=ok(request('squads?id=eq.'+squad+'&select=name,created_by'),'verify_owned_fixture')
        check('fixture_owner_and_scope',len(rows)==1 and rows[0]['created_by']==actors['a']['id'] and rows[0]['name'].startswith('会话设置验收-'))
    else:
        squad=ok(rpc('create_squad',{'p_name':'会话设置验收-'+uuid.uuid4().hex[:6],'p_description':'合成测试小队，供会话设置交互验收'}),'create_owned_squad')['id']
        fixture={'environmentId':config['environmentId'],'squadId':squad,'createdByThisScript':True}
        fd=os.open(args.fixture_file,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
        with os.fdopen(fd,'w') as file: json.dump(fixture,file)
    for name,body in [('save_conversation_preference',{'p_squad_id':squad,'p_remark':'forged','p_pinned':True}),('record_conversation_open',{'p_squad_id':squad}),('update_squad_profile',{'p_squad_id':squad,'p_name':'forged','p_description':'','p_avatar':None})]:
        code,value=rpc(name,body,'b');check('nonmember_'+name,code==200 and value.get('error')=='forbidden')
    invitation=ok(rpc('issue_invitation',{'p_squad_id':squad,'p_max_uses':1}),'captain_invitation')
    ok(rpc('redeem_invitation',{'p_credential':invitation['code']},'b'),'member_joins_real_invite')
    ok(rpc('save_conversation_preference',{'p_squad_id':squad,'p_remark':'我的置顶验收','p_pinned':True}),'a_save_private_remark')
    ok(rpc('record_conversation_open',{'p_squad_id':squad}),'a_open_once')
    ok(rpc('record_conversation_open',{'p_squad_id':squad}),'a_open_twice')
    check('a_visit_count',pref('a',squad)['recent_open_count']==2)
    b=pref('b',squad);check('b_cannot_see_a_remark',b['remark']=='' and b['pinned_at'] is None and b['recent_open_count']==0)
    members=ok(request('squad_members?squad_id=eq.'+squad+'&select=id,user_id'),'read_members')
    membership=next(m['id'] for m in members if m['user_id']==actors['a']['id'])
    check('b_preferences_rls',ok(request('conversation_preferences?membership_id=eq.'+membership,'b'),'b_read_a_preferences')==[])
    check('b_visits_rls',ok(request('conversation_open_days?membership_id=eq.'+membership,'b'),'b_read_a_visits')==[])
    ok(rpc('save_conversation_preference',{'p_squad_id':squad,'p_remark':'我的成员备注','p_pinned':False},'b'),'b_save_own_remark')
    ok(rpc('record_conversation_open',{'p_squad_id':squad},'b'),'b_open_once')
    check('a_remark_unchanged',pref('a',squad)['remark']=='我的置顶验收')
    code,value=rpc('update_squad_profile',{'p_squad_id':squad,'p_name':'forged','p_description':'','p_avatar':None},'b')
    check('member_cannot_update_shared_profile',code==200 and value.get('error')=='forbidden')
    avatar='data:image/png;base64,'+base64.b64encode(Path('test/features/squad/fixtures/avatar.png').read_bytes()).decode()
    name='会话设置验收'
    ok(rpc('update_squad_profile',{'p_squad_id':squad,'p_name':name,'p_description':'头像、备注与置顶验收','p_avatar':avatar}),'captain_saves_avatar_name')
    rows=ok(request('squads?id=eq.'+squad+'&select=name,description,avatar_url','b'),'b_read_shared_profile')
    check('b_sees_shared_avatar_name',len(rows)==1 and rows[0]['name']==name and rows[0]['avatar_url']==avatar)
    code,value=rpc('update_squad_profile',{'p_squad_id':squad,'p_name':name,'p_description':'','p_avatar':'https://example.com/private.png'})
    check('external_avatar_url_rejected',code==200 and value.get('error')=='invalid_avatar')
    code,_=request('conversation_preferences','anonymous');check('anonymous_preferences_denied',code in (401,403))
    code,_=rpc('save_conversation_preference',{'p_squad_id':squad,'p_remark':'anon','p_pinned':True},'anonymous');check('anonymous_rpc_denied',code in (401,403))
    code,_=request('squads?id=eq.'+squad,'b',{'name':'forged'},'PATCH');check('direct_update_denied',code in (401,403))
    check('b_alias_independent',pref('b',squad)['remark']=='我的成员备注')
    result={'date':'2026-11-03','environment':'staging','passed':True,'checks':checks,'retainedFixture':'Synthetic two-member Squad retained for Device Hub UI verification; no original Squad modified','notVerified':['physical device','Android native avatar picker','leave/rejoin on CloudBase (local SQL regression only)']}
    Path(args.report).parent.mkdir(parents=True,exist_ok=True)
    Path(args.report).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
except Exception as error:
    raise SystemExit(str(error) if isinstance(error,RuntimeError) else 'Staging verification stopped; diagnostics and credentials redacted')
