package toolkit.configuration.jwt;

import toolkit.user.Authority;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import java.util.List;

@ExtendWith(MockitoExtension.class)
class JwtUtilsTest {

    private JwtUtils jwtUtils;

    private final String secret = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ012345678912345678901234567890";
    private final int expirationMs = 60000;

    @Mock
    private Authentication authentication;

    @BeforeEach
    void setUp() {
        jwtUtils = new JwtUtils();
        ReflectionTestUtils.setField(jwtUtils, "jwtSecret", secret);
        ReflectionTestUtils.setField(jwtUtils, "jwtExpirationMs", expirationMs);
    }

    @Test
    void testGenerateJwtTokenAndGetUsername() {
        UserDetails userPrincipal = User.builder().username("john").password("password")
        .authorities(List.of(new SimpleGrantedAuthority("USER"))).build();
        when(authentication.getPrincipal()).thenReturn(userPrincipal);

        String token = jwtUtils.generateJwtToken(authentication);
        assertNotNull(token);
        assertTrue(jwtUtils.validateJwtToken(token));
        assertEquals("john", jwtUtils.getUserNameFromJwtToken(token));
    }

    @Test
    void testGenerateTokenFromUsername() {
        String token = jwtUtils.generateTokenFromUsername("admin_user", Authority.ADMIN);
        assertNotNull(token);
        assertTrue(jwtUtils.validateJwtToken(token));
        assertEquals("admin_user", jwtUtils.getUserNameFromJwtToken(token));
    }

    @Test
    void testValidateJwtToken_InvalidCases() {
        // Invalid token
        assertFalse(jwtUtils.validateJwtToken("invalid.jwt.token"));

        // Null / empty
        assertFalse(jwtUtils.validateJwtToken(""));

        // Signed with wrong secret
        JwtUtils wrongSecretUtils = new JwtUtils();
        ReflectionTestUtils.setField(wrongSecretUtils, "jwtSecret", "wrongSecretKey12345678901234567890123456789012345678901234567890");
        ReflectionTestUtils.setField(wrongSecretUtils, "jwtExpirationMs", expirationMs);
        String tokenFromWrongSecret = wrongSecretUtils.generateTokenFromUsername("test", Authority.USER);

        assertFalse(jwtUtils.validateJwtToken(tokenFromWrongSecret));

        // Expired token
        JwtUtils expiredUtils = new JwtUtils();
        ReflectionTestUtils.setField(expiredUtils, "jwtSecret", secret);
        ReflectionTestUtils.setField(expiredUtils, "jwtExpirationMs", -1000);
        String expiredToken = expiredUtils.generateTokenFromUsername("test", Authority.USER);

        assertFalse(jwtUtils.validateJwtToken(expiredToken));

        // Unsupported JWT token
        String unsignedToken = "eyJhbGciOiJub25lIn0.eyJzdWIiOiJ0ZXN0In0.";
        assertFalse(jwtUtils.validateJwtToken(unsignedToken));
    }
}
