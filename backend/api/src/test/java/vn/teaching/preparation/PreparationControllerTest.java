package vn.teaching.preparation;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.test.web.servlet.*;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import com.google.gson.*;
import vn.teaching.exam.*;
import vn.teaching.service.PlanningService;
import java.nio.file.Path;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
class PreparationControllerTest {
    @TempDir Path dir;
    @Test void classroomCloneReturnsCommittedTeachingContentWithoutChangingSource() throws Exception {
        Gson gson=new Gson();PlanningService planning=new PlanningService(dir,gson);
        String id=planning.saveOrUpdatePlanning(null,"Saved lesson","General",null).getId();
        PreparationStore store=new PreparationStore(dir,gson,planning);store.claim(id,"a");
        JsonObject source=planning.getPlanningContent(id);
        ExamAuth auth=mock(ExamAuth.class);
        when(auth.authenticate("Bearer a")).thenReturn(new ExamModels.Account("a","a@test.org","A","TEACHER"));
        MockMvc mvc=MockMvcBuilders.standaloneSetup(new vn.teaching.controller.PlanningController(planning,gson,store,auth,mock(PreparationRecording.class)))
            .setControllerAdvice(new PreparationErrors()).build();
        String body=mvc.perform(post("/api/plannings/"+id+"/clone-to-classroom").header("Authorization","Bearer a"))
            .andExpect(status().isOk()).andExpect(content().contentTypeCompatibleWith("application/json"))
            .andExpect(jsonPath("$.success").value(true)).andExpect(jsonPath("$.content.title").value("Saved lesson"))
            .andReturn().getResponse().getContentAsString();
        JsonObject cloned=JsonParser.parseString(body).getAsJsonObject().getAsJsonObject("content");
        org.assertj.core.api.Assertions.assertThat(JsonParser.parseString(java.nio.file.Files.readString(dir.resolve("lesson.json")))).isEqualTo(cloned);
        org.assertj.core.api.Assertions.assertThat(planning.getPlanningContent(id)).isEqualTo(source);
    }
    @Test void boardSaveAcknowledgementIsJsonAndSupportsConsecutiveSaves() throws Exception {
        Gson gson=new Gson();PlanningService planning=new PlanningService(dir,gson);
        String id=planning.saveOrUpdatePlanning(null,"Lesson","General",null).getId();
        PreparationStore store=new PreparationStore(dir,gson,planning);store.claim(id,"a");
        ExamAuth auth=mock(ExamAuth.class);
        when(auth.authenticate("Bearer a")).thenReturn(new ExamModels.Account("a","a@test.org","A","TEACHER"));
        MockMvc mvc=MockMvcBuilders.standaloneSetup(new vn.teaching.controller.PlanningController(planning,gson,store,auth,mock(PreparationRecording.class)))
            .setControllerAdvice(new PreparationErrors()).build();
        JsonObject board=planning.getPlanningContent(id);
        for(int revision=0;revision<2;revision++) {
            JsonObject request=new JsonObject();request.addProperty("expectedRevision",revision);
            board.addProperty("notes","saved-"+revision);request.add("content",board.deepCopy());
            mvc.perform(put("/api/plannings/"+id).header("Authorization","Bearer a").contentType("application/json").content(request.toString()))
                .andExpect(status().isOk()).andExpect(content().contentTypeCompatibleWith("application/json"))
                .andExpect(jsonPath("$.id").value(id)).andExpect(jsonPath("$.boardRevision").value(revision+1));
            // Simulate a committed save whose acknowledgement never reached the client.
            mvc.perform(put("/api/plannings/"+id).header("Authorization","Bearer a")
                .contentType("application/json").content(request.toString()))
                .andExpect(status().isOk()).andExpect(jsonPath("$.boardRevision").value(revision+1));
            mvc.perform(get("/api/plannings/"+id).header("Authorization","Bearer a"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.boardRevision").value(revision+1))
                .andExpect(jsonPath("$.notes").value("saved-"+revision));
        }
        mvc.perform(put("/api/plannings/"+id).header("Authorization","Bearer a").contentType("application/json")
              .content("{\"expectedRevision\":1,\"content\":{\"pages\":[[]],\"notes\":\"different\"}}"))
              .andExpect(status().isConflict());
          mvc.perform(put("/api/plannings/"+id).header("Authorization","Bearer a").contentType("application/json")
            .content("{\"expectedRevision\":0,\"content\":{\"pages\":[[]]}}"))
            .andExpect(status().isConflict());
        org.assertj.core.api.Assertions.assertThat(planning.getPlanningContent(id).get("notes").getAsString()).isEqualTo("saved-1");
    }
    @Test void endpointsRejectMissingBearerAndOtherTeacherAndReturnPublicDocument()throws Exception{
        PlanningService planning=new PlanningService(dir,new Gson());String id=planning.saveOrUpdatePlanning(null,"Lesson","General",null).getId();
        PreparationStore store=new PreparationStore(dir,new Gson(),planning);ExamAuth auth=mock(ExamAuth.class);
        when(auth.authenticate(null)).thenThrow(new ExamException(org.springframework.http.HttpStatus.UNAUTHORIZED,"SESSION_REQUIRED","Login",java.util.List.of()));
        when(auth.authenticate("Bearer a")).thenReturn(new ExamModels.Account("a","a@test.org","A","TEACHER"));when(auth.authenticate("Bearer b")).thenReturn(new ExamModels.Account("b","b@test.org","B","TEACHER"));
        MockMvc mvc=MockMvcBuilders.standaloneSetup(new PreparationController(auth,store,mock(PreparationJobs.class),mock(PreparationPublishing.class),mock(PreparationRecording.class),mock(PreparationComponents.class))).setControllerAdvice(new PreparationErrors()).build();
        mvc.perform(get("/api/preparation/plannings/"+id)).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/preparation/plannings/"+id).header("Authorization","Bearer a")).andExpect(status().isOk()).andExpect(jsonPath("$.revision").value(0)).andExpect(jsonPath("$.owner").doesNotExist());
        mvc.perform(get("/api/preparation/plannings/"+id).header("Authorization","Bearer b")).andExpect(status().isNotFound());
        mvc.perform(put("/api/preparation/plannings/"+id).header("Authorization","Bearer a").contentType("application/json").content("{\"expectedRevision\":9,\"document\":{}}" )).andExpect(status().isConflict());
    }
    @Test void legacyPlanningCannotReadModifyDeleteOrCloneClaimedPreparation()throws Exception{
        PlanningService planning=new PlanningService(dir,new Gson());String id=planning.saveOrUpdatePlanning(null,"Lesson","General",null).getId();PreparationStore store=new PreparationStore(dir,new Gson(),planning);store.claim(id,"a");
        ExamAuth auth=mock(ExamAuth.class);when(auth.authenticate("Bearer a")).thenReturn(new ExamModels.Account("a","a@test.org","A","TEACHER"));when(auth.authenticate("Bearer b")).thenReturn(new ExamModels.Account("b","b@test.org","B","TEACHER"));
        PreparationRecording recording=mock(PreparationRecording.class);MockMvc mvc=MockMvcBuilders.standaloneSetup(new vn.teaching.controller.PlanningController(planning,new Gson(),store,auth,recording)).setControllerAdvice(new PreparationErrors()).build();
        mvc.perform(get("/api/plannings/"+id)).andExpect(status().isNotFound());mvc.perform(get("/api/plannings").header("Authorization","Bearer b")).andExpect(jsonPath("$.length()").value(0));
        mvc.perform(put("/api/plannings/"+id).header("Authorization","Bearer b").contentType("application/json").content("{}")).andExpect(status().isNotFound());
        mvc.perform(delete("/api/plannings/"+id).header("Authorization","Bearer b")).andExpect(status().isNotFound());
        mvc.perform(post("/api/plannings/"+id+"/clone-to-classroom").header("Authorization","Bearer b")).andExpect(status().isNotFound());
        mvc.perform(get("/api/plannings/"+id).header("Authorization","Bearer a")).andExpect(status().isOk());
        when(recording.pending(id)).thenReturn(true);mvc.perform(delete("/api/plannings/"+id).header("Authorization","Bearer a")).andExpect(status().isConflict());when(recording.pending(id)).thenReturn(false);
        JsonObject state=store.state(id,"a"),job=new JsonObject();job.addProperty("id","pending");job.addProperty("status","queued");state.getAsJsonArray("jobs").add(job);store.saveState(id,state);mvc.perform(delete("/api/plannings/"+id).header("Authorization","Bearer a")).andExpect(status().isConflict());
        String unclaimed=planning.saveOrUpdatePlanning(null,"Legacy","General",null).getId();mvc.perform(get("/api/plannings/"+unclaimed)).andExpect(status().isOk());
    }
}
