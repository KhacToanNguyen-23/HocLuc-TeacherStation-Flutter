package vn.teaching.preparation;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import java.nio.file.*;
import java.net.http.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
class PreparationDriveTest {
    @TempDir Path dir;
    @SuppressWarnings("unchecked")
    @Test void resumesKnownSessionAtRemoteOffsetAndJournalsCompletedId()throws Exception{
        Path file=dir.resolve("movie");Files.write(file,new byte[8]);Files.writeString(dir.resolve("drive-upload-req-1.json"),"{\"session\":\"https://www.googleapis.com/upload/drive/v3/files?upload_id=known\"}");
        HttpClient client=mock(HttpClient.class);HttpResponse<String> status=mock(HttpResponse.class),done=mock(HttpResponse.class);
        when(status.statusCode()).thenReturn(308);when(status.headers()).thenReturn(HttpHeaders.of(Map.of("Range",List.of("bytes=0-3")),(a,b)->true));
        when(done.statusCode()).thenReturn(200);when(done.body()).thenReturn("{\"id\":\"drive-id\"}");
        when(client.send(any(HttpRequest.class),any(HttpResponse.BodyHandler.class))).thenReturn(status,done);
        PreparationDrive drive=new PreparationDrive(client);assertEquals("drive-id",drive.upload("token",file,"video.mp4","video/mp4","req-1"));
        var requests=org.mockito.ArgumentCaptor.forClass(HttpRequest.class);verify(client,times(2)).send(requests.capture(),any(HttpResponse.BodyHandler.class));
        assertEquals("bytes */8",requests.getAllValues().get(0).headers().firstValue("Content-Range").orElseThrow());assertEquals("bytes 4-7/8",requests.getAllValues().get(1).headers().firstValue("Content-Range").orElseThrow());
        assertEquals("drive-id",drive.upload("token",file,"video.mp4","video/mp4","req-1"));verifyNoMoreInteractions(client);assertFalse(Files.readString(dir.resolve("drive-upload-req-1.json")).contains("session"));
    }
    @Test void rejectsForeignUploadSession(){PreparationDrive drive=new PreparationDrive(mock(HttpClient.class));assertThrows(IllegalStateException.class,()->drive.checkedSession("https://example.org/upload"));}
}
