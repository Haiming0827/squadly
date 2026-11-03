#!/usr/bin/env python3
"""Actual concurrent transactions in the owned disposable PostgreSQL checker."""
import json
import select
import subprocess
import sys
import time

container = sys.argv[1]
if not container.startswith('squadly-cloudbase-pg-check-'):
    raise SystemExit('Disposable checker container required')
command = ['docker', 'exec', '-i', container, 'psql', '-X', '-qAt', '-U', 'postgres', '-v', 'ON_ERROR_STOP=1']
team = '93000000-0000-4000-8000-000000000010'
actors = ['93000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000002']


def sql(statement):
    result = subprocess.run(command, input=statement, text=True, capture_output=True, timeout=10)
    if result.returncode:
        raise RuntimeError('Local sync SQL failed: ' + result.stderr)
    return result.stdout.strip()


def session(statement):
    process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, text=True, bufsize=1)
    process.stdin.write(statement + '\n')
    process.stdin.flush()
    return process


def line(process):
    if not select.select([process.stdout], [], [], 5)[0]:
        raise RuntimeError('Local sync transaction checkpoint timed out')
    value = process.stdout.readline().strip()
    if not value:
        raise RuntimeError('Local sync transaction exited before checkpoint')
    return value


def commit(process):
    process.stdin.write('COMMIT;\n')
    process.stdin.close()
    process.wait(timeout=5)
    if process.returncode:
        raise RuntimeError('Local sync transaction failed: ' + process.stderr.read())


sql(f"""
INSERT INTO auth.users(id) VALUES('{actors[0]}'),('{actors[1]}');
INSERT INTO public.squads(id,name,created_by,status) VALUES('{team}','Concurrent privacy hints','{actors[0]}','active');
INSERT INTO public.squad_members(squad_id,user_id,role) VALUES
 ('{team}','{actors[0]}','captain'),('{team}','{actors[1]}','member');
INSERT INTO public.device_push_tokens(user_id,device_id,provider,token) VALUES
 ('{actors[0]}','93000000-0000-4000-8000-000000000020','apns',repeat('31',32)),
 ('{actors[1]}','93000000-0000-4000-8000-000000000021','apns',repeat('32',32));
UPDATE public.squads SET status='pending' WHERE id='{team}';
""")
processes = []
try:
    first = session('BEGIN; SET ROLE service_role; SELECT row_to_json(c) FROM public.claim_photo_sync(1) c;')
    processes.append(first)
    claim1 = json.loads(line(first))
    # The first transaction still owns its row lock: SKIP LOCKED must give the
    # second worker a different device without waiting for the first commit.
    claim2 = json.loads(sql('SET ROLE service_role; SELECT row_to_json(c) FROM public.claim_photo_sync(1) c;'))
    assert claim1['delivery_id'] != claim2['delivery_id'], 'Concurrent workers leased one target twice'
    commit(first)
    assert sql('SELECT count(*) FROM public.claim_photo_sync(10);') == '0', 'Live lease reclaimed'

    # A business change holds the rows while a completion races it. Completion
    # must observe the committed newer generation after waiting for that lock.
    event = session(f"BEGIN; UPDATE public.squads SET status='active' WHERE id='{team}'; "
                    f"UPDATE public.squads SET status='pending' WHERE id='{team}'; SELECT 'event_holds_rows';")
    processes.append(event)
    assert line(event) == 'event_holds_rows'
    receipt = session("SET application_name='squadly_privacy_receipt'; SET lock_timeout='4s'; "
                      f"SELECT public.complete_photo_sync('{claim1['delivery_id']}','{claim1['claim_id']}','sent');")
    processes.append(receipt)
    deadline = time.monotonic() + 3
    waiting = False
    while time.monotonic() < deadline:
        waiting = sql("SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name='squadly_privacy_receipt' AND wait_event_type='Lock');") == 't'
        if waiting:
            break
        time.sleep(0.025)
    assert waiting, 'Receipt did not wait on the actual event row lock'
    commit(event)
    assert line(receipt) == 't', 'Matching old receipt rejected instead of requeueing'
    receipt.stdin.close()
    receipt.wait(timeout=5)
    assert receipt.returncode == 0, 'Racing receipt failed'
    assert sql(f"SELECT status='pending' AND generation=2 FROM public.photo_sync_deliveries WHERE id='{claim1['delivery_id']}';") == 't', 'Concurrent receipt swallowed newer event'
    assert sql(f"SELECT public.complete_photo_sync('{claim1['delivery_id']}','{claim1['claim_id']}','sent');") == 'f', 'Old receipt accepted twice'
    assert sql(f"SELECT public.complete_photo_sync('{claim2['delivery_id']}','{claim2['claim_id']}','retry');") == 't'
    assert sql(f"SELECT bool_and(status='pending' AND generation=2 AND attempt_count=0) FROM public.photo_sync_deliveries WHERE squad_id='{team}';") == 't', 'New generation inherited stale retry budget'
    print('Actual concurrent privacy claims and event/receipt row-lock race passed (local PostgreSQL only).')
finally:
    for process in processes:
        if process.poll() is None:
            process.kill()
            process.wait()
    sql(f"DELETE FROM public.squads WHERE id='{team}'; DELETE FROM public.photo_sync_deliveries WHERE squad_id='{team}'; "
        f"DELETE FROM auth.users WHERE id IN ('{actors[0]}','{actors[1]}'); "
        f"DELETE FROM public.profiles WHERE id IN ('{actors[0]}','{actors[1]}');")
