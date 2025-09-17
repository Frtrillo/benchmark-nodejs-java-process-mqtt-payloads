// Algorithmic Benchmark: Monte Carlo Simulation for IoT Sensor Risk Analysis
// Usage:
//   node bench_algo_node.js                 # single thread
//   WORKERS=4 node bench_algo_node.js       # 4 worker threads
//
// What it does:
// 1) Monte Carlo simulation of sensor failure probability
// 2) Complex mathematical operations (trigonometry, exponentials)
// 3) Statistical analysis of temperature patterns
// 4) Risk scoring based on multiple variables
// 5) Heavy CPU computation with minimal I/O

const { Worker, isMainThread, parentPort, workerData } = require('node:worker_threads');

// Pseudo-random number generator (for consistent results across runs)
class PRNG {
  constructor(seed = 12345) {
    this.seed = seed;
  }
  
  next() {
    this.seed = (this.seed * 9301 + 49297) % 233280;
    return this.seed / 233280;
  }
}

// Complex sensor failure risk calculation
function calculateSensorRisk(deviceId, temperature, humidity, pressure, vibration, iterations = 50000) {
  const prng = new PRNG(deviceId.charCodeAt(0) * 1000);
  let riskScore = 0;
  let failureProbability = 0;
  
  // Monte Carlo simulation
  for (let i = 0; i < iterations; i++) {
    // Simulate environmental stress factors
    const tempStress = Math.exp((temperature - 25) / 15) * (1 + 0.1 * Math.sin(i * 0.01));
    const humidityStress = Math.pow(humidity / 100, 2) * (1 + 0.05 * Math.cos(i * 0.02));
    const pressureStress = Math.abs(pressure - 1013.25) / 50 * (1 + 0.03 * Math.sin(i * 0.015));
    const vibrationStress = Math.sqrt(vibration) * (1 + 0.08 * Math.cos(i * 0.008));
    
    // Complex failure probability calculation
    const randomFactor = prng.next();
    const stressCombination = tempStress * humidityStress + pressureStress * vibrationStress;
    const failureThreshold = 2.5 + randomFactor * 0.5;
    
    // Weibull distribution for failure modeling
    const shape = 1.5 + randomFactor * 0.3;
    const scale = 100 + randomFactor * 20;
    const weibullProb = 1 - Math.exp(-Math.pow(stressCombination / scale, shape));
    
    if (weibullProb > failureThreshold / 10) {
      failureProbability += weibullProb;
    }
    
    // Statistical moments calculation
    riskScore += Math.pow(stressCombination, 1.8) * Math.log(1 + weibullProb);
    
    // Additional complexity: Fourier-like analysis
    if (i % 1000 === 0) {
      for (let j = 1; j <= 10; j++) {
        riskScore += Math.sin(j * stressCombination) * Math.cos(j * failureProbability) / j;
      }
    }
  }
  
  return {
    riskScore: riskScore / iterations,
    failureProbability: failureProbability / iterations,
    checksum: Math.floor(riskScore * 1000000) % 1000000
  };
}

// Generate sensor data
function generateSensorData(count, devicePrefix = 'sensor') {
  const sensors = [];
  for (let i = 0; i < count; i++) {
    sensors.push({
      deviceId: `${devicePrefix}-${i}`,
      temperature: 20 + (i % 60) + Math.sin(i * 0.1) * 5,
      humidity: 40 + (i % 40) + Math.cos(i * 0.05) * 10,
      pressure: 1000 + (i % 50) + Math.sin(i * 0.02) * 15,
      vibration: 1 + (i % 10) + Math.cos(i * 0.03) * 2
    });
  }
  return sensors;
}

function processBatch(sensors, iterations) {
  let totalRisk = 0;
  let totalFailureProb = 0;
  let checksum = 0;
  
  for (const sensor of sensors) {
    const result = calculateSensorRisk(
      sensor.deviceId,
      sensor.temperature,
      sensor.humidity, 
      sensor.pressure,
      sensor.vibration,
      iterations
    );
    
    totalRisk += result.riskScore;
    totalFailureProb += result.failureProbability;
    checksum = (checksum + result.checksum) % 1000000000;
  }
  
  return {
    avgRisk: totalRisk / sensors.length,
    avgFailureProb: totalFailureProb / sensors.length,
    checksum
  };
}

async function runSingle(sensorCount = 100, iterations = 50000) {
  const start = performance.now();
  const sensors = generateSensorData(sensorCount);
  const result = processBatch(sensors, iterations);
  const ms = performance.now() - start;
  const opsPerSec = Math.round(sensorCount / (ms / 1000));
  
  console.log(JSON.stringify({
    lang: "node",
    type: "algorithmic",
    sensors: sensorCount,
    iterations,
    ms: +ms.toFixed(1),
    ops_per_sec: opsPerSec,
    avg_risk: +result.avgRisk.toFixed(6),
    checksum: result.checksum
  }));
}

async function runWorkers(sensorCount = 100, iterations = 50000, workers = +process.env.WORKERS || 1) {
  if (workers <= 1) return runSingle(sensorCount, iterations);
  
  const sensorsPerWorker = Math.floor(sensorCount / workers);
  const promises = [];
  const t0 = performance.now();
  
  for (let w = 0; w < workers; w++) {
    promises.push(new Promise((resolve, reject) => {
      const worker = new Worker(__filename, { 
        workerData: { 
          sensorCount: sensorsPerWorker, 
          iterations,
          workerId: w
        }
      });
      worker.on('message', resolve);
      worker.on('error', reject);
    }));
  }
  
  const results = await Promise.all(promises);
  const ms = performance.now() - t0;
  const totalSensors = results.reduce((t, r) => t + r.sensors, 0);
  const avgRisk = results.reduce((t, r) => t + r.avgRisk, 0) / results.length;
  const checksum = results.reduce((t, r) => (t + r.checksum) % 1000000000, 0);
  const opsPerSec = Math.round(totalSensors / (ms / 1000));
  
  console.log(JSON.stringify({
    lang: "node",
    type: "algorithmic", 
    workers,
    sensors: totalSensors,
    iterations,
    ms: +ms.toFixed(1),
    ops_per_sec: opsPerSec,
    avg_risk: +avgRisk.toFixed(6),
    checksum
  }));
}

if (isMainThread) {
  // Default: 100 sensors, 50k iterations per sensor = 5M total operations
  runWorkers(100, 50000).catch(e => { console.error(e); process.exit(1); });
} else {
  const { sensorCount, iterations, workerId } = workerData;
  const start = performance.now();
  const sensors = generateSensorData(sensorCount, `sensor-w${workerId}`);
  const result = processBatch(sensors, iterations);
  const ms = performance.now() - start;
  
  parentPort.postMessage({
    sensors: sensorCount,
    ms,
    avgRisk: result.avgRisk,
    checksum: result.checksum
  });
}
