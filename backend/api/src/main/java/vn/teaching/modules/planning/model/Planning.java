package vn.teaching.modules.planning.model;

import java.util.UUID;

public class Planning {
    private String id;
    private String title;
    private String subject;
    private int pageCount;
    private long createdAt;
    private long updatedAt;
    private String teacherId;

    public Planning() {
        this.id = "plan_" + UUID.randomUUID().toString().substring(0, 8);
        long now = System.currentTimeMillis();
        this.createdAt = now;
        this.updatedAt = now;
        this.pageCount = 1;
        this.subject = "Chung";
        this.teacherId = "teacher_default";
    }

    public Planning(String title, String subject) {
        this();
        this.title = title != null && !title.isBlank() ? title : "Kế hoạch bài giảng mới";
        this.subject = subject != null && !subject.isBlank() ? subject : "Chung";
    }

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getSubject() { return subject; }
    public void setSubject(String subject) { this.subject = subject; }

    public int getPageCount() { return pageCount; }
    public void setPageCount(int pageCount) { this.pageCount = pageCount; }

    public long getCreatedAt() { return createdAt; }
    public void setCreatedAt(long createdAt) { this.createdAt = createdAt; }

    public long getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(long updatedAt) { this.updatedAt = updatedAt; }

    public String getTeacherId() { return teacherId; }
    public void setTeacherId(String teacherId) { this.teacherId = teacherId; }
}

