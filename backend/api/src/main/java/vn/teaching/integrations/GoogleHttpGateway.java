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
        try {
            return http.post().uri("https://oauth2.googleapis.com/token")
                .contentType(MediaType.APPLICATION_FORM_URLENCODED).body(fields).retrieve().body(Map.class);
        } catch (RestClientResponseException e) {
            String error = "";
            try { error = new com.fasterxml.jackson.databind.ObjectMapper().readTree(e.getResponseBodyAsString()).path("error").asText(); }
            catch (Exception ignored) { }
            throw tokenFailure(e.getStatusCode().value(),error);
        } catch (ResourceAccessException e) {
            throw new GoogleFailure(503,"GOOGLE_NETWORK","Không kết nối được Google. Kiểm tra mạng rồi thử lại; chưa cần cấp quyền lại.");
        }
    }
    static GoogleFailure tokenFailure(int status, String error) {
        if ("invalid_grant".equals(error)) return new GoogleFailure(401,"RECONNECT_GOOGLE","Quyền Google đã hết hiệu lực hoặc bị thu hồi. Vui lòng cấp quyền lại.");
        if ("invalid_client".equals(error) || "unauthorized_client".equals(error))
            return new GoogleFailure(503,"GOOGLE_CLIENT_CONFIG","Cấu hình OAuth của ứng dụng không hợp lệ. Liên hệ người cài đặt HocLuc.");
        return new GoogleFailure(503,status == 429 ? "GOOGLE_RATE_LIMIT" : "GOOGLE_TEMPORARY","Google chưa xử lý được yêu cầu. Vui lòng thử lại sau; chưa cần cấp quyền lại.");
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
            if (status == 403) {
                try {
                    var body = new com.fasterxml.jackson.databind.ObjectMapper().readTree(e.getResponseBodyAsString());
                    for (var detail : body.path("error").path("errors")) {
                        if ("insufficientPermissions".equals(detail.path("reason").asText()))
                            throw new GoogleFailure(403,"SCOPE_MISSING","Google chưa cấp đủ quyền cho thao tác này. Vui lòng cấp quyền lại.");
                    }
                } catch (GoogleFailure missing) { throw missing; }
                catch (Exception ignored) { }
            }
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
