package vn.teaching.exam;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.pdfbox.Loader;
import org.apache.pdfbox.pdmodel.*;
import org.apache.pdfbox.pdmodel.font.*;
import org.apache.pdfbox.text.PDFTextStripper;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.apache.poi.xwpf.usermodel.XWPFDocument;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static vn.teaching.exam.ExamModels.*;

@SpringBootTest
@AutoConfigureMockMvc
class ExamPlatformTest {
    @Autowired ExamAuth auth; @Autowired SourceService sources; @Autowired MatrixService matrices;
    @Autowired PaperService papers; @Autowired ExportService exports; @Autowired ResultService results;
    @Autowired AnalyticsService analytics; @Autowired ExamRepository repo; @Autowired MockMvc mvc; @Autowired ObjectMapper mapper;
    record Login(Account account,String token) {}
    record Fixture(Login teacher,Source source,Matrix matrix,Paper paper,SchoolClass schoolClass,Student student,Session session) {}
    Login teacher() { var session=auth.register(UUID.randomUUID()+"@test.vn","Password-test-2026","Giáo viên thử nghiệm"); return new Login((Account)session.get("user"),(String)session.get("token")); }
    Account admin() { return (Account)auth.login("admin@exam.test","Test-admin-password-2026").get("user"); }
    byte[] pdfBytes(boolean scan) throws Exception {
        try(PDDocument doc=new PDDocument(); ByteArrayOutputStream bytes=new ByteArrayOutputStream()) {
            PDPage page=new PDPage(); doc.addPage(page);
            try(PDPageContentStream stream=new PDPageContentStream(doc,page)) {
                if(!scan) { stream.beginText(); stream.setFont(new PDType1Font(Standard14Fonts.FontName.HELVETICA),12); stream.newLineAtOffset(40,700); stream.showText("Question 1. "+UUID.randomUUID()+" A. One B. Two C. Three D. Four"); stream.endText(); }
                else { stream.addRect(10,10,25,25); stream.fill(); }
            }
            doc.getDocumentInformation().setSubject(UUID.randomUUID().toString()); doc.save(bytes); return bytes.toByteArray();
        }
    }
    Source source() throws Exception { Source s=(Source)sources.upload(new MockMultipartFile("file","fixture.pdf","application/pdf",pdfBytes(false)),"fixtures/"+UUID.randomUUID()+".pdf","VACT","2026").get("source"); sources.process(s.id(),false); return sources.source(s.id()); }
    Question question(Source s,String section,String type,String group) throws Exception {
        Asset crop=sources.crop(s.id(),1,10,10,100,100);
        Question q=sources.edit(null,new Question(null,s.id(),1,"VACT","2026",section,"","algebra","reasoning","MEDIUM","APPLY",type,"Fixture "+UUID.randomUUID(),type.equals("MCQ")?List.of(new Choice("A","One"),new Choice("B","Two"),new Choice("C","Three"),new Choice("D","Four")):List.of(),type.equals("MCQ")?"B":"12.5",List.of(),"Lời giải đã duyệt",List.of(crop.id()),group,"NEEDS_REVIEW",null));
        return sources.approve(q.id(),admin(),true,true);
    }
    Matrix matrix(List<Quota> quotas) { Matrix m=new Matrix("test-"+UUID.randomUUID(),"VACT","2026","Ma trận fixture","ACTIVE",30,quotas.stream().mapToInt(Quota::count).sum(),quotas,"RAW_PRACTICE",1,"Test-only fixture, not an official matrix"); return matrices.create(m); }
    Fixture fixture(int count) throws Exception {
        Login teacher=teacher(); Source source=source(); for(int i=0;i<count;i++) question(source,"math","MCQ",null);
        Matrix matrix=matrix(List.of(new Quota("math","Math",count,"MCQ",null,null,null)));
        Paper paper=papers.generate(teacher.account().id(),new PaperService.Generate(matrix.id(),"Đề kiểm tra năng lực",List.of(source.id()),1,1L,null,null)).get(0);
        paper=papers.publish(paper.id(),teacher.account().id()); SchoolClass cls=results.createClass(teacher.account().id(),"12A1");
        Student student=results.createStudent(teacher.account().id(),"HS01","Nguyễn An","",cls.id());
        Session session=results.createSession(teacher.account().id(),cls.id(),paper.id(),"Lần 1","2026-10-13T01:00:00Z"); return new Fixture(teacher,source,matrix,paper,cls,student,session);
    }
    @Test void teacherSessionRequiresRealAuthAndCannotBecomeAdmin() throws Exception {
        Login teacher=teacher();
        mvc.perform(get("/api/exams/dashboard").header("X-Companion-Token","anything")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/exams/dashboard").header("Authorization","Bearer "+teacher.token())).andExpect(status().isOk());
        mvc.perform(get("/api/exams/admin/jobs").header("Authorization","Bearer "+teacher.token())).andExpect(status().isForbidden());
        mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON).content(mapper.writeValueAsString(Map.of("target",UUID.randomUUID()+"@test.vn","password","Password-test-2026","otp","123456","role","ADMIN")))).andExpect(status().isOk()).andExpect(jsonPath("$.user.role").value("TEACHER"));
    }
    @Test void identityIsStablePasswordHashedAndLogoutRevokes() {
        Login teacher=teacher(); Account again=(Account)auth.login(teacher.account().email(),"Password-test-2026").get("user"); assertEquals(teacher.account().id(),again.id());
        String hash=repo.jdbc().queryForObject("SELECT password_hash FROM exam_platform.accounts WHERE id=?",String.class,again.id()); assertTrue(hash.startsWith("$2")); assertNotEquals("Password-test-2026",hash);
        auth.logout("Bearer "+teacher.token()); assertThrows(ExamException.class,()->auth.authenticate("Bearer "+teacher.token()));
    }
    @Test void expiredSessionsAreRejected() {
        Login teacher=teacher(); repo.jdbc().update("UPDATE exam_platform.auth_sessions SET expires_at=0 WHERE account_id=?",teacher.account().id()); assertThrows(ExamException.class,()->auth.authenticate("Bearer "+teacher.token()));
    }
    @Test void checksumDedupAndRevisionAreIndependent() throws Exception {
        byte[] bytes=pdfBytes(false); String name="same/"+UUID.randomUUID()+".pdf";
        var first=sources.upload(new MockMultipartFile("file","a.pdf","application/pdf",bytes),name,"VACT","2026"); Source source=(Source)first.get("source");
        var duplicate=sources.upload(new MockMultipartFile("file","b.pdf","application/pdf",bytes),"different.pdf","HSA","2026"); assertEquals(true,duplicate.get("duplicate")); assertEquals(source.id(),((Source)duplicate.get("source")).id());
        var revision=sources.upload(new MockMultipartFile("file","a.pdf","application/pdf",pdfBytes(false)),name,"VACT","2026"); assertEquals(2,((Source)revision.get("source")).revision());
    }
    @Test void maliciousPathAndCorruptPdfAreRejected() {
        assertThrows(ExamException.class,()->sources.upload(new MockMultipartFile("file","file.pdf","application/pdf","not a pdf".getBytes()),"../file.pdf","VACT","2026"));
        assertThrows(ExamException.class,()->sources.upload(new MockMultipartFile("file","file.pdf","application/pdf","%PDF-broken".getBytes()),"file.pdf","VACT","2026"));
    }
    @Test void extractionRetainsVisualAssetsAndRequiresReview() throws Exception {
        Source source=source(); List<Question> candidates=repo.all("questions",Question.class).stream().filter(q->q.sourceId().equals(source.id())).toList(); assertEquals(1,candidates.size()); assertEquals("NEEDS_REVIEW",candidates.get(0).status()); assertEquals(4,candidates.get(0).choices().size()); assertFalse(sources.assets(source.id()).isEmpty()); assertTrue(sources.bank().stream().noneMatch(q->q.sourceId().equals(source.id())));
        assertThrows(ExamException.class,()->sources.approve(candidates.get(0).id(),admin(),true,true)); assertThrows(ExamException.class,()->sources.process(source.id(),false));
    }
    @Test void scanDoesNotPretendOcrHasRun() throws Exception {
        Source s=(Source)sources.upload(new MockMultipartFile("file","scan.pdf","application/pdf",pdfBytes(true)),"scan/"+UUID.randomUUID()+".pdf","HSA","2026").get("source");
        Job j=sources.process(s.id(),false); assertEquals("NEEDS_OCR",j.status()); assertEquals(1,sources.assets(s.id()).size()); assertFalse(j.issues().isEmpty());
    }
    @Test void missingQuotaIsReportedWithoutFiller() throws Exception {
        Source s=source(); Matrix m=matrix(List.of(new Quota("math","Toán",3,"MCQ",null,null,null))); question(s,"math","MCQ",null); Login teacher=teacher();
        ExamException e=assertThrows(ExamException.class,()->papers.generate(teacher.account().id(),new PaperService.Generate(m.id(),"Missing",List.of(s.id()),1,null,null,null))); assertEquals("INSUFFICIENT_BANK",e.code); assertTrue(e.details.toString().contains("missing=2")); assertTrue(repo.owned("papers",teacher.account().id(),Paper.class).isEmpty());
    }
    @Test void exactQuestionTypeQuotasAndVariantMapping() throws Exception {
        Source s=source(); question(s,"math","MCQ",null); question(s,"math","SHORT",null); Matrix m=matrix(List.of(new Quota("math","MCQ",1,"MCQ",null,null,null),new Quota("math","SHORT",1,"SHORT",null,null,null))); Login teacher=teacher();
        var generated=papers.generate(teacher.account().id(),new PaperService.Generate(m.id(),"Two types",List.of(s.id()),2,45L,null,null)); assertEquals(2,generated.size()); assertNotEquals(generated.get(0).id(),generated.get(1).id());
        for(Paper paper:generated) { assertEquals(1,paper.questions().stream().filter(q->q.type().equals("SHORT")).count()); assertEquals(2,repo.jdbc().queryForObject("SELECT COUNT(*) FROM exam_platform.paper_items WHERE paper_id=?",Integer.class,paper.id())); }
    }
    @Test void contextGroupIsIndivisible() throws Exception {
        Source s=source(); Group group=sources.group(new Group(null,s.id(),"math","Shared passage",List.of())); question(s,"math","MCQ",group.id()); question(s,"math","MCQ",group.id()); Login teacher=teacher();
        Matrix incompatible=matrix(List.of(new Quota("math","One",1,"MCQ",null,null,null)));
        ExamException e=assertThrows(ExamException.class,()->papers.generate(teacher.account().id(),new PaperService.Generate(incompatible.id(),"Group conflict",List.of(s.id()),1,1L,null,null))); assertEquals("GROUP_QUOTA_CONFLICT",e.code);
        Matrix compatible=matrix(List.of(new Quota("math","Two",2,"MCQ",null,null,null))); Paper paper=papers.generate(teacher.account().id(),new PaperService.Generate(compatible.id(),"Shared",List.of(s.id()),1,1L,null,null)).get(0); assertEquals(1,paper.groups().size()); assertTrue(paper.questions().stream().allMatch(q->group.id().equals(q.groupId())));
    }
    @Test void disabledSourcesCannotEnterNewPapers() throws Exception {
        Fixture f=fixture(1); sources.active(f.source().id(),false); assertTrue(sources.bank().stream().noneMatch(q->q.sourceId().equals(f.source().id())));
        assertThrows(ExamException.class,()->papers.generate(f.teacher().account().id(),new PaperService.Generate(f.matrix().id(),"Disabled",List.of(f.source().id()),1,1L,null,null)));
        assertTrue(exports.export(f.paper(),"pdf","answers").length>100);
    }
    @Test void publishedPapersAndApprovedQuestionsAreImmutable() throws Exception {
        Fixture f=fixture(1); assertThrows(ExamException.class,()->papers.edit(f.paper().id(),f.teacher().account().id(),new PaperService.Edit("Changed","",30,List.of(f.paper().questions().get(0).id()))));
        Question q=f.paper().questions().get(0); assertThrows(ExamException.class,()->sources.edit(q.id(),q));
    }
    @Test void editorRejectsWrongDurationAndRepeatedQuestions() throws Exception {
        Source s=source(); question(s,"math","MCQ",null); question(s,"math","MCQ",null); Matrix m=matrix(List.of(new Quota("math","Math",2,"MCQ",null,null,null))); Login teacher=teacher(); Paper p=papers.generate(teacher.account().id(),new PaperService.Generate(m.id(),"Draft",List.of(s.id()),1,1L,null,null)).get(0);
        assertThrows(ExamException.class,()->papers.edit(p.id(),teacher.account().id(),new PaperService.Edit("Bad","",31,p.questions().stream().map(Question::id).toList())));
        assertThrows(ExamException.class,()->papers.edit(p.id(),teacher.account().id(),new PaperService.Edit("Bad","",30,List.of(p.questions().get(0).id(),p.questions().get(0).id()))));
    }
    @Test void ownershipCoversPaperRosterSessionAndAnalytics() throws Exception {
        Fixture f=fixture(1); Login other=teacher(); String owner=other.account().id();
        assertThrows(ExamException.class,()->papers.owned(f.paper().id(),owner)); assertThrows(ExamException.class,()->results.roster(f.schoolClass().id(),owner)); assertThrows(ExamException.class,()->results.ownedSession(f.session().id(),owner)); assertThrows(ExamException.class,()->analytics.analyze(owner,f.schoolClass().id(),null,null));
        mvc.perform(get("/api/exams/papers/"+f.paper().id()).header("Authorization","Bearer "+other.token())).andExpect(status().isNotFound());
    }
    @Test void pdfAndDocxCarryImagesAndSeparateAnswerKey() throws Exception {
        Fixture f=fixture(1); byte[] pdf=exports.export(f.paper(),"pdf","paper");
        try(PDDocument doc=Loader.loadPDF(pdf)) { String text=new PDFTextStripper().getText(doc); assertTrue(text.contains("Đề kiểm tra năng lực")); assertTrue(text.contains(f.paper().id())); assertFalse(text.contains("Lời giải đã duyệt")); boolean image=false; for(PDPage page:doc.getPages()) for(var name:page.getResources().getXObjectNames()) if(page.getResources().isImageXObject(name)) image=true; assertTrue(image); }
        try(XWPFDocument doc=new XWPFDocument(new ByteArrayInputStream(exports.export(f.paper(),"docx","paper")))) { assertEquals(1,doc.getAllPictures().size()); }
        try(PDDocument doc=Loader.loadPDF(exports.export(f.paper(),"pdf","answers"))) { assertTrue(new PDFTextStripper().getText(doc).contains("Câu 1: B")); }
    }
    @Test void detailedScoringMapsPaperPositionsAndBlankAnswers() throws Exception {
        Fixture f=fixture(2); var r=results.record(f.teacher().account().id(),f.session().id(),new ResultService.ResultInput(f.student().id(),Map.of("1","B","2",""),null,null)); assertEquals("DETAILED",r.level()); assertEquals(1,r.correctCount()); assertEquals(1,r.score()); assertEquals(2,repo.jdbc().queryForObject("SELECT COUNT(*) FROM exam_platform.answer_records WHERE result_id=?",Integer.class,r.id()));
    }
    @Test void scoreOnlyCannotCreateSkillEvidenceOrRecommendations() throws Exception {
        Fixture f=fixture(1); results.record(f.teacher().account().id(),f.session().id(),new ResultService.ResultInput(f.student().id(),null,1.0,null)); var report=analytics.analyze(f.teacher().account().id(),null,f.student().id(),"VACT"); assertEquals(1,report.get("aggregateResultCount")); assertTrue(((List<?>)report.get("skills")).isEmpty()); assertTrue(((List<?>)report.get("recommendations")).isEmpty()); assertEquals(1,((List<?>)report.get("scores")).size());
    }
    @Test void limitedEvidenceDoesNotBecomeConfidentRecommendation() throws Exception {
        Fixture f=fixture(1); results.record(f.teacher().account().id(),f.session().id(),new ResultService.ResultInput(f.student().id(),Map.of("1","A"),null,null)); var report=analytics.analyze(f.teacher().account().id(),null,f.student().id(),null); var skill=(Map<?,?>)((List<?>)report.get("skills")).get(0); assertEquals("LIMITED",skill.get("evidenceLevel")); assertEquals(1,skill.get("questionsAttempted")); assertTrue(((List<?>)report.get("recommendations")).isEmpty());
    }
    @Test void resultValidationRejectsBadAnswerMissingColumnAndConflictingScore() throws Exception {
        Fixture f=fixture(2); String owner=f.teacher().account().id();
        assertThrows(ExamException.class,()->results.record(owner,f.session().id(),new ResultService.ResultInput(f.student().id(),Map.of("1","E","2","B"),null,null)));
        assertThrows(ExamException.class,()->results.record(owner,f.session().id(),new ResultService.ResultInput(f.student().id(),Map.of("1","B"),null,null)));
        assertThrows(ExamException.class,()->results.record(owner,f.session().id(),new ResultService.ResultInput(f.student().id(),null,2.0,1)));
        assertThrows(ExamException.class,()->results.record(owner,f.session().id(),new ResultService.ResultInput(f.student().id(),null,Double.NaN,null)));
    }
    MockMultipartFile csv(String text) { return new MockMultipartFile("file","results.csv","text/csv",text.getBytes(StandardCharsets.UTF_8)); }
    @Test void csvPreviewIsNonMutatingCommitExactlyOnceAndOwnerBound() throws Exception {
        Fixture f=fixture(1); String owner=f.teacher().account().id(); ImportJob job=results.preview(owner,f.session().id(),null,"RESULTS",csv("student_code,exam_id,question_1\nHS01,"+f.paper().id()+",B\n")); assertTrue(job.errors().isEmpty()); assertTrue(repo.owned("student_results",owner,Result.class).isEmpty());
        assertThrows(ExamException.class,()->results.commit(teacher().account().id(),job.id())); results.commit(owner,job.id()); assertEquals(1,repo.owned("student_results",owner,Result.class).size()); assertThrows(ExamException.class,()->results.commit(owner,job.id()));
    }
    @Test void invalidImportCannotPartiallyCommit() throws Exception {
        Fixture f=fixture(1); String owner=f.teacher().account().id(); ImportJob job=results.preview(owner,f.session().id(),null,"RESULTS",csv("student_code,exam_id,question_1\nHS01,"+f.paper().id()+",B\nUNKNOWN,"+f.paper().id()+",A\n")); assertEquals(1,job.errors().size()); assertThrows(ExamException.class,()->results.commit(owner,job.id())); assertTrue(repo.owned("student_results",owner,Result.class).isEmpty());
    }
    @Test void duplicateAndWrongVariantArePreviewErrors() throws Exception {
        Fixture f=fixture(1); ImportJob job=results.preview(f.teacher().account().id(),f.session().id(),null,"RESULTS",csv("student_code,exam_id,question_1\nHS01,wrong-id,B\nHS01,"+f.paper().id()+",B\n")); assertEquals(2,job.errors().size());
    }
    @Test void stalePreviewRevalidatesBeforeCommit() throws Exception {
        Fixture f=fixture(1); String owner=f.teacher().account().id(); ImportJob job=results.preview(owner,f.session().id(),null,"RESULTS",csv("student_code,exam_id,question_1\nHS01,"+f.paper().id()+",B\n")); results.record(owner,f.session().id(),new ResultService.ResultInput(f.student().id(),null,0.0,null)); assertThrows(ExamException.class,()->results.commit(owner,job.id())); assertEquals(1,repo.owned("student_results",owner,Result.class).size());
    }
    @Test void xlsxResultsAndRosterImportWork() throws Exception {
        Fixture f=fixture(1); byte[] bytes;
        try(XSSFWorkbook workbook=new XSSFWorkbook(); ByteArrayOutputStream out=new ByteArrayOutputStream()) { var sheet=workbook.createSheet(); var header=sheet.createRow(0); header.createCell(0).setCellValue("student_code"); header.createCell(1).setCellValue("exam_id"); header.createCell(2).setCellValue("question_1"); var row=sheet.createRow(1); row.createCell(0).setCellValue("HS01"); row.createCell(1).setCellValue(f.paper().id()); row.createCell(2).setCellValue("B"); workbook.write(out); bytes=out.toByteArray(); }
        String owner=f.teacher().account().id(); ImportJob job=results.preview(owner,f.session().id(),null,"RESULTS",new MockMultipartFile("file","results.xlsx","application/octet-stream",bytes)); assertTrue(job.errors().isEmpty()); results.commit(owner,job.id());
        ImportJob roster=results.preview(owner,null,f.schoolClass().id(),"ROSTER",csv("student_code,full_name,notes\nHS02,Nguyễn Bình,\n")); results.commit(owner,roster.id()); assertEquals(2,results.roster(f.schoolClass().id(),owner).size());
    }
    @Test void matrixRejectsOverlapAndUnverifiedScienceActivation() {
        assertThrows(ExamException.class,()->matrix(List.of(new Quota("math","All",1,null,null,null,null),new Quota("math","MCQ",1,"MCQ",null,null,null))));
        Matrix draft=repo.require("matrix_versions","hsa-2026-science-draft-v1",Matrix.class); Matrix active=new Matrix("invalid-science-version","HSA","2026",draft.name(),"ACTIVE",195,150,draft.quotas(),"RAW_PRACTICE",1,draft.provenance()); assertThrows(ExamException.class,()->matrices.create(active));
    }
    @Test void numericAnswersHaveDeterministicNormalization() { assertEquals("12.5",ResultService.normalizeAnswer(" 12,500 ")); assertEquals("a",ResultService.normalizeAnswer(" A ")); }
    @Test void practiceRevisionUsesOnlyExistingReviewedSkillQuestions() throws Exception {
        Fixture f=fixture(2); var revision=papers.revision(f.teacher().account().id(),new PaperService.Revision("VACT","2026","reasoning","Ôn lại kỹ năng",2,20)).get(0);
        assertEquals("PRACTICE",revision.matrix().purpose()); assertEquals(2,revision.questions().size()); assertTrue(revision.questions().stream().allMatch(q->q.skill().equals("reasoning"))); assertEquals("DRAFT",revision.status());
        assertThrows(ExamException.class,()->papers.revision(f.teacher().account().id(),new PaperService.Revision("VACT","2026","missing-skill","Missing",1,20)));
    }
    @Test void batchExportPreservesOwnershipAndProducesZip() throws Exception {
        Fixture f=fixture(1); String body=mapper.writeValueAsString(Map.of("paperIds",List.of(f.paper().id()),"format","pdf","kind","answers"));
        byte[] bytes=mvc.perform(post("/api/exams/papers/export").header("Authorization","Bearer "+f.teacher().token()).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk()).andReturn().getResponse().getContentAsByteArray(); assertEquals('P',bytes[0]); assertEquals('K',bytes[1]);
        Login other=teacher(); mvc.perform(post("/api/exams/papers/export").header("Authorization","Bearer "+other.token()).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isNotFound());
    }
    @Test void solutionImagesStayOutOfPaperAndAppearInSeparateSolutions() throws Exception {
        Source s=source(); Question draft=repo.all("questions",Question.class).stream().filter(q->q.sourceId().equals(s.id())).findFirst().orElseThrow(); Asset crop=sources.crop(s.id(),1,10,10,100,100); Asset solution=sources.crop(s.id(),1,100,100,100,100);
        Question q=sources.edit(draft.id(),new Question(draft.id(),s.id(),1,"VACT","2026","math","","algebra","reasoning","MEDIUM","APPLY","MCQ","Question with image solution",List.of(new Choice("A","One"),new Choice("B","Two"),new Choice("C","Three"),new Choice("D","Four")),"B",List.of(),"",List.of(crop.id()),null,"NEEDS_REVIEW",null,List.of(solution.id()))); sources.approve(q.id(),admin(),true,true);
        Login teacher=teacher(); Matrix m=matrix(List.of(new Quota("math","Math",1,"MCQ",null,null,null))); Paper paper=papers.publish(papers.generate(teacher.account().id(),new PaperService.Generate(m.id(),"Raster solution",List.of(s.id()),1,1L,null,null)).get(0).id(),teacher.account().id());
        try(XWPFDocument doc=new XWPFDocument(new ByteArrayInputStream(exports.export(paper,"docx","solutions")))) { assertEquals(1,doc.getAllPictures().size()); }
        try(XWPFDocument doc=new XWPFDocument(new ByteArrayInputStream(exports.export(paper,"docx","answers")))) { assertEquals(0,doc.getAllPictures().size()); }
    }
    @Test void duplicateQuestionFingerprintsCannotSatisfyQuota() throws Exception {
        Source s=source(); Question original=question(s,"math","MCQ",null); Question copy=sources.edit(null,original); sources.approve(copy.id(),admin(),true,true);
        Matrix m=matrix(List.of(new Quota("math","Two distinct",2,"MCQ",null,null,null))); Login teacher=teacher();
        ExamException error=assertThrows(ExamException.class,()->papers.generate(teacher.account().id(),new PaperService.Generate(m.id(),"Duplicate quota",List.of(s.id()),1,null,null,null))); assertEquals("INSUFFICIENT_BANK",error.code);
    }
    @Test void importExpiryAndStudentTransferPreservePastResults() throws Exception {
        Fixture f=fixture(1); String owner=f.teacher().account().id(); ImportJob job=results.preview(owner,f.session().id(),null,"RESULTS",csv("student_code,exam_id,question_1\nHS01,"+f.paper().id()+",B\n")); repo.update("import_jobs",job.id(),new ImportJob(job.id(),owner,job.sessionId(),null,job.kind(),job.rows(),job.errors(),0,false)); assertThrows(ExamException.class,()->results.commit(owner,job.id()));
        results.record(owner,f.session().id(),new ResultService.ResultInput(f.student().id(),null,1.0,null)); SchoolClass second=results.createClass(owner,"12A2"); results.transfer(f.schoolClass().id(),second.id(),f.student().id(),owner); assertTrue(results.roster(f.schoolClass().id(),owner).isEmpty()); assertEquals(1,results.roster(second.id(),owner).size()); assertEquals(1,analytics.analyze(owner,f.schoolClass().id(),null,null).get("resultCount"));
    }
    @Test void standaloneExamLinkRedirectsToExistingApp() throws Exception {
        mvc.perform(get("/exams/index.html")).andExpect(status().is3xxRedirection()).andExpect(redirectedUrl("/"));
    }
}
