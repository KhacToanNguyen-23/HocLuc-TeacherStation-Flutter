package vn.teaching.preparation;
import com.google.gson.*;
import org.junit.jupiter.api.Test;
import java.nio.file.*;
import java.awt.*;
import java.awt.image.BufferedImage;
import javax.imageio.ImageIO;
import org.apache.pdfbox.Loader;
import org.apache.pdfbox.rendering.*;
import static org.junit.jupiter.api.Assertions.*;

/** Intentional ignored target artifacts for visual inspection of the real exporter. */
class PreparationPdfVisualTest {
 @Test void rendersBothAudiencesForVisualInspection()throws Exception{
    Path qa=Path.of("target","preparation-qa");Files.createDirectories(qa);
    BufferedImage image=new BufferedImage(900,240,BufferedImage.TYPE_INT_RGB);Graphics2D g=image.createGraphics();
    g.setColor(Color.WHITE);g.fillRect(0,0,900,240);g.setColor(new Color(3,105,161));g.setFont(new Font("Arial",Font.BOLD,25));
    g.drawString("Water -> Evaporation -> Clouds -> Rain",65,100);g.setColor(Color.DARK_GRAY);g.setFont(new Font("Arial",Font.PLAIN,20));g.drawString("Shared context: observe the cycle before answering both questions.",65,155);g.dispose();
    Path picture=qa.resolve("question.png");ImageIO.write(image,"png",picture.toFile());
    JsonObject doc=JsonParser.parseString("""
      {"title":"Water cycle — Bài học mẫu","subject":"Science","sections":[
      {"id":"group","title":"Nhóm câu hỏi dùng chung ngữ cảnh","body":"Observe the water cycle. Question 1. What causes evaporation? A. Heat. B. Cold. Question 2. What happens inside clouds?",
      "teacherNotes":"PRIVATE_ANSWER: 1. A — Heat causes evaporation. 2. Water condenses. Nhắc riêng: đợi học sinh thảo luận trước khi giải thích.",
      "questionBank":{"images":[{"imageAssetId":"public","private":false}]}}],
      "scenes":[],"exportTemplate":{"school":"Trường Đại học Mẫu","faculty":"Khoa Giáo dục","name":"GIÁO ÁN / HỌC LIỆU","fields":[]}}
      """).getAsJsonObject();
    doc.add("teacherCues",JsonParser.parseString("[{\"id\":\"cue1\",\"text\":\"PRIVATE_PAGE_CUE\",\"locator\":{\"kind\":\"pdf\",\"documentId\":\"doc1\",\"contentFingerprint\":\"abc\",\"pageIndex\":3}}]"));
    for(String audience:new String[]{"student","teacher"}){
       PreparationPdf.generate(doc,qa,audience,id->picture);
       try(var pdf=Loader.loadPDF(qa.resolve(audience+"-lesson.pdf").toFile())){
         String text=new org.apache.pdfbox.text.PDFTextStripper().getText(pdf);
         assertEquals(audience.equals("teacher"),text.contains("PRIVATE_ANSWER"));
         assertEquals(audience.equals("teacher"),text.contains("PRIVATE_PAGE_CUE"));
         PDFRenderer renderer=new PDFRenderer(pdf);
         for(int page=0;page<pdf.getNumberOfPages();page++)ImageIO.write(renderer.renderImageWithDPI(page,100,ImageType.RGB),"png",qa.resolve(audience+"-"+(page+1)+".png").toFile());
       }
    }
 }
}
