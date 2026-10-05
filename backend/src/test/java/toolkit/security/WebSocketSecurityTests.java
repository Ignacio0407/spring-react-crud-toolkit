/**
 * -----------------------------------------------------------------------------
 * Autor / Author: Ignacio Gutiérrez Serrera
 * GitHub: https://github.com/Ignacio0407 (@Ignacio0407)
 * Contact / Email: ignaciogutierrezserrera@gmail.com
 * 
 * 🇬🇧 NON-COMMERCIAL & EDUCATIONAL LICENSE:
 * This software was developed by Ignacio Gutiérrez Serrera.
 * Permission is granted to use, copy, modify, and study this software for 
 * non-commercial, personal, academic, and educational purposes, provided 
 * that this copyright notice, author attribution, and contact details are 
 * preserved in all copies or substantial portions of the software.
 * 
 * Any commercial use, integration into proprietary software, or closed-source 
 * distribution is strictly prohibited without prior written permission and an 
 * express commercial license granted by the author.
 * 
 * 🇪🇸 LICENCIA PARA FINES NO LUCRATIVOS Y EDUCATIVOS:
 * Este software ha sido desarrollado por Ignacio Gutiérrez Serrera.
 * Se autoriza su uso, copia, modificación y estudio exclusivamente para 
 * fines personales, académicos, de investigación y educativos no lucrativos, 
 * con la condición obligatoria de mantener intacto este aviso de copyright, 
 * la atribución de autoría y los datos de contacto en todas las copias.
 * 
 * Queda terminantemente prohibido cualquier uso comercial, integración en 
 * software privativo o distribución con fines lucrativos sin la autorización 
 * previa por escrito del autor y la adquisición de una licencia comercial.
 * -----------------------------------------------------------------------------
 */

package toolkit.security;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.Mockito.*;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;
import org.junit.jupiter.api.Test;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageDeliveryException;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.MessageBuilder;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;

import toolkit.configuration.jwt.JwtUtils;

class WebSocketSecurityTests {

    private JwtUtils jwtUtils;
    private UserDetailsService userDetailsService;
    private WebSocketSecurityInterceptor interceptor;

    @BeforeEach
    void setup() {
        jwtUtils = mock(JwtUtils.class);
        userDetailsService = mock(UserDetailsService.class);
        interceptor = new WebSocketSecurityInterceptor(jwtUtils, userDetailsService);
        SecurityContextHolder.clearContext();
    }

    // Accessor with authenticated user
    private StompHeaderAccessor authenticatedAccessor(String command, String destination) {
        StompHeaderAccessor acc = StompHeaderAccessor.create(StompCommand.valueOf(command));
        acc.setLeaveMutable(true);
        acc.setDestination(destination);
        UserDetails user = User.withUsername("user").password("x").authorities("PLAYER").build();
        acc.setUser(new UsernamePasswordAuthenticationToken(user, null, user.getAuthorities()));
        return acc;
    }

    // Accessor without authenticated user
    private StompHeaderAccessor unauthenticatedAccessor(String command, String destination) {
        StompHeaderAccessor acc = StompHeaderAccessor.create(StompCommand.valueOf(command));
        acc.setLeaveMutable(true);
        acc.setDestination(destination);
        return acc;
    }

    // 1. CONNECT: JWT authentication
    @ParameterizedTest(name = "[{index}] authHeader=''{0}'' valid={1} -> success={2}")
    @CsvSource({
        // authHeader,          jwtValid, shouldSucceed
        "Bearer valid.jwt,      true,     true",   // Valid token
        "Bearer invalid.jwt,    false,    false",  // Invalid token
        "'',                    false,    false",  // No header (empty)
        "Basic dXNlcjpwYXNz,   false,    false",  // Header not Bearer
    })
    void connectAuthentication(String authHeader, boolean jwtValid, boolean shouldSucceed) {
        StompHeaderAccessor acc = StompHeaderAccessor.create(StompCommand.CONNECT);
        acc.setLeaveMutable(true);

        String trimmed = authHeader.trim();
        if (!trimmed.isEmpty()) acc.setNativeHeader("Authorization", trimmed);

        if (trimmed.startsWith("Bearer ")) {
            String token = trimmed.substring(7);
            when(jwtUtils.validateJwtToken(token)).thenReturn(jwtValid);
            if (jwtValid) {
                when(jwtUtils.getUserNameFromJwtToken(token)).thenReturn("user");
                UserDetails ud = User.withUsername("user").password("x").authorities("PLAYER").build();
                when(userDetailsService.loadUserByUsername("user")).thenReturn(ud);
            }
        }

        Message<byte[]> msg = MessageBuilder.createMessage(new byte[0], acc.getMessageHeaders());

        if (shouldSucceed) {
            assertThatCode(() -> interceptor.preSend(msg, null)).doesNotThrowAnyException();
        } else {
            assertThatThrownBy(() -> interceptor.preSend(msg, null)).isInstanceOf(MessageDeliveryException.class);
        }
    }

