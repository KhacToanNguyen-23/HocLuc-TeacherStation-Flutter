package vn.teaching.integrations;

import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.web.client.ResourceAccessException;
import java.net.http.HttpClient;
import java.time.Duration;
import java.util.Map;

@Component
public class GoogleHttpGateway implements GoogleGateway {
    private final RestClient http;
    public GoogleHttpGateway() {
        var factory = new JdkClientHttpRequestFactory(HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build());
        factory.setReadTimeout(Duration.ofSeconds(20));
        http = RestClient.builder().requestFactory(factory).build();
    }
    @Override public Map<String, Object> token(Map<String, String> form) {
        var fields = new LinkedMultiValueMap<String, String>(); form.forEach(fields::add);
        return execute(() -> http.post().uri("https://oauth2.googleapis.com/token")
            .contentType(MediaType.APPLICATION_FORM_URLENCODED).body(fields).retrieve().body(Map.class));
    }
    @Override public Map<String, Object> call(String method, String url, String token, Object body) {
        if (!url.startsWith("https://classroom.googleapis.com/") && !url.startsWith("https://meet.googleapis.com/")
                && !url.startsWith("https://www.googleapis.com/calendar/") && !url.equals("https://openidconnect.googleapis.com/v1/userinfo"))
            throw new IllegalArgumentException("Unsupported Google endpoint");
        return execute(() -> {
            var request = http.method(HttpMethod.valueOf(method)).uri(url).headers(h -> h.setBearerAuth(token));
            if (body != null) request.contentType(MediaType.APPLICATION_JSON).body(body);
            return request.retrieve().body(Map.class);
        });
    }
    @Override public void revoke(String token) {
        var fields = new LinkedMultiValueMap<String, String>(); fields.add("token", token);
        execute(() -> { http.post().uri("https://oauth2.googleapis.com/revoke").contentType(MediaType.APPLICATION_FORM_URLENCODED)
            .body(fields).retrieve().toBodilessEntity(); return Map.of(); });
    }
    @SuppressWarnings("unchecked")
    private Map<String, Object> execute(java.util.function.Supplier<Map> action) {
        try { var result = action.get(); return result == null ? Map.of() : result; }
        catch (RestClientResponseException e) {
            int status = e.getStatusCode().value();
            // Never return Google's raw body: it can contain tokens or personal data.
            throw new GoogleFailure(status == 401 ? 401 : 502, "GOOGLE_" + status,
                status == 401 ? "Kết nối Google hết hiệu lực. Vui lòng kết nối lại."
                : status == 403 ? "Google từ chối thao tác. Kiểm tra quyền đã cấp, API và chính sách tài khoản trường."
                : "Google chưa hoàn tất thao tác (" + status + "). Có thể đồng bộ hoặc thử lại.");
        } catch (ResourceAccessException e) {
            throw new GoogleFailure(502, "GOOGLE_NETWORK", "Không nhận được phản hồi Google. Đồng bộ trước khi thử lại để tránh tạo trùng.");
        }
    }
}
