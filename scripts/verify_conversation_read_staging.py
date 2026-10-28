#!/usr/bin/env python3
"""Explicit live staging acceptance. No high-privilege credentials or private payload logging.

Uses only A/B user sessions in a mode-0600 config. Test fixture IDs are checkpointed
in that ignored config. Reports contain check aliases and statuses, never tokens,
user IDs, message bodies, invite credentials, financial or health values.
"""
import argparse,json,os,stat,time,uuid,base64,sys,re
from pathlib import Path
from urllib.request import Request,build_opener,HTTPRedirectHandler
from urllib.parse import urlencode
from urllib.error import HTTPError,URLError
parser=argparse.ArgumentParser(description='Run real A/B read-cursor acceptance using ordinary staging user JWTs. Creates synthetic test squads/plans/messages and updates test cursors.')
parser.add_argument('--config',required=True)
parser.add_argument('--environment',required=True)
parser.add_argument('--report',required=True)
parser.add_argument('--allow-test-writes',action='store_true')
args=parser.parse_args()
if not args.allow_test_writes: parser.error('--allow-test-writes is required; this acceptance writes synthetic fixtures')
CONFIG=Path(args.config)
REPORT=Path(args.report)
if CONFIG.is_symlink(): parser.error('Use a regular private config file')
if REPORT.exists(): parser.error('Report already exists; choose a new report path')
class NoRedirect(HTTPRedirectHandler):
 def redirect_request(self,*a,**kw): return None
opener=build_opener(NoRedirect())
c=json.loads(CONFIG.read_text())
assert stat.S_IMODE(CONFIG.stat().st_mode)==0o600
assert args.environment==c['environmentId']=='squadly-staging-d1fjsdpkc562fa9c' and c['region']=='ap-shanghai'
assert all(c['actors'][n].get('userId') and c['actors'][n].get('jwt') for n in ['a','b'])
assert c['actors']['a']['userId']!=c['actors']['b']['userId']
assert c['actors']['a']['jwt']!=c['actors']['b']['jwt']
for value in [c['publishableKey'],c['actors']['a']['jwt'],c['actors']['b']['jwt']]:
 assert not re.search(r'service[_-]?role|secret[_-]?key',value,re.I)
 parts=value.split('.')
 if len(parts)==3:
  claims=json.loads(base64.urlsafe_b64decode(parts[1]+'='*(-len(parts[1])%4)))
  assert claims.get('role') not in ('service_role','supabase_admin','postgres')
