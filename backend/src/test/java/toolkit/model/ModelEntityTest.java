package toolkit.model;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class ModelEntityTest {

    @Test
    void testBaseEntity() {
        BaseEntity entity = new BaseEntity();
        assertTrue(entity.isNew());

        entity.setId(100);
        assertFalse(entity.isNew());
        assertEquals(100, entity.getId());
    }

    @Test
    void testNamedEntity() {
        NamedEntity entity = new NamedEntity();
        entity.setName("TestName");
        assertEquals("TestName", entity.getName());
        assertEquals("TestName", entity.toString());
    }
}
