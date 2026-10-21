package vn.teaching.preparation;

import com.google.gson.*;
import java.util.*;
import vn.teaching.exam.ExamException;

/** Unlock is an explicit save; stale jobs cannot overwrite reviewed scene content. */
final class PreparationSceneLocks {
    private PreparationSceneLocks() {}
    static final List<String> CONTENT=List.of("title","text","narration","language","template","imageAssetId");
    static boolean locked(JsonObject scene){return scene.has("locked")&&scene.get("locked").isJsonPrimitive()&&scene.getAsJsonPrimitive("locked").isBoolean()&&scene.get("locked").getAsBoolean();}
    static JsonArray scenes(JsonObject doc){return doc.has("scenes")&&doc.get("scenes").isJsonArray()?doc.getAsJsonArray("scenes"):new JsonArray();}
    static void validate(JsonObject current,JsonObject incoming){
        Map<String,JsonObject> next=new HashMap<>();
        for(JsonElement e:scenes(incoming)){JsonObject scene=e.getAsJsonObject();
            if(scene.has("locked")&&(!scene.get("locked").isJsonPrimitive()||!scene.getAsJsonPrimitive("locked").isBoolean()))throw ExamException.bad("Trạng thái khóa cảnh không hợp lệ.");
            next.put(PreparationStore.str(scene,"id"),scene);
        }
        for(JsonElement e:scenes(current)){JsonObject old=e.getAsJsonObject();if(!locked(old))continue;JsonObject target=next.get(PreparationStore.str(old,"id"));
            if(target==null)throw ExamException.conflict("Mở khóa và lưu cảnh trước khi xóa.");
            for(String key:CONTENT)if(!Objects.equals(old.get(key),target.get(key)))throw ExamException.conflict("Mở khóa và lưu cảnh trước khi sửa nội dung đã duyệt.");
        }
    }
    static void requireEditableJob(JsonObject doc,JsonObject input,String kind){
        if(!Set.of("translate","author").contains(kind)||!input.has("sceneId"))return;
        for(JsonElement e:scenes(doc)){JsonObject scene=e.getAsJsonObject();if(PreparationStore.str(scene,"id").equals(PreparationStore.str(input,"sceneId"))&&locked(scene))throw ExamException.conflict("Mở khóa cảnh trước khi sinh lại hoặc dịch.");}
    }
}
