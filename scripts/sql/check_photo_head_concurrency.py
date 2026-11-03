#!/usr/bin/env python3
"""Real concurrent PG transactions, only in the disposable SQL-check container."""
import json
import subprocess
import sys
import time
import uuid

container = sys.argv[1]
if not container.startswith('squadly-cloudbase-pg-check-'):
    raise SystemExit('Disposable checker container required')
command = ['docker', 'exec', '-i', container, 'psql', '-X', '-qAt', '-U', 'postgres', '-v', 'ON_ERROR_STOP=1']

def sql(statement):
    result = subprocess.run(command, input=statement, text=True, capture_output=True, timeout=10)
    if result.returncode:
        raise RuntimeError('Local photo-head SQL failed: ' + result.stderr)
    return result.stdout.strip()

team = '91000000-0000-4000-8000-000000000010'
actors = ['91000000-0000-4000-8000-000000000001', '91000000-0000-4000-8000-000000000002']
sql(f"""
INSERT INTO auth.users(id) VALUES('{actors[0]}'),('{actors[1]}');
INSERT INTO public.squads(id,name,created_by,status) VALUES('{team}','Concurrent photos','{actors[0]}','active');
INSERT INTO public.squad_members(squad_id,user_id,role) VALUES
 ('{team}','{actors[0]}','captain'),('{team}','{actors[1]}','member');
""")
prepared = []
for actor in actors:
    result = sql(f"""SET ROLE authenticated;
    SET request.jwt.claims='{{"sub":"{actor}"}}';
    SELECT public.reserve_photo_upload('{team}','{uuid.uuid4()}',repeat('a',64),NULL);""")
    prepared.append(json.loads(result))

def complete(index):
    photo = prepared[index]
    return f"SELECT public.complete_photo_upload('{photo['media_id']}','{photo['attempt_id']}',repeat('b',64),4,3,500);"

first = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
second = None
try:
    first.stdin.write('BEGIN; SET ROLE service_role;' + complete(0) + "SELECT 'first_holds_head';\n")
    first.stdin.flush()
    while True:
        line = first.stdout.readline()
        if not line:
            raise RuntimeError('First transaction failed before lock checkpoint')
        if line.strip() == 'first_holds_head':
            break
    second = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    second.stdin.write("SET application_name='squadly_photo_head_second'; SET lock_timeout='4s'; BEGIN; SET ROLE service_role;" + complete(1) + 'COMMIT;\n')
    second.stdin.close()
    deadline = time.monotonic() + 3
    locked = False
    while time.monotonic() < deadline:
        locked = sql("SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name='squadly_photo_head_second' AND wait_event_type='Lock');") == 't'
        if locked:
            break
    if not locked:
        raise RuntimeError('Second publisher did not wait on the same head row')
    first.stdin.write('COMMIT;\n')
    first.stdin.close()
    first.wait(timeout=5)
    second.wait(timeout=5)
    if first.returncode or second.returncode:
        raise RuntimeError('Concurrent publication failed')
finally:
    for process in [first, second]:
        if process is not None and process.poll() is None:
            process.kill()
            process.wait()

head_sql = f"SELECT public.get_squad_photo_head('{team}');"
def head():
    return json.loads(sql(f"SET ROLE authenticated; SET request.jwt.claims='{{\"sub\":\"{actors[0]}\"}}';" + head_sql))

current = head()
assert current['revision'] == '2' and current['photo'], 'Concurrent commit lost version/photo'
initial_id = current['photo']['id']
author = current['photo']['sender_id']
sql(f"SET ROLE authenticated; SET request.jwt.claims='{{\"sub\":\"{author}\"}}'; SELECT public.revoke_photo_message('{team}','{initial_id}');")
fallback = head()
assert fallback['revision'] == '3' and fallback['photo']['id'] != initial_id, 'Latest revocation did not atomically fall back'
assert fallback['photo']['created_at'] <= current['photo']['created_at'], 'Fallback is not an older photo'
remaining = fallback['photo']
sql(f"SET ROLE authenticated; SET request.jwt.claims='{{\"sub\":\"{remaining['sender_id']}\"}}'; SELECT public.revoke_photo_message('{team}','{remaining['id']}');")
assert head() == {'revision': '4', 'photo': None}, 'Empty head lost revocation version'
print('Concurrent publication row-lock/commit order and latest-photo revocation fallback passed (local PG only).')

# A private hide can commit independently of a new public publication. The sum
# is monotone for the receiver and does not change the author's public view.
prepared3 = json.loads(sql(f"SET ROLE authenticated; SET request.jwt.claims='{{\"sub\":\"{actors[0]}\"}}'; SELECT public.reserve_photo_upload('{team}','{uuid.uuid4()}',repeat('a',64),NULL);"))
# Recreate one visible photo for the hide target.
visible = json.loads(sql(f"SET ROLE service_role; SELECT public.complete_photo_upload('{prepared3['media_id']}','{prepared3['attempt_id']}',repeat('b',64),4,3,500);"))
target_id = visible['message_id']
prepared4 = json.loads(sql(f"SET ROLE authenticated; SET request.jwt.claims='{{\"sub\":\"{actors[0]}\"}}'; SELECT public.reserve_photo_upload('{team}','{uuid.uuid4()}',repeat('a',64),NULL);"))
hiding = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
try:
    hiding.stdin.write(f"BEGIN; SET ROLE authenticated; SET request.jwt.claims='{{\"sub\":\"{actors[1]}\"}}'; SELECT public.hide_photo_message('{team}','{target_id}'); SELECT 'private_hide_uncommitted';\n")
    hiding.stdin.flush()
    while hiding.stdout.readline().strip() != 'private_hide_uncommitted':
        if hiding.poll() is not None:
            raise RuntimeError('Hide transaction failed before checkpoint')
    published = json.loads(sql(f"SET ROLE service_role; SELECT public.complete_photo_upload('{prepared4['media_id']}','{prepared4['attempt_id']}',repeat('c',64),4,3,500);"))
    hiding.stdin.write('COMMIT;\n');hiding.stdin.close();hiding.wait(timeout=5)
    assert hiding.returncode == 0
finally:
    if hiding.poll() is None:
        hiding.kill();hiding.wait()
receiver = json.loads(sql(f"SET ROLE authenticated; SET request.jwt.claims='{{\"sub\":\"{actors[1]}\"}}';" + head_sql))
assert head()['revision'] == '6', 'Private hide changed public version'
assert receiver['revision'] == '7', 'Concurrent private/public revision was lost'
assert receiver['photo']['id'] != target_id, 'Hidden photo returned after concurrent publication'
print('Concurrent private hide/public publication preserves account-specific monotone heads (local PG only).')
