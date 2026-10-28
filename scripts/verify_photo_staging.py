#!/usr/bin/env python3
"""Live synthetic photo acceptance with ordinary A/B JWTs, never service keys.

Shares the existing fixed-staging, private-config and explicit-write guards.
Reports contain aliases/statuses; bytes, object paths and credentials stay out.
"""
import runpy, json, uuid, base64, hashlib, time, re
from pathlib import Path
from urllib.request import Request
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse

n = runpy.run_path(str(Path(__file__).with_name('verify_conversation_read_staging.py')))
c = n['c']; check = n['check']; ok = n['ok']; rpc = n['rpc']; save = n['save']
get = n['get']; row = n['row']
checks = n['checks']
not_verified = ['third_account_never_joined', 'leave_rejoin', 'physical_device_UI', 'widget_and_push', 'large_real_camera_photo']

def media(body, actor='a'):
    gateway = c['photoAcceptance']['workerUrl']
    u = urlparse(gateway)
    if u.scheme != 'https' or u.path != '/photos' or u.query or u.fragment or u.username or not u.hostname.startswith(c['environmentId']+'-') or not u.hostname.endswith('.ap-shanghai.app.tcloudbase.com'):
        raise RuntimeError('photo_gateway_identity_mismatch')
    headers = {'Content-Type': 'application/json', 'x-device-id': c['actors'].get(actor, {}).get('deviceId', 'photo-acceptance-anonymous')}
    if actor is not None:
        headers['Authorization'] = 'Bearer ' + (c['publishableKey'] if actor == 'anonymous' else c['actors'][actor]['jwt'])
    req = Request(gateway, data=json.dumps(body).encode(), headers=headers, method='POST')
    try:
        with n['opener'].open(req, timeout=55) as r:
            return r.status, json.load(r)
    except HTTPError as e:
        try: value = json.load(e)
        except Exception: value = {}
        return e.code, value
    except (URLError, TimeoutError):
        return 0, {}

def denied(result, label, allowed=(401,403,404,410)):
    status, data = result
    check(label, status in allowed and not (isinstance(data,dict) and 'bytes' in data), status)

def photo_head(squad, actor='a'):
    value = ok(rpc('get_squad_photo_head',{'p_squad_id':squad},actor),'photo_head_'+actor)
    if value is None: return None
    revision = value.get('revision') if isinstance(value,dict) else None
    if not isinstance(revision,str) or not re.fullmatch(r'0|[1-9][0-9]{0,18}',revision) or int(revision)>9223372036854775807 or set(value)!={'revision','photo'}:
        raise RuntimeError('invalid_photo_head_projection')
    return value

def report(error=None):
    output = {'scope':'photos-user-HTTP', 'finishedAt':int(time.time()), 'passed':error is None,
      'checks':checks, 'notVerified':not_verified, 'completePhotoLoop':False}
    if error: output['stoppedAt'] = error
    n['REPORT'].write_text(json.dumps(output, indent=2))
    print('Photo report saved: '+str(n['REPORT']),flush=True)

