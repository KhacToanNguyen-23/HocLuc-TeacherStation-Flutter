package vn.teaching.modules.plugin;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

import static org.hamcrest.Matchers.greaterThan;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.notNullValue;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
public class PluginMarketplaceControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void testGetCatalogReturnsAvailablePluginsIncludingCasio() throws Exception {
        mockMvc.perform(get("/api/marketplace/plugins"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.length()").value(greaterThan(0)))
                .andExpect(jsonPath("$[*].id", hasItem("com.hocluc.plugin.casio")))
                .andExpect(jsonPath("$[0].sha256", notNullValue()))
                .andExpect(jsonPath("$[0].downloadUrl", notNullValue()));

        // Verify v1 alias endpoint works identically
        mockMvc.perform(get("/api/v1/plugins"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].id", hasItem("com.hocluc.plugin.casio")));
    }

    @Test
    void testDownloadCasioPluginStreamsValidHlepArchive() throws Exception {
        MvcResult res = mockMvc.perform(get("/api/marketplace/plugins/com.hocluc.plugin.casio/download"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_OCTET_STREAM))
                .andExpect(header().exists("X-Plugin-Sha256"))
                .andReturn();

        byte[] bytes = res.getResponse().getContentAsByteArray();
        assertTrue(bytes.length > 100, "Downloaded .hlep package must not be empty");
        // Verify PK zip magic header (0x50, 0x4B)
        assertTrue(bytes[0] == 0x50 && bytes[1] == 0x4B, "Downloaded .hlep must be a valid ZIP archive");
    }

    @Test
    void testGetPluginIconReturnsPngBytes() throws Exception {
        mockMvc.perform(get("/api/marketplace/plugins/com.hocluc.plugin.casio/icon"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.IMAGE_PNG));
    }

    @Test
    void testPublishNewOpenSourcePluginAndDownload() throws Exception {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        try (ZipOutputStream zos = new ZipOutputStream(baos)) {
            ZipEntry manifestEntry = new ZipEntry("manifest.json");
            zos.putNextEntry(manifestEntry);
            String manifestJson = """
                    {
                      "id": "com.hocluc.plugin.geogebra_test",
                      "name": "GeoGebra Hình Học Mở Rộng",
                      "version": "1.2.0",
                      "author": "OpenSource Community",
                      "description": "Công cụ vẽ hình học phẳng tích hợp từ mã nguồn mở.",
                      "category": "math",
                      "main": "ui/index.html",
                      "placement": "floating_window",
                      "inject_sdk": true,
                      "permissions": ["board:insert_annotation"]
                    }
                    """;
            zos.write(manifestJson.getBytes(StandardCharsets.UTF_8));
            zos.closeEntry();

            ZipEntry uiEntry = new ZipEntry("ui/index.html");
            zos.putNextEntry(uiEntry);
            zos.write("<html><body><h1>GeoGebra</h1></body></html>".getBytes(StandardCharsets.UTF_8));
            zos.closeEntry();
        }

        MockMultipartFile multipartFile = new MockMultipartFile(
                "file",
                "geogebra_test.hlep",
                "application/octet-stream",
                baos.toByteArray()
        );

        mockMvc.perform(multipart("/api/marketplace/plugins/publish").file(multipartFile))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.plugin.id").value("com.hocluc.plugin.geogebra_test"))
                .andExpect(jsonPath("$.plugin.version").value("1.2.0"));

        // Verify the newly published plugin is downloadable
        mockMvc.perform(get("/api/marketplace/plugins/com.hocluc.plugin.geogebra_test/download"))
                .andExpect(status().isOk())
                .andExpect(header().exists("X-Plugin-Sha256"));
    }
}

