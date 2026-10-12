package vn.teaching.model;

public class Classroom {
    private String id;
    private String teacherId;
    private String title;
    private String meetingUrl;
    private String status;
    private long startedAt;
    private Long endedAt;
    private int durationMinutes;
    private long createdAt;
    private boolean success;
    private String error;

    public Classroom() {
        this.createdAt = System.currentTimeMillis();
        this.startedAt = this.createdAt;
    }

    public Classroom(boolean success, String meetingUrl, String status) {
        this.id = java.util.UUID.randomUUID().toString();
        this.success = success;
        this.meetingUrl = meetingUrl;
        this.status = status;
        this.createdAt = System.currentTimeMillis();
        this.startedAt = this.createdAt;
    }

    public static Classroom error(String errorMessage) {
        Classroom c = new Classroom();
        c.success = false;
        c.error = errorMessage;
        return c;
    }

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    public String getTeacherId() { return teacherId; }
    public void setTeacherId(String teacherId) { this.teacherId = teacherId; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getMeetingUrl() { return meetingUrl; }
    public void setMeetingUrl(String meetingUrl) { this.meetingUrl = meetingUrl; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public long getStartedAt() { return startedAt; }
    public void setStartedAt(long startedAt) { this.startedAt = startedAt; }

    public Long getEndedAt() { return endedAt; }
    public void setEndedAt(Long endedAt) { this.endedAt = endedAt; }

    public int getDurationMinutes() { return durationMinutes; }
    public void setDurationMinutes(int durationMinutes) { this.durationMinutes = durationMinutes; }

    public long getCreatedAt() { return createdAt; }
    public void setCreatedAt(long createdAt) { this.createdAt = createdAt; }

    public boolean isSuccess() { return success; }
    public void setSuccess(boolean success) { this.success = success; }

    public String getError() { return error; }
    public void setError(String error) { this.error = error; }
}
