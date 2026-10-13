package vn.teaching.exam;

import org.apache.pdfbox.pdmodel.*;
import org.apache.pdfbox.pdmodel.common.PDRectangle;
import org.apache.pdfbox.pdmodel.font.*;
import org.apache.pdfbox.pdmodel.graphics.image.PDImageXObject;
import org.apache.poi.xwpf.usermodel.*;
import org.apache.poi.util.Units;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;
import java.io.*;
import java.util.*;
import static vn.teaching.exam.ExamModels.*;

@Service
public class ExportService {
    private final SourceService sources; private final ExamRepository repo;
    public ExportService(SourceService sources,ExamRepository repo) { this.sources=sources; this.repo=repo; }
    private record Block(String text,String assetId) {}
    private List<Block> blocks(Paper p,String kind) {
        List<Block> out=new ArrayList<>(); out.add(new Block(p.title(),null));
        out.add(new Block(p.matrix().examType()+" · "+p.matrix().examVersion()+" · Mã đề "+p.variant()+" · "+p.durationMinutes()+" phút",null));
        out.add(new Block("Exam ID: "+p.id()+" · Điểm luyện tập / raw score",null));
        if(kind.equals("matrix")) {
            out.add(new Block("Ma trận: "+p.matrix().name(),null));
            for(Quota q:p.matrix().quotas()) out.add(new Block(q.label()+": "+q.count()+" câu · "+(q.type()==null?"MCQ/SHORT":q.type()),null)); return out;
        }
        if(kind.equals("paper")) out.add(new Block(p.instructions(),null));
        Set<String> contexts=new HashSet<>();
        for(int i=0;i<p.questions().size();i++) {
            Question q=p.questions().get(i);
            if(kind.equals("paper")) {
                if(q.groupId()!=null&&contexts.add(q.groupId())) {
                    Group g=p.groups().stream().filter(group->group.id().equals(q.groupId())).findFirst().orElseThrow();
                    if(g.assets().isEmpty()) out.add(new Block(g.content(),null)); else g.assets().forEach(a->out.add(new Block(null,a)));
                }
                out.add(new Block("Câu "+(i+1)+".",null)); q.assets().forEach(a->out.add(new Block(null,a)));
            } else {
                out.add(new Block("Câu "+(i+1)+": "+q.answer(),null));
                if(kind.equals("solutions")) {
                    if(q.solution()!=null&&!q.solution().isBlank()) out.add(new Block(q.solution(),null));
                    else if(q.solutionAssets().isEmpty()) out.add(new Block("Chưa có lời giải đã duyệt.",null));
                    q.solutionAssets().forEach(asset->out.add(new Block(null,asset)));
                }
            }
        }
        return out;
    }
    public byte[] export(Paper p,String format,String kind) throws IOException {
        if(!p.status().equals("PUBLISHED")) throw ExamException.bad("Xuất bản đề hợp lệ trước khi tải tài liệu.");
        if(!Set.of("paper","answers","solutions","matrix").contains(kind)||!Set.of("pdf","docx").contains(format)) throw ExamException.bad("Định dạng/loại xuất không hợp lệ.");
        List<Block> blocks=blocks(p,kind); byte[] bytes=format.equals("pdf")?pdf(blocks):docx(blocks);
        repo.insert("export_records",ExamRepository.id(),Map.of("format",format,"kind",kind,"at",ExamRepository.now(),"checksum",ExamAuth.digest(bytes)),Map.of("paper_id",p.id())); return bytes;
    }
    private byte[] docx(List<Block> blocks) throws IOException {
        try(XWPFDocument doc=new XWPFDocument(); ByteArrayOutputStream out=new ByteArrayOutputStream()) {
            for(Block b:blocks) {
                XWPFParagraph para=doc.createParagraph(); XWPFRun run=para.createRun(); run.setFontFamily("Manrope"); run.setFontSize(11);
                if(b.assetId()!=null) {
                    Asset a=sources.asset(b.assetId()); double factor=Math.min(1,Math.min(600.0/a.width(),850.0/a.height()));
                    try(InputStream in=new FileInputStream(sources.path(a.path()).toFile())) {
                        run.addPicture(in,org.apache.poi.xwpf.usermodel.Document.PICTURE_TYPE_PNG,"question.png",Units.toEMU(a.width()*factor),Units.toEMU(a.height()*factor));
                    } catch(org.apache.poi.openxml4j.exceptions.InvalidFormatException e) { throw new IOException(e); }
                } else run.setText(b.text()==null?"":b.text());
            }
            doc.write(out); return out.toByteArray();
        }
    }
    private byte[] pdf(List<Block> blocks) throws IOException {
        try(PDDocument doc=new PDDocument(); ByteArrayOutputStream out=new ByteArrayOutputStream(); InputStream in=new ClassPathResource("exam-assets/fonts/Manrope.ttf").getInputStream()) {
            PDFont font=PDType0Font.load(doc,in); PDPage page=new PDPage(PDRectangle.A4); doc.addPage(page); float y=790; int number=1;
            for(Block b:blocks) {
                if(b.assetId()!=null) {
                    Asset a=sources.asset(b.assetId()); float w=499, h=w*a.height()/a.width(); if(h>710) { h=710; w=h*a.width()/a.height(); }
                    if(y-h<40) { page=new PDPage(PDRectangle.A4); doc.addPage(page); y=790; number++; }
                    try(PDPageContentStream stream=new PDPageContentStream(doc,page,PDPageContentStream.AppendMode.APPEND,true)) {
                        stream.drawImage(PDImageXObject.createFromFileByContent(sources.path(a.path()).toFile(),doc),48,y-h,w,h);
                    } y-=h+14;
                } else {
                    String value=(b.text()==null?"":b.text()).replaceAll("[\\p{Cc}&&[^\\n]]", " ");
                    for(String paragraph:value.split("\\n",-1)) for(String line:wrap(paragraph,font,10,499)) {
                        if(y<55) { page=new PDPage(PDRectangle.A4); doc.addPage(page); y=790; number++; }
                        try(PDPageContentStream stream=new PDPageContentStream(doc,page,PDPageContentStream.AppendMode.APPEND,true)) {
                            stream.beginText(); stream.setFont(font,10); stream.newLineAtOffset(48,y); stream.showText(line); stream.endText();
                        } y-=15;
                    } y-=6;
                }
            }
            int index=1;
            for(PDPage p:doc.getPages()) try(PDPageContentStream stream=new PDPageContentStream(doc,p,PDPageContentStream.AppendMode.APPEND,true)) {
                stream.beginText(); stream.setFont(font,9); stream.newLineAtOffset(48,25); stream.showText("Trang "+index++ +" / "+doc.getNumberOfPages()); stream.endText();
            }
            doc.save(out); return out.toByteArray();
        }
    }
    private List<String> wrap(String text,PDFont font,float size,float width) throws IOException {
        List<String> lines=new ArrayList<>(); StringBuilder line=new StringBuilder();
        for(int cp:text.codePoints().toArray()) {
            String ch=new String(Character.toChars(cp));
            try { font.getStringWidth(ch); } catch(IllegalArgumentException e) { ch="?"; }
            if(font.getStringWidth(line+ch)/1000*size>width&&line.length()>0) { lines.add(line.toString()); line.setLength(0); }
            line.append(ch);
        }
        lines.add(line.toString()); return lines;
    }
}
