import test from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';

async function withServer(pool, fn) {
  const server = createApp(pool, { APP_ENV: 'test', DB_HOST: 'mock-db' }).listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  try { await fn(`http://127.0.0.1:${server.address().port}`); }
  finally { await new Promise(resolve => server.close(resolve)); }
}

test('health y configuración no exponen secretos', async () => {
  await withServer({ query: async () => ({ rows: [] }) }, async base => {
    const health = await (await fetch(`${base}/health`)).json();
    assert.equal(health.status, 'ok');
    const config = await (await fetch(`${base}/config`)).json();
    assert.equal(config.environment, 'test');
    assert.ok(!('DB_PASSWORD' in config));
  });
});

test('rechaza entradas inválidas sin consultar base de datos', async () => {
  await withServer({ query: () => { throw new Error('No debe consultar'); } }, async base => {
    const response = await fetch(`${base}/notes`, { method:'POST', headers:{'content-type':'application/json'}, body:JSON.stringify({text:''}) });
    assert.equal(response.status, 400);
  });
});

test('crea nota con consulta parametrizada', async () => {
  let executed;
  const pool = { query: async (sql, values) => { executed = {sql, values}; return {rows:[{id:1,text:'hola'}]}; } };
  await withServer(pool, async base => {
    const response = await fetch(`${base}/notes`, {method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({text:' hola '})});
    assert.equal(response.status,201);
    assert.deepEqual(executed.values,['hola']);
  });
});