    // 2. SEND / SUBSCRIBE: Generic destinations and payload validation
    @ParameterizedTest(name = "[{index}] {0} {1} bigPayload={2} -> success={3}")
    @CsvSource({
        // command,    destination,           bigPayload, shouldSucceed
        "SEND,       /topic/messages,       false,      true",
        "SEND,       /topic/notifications,  false,      true",
        "SUBSCRIBE,  /topic/messages,       false,      true",
        "SUBSCRIBE,  /topic/notifications,  false,      true",
        "SEND,       /app/chat,             false,      true",
        "SUBSCRIBE,  /queue/alerts,         false,      true",
        // Big Payload (> 64 KB)
        "SEND,       /topic/messages,       true,       false",
        "SUBSCRIBE,  /topic/messages,       true,       false",
    })
    void sendAndSubscribeValidation(String command, String destination, boolean bigPayload, boolean shouldSucceed) {
        StompHeaderAccessor acc = authenticatedAccessor(command, destination.trim());

        byte[] payload = bigPayload ? new byte[70 * 1024] : "ok".getBytes();
        Message<byte[]> msg = MessageBuilder.createMessage(payload, acc.getMessageHeaders());

        if (shouldSucceed) {
            assertThatCode(() -> interceptor.preSend(msg, null)).doesNotThrowAnyException();
        } else {
            assertThatThrownBy(() -> interceptor.preSend(msg, null)).isInstanceOf(MessageDeliveryException.class);
        }
    }

    // 3. SEND / SUBSCRIBE: Invalid destinations (null or blank)
    @ParameterizedTest(name = "[{index}] Destination ''{0}'' should fail")
    @NullAndEmptySource
    @ValueSource(strings = {"   ", "\t"})
    void sendWithInvalidDestination_shouldFail(String destination) {
        StompHeaderAccessor acc = authenticatedAccessor("SEND", destination);
        Message<byte[]> msg = MessageBuilder.createMessage("ok".getBytes(), acc.getMessageHeaders());

        assertThatThrownBy(() -> interceptor.preSend(msg, null)).isInstanceOf(MessageDeliveryException.class);
    }

    // 4. SEND / SUBSCRIBE: unauthenticated user
    @ParameterizedTest(name = "[{index}] {0} without user -> must fail")
    @CsvSource({
        "SEND,      /topic/messages",
        "SUBSCRIBE, /topic/messages",
    })
    void sendOrSubscribeWithoutAuthenticatedUser_shouldFail(String command, String destination) {
        StompHeaderAccessor acc = unauthenticatedAccessor(command, destination.trim());
        Message<byte[]> msg = MessageBuilder.createMessage("ok".getBytes(), acc.getMessageHeaders());

        assertThatThrownBy(() -> interceptor.preSend(msg, null)).isInstanceOf(MessageDeliveryException.class);
    }

    // 5. Rate limit: 60 messages allowed per minute, 61st is rejected
    @ParameterizedTest(name = "[{index}] rate limit in {0} {1}")
    @CsvSource({
        "SEND,      /topic/messages",
        "SUBSCRIBE, /topic/messages",
    })
    void rateLimitExceeded_shouldFail(String command, String destination) {
        StompHeaderAccessor acc = authenticatedAccessor(command, destination.trim());
        Message<byte[]> msg = MessageBuilder.createMessage("ok".getBytes(), acc.getMessageHeaders());

        for (int i = 0; i < 60; i++) {
            interceptor.preSend(msg, null);
        }

        assertThatThrownBy(() -> interceptor.preSend(msg, null)).isInstanceOf(MessageDeliveryException.class);
    }

    // 6. Rate limit reset after 60 seconds
    @Test
    void testRateLimitResetAfterOneMinute() throws Exception {
        StompHeaderAccessor acc = authenticatedAccessor("SEND", "/topic/messages");
        Message<byte[]> msg = MessageBuilder.createMessage("ok".getBytes(), acc.getMessageHeaders());

        // Fill rate limit
        for (int i = 0; i < 60; i++) {
            interceptor.preSend(msg, null);
        }

        // Manually simulate time reset in lastReset map
        java.lang.reflect.Field lastResetField = WebSocketSecurityInterceptor.class.getDeclaredField("lastReset");
        lastResetField.setAccessible(true);
        @SuppressWarnings("unchecked")
        java.util.Map<String, Long> lastResetMap = (java.util.Map<String, Long>) lastResetField.get(interceptor);
        lastResetMap.put("user", System.currentTimeMillis() - 61000);

        // Next send should reset counter and succeed
        assertThatCode(() -> interceptor.preSend(msg, null)).doesNotThrowAnyException();
    }

    // 7. Null accessor or command that does not require security check
    @Test
    void testNullAccessorAndCommand() {
        Message<byte[]> msgWithoutHeaders = MessageBuilder.createMessage(new byte[0], MessageBuilder.withPayload(new byte[0]).build().getHeaders());
        Message<?> resultWithoutHeaders = interceptor.preSend(msgWithoutHeaders, null);
        assertEquals(msgWithoutHeaders, resultWithoutHeaders, "Must return original message if accessor is null");

        StompHeaderAccessor accNoCommand = StompHeaderAccessor.create(StompCommand.DISCONNECT);
        accNoCommand.setLeaveMutable(true);
        Message<byte[]> msgNoCommand = MessageBuilder.createMessage(new byte[0], accNoCommand.getMessageHeaders());
        Message<?> resultNoCommand = interceptor.preSend(msgNoCommand, null);
        assertEquals(msgNoCommand, resultNoCommand, "Must return original message if command does not require validation");
    }

    // 8. SecurityContextHolder set on valid SEND / SUBSCRIBE
    @Test
    void testSecurityContextHolderSetOnSendAndSubscribe() {
        StompHeaderAccessor acc = authenticatedAccessor("SEND", "/topic/messages");
        Message<byte[]> msg = MessageBuilder.createMessage("ok".getBytes(), acc.getMessageHeaders());

        interceptor.preSend(msg, null);

        org.springframework.security.core.Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        assertNotNull(auth);
        assertEquals("user", auth.getName());
    }
}
