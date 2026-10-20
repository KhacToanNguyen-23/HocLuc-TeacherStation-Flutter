package vn.teaching.config;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.mock.http.MockHttpInputMessage;
import org.springframework.web.server.ResponseStatusException;
import vn.teaching.integrations.GoogleFailure;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class GlobalExceptionHandlerTest {
    private GlobalExceptionHandler handler;

    @BeforeEach
    void setUp() {
        handler = new GlobalExceptionHandler();
    }

    @Test
    void testResponseStatusExceptionMapping() {
        ResponseStatusException ex = new ResponseStatusException(HttpStatus.CONFLICT, "Đang có buổi học khác.");
        ResponseEntity<Map<String, Object>> res = handler.handleResponseStatusException(ex);

        assertEquals(HttpStatus.CONFLICT, res.getStatusCode());
        assertNotNull(res.getBody());
        assertEquals(false, res.getBody().get("success"));
        assertEquals(409, res.getBody().get("status"));
        assertEquals("Đang có buổi học khác.", res.getBody().get("message"));
        assertEquals("Đang có buổi học khác.", res.getBody().get("error"));
    }

    @Test
    void testGoogleFailureMapping() {
        GoogleFailure ex = new GoogleFailure(403, "LOCAL_ONLY", "Kết nối chỉ dùng nội bộ.");
        ResponseEntity<Map<String, Object>> res = handler.handleGoogleFailure(ex);

        assertEquals(HttpStatus.FORBIDDEN, res.getStatusCode());
        assertNotNull(res.getBody());
        assertEquals(false, res.getBody().get("success"));
        assertEquals(403, res.getBody().get("status"));
        assertEquals("LOCAL_ONLY", res.getBody().get("code"));
        assertEquals("Kết nối chỉ dùng nội bộ.", res.getBody().get("message"));
    }

    @Test
    void testIllegalArgumentExceptionMapping() {
        IllegalArgumentException ex = new IllegalArgumentException("Tham số không hợp lệ.");
        ResponseEntity<Map<String, Object>> res = handler.handleIllegalArgumentException(ex);

        assertEquals(HttpStatus.BAD_REQUEST, res.getStatusCode());
        assertNotNull(res.getBody());
        assertEquals(false, res.getBody().get("success"));
        assertEquals(400, res.getBody().get("status"));
        assertEquals("Tham số không hợp lệ.", res.getBody().get("message"));
    }

    @Test
    void testHttpMessageNotReadableMapping() {
        HttpMessageNotReadableException ex = new HttpMessageNotReadableException(
                "Malformed JSON",
                new MockHttpInputMessage(new byte[0])
        );
        ResponseEntity<Map<String, Object>> res = handler.handleHttpMessageNotReadable(ex);

        assertEquals(HttpStatus.BAD_REQUEST, res.getStatusCode());
        assertNotNull(res.getBody());
        assertEquals(false, res.getBody().get("success"));
        assertEquals(400, res.getBody().get("status"));
        assertTrue(res.getBody().get("message").toString().contains("JSON"));
    }
}

