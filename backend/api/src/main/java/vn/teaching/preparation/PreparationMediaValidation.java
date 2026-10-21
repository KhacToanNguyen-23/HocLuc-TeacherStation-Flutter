package vn.teaching.preparation;

import com.google.gson.*;
import vn.teaching.exam.ExamException;
import java.io.*;
import java.nio.*;
import java.nio.charset.*;
import java.nio.file.*;
import java.util.*;

final class PreparationMediaValidation {
    static void check(Path file,String mime)throws IOException{
        byte[] head;try(InputStream input=Files.newInputStream(file)){head=input.readNBytes(1024);}
        boolean valid=switch(mime){
            case "application/pdf"->starts(head,"%PDF-".getBytes(StandardCharsets.US_ASCII));
            case "image/png"->starts(head,new byte[]{(byte)137,80,78,71,13,10,26,10});
            case "image/jpeg"->starts(head,new byte[]{(byte)255,(byte)216,(byte)255});
            case "audio/wav"->head.length>=12&&ascii(head,0,4).equals("RIFF")&&ascii(head,8,4).equals("WAVE");
            case "video/mp4"->head.length>=12&&ascii(head,4,4).equals("ftyp");
            case "audio/mpeg"->starts(head,"ID3".getBytes(StandardCharsets.US_ASCII))||(head.length>=2&&(head[0]&255)==255&&(head[1]&224)==224);
            case "text/plain"->validText(file);
            default->false;
        };
        if(!valid)throw ExamException.bad("Nội dung file không khớp định dạng đã chọn, hoặc file hỏng. Hãy chọn lại nguồn.");
    }
    static boolean validText(Path file)throws IOException{
        if(Files.size(file)>1_000_000)throw ExamException.bad("Script TXT/Markdown tối đa 1 MB.");
        try{String text=StandardCharsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(Files.readAllBytes(file))).toString();return !text.contains("\u0000");}
        catch(CharacterCodingException e){return false;}
    }
    static void quota(PreparationStore store,String plan,String owner,long incoming,boolean source)throws IOException{
        synchronized(store){JsonObject state=store.state(plan,owner);long used=0;
            for(String group:List.of("sources","artifacts"))for(JsonElement row:state.getAsJsonArray(group))used+=row.getAsJsonObject().get("size").getAsLong();
            if(source&&state.getAsJsonArray("sources").size()>=100||used+incoming>1_000_000_000L)throw ExamException.bad("Bài tối đa 100 nguồn và 1 GB học liệu. Xóa nguồn chưa dùng hoặc tạo bài khác.");
            if(Files.getFileStore(store.root).getUsableSpace()<incoming*2+100_000_000L)throw ExamException.bad("Không đủ dung lượng lưu nguồn; cần vùng an toàn 100 MB.");
        }
    }
    static boolean starts(byte[] input,byte[] prefix){if(input.length<prefix.length)return false;for(int i=0;i<prefix.length;i++)if(input[i]!=prefix[i])return false;return true;}
    static String ascii(byte[] bytes,int start,int length){return new String(bytes,start,length,StandardCharsets.US_ASCII);}
}
