package vn.teaching.preparation;

import com.google.gson.*;
import org.apache.pdfbox.pdmodel.*;
import org.apache.pdfbox.pdmodel.font.*;
import java.nio.file.*;
import java.util.*;

/** Audience is selected by the job, never by document content. */
final class PreparationPdf {
    static JsonObject generate(JsonObject document,Path workspace)throws Exception{return generate(document,workspace,"student");}
    static JsonObject generate(JsonObject document,Path workspace,String audience)throws Exception {
        if(!Set.of("student","teacher").contains(audience))throw vn.teaching.exam.ExamException.bad("Bản PDF không hợp lệ.");
        return generate(document,workspace,audience,null);
    }
    static JsonObject generate(JsonObject document,Path workspace,String audience,java.util.function.Function<String,Path> resolve)throws Exception {
        if(!Set.of("student","teacher").contains(audience))throw vn.teaching.exam.ExamException.bad("Bản PDF không hợp lệ.");
        boolean teacher=audience.equals("teacher");
        try(PDDocument pdf=new PDDocument()){
            Path fontPath=Path.of(System.getenv().getOrDefault("WINDIR","C:/Windows"),"Fonts","arial.ttf");
            if(!Files.isRegularFile(fontPath))fontPath=Path.of("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf");
            PDFont font=PDType0Font.load(pdf,fontPath.toFile());
            List<String> lines=new ArrayList<>(PreparationExportTemplate.blocks(document,teacher));
            boolean custom=!PreparationExportTemplate.fields(PreparationExportTemplate.settings(document)).isEmpty();
            if(!custom||!PreparationExportTemplate.mapped(document,"title"))lines.add(PreparationStore.str(document,"title"));
            if(!custom)for(String group:List.of("sections","scenes"))if(document.has(group))for(JsonElement e:document.getAsJsonArray(group)){
                JsonObject part=e.getAsJsonObject();lines.add(PreparationStore.str(part,"title"));lines.add(group.equals("sections")?PreparationStudentProjection.body(part):PreparationStore.str(part,"text"));
            }
            if(teacher&&!PreparationExportTemplate.mapped(document,"teacherNotes")&&document.has("sections"))for(JsonElement e:document.getAsJsonArray("sections")){
                JsonObject part=e.getAsJsonObject();String notes=PreparationStudentProjection.teacherNotes(part);if(!notes.isBlank())lines.add("Hướng dẫn / đáp án riêng — "+PreparationStore.str(part,"title")+":\n"+notes);
            }
            if(teacher && document.has("teacherCues")) for(JsonElement entry:document.getAsJsonArray("teacherCues")) {
                JsonObject cue=entry.getAsJsonObject();String value=PreparationStore.str(cue,"text");
                if(value.isBlank())continue;
                JsonObject locator=cue.getAsJsonObject("locator");
                String label=PreparationStore.str(locator,"kind").equals("pdf")
                    ? "PDF "+PreparationStore.str(locator,"documentId")+" / trang "+PreparationStore.str(locator,"pageIndex")
                    : "Trang bảng "+PreparationStore.str(locator,"pageId");
                lines.add("Ghi chú riêng — "+label+"\n"+value);
            }
            try(Layout layout=new Layout(pdf,font,teacher)){for(String block:lines)layout.block(block);
                if(document.has("sections"))for(JsonElement e:document.getAsJsonArray("sections")){JsonObject section=e.getAsJsonObject();if(!section.has("questionBank"))continue;JsonObject bank=section.getAsJsonObject("questionBank");if(!bank.has("images"))continue;boolean heading=false;
                    for(JsonElement image:bank.getAsJsonArray("images")){JsonObject ref=image.getAsJsonObject();boolean secret=!ref.has("private")||!ref.get("private").isJsonPrimitive()||!ref.getAsJsonPrimitive("private").isBoolean()||ref.get("private").getAsBoolean();if(secret&&!teacher)continue;if(resolve==null)throw new IllegalStateException("Không thể xuất ảnh câu hỏi: chưa có bộ giải asset.");if(!heading){layout.block("Hình câu hỏi: "+PreparationStore.str(section,"title"));heading=true;}Path path=resolve.apply(PreparationStore.str(ref,"imageAssetId"));layout.image(path,secret);}
                }
            }
            Path output=workspace.resolve(audience+"-lesson.pdf");pdf.save(output.toFile());
            JsonObject artifact=new JsonObject();artifact.addProperty("path",output.toString());artifact.addProperty("name",audience+"-lesson.pdf");artifact.addProperty("kind","pdf");artifact.addProperty("mimeType","application/pdf");
            artifact.addProperty("audience",audience);artifact.addProperty("private",teacher);
            JsonArray artifacts=new JsonArray();artifacts.add(artifact);JsonObject result=new JsonObject();result.addProperty("audience",audience);result.add("artifacts",artifacts);return result;
        }
    }
    static final class Layout implements AutoCloseable {
        final PDDocument pdf;final PDFont font;final boolean teacher;PDPageContentStream stream;float y;
        Layout(PDDocument pdf,PDFont font,boolean teacher){this.pdf=pdf;this.font=font;this.teacher=teacher;}
        void page()throws Exception{if(stream!=null)stream.close();PDPage page=new PDPage();pdf.addPage(page);stream=new PDPageContentStream(pdf,page);y=740;if(teacher){draw("BẢN GIÁO VIÊN — CÓ NỘI DUNG RIÊNG",9);y-=10;}}
        void draw(String value,float size)throws Exception{stream.beginText();stream.setFont(font,size);stream.newLineAtOffset(45,y);stream.showText(value);stream.endText();y-=17;}
        void line(String text)throws Exception{if(stream==null||y<55)page();draw(text,11);}
        void block(String value)throws Exception {
            for(String paragraph:value.replaceAll("[\\p{Cntrl}&&[^\\n\\r]]"," ").split("\\R",-1)){
                StringBuilder line=new StringBuilder();
                for(String word:paragraph.split("\\s+")){
                    if(!line.isEmpty()&&width(line+word)>515){line(line.toString().stripTrailing());line.setLength(0);}
                    // Measure glyph widths; split even an unbroken URL so it cannot leave the page.
                    for(int offset=0;offset<word.length();){int cp=word.codePointAt(offset);String glyph=new String(Character.toChars(cp));offset+=Character.charCount(cp);
                        if(width(line+glyph)>515&&!line.isEmpty()){line(line.toString());line.setLength(0);}line.append(glyph);}
                    if(width(line+" ")>515){line(line.toString());line.setLength(0);}else line.append(' ');
                }
                line(line.toString().stripTrailing());
            }
            y-=6;
        }
        void image(Path path,boolean secret)throws Exception{var image=org.apache.pdfbox.pdmodel.graphics.image.PDImageXObject.createFromFileByContent(path.toFile(),pdf);float scale=Math.min(515f/image.getWidth(),480f/image.getHeight()),height=image.getHeight()*scale;if(stream==null||y-height<55)page();if(secret)block("Hình hướng dẫn / lời giải riêng");if(y-height<55)page();stream.drawImage(image,45,y-height,image.getWidth()*scale,height);y-=height+16;}
        float width(String text)throws Exception{return font.getStringWidth(text)*11/1000;}
        public void close()throws Exception{if(stream!=null)stream.close();}
    }
}
