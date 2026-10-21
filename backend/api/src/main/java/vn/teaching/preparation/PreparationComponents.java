package vn.teaching.preparation;

import com.google.gson.*;
import jakarta.annotation.PreDestroy;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.apache.commons.compress.archivers.zip.*;
import vn.teaching.exam.ExamException;
import java.io.*;
import java.nio.file.*;
import java.security.*;
import java.util.*;
import java.util.concurrent.*;
import static vn.teaching.preparation.PreparationStore.*;

/** Explicit offline package installation. Hashes establish integrity, not publisher trust. */
@Service
public class PreparationComponents {
    static final long MAX_ZIP=8L*1024*1024*1024,MAX_EXPANDED=16L*1024*1024*1024;
    static final String MANIFEST="bundle-manifest.json";
    final PreparationStore store;final Path root;
    final ExecutorService executor=Executors.newSingleThreadExecutor(r->{Thread t=new Thread(r,"preparation-installer");t.setDaemon(true);return t;});
    final Set<String> cancelled=ConcurrentHashMap.newKeySet();
    public PreparationComponents(PreparationStore store)throws IOException{
        this.store=store;this.root=store.root.resolve("components");Files.createDirectories(root.resolve("jobs"));Files.createDirectories(root.resolve("staging"));Files.createDirectories(root.resolve("installed"));
        try(var files=Files.list(root.resolve("jobs"))){for(Path path:files.filter(p->p.toString().endsWith(".json")).toList()){
            JsonObject state=store.read(path);if(Set.of("queued","running").contains(str(state,"status"))){String id=path.getFileName().toString().replaceFirst("\\.json$","");checkId(id);JsonObject installed=store.read(root.resolve("installed").resolve(id).resolve("installation.json"));JsonObject configuration=store.read(store.root.resolve("configuration.json"));boolean active=installed.has("components");
                if(active)for(String key:installed.getAsJsonObject("components").keySet())if(!str(configuration,key).equals(root.resolve("installed").resolve(id).resolve(str(installed.getAsJsonObject("components"),key)).toAbsolutePath().toString()))active=false;
                state.addProperty("status",active?"installed":"failed");if(active){state.addProperty("progress",1);state.add("installation",installed);}else state.addProperty("error","Cài đặt bị gián đoạn. Kiểm tra Cài đặt rồi nhập lại bundle.");store.write(path,state);Files.deleteIfExists(root.resolve("jobs").resolve(id+".zip"));deleteTree(root.resolve("staging").resolve(id));}
        }}
    }
    Path jobPath(String id){checkId(id);return root.resolve("jobs").resolve(id+".json");}
    public JsonObject get(String id,String owner){JsonObject job=store.read(jobPath(id));if(!str(job,"owner").equals(owner))throw ExamException.missing();JsonObject result=job.deepCopy();result.remove("owner");return result;}
    public JsonArray list(String owner){JsonArray result=new JsonArray();try(var files=Files.list(root.resolve("jobs"))){for(Path path:files.filter(p->p.toString().endsWith(".json")).sorted(Comparator.reverseOrder()).toList()){JsonObject state=store.read(path);if(str(state,"owner").equals(owner)){state.remove("owner");result.add(state);}}}catch(IOException e){throw new IllegalStateException(e);}return result;}
    void change(String id,java.util.function.Consumer<JsonObject> change){synchronized(store){JsonObject job=store.read(jobPath(id));change.accept(job);store.write(jobPath(id),job);}}
    public synchronized JsonObject start(String owner,MultipartFile upload)throws Exception{
        if(upload.isEmpty()||upload.getSize()>MAX_ZIP)throw ExamException.bad("Bundle ZIP cần từ 1 byte đến 8 GB.");
        if(Files.getFileStore(root).getUsableSpace()<upload.getSize()+512L*1024*1024)throw ExamException.bad("Không đủ dung lượng để lưu bundle và vùng an toàn 512 MB.");
        String id=id();Path zip=root.resolve("jobs").resolve(id+".zip");
        try(InputStream in=upload.getInputStream();OutputStream out=Files.newOutputStream(zip,StandardOpenOption.CREATE_NEW)){copy(in,out,upload.getSize(),null,null);}
        catch(Exception e){Files.deleteIfExists(zip);throw e;}
        JsonObject job=new JsonObject();job.addProperty("id",id);job.addProperty("owner",owner);job.addProperty("status","queued");job.addProperty("progress",0);job.addProperty("createdAt",java.time.Instant.now().toString());store.write(jobPath(id),job);
        executor.submit(()->install(id,zip));return get(id,owner);
    }
    public synchronized JsonObject cancel(String id,String owner){JsonObject job=get(id,owner);if(Set.of("queued","running").contains(str(job,"status"))){cancelled.add(id);change(id,j->j.addProperty("status","cancelled"));}return get(id,owner);}
    void checkCancelled(String id){if(cancelled.contains(id)||Thread.currentThread().isInterrupted())throw new CancellationException("Cài đặt đã hủy.");}
    public JsonArray installed(){JsonArray list=new JsonArray();try(var dirs=Files.list(root.resolve("installed"))){for(Path dir:dirs.filter(Files::isDirectory).toList()){Path manifest=dir.resolve("installation.json");if(Files.isRegularFile(manifest))list.add(store.read(manifest));}}catch(IOException e){throw new IllegalStateException(e);}return list;}
    void install(String id,Path zip){Path staging=root.resolve("staging").resolve(id),activated=root.resolve("installed").resolve(id);boolean committed=false;
        try{
            checkCancelled(id);change(id,j->{j.addProperty("status","running");j.addProperty("stage","verifying-manifest");});Files.createDirectories(staging);
            JsonObject manifest;String manifestHash;long total;byte[] manifestBytes;
            try(ZipFile archive=new ZipFile(zip.toFile())){
                ZipArchiveEntry entry=archive.getEntry(MANIFEST);if(entry==null||entry.isDirectory()||entry.isUnixSymlink()||entry.getSize()<2||entry.getSize()>8_000_000)throw ExamException.bad("Thiếu manifest bundle hợp lệ (tối đa 8 MB).");
                try(InputStream in=archive.getInputStream(entry)){manifestBytes=in.readNBytes(8_000_001);}if(manifestBytes.length>8_000_000)throw ExamException.bad("Manifest quá lớn.");manifestHash=hex(MessageDigest.getInstance("SHA-256").digest(manifestBytes));manifest=JsonParser.parseString(new String(manifestBytes,java.nio.charset.StandardCharsets.UTF_8)).getAsJsonObject();
                if(integer(manifest,"schemaVersion",0)!=1||!str(manifest,"version").matches("[A-Za-z0-9][A-Za-z0-9._-]{0,79}"))throw ExamException.bad("schemaVersion/version bundle không hợp lệ.");
                JsonArray files=manifest.getAsJsonArray("files");if(files==null||files.isEmpty()||files.size()>100_000)throw ExamException.bad("Bundle cần danh sách file đã băm.");
                Map<String,JsonObject> expected=new LinkedHashMap<>();Set<String> normalized=new HashSet<>();total=0;
                for(JsonElement rawFile:files){JsonObject file=rawFile.getAsJsonObject();String name=safeName(str(file,"path"));if(name.equals(MANIFEST)||name.equals("installation.json")||!normalized.add(name.toLowerCase(Locale.ROOT)))throw ExamException.bad("File bundle trùng hoặc dành riêng.");
                    long size=file.get("size").getAsLong();if(size<0||size>MAX_EXPANDED||!str(file,"sha256").matches("[a-fA-F0-9]{64}"))throw ExamException.bad("Size/hash file không hợp lệ.");total=Math.addExact(total,size);if(total>MAX_EXPANDED)throw ExamException.bad("Bundle giải nén tối đa 16 GB.");expected.put(name,file);}
                if(Files.getFileStore(root).getUsableSpace()<total+512L*1024*1024)throw ExamException.bad("Không đủ dung lượng giải nén và vùng an toàn 512 MB.");
                Set<String> declared=Set.copyOf(expected.keySet());Set<String> seen=new HashSet<>();long processed=0;Enumeration<ZipArchiveEntry> entries=archive.getEntries();
                while(entries.hasMoreElements()){
                    checkCancelled(id);ZipArchiveEntry file=entries.nextElement();String name=safeName(file.getName());
                    if(!seen.add(name.toLowerCase(Locale.ROOT))||file.isUnixSymlink()||file.getUnixMode()!=0&&((file.getUnixMode()&0170000)!=0100000&&(file.getUnixMode()&0170000)!=0040000))throw ExamException.bad("Bundle chứa link/file đặc biệt hoặc tên trùng.");
                    if(name.equals(MANIFEST))continue;if(file.isDirectory()){boolean known=declared.stream().anyMatch(n->n.startsWith(name+"/"));if(!known)throw ExamException.bad("Thư mục ngoài manifest.");continue;}
                    JsonObject spec=expected.remove(name);if(spec==null)throw ExamException.bad("Bundle chứa file ngoài manifest: "+name);
                    long size=spec.get("size").getAsLong();if(file.getSize()!=size)throw ExamException.bad("Kích thước ZIP khác manifest: "+name);
                    Path dest=staging.resolve(name).normalize();if(!dest.startsWith(staging))throw ExamException.bad("Đường dẫn thoát staging.");Files.createDirectories(dest.getParent());MessageDigest digest=MessageDigest.getInstance("SHA-256");
                    try(InputStream in=archive.getInputStream(file);OutputStream out=Files.newOutputStream(dest,StandardOpenOption.CREATE_NEW)){copy(in,out,size,digest,id);}
                    if(!hex(digest.digest()).equalsIgnoreCase(str(spec,"sha256")))throw ExamException.bad("SHA256 không khớp: "+name);
                    processed+=size;final double progress=.05+.9*processed/Math.max(1,total);change(id,j->{j.addProperty("progress",progress);j.addProperty("stage","verifying-files");});
                }
                if(!expected.isEmpty())throw ExamException.bad("Bundle thiếu file trong manifest.");
            }
            JsonObject components=manifest.getAsJsonObject("components");if(components==null||components.size()==0)throw ExamException.bad("Bundle thiếu component paths.");JsonObject config=store.read(store.root.resolve("configuration.json"));
            for(String key:components.keySet()){
                if(!Set.of("pythonPath","modelRoot","ffmpegPath").contains(key))throw ExamException.bad("Component không hỗ trợ: "+key);
                String relative=safeName(str(components,key));Path source=staging.resolve(relative);boolean valid=key.equals("modelRoot")?Files.isDirectory(source):Files.isRegularFile(source);if(!valid)throw ExamException.bad("Component path không tồn tại: "+key);
                if(!key.equals("modelRoot")&&!source.getFileName().toString().toLowerCase(Locale.ROOT).equals(key.equals("pythonPath")?"python.exe":"ffmpeg.exe"))throw ExamException.bad("Tên executable component không hợp lệ.");
                config.addProperty(key,activated.resolve(relative).toAbsolutePath().toString());
            }
            Files.write(staging.resolve(MANIFEST),manifestBytes,StandardOpenOption.CREATE_NEW);
            JsonObject metadata=new JsonObject();metadata.addProperty("id",id);metadata.addProperty("version",str(manifest,"version"));metadata.addProperty("manifestSha256",manifestHash);metadata.addProperty("totalBytes",total);metadata.addProperty("fileCount",manifest.getAsJsonArray("files").size());metadata.addProperty("installedAt",java.time.Instant.now().toString());metadata.addProperty("integrityVerified",true);metadata.addProperty("publisherTrustVerified",false);metadata.add("components",components.deepCopy());store.write(staging.resolve("installation.json"),metadata);
            // The cancellation check, rename and pointer update are serialized. Existing
            // installation/configuration are never modified before every hash matches.
            synchronized(this){checkCancelled(id);Files.move(staging,activated,StandardCopyOption.ATOMIC_MOVE);synchronized(store){JsonObject latest=store.read(store.root.resolve("configuration.json"));for(String key:components.keySet())latest.add(key,config.get(key));store.write(store.root.resolve("configuration.json"),latest);}committed=true;change(id,j->{j.addProperty("status","installed");j.addProperty("progress",1);j.add("installation",metadata);});}
        }catch(Exception e){if(!cancelled.contains(id))change(id,j->{j.addProperty("status","failed");j.addProperty("error",e.getMessage()==null?"Bundle không hợp lệ; cấu hình trước được giữ.":e.getMessage());});}
        finally{try{Files.deleteIfExists(zip);deleteTree(staging);if(!committed)deleteTree(activated);}catch(IOException ignored){}cancelled.remove(id);}
    }
    static String safeName(String name){
        if(name==null||name.isBlank()||name.length()>1000||name.indexOf('\\')>=0||name.startsWith("/")||name.contains(":"))throw ExamException.bad("Đường dẫn bundle không hợp lệ.");
        String result=name.endsWith("/")?name.substring(0,name.length()-1):name;
        for(String part:result.split("/",-1))if(part.isBlank()||part.equals(".")||part.equals("..")||part.endsWith(".")||part.endsWith(" ")||part.matches("(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\\..*)?")||part.chars().anyMatch(c->c<32))throw ExamException.bad("Đường dẫn bundle không an toàn.");return result;
    }
    void copy(InputStream in,OutputStream out,long expected,MessageDigest digest,String id)throws Exception{byte[] buffer=new byte[128*1024];long count=0;int n;while((n=in.read(buffer))!=-1){if(id!=null)checkCancelled(id);count+=n;if(count>expected)throw ExamException.bad("Dữ liệu vượt kích thước đã khai báo.");out.write(buffer,0,n);if(digest!=null)digest.update(buffer,0,n);}if(count!=expected)throw ExamException.bad("Dữ liệu không đủ kích thước khai báo.");}
    static String hex(byte[] bytes){return HexFormat.of().formatHex(bytes);}
    static void deleteTree(Path root)throws IOException{if(!Files.exists(root))return;try(var paths=Files.walk(root)){for(Path path:paths.sorted(Comparator.reverseOrder()).toList())Files.deleteIfExists(path);}}
    @PreDestroy public void close(){executor.shutdownNow();}
}
