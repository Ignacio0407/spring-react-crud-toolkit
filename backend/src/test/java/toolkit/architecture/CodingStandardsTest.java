package toolkit.architecture;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;
import com.tngtech.archunit.library.GeneralCodingRules;

import toolkit.model.BaseEntity;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.fields;

/**
 * Architecture tests enforcing standard clean-code rules, logging conventions,
 * exception-handling standards, and constructor injection across the codebase.
 */
@AnalyzeClasses(packages = "toolkit", importOptions = { ImportOption.DoNotIncludeTests.class })
public class CodingStandardsTest {

    @ArchTest
    public static final ArchRule no_field_injection_allowed = GeneralCodingRules.NO_CLASSES_SHOULD_USE_FIELD_INJECTION
            .because("Constructor injection must be preferred for immutability, testability, and Spring Boot 3 standards");

    @ArchTest
    public static final ArchRule no_classes_should_access_standard_streams = GeneralCodingRules.NO_CLASSES_SHOULD_ACCESS_STANDARD_STREAMS
            .because("Production code must use SLF4J / structured loggers instead of System.out or System.err");

    @ArchTest
    public static final ArchRule no_generic_exceptions_thrown = GeneralCodingRules.NO_CLASSES_SHOULD_THROW_GENERIC_EXCEPTIONS
            .because("Methods must throw specific, typed domain exceptions rather than generic Exception or Throwable");

    @ArchTest
    public static final ArchRule no_java_util_logging = GeneralCodingRules.NO_CLASSES_SHOULD_USE_JAVA_UTIL_LOGGING
            .because("Logging must be handled via SLF4J / Logback rather than java.util.logging");

    @ArchTest
    public static final ArchRule custom_exceptions_must_extend_throwable_and_reside_in_exception_package = classes()
            .that().haveSimpleNameEndingWith("Exception")
            .should().beAssignableTo(Throwable.class)
            .andShould().resideInAPackage("..exception..")
            .because("Domain and system exceptions must inherit from Throwable and reside in the exception package");

    @ArchTest
    public static final ArchRule entity_fields_must_not_be_public = fields()
            .that().areDeclaredInClassesThat().areAssignableTo(BaseEntity.class)
            .and().areNotStatic()
            .should().notBePublic()
            .because("JPA entities must maintain proper encapsulation; fields must be protected or private with accessors");
}
