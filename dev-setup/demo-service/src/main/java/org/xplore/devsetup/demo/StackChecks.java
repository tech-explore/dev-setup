package org.xplore.devsetup.demo;

/**
 * @author Murali Krishna Punaganti Venkata
 * Created at: 15/10/2026(Thursday) 17:43
 */

import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.CreateBucketRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.HeadBucketRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;

/** One round-trip check per backing service: write something, read it back. */
@Service
public class StackChecks {

  private final JdbcTemplate jdbc;
  private final StringRedisTemplate redis;
  private final KafkaTemplate<String, String> kafka;
  private final S3Client s3;
  private final String topic;
  private final String bucket;

  /** Checks waiting for their Kafka message to come back, keyed by message key. */
  private final Map<String, CompletableFuture<String>> pending = new ConcurrentHashMap<>();

  public StackChecks(JdbcTemplate jdbc,
                     StringRedisTemplate redis,
                     KafkaTemplate<String, String> kafka,
                     S3Client s3,
                     @Value("${demo.topic}") String topic,
                     @Value("${s3.bucket}") String bucket) {
    this.jdbc = jdbc;
    this.redis = redis;
    this.kafka = kafka;
    this.s3 = s3;
    this.topic = topic;
    this.bucket = bucket;
  }

  /** Runs one check by name and returns status, detail or error, and duration. */
  public Map<String, Object> run(String name) {
    long start = System.nanoTime();
    Map<String, Object> result = new LinkedHashMap<>();
    try {
      String detail = switch (name) {
        case "postgres" -> postgres();
        case "redis" -> redis();
        case "kafka" -> kafka();
        case "s3" -> objectStorage();
        default -> throw new IllegalArgumentException("unknown check: " + name);
      };
      result.put("status", "UP");
      result.put("detail", detail);
    } catch (Exception e) {
      result.put("status", "DOWN");
      result.put("error", e.getClass().getSimpleName() + ": " + e.getMessage());
    }
    result.put("ms", (System.nanoTime() - start) / 1_000_000);
    return result;
  }

  private String postgres() {
    jdbc.execute("create table if not exists demo_checks ("
      + "id serial primary key, "
      + "created_at timestamptz not null default now(), "
      + "note text)");
    jdbc.update("insert into demo_checks (note) values (?)", "check at " + Instant.now());
    Integer rows = jdbc.queryForObject("select count(*) from demo_checks", Integer.class);
    return "inserted a row; table demo_checks now has " + rows + " rows";
  }

  private String redis() {
    String key = "demo:ping";
    String value = Instant.now().toString();
    redis.opsForValue().set(key, value, Duration.ofMinutes(1));
    String back = redis.opsForValue().get(key);
    if (!value.equals(back)) {
      throw new IllegalStateException("read back a different value: " + back);
    }
    return "set and read back key " + key;
  }

  private String kafka() throws Exception {
    String id = UUID.randomUUID().toString();
    CompletableFuture<String> received = new CompletableFuture<>();
    pending.put(id, received);
    try {
      kafka.send(topic, id, "hello-" + id).get(10, TimeUnit.SECONDS);
      received.get(15, TimeUnit.SECONDS);
      return "sent a message to topic " + topic + " and received it back";
    } finally {
      pending.remove(id);
    }
  }

  @KafkaListener(topics = "${demo.topic}", groupId = "demo-group")
  public void onMessage(ConsumerRecord<String, String> record) {
    CompletableFuture<String> waiting = pending.remove(record.key());
    if (waiting != null) {
      waiting.complete(record.value());
    }
  }

  private String objectStorage() {
    try {
      s3.headBucket(HeadBucketRequest.builder().bucket(bucket).build());
    } catch (S3Exception e) {
      if (e.statusCode() != 404) {
        throw e;
      }
      s3.createBucket(CreateBucketRequest.builder().bucket(bucket).build());
    }
    String key = "check-" + System.currentTimeMillis() + ".txt";
    String text = "hello from demo-service at " + Instant.now();
    s3.putObject(PutObjectRequest.builder().bucket(bucket).key(key).build(),
      RequestBody.fromString(text));
    String back = s3.getObjectAsBytes(
      GetObjectRequest.builder().bucket(bucket).key(key).build()).asUtf8String();
    if (!text.equals(back)) {
      throw new IllegalStateException("read back different content");
    }
    return "wrote and read back object " + key + " in bucket " + bucket;
  }
}
