package com.example.demo;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class CheckController {

    private static final List<String> NAMES = List.of("postgres", "redis", "kafka", "s3");

    private final StackChecks checks;

    public CheckController(StackChecks checks) {
        this.checks = checks;
    }

    /** Liveness only: does not touch any backing service. */
    @GetMapping("/ping")
    public String ping() {
        return "ok";
    }

    /** Runs every check. Returns 200 if all are UP, otherwise 503. */
    @GetMapping("/check")
    public ResponseEntity<Map<String, Object>> all() {
        Map<String, Object> results = new LinkedHashMap<>();
        boolean allUp = true;
        for (String name : NAMES) {
            Map<String, Object> result = checks.run(name);
            results.put(name, result);
            allUp &= "UP".equals(result.get("status"));
        }
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("overall", allUp ? "UP" : "DOWN");
        body.putAll(results);
        return ResponseEntity.status(allUp ? 200 : 503).body(body);
    }

    /** Runs a single check: postgres, redis, kafka or s3 (object storage). */
    @GetMapping("/check/{name}")
    public ResponseEntity<Map<String, Object>> one(@PathVariable String name) {
        if (!NAMES.contains(name)) {
            return ResponseEntity.notFound().build();
        }
        Map<String, Object> result = checks.run(name);
        return ResponseEntity.status("UP".equals(result.get("status")) ? 200 : 503).body(result);
    }
}
