package vn.teaching.preparation;

import com.google.gson.*;
import org.springframework.stereotype.Service;
import vn.teaching.exam.*;
import vn.teaching.integrations.*;
import java.util.*;
import static vn.teaching.preparation.PreparationStore.*;

@Service
public class PreparationPublishing {
    final PreparationStore store;final ExamRepository repo;final GoogleConnectionService connections;final GoogleGateway google;final PreparationDrive drive;
    public PreparationPublishing(PreparationStore store,ExamRepository repo,GoogleConnectionService connections,GoogleGateway google,PreparationDrive drive){this.store=store;this.repo=repo;this.connections=connections;this.google=google;this.drive=drive;}
    void identity(ExamModels.Account account,String email){
        if(email==null)throw ExamException.bad("Chọn tài khoản Google.");
        boolean same=account.email().equalsIgnoreCase(email);
        if(!same)same=!repo.jdbc().queryForList("SELECT subject FROM exam_platform.external_identities WHERE account_id=? AND provider='APP_WEBVIEW' AND subject=?",account.id(),email.toLowerCase(Locale.ROOT)).isEmpty();
        if(!same)throw ExamException.missing();
    }
    public Object connect(ExamModels.Account account,String email){identity(account,email);return connections.startPublishing(email);}
    public Object courses(ExamModels.Account account,String email){identity(account,email);List<Object> all=new ArrayList<>();Set<String> pages=new HashSet<>();String page="",token=connections.access(email);
        do{if(!pages.add(page)||pages.size()>100)throw new IllegalStateException("Google trả danh sách lớp quá lớn hoặc không hợp lệ.");
            var result=google.call("GET","https://classroom.googleapis.com/v1/courses?teacherId=me&courseStates=ACTIVE&pageSize=100"+(page.isBlank()?"":"&pageToken="+encode(page)),token,null);
            all.addAll((List<?>)result.getOrDefault("courses",List.of()));Object next=result.get("nextPageToken");page=next==null?"":next.toString();
        }while(!page.isBlank());return Map.of("courses",all);}
    synchronized JsonObject publish(String plan,ExamModels.Account account,String email,JsonObject input){
        identity(account,email);String owner=account.id();JsonObject doc=store.document(plan,owner);int revision=integer(input,"revision",-1);
        String requestId=str(input,"requestId"),course=str(input,"courseId"),title=str(input,"title");checkId(requestId);checkId(course);
        if(title.isBlank()||title.length()>300)throw ExamException.bad("Tiêu đề cần 1–300 ký tự.");
        JsonArray ids=input.getAsJsonArray("artifactIds");if(ids==null||ids.isEmpty()||ids.size()>20)throw ExamException.bad("Chọn 1–20 tài liệu học sinh.");
        JsonObject state=store.state(plan,owner),publication=null;
        for(JsonElement e:state.getAsJsonArray("publications"))if(str(e.getAsJsonObject(),"requestId").equals(requestId))publication=e.getAsJsonObject();
        if(publication==null)for(JsonElement e:state.getAsJsonArray("publications")){
            JsonObject prior=e.getAsJsonObject();
            if(Set.of("uploading","creating","uncertain").contains(str(prior,"status"))&&str(prior,"courseId").equals(course)
                    &&sameFiles(prior.getAsJsonArray("artifactIds"),ids)&&intentTitle(str(prior,"title")).equals(intentTitle(title)))
                throw new ExamException(org.springframework.http.HttpStatus.CONFLICT,"PUBLICATION_RECONCILIATION_REQUIRED",
                    "Lần đăng trước chưa được xác nhận. Tiếp tục đối soát bằng request ID gốc: "+str(prior,"requestId"),
                    Map.of("requestId",str(prior,"requestId"),"courseId",course,"revision",integer(prior,"revision",0)));
        }
        if(publication!=null){if(!str(publication,"courseId").equals(course)||integer(publication,"revision",-2)!=revision||!publication.get("artifactIds").equals(ids))throw ExamException.conflict("Request ID đã dùng cho nội dung khác.");
            if(str(publication,"status").equals("published"))return publication;
            if(str(publication,"status").equals("creating")||str(publication,"status").equals("uncertain"))return reconcile(plan,owner,email,publication);
        }
        if(integer(doc,"revision",0)!=revision)throw ExamException.conflict("Bài đã đổi. Chọn lại bản xuất.");
        List<JsonObject> assets=new ArrayList<>();for(JsonElement id:ids){JsonObject a=store.asset(id.getAsString(),owner);
            if(str(a,"kind").equals("question_private")||str(a,"audience").equals("teacher")||(a.has("private")&&a.get("private").getAsBoolean()))throw ExamException.bad("Không thể đăng tài liệu riêng giáo viên lên Classroom.");
            boolean source=str(a,"kind").equals("source");
            if(!str(a,"planId").equals(plan)||(!source&&integer(a,"revision",-2)!=revision))throw ExamException.bad("Tài liệu không thuộc bản xuất hiện tại.");
            if(source&&(!input.has("externalFilesConfirmed")||!input.get("externalFilesConfirmed").getAsBoolean()))throw ExamException.bad("Xác nhận đã kiểm tra file tải lên không chứa ghi chú/đáp án riêng.");
            if(!Set.of("application/pdf","video/mp4","audio/wav","audio/mpeg","image/png","image/jpeg","application/x-subrip","text/vtt").contains(str(a,"mimeType")))throw ExamException.bad("Chỉ đăng PDF, video, audio, hình và phụ đề học sinh; không đăng project/transcript JSON.");assets.add(a);}
        if(publication==null){publication=new JsonObject();publication.addProperty("requestId",requestId);publication.addProperty("courseId",course);publication.addProperty("revision",revision);publication.add("artifactIds",ids.deepCopy());publication.add("driveFiles",new JsonArray());publication.addProperty("title",title);publication.addProperty("description",str(input,"description"));publication.addProperty("status","uploading");synchronized(store){state=store.state(plan,owner);state.getAsJsonArray("publications").add(publication);store.saveState(plan,state);}}
        String token=connections.access(email);JsonObject journal=publication;List<Map<String,Object>> materials=new ArrayList<>();
        try{
            for(int i=0;i<assets.size();i++){JsonObject a=assets.get(i);JsonArray files=journal.getAsJsonArray("driveFiles");String fileId;
                if(i<files.size())fileId=files.get(i).getAsString();else{
                    // Recover an upload whose response was lost using appProperties before creating another file.
                    String key=driveKey(plan,owner,requestId,i);var lookup=google.call("GET","https://www.googleapis.com/drive/v3/files?q="+encode("trashed=false and appProperties has { key='hoclucPreparationKey' and value='"+key+"' }")+"&fields=files(id)",token,null);
                    var found=(List<?>)lookup.getOrDefault("files",List.of());fileId=found.isEmpty()?drive.upload(token,store.assetPath(a),str(a,"name"),str(a,"mimeType"),key):String.valueOf(((Map<?,?>)found.get(0)).get("id"));
                    files.add(fileId);saveJournal(plan,owner,journal);
                }
                materials.add(Map.of("driveFile",Map.of("driveFile",Map.of("id",fileId),"shareMode","VIEW")));
            }
            String marker="[HocLuc:"+requestId+"]";journal.addProperty("marker",marker);journal.addProperty("status","creating");saveJournal(plan,owner,journal);
            var response=google.call("POST","https://classroom.googleapis.com/v1/courses/"+encode(course)+"/courseWorkMaterials",token,Map.of("title",title,"description",str(journal,"description")+"\n"+marker,"state","PUBLISHED","materials",materials));
            String materialId=remoteId(response);journal.addProperty("status","published");journal.addProperty("materialId",materialId);journal.addProperty("url",String.valueOf(response.getOrDefault("alternateLink","")));saveJournal(plan,owner,journal);return journal;
        }catch(Exception e){journal.addProperty("status",str(journal,"status").equals("creating")?"uncertain":"failed");journal.addProperty("error",e instanceof GoogleFailure?"Google chưa hoàn tất đăng. Cấp quyền xuất bản hoặc kiểm tra kết nối.":e.getMessage());saveJournal(plan,owner,journal);return journal;}
    }
    JsonObject reconcile(String plan,String owner,String email,JsonObject journal){
        try {String page="";do {var response=google.call("GET","https://classroom.googleapis.com/v1/courses/"+encode(str(journal,"courseId"))+"/courseWorkMaterials?pageSize=100"+(page.isBlank()?"":"&pageToken="+encode(page)),connections.access(email),null);
            for(Object raw:(List<?>)response.getOrDefault("courseWorkMaterial",List.of())){Map<?,?> item=(Map<?,?>)raw;if(String.valueOf(item.get("description")).contains(str(journal,"marker"))){String materialId=remoteId(item);journal.addProperty("status","published");journal.addProperty("materialId",materialId);journal.addProperty("url",String.valueOf(item.get("alternateLink")));saveJournal(plan,owner,journal);return journal;}}
            page=String.valueOf(response.getOrDefault("nextPageToken",""));}while(!page.isBlank());
            journal.addProperty("status","uncertain");journal.addProperty("error","Chưa tìm thấy bài. Không tự đăng lại để tránh trùng; kiểm tra Classroom rồi thử đối soát lại.");
        }catch(Exception e){journal.addProperty("status","uncertain");journal.addProperty("error","Không đối soát được Classroom. Thử lại khi kết nối phục hồi.");}saveJournal(plan,owner,journal);return journal;
    }
    void saveJournal(String plan,String owner,JsonObject journal){synchronized(store){JsonObject state=store.state(plan,owner);JsonArray list=state.getAsJsonArray("publications");for(int i=0;i<list.size();i++)if(str(list.get(i).getAsJsonObject(),"requestId").equals(str(journal,"requestId"))){list.set(i,journal.deepCopy());break;}store.saveState(plan,state);}}
    static String encode(String value){return java.net.URLEncoder.encode(value,java.nio.charset.StandardCharsets.UTF_8);}
    static String driveKey(String plan,String owner,String request,int index){return ExamAuth.digest((owner+"\n"+plan+"\n"+request).getBytes(java.nio.charset.StandardCharsets.UTF_8))+"-"+index;}
    static String remoteId(Map<?,?> response){Object id=response.get("id");if(id==null||id.toString().isBlank()||id.toString().equals("null"))throw new IllegalStateException("Google chưa xác nhận material ID; cần đối soát.");return id.toString();}
    static String intentTitle(String title){return title.trim().replaceAll("\\s+"," ").toLowerCase(Locale.ROOT);}
    static boolean sameFiles(JsonArray left,JsonArray right){if(left==null||right==null)return false;Set<String> a=new TreeSet<>(),b=new TreeSet<>();for(JsonElement id:left)a.add(id.getAsString());for(JsonElement id:right)b.add(id.getAsString());return a.equals(b);}
}
