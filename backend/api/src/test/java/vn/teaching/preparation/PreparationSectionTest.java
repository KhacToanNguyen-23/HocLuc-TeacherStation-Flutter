package vn.teaching.preparation;

import com.google.gson.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import vn.teaching.service.*;
import vn.teaching.exam.ExamException;
import java.nio.file.*;
import static org.junit.jupiter.api.Assertions.*;

class PreparationSectionTest {
    @TempDir Path dir;
    PreparationStore store;PlanningService planning;String plan;
    @BeforeEach void setup()throws Exception {
        planning=new PlanningService(dir,new Gson());plan=planning.saveOrUpdatePlanning(null,"Lesson","General",null).getId();
        store=new PreparationStore(dir,new Gson(),planning);
    }
    JsonObject section(){return JsonParser.parseString("""
      {"id":"section-1","title":"Observe","body":"Visible lesson","objective":"Explain the idea","minutes":10,
       "teacherNotes":"PRIVATE_NOTE",
       "activities":[{"id":"activity-1","title":"Discuss","teacherAction":"PRIVATE_ACTION","studentAction":"PUBLIC_TASK","minutes":5,"objectiveId":"section-1"}],
       "supportCards":[{"id":"hint-1","kind":"hint","teacherText":"PRIVATE_ANSWER","publicText":"PUBLIC_HINT","publicReviewed":true,"publicReviewedText":"PUBLIC_HINT"},
         {"id":"example-1","kind":"example","teacherText":"PRIVATE_EXAMPLE","publicText":"UNREVIEWED_TEXT","publicReviewed":false}]}
      """).getAsJsonObject();}
    JsonObject document(){JsonObject d=store.document(plan,"teacher");d.getAsJsonArray("sections").add(section());return d;}
    @Test void activitiesAndTeacherCardsPersistAcrossRestart()throws Exception {
        store.update(plan,"teacher",0,document());
        JsonObject loaded=new PreparationStore(dir,new Gson(),planning).document(plan,"teacher");
        JsonObject section=loaded.getAsJsonArray("sections").get(0).getAsJsonObject();
        assertEquals("PRIVATE_ACTION",section.getAsJsonArray("activities").get(0).getAsJsonObject().get("teacherAction").getAsString());
        assertEquals("PRIVATE_ANSWER",section.getAsJsonArray("supportCards").get(0).getAsJsonObject().get("teacherText").getAsString());
        assertEquals("section-1",section.getAsJsonArray("activities").get(0).getAsJsonObject().get("objectiveId").getAsString());
    }
    @Test void pdfAndLiveBodyContainOnlyStudentActionsAndExplicitlyReviewedHints()throws Exception {
        JsonObject doc=document();
        JsonObject result=PreparationPdf.generate(doc,dir);
        Path path=Path.of(result.getAsJsonArray("artifacts").get(0).getAsJsonObject().get("path").getAsString());
        try(var pdf=org.apache.pdfbox.Loader.loadPDF(path.toFile())) {
            String text=new org.apache.pdfbox.text.PDFTextStripper().getText(pdf);
            assertTrue(text.contains("PUBLIC_TASK"));assertTrue(text.contains("PUBLIC_HINT"));
            assertFalse(text.contains("PRIVATE_"));assertFalse(text.contains("UNREVIEWED_TEXT"));
        }
        JsonObject lesson=new JsonObject();lesson.add("preparation",doc);
        JsonObject projected=PreparationLiveProjection.project(lesson);
        String publicBoard=projected.get("stickers").toString();
        assertTrue(publicBoard.contains("PUBLIC_TASK"));assertTrue(publicBoard.contains("PUBLIC_HINT"));
        assertFalse(publicBoard.contains("PRIVATE_"));assertFalse(publicBoard.contains("UNREVIEWED_TEXT"));
        assertTrue(projected.get("pageNotes").toString().contains("PRIVATE_ACTION"));
        assertTrue(projected.get("pageNotes").toString().contains("PRIVATE_ANSWER"));
        assertTrue(lesson.has("preparation"));
    }
    @Test void editingPublicTextRequiresMatchingExplicitReview() {
        JsonObject doc=document(),card=doc.getAsJsonArray("sections").get(0).getAsJsonObject().getAsJsonArray("supportCards").get(0).getAsJsonObject();
        card.addProperty("publicText","CHANGED_NOT_REVIEWED");
        assertThrows(ExamException.class,()->store.update(plan,"teacher",0,doc));
        assertFalse(PreparationStudentProjection.body(doc.getAsJsonArray("sections").get(0).getAsJsonObject()).contains("CHANGED_NOT_REVIEWED"));
        assertEquals(0,store.document(plan,"teacher").get("revision").getAsInt());
    }
    @Test void invalidActivityTimingAndDuplicateIdsAreRejectedWithoutWriting() {
        JsonObject doc=document(),s=doc.getAsJsonArray("sections").get(0).getAsJsonObject(),a=s.getAsJsonArray("activities").get(0).getAsJsonObject();
        a.addProperty("minutes",-1);assertThrows(ExamException.class,()->store.update(plan,"teacher",0,doc));
        a.addProperty("minutes",5);s.getAsJsonArray("activities").add(a.deepCopy());
        assertThrows(ExamException.class,()->store.update(plan,"teacher",0,doc));
    }
    @Test void captionsRejectOverlapAndReviewOfChangedNarration() {
        JsonObject doc=document(),scene=JsonParser.parseString("""
          {"id":"scene-1","narration":"New script","captionsReviewed":true,"captionsNarration":"Old script",
           "captions":[{"id":"cue-1","start":0,"end":2,"text":"Hello"}]}
          """).getAsJsonObject();
        doc.getAsJsonArray("scenes").add(scene);assertThrows(ExamException.class,()->store.update(plan,"teacher",0,doc));
        scene.addProperty("captionsReviewed",false);
        scene.getAsJsonArray("captions").add(JsonParser.parseString("{\"id\":\"cue-2\",\"start\":1,\"end\":3,\"text\":\"Overlap\"}"));
        assertThrows(ExamException.class,()->store.update(plan,"teacher",0,doc));
    }
}
