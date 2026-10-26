package vn.teaching.modules.tutor;

import com.sun.net.httpserver.HttpServer;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.junit.jupiter.api.*;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import vn.teaching.config.SecurityTokenInterceptor;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicInteger;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class TutorControllerTest {
    HttpServer provider;
    MockMvc mvc;
    volatile String response;
    volatile int status;
    volatile String received;
    volatile String authorization;
    AtomicInteger calls;
    static final String QUOTE = "Water freezes at zero degrees Celsius.";
    @BeforeEach void setup() throws Exception {
        status = 200; calls = new AtomicInteger();
        provider = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        provider.createContext("/v1/chat/completions", exchange -> {
            calls.incrementAndGet();
            received = new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
            authorization = exchange.getRequestHeaders().getFirst("Authorization");
            exchange.getResponseHeaders().set("Location", "/redirect-target");
            byte[] bytes = response.getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(status, bytes.length);
            try (var out = exchange.getResponseBody()) { out.write(bytes); }
        });
        provider.start();
        mvc = MockMvcBuilders.standaloneSetup(new TutorController(new TutorService()))
                .addInterceptors(new SecurityTokenInterceptor("local-token")).build();
        completion("{\"answer\":\"" + QUOTE + "\",\"sources\":[{\"id\":\"p1\",\"quote\":\"" + QUOTE + "\"}]}");
    }
    @AfterEach void close() { provider.stop(0); }
    void completion(String content) throws Exception {
        response = TutorService.JSON.writeValueAsString(java.util.Map.of("choices", java.util.List.of(
                java.util.Map.of("finish_reason", "stop", "message", java.util.Map.of("content", content)))));
    }
    ObjectNode input() {
        var node = TutorService.JSON.createObjectNode();
        node.putObject("config").put("baseUrl", "http://127.0.0.1:" + provider.getAddress().getPort() + "/v1")
                .put("apiKey", "secret-test-key").put("model", "mock-model");
        node.put("question", "When does water freeze?").put("currentPage", 1);
        node.putArray("sources").addObject().put("id", "p1").put("label", "Page 1").put("text", QUOTE);
        return node;
    }
    org.springframework.test.web.servlet.ResultActions send(String path, String body) throws Exception {
        return mvc.perform(post("/api/tutor/" + path).header("X-Companion-Token", "local-token")
                .contentType("application/json").content(body));
    }
    MockEnvironment environment() {
        return new MockEnvironment()
                .withProperty("HOCLUC_TUTOR_BASE_URL", "http://127.0.0.1:" + provider.getAddress().getPort() + "/v1")
                .withProperty("HOCLUC_TUTOR_MODEL", "env-model")
                .withProperty("HOCLUC_TUTOR_API_KEY", "env-secret-key");
    }
    void useEnvironment(MockEnvironment env) {
        mvc = MockMvcBuilders.standaloneSetup(new TutorController(new TutorService(env)))
                .addInterceptors(new SecurityTokenInterceptor("local-token")).build();
    }
    @Test void environmentRequestsUseBackendKeyForAnswerAndTestWithoutClientKey() throws Exception {
        useEnvironment(environment());
        var body = input(); body.putObject("config").put("useEnvironment", true);
        send("answer", body.toString()).andExpect(jsonPath("$.status").value("answered"));
        assertEquals("Bearer env-secret-key", authorization);
        assertEquals("env-model", TutorService.JSON.readTree(received).path("model").asText());
        assertFalse(received.contains("env-secret-key"));
        completion("OK");
        send("test", "{\"config\":{\"useEnvironment\":true}}")
                .andExpect(jsonPath("$.success").value(true));
    }
    @Test void environmentCannotBeMixedWithClientDestinationAndManualConfigNeverBorrowsItsKey() throws Exception {
        useEnvironment(environment());
        var mixed = input(); ((ObjectNode) mixed.get("config")).put("useEnvironment", true);
        send("answer", mixed.toString()).andExpect(status().isBadRequest());
        assertEquals(0, calls.get());
        var manual = input(); ((ObjectNode) manual.get("config")).put("apiKey", "");
        send("answer", manual.toString()).andExpect(jsonPath("$.status").value("answered"));
        assertNull(authorization);
    }
    @Test void missingInvalidOrKeylessEnvironmentIsHandledWithoutLeakingValues() throws Exception {
        var body = input(); body.putObject("config").put("useEnvironment", true);
        useEnvironment(new MockEnvironment());
        send("answer", body.toString()).andExpect(status().isBadRequest());
        useEnvironment(environment().withProperty("HOCLUC_TUTOR_BASE_URL", "http://unsafe.test/v1"));
        var invalid = send("answer", body.toString()).andExpect(status().isBadRequest()).andReturn();
        assertFalse(invalid.getResponse().getContentAsString().contains("env-secret-key"));
        assertEquals(0, calls.get());
        useEnvironment(environment().withProperty("HOCLUC_TUTOR_API_KEY", ""));
        send("answer", body.toString()).andExpect(jsonPath("$.status").value("answered"));
        assertNull(authorization);
    }
    @Test void groundedCompletionAndRequestContract() throws Exception {
        send("answer", input().toString()).andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("answered")).andExpect(jsonPath("$.answer").value(QUOTE))
                .andExpect(jsonPath("$.sources[0].id").value("p1")).andExpect(jsonPath("$.reason").value(""));
        assertEquals("Bearer secret-test-key", authorization);
        var body = TutorService.JSON.readTree(received);
        assertEquals("mock-model", body.path("model").asText());
        assertFalse(body.path("stream").asBoolean());
        assertFalse(received.contains("secret-test-key"));
        assertEquals(1, calls.get());
    }
    @Test void unrelatedQuestionProducesCanonicalReplyAndReceivesLessonSubject() throws Exception {
        var input = input(); input.put("lessonSubject", "Mathematics").put("question", "What should I eat today?");
        completion("{\"answer\":\"arbitrary unrelated advice\",\"sources\":[],\"confidence\":\"low\",\"scope\":\"out_of_scope\"}");
        send("answer", input.toString()).andExpect(jsonPath("$.status").value("out_of_scope"))
                .andExpect(jsonPath("$.answer").value("Không thuộc phạm vi bài giảng."))
                .andExpect(jsonPath("$.sources").isEmpty());
        var messages = TutorService.JSON.readTree(received).path("messages");
        assertEquals("Mathematics", TutorService.JSON.readTree(messages.get(1).path("content").asText()).path("lessonSubject").asText());
    }
    @Test void newScopeSchemaAcceptsInScopeLowAndRejectsInvalidScope() throws Exception {
        completion("{\"answer\":\"It may mean the shape has three sides.\",\"sources\":[],\"confidence\":\"low\",\"scope\":\"in_scope\"}");
        send("answer", input().toString()).andExpect(jsonPath("$.status").value("tentative"));
        completion("{\"answer\":\"Invalid.\",\"sources\":[],\"confidence\":\"low\",\"scope\":\"anything\"}");
        send("answer", input().toString()).andExpect(jsonPath("$.status").value("review"));
    }
    @Test void testRequiresActualSmallCompletion() throws Exception {
        var input = input(); input.remove(java.util.List.of("question", "currentPage", "sources"));
        completion("OK");
        send("test", input.toString()).andExpect(status().isOk()).andExpect(content().json("{\"success\":true}"));
        assertEquals(8, TutorService.JSON.readTree(received).path("max_tokens").asInt());
        completion("not OK");
        send("test", input.toString()).andExpect(status().isBadGateway()).andExpect(jsonPath("$.success").value(false));
        assertEquals(2, calls.get());
    }
    @Test void emptyKeyOmitsAuthorizationForLocalProvider() throws Exception {
        var input = input(); ((ObjectNode) input.get("config")).put("apiKey", "");
        send("answer", input.toString()).andExpect(jsonPath("$.status").value("answered"));
        assertNull(authorization);
        input.remove(java.util.List.of("question", "currentPage", "sources"));
        completion("OK");
        send("test", input.toString()).andExpect(status().isOk()).andExpect(jsonPath("$.success").value(true));
        assertNull(authorization);
    }
    @Test void noSourcesCallsProviderForExplicitlyTentativeAnswer() throws Exception {
        var input = input(); input.putArray("sources");
        completion("{\"answer\":\"At normal pressure it may be around zero degrees Celsius.\",\"sources\":[],\"confidence\":\"low\"}");
        send("answer", input.toString()).andExpect(jsonPath("$.status").value("tentative"))
                .andExpect(jsonPath("$.confidence").value("low"));
        assertEquals(1, calls.get());
    }
    @Test void tentativeExplanationMayUseVerifiedEvidenceWithoutMatchingQuote() throws Exception {
        completion("{\"answer\":\"This probably refers to ordinary atmospheric pressure.\",\"sources\":[{\"id\":\"p1\",\"quote\":\""+QUOTE+"\"}],\"confidence\":\"low\"}");
        send("answer", input().toString()).andExpect(jsonPath("$.status").value("tentative"))
                .andExpect(jsonPath("$.confidence").value("low"));
    }
    @Test void lowConfidenceCannotBypassCitationAndSchemaValidation() throws Exception {
        for (String content : java.util.List.of(
                "{\"answer\":\"Maybe.\",\"sources\":[{\"id\":\"fake\",\"quote\":\"Invented quote.\"}],\"confidence\":\"low\"}",
                "{\"answer\":\"Maybe.\",\"sources\":[],\"confidence\":0.2}",
                "{\"answer\":\"Maybe.\",\"sources\":[],\"confidence\":\"unknown\"}",
                "{\"answer\":\"\",\"sources\":[],\"confidence\":\"low\"}",
                "{\"answer\":\""+"x".repeat(1201)+"\",\"sources\":[],\"confidence\":\"low\"}")) {
            completion(content);
            send("answer", input().toString()).andExpect(jsonPath("$.status").value("review"))
                    .andExpect(jsonPath("$.answer").value(""));
        }
    }
    @Test void highConfidenceStillRequiresExactEvidenceEvenWithNoSources() throws Exception {
        completion("{\"answer\":\"Maybe.\",\"sources\":[],\"confidence\":\"high\"}");
        var input = input(); input.putArray("sources");
        send("answer", input.toString()).andExpect(jsonPath("$.status").value("review"));
    }
    @Test void invalidEvidenceFailsClosed() throws Exception {
        for (String content : java.util.List.of(
                "{\"answer\":\"Invented.\",\"sources\":[]}",
                "{\"answer\":\""+QUOTE+"\",\"sources\":[{\"id\":\"wrong\",\"quote\":\""+QUOTE+"\"}]}",
                "{\"answer\":\"Paraphrase\",\"sources\":[{\"id\":\"p1\",\"quote\":\""+QUOTE+"\"}]}",
                "{\"answer\":\"freezes at zero degrees Celsius.\",\"sources\":[{\"id\":\"p1\",\"quote\":\"freezes at zero degrees Celsius.\"}]}",
                "{\"answer\":\"\",\"sources\":[]}", "not JSON")) {
            completion(content);
            send("answer", input().toString()).andExpect(jsonPath("$.status").value("review"))
                    .andExpect(jsonPath("$.answer").value("")).andExpect(jsonPath("$.sources").isEmpty());
        }
    }
    @Test void duplicateCitationsAndDuplicateSourceIdsRejected() throws Exception {
        String evidence = "{\"id\":\"p1\",\"quote\":\""+QUOTE+"\"}";
        completion("{\"answer\":\""+QUOTE+"\\n"+QUOTE+"\",\"sources\":["+evidence+","+evidence+"]}");
        send("answer", input().toString()).andExpect(jsonPath("$.status").value("review"));
        var input = input(); ((com.fasterxml.jackson.databind.node.ArrayNode)input.get("sources")).add(input.get("sources").get(0));
        send("answer", input.toString()).andExpect(status().isBadRequest());
    }
    @Test void rejectsUnsafeUrlsAndInvalidConfigBeforeNetwork() throws Exception {
        for (String url : java.util.List.of("http://example.com/v1", "file:///tmp/x", "http://localhost/v1",
                "https://user:pass@example.com", "https://example.com?key=secret", "https://example.com/#fragment")) {
            var input = input(); ((ObjectNode)input.get("config")).put("baseUrl", url);
            send("answer", input.toString()).andExpect(status().isBadRequest());
        }
        var input = input(); ((ObjectNode)input.get("config")).put("apiKey", "secret\r\nInjected: yes");
        send("answer", input.toString()).andExpect(status().isBadRequest());
        assertEquals(0, calls.get());
    }
    @Test void boundedInputAndMalformedJson() throws Exception {
        var input = input(); input.put("question", "x".repeat(2001));
        send("answer", input.toString()).andExpect(status().isBadRequest());
        input = input(); ((ObjectNode)input.get("sources").get(0)).put("text", "x".repeat(3001));
        send("answer", input.toString()).andExpect(status().isBadRequest());
        input = input(); for (int i=0;i<6;i++) ((com.fasterxml.jackson.databind.node.ArrayNode)input.get("sources"))
                .addObject().put("id", "extra"+i).put("label", "p").put("text", QUOTE);
        send("answer", input.toString()).andExpect(status().isBadRequest());
        send("answer", " ".repeat(65_537)).andExpect(status().isBadRequest());
        send("answer", "{\"config\":{},\"config\":{}}").andExpect(status().isBadRequest());
        send("answer", input()+" {}").andExpect(status().isBadRequest());
        assertEquals(0, calls.get());
    }
    @Test void remoteErrorsRedirectsAndLargeResponsesAreSanitized() throws Exception {
        for (int code : new int[]{401, 429, 500, 302, 307}) {
            status = code; response = "secret-test-key remote internal error";
            var result = send("answer", input().toString()).andExpect(jsonPath("$.status").value("review")).andReturn();
            assertFalse(result.getResponse().getContentAsString().contains("secret"));
        }
        assertEquals(5, calls.get());
        status = 200; response = "x".repeat(40_000);
        send("answer", input().toString()).andExpect(jsonPath("$.status").value("review"));
    }
    @Test void providerBodyDeadlineUnderTwentySeconds() throws Exception {
        provider.createContext("/slow/chat/completions", exchange -> {
            exchange.sendResponseHeaders(200, 0);
            try (var out = exchange.getResponseBody()) {
                out.write('{'); out.flush();
                try { new java.util.concurrent.CountDownLatch(1).await(14, java.util.concurrent.TimeUnit.SECONDS); }
                catch (InterruptedException e) { Thread.currentThread().interrupt(); }
            } catch (java.io.IOException ignored) { }
        });
        var input = input();
        ((ObjectNode) input.get("config")).put("baseUrl", "http://127.0.0.1:"+provider.getAddress().getPort()+"/slow");
        long start = System.nanoTime();
        send("answer", input.toString()).andExpect(jsonPath("$.status").value("review"))
                .andExpect(jsonPath("$.reason").value("provider_unavailable"));
        long millis = java.util.concurrent.TimeUnit.NANOSECONDS.toMillis(System.nanoTime()-start);
        assertTrue(millis >= 10_000 && millis < 19_000, "provider body deadline: " + millis);
    }
    @Test void remoteSocketRejectedEvenWithToken() throws Exception {
        mvc.perform(post("/api/tutor/answer").with(req -> { req.setRemoteAddr("192.168.1.20"); return req; })
                .header("X-Companion-Token", "local-token").contentType("application/json").content(input().toString()))
                .andExpect(status().isForbidden());
        assertEquals(0, calls.get());
    }
    @Test void outputLimitTruncationAndExtraFieldsFailClosed() throws Exception {
        completion("{\"answer\":\""+"x".repeat(1201)+"\",\"sources\":[]}");
        send("answer", input().toString()).andExpect(jsonPath("$.status").value("review"));
        completion("{\"answer\":\""+QUOTE+"\",\"sources\":[{\"id\":\"p1\",\"quote\":\""+QUOTE+"\"}],\"extra\":true}");
        send("answer", input().toString()).andExpect(jsonPath("$.status").value("review"));
        completion("OK"); response = response.replace("\"stop\"", "\"length\"");
        var input = input(); input.remove(java.util.List.of("question", "currentPage", "sources"));
        send("test", input.toString()).andExpect(status().isBadGateway());
    }
    @Test void rebindingHostRejectedWithMatchingOriginOrNoOrigin() throws Exception {
        for (String route : java.util.List.of("answer", "test")) {
            for (boolean withOrigin : new boolean[]{true, false}) {
                var request = post("/api/tutor/" + route)
                        .header("Host", "evil.example:8080")
                        .header("X-Companion-Token", "local-token")
                        .with(req -> {
                            req.setRemoteAddr("127.0.0.1");
                            req.setServerName("evil.example");
                            req.setServerPort(8080);
                            return req;
                        })
                        .contentType("application/json").content(input().toString());
                if (withOrigin) request.header("Origin", "http://evil.example:8080");
                mvc.perform(request).andExpect(status().isForbidden())
                        .andExpect(jsonPath("$.reason").value("forbidden_origin"));
            }
        }
        assertEquals(0, calls.get());
    }
    @Test void nativeAndSameOriginLoopbackHostsRemainAccepted() throws Exception {
        for (String host : java.util.List.of("127.0.0.1", "localhost", "::1", "[::1]")) {
            for (boolean withOrigin : new boolean[]{true, false}) {
                String authority = host.contains(":") ? "[::1]" : host;
                var request = post("/api/tutor/answer")
                        .header("Host", authority + ":8080")
                        .header("X-Companion-Token", "local-token")
                        .with(req -> {
                            req.setRemoteAddr(host.contains(":") ? "::1" : "127.0.0.1");
                            req.setServerName(host);
                            req.setServerPort(8080);
                            return req;
                        })
                        .contentType("application/json").content(input().toString());
                if (withOrigin) request.header("Origin", "http://" + authority + ":8080");
                mvc.perform(request).andExpect(status().isOk())
                        .andExpect(jsonPath("$.status").value("answered"));
            }
        }
        assertEquals(8, calls.get());
    }
    @Test void authAndBrowserOriginProtection() throws Exception {
        mvc.perform(post("/api/tutor/answer").contentType("application/json").content(input().toString()))
                .andExpect(status().isUnauthorized());
        for (String route : java.util.List.of("answer", "test")) {
            for (String origin : java.util.List.of("https://evil.example", "null", "http://localhost:3000", "http://localhost/path")) {
                mvc.perform(post("/api/tutor/"+route).header("X-Companion-Token", "local-token").header("Origin", origin)
                        .contentType("application/json").content(input().toString())).andExpect(status().isForbidden());
            }
        }
        mvc.perform(post("/api/tutor/answer").header("X-Companion-Token", "local-token").header("Origin", "http://localhost")
                .contentType("application/json").content(input().toString())).andExpect(status().isOk());
        assertEquals(1, calls.get());
    }
}
