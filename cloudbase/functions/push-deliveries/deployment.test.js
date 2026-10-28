const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('handler deployments use Event gateway mode and CLI-compatible protected log settings', () => {
  const config = JSON.parse(fs.readFileSync(path.join(__dirname, '../../cloudbaserc.json')));
  for (const name of ['photos', 'push-deliveries']) {
    const fn = config.functions.find((value) => value.name === name);
    // index.main does not start a listening HTTP server. A native HTTP-type
    // deployment cannot substitute for the Event + HTTP service binding.
    assert.equal(fn.type, 'Event');
    assert.equal(fn.handler, 'index.main');
    // CLI 3.8.6 forwards this field unchanged to TCB configuration update,
    // which rejects a boolean. Actual SCF IgnoreSysLog must also be checked.
    assert.equal(fn.ignoreSysLog, 'true');
    assert.ok(fn.ignore.includes('*.test.js'));
  }
});
