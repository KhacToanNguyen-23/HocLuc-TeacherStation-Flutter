package vn.teaching.preparation;

import com.google.gson.*;
import vn.teaching.exam.ExamException;
import java.util.*;
import static vn.teaching.preparation.PreparationStore.*;

/** Authoring references are teacher metadata, never part of a student projection. */
final class PreparationEvidence {
    static void validate(PreparationStore store,String plan,String owner,JsonObject doc) {
        for(String list:List.of("sections","scenes"))for(JsonElement raw:doc.getAsJsonArray(list)) {
            JsonObject item=raw.getAsJsonObject();
            if(item.has("aiAdded")&&(!item.get("aiAdded").isJsonPrimitive()||!item.getAsJsonPrimitive("aiAdded").isBoolean()))throw ExamException.bad("Nhãn AI không hợp lệ.");
            if(!item.has("sourceRefs"))continue;
            if(!item.get("sourceRefs").isJsonArray()||item.getAsJsonArray("sourceRefs").size()>30)throw ExamException.bad("Tối đa 30 tham chiếu mỗi phần/cảnh.");
            for(JsonElement value:item.getAsJsonArray("sourceRefs")) {
                if(!value.isJsonObject())throw ExamException.bad("Tham chiếu nguồn không hợp lệ.");
                JsonObject ref=value.getAsJsonObject();
                if(!Set.of("sourceAssetId","sourceRevision","start","end").containsAll(ref.keySet()))throw ExamException.bad("Trường tham chiếu không hợp lệ.");
                JsonObject asset=store.asset(str(ref,"sourceAssetId"),owner);
                if(!str(asset,"planId").equals(plan)||!str(asset,"kind").equals("source"))throw ExamException.bad("Tham chiếu phải thuộc nguồn của bài.");
                if(!ref.has("sourceRevision")||number(ref,"sourceRevision")!=integer(asset,"revision",0))throw ExamException.bad("Phiên bản nguồn không khớp.");
                boolean timed=str(asset,"mimeType").startsWith("video/")||str(asset,"mimeType").startsWith("audio/");
                if(timed||ref.has("start")||ref.has("end")) {
                    double start=number(ref,"start"),end=number(ref,"end");
                    if(!timed||start<0||end<=start||end>7200)throw ExamException.bad("Đoạn tham chiếu phải nằm trong 0–7200 giây.");
                    if(!asset.has("durationSeconds")||end>number(asset,"durationSeconds"))throw ExamException.bad("Cần kiểm thời lượng nguồn và chọn đoạn nằm trong video/audio.");
                }
            }
        }
    }
    static double number(JsonObject object,String key) {
        try {JsonElement value=object.get(key);if(value==null||!value.isJsonPrimitive()||!value.getAsJsonPrimitive().isNumber())throw new IllegalArgumentException();double number=value.getAsDouble();if(!Double.isFinite(number))throw new IllegalArgumentException();return number;}
        catch(RuntimeException error){throw ExamException.bad("Mốc/phiên bản nguồn phải là số hợp lệ.");}
    }
    static void markAuthorDraft(JsonObject output) {
        // A language model cannot prove a citation. Teacher attaches/reviews references in the editor.
        for(String key:List.of("sections","scenes"))if(output.has(key)&&output.get(key).isJsonArray())for(JsonElement raw:output.getAsJsonArray(key))if(raw.isJsonObject()) {
            JsonObject item=raw.getAsJsonObject();item.addProperty("aiAdded",!str(output,"method").equals("manual-script"));item.add("sourceRefs",new JsonArray());
        }
    }
}
