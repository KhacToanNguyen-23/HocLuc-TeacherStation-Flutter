package vn.teaching.integrations;

public class GoogleFailure extends RuntimeException {
    public final int status;
    public final String code;
    public GoogleFailure(int status, String code, String message) {
        super(message); this.status = status; this.code = code;
    }
}
