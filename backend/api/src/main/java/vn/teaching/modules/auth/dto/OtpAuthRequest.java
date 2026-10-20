package vn.teaching.modules.auth.dto;

import jakarta.validation.constraints.NotBlank;

public class OtpAuthRequest {
    @NotBlank(message = "Vui lòng cung cấp Số điện thoại hoặc Email.")
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

