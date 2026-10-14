package vn.teaching.exam;

import org.apache.pdfbox.Loader;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.rendering.PDFRenderer;
import org.apache.pdfbox.text.PDFTextStripper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.*;
import java.nio.file.*;
import java.text.Normalizer;
import java.util.*;
import java.util.regex.*;
import static vn.teaching.exam.ExamModels.*;
import static vn.teaching.exam.ExamRepository.*;

@Service
public class SourceService {
    private final ExamRepository repo;
    private final Path storage;
    public SourceService(ExamRepository repo,@Value("${exam.storage}") String storage) throws IOException {
        this.repo=repo; this.storage=Path.of(storage).toAbsolutePath().normalize(); Files.createDirectories(this.storage);
    }
    public Path path(String relative) {
        Path p=storage.resolve(relative).normalize();
        if(!p.startsWith(storage)) throw ExamException.bad("Đường dẫn không hợp lệ."); return p;
    }
    public Source source(String sourceId) { return repo.require("pdf_sources",sourceId,Source.class); }
    public Path pdf(String sourceId) { return path(source(sourceId).checksum()+"/source.pdf"); }
    @Transactional
    public synchronized Map<String,Object> upload(MultipartFile file,String relative,String examType,String version) throws IOException {
        if(!Set.of("VACT","HSA").contains(examType) || version==null || !version.matches("[0-9]{4}(?:[a-zA-Z0-9_-]{0,24})")) throw ExamException.bad("Chọn VACT/HSA và phiên bản năm.");
        if(file.isEmpty() || file.getSize()>30*1024*1024) throw ExamException.bad("PDF rỗng hoặc lớn hơn 30 MB.");
        String rawName=relative==null?file.getOriginalFilename():relative;
        if(rawName==null) throw ExamException.bad("Tên PDF bắt buộc.");
        String name=rawName.replace('\\','/');
        if(name.length()>450 || !name.toLowerCase(Locale.ROOT).endsWith(".pdf") || name.startsWith("/") || Arrays.asList(name.split("/")).contains("..") || name.contains(":")) throw ExamException.bad("Tên PDF/thư mục không hợp lệ.");
        byte[] bytes=file.getBytes();
        if(bytes.length<5 || !new String(bytes,0,5,java.nio.charset.StandardCharsets.US_ASCII).equals("%PDF-")) throw ExamException.bad("File không phải PDF.");
        String checksum=ExamAuth.digest(bytes);
        var duplicate=repo.all("pdf_sources",Source.class).stream().filter(s->s.checksum().equals(checksum)).findFirst();
        if(duplicate.isPresent()) return Map.of("duplicate",true,"source",duplicate.get());
        int pages;
        try(PDDocument doc=Loader.loadPDF(bytes)) {
            if(doc.isEncrypted()) throw ExamException.bad("PDF có mật khẩu chưa được hỗ trợ.");
            pages=doc.getNumberOfPages();
            if(pages<1 || pages>300) throw ExamException.bad("Mỗi PDF cần 1–300 trang.");
        } catch(IOException e) { throw ExamException.bad("PDF không đọc được hoặc bị hỏng."); }
        String logical=examType+":"+version+":"+name;
        int revision=repo.all("pdf_sources",Source.class).stream().filter(s->s.logicalKey().equals(logical)).mapToInt(Source::revision).max().orElse(0)+1;
        Files.createDirectories(path(checksum)); Path original=path(checksum+"/source.pdf");
        if(!Files.exists(original)) Files.write(original,bytes,StandardOpenOption.CREATE_NEW);
        else if(!ExamAuth.digest(Files.readAllBytes(original)).equals(checksum)) throw new IOException("Stored source checksum mismatch");
        Source source=new Source(id(),logical,name,examType,version,checksum,revision,true,"UPLOADED",pages,now());
        repo.insert("pdf_sources",source.id(),source,Map.of("logical_key",logical,"checksum",checksum,"revision",revision));
        return Map.of("duplicate",false,"source",source);
    }
    @Transactional
    public Source active(String id,boolean active) {
        Source s=source(id); Source updated=new Source(s.id(),s.logicalKey(),s.relativePath(),s.examType(),s.examVersion(),s.checksum(),s.revision(),active,s.status(),s.pages(),s.createdAt());
        repo.update("pdf_sources",id,updated); return updated;
    }
    @Transactional
    public synchronized Job process(String sourceId,boolean force) {
        Source s=source(sourceId);
        if(!force && (s.status().equals("REVIEW_READY") || s.status().equals("NEEDS_OCR")))
            throw ExamException.conflict("PDF đã xử lý. Chọn xử lý lại nếu cần; câu hỏi đã duyệt được giữ nguyên.");
        String jobId=id(); List<String> issues=new ArrayList<>(); String status="REVIEW_READY";
        repo.insert("processing_jobs",jobId,new Job(jobId,sourceId,"PROCESSING",List.of(),now()),Map.of("source_id",sourceId));
        try(PDDocument document=Loader.loadPDF(pdf(sourceId).toFile())) {
            PDFRenderer renderer=new PDFRenderer(document); PDFTextStripper stripper=new PDFTextStripper(); stripper.setSortByPosition(true);
            int textPages=0;
            for(int page=1;page<=document.getNumberOfPages();page++) {
                String imagePath=s.checksum()+"/page-"+page+".png";
                if(!Files.exists(path(imagePath))) {
                    var bounds=document.getPage(page-1).getMediaBox();
                    float scale=Math.min(120f/72f,1800f/Math.max(bounds.getWidth(),bounds.getHeight()));
                    BufferedImage image=renderer.renderImage(page-1,scale);
                    ImageIO.write(image,"png",path(imagePath).toFile());
                }
                boolean assetExists=repo.all("question_assets",Asset.class).stream().anyMatch(a->a.sourceId().equals(sourceId) && a.path().equals(imagePath));
                if(!assetExists) {
                    BufferedImage image=ImageIO.read(path(imagePath).toFile()); Asset asset=new Asset(id(),sourceId,page,imagePath,0,0,image.getWidth(),image.getHeight());
                    repo.insert("question_assets",asset.id(),asset,Map.of("source_id",sourceId));
                }
                stripper.setStartPage(page); stripper.setEndPage(page); String text=stripper.getText(document);
                if(text.strip().length()<20) { issues.add("Trang "+page+": cần OCR hoặc tạo câu hỏi thủ công từ ảnh."); continue; }
                textPages++;
                Pattern starts=Pattern.compile("(?m)^\\s*(?:Câu|Cau|Question)\\s+\\d+[.:)]\\s*",Pattern.CASE_INSENSITIVE|Pattern.UNICODE_CASE);
                Matcher m=starts.matcher(text); List<Integer> start=new ArrayList<>(); List<Integer> body=new ArrayList<>();
                while(m.find()) { start.add(m.start()); body.add(m.end()); }
                if(start.isEmpty()) issues.add("Trang "+page+": chưa nhận diện ranh giới câu; cần duyệt thủ công.");
                for(int i=0;i<start.size();i++) {
                    String block=text.substring(body.get(i),i+1<start.size()?start.get(i+1):text.length()).strip();
                    List<Choice> choices=new ArrayList<>(); Matcher c=Pattern.compile("(?m)(?:^|\\s)([A-D])[.)]\\s+").matcher(block);
                    List<Integer> cs=new ArrayList<>(),ce=new ArrayList<>(); List<String> keys=new ArrayList<>();
                    while(c.find()) { cs.add(c.start()); ce.add(c.end()); keys.add(c.group(1)); }
                    for(int j=0;j<cs.size();j++) choices.add(new Choice(keys.get(j),block.substring(ce.get(j),j+1<cs.size()?cs.get(j+1):block.length()).strip()));
                    String stem=cs.isEmpty()?block:block.substring(0,cs.get(0)).strip();
                    String fingerprint=fingerprint(block);
                    int currentPage=page;
                    if(repo.all("questions",Question.class).stream().anyMatch(q->q.sourceId().equals(sourceId)&&q.sourcePage()==currentPage&&q.fingerprint().equals(fingerprint))) continue;
                    Question q=new Question(id(),sourceId,page,s.examType(),s.examVersion(),"","","","","MEDIUM","",choices.isEmpty()?"SHORT":"MCQ",stem,choices,"",List.of(),"",List.of(),null,"NEEDS_REVIEW",fingerprint);
                    saveQuestion(q);
                }
            }
            if(textPages==0) status="NEEDS_OCR";
            issues.add("Tất cả câu cần kiểm tra đáp án, phân loại, ngữ cảnh và cắt ảnh không chứa lời giải trước khi duyệt.");
        } catch(Exception e) { status="FAILED"; issues.add("Không hoàn tất xử lý PDF: "+e.getClass().getSimpleName()); }
        Source updated=new Source(s.id(),s.logicalKey(),s.relativePath(),s.examType(),s.examVersion(),s.checksum(),s.revision(),s.active(),status,s.pages(),s.createdAt()); repo.update("pdf_sources",s.id(),updated);
        Job job=new Job(jobId,sourceId,status,List.copyOf(issues),now()); repo.update("processing_jobs",jobId,job); return job;
    }
    @Transactional
    public Asset crop(String sourceId,int page,int x,int y,int width,int height) throws IOException {
        Source source=source(sourceId);
        if(page<1||page>source.pages()) throw ExamException.bad("Trang nguồn không hợp lệ.");
        Path imagePath=path(source.checksum()+"/page-"+page+".png");
        if(!Files.exists(imagePath)) throw ExamException.bad("Hãy xử lý PDF để tạo ảnh trang trước.");
        BufferedImage image=ImageIO.read(imagePath.toFile());
        if(x<0||y<0||width<10||height<10||x+width>image.getWidth()||y+height>image.getHeight()) throw ExamException.bad("Vùng cắt nằm ngoài trang hoặc quá nhỏ.");
        String id=id(), target=source.checksum()+"/crop-"+id+".png";
        ImageIO.write(image.getSubimage(x,y,width,height),"png",path(target).toFile());
        Asset asset=new Asset(id,sourceId,page,target,x,y,width,height); repo.insert("question_assets",id,asset,Map.of("source_id",sourceId)); return asset;
    }
    public List<Asset> assets(String sourceId) { source(sourceId); return repo.all("question_assets",Asset.class).stream().filter(a->a.sourceId().equals(sourceId)).toList(); }
    public Asset asset(String id) { return repo.require("question_assets",id,Asset.class); }
    public static String fingerprint(String text) { return ExamAuth.digest(Normalizer.normalize(text,Normalizer.Form.NFKC).toLowerCase(Locale.ROOT).replaceAll("\\s+"," ").strip().getBytes(java.nio.charset.StandardCharsets.UTF_8)); }
    public static void required(String value,String label) { if(value==null||value.isBlank()||value.length()>1000) throw ExamException.bad(label+" bắt buộc, tối đa 1000 ký tự."); }
    @Transactional
    public Group group(Group input) {
        source(input.sourceId()); required(input.section(),"Phần thi");
        if((input.content()==null||input.content().isBlank()) && (input.assets()==null||input.assets().isEmpty())) throw ExamException.bad("Nhóm cần ngữ cảnh dùng chung.");
        checkAssets(input.sourceId(),input.assets());
        Group g=new Group(id(),input.sourceId(),input.section(),input.content(),input.assets()==null?List.of():input.assets()); repo.insert("question_groups",g.id(),g,Map.of("source_id",g.sourceId())); return g;
    }
    private void checkAssets(String sourceId,List<String> ids) {
        if(ids==null) return;
        for(String id:ids) { Asset a=asset(id); if(!a.sourceId().equals(sourceId)||!a.path().contains("/crop-")) throw ExamException.bad("Phải dùng ảnh cắt từ đúng PDF nguồn."); }
    }
    @Transactional
    public Question edit(String questionId,Question input) {
        if(questionId!=null) {
            Question old=repo.require("questions",questionId,Question.class);
            if(old.status().equals("APPROVED")) throw ExamException.conflict("Câu đã duyệt là bất biến; tạo bản mới để hiệu chỉnh.");
            if(!old.sourceId().equals(input.sourceId())) throw ExamException.bad("Không đổi nguồn của câu hỏi.");
        }
        Source s=source(input.sourceId());
        if(input.sourcePage()<1||input.sourcePage()>s.pages()) throw ExamException.bad("Trang nguồn không hợp lệ.");
        if(input.type()==null||!Set.of("MCQ","SHORT").contains(input.type())) throw ExamException.bad("Loại câu MCQ hoặc SHORT.");
        if(input.stem()==null||input.stem().isBlank()) throw ExamException.bad("Nội dung câu bắt buộc.");
        if(input.difficulty()==null||!Set.of("EASY","MEDIUM","HARD").contains(input.difficulty())) throw ExamException.bad("Độ khó không hợp lệ.");
        checkAssets(s.id(),input.assets());
        checkAssets(s.id(),input.solutionAssets());
        String groupId=input.groupId()==null||input.groupId().isBlank()?null:input.groupId();
        if(groupId!=null) {
            Group g=repo.require("question_groups",groupId,Group.class);
            if(!g.sourceId().equals(s.id())||!g.section().equals(input.section())) throw ExamException.bad("Ngữ cảnh phải cùng nguồn và phần thi.");
        }
        List<Choice> choices=input.choices()==null?List.of():List.copyOf(input.choices());
        String canonical=input.stem()+" "+choices.stream().map(Choice::text).reduce("",(a,b)->a+" "+b);
        Question q=new Question(questionId==null?id():questionId,s.id(),input.sourcePage(),s.examType(),s.examVersion(),input.section(),input.subsection(),input.topic(),input.skill(),input.difficulty(),input.cognitiveLevel(),input.type(),input.stem(),choices,input.answer(),input.acceptedAnswers()==null?List.of():input.acceptedAnswers(),input.solution(),input.assets()==null?List.of():input.assets(),groupId,"NEEDS_REVIEW",fingerprint(canonical),input.solutionAssets());
        if(questionId==null) saveQuestion(q); else { repo.update("questions",q.id(),q); repo.jdbc().update("UPDATE exam_platform.questions SET group_id=?,fingerprint=? WHERE id=?",q.groupId(),q.fingerprint(),q.id()); }
        return q;
    }
    private void saveQuestion(Question q) {
        Map<String,Object> cols=new HashMap<>(); cols.put("source_id",q.sourceId()); cols.put("group_id",q.groupId()); cols.put("status",q.status()); cols.put("fingerprint",q.fingerprint()); repo.insert("questions",q.id(),q,cols);
    }
    @Transactional
    public Question approve(String id,Account reviewer,boolean visualVerified,boolean answerFree) {
        Question q=repo.require("questions",id,Question.class);
        if(q.status().equals("APPROVED")) return q;
        if(!visualVerified||!answerFree) throw ExamException.bad("Xác nhận đã soát hình/công thức/ngữ cảnh và vùng cắt không chứa đáp án.");
        if(!source(q.sourceId()).active()) throw ExamException.bad("Nguồn đã bị vô hiệu hóa.");
        required(q.section(),"Phần thi"); required(q.topic(),"Chuyên đề"); required(q.skill(),"Kỹ năng"); required(q.cognitiveLevel(),"Mức nhận thức"); required(q.answer(),"Đáp án");
        if(q.assets().isEmpty()) throw ExamException.bad("Cần ảnh cắt câu hỏi để giữ hình, công thức và bảng.");
        if(q.type().equals("MCQ")) {
            if(!q.acceptedAnswers().isEmpty()) throw ExamException.bad("MCQ chỉ có một phương án đúng; đáp án tương đương chỉ dành cho điền đáp án.");
            Set<String> keys=new HashSet<>();
            if(q.choices().size()!=4) throw ExamException.bad("MCQ cần 4 phương án A–D.");
            for(Choice c:q.choices()) { if(c.text()==null||c.text().isBlank()||!Set.of("A","B","C","D").contains(c.key())||!keys.add(c.key())) throw ExamException.bad("Phương án không hợp lệ."); }
            if(!keys.contains(q.answer())) throw ExamException.bad("Đáp án phải là một phương án.");
        }
        Question approved=new Question(q.id(),q.sourceId(),q.sourcePage(),q.examType(),q.examVersion(),q.section(),q.subsection(),q.topic(),q.skill(),q.difficulty(),q.cognitiveLevel(),q.type(),q.stem(),q.choices(),q.answer(),q.acceptedAnswers(),q.solution(),q.assets(),q.groupId(),"APPROVED",q.fingerprint(),q.solutionAssets());
        repo.update("questions",id,approved); repo.jdbc().update("UPDATE exam_platform.questions SET status='APPROVED' WHERE id=?",id);
        repo.insert("question_reviews",ExamRepository.id(),Map.of("reviewer",reviewer.id(),"at",now(),"visualVerified",true,"answerFree",true),Map.of("question_id",id,"reviewer_id",reviewer.id())); return approved;
    }
    public List<Question> bank() {
        Set<String> active=new HashSet<>(); repo.all("pdf_sources",Source.class).stream().filter(Source::active).forEach(s->active.add(s.id()));
        return repo.all("questions",Question.class).stream().filter(q->q.status().equals("APPROVED")&&active.contains(q.sourceId())).toList();
    }
}
