// Node 18+
// Usage:
//   node bench_node.js                 # single thread
//   WORKERS=4 node bench_node.js       # 4 worker threads
//
// What it does per record:
// 1) JSON.parse
// 2) validate required fields
// 3) enrich: compute isAlarm
// 4) aggregate: per-device counters
// 5) small CPU: 32-bit FNV-1a over payload string (cheap checksum)

const { Worker, isMainThread, parentPort, workerData } = require('node:worker_threads');

function fnv1a32(str) {
  let h = 0x811c9dc5 >>> 0;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

function genPayloads(n, devices=1000) {
  const arr = new Array(n);
  for (let i = 0; i < n; i++) {
    const dev = 'dev-' + (i % devices);
    const temp = (i % 120);
    const status = (temp > 95 && (i % 7 === 0)) ? 'ALARM' : 'OK';
    arr[i] = JSON.stringify({
      deviceId: dev,
      ts: Date.now(),
      temp,
      status,
      payload: "x".repeat(64) // fixed-size to avoid GC extremes
    });
  }
  return arr;
}

function processBatch(payloads) {
  const agg = new Map(); // deviceId -> {count, alarms, checksum}
  let alarmCount = 0;
  for (let i = 0; i < payloads.length; i++) {
    const s = payloads[i];
    const obj = JSON.parse(s);

    // validate
    if (typeof obj.deviceId !== 'string' ||
        typeof obj.ts !== 'number' ||
        typeof obj.temp !== 'number' ||
        typeof obj.status !== 'string') {
      throw new Error('bad record');
    }

    // enrich
    const isAlarm = obj.temp > 95 || obj.status === 'ALARM';
    if (isAlarm) alarmCount++;

    // aggregate
    const a = agg.get(obj.deviceId) || { count: 0, alarms: 0, checksum: 0 };
    a.count++;
    if (isAlarm) a.alarms++;
    a.checksum = (a.checksum + fnv1a32(s)) >>> 0;
    agg.set(obj.deviceId, a);
  }
  return { devices: agg.size, alarmCount, checksumTotal: [...agg.values()].reduce((t,a)=>t+a.checksum,0) >>> 0 };
}

async function runSingle(total=1_000_000, batch=10_000) {
  const start = performance.now();
  let processed = 0;
  let checksum = 0;
  while (processed < total) {
    const n = Math.min(batch, total - processed);
    const payloads = genPayloads(n);
    const res = processBatch(payloads);
    checksum = (checksum + res.checksumTotal) >>> 0;
    processed += n;
  }
  const ms = performance.now() - start;
  const rps = (total / (ms / 1000)).toFixed(0);
  console.log(JSON.stringify({ lang: "node", total, ms: +ms.toFixed(1), rps: +rps, checksum }));
}

async function runWorkers(total=1_000_000, workers=+process.env.WORKERS || 1) {
  if (workers <= 1) return runSingle(total);
  const per = Math.floor(total / workers);
  const promises = [];
  const t0 = performance.now();
  for (let w = 0; w < workers; w++) {
    promises.push(new Promise((resolve, reject) => {
      const worker = new Worker(__filename, { workerData: { count: per }});
      worker.on('message', resolve);
      worker.on('error', reject);
    }));
  }
  const results = await Promise.all(promises);
  const ms = performance.now() - t0;
  const totalDone = results.reduce((t, r) => t + r.total, 0);
  const checksum = results.reduce((t, r) => (t + r.checksum) >>> 0, 0);
  const rps = (totalDone / (ms / 1000)).toFixed(0);
  console.log(JSON.stringify({ lang: "node", workers, total: totalDone, ms: +ms.toFixed(1), rps: +rps, checksum }));
}

if (isMainThread) {
  runWorkers(1_000_000).catch(e => { console.error(e); process.exit(1); });
} else {
  const total = workerData.count;
  const start = performance.now();
  let processed = 0;
  let checksum = 0;
  while (processed < total) {
    const n = Math.min(10_000, total - processed);
    const payloads = genPayloads(n);
    const res = processBatch(payloads);
    checksum = (checksum + res.checksumTotal) >>> 0;
    processed += n;
  }
  const ms = performance.now() - start;
  parentPort.postMessage({ total, ms, checksum });
}
