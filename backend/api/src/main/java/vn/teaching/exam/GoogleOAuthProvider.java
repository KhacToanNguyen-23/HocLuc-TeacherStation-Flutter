package vn.teaching.exam;

public interface GoogleOAuthProvider {
    record Identity(String subject,String email,String name,String accessToken) {}
    Identity exchange(String code,String verifier,String redirectUri);
}
