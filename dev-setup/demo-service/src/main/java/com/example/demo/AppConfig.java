package com.example.demo;

import java.net.URI;

import org.apache.kafka.clients.admin.NewTopic;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.TopicBuilder;

import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;

@Configuration
public class AppConfig {

    /** S3 client pointed at RustFS (any S3-compatible server works). Path-style access keeps the bucket out of the hostname. */
    @Bean
    S3Client s3Client(@Value("${s3.endpoint}") String endpoint,
                      @Value("${s3.access-key}") String accessKey,
                      @Value("${s3.secret-key}") String secretKey) {
        return S3Client.builder()
                .endpointOverride(URI.create(endpoint))
                .region(Region.US_EAST_1)
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(accessKey, secretKey)))
                .forcePathStyle(true)
                .build();
    }

    /** Created on startup if Kafka is reachable. */
    @Bean
    NewTopic demoTopic(@Value("${demo.topic}") String topic) {
        return TopicBuilder.name(topic).partitions(1).replicas(1).build();
    }
}
