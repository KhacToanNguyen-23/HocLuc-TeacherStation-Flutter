package vn.teaching.service;

import com.google.gson.*;
import vn.teaching.preparation.PreparationStudentProjection;

/** Projects approved lesson content onto legacy board pages without mutating the plan. */
public final class PreparationLiveProjection {
    private PreparationLiveProjection() {}
    private static String text(JsonObject value,String key) {
        return value.has(key)&&value.get(key).isJsonPrimitive()?value.get(key).getAsString():"";
    }
    public static JsonObject project(JsonObject original) {
        JsonObject lesson=original.deepCopy();
        // A derived snapshot with no newer preparation is already the intended output.
        if (!lesson.has("preparation") || !lesson.get("preparation").isJsonObject()) return lesson;
        if (lesson.has("preparationProjection") && lesson.get("preparationProjection").isJsonObject()) {
            JsonObject marker = lesson.getAsJsonObject("preparationProjection");
            if (marker.has("source")) {
                JsonElement document = lesson.get("preparation");
                lesson = marker.getAsJsonObject("source").deepCopy();
                if (document != null) lesson.add("preparation", document.deepCopy());
            }
        }
        if(!lesson.has("preparation")||!lesson.get("preparation").isJsonObject())return lesson;
        JsonObject doc=lesson.getAsJsonObject("preparation"); lesson.remove("preparation");
        JsonObject source = lesson.deepCopy(); source.remove("preparationProjection");
        JsonObject teacher = new JsonObject();
        for(String key:new String[]{"revision","teacherCues"})if(doc.has(key))teacher.add(key,doc.get(key).deepCopy());
        JsonArray teacherSections=new JsonArray();
        if(doc.has("sections"))for(JsonElement value:doc.getAsJsonArray("sections")) {
            JsonObject section=new JsonObject(),full=value.getAsJsonObject();
            for(String key:new String[]{"id","title","presentationTarget","presentationTargets"})if(full.has(key))section.add(key,full.get(key).deepCopy());
            section.addProperty("teacherNotes",PreparationStudentProjection.teacherNotes(full));teacherSections.add(section);
        }
        teacher.add("sections",teacherSections);lesson.add("teacherPreparation",teacher);

        JsonArray sections=doc.has("sections")?doc.getAsJsonArray("sections"):new JsonArray();
        String bodyKey="body";
        if(sections.isEmpty()){sections=doc.has("scenes")?doc.getAsJsonArray("scenes"):new JsonArray();bodyKey="text";}
        if(sections.isEmpty())return lesson;
        JsonArray pages=lesson.has("pages")?lesson.getAsJsonArray("pages"):new JsonArray();
        JsonArray titles=lesson.has("pageTitles")?lesson.getAsJsonArray("pageTitles"):new JsonArray();
        JsonArray notes=lesson.has("pageNotes")?lesson.getAsJsonArray("pageNotes"):new JsonArray();
        JsonObject stickers=lesson.has("stickers")?lesson.getAsJsonObject("stickers"):new JsonObject();
        boolean blank=pages.size()==1&&pages.get(0).isJsonArray()&&pages.get(0).getAsJsonArray().isEmpty()
            &&stickers.size()==0&&(!lesson.has("pdfFilePath")||lesson.get("pdfFilePath").isJsonNull()||text(lesson,"pdfFilePath").isBlank())
            &&(!lesson.has("importedPdfDocuments")||lesson.getAsJsonArray("importedPdfDocuments").isEmpty())
            &&text(lesson,"notes").isBlank()&&(notes.isEmpty()||notes.get(0).getAsString().isBlank());
        if(blank){pages=new JsonArray();titles=new JsonArray();notes=new JsonArray();}
        while(titles.size()<pages.size())titles.add("Trang "+(titles.size()+1));
        while(notes.size()<pages.size())notes.add("");
        java.util.Map<Integer,JsonObject> generatedTargets = new java.util.LinkedHashMap<>();
        java.util.Set<String> usedPageIds = new java.util.HashSet<>();
        if(source.has("pageIds"))for(JsonElement id:source.getAsJsonArray("pageIds"))usedPageIds.add(id.getAsString());
        int sectionPosition = -1;
        for(JsonElement raw:sections){
            sectionPosition++;
            JsonObject section=raw.getAsJsonObject();String body=bodyKey.equals("body")?PreparationStudentProjection.body(section):text(section,bodyKey),title=text(section,"title");
            boolean bound = section.has("presentationTarget") && section.get("presentationTarget").isJsonObject()
                || section.has("presentationTargets") && section.get("presentationTargets").isJsonArray() && !section.getAsJsonArray("presentationTargets").isEmpty();
            if (bound || body.isBlank()&&title.isBlank())continue;
            int firstGeneratedPage=pages.size();
            // Long text is split across pages; never silently truncated or converted to notes.
            int offset=0,part=0;
            do {
                int end=Math.min(body.length(),offset+700);
                if(end<body.length()){int space=body.lastIndexOf(' ',end);if(space>offset+350)end=space;}
                String chunk=body.substring(offset,end).trim();int index=pages.size();pages.add(new JsonArray());
                titles.add(title+(part==0?"":" ("+(part+1)+")"));notes.add(PreparationStudentProjection.teacherNotes(section));
                JsonObject card=new JsonObject();card.addProperty("id","prepared-"+index);
                card.addProperty("type","lesson_section");card.addProperty("rawText",title+"\n\n"+chunk);
                JsonArray rect=new JsonArray();for(double n:new double[]{.05,.06,.9,.78})rect.add(n);card.add("rect",rect);
                card.add("tokens",new JsonArray());card.add("issues",new JsonArray());JsonArray cards=new JsonArray();cards.add(card);stickers.add(String.valueOf(index),cards);
                offset=end;part++;
            } while(offset<body.length());
            for(JsonElement image:PreparationStudentProjection.publicQuestionImages(section)) {
                JsonObject ref=image.getAsJsonObject();int index=pages.size();pages.add(new JsonArray());
                titles.add(title+" — hình câu hỏi");notes.add(PreparationStudentProjection.teacherNotes(section));
                JsonObject card=new JsonObject();card.addProperty("id","prepared-image-"+index);card.addProperty("type","lesson_image");
                card.addProperty("rawText",title);card.add("imageAssetId",ref.get("imageAssetId"));
                JsonArray rect=new JsonArray();for(double n:new double[]{.05,.06,.9,.84})rect.add(n);card.add("rect",rect);
                card.add("tokens",new JsonArray());card.add("issues",new JsonArray());JsonArray cards=new JsonArray();cards.add(card);stickers.add(String.valueOf(index),cards);
            }
            if (bodyKey.equals("body") && sectionPosition<teacherSections.size()) {
                JsonObject teacherSection=teacherSections.get(sectionPosition).getAsJsonObject();
                JsonArray targets=new JsonArray();
                String sectionId=text(section,"id");if(sectionId.isBlank())sectionId="section-"+sectionPosition;
                for(int index=firstGeneratedPage;index<pages.size();index++) {
                    String base="projection-"+sectionId+"-"+(index-firstGeneratedPage),id=base;
                    int suffix=1;while(!usedPageIds.add(id))id=base+"-"+suffix++;
                    JsonObject target=new JsonObject();target.addProperty("kind","board");target.addProperty("pageId",id);
                    generatedTargets.put(index,target);targets.add(target.deepCopy());
                }
                if(!targets.isEmpty()) {
                    teacherSection.add("presentationTarget",targets.get(0).deepCopy());
                    teacherSection.add("presentationTargets",targets);
                }
            }
        }
        if (pages.isEmpty() && blank) {
            pages=source.getAsJsonArray("pages").deepCopy();
            titles=source.has("pageTitles")?source.getAsJsonArray("pageTitles").deepCopy():new JsonArray();
            notes=source.has("pageNotes")?source.getAsJsonArray("pageNotes").deepCopy():new JsonArray();blank=false;
        }
        lesson.add("pages",pages);lesson.add("pageTitles",titles);lesson.add("pageNotes",notes);lesson.add("stickers",stickers);
        JsonArray pageIds = new JsonArray();
        for (int i=0; i<pages.size(); i++) {
            if (source.has("pageIds") && i<source.getAsJsonArray("pageIds").size() && !blank)
                pageIds.add(source.getAsJsonArray("pageIds").get(i));
            else if(generatedTargets.containsKey(i))pageIds.add(generatedTargets.get(i).get("pageId"));
            else pageIds.add("projection-"+i);
        }
        lesson.add("pageIds",pageIds);
        JsonObject origin = new JsonObject(); origin.addProperty("kind","preparation");
        origin.addProperty("sourceRevision",doc.has("revision")?doc.get("revision").getAsInt():0);
        origin.add("source",source); lesson.add("preparationProjection",origin);
        lesson.addProperty("page",0);lesson.addProperty("view","board");
        return lesson;
    }
}
