package vn.teaching.preparation;

import com.google.gson.*;
import org.junit.jupiter.api.Test;
import vn.teaching.exam.ExamException;
import static org.junit.jupiter.api.Assertions.*;

class PreparationCaptionPresentationTest {
    JsonObject document() {
        return JsonParser.parseString("""
            {"sections":[],"scenes":[{"id":"scene-1","narration":"Water rises.",
             "captionsReviewed":true,"captionsNarration":"Water rises.",
             "captionMode":"bilingual","captionsVisible":false,
             "captions":[{"id":"cue-1","start":0,"end":2,"text":"Water rises.","secondaryText":"Nước bốc lên."}]}]}
            """).getAsJsonObject();
    }
    @Test void bilingualPresentationPersistsAsValidDocument() {
        assertDoesNotThrow(()->PreparationSectionSchema.validate(document()));
    }
    @Test void approvedBilingualNeedsEverySecondaryText() {
        JsonObject doc=document();
        doc.getAsJsonArray("scenes").get(0).getAsJsonObject().getAsJsonArray("captions").get(0).getAsJsonObject().remove("secondaryText");
        assertThrows(ExamException.class,()->PreparationSectionSchema.validate(doc));
    }
    @Test void rejectsUnknownModeAndNonBooleanVisibility() {
        JsonObject doc=document(),scene=doc.getAsJsonArray("scenes").get(0).getAsJsonObject();
        scene.addProperty("captionMode","unsupported");
        assertThrows(ExamException.class,()->PreparationSectionSchema.validate(doc));
        scene.addProperty("captionMode","english");scene.addProperty("captionsVisible","false");
        assertThrows(ExamException.class,()->PreparationSectionSchema.validate(doc));
    }
}
