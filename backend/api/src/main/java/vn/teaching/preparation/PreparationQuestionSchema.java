package vn.teaching.preparation;
import com.google.gson.*;
import vn.teaching.exam.ExamException;
import java.util.*;
/** Snapshot references cannot turn private solution images into student media. */
final class PreparationQuestionSchema {
    private PreparationQuestionSchema(){}
    static void preserveSnapshots(JsonObject current,JsonObject incoming,boolean trusted){
        if(trusted)return;
        Map<String,JsonElement> snapshots=new HashMap<>();
        for(JsonElement raw:current.getAsJsonArray("sections")){JsonObject section=raw.getAsJsonObject();if(section.has("questionBank"))snapshots.put(PreparationStore.str(section,"id"),section.get("questionBank"));}
        for(JsonElement raw:incoming.getAsJsonArray("sections")){JsonObject section=raw.getAsJsonObject();JsonElement previous=snapshots.get(PreparationStore.str(section,"id"));
            if(previous==null){if(section.has("questionBank"))throw ExamException.bad("Nguồn câu hỏi chỉ được tạo từ kho đã duyệt.");}
            else if(!section.has("questionBank"))section.add("questionBank",previous.deepCopy());
            else if(!previous.equals(section.get("questionBank")))throw ExamException.bad("Không được thay đổi snapshot nguồn câu hỏi đã chèn.");
        }
    }
    static void validate(PreparationStore store,String plan,String owner,JsonObject doc){
        for(JsonElement raw:doc.getAsJsonArray("sections")){JsonObject section=raw.getAsJsonObject();if(!section.has("questionBank"))continue;
            JsonObject bank=PreparationSectionSchema.object(section.get("questionBank"));
            PreparationStore.checkId(PreparationStore.str(bank,"sourceId"));
            JsonArray ids=PreparationSectionSchema.array(bank,"questionIds",200),prints=PreparationSectionSchema.array(bank,"fingerprints",200);
            if(ids.isEmpty()||ids.size()!=prints.size())throw ExamException.bad("Snapshot câu hỏi không hợp lệ.");
            Set<String> unique=new HashSet<>();for(JsonElement id:ids){PreparationStore.checkId(id.getAsString());if(!unique.add(id.getAsString()))throw ExamException.bad("Câu hỏi snapshot bị trùng.");}
            for(JsonElement image:PreparationSectionSchema.array(bank,"images",400)){JsonObject ref=PreparationSectionSchema.object(image);PreparationSectionSchema.bool(ref,"private");
                if(!ref.has("private"))throw ExamException.bad("Ảnh câu hỏi cần phân loại riêng tư.");
                JsonObject asset=store.asset(PreparationStore.str(ref,"imageAssetId"),owner);
                if(!PreparationStore.str(asset,"planId").equals(plan))throw ExamException.bad("Ảnh không thuộc bài soạn này.");
                String kind=PreparationStore.str(asset,"kind");if(!Set.of("question_image","question_private").contains(kind)||kind.equals("question_private")&&!ref.get("private").getAsBoolean())throw ExamException.bad("Không thể công khai ảnh đáp án.");
            }
        }
    }
}
