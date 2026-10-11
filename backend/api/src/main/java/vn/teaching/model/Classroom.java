package vn.teaching.model;

public class Classroom {
    private boolean success;
    private String meetingUrl;
    private String status;
    private long createdAt;
    private String error;

    public Classroom() {}

    public Classroom(boolean success, String meetingUrl, String status) {
        this.success = success;
        this.meetingUrl = meetingUrl;
        this.status = status;
        this.createdAt = System.currentTimeMillis();
    }

    public static Classroom error(String errorMessage) {
        Classroom c = new Classroom();
        c.success = false;
        c.error = errorMessage;
        return c;
    }

    public boolean isSuccess() { return success; }
    public void setSuccess(boolean success) { this.success = success; }

    public String getMeetingUrl() { return meetingUrl; }
    public void setMeetingUrl(String meetingUrl) { this.meetingUrl = meetingUrl; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public long getCreatedAt() { return createdAt; }
    public void setCreatedAt(long createdAt) { this.createdAt = createdAt; }

    public String getError() { return error; }
    public void setError(String error) { this.error = error; }
}