def never_joined_c_control(payload):
    # Keep the never-member fixture separate from the later C join/leave test.
    f = c.setdefault('photoNeverJoinedAcceptance',{'runId':uuid.uuid4().hex[:10]})
    if 'squad' not in f:
        team = ok(rpc('create_squad',{'p_name':'验收测试-照片未入队C-'+f['runId'],'p_description':'Never invite C; synthetic privacy control'}),'never_c_fixture_create')
        f['squad'] = team['id']; f['cUserId'] = c['actors']['c']['userId']; save()
    squad = f['squad']
    team = row(get('squads',id='eq.'+squad,select='id,name,created_by'),'never_c_fixture_identity')
    if team['name']!='验收测试-照片未入队C-'+f['runId'] or team['created_by']!=c['actors']['a']['userId'] or f['cUserId']!=c['actors']['c']['userId']:
        raise RuntimeError('not_dedicated_never_c_fixture')
    members = ok(get('squad_members',squad_id='eq.'+squad,select='user_id'),'never_c_members')
    if c['actors']['b']['userId'] not in [m['user_id'] for m in members]:
        invite = ok(rpc('issue_invitation',{'p_squad_id':squad,'p_max_uses':1}),'never_c_invite_b')
        ok(rpc('redeem_invitation',{'p_credential':invite['code']},'b'),'never_c_join_b')
    members = ok(get('squad_members',squad_id='eq.'+squad,select='user_id'),'never_c_members_ready')
    check('never_joined_c_fixture_only_a_b',len(members)==2 and {m['user_id'] for m in members}=={c['actors']['a']['userId'],c['actors']['b']['userId']})
    if f.get('message'):
        status,_ = media({'action':'revoke','squad_id':squad,'message_id':f['message']})
        if status not in (200,404):raise RuntimeError('never_c_prior_fixture_cleanup')
    before = photo_head(squad)
    check('never_c_fixture_empty_head',before is not None and before['photo'] is None)
    published = ok(media({**payload,'squad_id':squad,'client_nonce':str(uuid.uuid4())}),'never_c_publish')
    f['message'] = published['message_id'];save()
    load = {'action':'load','squad_id':squad,'message_id':f['message']}
    visible = ok(media(load,'b'),'never_c_b_positive_load')
    check('never_joined_c_b_bytes_positive_control',hashlib.sha256(base64.b64decode(visible['bytes'])).hexdigest()==visible['sha256'])
    denied(media(load,'c'),'never_joined_c_bytes_denied')
    check('never_joined_c_head_hidden',photo_head(squad,'c') is None)
    visible_head = photo_head(squad,'b')
    check('never_c_member_head_positive',int(visible_head['revision'])==int(before['revision'])+1 and visible_head['photo']['id']==f['message'])
    check('never_joined_c_photo_page_empty',ok(rpc('page_squad_photos',{'p_squad_id':squad},'c'),'never_c_page')==[])
    check('never_joined_c_parent_hidden',ok(rpc('get_squad_photo',{'p_squad_id':squad,'p_message_id':f['message']},'c'),'never_c_parent') is None)
    denied(media({**payload,'squad_id':squad,'client_nonce':str(uuid.uuid4())},'c'),'never_joined_c_publish_denied')
    members = ok(get('squad_members',squad_id='eq.'+squad,select='user_id'),'never_c_members_final')
    check('never_joined_c_stayed_outside',len(members)==2 and all(m['user_id']!=c['actors']['c']['userId'] for m in members))
    ok(media({'action':'revoke','squad_id':squad,'message_id':f['message']}),'never_c_cleanup')
    after = photo_head(squad)
    check('revoking_last_photo_retains_empty_new_version',after['photo'] is None and int(after['revision'])==int(before['revision'])+2)
    ok(media({'action':'revoke','squad_id':squad,'message_id':f['message']}),'never_c_repeated_cleanup')
    check('repeated_revoke_does_not_increment_version',photo_head(squad)==after)
    not_verified.remove('third_account_never_joined')

