package vn.teaching.service;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;

public class GoogleMeetService {
    private static final Logger log = LoggerFactory.getLogger(GoogleMeetService.class);
    private final java.net.http.HttpClient httpClient;

    public GoogleMeetService() {
        this.httpClient = java.net.http.HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();
    }

    public String createOfficialMeetRoom(String accessToken, String title) {
        if (accessToken == null || accessToken.isBlank()) {
            return null;
        }

        long startedAt = System.nanoTime();
        try {
            String now = Instant.now().toString();
            String end = Instant.now().plus(Duration.ofHours(3)).toString();

            JsonObject body = new JsonObject();
            body.addProperty("summary", title != null ? title : "Lớp học trực tuyến · Trạm Giảng Dạy");

            JsonObject start = new JsonObject();
            start.addProperty("dateTime", now);
            JsonObject endTime = new JsonObject();
            endTime.addProperty("dateTime", end);
            body.add("start", start);
            body.add("end", endTime);

            JsonObject confData = new JsonObject();
            JsonObject createReq = new JsonObject();
            createReq.addProperty("requestId", "meet-" + System.currentTimeMillis());
            JsonObject solutionKey = new JsonObject();
            solutionKey.addProperty("type", "hangoutsMeet");
            createReq.add("conferenceSolutionKey", solutionKey);
            confData.add("createRequest", createReq);
            body.add("conferenceData", confData);

            java.net.http.HttpRequest request = java.net.http.HttpRequest.newBuilder()
                .uri(URI.create("https://www.googleapis.com/calendar/v3/calendars/primary/events?conferenceDataVersion=1"))
                .header("Authorization", "Bearer " + accessToken)
                .header("Content-Type", "application/json")
                .POST(java.net.http.HttpRequest.BodyPublishers.ofString(body.toString(), StandardCharsets.UTF_8))
                .timeout(Duration.ofSeconds(15))
                .build();

            java.net.http.HttpResponse<String> response = httpClient.send(
                request,
                java.net.http.HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8)
            );

            if (response.statusCode() == 200 || response.statusCode() == 201) {
                JsonObject json = JsonParser.parseString(response.body()).getAsJsonObject();
                if (json.has("hangoutLink")) {
                    log.info("[google-meet] Room created | status={} duration_ms={}", response.statusCode(),
                            (System.nanoTime() - startedAt) / 1_000_000);
                    return json.get("hangoutLink").getAsString();
                }
                log.warn("[google-meet] Room creation response missing meeting link | status={} duration_ms={}",
                        response.statusCode(), (System.nanoTime() - startedAt) / 1_000_000);
            } else {
                log.warn("[google-meet] Room creation failed | status={} duration_ms={}", response.statusCode(),
                        (System.nanoTime() - startedAt) / 1_000_000);
            }
        } catch (Exception e) {
            log.error("[google-meet] Room creation error | duration_ms={}",
                    (System.nanoTime() - startedAt) / 1_000_000, e);
        }
        return null;
    }
}
