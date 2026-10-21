package vn.teaching.preparation;

import org.springframework.stereotype.Component;
import com.google.gson.*;
import java.net.*;
import java.net.http.*;
import java.nio.file.*;
import java.time.Duration;
import java.util.Map;

/** Injectable boundary for Drive resumable transfer; no public sharing permission is created. */
@Component
public class PreparationDrive {
    final HttpClient client;
    @org.springframework.beans.factory.annotation.Autowired
    public PreparationDrive(){this(HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(20)).followRedirects(HttpClient.Redirect.NEVER).build());}
    PreparationDrive(HttpClient client){this.client=client;}
    final Gson gson=new Gson();
    public String upload(String token,Path file,String name,String mime,String key)throws Exception {
        PreparationStore.checkId(key);Path journal=file.resolveSibling("drive-upload-"+key+".json");long length=Files.size(file);
        JsonObject saved=Files.exists(journal)?JsonParser.parseString(Files.readString(journal)).getAsJsonObject():new JsonObject();
        if(saved.has("fileId"))return saved.get("fileId").getAsString();
        URI session=null;long offset=0;
        if(saved.has("session")){
            session=checkedSession(saved.get("session").getAsString());
            var status=client.send(HttpRequest.newBuilder(session).timeout(Duration.ofSeconds(45)).header("Authorization","Bearer "+token).header("Content-Range","bytes */"+length).PUT(HttpRequest.BodyPublishers.noBody()).build(),HttpResponse.BodyHandlers.ofString());
            if(status.statusCode()/100==2)return completed(journal,saved,status.body());
            if(status.statusCode()==308){String range=status.headers().firstValue("Range").orElse("");if(!range.isBlank())offset=Long.parseLong(range.substring(range.lastIndexOf('-')+1))+1;}
            else if(status.statusCode()==404||status.statusCode()==410){session=null;saved=new JsonObject();}
            else throw new IllegalStateException("Chưa xác định được trạng thái upload. Thử lại sau.");
        }
        if(session==null){
        var metadata=Map.of("name",name,"appProperties",Map.of("hoclucPreparationKey",key));
        var start=client.send(HttpRequest.newBuilder(URI.create("https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&fields=id"))
            .timeout(Duration.ofSeconds(60)).header("Authorization","Bearer "+token).header("Content-Type","application/json; charset=UTF-8")
            .header("X-Upload-Content-Type",mime).header("X-Upload-Content-Length",Long.toString(Files.size(file)))
            .POST(HttpRequest.BodyPublishers.ofString(gson.toJson(metadata))).build(),HttpResponse.BodyHandlers.ofString());
        if(start.statusCode()/100!=2)throw new IllegalStateException("Drive từ chối khởi tạo upload ("+start.statusCode()+"). Cấp quyền xuất bản lại nếu cần.");
        session=checkedSession(start.headers().firstValue("Location").orElseThrow());saved.addProperty("session",session.toString());persist(journal,saved);
        }
        if(offset>=length)throw new IllegalStateException("Upload chưa xác nhận hoàn tất. Thử đối soát lại.");
        final long skip=offset;
        HttpRequest.BodyPublisher data=HttpRequest.BodyPublishers.fromPublisher(HttpRequest.BodyPublishers.ofInputStream(()->{
            try {var stream=Files.newInputStream(file);stream.skipNBytes(skip);return stream;}catch(java.io.IOException e){throw new java.io.UncheckedIOException(e);}
        }),length-offset);
        var result=client.send(HttpRequest.newBuilder(session).timeout(Duration.ofMinutes(15)).header("Authorization","Bearer "+token).header("Content-Type",mime)
            .header("Content-Range","bytes "+offset+"-"+(length-1)+"/"+length).PUT(data).build(),HttpResponse.BodyHandlers.ofString());
        if(result.statusCode()/100!=2)throw new IllegalStateException("Drive upload chưa hoàn tất ("+result.statusCode()+").");
        return completed(journal,saved,result.body());
    }
    URI checkedSession(String url){URI uri=URI.create(url);if(!"https".equals(uri.getScheme())||!"www.googleapis.com".equals(uri.getHost())||uri.getUserInfo()!=null)throw new IllegalStateException("Upload URL không hợp lệ.");return uri;}
    String completed(Path journal,JsonObject state,String body)throws Exception{String id=JsonParser.parseString(body).getAsJsonObject().get("id").getAsString();state.addProperty("fileId",id);state.remove("session");persist(journal,state);return id;}
    void persist(Path path,JsonObject state)throws Exception{Path temp=Files.createTempFile(path.getParent(),"drive-",".tmp");Files.writeString(temp,gson.toJson(state));try{Files.move(temp,path,StandardCopyOption.ATOMIC_MOVE,StandardCopyOption.REPLACE_EXISTING);}catch(AtomicMoveNotSupportedException e){Files.move(temp,path,StandardCopyOption.REPLACE_EXISTING);}}
}
