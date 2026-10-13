package vn.teaching.exam;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

/** Old standalone links now open the existing Flutter application. */
@Controller
public class LegacyExamRedirect {
    @GetMapping("/")
    public String home() { return "forward:/index.html"; }

    @GetMapping({"/exams", "/exams/", "/exams/**"})
    public String app() { return "redirect:/"; }
}
