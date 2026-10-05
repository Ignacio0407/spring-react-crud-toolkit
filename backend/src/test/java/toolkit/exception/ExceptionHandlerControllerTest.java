package toolkit.exception;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

class ExceptionHandlerControllerTest {

    private MockMvc mockMvc;

    @RestController
    static class ThrowingController {
        @GetMapping("/test/not-found")
        void notFound() { throw new ResourceNotFoundException("User", "id", 1); }

        @GetMapping("/test/generic")
        void generic() { throw new RuntimeException("Unexpected error"); }

        @GetMapping("/test/illegal-argument")
        void illegalArgument() { throw new IllegalArgumentException("Bad arg"); }
    }

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders
                .standaloneSetup(new ThrowingController())
                .setControllerAdvice(new ExceptionHandlerController())
                .build();
    }

    @Test
    void shouldReturn404ForResourceNotFoundException() throws Exception {
        mockMvc.perform(get("/test/not-found").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.statusCode").value(404))
                .andExpect(jsonPath("$.message").value("User not found with id: '1'"));
    }

    @Test
    void shouldReturn400ForIllegalArgumentException() throws Exception {
        mockMvc.perform(get("/test/illegal-argument").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.statusCode").value(400))
                .andExpect(jsonPath("$.message").value("Bad arg"));
    }

    @Test
    void shouldReturn500ForGenericException() throws Exception {
        mockMvc.perform(get("/test/generic").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.statusCode").value(500))
                .andExpect(jsonPath("$.message").value("Unexpected error"));
    }
}
