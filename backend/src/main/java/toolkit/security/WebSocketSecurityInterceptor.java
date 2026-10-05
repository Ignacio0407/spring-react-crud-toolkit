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

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.MessageDeliveryException;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.lang.Nullable;

import toolkit.configuration.jwt.JwtUtils;

public class WebSocketSecurityInterceptor implements ChannelInterceptor {

    // Exception messages are not too detailed to not reveal much information (Security through obscurity)
    // 🛡️ is for SEND/SUBSCRIBE while 🔐 is for CONNECT

    private final JwtUtils jwtUtils;
    private final UserDetailsService userDetailsService;

    private static final int MAX_MESSAGES_PER_MINUTE = 60;
    private static final int MAX_PAYLOAD_SIZE = 64 * 1024; // 64 KB

    private final Map<String, AtomicInteger> messageCount = new ConcurrentHashMap<>();
    private final Map<String, Long> lastReset = new ConcurrentHashMap<>();

    public WebSocketSecurityInterceptor(JwtUtils jwtUtils, UserDetailsService userDetailsService) {
        this.jwtUtils = jwtUtils;
        this.userDetailsService = userDetailsService;
    }

    // 🛡️ Destination validation hook (can be overridden by subclasses for custom route authorization)
    protected void validateDestination(String destination, Message<?> message) {
        if (destination == null || destination.trim().isEmpty()) {
            throw new MessageDeliveryException(message, "Invalid destination");
        }
    }

    // 🔐 Authorization + Validation
    protected void validateMessage(StompHeaderAccessor accessor, Message<?> message) {
        String destination = accessor.getDestination();
        this.validateDestination(destination, message);

        Authentication auth = (Authentication) accessor.getUser();
        if (auth == null) {
            throw new MessageDeliveryException(message, "Unauthorized");
        }
        String username = auth.getName();
        this.checkRateLimit(username, message);
        this.validatePayload(message);
    }

    // 🛡️ Rate Limit. Prevents DoS (Denial of Service)
    protected void checkRateLimit(String username, Message<?> message) {
        long now = System.currentTimeMillis();
        lastReset.putIfAbsent(username, now);
        messageCount.putIfAbsent(username, new AtomicInteger(0));
        if (now - lastReset.get(username) > 60000) {
            messageCount.get(username).set(0);
            lastReset.put(username, now);
        }
        if (messageCount.get(username).incrementAndGet() > MAX_MESSAGES_PER_MINUTE) {
            throw new MessageDeliveryException(message, "Too many requests");
        }
    }

    // 🛡️ Payload Validation. Prevents malicious JSON, huge payloads and XSS if it is later resent to clients
    protected void validatePayload(Message<?> message) {
        if (message.getPayload() instanceof byte[] data && data.length > MAX_PAYLOAD_SIZE) {
            throw new MessageDeliveryException(message, "Invalid payload");
        }
    }

    // 🔐 Authentication (Connect)
    protected void handleConnect(StompHeaderAccessor accessor, Message<?> message) {
        String authHeader = accessor.getFirstNativeHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            throw new MessageDeliveryException(message, "Unauthorized");
        }
        String jwt = authHeader.substring(7);
        if (!this.jwtUtils.validateJwtToken(jwt)) {
            throw new MessageDeliveryException(message, "Unauthorized");
        }
        String username = this.jwtUtils.getUserNameFromJwtToken(jwt);
        UserDetails user = this.userDetailsService.loadUserByUsername(username);
        Authentication auth = new UsernamePasswordAuthenticationToken(
                user, null, user.getAuthorities());
        accessor.setUser(auth);
    }

    @Override
    @Nullable
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor =
            MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);

        if (accessor == null) return message;
        StompCommand command = accessor.getCommand();
        if (command == null) return message;

        if (command == StompCommand.CONNECT) {
            this.handleConnect(accessor, message);
        } else if (command == StompCommand.SEND || command == StompCommand.SUBSCRIBE) {
            this.validateMessage(accessor, message);
            if (accessor.getUser() instanceof Authentication authentication) {
                SecurityContextHolder.getContext().setAuthentication(authentication);
            }
        }
        return message;
    }
}
