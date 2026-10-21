package vn.teaching.service;

import com.google.gson.*;
import vn.teaching.exam.ExamException;
import java.util.*;

/** Private cue validation shared by both document and board scoped writes. */
public final class TeacherCueSchema {
    private TeacherCueSchema() {}
    public static void validate(JsonObject document) {
        if (!document.has("teacherCues")) return;
        JsonElement raw=document.get("teacherCues");
        if (!raw.isJsonArray() || raw.getAsJsonArray().size()>1000) throw ExamException.bad("Invalid teacher cues.");
        Set<String> ids=new HashSet<>();
        for (JsonElement entry:raw.getAsJsonArray()) {
            if (!entry.isJsonObject()) throw ExamException.bad("Invalid teacher cue.");
            JsonObject cue=entry.getAsJsonObject();String id=text(cue,"id");
            if (!id.matches("[A-Za-z0-9_-]{1,100}") || !ids.add(id) || text(cue,"text").length()>20000)
                throw ExamException.bad("Invalid teacher cue ID or content.");
            if (!cue.has("locator") || !cue.get("locator").isJsonObject()) throw ExamException.bad("Missing cue locator.");
            JsonObject locator=cue.getAsJsonObject("locator");
            switch(text(locator,"kind")) {
                case "board" -> { if(text(locator,"pageId").isBlank()) throw ExamException.bad("Missing board page ID."); }
                case "pdf" -> {
                    if(text(locator,"documentId").isBlank() || text(locator,"contentFingerprint").isBlank()
                            || !locator.has("pageIndex") || !locator.get("pageIndex").isJsonPrimitive()
                            || !locator.getAsJsonPrimitive("pageIndex").isNumber() || locator.get("pageIndex").getAsInt()<1)
                        throw ExamException.bad("Missing PDF page identity.");
                }
                default -> throw ExamException.bad("Invalid cue locator kind.");
            }
        }
    }
    private static String text(JsonObject object,String field) {
        return object.has(field) && object.get(field).isJsonPrimitive() ? object.get(field).getAsString() : "";
    }
}
