package vn.teaching.exam;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.web.client.RestClient;
import java.net.http.HttpClient;
import java.time.Duration;
import java.util.Map;

@Component
public class GoogleOAuthHttpProvider implements GoogleOAuthProvider {
    private final String clientId,clientSecret;
    private final RestClient http;
    public GoogleOAuthHttpProvider(@Value("${app.auth.google.client-id:}") String id,@Value("${app.auth.google.client-secret:}") String secret) {
        clientId=id; clientSecret=secret;
        var factory=new JdkClientHttpRequestFactory(HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build());
        factory.setReadTimeout(Duration.ofSeconds(15)); http=RestClient.builder().requestFactory(factory).build();
    }
    @Override public Identity exchange(String code,String verifier,String redirectUri) {
        var body=new LinkedMultiValueMap<String,String>(); body.add("client_id",clientId); body.add("client_secret",clientSecret);
        body.add("code",code); body.add("code_verifier",verifier); body.add("redirect_uri",redirectUri); body.add("grant_type","authorization_code");
        Map<?,?> tokens=http.post().uri("https://oauth2.googleapis.com/token").contentType(MediaType.APPLICATION_FORM_URLENCODED).body(body).retrieve().body(Map.class);
        if(tokens==null||!(tokens.get("access_token") instanceof String accessToken)||accessToken.isBlank()) throw ExamException.bad("Google không cấp token hợp lệ.");
        Map<?,?> identity=http.get().uri("https://openidconnect.googleapis.com/v1/userinfo").headers(h->h.setBearerAuth(accessToken)).retrieve().body(Map.class);
        if(identity==null||!Boolean.TRUE.equals(identity.get("email_verified"))||!(identity.get("sub") instanceof String subject)||!(identity.get("email") instanceof String email)) throw ExamException.bad("Google chưa xác minh danh tính/email.");
        return new Identity(subject,email,identity.get("name") instanceof String name?name:email,accessToken);
    }
}
