package vn.teaching.service;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.springframework.stereotype.Service;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;

@Service
public class GoogleMeetService {
    private final HttpClient httpClient;
    private final URI spacesEndpoint;

    public GoogleMeetService() {
        this(HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build(),
                URI.create("https://meet.googleapis.com/v2/spaces"));
    }

    GoogleMeetService(HttpClient httpClient, URI spacesEndpoint) {
        this.httpClient = httpClient;
        this.spacesEndpoint = spacesEndpoint;
    }

    public record MeetSpace(String meetingUri, String name, String accessType) {}
    public static class AuthorizationRequiredException extends IllegalStateException {
        public AuthorizationRequiredException(String message) { super(message); }
    }

    public MeetSpace createOpenSpace(String accessToken) {
        if (accessToken == null || accessToken.isBlank()
                || accessToken.startsWith("demo_") || accessToken.startsWith("webview2_")) {
            throw new IllegalStateException("Cần kết nối Google và cấp quyền tạo phòng Meet.");
        }
        JsonObject config = new JsonObject();
        config.addProperty("accessType", "OPEN");
        config.addProperty("entryPointAccess", "ALL");
        JsonObject body = new JsonObject();
        body.add("config", config);
        try {
            HttpRequest request = HttpRequest.newBuilder(spacesEndpoint)
                    .header("Authorization", "Bearer " + accessToken)
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(body.toString(), StandardCharsets.UTF_8))
                    .timeout(Duration.ofSeconds(20)).build();
            HttpResponse<String> response = httpClient.send(request,
                    HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            if (response.statusCode() == 401) {
                throw new AuthorizationRequiredException("Phiên Google không còn hợp lệ. Hãy kết nối lại Google.");
            }
            if (response.statusCode() == 403) {
                throw new IllegalStateException("Google từ chối tạo phòng OPEN. Kiểm tra quyền Meet, Meet API và chính sách Workspace.");
            }
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw new IllegalStateException("Không thể tạo phòng Google Meet (HTTP " + response.statusCode() + "). Hãy thử lại.");
            }
            JsonObject json = JsonParser.parseString(response.body()).getAsJsonObject();
            String accessType = json.has("config") && json.getAsJsonObject("config").has("accessType")
                    ? json.getAsJsonObject("config").get("accessType").getAsString() : "";
            if (!"OPEN".equals(accessType)) {
                throw new IllegalStateException("Google chưa xác nhận phòng OPEN. Hãy kiểm tra chính sách tham gia của tài khoản Google.");
            }
            String meetingUri = json.has("meetingUri") ? json.get("meetingUri").getAsString() : "";
            if (!meetingUri.matches("https://meet\\.google\\.com/[a-z]{3}-[a-z]{4}-[a-z]{3}")) {
                throw new IllegalStateException("Google không trả về đường dẫn phòng Meet hợp lệ.");
            }
            return new MeetSpace(meetingUri, json.has("name") ? json.get("name").getAsString() : "", accessType);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Đã hủy yêu cầu tạo phòng Google Meet.");
        } catch (IllegalStateException e) {
            throw e;
        } catch (Exception e) {
            throw new IllegalStateException("Không kết nối được Google Meet. Kiểm tra mạng rồi thử lại.");
        }
    }
}
