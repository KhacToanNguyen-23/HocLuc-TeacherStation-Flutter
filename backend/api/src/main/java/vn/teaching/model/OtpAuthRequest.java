package vn.teaching.model;

public class OtpAuthRequest {
    private String target; // Phone number or email
    private String otp;    // 6-digit OTP code
    private String name;   // Teacher name for signup / profile
    private String type;   // "login" or "signup"

    public OtpAuthRequest() {}

    public OtpAuthRequest(String target, String otp, String name, String type) {
        this.target = target;
        this.otp = otp;
        this.name = name;
        this.type = type;
    }

    public String getTarget() { return target; }
    public void setTarget(String target) { this.target = target; }

    public String getOtp() { return otp; }
    public void setOtp(String otp) { this.otp = otp; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getType() { return type; }
    public void setType(String type) { this.type = type; }
}
