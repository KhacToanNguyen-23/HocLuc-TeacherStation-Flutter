package vn.teaching.service;

import com.google.gson.Gson;
import com.google.gson.JsonParser;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import java.net.InetSocketAddress;
import java.net.URI;
import java.net.http.HttpClient;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.concurrent.atomic.AtomicInteger;
import static org.junit.jupiter.api.Assertions.*;

class GoogleMeetServiceTest {
    @TempDir Path data;
    private HttpServer provider;
    private GoogleMeetService meet;
    private final AtomicInteger creates = new AtomicInteger();
    private int httpStatus = 200;
    private String response = "{\"name\":\"spaces/test-space\",\"meetingUri\":\"https://meet.google.com/abc-defg-hij\",\"config\":{\"accessType\":\"OPEN\"}}";

    @BeforeEach
    void setup() throws Exception {
        provider = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        provider.createContext("/v2/spaces", request -> {
            creates.incrementAndGet();
            assertEquals("POST", request.getRequestMethod());
            assertEquals("Bearer test-google-token", request.getRequestHeaders().getFirst("Authorization"));
            var config = JsonParser.parseString(new String(request.getRequestBody().readAllBytes(), StandardCharsets.UTF_8)).getAsJsonObject().getAsJsonObject("config");
            assertEquals("OPEN", config.get("accessType").getAsString());
            assertEquals("ALL", config.get("entryPointAccess").getAsString());
            byte[] body = response.getBytes(StandardCharsets.UTF_8);
            request.sendResponseHeaders(httpStatus, body.length);
            try (var output = request.getResponseBody()) { output.write(body); }
        });
        provider.start();
        meet = new GoogleMeetService(HttpClient.newHttpClient(), URI.create("http://127.0.0.1:" + provider.getAddress().getPort() + "/v2/spaces"));
    }

    @AfterEach void close() { provider.stop(0); }

    @Test
    void persistsTheExactOpenSpaceAndDoesNotDuplicateItWhenLobbySyncs() {
        var classrooms = new ClassroomService(data, new Gson(), meet);
        var room = classrooms.createClassroom(null, "test-google-token", "Toán 12", "teacher-id");
        assertTrue(room.isSuccess());
        assertEquals("OPEN", room.getAccessType());
        assertEquals("spaces/test-space", room.getSpaceName());
        assertEquals("https://meet.google.com/abc-defg-hij", room.getMeetingUrl());
        var synced = classrooms.createClassroom(room.getMeetingUrl(), null, "Toán 12", "teacher-id");
        assertEquals(room.getId(), synced.getId());
        assertEquals("OPEN", synced.getAccessType());
        assertEquals(1, creates.get());
    }

    @Test
    void restrictedOrMissingAccessConfirmationNeverPersistsAnOpenRoom() {
        var classrooms = new ClassroomService(data, new Gson(), meet);
        response = response.replace("OPEN", "RESTRICTED");
        assertFalse(classrooms.createClassroom(null, "test-google-token", null).isSuccess());
        assertEquals(0, classrooms.getActiveClassroom().size());
        response = "{\"meetingUri\":\"https://meet.google.com/abc-defg-hij\"}";
        assertThrows(IllegalStateException.class, () -> meet.createOpenSpace("test-google-token"));
    }

    @Test
    void rejectsPlaceholderTokensAndUntrustedMeetingUris() {
        assertThrows(IllegalStateException.class, () -> meet.createOpenSpace("webview2_authenticated_google_session"));
        assertThrows(IllegalStateException.class, () -> meet.createOpenSpace("demo_google_access_token"));
        assertEquals(0, creates.get());
        response = response.replace("https://meet.google.com/abc-defg-hij", "https://example.com/abc-defg-hij");
        assertThrows(IllegalStateException.class, () -> meet.createOpenSpace("test-google-token"));
    }

    @Test
    void authFailureRequiresReconnectAndPolicyFailureNeverFallsBack() {
        var classrooms = new ClassroomService(data, new Gson(), meet);
        httpStatus = 401;
        var expired = classrooms.createClassroom(null, "test-google-token", null);
        assertFalse(expired.isSuccess());
        assertTrue(expired.isRequiresGoogleReconnect());
        httpStatus = 403;
        var blocked = classrooms.createClassroom(null, "test-google-token", null);
        assertFalse(blocked.isSuccess());
        assertFalse(blocked.isRequiresGoogleReconnect());
        assertEquals(0, classrooms.getActiveClassroom().size());
    }

    @Test
    void pastedMeetLinksDoNotClaimVerifiedOpenAccess() {
        var classrooms = new ClassroomService(data, new Gson(), meet);
        var pasted = classrooms.createClassroom("https://meet.google.com/xyz-abcd-efg", null, null);
        assertTrue(pasted.isSuccess());
        assertNull(pasted.getAccessType());
        assertEquals(0, creates.get());
    }
}
