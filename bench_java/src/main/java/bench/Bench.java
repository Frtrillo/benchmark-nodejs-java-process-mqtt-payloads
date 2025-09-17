package bench;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicLong;

public class Bench {
    static final ObjectMapper MAPPER = new ObjectMapper();
    static final int PAYLOAD_SIZE = 64;

    static String genPayload(int i, int devices) {
        String dev = "dev-" + (i % devices);
        int temp = (i % 120);
        String status = (temp > 95 && (i % 7 == 0)) ? "ALARM" : "OK";
        StringBuilder sb = new StringBuilder(128 + PAYLOAD_SIZE);
        sb.append("{\"deviceId\":\"").append(dev).append("\",")
          .append("\"ts\":").append(System.currentTimeMillis()).append(",")
          .append("\"temp\":").append(temp).append(",")
          .append("\"status\":\"").append(status).append("\",")
          .append("\"payload\":\"").append("x".repeat(PAYLOAD_SIZE)).append("\"}");
        return sb.toString();
    }

    static int fnv1a32(byte[] bytes) {
        int h = 0x811c9dc5;
        for (byte b : bytes) {
            h ^= (b & 0xff);
            h *= 0x01000193;
        }
        return h;
    }

    static class Agg { int count; int alarms; long checksum; }
    static class Result { final int devices; final int alarmCount; final long checksumTotal;
        Result(int d, int a, long c){ devices=d; alarmCount=a; checksumTotal=c; } }

    static Result processBatch(List<String> batch) throws Exception {
        Map<String, Agg> agg = new HashMap<>();
        int alarmCount = 0;
        long checksumTotal = 0;

        for (String s : batch) {
            JsonNode node = MAPPER.readTree(s);

            if (!node.hasNonNull("deviceId") || !node.hasNonNull("ts") ||
                !node.hasNonNull("temp") || !node.hasNonNull("status"))
                throw new RuntimeException("bad record");

            String deviceId = node.get("deviceId").asText();
            int temp = node.get("temp").asInt();
            String status = node.get("status").asText();

            boolean isAlarm = temp > 95 || "ALARM".equals(status);
            if (isAlarm) alarmCount++;

            Agg a = agg.get(deviceId);
            if (a == null) { a = new Agg(); agg.put(deviceId, a); }
            a.count++;
            if (isAlarm) a.alarms++;
            a.checksum += fnv1a32(s.getBytes(StandardCharsets.UTF_8));
        }
        for (Agg a : agg.values()) checksumTotal += a.checksum;
        return new Result(agg.size(), alarmCount, checksumTotal);
    }

    public static void main(String[] args) throws Exception {
        final int total   = Integer.getInteger("total",   1_000_000);
        final int workers = Integer.getInteger("workers", Runtime.getRuntime().availableProcessors());
        final int batch   = Integer.getInteger("batch",   10_000);
        final int devices = Integer.getInteger("devices", 1_000);

        ExecutorService pool = Executors.newFixedThreadPool(workers);
        List<Future<Result>> futures = new ArrayList<>();
        long t0 = System.nanoTime();
        AtomicLong checksum = new AtomicLong();
        long devicesTotal = 0, alarmsTotal = 0;

        int submitted = 0;
        while (submitted < total) {
            int n = Math.min(batch, total - submitted);
            List<String> payloads = new ArrayList<>(n);
            for (int i = 0; i < n; i++) payloads.add(genPayload(submitted + i, devices));
            futures.add(pool.submit(() -> processBatch(payloads)));
            submitted += n;
        }

        for (Future<Result> f : futures) {
            Result r = f.get();
            devicesTotal += r.devices;
            alarmsTotal  += r.alarmCount;
            checksum.addAndGet(r.checksumTotal);
        }
        pool.shutdown();

        double ms = (System.nanoTime() - t0) / 1e6;
        long rps = Math.round(total / (ms / 1000.0));
        System.out.println("{\"lang\":\"java\",\"workers\":"+workers+"," +
                "\"total\":"+total+",\"ms\":"+String.format(Locale.ROOT,"%.1f", ms)+"," +
                "\"rps\":"+rps+",\"checksum\":"+checksum.get()+"}");
    }
}
