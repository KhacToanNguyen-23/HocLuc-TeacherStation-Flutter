package vn.teaching.dto;

import java.util.List;

public record GoogleCreateCourseRequest(
        String requestId,
        String title,
        String description,
        List<String> emails
) {}

