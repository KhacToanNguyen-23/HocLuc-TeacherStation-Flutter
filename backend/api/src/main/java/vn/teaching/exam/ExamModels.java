package vn.teaching.exam;

import java.util.List;
import java.util.Map;

/** Immutable document contracts; foreign keys and ownership live in SQL as well. */
public final class ExamModels {
    private ExamModels() {}
    public record Account(String id, String email, String name, String role) {}
    public record Source(String id, String logicalKey, String relativePath, String examType,
                         String examVersion, String checksum, int revision, boolean active,
                         String status, int pages, String createdAt) {}
    public record Job(String id, String sourceId, String status, List<String> issues, String createdAt) {}
    public record Asset(String id, String sourceId, int page, String path, int x, int y, int width, int height) {}
    public record Group(String id, String sourceId, String section, String content, List<String> assets) {}
    public record Choice(String key, String text) {}
    public record Question(String id, String sourceId, int sourcePage, String examType, String examVersion,
                           String section, String subsection, String topic, String skill, String difficulty,
                           String cognitiveLevel, String type, String stem, List<Choice> choices,
                           String answer, List<String> acceptedAnswers, String solution, List<String> assets,
                           String groupId, String status, String fingerprint, List<String> solutionAssets) {
        public Question { if(solutionAssets==null) solutionAssets=List.of(); }
        public Question(String id,String sourceId,int sourcePage,String examType,String examVersion,String section,String subsection,String topic,String skill,String difficulty,String cognitiveLevel,String type,String stem,List<Choice> choices,String answer,List<String> acceptedAnswers,String solution,List<String> assets,String groupId,String status,String fingerprint) {
            this(id,sourceId,sourcePage,examType,examVersion,section,subsection,topic,skill,difficulty,cognitiveLevel,type,stem,choices,answer,acceptedAnswers,solution,assets,groupId,status,fingerprint,List.of());
        }
    }
    public record Quota(String section, String label, int count, String type, String topic, String skill, String difficulty) {}
    public record Matrix(String id, String examType, String examVersion, String name, String status,
                         int durationMinutes, int totalQuestions, List<Quota> quotas, String scoringPolicy,
                         double pointsPerCorrect, String provenance, String purpose) {
        public Matrix { if(purpose==null) purpose="FULL"; }
        public Matrix(String id,String examType,String examVersion,String name,String status,int durationMinutes,int totalQuestions,List<Quota> quotas,String scoringPolicy,double pointsPerCorrect,String provenance) {
            this(id,examType,examVersion,name,status,durationMinutes,totalQuestions,quotas,scoringPolicy,pointsPerCorrect,provenance,"FULL");
        }
    }
    public record Paper(String id, String teacherId, Matrix matrix, String title, String instructions,
                        int durationMinutes, int variant, String status, List<Question> questions, List<Group> groups, String createdAt) {}
    public record SchoolClass(String id, String teacherId, String name, String createdAt) {}
    public record Student(String id, String teacherId, String code, String fullName, String notes, String createdAt, String updatedAt) {}
    public record Session(String id, String teacherId, String classId, String paperId, String title, String assessedAt) {}
    public record Result(String id, String teacherId, String sessionId, String studentId, String level,
                         double score, Integer correctCount, int totalQuestions, Map<String,String> answers, String createdAt) {}
    public record ImportJob(String id, String teacherId, String sessionId, String classId, String kind,
                            List<Map<String,String>> rows, List<String> errors, long expiresAt, boolean committed) {}
}
