package vn.teaching.preparation;

import com.google.gson.*;
import vn.teaching.exam.ExamException;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.TimeUnit;

/** Main windows exposed by Windows, identified by handle rather than ambiguous title. */
final class PreparationCaptureSources {
    static List<JsonObject> windows(Path temporaryRoot) throws Exception {
        if (!System.getProperty("os.name").toLowerCase(Locale.ROOT).contains("win")) return List.of();
        String script = "[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new(); "
            + "@(Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle } | "
            + "ForEach-Object { @{source=('hwnd='+$_.MainWindowHandle.ToInt64()); title=$_.MainWindowTitle} }) | ConvertTo-Json -Compress";
        String encoded = Base64.getEncoder().encodeToString(script.getBytes(StandardCharsets.UTF_16LE));
        Path output = Files.createTempFile(temporaryRoot,"windows-",".json");
        try {
            Path shell = Path.of(System.getenv().getOrDefault("SystemRoot","C:/Windows"),"System32","WindowsPowerShell","v1.0","powershell.exe");
            Process process = new ProcessBuilder(shell.toString(),"-NoProfile","-NonInteractive","-WindowStyle","Hidden","-EncodedCommand",encoded)
                .redirectErrorStream(true).redirectOutput(output.toFile()).start();
            if (!process.waitFor(8,TimeUnit.SECONDS)) { process.destroyForcibly(); throw ExamException.bad("Chưa đọc được cửa sổ. Thử kiểm tra lại."); }
            if (process.exitValue()!=0 || Files.size(output)>1_000_000) throw ExamException.bad("Không đọc được danh sách cửa sổ.");
            String raw=Files.readString(output,StandardCharsets.UTF_8).replace("\uFEFF","").trim();
            if(raw.isEmpty())return List.of();
            JsonElement parsed=JsonParser.parseString(raw);JsonArray rows=parsed.isJsonArray()?parsed.getAsJsonArray():new JsonArray();
            if(parsed.isJsonObject())rows.add(parsed);
            List<JsonObject> windows=new ArrayList<>();
            for(JsonElement row:rows)if(row.isJsonObject()){
                JsonObject value=row.getAsJsonObject();String source=PreparationStore.str(value,"source"),title=PreparationStore.str(value,"title");
                if(source.matches("hwnd=[1-9][0-9]{0,18}")&&!title.isBlank())windows.add(value);
            }
            return windows;
        } finally {Files.deleteIfExists(output);}
    }

    static String resolve(String selected,String confirmedTitle,List<JsonObject> windows) {
        if(selected.equals("desktop"))return selected;
        if(!selected.matches("hwnd=[1-9][0-9]{0,18}"))throw ExamException.bad("Chọn nguồn trong danh sách cửa sổ.");
        for(JsonObject window:windows)if(PreparationStore.str(window,"source").equals(selected)){
            if(confirmedTitle.isBlank()||!PreparationStore.str(window,"title").equals(confirmedTitle))
                throw ExamException.conflict("Cửa sổ đã thay đổi. Chọn và xác nhận lại nguồn.");
            return selected;
        }
        throw ExamException.bad("Cửa sổ đã đóng hoặc không còn khả dụng. Chọn lại nguồn.");
    }
}
