#!/usr/bin/env python3
"""Exercise captain-only fund metadata and ledger-only balances in staging."""
import runpy
from pathlib import Path
# Reuse the fixed-staging credential/output guards and explicit write opt-in.
n=runpy.run_path(str(Path(__file__).with_name('verify_conversation_read_staging.py'))); c=n['c'];check=n['check'];ok=n['ok'];row=n['row'];http=n['http'];get=n['get'];denied=n['denied'];save=n['save']
try:
 n['preflight']()
 fixture=c['readReceiptAcceptance']
 squad=fixture['memberSquad']
 metadata=row(get('squads',id='eq.'+squad,select='id,name,created_by'),'fixture_squad_identity')
 if metadata['name']!='验收测试-已读-'+fixture['runId'] or metadata['created_by']!=c['actors']['a']['userId']:
  raise RuntimeError('fixture_is_not_dedicated_test_squad')
 f=c.setdefault('fundPermissionsAcceptance',{});save()
 # Each explicitly authorized run gets a fresh, clearly marked synthetic fund.
 d=row(http('/v1/rdb/rest/public_funds?select=id,current_amount','a',{'squad_id':squad,'created_by':c['actors']['a']['userId'],'name':'验收测试-基金权限修复','fund_type':'custom'},prefer='return=representation'),'captain_create')
 f['fund']=d['id'];save();check('captain_create_zero_balance',float(d['current_amount'])==0)
 fund=f['fund']; q=n['urlencode']({'id':'eq.'+fund,'select':'id'})
 d=row(http('/v1/rdb/rest/public_funds?'+q,'a',{'name':'验收测试-队长编辑','target_amount':100},method='PATCH',prefer='return=representation'),'captain_edit')
 check('captain_metadata_edit',d['id']==fund)
 status,d=http('/v1/rdb/rest/public_funds?'+q,'b',{'name':'Member edit'},method='PATCH',prefer='return=representation')
 check('member_metadata_edit_denied',status==200 and d==[] or status==403,status)
 denied(http('/v1/rdb/rest/public_funds','b',{'squad_id':squad,'created_by':c['actors']['b']['userId'],'name':'Rejected','fund_type':'custom'}),'member_fund_create_denied')
 for actor in ['a','b']:
  denied(http('/v1/rdb/rest/public_funds?'+q,actor,{'current_amount':99},method='PATCH'),'direct_balance_update_denied_'+actor)
 denied(http('/v1/rdb/rest/public_funds','a',{'squad_id':squad,'created_by':c['actors']['a']['userId'],'name':'Rejected','fund_type':'custom','current_amount':0}),'explicit_initial_balance_denied')
 for actor,amount,label in [('b',10,'member_deposit'),('b',-3,'member_expense'),('a',2,'captain_deposit')]:
  result=http('/v1/rdb/rest/fund_transactions',actor,{'fund_id':fund,'user_id':c['actors'][actor]['userId'],'amount':amount,'description':'验收测试-合成流水'},prefer='return=representation')
  data=ok(result,label)
  check(label+'_accepted',len(data)==1)
 denied(http('/v1/rdb/rest/fund_transactions','b',{'fund_id':fund,'user_id':c['actors']['a']['userId'],'amount':1}),'member_cannot_impersonate_ledger_owner')
 denied(http('/v1/rdb/rest/fund_transactions','b',{'fund_id':fund,'user_id':c['actors']['b']['userId'],'amount':1,'approved_by':c['actors']['a']['userId']}),'member_cannot_forge_approver')
 for actor in ['a','b']:
  data=row(get('public_funds',actor,select='id,current_amount',id='eq.'+fund),'balance_'+actor)
  transactions=ok(get('fund_transactions',actor,select='amount',fund_id='eq.'+fund),'ledger_'+actor)
  check('balance_equals_ledger_'+actor,float(data['current_amount'])==9 and sum(float(t['amount']) for t in transactions)==9)
 for actor in ['a','b']:
  identity=ok(http('/auth/v1/user/me?client_id='+c['environmentId'],actor),'final_identity_'+actor)
  identity=identity.get('data',identity)
  check('final_identity_'+actor,(identity.get('sub') or identity.get('uid'))==c['actors'][actor]['userId'])
 n['report']()
except Exception as e:
 error=str(e) if isinstance(e,RuntimeError) else type(e).__name__
 print('Fund acceptance stopped: '+error,flush=True); n['report'](error)
 raise SystemExit(1)
