package vn.teaching.preparation;

import com.google.gson.*;
import java.util.*;
import vn.teaching.exam.ExamException;

/** Declarative export fields: no expressions, arbitrary JSON paths or private student mappings. */
final class PreparationExportTemplate {
    static final Set<String> SOURCES=Set.of("title","subject","className","section.title","section.body","section.objective","section.minutes","teacherNotes","custom");
    static JsonObject settings(JsonObject doc){if(!doc.has("exportTemplate"))return new JsonObject();if(!doc.get("exportTemplate").isJsonObject())throw ExamException.bad("Mẫu xuất phải là object.");return doc.getAsJsonObject("exportTemplate");}
    static JsonArray fields(JsonObject config){if(!config.has("fields"))return new JsonArray();if(!config.get("fields").isJsonArray())throw ExamException.bad("Danh sách trường mẫu xuất không hợp lệ.");return config.getAsJsonArray("fields");}
    static boolean mapped(JsonObject doc,String source){for(JsonElement e:fields(settings(doc)))if(e.isJsonObject()&&text(e.getAsJsonObject(),"source").equals(source))return true;return false;}
    static String text(JsonObject o,String key){return o.has(key)&&o.get(key).isJsonPrimitive()?o.get(key).getAsString():"";}
    static List<String> blocks(JsonObject doc,boolean teacher){
        JsonObject config=settings(doc);List<String> result=new ArrayList<>();
        for(String key:List.of("school","faculty","name")){if(config.has(key)&&(!config.get(key).isJsonPrimitive()||!config.getAsJsonPrimitive(key).isString()))throw ExamException.bad("Tiêu đề mẫu xuất phải là chuỗi.");String s=text(config,key);if(s.length()>300)throw ExamException.bad("Tiêu đề mẫu xuất tối đa 300 ký tự.");if(!s.isBlank())result.add(s);}
        JsonArray fields=fields(config);
        if(fields.size()>40)throw ExamException.bad("Mẫu xuất tối đa 40 trường.");
        for(JsonElement raw:fields){if(!raw.isJsonObject())throw ExamException.bad("Trường mẫu xuất không hợp lệ.");JsonObject f=raw.getAsJsonObject();String source=text(f,"source"),label=text(f,"label");
            if(f.has("teacherOnly")&&(!f.get("teacherOnly").isJsonPrimitive()||!f.getAsJsonPrimitive("teacherOnly").isBoolean()))throw ExamException.bad("Phạm vi trường mẫu xuất phải là boolean.");
            for(String key:List.of("label","source","value"))if(f.has(key)&&(!f.get(key).isJsonPrimitive()||!f.getAsJsonPrimitive(key).isString()))throw ExamException.bad("Giá trị ánh xạ phải là chuỗi.");
            if(text(f,"label").length()>200||text(f,"value").length()>20000)throw ExamException.bad("Nhãn tối đa 200 ký tự; giá trị tự nhập tối đa 20.000 ký tự.");
            if(!SOURCES.contains(source))throw ExamException.bad("Nguồn ánh xạ mẫu xuất không hợp lệ.");
            if(!teacher&&(source.equals("teacherNotes")||(f.has("teacherOnly")&&f.get("teacherOnly").getAsBoolean())))continue;
            List<String> values=new ArrayList<>();
            if(source.equals("custom"))values.add(text(f,"value"));
            else if(source.equals("teacherNotes")||source.startsWith("section.")){
                if(doc.has("sections"))for(JsonElement e:doc.getAsJsonArray("sections")){JsonObject section=e.getAsJsonObject();String value=source.equals("teacherNotes")?PreparationStudentProjection.teacherNotes(section):source.equals("section.body")?PreparationStudentProjection.body(section):text(section,source.substring(8));if(!value.isBlank())values.add(text(section,"title")+": "+value);}
            }else if(source.equals("className")){JsonObject variant=doc.has("variant")&&doc.get("variant").isJsonObject()?doc.getAsJsonObject("variant"):new JsonObject();JsonObject target=variant.has("targetClass")&&variant.get("targetClass").isJsonObject()?variant.getAsJsonObject("targetClass"):new JsonObject();values.add(text(target,"name"));}
            else values.add(text(doc,source));
            String value=String.join("\n",values);if(label.length()>200||value.length()>200000)throw ExamException.bad("Nội dung mẫu xuất quá dài.");
            result.add(label+(label.isBlank()?"":": ")+value);
        }
        return result;
    }
}