base='https://'+c['environmentId']+'.api.tcloudbasegateway.com'
checks=[]
def save():
 temp=CONFIG.with_suffix('.json.tmp')
 fd=os.open(temp,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
 with os.fdopen(fd,'w') as f: json.dump(c,f,ensure_ascii=False,indent=2)
 os.replace(temp,CONFIG)
def http(path,actor='a',body=None,method=None,prefer=None,device_id=None):
 headers={'Content-Type':'application/json','Accept':'application/json','x-device-id':device_id or c['actors'].get(actor,{}).get('deviceId','squadly-staging-account-setup'),'x-request-id':uuid.uuid4().hex}
 if actor is not None: headers['Authorization']='Bearer '+(c['publishableKey'] if actor=='anonymous' else c['actors'][actor]['jwt'])
 if prefer: headers['Prefer']=prefer
 req=Request(base+path,data=json.dumps(body).encode() if body is not None else None,headers=headers,method=method or ('POST' if body is not None else 'GET'))
 try:
  with opener.open(req,timeout=25) as r:
   raw=r.read(); data=json.loads(raw) if raw else None
   return r.status,data
 except HTTPError as e:
  try: data=json.loads(e.read())
  except Exception: data={}
  return e.code,data
 except (URLError,TimeoutError): return 0,{}
def get(table,actor='a',**params): return http('/v1/rdb/rest/'+table+'?'+urlencode(params),actor)
def rpc(name,body,actor='a'): return http('/v1/rdb/rest/rpc/'+name,actor,body)
def ok(result,label):
 status,data=result
 if status not in (200,201,204) or isinstance(data,dict) and data.get('error'):
  code=data.get('code',data.get('error','unknown')) if isinstance(data,dict) else 'unknown'
  if not isinstance(code,str) or not re.fullmatch(r'[A-Za-z0-9_.-]{1,80}',code): code='unknown'
  raise RuntimeError(label+': http='+str(status)+' code='+code)
 return data
def check(label,passed,status=None):
 checks.append({'check':label,'status':'pass' if passed else 'fail',**({'httpStatus':status} if status is not None else {})})
 print(label+': '+('pass' if passed else 'FAIL'),flush=True)
 if not passed: raise RuntimeError(label)
def preflight():
 for name in ['a','b']:
  actor=c['actors'][name]
  parts=actor['jwt'].split('.')
  claims=json.loads(base64.urlsafe_b64decode(parts[1]+'='*(-len(parts[1])%4))) if len(parts)==3 else {}
  if claims.get('exp',0)<time.time()+300 or time.time()-actor.get('authenticatedAt',0)>3600:
   token=ok(http('/auth/v1/token?client_id='+c['environmentId'],None,{'client_id':c['environmentId'],'grant_type':'refresh_token','refresh_token':actor['refresh_token']},device_id=actor.get('deviceId')),'refresh_'+name)
   token=token.get('data',token)
   actor['jwt']=token['access_token']
   for key in ['refresh_token','expires_in','expires_at']:
    if key in token: actor[key]=token[key]
   actor['authenticatedAt']=int(time.time())
   save()
  identity=ok(http('/auth/v1/user/me?client_id='+c['environmentId'],name),'identity_'+name)
  identity=identity.get('data',identity)
  check(name+'_authenticated_identity',(identity.get('sub') or identity.get('uid'))==actor['userId'])
  rows=ok(get('squad_members',name,select='id,squad_id,role',user_id='eq.'+actor['userId']),'memberships_'+name)
  print(name.upper()+' existing memberships: '+str(len(rows)),flush=True)
def row(result,label):
 data=ok(result,label)
 if not isinstance(data,list) or len(data)!=1: raise RuntimeError(label+': expected one row')
 return data[0]
def denied(result,label,sql_code='42501'):
 status,data=result
 code=data.get('code') if isinstance(data,dict) else None
 allowed_code=code in (sql_code,'DATABASE_'+sql_code,None) or label.startswith('anonymous_') and code=='INVALID_CREDENTIALS'
 check(label,status in (401,403) and allowed_code,status)
def receipt(message,squad,plan=None,actor='a'):
 data=ok(rpc('get_message_read_receipts',{'p_squad_id':squad,'p_plan_id':plan,'p_message_ids':[message]},actor),'receipt_load')
 if not isinstance(data,list) or len(data)!=1 or data[0].get('message_id')!=message: raise RuntimeError('receipt_shape')
 return data[0]['members']
def advance(message,squad,plan=None,actor='b'):
 return rpc('advance_conversation_read_cursor',{'p_squad_id':squad,'p_plan_id':plan,'p_message_id':message},actor)
def setup():
 f=c.setdefault('readReceiptAcceptance',{'runId':uuid.uuid4().hex[:12],'createdAt':int(time.time())})
 assert re.fullmatch(r'[0-9a-f]{12}',f['runId'])
 for label in ['memberSquad','otherSquad']:
  if label not in f:
   d=ok(rpc('create_squad',{'p_name':'验收测试-已读-'+f['runId']+('-隔离' if label=='otherSquad' else ''),'p_description':'自动化 staging 合成测试数据，不含真实业务内容'}),'create_'+label)
   f[label]=d['id']; save()
 squad=f['memberSquad']
 own=ok(get('squads',id='eq.'+squad,select='id'),'owner_squad_read')
 check('owner_squad_positive_control',len(own)==1 and own[0]['id']==squad)
 metadata=row(get('squads',id='eq.'+squad,select='id,name,created_by'),'fixture_squad_identity')
 check('fixture_is_dedicated_test_squad',metadata['name']=='验收测试-已读-'+f['runId'] and metadata['created_by']==c['actors']['a']['userId'])
 members=ok(get('squad_members',select='id,user_id,role',squad_id='eq.'+squad),'members_before_join')
 if not any(m['user_id']==c['actors']['b']['userId'] for m in members):
  invisible=ok(get('squads','b',id='eq.'+squad,select='id'),'nonmember_squad_read')
  check('nonmember_cannot_read_squad',invisible==[])
  invitation=ok(rpc('issue_invitation',{'p_squad_id':squad,'p_max_uses':1}),'issue_invitation')
  joined=ok(rpc('redeem_invitation',{'p_credential':invitation['code']},'b'),'redeem_invitation')
  check('invitation_join_activates_squad',joined.get('id')==squad and joined.get('status')=='active')
  repeated=rpc('redeem_invitation',{'p_credential':invitation['code']},'b')
  check('single_use_invitation_cannot_replay',repeated[0]==200 and repeated[1].get('error')=='invalid_invitation')
  f['joinedWithInvitation']=True; save()
 members=ok(get('squad_members',select='id,user_id,role',squad_id='eq.'+squad),'members_after_join')
 check('two_members_roles',len(members)==2 and any(m['role']=='captain' and m['user_id']==c['actors']['a']['userId'] for m in members) and any(m['role']=='member' and m['user_id']==c['actors']['b']['userId'] for m in members))
 f['memberships']={n:next(m['id'] for m in members if m['user_id']==c['actors'][n]['userId']) for n in ['a','b']}; save()
 for label,visibility in [('sharedPlan','squad'),('privatePlan','private')]:
  if label not in f:
   plan=uuid.uuid4().__str__()
   d=row(http('/v1/rdb/rest/squad_plans','a',{'id':plan,'squad_id':squad,'title':'已读验收-'+visibility,'category':'custom','visibility':visibility,'created_by':c['actors']['a']['userId']},prefer='return=representation'),'create_'+label)
   check(label+'_created',d['id']==plan and d['squad_id']==squad and d['visibility']==visibility)
   f[label]=plan; save()
 return f

def tests(f):
 squad=f['memberSquad']; shared=f['sharedPlan']; private=f['privatePlan']
 f['latestMessages']={}; save()
 def send(label,actor='a',plan=None):
  params={'p_squad_id':squad,'p_body':'已读验收合成消息 '+label,'p_client_nonce':str(uuid.uuid4())}
  name='send_text_message'
  if plan is not None: name='send_squad_plan_message'; params['p_plan_id']=plan
  d=ok(rpc(name,params,actor),'send_'+label)
  if not d.get('id') or d.get('sender_id')!=c['actors'][actor]['userId'] or d.get('squad_id')!=squad or d.get('plan_id')!=plan: raise RuntimeError('send_projection_'+label)
  f['latestMessages'][label]=d['id']; save()
  return d['id']
 g1=send('general_1'); g2=send('general_2'); p1=send('plan_1',plan=shared); p2=send('plan_2',plan=shared); priv=send('private_1',plan=private)
 bmsg=send('reader_own','b')
 def member_status(mid,plan=None,expected='unread'):
  m=receipt(mid,squad,plan)
  return len(m)==1 and m[0]['user_id']==c['actors']['b']['userId'] and m[0]['membership_id']==f['memberships']['b'] and m[0]['status']==expected and set(m[0])=={'membership_id','user_id','nickname','status'}
 check('initial_general_unread',member_status(g1))
 check('initial_plan_unread',member_status(p1,shared))
 denied(rpc('get_message_read_receipts',{'p_squad_id':squad,'p_message_ids':[g1]},'b'),'only_author_can_load_details')
 denied(rpc('get_message_read_receipts',{'p_squad_id':squad,'p_message_ids':[g1,bmsg]}),'mixed_author_batch_denied')
 denied(advance(g1,squad,actor='anonymous'),'anonymous_cursor_denied')
 denied(rpc('get_message_read_receipts',{'p_squad_id':squad,'p_message_ids':[g1]},'anonymous'),'anonymous_details_denied')
 denied(advance(g1,f['otherSquad']),'nonmember_other_squad_denied')
 denied(advance(g1,squad,shared),'general_id_cannot_advance_plan')
 denied(advance(p1,squad),'plan_id_cannot_advance_general')
 denied(advance(priv,squad,private),'private_plan_cursor_denied')
 denied(rpc('get_message_read_receipts',{'p_squad_id':squad,'p_plan_id':private,'p_message_ids':[priv]},'b'),'private_plan_details_denied')
 check('private_plan_owner_no_other_members',receipt(priv,squad,private)==[])
 private_b=ok(get('squad_plans','b',id='eq.'+private,select='id'),'private_plan_nonowner')
 private_a=ok(get('squad_plans','a',id='eq.'+private,select='id'),'private_plan_owner')
 check('private_plan_read_isolation',private_b==[] and len(private_a)==1)
 private_message_b=ok(get('squad_messages','b',id='eq.'+priv,select='id'),'private_message_nonowner')
 check('private_discussion_read_isolation',private_message_b==[])
 ok(advance(g1,squad),'advance_general_first')
 check('reader_advance_changes_author_projection',member_status(g1,expected='read'))
 check('later_general_remains_unread',member_status(g2))
 check('general_advance_does_not_read_plan',member_status(p1,shared))
 ok(advance(g2,squad),'advance_general_second')
 ok(advance(g1,squad),'advance_general_older')
 ok(advance(g2,squad),'advance_general_replay')
 check('older_and_replayed_cursor_does_not_regress',member_status(g2,expected='read'))
 newg=send('general_after_plan')
 ok(advance(p1,squad,shared),'advance_plan_first')
 check('plan_reader_projection_read',member_status(p1,shared,'read'))
 check('later_plan_remains_unread',member_status(p2,shared))
 check('plan_advance_does_not_read_general',member_status(newg))
 ok(advance(p2,squad,shared),'advance_plan_second')
 ok(advance(p1,squad,shared),'advance_plan_older')
 check('plan_cursor_monotonic',member_status(p2,shared,'read'))
 for label,ids in [('empty',[]),('duplicate',[g1,g1]),('over_limit',[str(uuid.uuid4()) for _ in range(51)]),('null',[None])]:
  status,d=rpc('get_message_read_receipts',{'p_squad_id':squad,'p_message_ids':ids})
  check('invalid_batch_'+label+'_rejected',status==400 and d.get('code') in ('22023','DATABASE_22023'),status)
 own_b=ok(get('conversation_read_cursors','b',select='membership_id,thread_key,read_message_id',membership_id='eq.'+f['memberships']['b'],squad_id='eq.'+squad),'read_own_cursor')
 other_b=ok(get('conversation_read_cursors','a',select='membership_id,thread_key,read_message_id',membership_id='eq.'+f['memberships']['b'],squad_id='eq.'+squad),'read_other_cursor')
 check('raw_cursor_positions_owner_only',len(own_b)==2 and other_b==[])
 write_body={'membership_id':f['memberships']['a'],'squad_id':squad,'read_message_id':newg,'read_message_created_at':'2020-01-01T00:00:00Z'}
 denied(http('/v1/rdb/rest/conversation_read_cursors','b',write_body),'direct_cursor_insert_for_other_member_denied')
 own_body={**write_body,'membership_id':f['memberships']['b']}
 denied(http('/v1/rdb/rest/conversation_read_cursors','b',own_body),'direct_own_cursor_insert_denied')
 denied(http('/v1/rdb/rest/conversation_read_cursors?'+urlencode({'membership_id':'eq.'+f['memberships']['b']}),'b',{'read_message_id':newg},method='PATCH'),'direct_cursor_update_denied')
 denied(http('/v1/rdb/rest/conversation_read_cursors?'+urlencode({'membership_id':'eq.'+f['memberships']['b']}),'b',method='DELETE'),'direct_cursor_delete_denied')
 check('denied_writes_do_not_change_cursor',member_status(newg))
 member_invitation=rpc('issue_invitation',{'p_squad_id':squad},'b')
 check('member_cannot_issue_invitation',member_invitation[0]==200 and member_invitation[1].get('error')=='not_captain')
 status,d=rpc('leave_squad',{'p_squad_id':squad},'b')
 check('two_member_minimum_enforced',status==400 and d.get('message')=='squad_minimum_two',status)
 batch=ok(rpc('get_message_read_receipts',{'p_squad_id':squad,'p_message_ids':[newg,g1,g2]}),'author_batch_order')
 check('author_batch_preserves_request_order',[r['message_id'] for r in batch]==[newg,g1,g2])
 for n in ['a','b']:
  identity=ok(http('/auth/v1/user/me?client_id='+c['environmentId'],n),'end_identity_'+n)
  identity=identity.get('data',identity)
  check(n+'_end_identity_positive_control',(identity.get('sub') or identity.get('uid'))==c['actors'][n]['userId'])
  final=ok(get('squads',n,select='id',id='eq.'+squad),'end_squad_'+n)
  check(n+'_end_squad_positive_control',len(final)==1 and final[0]['id']==squad)

def report(error=None):
 d={'environmentId':c['environmentId'],'finishedAt':int(time.time()),'passed':error is None,'checks':checks,'notVerified':['third_account_visibility','leave_rejoin_membership_boundaries','same_timestamp_server_ordering','foreground_visibility_on_real_devices','flutter_sdk_session_refresh','all_feature_access_matrix']}
 if error: d['stoppedAt']=error
 REPORT.write_text(json.dumps(d,indent=2))
 print('Report saved: '+str(REPORT),flush=True)
def run():
 preflight()
 f=setup()
 tests(f)
 report()
if __name__=='__main__':
 try: run()
 except Exception as e:
  error=str(e) if isinstance(e,RuntimeError) else type(e).__name__
  print('Acceptance stopped: '+error,flush=True)
  report(error)
  raise SystemExit(1)