def run():
    n['preflight']()
    has_c = bool(c['actors'].get('c', {}).get('jwt'))
    if has_c:
        actor = c['actors']['c']
        claims = json.loads(base64.urlsafe_b64decode(actor['jwt'].split('.')[1]+'==='))
        check('c_ordinary_unexpired_session',claims.get('role') in ('user','authenticated') and claims.get('is_system_admin') is not True and claims.get('exp',0)>time.time()+300)
        identity = ok(n['http']('/auth/v1/user/me?client_id='+c['environmentId'],'c'),'identity_c')
        identity = identity.get('data',identity)
        check('c_authenticated_identity',(identity.get('sub') or identity.get('uid'))==actor['userId'])
        own = ok(get('profiles','c',id='eq.'+actor['userId'],select='id'),'c_profile')
        check('c_owner_profile_positive_control',len(own)==1 and own[0]['id']==actor['userId'])
    f = c.setdefault('photoAcceptance', {})
    if 'squad' not in f:
        f['runId'] = uuid.uuid4().hex[:10]; save()
        team = ok(rpc('create_squad', {'p_name':'验收测试-照片-'+f['runId'], 'p_description':'Synthetic photo fixture'}),'photo_fixture_create')
        f['squad'] = team['id']; save()
    squad = f['squad']
    team = row(get('squads',id='eq.'+squad,select='id,name,created_by'),'photo_fixture_identity')
    if team['name'] != '验收测试-照片-'+f['runId'] or team['created_by'] != c['actors']['a']['userId']:
        raise RuntimeError('not_dedicated_photo_fixture')
    members = ok(get('squad_members', select='user_id', squad_id='eq.'+squad),'photo_members')
    if c['actors']['b']['userId'] not in [m['user_id'] for m in members]:
        invite = ok(rpc('issue_invitation', {'p_squad_id':squad,'p_max_uses':1}),'photo_invite')
        ok(rpc('redeem_invitation', {'p_credential':invite['code']},'b'),'photo_join')
    check('two_real_photo_members',len(ok(get('squad_members',select='user_id',squad_id='eq.'+squad),'photo_joined'))==2)
    if has_c:
        outsider = ok(get('squads','c',id='eq.'+squad,select='id'),'outsider_c_squad')
        check('c_initially_outside_photo_fixture',outsider==[])
    bytes_ = Path('test/features/photos/fixtures/sanitized.jpg').read_bytes()
    digest = hashlib.sha256(bytes_).hexdigest()
    # Each invocation is a fresh, explicitly authorized synthetic round trip.
    # Revoke older checkpointed fixtures before replacing their identities.
    for name,actor in [('message','a'),('replyMessage','b')]:
        if f.get(name):
            status,_ = media({'action':'revoke','squad_id':squad,'message_id':f[name]},actor)
            if status not in (200,404): raise RuntimeError('prior_photo_fixture_cleanup_failed')
    before = photo_head(squad)
    baseline_version = int(before['revision'])
    f['publishNonce']=str(uuid.uuid4());f['replyNonce']=str(uuid.uuid4());save()
    payload = {'action':'publish','squad_id':squad,'client_nonce':f['publishNonce'],
      'source_sha256':digest,'bytes':base64.b64encode(bytes_).decode(),'reply_to_message_id':None}
    published = ok(media(payload),'photo_publish')
    check('author_publication_identity',published.get('author_id')==c['actors']['a']['userId'] and published.get('squad_id')==squad and published.get('client_nonce')==payload['client_nonce'])
    f['message'] = published['message_id']; save()
    repeat = ok(media(payload),'photo_retry')
    check('same_nonce_same_message',repeat==published)
    check('no_internal_fields_in_result',set(published)=={'message_id','media_id','squad_id','author_id','client_nonce','published_at','reply_to_message_id'})
    load = {'action':'load','squad_id':squad,'message_id':f['message']}
    for actor in ['a','b']:
        value = ok(media(load,actor),'photo_load_'+actor)
        data = base64.b64decode(value['bytes'])
        check('authenticated_bytes_'+actor,hashlib.sha256(data).hexdigest()==value['sha256'] and value['width']==4 and value['height']==3 and set(value)=={'bytes','width','height','sha256'})
        page = ok(rpc('page_squad_photos',{'p_squad_id':squad,'p_limit':1},actor),'photo_page_'+actor)
        check('latest_photo_rpc_'+actor,len(page)==1 and page[0]['id']==f['message'] and page[0]['kind']=='photo' and page[0]['photo']['revoked'] is False)
        parent = ok(rpc('get_squad_photo',{'p_squad_id':squad,'p_message_id':f['message']},actor),'photo_parent_'+actor)
        check('same_photo_projection_'+actor,parent==page[0] and set(parent['photo'])=={'id','width','height','byte_length','revoked'})
        head = photo_head(squad,actor)
        check('atomic_photo_head_matches_timeline_'+actor,int(head['revision'])==baseline_version+1 and head['photo']==parent)
        status,_ = get('squad_photo_heads',actor,select='revision',squad_id='eq.'+squad)
        check('member_cannot_read_internal_head_table_'+actor,status in (401,403),status)
        status,_ = rpc('claim_push_deliveries_v2',{'p_limit':1,'p_provider':'apns'},actor)
        check('member_cannot_claim_push_tokens_'+actor,status in (401,403),status)
    status,_ = rpc('claim_push_deliveries_v2',{'p_limit':1,'p_provider':'apns'},'anonymous')
    check('anonymous_cannot_claim_push_tokens',status in (401,403),status)
    status,_ = rpc('get_squad_photo_head',{'p_squad_id':squad},'anonymous')
    check('anonymous_cannot_execute_photo_head',status in (401,403),status)
    denied(media(load,'anonymous'),'anonymous_key_denied')
    denied(media(load,None),'missing_bearer_denied')
    if has_c:
        denied(media(load,'c'),'nonmember_c_bytes_denied')
        check('nonmember_c_photo_head_hidden',photo_head(squad,'c') is None)
        page = ok(rpc('page_squad_photos',{'p_squad_id':squad,'p_limit':50},'c'),'outsider_c_page')
        check('nonmember_c_photo_page_empty',page==[])
        parent = ok(rpc('get_squad_photo',{'p_squad_id':squad,'p_message_id':f['message']},'c'),'outsider_c_parent')
        check('nonmember_c_parent_hidden',parent is None)
        denied(media({**payload,'client_nonce':str(uuid.uuid4())},'c'),'nonmember_c_publish_denied')
        status,_ = rpc('claim_push_deliveries_v2',{'p_limit':1,'p_provider':'apns'},'c')
        check('nonmember_c_push_tokens_denied',status in (401,403),status)
        never_joined_c_control(payload)
    denied(media({'action':'revoke','squad_id':squad,'message_id':f['message']},'b'),'non_author_revoke_denied')
    changed = bytes_[:-1]+bytes([bytes_[-1]^1])
    status, data = media({**payload,'bytes':base64.b64encode(changed).decode(),'source_sha256':hashlib.sha256(changed).hexdigest()})
    check('changed_content_nonce_conflict',status==409 and data.get('error')=='nonce_conflict',status)
    read = ok(rpc('authorize_photo_read',{'p_squad_id':squad,'p_message_id':f['message']}),'photo_object_lookup')
    # Ordinary JWT must fail on the exact same Storage path the service used.
    for actor in ['a','b','anonymous']+(['c'] if has_c else []):
        status, data = n['http']('/v1/storages/object/squadly-photos/'+read['object_key'],actor)
        check('direct_storage_denied_'+actor,status in (401,403,404),status)
    denied(rpc('complete_photo_upload',{'p_media_id':published['media_id'],'p_attempt_id':str(uuid.uuid4()),'p_sha256':digest,'p_width':4,'p_height':3,'p_byte_length':len(bytes_)}),'user_cannot_certify_photo')
    f.setdefault('replyNonce',str(uuid.uuid4())); save()
    reply = ok(media({**payload,'client_nonce':f['replyNonce'],'reply_to_message_id':f['message']},'b'),'photo_reply')
    check('different_author_photo_reply',reply.get('author_id')==c['actors']['b']['userId'] and reply.get('reply_to_message_id')==f['message'])
    f['replyMessage'] = reply['message_id']; save()
    head = photo_head(squad)
    check('photo_reply_increments_head_once',int(head['revision'])==baseline_version+2 and head['photo']['id']==f['replyMessage'])
    if has_c:
        invite = ok(rpc('issue_invitation',{'p_squad_id':squad,'p_max_uses':1}),'c_photo_invite')
        ok(rpc('redeem_invitation',{'p_credential':invite['code']},'c'),'c_photo_join')
        membership = row(get('squad_members','c',squad_id='eq.'+squad,user_id='eq.'+c['actors']['c']['userId'],select='id'),'c_initial_membership')['id']
        visible = ok(media(load,'c'),'c_joined_photo_load')
        check('c_joined_member_can_read',hashlib.sha256(base64.b64decode(visible['bytes'])).hexdigest()==visible['sha256'])
        pending = ok(rpc('reserve_photo_upload',{'p_squad_id':squad,'p_client_nonce':str(uuid.uuid4()),'p_source_sha256':digest},'c'),'c_pending_photo')
        check('c_member_can_prepare_upload',bool(pending.get('media_id') and pending.get('attempt_id')))
        ok(rpc('remove_squad_member',{'p_squad_id':squad,'p_user_id':c['actors']['c']['userId']}),'captain_removes_c')
        denied(media(load,'c'),'removed_c_bytes_denied')
        check('removed_c_photo_head_hidden',photo_head(squad,'c') is None)
        status,authorization = rpc('authorize_photo_upload_attempt',{'p_media_id':pending['media_id'],'p_attempt_id':pending['attempt_id']},'c')
        check('removed_c_cannot_certify_pending',status==200 and authorization.get('error')=='not_member',status)
        check('removed_c_photo_page_empty',ok(rpc('page_squad_photos',{'p_squad_id':squad},'c'),'removed_c_page')==[])
        invite = ok(rpc('issue_invitation',{'p_squad_id':squad,'p_max_uses':1}),'c_rejoin_invite')
        ok(rpc('redeem_invitation',{'p_credential':invite['code']},'c'),'c_rejoin')
        current = row(get('squad_members','c',squad_id='eq.'+squad,user_id='eq.'+c['actors']['c']['userId'],select='id'),'c_rejoined_membership')['id']
        check('c_rejoin_creates_new_membership',current!=membership)
        ok(media(load,'c'),'c_rejoined_photo_load')
        ok(rpc('leave_squad',{'p_squad_id':squad},'c'),'c_self_leave')
        denied(media(load,'c'),'self_left_c_bytes_denied')
        check('fixture_returns_to_two_members',len(ok(get('squad_members',squad_id='eq.'+squad,select='user_id'),'photo_members_final'))==2)
        not_verified.remove('leave_rejoin')
    revoked = ok(media({'action':'revoke','squad_id':squad,'message_id':f['message']}),'photo_revoke')
    check('author_revoke',revoked=={'revoked':True})
    head = photo_head(squad)
    check('revoke_increments_head_without_hiding_reply',int(head['revision'])==baseline_version+3 and head['photo']['id']==f['replyMessage'])
    denied(media(load,'b'),'revoked_bytes_denied')
    for actor in ['a','b']:
        value = ok(rpc('get_squad_photo',{'p_squad_id':squad,'p_message_id':f['message']},actor),'revoked_parent_'+actor)
        check('revoked_parent_not_available_'+actor,value is None)
        page = ok(rpc('page_squad_photos',{'p_squad_id':squad,'p_limit':50},actor),'revoked_photo_page_'+actor)
        check('revoked_photo_excluded_'+actor,not any(m['id']==f['message'] for m in page))
    status, data = media(payload)
    check('retry_cannot_resurrect',status==410 and data.get('error')=='revoked',status)
    timeline = ok(rpc('page_squad_timeline',{'p_squad_id':squad}),'photo_timeline')
    parent = next(m for m in timeline if m['id']==f['message'])
    check('revocation_tombstone_same_message',parent['photo']['revoked'] is True and parent['kind']=='photo')
    ok(media({'action':'revoke','squad_id':squad,'message_id':f['replyMessage']},'b'),'reply_fixture_cleanup')
    head = photo_head(squad)
    check('reply_revoke_restores_previous_head_at_new_version',int(head['revision'])==baseline_version+4 and head['photo']==before['photo'])
    report()

if __name__ == '__main__':
    try: run()
    except Exception as error:
        label = str(error) if isinstance(error,RuntimeError) else type(error).__name__
        print('Photo acceptance stopped: '+label,flush=True);report(label);raise SystemExit(1)
