package vn.teaching.modules.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public class RegisterRequest {
    @NotBlank(message = "Vui lòng cung cấp Số điện thoại hoặc Email.")
    private String target;

    @NotBlank(message = "Vui lòng nhập mã xác thực OTP.")
    private String otp;

    @NotBlank(message = "Vui lòng nhập mật khẩu.")
    @Size(min = 6, message = "Mật khẩu phải có ít nhất 6 ký tự.")
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

