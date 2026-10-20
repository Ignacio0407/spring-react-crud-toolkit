package toolkit.architecture;

import com.tngtech.archunit.core.domain.JavaMethod;
import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchCondition;
import com.tngtech.archunit.lang.ArchRule;
import com.tngtech.archunit.lang.ConditionEvents;
import com.tngtech.archunit.lang.SimpleConditionEvent;
import org.springframework.data.repository.Repository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.methods;

/**
 * Architecture tests verifying Spring Boot component conventions,
 * repository abstractions, controller response contracts, and naming consistency.
 */
@AnalyzeClasses(packages = "toolkit", importOptions = { ImportOption.DoNotIncludeTests.class })
public class SpringConventionsTest {

    @ArchTest
    public static final ArchRule controllers_must_follow_naming_convention = classes()
            .that().resideInAPackage("..controller..")
            .should().haveSimpleNameEndingWith("Controller")
            .orShould().haveSimpleNameStartingWith("BaseRestController")
            .because("Controllers and base controller abstractions must follow unified naming conventions");

    @ArchTest
    public static final ArchRule services_must_follow_naming_convention = classes()
            .that().resideInAPackage("..service..")
            .should().haveSimpleNameEndingWith("Service")
            .orShould().haveSimpleNameStartingWith("BaseService")
            .because("Service components and base services must be identifiable by their class name");

    @ArchTest
    public static final ArchRule repositories_must_be_interfaces_and_extend_spring_repository = classes()
            .that().resideInAPackage("..repository..")
            .should().beInterfaces()
            .andShould().beAssignableTo(Repository.class)
            .because("Data access repositories must be Spring Data interfaces extending Repository");

    @ArchTest
    public static final ArchRule exception_handlers_must_reside_in_exception_package = classes()
            .that().areAnnotatedWith(RestControllerAdvice.class)
            .or().areAnnotatedWith(ControllerAdvice.class)
            .should().resideInAPackage("..exception..")
            .because("Global exception advice handlers belong in the exception handling module");

    @ArchTest
    public static final ArchRule methods_annotated_with_exception_handler_must_be_in_advice_classes = methods()
            .that().areAnnotatedWith(ExceptionHandler.class)
            .should().beDeclaredInClassesThat().areAnnotatedWith(RestControllerAdvice.class)
            .orShould().beDeclaredInClassesThat().areAnnotatedWith(ControllerAdvice.class)
            .because("Exception handling methods must be declared inside central advice classes");

    /**
     * Demonstrates a Custom ArchUnit Condition:
     * Validates that controller endpoints return {@link ResponseEntity}
     * or standard response wrappers rather than raw unencapsulated types.
     */
    @ArchTest
    public static final ArchRule controller_public_methods_should_return_response_entity = methods()
            .that().areDeclaredInClassesThat().resideInAPackage("..controller..")
            .and().arePublic()
            .should(new ArchCondition<JavaMethod>("return ResponseEntity") {
                @Override
                public void check(JavaMethod method, ConditionEvents events) {
                    boolean returnsResponseEntity = method.getRawReturnType().isAssignableTo(ResponseEntity.class);
                    if (!returnsResponseEntity) {
                        String message = String.format("Method %s does not return ResponseEntity",
                                method.getFullName());
                        events.add(SimpleConditionEvent.violated(method, message));
                    }
                }
            })
            .because("REST controller endpoints should encapsulate HTTP status codes and headers in a ResponseEntity");
}
