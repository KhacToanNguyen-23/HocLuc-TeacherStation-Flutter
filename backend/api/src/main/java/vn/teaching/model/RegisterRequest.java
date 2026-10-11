package vn.teaching.model;

public class RegisterRequest {
    private String target;
    private String otp;
    private String password;

    public RegisterRequest() {}

    public RegisterRequest(String target, String otp, String password) {
        this.target = target;
        this.otp = otp;
        this.password = password;
    }

    public String getTarget() {
        return target;
    }

    public void setTarget(String target) {
        this.target = target;
    }

    public String getOtp() {
        return otp;
    }

    public void setOtp(String otp) {
        this.otp = otp;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }
}
