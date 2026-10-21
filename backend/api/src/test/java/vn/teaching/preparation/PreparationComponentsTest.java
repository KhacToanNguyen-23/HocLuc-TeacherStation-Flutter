package vn.teaching.preparation;
import com.google.gson.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.mock.web.MockMultipartFile;
import vn.teaching.service.PlanningService;
import vn.teaching.exam.ExamException;
import java.nio.file.*;
import java.io.*;
import java.util.*;
import java.util.concurrent.*;
import java.security.MessageDigest;
import org.apache.commons.compress.archivers.zip.*;
import static org.junit.jupiter.api.Assertions.*;

class PreparationComponentsTest {
    @TempDir Path dir;PreparationStore store;PreparationComponents components;
    @BeforeEach void setup()throws Exception{store=new PreparationStore(dir,new Gson(),new PlanningService(dir,new Gson()));components=new PreparationComponents(store);JsonObject config=new JsonObject();config.addProperty("modelRoot","old-model-root");config.addProperty("authoringModel","keep-local-model");store.write(store.root.resolve("configuration.json"),config);}
    @AfterEach void close(){components.close();}
    MockMultipartFile bundle(String name,String actual,String digestInput,int unixMode)throws Exception{
        byte[] bytes=actual.getBytes(java.nio.charset.StandardCharsets.UTF_8);JsonObject manifest=new JsonObject(),component=new JsonObject(),file=new JsonObject();manifest.addProperty("schemaVersion",1);manifest.addProperty("version","test-1.0");component.addProperty("modelRoot","models");manifest.add("components",component);file.addProperty("path",name);file.addProperty("size",bytes.length);file.addProperty("sha256",HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(digestInput.getBytes(java.nio.charset.StandardCharsets.UTF_8))));JsonArray files=new JsonArray();files.add(file);manifest.add("files",files);
        ByteArrayOutputStream out=new ByteArrayOutputStream();try(ZipArchiveOutputStream zip=new ZipArchiveOutputStream(out)){
            ZipArchiveEntry metadata=new ZipArchiveEntry("bundle-manifest.json");zip.putArchiveEntry(metadata);zip.write(manifest.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8));zip.closeArchiveEntry();
            ZipArchiveEntry payload=new ZipArchiveEntry(name);if(unixMode!=0)payload.setUnixMode(unixMode);zip.putArchiveEntry(payload);zip.write(bytes);zip.closeArchiveEntry();
            if(name.startsWith("models/")){zip.putArchiveEntry(new ZipArchiveEntry("models/"));zip.closeArchiveEntry();}
        }return new MockMultipartFile("file","bundle.zip","application/zip",out.toByteArray());
    }
    JsonObject run(MockMultipartFile file)throws Exception{JsonObject job=components.start("teacher-a",file);components.executor.submit(()->{}).get(20,TimeUnit.SECONDS);return components.get(job.get("id").getAsString(),"teacher-a");}
    @Test void validBundleActivatesAfterHashVerificationPreservingOtherConfiguration()throws Exception{
        JsonObject job=run(bundle("models/example/config.json","{}","{}",0));assertEquals("installed",job.get("status").getAsString());assertEquals(1,job.get("progress").getAsDouble());JsonObject config=store.read(store.root.resolve("configuration.json"));assertEquals("keep-local-model",config.get("authoringModel").getAsString());Path models=Path.of(config.get("modelRoot").getAsString());assertEquals("{}",Files.readString(models.resolve("example/config.json")));assertTrue(models.startsWith(components.root.resolve("installed")));JsonObject installed=components.installed().get(0).getAsJsonObject();assertTrue(installed.get("integrityVerified").getAsBoolean());assertFalse(installed.get("publisherTrustVerified").getAsBoolean());assertEquals(64,installed.get("manifestSha256").getAsString().length());
    }
    @Test void hashMismatchPreservesExistingConfigurationAndRemovesStaging()throws Exception{
        JsonObject job=run(bundle("models/config.json","bad","old",0));assertEquals("failed",job.get("status").getAsString());assertTrue(job.get("error").getAsString().contains("SHA256"));assertEquals("old-model-root",store.read(store.root.resolve("configuration.json")).get("modelRoot").getAsString());assertEquals(0,components.installed().size());try(var paths=Files.list(components.root.resolve("staging"))){assertEquals(0,paths.count());}
    }
    @Test void rejectsZipTraversalAndWindowsAliasesBeforeWritingOutsideStaging()throws Exception{
        JsonObject job=run(bundle("../escape.txt","data","data",0));assertEquals("failed",job.get("status").getAsString());assertFalse(Files.exists(components.root.resolve("escape.txt")));for(String path:List.of("/root/file","C:/file","models/../outside","models\\outside","models/NUL.txt","models/a. "))assertThrows(ExamException.class,()->PreparationComponents.safeName(path));
    }
    @Test void rejectsUnixSymlinkEvenWhenHashAndSizeMatch()throws Exception{
        JsonObject job=run(bundle("models/link","target","target",0120777));assertEquals("failed",job.get("status").getAsString());assertEquals("old-model-root",store.read(store.root.resolve("configuration.json")).get("modelRoot").getAsString());
    }
    @Test void installationStateIsOwnedAndQueuedCancellationKeepsOldConfig()throws Exception{
        CountDownLatch release=new CountDownLatch(1);components.executor.submit(()->{try{release.await();}catch(InterruptedException e){Thread.currentThread().interrupt();}});
        JsonObject queued=components.start("teacher-a",bundle("models/config.json","{}","{}",0));String id=queued.get("id").getAsString();assertThrows(ExamException.class,()->components.get(id,"teacher-b"));assertThrows(ExamException.class,()->components.cancel(id,"teacher-b"));assertEquals(0,components.list("teacher-b").size());components.cancel(id,"teacher-a");release.countDown();components.executor.submit(()->{}).get(20,TimeUnit.SECONDS);assertEquals("cancelled",components.get(id,"teacher-a").get("status").getAsString());assertEquals("old-model-root",store.read(store.root.resolve("configuration.json")).get("modelRoot").getAsString());assertEquals(1,components.list("teacher-a").size());
    }
}
