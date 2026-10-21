package vn.teaching.preparation;

import com.google.gson.*;
import vn.teaching.exam.ExamException;
import java.util.*;

/** Optional teacher-authored structure; drafts may omit goals, but fields stay bounded. */
final class PreparationSectionSchema {
    private PreparationSectionSchema() {}
    static void validate(JsonObject doc) {
        minutes(doc,"targetMinutes",1440);
        for(JsonElement raw:doc.getAsJsonArray("sections")) {
            JsonObject section=object(raw);minutes(section,"minutes",600);
            text(section,"objective",4000);
            for(JsonElement item:array(section,"activities",100)) {
                JsonObject activity=object(item);PreparationStore.checkId(PreparationStore.str(activity,"id"));
                text(activity,"title",200);text(activity,"teacherAction",4000);text(activity,"studentAction",4000);
                minutes(activity,"minutes",600);
                if(activity.has("objectiveId"))PreparationStore.checkId(PreparationStore.str(activity,"objectiveId"));
            }
            uniqueIds(array(section,"activities",100));
            for(JsonElement item:array(section,"supportCards",100)) {
                JsonObject card=object(item);PreparationStore.checkId(PreparationStore.str(card,"id"));
                if(!Set.of("example","misconception","hint").contains(PreparationStore.str(card,"kind")))bad("Loại thẻ hỗ trợ không hợp lệ.");
                text(card,"teacherText",8000);text(card,"publicText",4000);text(card,"publicReviewedText",4000);bool(card,"publicReviewed");
                if(yes(card,"publicReviewed") && (PreparationStore.str(card,"publicText").isBlank()
                    ||!PreparationStore.str(card,"publicText").equals(PreparationStore.str(card,"publicReviewedText"))))
                    bad("Nội dung thẻ học sinh đã đổi; cần duyệt lại chính nội dung đó.");
            }
            uniqueIds(array(section,"supportCards",100));
        }
        for(JsonElement raw:doc.getAsJsonArray("scenes")) {
            JsonObject scene=object(raw);bool(scene,"captionsReviewed");text(scene,"captionsNarration",20000);
            bool(scene,"captionsVisible");text(scene,"captionMode",20);
            if(scene.has("captionMode")&&!Set.of("english","bilingual").contains(PreparationStore.str(scene,"captionMode")))bad("Chế độ phụ đề không hợp lệ.");
            double lastEnd=0;
            JsonArray cues=array(scene,"captions",200);uniqueIds(cues);
            for(JsonElement cueRaw:cues){JsonObject cue=object(cueRaw);PreparationStore.checkId(PreparationStore.str(cue,"id"));
                text(cue,"secondaryText",1000);
                if(yes(scene,"captionsReviewed")&&"bilingual".equals(PreparationStore.str(scene,"captionMode"))&&PreparationStore.str(cue,"secondaryText").isBlank())bad("Cần bản dịch thứ hai cho từng cue song ngữ.");
                text(cue,"text",1000);if(PreparationStore.str(cue,"text").isBlank())bad("Phụ đề không được để trống.");
                double start=number(cue,"start"),end=number(cue,"end");
                if(start<0||end<=start||end>900||start<lastEnd)bad("Mốc phụ đề phải tăng dần, không chồng lấn, trong 0–900 giây.");
                lastEnd=end;
            }
            if(yes(scene,"captionsReviewed")&&(cues.isEmpty()||!PreparationStore.str(scene,"narration").equals(PreparationStore.str(scene,"captionsNarration"))))
                bad("Script đã thay đổi; cần duyệt lại phụ đề.");
        }
    }
    static JsonObject object(JsonElement e){if(e==null||!e.isJsonObject())bad("Mục phải là một đối tượng.");return e.getAsJsonObject();}
    static JsonArray array(JsonObject o,String key,int max){if(!o.has(key))return new JsonArray();if(!o.get(key).isJsonArray())bad("Danh sách "+key+" không hợp lệ.");JsonArray a=o.getAsJsonArray(key);if(a.size()>max)bad("Quá nhiều mục "+key+".");return a;}
    static void uniqueIds(JsonArray a){Set<String> seen=new HashSet<>();for(JsonElement e:a){String id=PreparationStore.str(object(e),"id");if(!seen.add(id))bad("ID bị trùng trong danh sách.");}}
    static void text(JsonObject o,String key,int max){if(!o.has(key))return;JsonElement e=o.get(key);if(!e.isJsonPrimitive()||!e.getAsJsonPrimitive().isString()||e.getAsString().length()>max)bad("Nội dung "+key+" không hợp lệ hoặc quá dài.");}
    static void bool(JsonObject o,String key){if(o.has(key)&&(!o.get(key).isJsonPrimitive()||!o.getAsJsonPrimitive(key).isBoolean()))bad("Cờ "+key+" không hợp lệ.");}
    static boolean yes(JsonObject o,String key){return o.has(key)&&o.get(key).isJsonPrimitive()&&o.getAsJsonPrimitive(key).isBoolean()&&o.get(key).getAsBoolean();}
    static void minutes(JsonObject o,String key,int max){if(!o.has(key))return;double n=number(o,key);if(n<0||n>max||n!=Math.rint(n))bad("Thời lượng "+key+" không hợp lệ.");}
    static double number(JsonObject o,String key){if(!o.has(key)||!o.get(key).isJsonPrimitive()||!o.getAsJsonPrimitive(key).isNumber())bad("Mốc/thời lượng "+key+" phải là số.");double n=o.get(key).getAsDouble();if(!Double.isFinite(n))bad("Mốc/thời lượng phải hữu hạn.");return n;}
    static void bad(String message){throw ExamException.bad(message);}
}
