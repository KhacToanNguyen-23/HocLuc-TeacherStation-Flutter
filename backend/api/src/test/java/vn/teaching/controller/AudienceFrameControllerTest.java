package vn.teaching.controller;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.server.ResponseStatusException;
import static org.assertj.core.api.Assertions.*;

class AudienceFrameControllerTest {
    private MockHttpServletRequest local() {
        var request=new MockHttpServletRequest(); request.setRemoteAddr("127.0.0.1"); return request;
    }
    private final String id="a".repeat(48);
    private final byte[] png={(byte)137,80,78,71,13,10,26,10,1};
    @Test void isolatesFramesAndClearsWithoutPersistingLessonContent() {
        var c=new AudienceFrameController();
        assertThat(c.read(id,local()).getStatusCode().value()).isEqualTo(404);
        c.update(id,png,local());
        assertThat(c.read(id,local()).getBody()).isEqualTo(png);
        assertThat(c.read("b".repeat(48),local()).getStatusCode().value()).isEqualTo(404);
        assertThatThrownBy(()->c.update("b".repeat(48),png,local())).isInstanceOf(ResponseStatusException.class);
        c.clear(id,local());
        assertThat(c.read(id,local()).getStatusCode().value()).isEqualTo(404);
    }
    @Test void rejectsRemoteOversizedAndNonPngContent() {
        var c=new AudienceFrameController(); var remote=local(); remote.setRemoteAddr("10.0.0.2");
        assertThatThrownBy(()->c.update(id,png,remote)).isInstanceOf(ResponseStatusException.class);
        assertThatThrownBy(()->c.update(id,"private notes".getBytes(),local())).isInstanceOf(ResponseStatusException.class);
        assertThatThrownBy(()->c.update("invalid",png,local())).isInstanceOf(ResponseStatusException.class);
        assertThatThrownBy(()->c.update(id,new byte[2_000_001],local())).isInstanceOf(ResponseStatusException.class);
    }
}
