package vn.teaching.service;
import com.google.gson.*;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.*;

class PreparationLiveProjectionTest {
    @Test void directDoubleProjectionRetainsGeneratedPagesAndTeacherContext() {
        JsonObject original=JsonParser.parseString("""
            {"pages":[[{"stroke":"base"}]],"pageIds":["base"],"preparation":{"revision":2,"sections":[
             {"id":"a","title":"A","body":"Alpha","teacherNotes":"noteA"},
             {"id":"b","title":"B","body":"Beta","teacherNotes":"noteB"}]}}
            """).getAsJsonObject();
        JsonObject once=PreparationLiveProjection.project(original),twice=PreparationLiveProjection.project(once);
        assertThat(twice).isEqualTo(once);
        assertThat(twice.getAsJsonArray("pages")).hasSize(3);
        assertThat(twice.getAsJsonObject("teacherPreparation").getAsJsonArray("sections")).hasSize(2);
        JsonArray teacherSections=twice.getAsJsonObject("teacherPreparation").getAsJsonArray("sections");
        for(int index=0;index<2;index++) {
            JsonObject target=teacherSections.get(index).getAsJsonObject().getAsJsonObject("presentationTarget");
            assertThat(target.get("pageId")).isEqualTo(twice.getAsJsonArray("pageIds").get(index+1));
        }
    }
    @Test void longSectionTargetsEveryGeneratedPageAndExplicitTargetsAreKeptWithoutDuplication() {
        JsonObject original=JsonParser.parseString("""
            {"pages":[[{"stroke":"base"}]],"pageIds":["base"],"preparation":{"sections":[
             {"id":"bound","title":"Bound","body":"Do not duplicate","presentationTarget":{"kind":"board","pageId":"base"},
              "presentationTargets":[{"kind":"board","pageId":"base"}]},
             {"id":"long","title":"Long","body":"LONG"}]}}
            """).getAsJsonObject();
        original.getAsJsonObject("preparation").getAsJsonArray("sections").get(1).getAsJsonObject().addProperty("body","word ".repeat(400));
        JsonObject live=PreparationLiveProjection.project(original);
        JsonArray sections=live.getAsJsonObject("teacherPreparation").getAsJsonArray("sections");
        assertThat(sections.get(0).getAsJsonObject().getAsJsonArray("presentationTargets").get(0).getAsJsonObject().get("pageId").getAsString()).isEqualTo("base");
        assertThat(live.getAsJsonObject("stickers").toString()).doesNotContain("Do not duplicate");
        JsonArray targets=sections.get(1).getAsJsonObject().getAsJsonArray("presentationTargets");
        assertThat(targets.size()).isEqualTo(live.getAsJsonArray("pages").size()-1);
        for(int i=0;i<targets.size();i++)assertThat(targets.get(i).getAsJsonObject().get("pageId")).isEqualTo(live.getAsJsonArray("pageIds").get(i+1));
    }
    @Test void liveTeacherContextRetainsCueLocatorsWithoutJobsOrSourceEnvelope() {
        JsonObject source=JsonParser.parseString("""
            {"pages":[[]],"preparation":{"revision":4,"sources":[{"secret":"SOURCE"}],"jobs":[{}],
              "teacherCues":[{"id":"cue","text":"PRIVATE_CUE","locator":{"kind":"pdf","documentId":"doc","contentFingerprint":"sha","pageIndex":3}}],
              "sections":[{"id":"part","title":"Intro","body":"Public","teacherNotes":"PRIVATE_SECTION","presentationTarget":{"kind":"board","pageId":"board1"}}]}}
            """).getAsJsonObject();
        var projected=PreparationLiveProjection.project(source);
        var teacher=projected.getAsJsonObject("teacherPreparation");
        assertThat(teacher.has("sources")).isFalse();assertThat(teacher.has("jobs")).isFalse();
        assertThat(teacher.getAsJsonArray("teacherCues")).isEqualTo(source.getAsJsonObject("preparation").getAsJsonArray("teacherCues"));
        assertThat(teacher.getAsJsonArray("sections").get(0).getAsJsonObject().get("presentationTarget")).isNotNull();
        assertThat(projected.getAsJsonObject("stickers").toString()).doesNotContain("PRIVATE_CUE","PRIVATE_SECTION");
    }
    @Test void projectingSavedDerivedSnapshotAgainDoesNotAccumulatePages() {
        JsonObject source=JsonParser.parseString("{\"pages\":[[]],\"preparation\":{\"revision\":3,\"sections\":[{\"id\":\"one\",\"title\":\"Part\",\"body\":\"Content\"}]}}").getAsJsonObject();
        JsonObject first=PreparationLiveProjection.project(source);
        first.add("preparation",source.get("preparation").deepCopy());
        JsonObject second=PreparationLiveProjection.project(first);
        assertThat(second.getAsJsonArray("pages")).hasSize(1);
        assertThat(second.getAsJsonObject("preparationProjection").get("sourceRevision").getAsInt()).isEqualTo(3);
        assertThat(second.getAsJsonObject("stickers").size()).isEqualTo(1);
    }
    @Test void questionImagesAppearOnSeparateBoardPagesButPrivateSolutionIdsNeverEnterPublicCards() {
        JsonObject plan=JsonParser.parseString("""
          {"pages":[[]],"stickers":{},"preparation":{"sections":[{"title":"Group","body":"Shared passage and questions",
          "teacherNotes":"PRIVATE ANSWERS","questionBank":{"images":[
          {"imageAssetId":"public-image","private":false},
          {"imageAssetId":"solution-image","private":true},
          {"imageAssetId":"unclassified-image"}]}}]}}
          """).getAsJsonObject();
        JsonObject live=PreparationLiveProjection.project(plan);
        assertThat(live.getAsJsonArray("pages").size()).isEqualTo(2);
        String cards=live.getAsJsonObject("stickers").toString();
        assertThat(cards).contains("lesson_image","public-image").doesNotContain("solution-image","unclassified-image","PRIVATE ANSWERS");
        assertThat(live.getAsJsonArray("pageNotes").toString()).contains("PRIVATE ANSWERS");
    }
    @Test void authoredSectionsAppearOnBoardWithoutPuttingNotesIntoPublicCards() {
        JsonObject plan=JsonParser.parseString("""
            {"pages":[[]],"pageTitles":["Blank"],"pageNotes":[""],"stickers":{},
            "preparation":{"sections":[{"title":"Water cycle","body":"Water evaporates.","teacherNotes":"PRIVATE SENTINEL"}],"scenes":[]}}
            """).getAsJsonObject();
        var live=PreparationLiveProjection.project(plan);
        assertThat(live.has("preparation")).isFalse();
        assertThat(live.getAsJsonArray("pages").size()).isEqualTo(1);
        assertThat(live.getAsJsonObject("stickers").toString()).contains("Water evaporates").doesNotContain("PRIVATE SENTINEL");
        assertThat(live.getAsJsonArray("pageNotes").get(0).getAsString()).isEqualTo("PRIVATE SENTINEL");
        assertThat(plan.has("preparation")).isTrue();
        assertThat(plan.getAsJsonObject("stickers").size()).isZero();
    }
    @Test void preservesExistingBoardAndSplitsLongLessonsWithoutTruncation() {
        JsonObject plan=JsonParser.parseString("""
            {"pages":[[{"stroke":"kept"}]],"pageTitles":["Original"],"pageNotes":["Old"],"stickers":{},
             "preparation":{"sections":[],"scenes":[{"title":"Scene","text":"PLACEHOLDER"}]}}
            """).getAsJsonObject();
        plan.getAsJsonObject("preparation").getAsJsonArray("scenes").get(0).getAsJsonObject().addProperty("text","word ".repeat(300));
        var live=PreparationLiveProjection.project(plan);
        assertThat(live.getAsJsonArray("pages").get(0)).isEqualTo(plan.getAsJsonArray("pages").get(0));
        assertThat(live.getAsJsonArray("pages").size()).isGreaterThan(2);
        assertThat(live.getAsJsonArray("pageNotes").get(0).getAsString()).isEqualTo("Old");
    }
}
