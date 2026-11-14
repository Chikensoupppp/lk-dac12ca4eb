const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');

function load(url = 'https://www.youtube.com/watch?v=synthetic', focused = true) {
  const sent = [], timers = [];
  let listener;
  let queries = 0;
  const event = { addListener() {} };
  const port = { postMessage: m => sent.push(m), onMessage: { addListener: fn => { listener = fn; } }, onDisconnect: event };
  const chrome = {
    runtime: { connectNative: () => port, onMessage: event, onStartup: event, onInstalled: event },
    extension: { isAllowedIncognitoAccess: async () => true },
    windows: { getLastFocused: async () => ({ id: 7, focused }) },
    tabs: { query: async () => { queries++; return [{ url }]; } },
    alarms: { create() {}, onAlarm: event },
  };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../../apps/browser-extension/background.js'), 'utf8'), { chrome, URL, setInterval: fn => timers.push(fn) });
  timers[1](); // establishes the native connection synchronously, before alive's await completes
  return { sent, timers, receive: m => listener(m), queries: () => queries };
}

test('polls contain no URL; tabs are read only after a valid buddy request', async () => {
  const env = load();
  env.timers[1]();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(env.queries(), 0);
  assert.equal(env.sent.some(m => 'url' in m), false);
  await env.receive({ savePage: 'a'.repeat(32) });
  assert.equal(env.queries(), 1);
  const saved = env.sent.find(m => m.kind === 'later-save');
  assert.equal(saved.url, 'https://www.youtube.com/watch?v=synthetic');
  assert.equal(saved.request, 'a'.repeat(32));
});

test('background browser and unsupported URLs cannot be saved', async () => {
  for (const [url, focused] of [['https://reddit.com/r/test/', false], ['https://youtube.com.evil.test/', true], ['file:///C:/synthetic', true], ['https://user:password@youtube.com/', true]]) {
    const env = load(url, focused);
    await env.receive({ savePage: 'b'.repeat(32) });
    assert.equal(env.sent.some(m => m.kind === 'later-save'), false);
  }
});

test('invalid or absent request never reads a tab', async () => {
  const env = load();
  await env.receive({ ok: true });
  await env.receive({ savePage: 'invalid' });
  assert.equal(env.queries(), 0);
});
