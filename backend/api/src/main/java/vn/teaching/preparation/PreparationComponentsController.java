package vn.teaching.preparation;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import vn.teaching.exam.ExamAuth;
@RestController
@RequestMapping("/api/preparation/components")
public class PreparationComponentsController {
    final PreparationComponents components;final ExamAuth auth;
    public PreparationComponentsController(PreparationComponents components,ExamAuth auth){this.components=components;this.auth=auth;}
    Object result(com.google.gson.JsonElement value){return components.store.gson.fromJson(value,Object.class);}
    @PostMapping("/install")public Object install(@RequestHeader(value="Authorization",required=false)String token,@RequestParam MultipartFile file)throws Exception{return result(components.start(auth.authenticate(token).id(),file));}
    @GetMapping("/installations")public Object list(@RequestHeader(value="Authorization",required=false)String token){return result(components.list(auth.authenticate(token).id()));}
    @GetMapping("/installations/{id}")public Object state(@RequestHeader(value="Authorization",required=false)String token,@PathVariable String id){return result(components.get(id,auth.authenticate(token).id()));}
    @PostMapping("/installations/{id}/cancel")public Object cancel(@RequestHeader(value="Authorization",required=false)String token,@PathVariable String id){return result(components.cancel(id,auth.authenticate(token).id()));}
}
