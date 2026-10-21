package vn.teaching.preparation;

import com.google.gson.*;
import java.util.*;

/** Explicit allowlist for student PDF and live content; private fields never become body text. */
public final class PreparationStudentProjection {
    private PreparationStudentProjection() {}
    private static String text(JsonObject o,String key){return o.has(key)&&o.get(key).isJsonPrimitive()?o.get(key).getAsString():"";}
    private static JsonArray rows(JsonObject o,String key){return o.has(key)&&o.get(key).isJsonArray()?o.getAsJsonArray(key):new JsonArray();}
    public static boolean reviewed(JsonObject card){return card.has("publicReviewed")&&card.get("publicReviewed").isJsonPrimitive()
        &&card.getAsJsonPrimitive("publicReviewed").isBoolean()&&card.get("publicReviewed").getAsBoolean()
        &&!text(card,"publicText").isBlank()&&text(card,"publicText").equals(text(card,"publicReviewedText"));}
    public static JsonArray publicQuestionImages(JsonObject section){
        JsonArray result=new JsonArray();if(!section.has("questionBank")||!section.get("questionBank").isJsonObject())return result;
        for(JsonElement raw:rows(section.getAsJsonObject("questionBank"),"images")){if(!raw.isJsonObject())continue;JsonObject image=raw.getAsJsonObject();
            if(image.has("private")&&image.get("private").isJsonPrimitive()&&image.getAsJsonPrimitive("private").isBoolean()&&!image.get("private").getAsBoolean())result.add(image.deepCopy());}
        return result;
    }
    public static String body(JsonObject section){
        List<String> lines=new ArrayList<>();lines.add(text(section,"body"));
        if(!text(section,"objective").isBlank())lines.add("Mục tiêu: "+text(section,"objective"));
        for(JsonElement raw:rows(section,"activities")){JsonObject a=raw.getAsJsonObject();
            lines.add(text(a,"title"));lines.add(text(a,"studentAction"));}
        for(JsonElement raw:rows(section,"supportCards")){JsonObject card=raw.getAsJsonObject();if(reviewed(card))lines.add(text(card,"publicText"));}
        return String.join("\n\n",lines.stream().filter(s->!s.isBlank()).toList());
    }
    public static String teacherNotes(JsonObject section){
        List<String> lines=new ArrayList<>();lines.add(text(section,"teacherNotes"));
        for(JsonElement raw:rows(section,"activities")){JsonObject a=raw.getAsJsonObject();if(!text(a,"teacherAction").isBlank())lines.add(text(a,"title")+": "+text(a,"teacherAction"));}
        for(JsonElement raw:rows(section,"supportCards")){JsonObject c=raw.getAsJsonObject();if(!text(c,"teacherText").isBlank())lines.add(text(c,"kind")+": "+text(c,"teacherText"));}
        return String.join("\n\n",lines.stream().filter(s->!s.isBlank()).toList());
    }
}
