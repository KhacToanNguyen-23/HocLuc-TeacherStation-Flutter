package vn.teaching.integrations;

import java.util.Map;

/** Provider boundary; tokens and Google responses never reach the UI directly. */
public interface GoogleGateway {
    Map<String, Object> token(Map<String, String> form);
    Map<String, Object> call(String method, String url, String token, Object body);
    void revoke(String token);
}
