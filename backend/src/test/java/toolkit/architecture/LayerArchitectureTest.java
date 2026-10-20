package toolkit.architecture;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static com.tngtech.archunit.library.Architectures.layeredArchitecture;
import static com.tngtech.archunit.library.dependencies.SlicesRuleDefinition.slices;

/**
 * Architecture tests verifying layer boundaries and package isolation
 * across the Spring Boot backend using ArchUnit.
 *
 * <p>Originated at TNG Technology Consulting, ArchUnit treats architecture
 * as executable, regression-tested code.</p>
 */
@AnalyzeClasses(packages = "toolkit", importOptions = { ImportOption.DoNotIncludeTests.class })
public class LayerArchitectureTest {

    @ArchTest
    public static final ArchRule layered_architecture_is_respected = layeredArchitecture()
            .consideringOnlyDependenciesInLayers()
            .layer("Controllers").definedBy("toolkit.controller..")
            .layer("Services").definedBy("toolkit.service..")
            .layer("Repositories").definedBy("toolkit.repository..")
            .layer("Models").definedBy("toolkit.model..")
            .layer("Security").definedBy("toolkit.security..", "toolkit.configuration..")
            .whereLayer("Controllers").mayNotBeAccessedByAnyLayer()
            .whereLayer("Services").mayOnlyBeAccessedByLayers("Controllers", "Security")
            .whereLayer("Repositories").mayOnlyBeAccessedByLayers("Services");

    @ArchTest
    public static final ArchRule controllers_must_not_access_repositories_directly = noClasses()
            .that().resideInAPackage("..controller..")
            .should().dependOnClassesThat().resideInAPackage("..repository..")
            .because("Controllers must delegate database persistence through the Service layer and never bypass it");

    @ArchTest
    public static final ArchRule services_must_not_depend_on_controllers = noClasses()
            .that().resideInAPackage("..service..")
            .should().dependOnClassesThat().resideInAPackage("..controller..")
            .because("Business services must not depend on HTTP/Web presentation controllers");

    @ArchTest
    public static final ArchRule repositories_must_not_depend_on_services = noClasses()
            .that().resideInAPackage("..repository..")
            .should().dependOnClassesThat().resideInAPackage("..service..")
            .because("Repositories must remain focused strictly on data persistence");

    @ArchTest
    public static final ArchRule toolkit_packages_must_be_free_of_cycles = slices()
            .matching("toolkit.(*)..")
            .should().beFreeOfCycles()
            .because("Circular package dependencies violate clean architecture and make modules unmaintainable");
}
