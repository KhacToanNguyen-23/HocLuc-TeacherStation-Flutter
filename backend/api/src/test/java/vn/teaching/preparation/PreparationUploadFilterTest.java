package vn.teaching.preparation;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.*;
import vn.teaching.exam.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
class PreparationUploadFilterTest {
    @Test void authenticatesBundleBeforeMultipartParsing()throws Exception{
        ExamAuth auth=mock(ExamAuth.class);when(auth.authenticate(null)).thenThrow(new ExamException(org.springframework.http.HttpStatus.UNAUTHORIZED,"SESSION_REQUIRED","Login",java.util.List.of()));var filter=new PreparationUploadFilter(auth,"companion");MockHttpServletRequest req=new MockHttpServletRequest("POST","/api/preparation/components/install");req.setContentType("multipart/form-data; boundary=test");MockHttpServletResponse res=new MockHttpServletResponse();MockFilterChain chain=new MockFilterChain();filter.doFilter(req,res,chain);assertEquals(401,res.getStatus());assertNull(chain.getRequest());verifyNoInteractions(auth);
        req=new MockHttpServletRequest("POST","/api/preparation/components/install");req.setContentType("multipart/form-data; boundary=test");req.addHeader("X-Companion-Token","companion");res=new MockHttpServletResponse();chain=new MockFilterChain();filter.doFilter(req,res,chain);assertEquals(401,res.getStatus());assertNull(chain.getRequest());
    }
    @Test void largeNonBundleRequestsRemainBoundedAndAuthenticatedBundleCanProceed()throws Exception{
        ExamAuth auth=mock(ExamAuth.class);var filter=new PreparationUploadFilter(auth,"companion");MockHttpServletRequest request=new MockHttpServletRequest("POST","/api/preparation/plannings/p/sources"){@Override public long getContentLengthLong(){return 60L*1024*1024;}};request.setContentType("multipart/form-data");MockFilterChain chain=new MockFilterChain();MockHttpServletResponse response=new MockHttpServletResponse();filter.doFilter(request,response,chain);assertEquals(413,response.getStatus());assertNull(chain.getRequest());
        request=new MockHttpServletRequest("POST","/api/preparation/components/install");request.setContent(new byte[1]);request.setContentType("multipart/form-data");request.addHeader("X-Companion-Token","companion");request.addHeader("Authorization","Bearer teacher");when(auth.authenticate("Bearer teacher")).thenReturn(new ExamModels.Account("teacher","t@example.org","T","TEACHER"));chain=new MockFilterChain();response=new MockHttpServletResponse();filter.doFilter(request,response,chain);assertNotNull(chain.getRequest());assertEquals(200,response.getStatus());
    }
    @Test void checksLengthAndSpoolHeadroomBeforeBodyParsing()throws Exception{
        ExamAuth auth=mock(ExamAuth.class);var filter=new PreparationUploadFilter(auth,"companion"){@Override long available(){return 600L*1024*1024;}};
        var req=new MockHttpServletRequest("POST","/api/preparation/components/install");req.setContentType("multipart/form-data");req.addHeader("X-Companion-Token","companion");
        var res=new MockHttpServletResponse();var chain=new MockFilterChain();filter.doFilter(req,res,chain);assertEquals(411,res.getStatus());assertNull(chain.getRequest());
        req=new MockHttpServletRequest("POST","/api/preparation/components/install"){@Override public long getContentLengthLong(){return 200L*1024*1024;}};
        req.setContentType("multipart/form-data");req.addHeader("X-Companion-Token","companion");res=new MockHttpServletResponse();chain=new MockFilterChain();filter.doFilter(req,res,chain);assertEquals(507,res.getStatus());assertNull(chain.getRequest());
    }
}
