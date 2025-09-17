package bench;

import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Algorithmic Benchmark: Monte Carlo Simulation for IoT Sensor Risk Analysis
 * 
 * This benchmark is designed to showcase Java's strengths:
 * - Heavy mathematical computation
 * - Tight loops with JIT optimization
 * - CPU-intensive work
 * - Long-running computation allowing JIT warmup
 */
public class AlgoBench {
    
    // Pseudo-random number generator for consistent results
    static class PRNG {
        private long seed;
        
        public PRNG(long seed) {
            this.seed = seed;
        }
        
        public double next() {
            seed = (seed * 9301L + 49297L) % 233280L;
            return (double) seed / 233280.0;
        }
    }
    
    static class SensorData {
        final String deviceId;
        final double temperature;
        final double humidity;
        final double pressure;
        final double vibration;
        
        SensorData(String deviceId, double temperature, double humidity, double pressure, double vibration) {
            this.deviceId = deviceId;
            this.temperature = temperature;
            this.humidity = humidity;
            this.pressure = pressure;
            this.vibration = vibration;
        }
    }
    
    static class RiskResult {
        final double riskScore;
        final double failureProbability;
        final long checksum;
        
        RiskResult(double riskScore, double failureProbability, long checksum) {
            this.riskScore = riskScore;
            this.failureProbability = failureProbability;
            this.checksum = checksum;
        }
    }
    
    // Complex sensor failure risk calculation using Monte Carlo simulation
    static RiskResult calculateSensorRisk(String deviceId, double temperature, double humidity, 
                                         double pressure, double vibration, int iterations) {
        PRNG prng = new PRNG(deviceId.charAt(0) * 1000L);
        double riskScore = 0.0;
        double failureProbability = 0.0;
        
        // Monte Carlo simulation - this is where Java's JIT will shine
        for (int i = 0; i < iterations; i++) {
            // Simulate environmental stress factors with complex math
            double tempStress = Math.exp((temperature - 25.0) / 15.0) * (1.0 + 0.1 * Math.sin(i * 0.01));
            double humidityStress = Math.pow(humidity / 100.0, 2.0) * (1.0 + 0.05 * Math.cos(i * 0.02));
            double pressureStress = Math.abs(pressure - 1013.25) / 50.0 * (1.0 + 0.03 * Math.sin(i * 0.015));
            double vibrationStress = Math.sqrt(vibration) * (1.0 + 0.08 * Math.cos(i * 0.008));
            
            // Complex failure probability calculation
            double randomFactor = prng.next();
            double stressCombination = tempStress * humidityStress + pressureStress * vibrationStress;
            double failureThreshold = 2.5 + randomFactor * 0.5;
            
            // Weibull distribution for failure modeling
            double shape = 1.5 + randomFactor * 0.3;
            double scale = 100.0 + randomFactor * 20.0;
            double weibullProb = 1.0 - Math.exp(-Math.pow(stressCombination / scale, shape));
            
            if (weibullProb > failureThreshold / 10.0) {
                failureProbability += weibullProb;
            }
            
            // Statistical moments calculation
            riskScore += Math.pow(stressCombination, 1.8) * Math.log(1.0 + weibullProb);
            
            // Additional complexity: Fourier-like analysis
            if (i % 1000 == 0) {
                for (int j = 1; j <= 10; j++) {
                    riskScore += Math.sin(j * stressCombination) * Math.cos(j * failureProbability) / j;
                }
            }
        }
        
        return new RiskResult(
            riskScore / iterations,
            failureProbability / iterations,
            (long) (riskScore * 1000000.0) % 1000000L
        );
    }
    
    // Generate sensor data
    static List<SensorData> generateSensorData(int count, String devicePrefix) {
        List<SensorData> sensors = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            sensors.add(new SensorData(
                devicePrefix + "-" + i,
                20.0 + (i % 60) + Math.sin(i * 0.1) * 5.0,
                40.0 + (i % 40) + Math.cos(i * 0.05) * 10.0,
                1000.0 + (i % 50) + Math.sin(i * 0.02) * 15.0,
                1.0 + (i % 10) + Math.cos(i * 0.03) * 2.0
            ));
        }
        return sensors;
    }
    
    static class BatchResult {
        final double avgRisk;
        final double avgFailureProb;
        final long checksum;
        
        BatchResult(double avgRisk, double avgFailureProb, long checksum) {
            this.avgRisk = avgRisk;
            this.avgFailureProb = avgFailureProb;
            this.checksum = checksum;
        }
    }
    
    static BatchResult processBatch(List<SensorData> sensors, int iterations) {
        double totalRisk = 0.0;
        double totalFailureProb = 0.0;
        long checksum = 0L;
        
        for (SensorData sensor : sensors) {
            RiskResult result = calculateSensorRisk(
                sensor.deviceId,
                sensor.temperature,
                sensor.humidity,
                sensor.pressure,
                sensor.vibration,
                iterations
            );
            
            totalRisk += result.riskScore;
            totalFailureProb += result.failureProbability;
            checksum = (checksum + result.checksum) % 1000000000L;
        }
        
        return new BatchResult(
            totalRisk / sensors.size(),
            totalFailureProb / sensors.size(),
            checksum
        );
    }
    
    public static void main(String[] args) throws Exception {
        final int sensorCount = Integer.getInteger("sensors", 100);
        final int iterations = Integer.getInteger("iterations", 50000);
        final int workers = Integer.getInteger("workers", Runtime.getRuntime().availableProcessors());
        
        // Warmup phase - crucial for Java JIT optimization
        System.err.println("Warming up JIT compiler...");
        List<SensorData> warmupSensors = generateSensorData(10, "warmup");
        for (int i = 0; i < 3; i++) {
            processBatch(warmupSensors, 1000);
        }
        System.err.println("Warmup complete, starting benchmark...");
        
        ExecutorService pool = Executors.newFixedThreadPool(workers);
        List<Future<BatchResult>> futures = new ArrayList<>();
        long t0 = System.nanoTime();
        
        // Distribute work across threads
        int sensorsPerWorker = sensorCount / workers;
        int remainingSensors = sensorCount % workers;
        
        for (int w = 0; w < workers; w++) {
            final int workerSensors = sensorsPerWorker + (w < remainingSensors ? 1 : 0);
            final String prefix = "sensor-w" + w;
            
            futures.add(pool.submit(() -> {
                List<SensorData> sensors = generateSensorData(workerSensors, prefix);
                return processBatch(sensors, iterations);
            }));
        }
        
        // Collect results
        double totalRisk = 0.0;
        long totalChecksum = 0L;
        int totalSensors = 0;
        
        for (Future<BatchResult> future : futures) {
            BatchResult result = future.get();
            totalRisk += result.avgRisk;
            totalChecksum = (totalChecksum + result.checksum) % 1000000000L;
            totalSensors += sensorsPerWorker;
        }
        
        pool.shutdown();
        double ms = (System.nanoTime() - t0) / 1e6;
        long opsPerSec = Math.round(sensorCount / (ms / 1000.0));
        
        System.out.println(String.format(Locale.ROOT,
            "{\"lang\":\"java\",\"type\":\"algorithmic\",\"workers\":%d,\"sensors\":%d," +
            "\"iterations\":%d,\"ms\":%.1f,\"ops_per_sec\":%d,\"avg_risk\":%.6f,\"checksum\":%d}",
            workers, sensorCount, iterations, ms, opsPerSec, 
            totalRisk / workers, totalChecksum));
    }
}
