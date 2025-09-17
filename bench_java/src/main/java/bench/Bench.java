package bench;

import com.fasterxml.jackson.core.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicLong;

public class Bench {
  static final JsonFactory JF = new JsonFactory();
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
    for (byte b : bytes) { h ^= (b & 0xff); h *= 0x01000193; }
    return h;
  }

  static final class Agg { int c, a; long chk; }
  static final class Result { final int devs; final int alarms; final long chk; Result(int d,int a,long c){devs=d;alarms=a;chk=c;} }

  static Result processBatch(List<String> batch) throws Exception {
    Map<String, Agg> agg = new HashMap<>();
    int alarmCount = 0;
    long checksumTotal = 0;

    for (String s : batch) {
      byte[] bytes = s.getBytes(StandardCharsets.UTF_8);
      JsonParser p = JF.createParser(bytes);

      String deviceId = null, status = null;
      int temp = 0;
      long ts = 0L;

      // stream parse: {"deviceId": "...", "ts": ..., "temp": ..., "status": "...", "payload":"..."}
      if (p.nextToken() != JsonToken.START_OBJECT) throw new RuntimeException("bad");
      while (p.nextToken() != JsonToken.END_OBJECT) {
        String field = p.getCurrentName();
        p.nextToken();
        switch (field) {
          case "deviceId" -> deviceId = p.getValueAsString();
          case "ts"       -> ts = p.getLongValue();
          case "temp"     -> temp = p.getIntValue();
          case "status"   -> status = p.getValueAsString();
          default         -> p.skipChildren();
        }
      }
      p.close();

      // validate
      if (deviceId == null || status == null || ts == 0L) throw new RuntimeException("bad record");

      // enrich
      boolean isAlarm = temp > 95 || "ALARM".equals(status);
      if (isAlarm) alarmCount++;

      // aggregate
      Agg a = agg.get(deviceId);
      if (a == null) { a = new Agg(); agg.put(deviceId, a); }
      a.c++; if (isAlarm) a.a++;
      a.chk += fnv1a32(bytes);
    }

    for (Agg a : agg.values()) checksumTotal += a.chk;
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
    long devs = 0, alarms = 0;

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
      devs += r.devs; alarms += r.alarms; checksum.addAndGet(r.chk);
    }
    pool.shutdown();
    double ms = (System.nanoTime() - t0) / 1e6;
    long rps = Math.round(total / (ms / 1000.0));
    System.out.println("{\"lang\":\"java\",\"workers\":"+workers+",\"total\":"+total+"," +
      "\"ms\":"+String.format(java.util.Locale.ROOT,"%.1f", ms)+",\"rps\":"+rps+",\"checksum\":"+checksum.get()+"}");
  }
}
