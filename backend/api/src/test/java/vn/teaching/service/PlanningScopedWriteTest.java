package vn.teaching.service;

import com.google.gson.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import java.nio.file.*;
import java.util.concurrent.*;
import static org.assertj.core.api.Assertions.*;

class PlanningScopedWriteTest {
    @TempDir Path root;
    final Gson gson = new Gson();
    JsonObject json(String text) { return JsonParser.parseString(text).getAsJsonObject(); }
    @Test void derivedPresentationCannotSilentlyReplaceCanonicalBoard() throws Exception {
        var service=new PlanningService(root,gson);
        String id=service.saveOrUpdatePlanning(null,"T","S",json("{\"pages\":[[]]}")).getId();
        var board=service.getPlanningContent(id);board.add("preparationProjection",new JsonObject());
        assertThatThrownBy(()->service.saveBoard(id,null,null,board,0)).isInstanceOf(vn.teaching.exam.ExamException.class);
        assertThat(service.getPlanningContent(id).has("preparationProjection")).isFalse();
    }
    @Test void stalePreparationRevisionCannotReplaceNewerDocument() throws Exception {
        var service=new PlanningService(root,gson);
        String id=service.saveOrUpdatePlanning(null,"T","S",json("{\"pages\":[[]]}")).getId();
        service.mergePreparation(id,0,json("{\"revision\":1,\"title\":\"Kept\"}"));
        assertThatThrownBy(()->service.mergePreparation(id,0,json("{\"revision\":1,\"title\":\"Lost\"}")))
            .isInstanceOf(vn.teaching.exam.ExamException.class);
        assertThat(service.getPlanningContent(id).getAsJsonObject("preparation").get("title").getAsString()).isEqualTo("Kept");
    }
    @Test void staleBoardSnapshotCannotReplacePreparationAndStaleRevisionConflicts() throws Exception {
        var service = new PlanningService(root,gson);
        var created = service.saveOrUpdatePlanning(null,"Title","Subject",json("{\"pages\":[[]],\"preparation\":{\"revision\":0}}"));
        var stale = service.getPlanningContent(created.getId());
        service.mergePreparation(created.getId(),0,json("{\"revision\":1,\"title\":\"New\"}"));
        service.saveBoard(created.getId(),null,null,stale,0);
        var result = service.getPlanningContent(created.getId());
        assertThat(result.getAsJsonObject("preparation").get("title").getAsString()).isEqualTo("New");
        assertThatThrownBy(()->service.saveBoard(created.getId(),null,null,stale,0)).isInstanceOf(vn.teaching.exam.ExamException.class);
    }
    @Test void concurrentScopedWritesPreserveBothScopes() throws Exception {
        var service = new PlanningService(root,gson);
        String id=service.saveOrUpdatePlanning(null,"T","S",json("{\"pages\":[[]]}" )).getId();
        var board=service.getPlanningContent(id);board.addProperty("notes","BOARD SENTINEL");
        var start=new CountDownLatch(1);var executor=Executors.newFixedThreadPool(2);
        try {
            var a=executor.submit(()->{start.await();return service.saveBoard(id,null,null,board,0);});
            var b=executor.submit(()->{start.await();return service.mergePreparation(id,0,json("{\"revision\":1,\"title\":\"PREP SENTINEL\"}"));});
            start.countDown();a.get(5,TimeUnit.SECONDS);b.get(5,TimeUnit.SECONDS);
            var result=service.getPlanningContent(id);
            assertThat(result.get("notes").getAsString()).isEqualTo("BOARD SENTINEL");
            assertThat(result.getAsJsonObject("preparation").get("title").getAsString()).isEqualTo("PREP SENTINEL");
        } finally { executor.shutdownNow(); }
    }
    @Test void legacyMigrationHasStableIdsAndImmutableBackup() throws Exception {
        var service=new PlanningService(root,gson);
        String id=service.saveOrUpdatePlanning(null,"T","S",json("{\"pages\":[[],[]],\"pageNotes\":[\"One\",\"Two\"]}")).getId();
        Path file=root.resolve("plannings").resolve(id+".json");String original=Files.readString(file);
        var first=service.getPlanningContent(id);var second=service.getPlanningContent(id);
        assertThat(first.getAsJsonArray("pageIds")).hasSize(2);
        assertThat(first).isEqualTo(second);
        assertThat(Files.readString(file.resolveSibling(id+".json.schema1.bak"))).isEqualTo(original);
        assertThat(first.getAsJsonArray("pageNotes").get(1).getAsString()).isEqualTo("Two");
    }
    @Test void boardCueWriteChecksPreparationRevisionAndPreservesSections() throws Exception {
        var service=new PlanningService(root,gson);
        String id=service.saveOrUpdatePlanning(null,"T","S",json("{\"pages\":[[]],\"preparation\":{\"revision\":3,\"sections\":[{\"id\":\"kept\"}]}}")).getId();
        var board=service.getPlanningContent(id);board.add("teacherCueUpdates",new JsonArray());board.addProperty("expectedPreparationRevision",2);
        assertThatThrownBy(()->service.saveBoard(id,null,null,board,0)).isInstanceOf(vn.teaching.exam.ExamException.class);
        board.addProperty("expectedPreparationRevision",3);service.saveBoard(id,null,null,board,0);
        var prep=service.getPlanningContent(id).getAsJsonObject("preparation");
        assertThat(prep.get("revision").getAsInt()).isEqualTo(4);
        assertThat(prep.getAsJsonArray("sections")).hasSize(1);
        service.saveBoard(id,null,null,board,0);
        assertThatThrownBy(()->service.saveBoard(id,"Different title",null,board,0)).isInstanceOf(vn.teaching.exam.ExamException.class);
        assertThat(service.getPlanningContent(id).get("boardRevision").getAsInt()).isEqualTo(1);
        assertThat(service.getPlanningContent(id).getAsJsonObject("preparation").get("revision").getAsInt()).isEqualTo(4);
        board.addProperty("notes","different unsaved edit");
        assertThatThrownBy(()->service.saveBoard(id,null,null,board,0)).isInstanceOf(vn.teaching.exam.ExamException.class);
    }
}
