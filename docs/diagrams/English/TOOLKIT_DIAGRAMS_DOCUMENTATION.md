# Architecture and Design Technical Diagrams Documentation
## Project: Spring-React CRUD Toolkit & Accelerator (Full-Stack Framework)

This document centralizes and details all **19 diagrams** that model the structural architecture, dynamic component interaction, security perimeter, and fundamental logical algorithms of the **Spring-React CRUD Toolkit** framework.

The diagrams are organized under a strict hierarchy running **from the highest architectural level to the lowest algorithmic level**, strictly complying with the guiding principle of **"Single Documentary Responsibility"**: each diagram answers one primary question and delegates details belonging to other perspectives to specialized diagrams via explicit cross-references.

---

## 🏛️ LEVEL 1: GLOBAL AND STRUCTURAL ARCHITECTURE (01 - 04)

### 01. Framework Global Full-Stack Architecture
* **Files:** `01_Component_Global_Architecture_Toolkit.puml` / `01_Component_Global_Architecture_Toolkit.svg`
* **UML Type:** Component Diagram
* **Primary Question:** How are frontend modules, network transport protocols, and backend layers structured in a decoupled architecture?
* **Purpose:** Holistic decoupled view of the complete framework. Models the interaction across the 5 frontend modules (Forms, Tables/Mass Edit, Client Search, Security/Routes, Real-time WebSocket), the REST (JSON) and STOMP transport contracts, and the 4 clean backend layers in Spring Boot 3 (`toolkit.configuration.jwt`, `toolkit.security`, `toolkit.controller`, `toolkit.service`, `toolkit.repository`) with the STOMP SimpleBroker and relational database.

### 02. Frontend Modular Component Architecture
* **Files:** `02_Component_Frontend_Architecture_Toolkit.puml` / `02_Component_Frontend_Architecture_Toolkit.svg`
* **UML Type:** Component Diagram
* **Primary Question:** What are the dependencies and modular boundaries of the UI components within the `src/components` package?
* **Purpose:** Map of internal dependencies and interfaces within `src/components`. Details relations among `ListGenerator`, `ListSortBar`, `ListPagination`, `MassEditWizard`, `ReviewModal`, `SearchBar`, `useSearchEngine`, `searchEngine` (with `LRUCache`), `FormGenerator`, `EditFormGenerator`, `FormInput`, `DoNotHackMyApp`, `ButtonLink`, and `webSocketManager`.

### 03. Backend Generic Class Hierarchy
* **Files:** `03_Class_Generic_Hierarchy_Backend.puml` / `03_Class_Generic_Hierarchy_Backend.svg`
* **UML Type:** Class Diagram
* **Primary Question:** How are the base generic types and CRUD abstractions structured in Spring Boot 3?
* **Purpose:** Pure structure of Spring Boot 3 abstractions under canonical `toolkit.*` packages. Models `BaseEntity`, `NamedEntity`, the `BaseRepository<T, D, I>` contract, the transactional base class `BaseService<T, I>` with `updateSome` and Template Method hooks, its decoupled variant `BaseServiceWithDTO<T, D, I>` connected to `EntityMapper<T, D>`, and the REST controllers `BaseRestController<T, I>` and `BaseRestControllerWithDTO<T, D, I>`, using standard OMG UML 2.5.1 directed associations.

### 04. Unit Testing Architecture with Test Doubles (Dummies & Mocks)
* **Files:** `04_Class_Unit_Testing_Architecture_Dummies.puml` / `04_Class_Unit_Testing_Architecture_Dummies.svg`
* **UML Type:** Class Diagram
* **Primary Question:** How do unit test suites validate the toolkit's generic contracts without depending on external databases?
* **Purpose:** Design of the unit testing harness (`src/test/java/toolkit`). Demonstrates how self-contained dummy classes from `toolkit.model.dummy` (`TestEntity`, `TestDTO`, `TestService`, `TestRepository`, `TestController`) enable suites `BaseServiceTest`, `BaseRestControllerTest`, `BaseServiceWithDTOTest`, and `BaseRestControllerWithDTOTest` to validate cross-cutting CRUD behavior, exception handling, and HTTP endpoints in complete isolation with Mockito and MockMvc.

---

## 🔄 LEVEL 2: COMPONENT COORDINATION AND SEQUENCE (05 - 12)

### 05. Comprehensive Component Orchestration by ListGenerator
* **Files:** `05_Sequence_ListGenerator_Component_Coordination.puml` / `05_Sequence_ListGenerator_Component_Coordination.svg`
* **UML Type:** Sequence Diagram
* **Primary Question:** How does `ListGenerator` coordinate event flow, sorting, filtering, pagination, and mass editing among dependent components?
* **Purpose:** Models `ListGenerator` as the UI master orchestrator: prior security check delegated to `DoNotHackMyAppHelper` (diagrams 08 and 18), data pipeline (`raw -> sortedData -> filteredData -> paginatedData`), coordination of `ListSortBar`, reactive filtering with `SearchBar`, synchronized pagination with `ListPagination`, keyboard shortcuts, and launch of the `MassEditWizard` modal (delegating to diagrams 07 and 19).

### 06. Dynamic Schema Inference and Form Lifecycle
* **Files:** `06_Sequence_FormGenerator_Schema_Inference.puml` / `06_Sequence_FormGenerator_Schema_Inference.svg`
* **UML Type:** Sequence Diagram
* **Primary Question:** How do the user, form generator, React Hook Form, and REST API interact during the form lifecycle?
* **Purpose:** Models the lifecycle of `EditFormGenerator` and `FormGenerator`. Illustrates schema inference from in-memory objects delegating the detailed algorithm to diagram 15 (`buildFieldsFromEntity`), uncontrolled subscription via refs in **React Hook Form**, client-side validation, and persistence via REST PUT/POST.

### 07. Mass Edit Cycle (MassEditWizard): Differential Review and Atomic Persistence
* **Files:** `07_Sequence_MassEditWizard_UndoRedo_Persistence.puml` / `07_Sequence_MassEditWizard_UndoRedo_Persistence.svg`
* **UML Type:** Sequence Diagram
* **Primary Question:** What are the temporal interactions and message exchanges between the user, mass edit wizard, form, review modal, and transactional persistence endpoints?
* **Purpose:** Models the multi-item editing flow: sequential row edits, change tracking delegating version stack manipulation to activity diagram 19 (`Undo/Redo History`), prior differential preview in `ReviewModal`, and batch submission to the `PUT /some` endpoint for atomic backend persistence (delegating `@Transactional` processing to activity diagram 17).

### 08. Client-Side Security Guard and Access Control (DoNotHackMyApp)
* **Files:** `08_Sequence_DoNotHackMyApp_Route_Guard.puml` / `08_Sequence_DoNotHackMyApp_Route_Guard.svg`
* **UML Type:** Sequence Diagram
* **Primary Question:** How does `navigateToUnauthorized` intercept the mount of a protected component and what sequence branches occur?
* **Purpose:** Models pre-render interception in `ListGenerator` and `EditFormGenerator`. Evaluates permissions delegating the decision tree to activity diagram 18 (`navigateToUnauthorized`), and depicts the two interaction paths: immediate abort and redirection to `/do-not-hack-my-app` vs. authorized rendering.

### 09. Client-Side Lifecycle and Subscription Management (WebSocketManager)
* **Files:** `09_Sequence_WebSocketManager_Subscription_Lifecycle.puml` / `09_Sequence_WebSocketManager_Subscription_Lifecycle.svg`
* **UML Type:** Sequence Diagram
* **Primary Question:** How are subscription registration, STOMP-over-WebSockets connection, and client-side message delivery coordinated over time?
* **Purpose:** Models temporal collaboration of the STOMP client (`webSocketManager.ts`): in-memory topic queuing, connection resolution delegating URL and transport algorithmic logic to diagram 16, JWT authenticated handshake, automatic resubscriptions, reactive JSON event dispatching, and controlled teardown.

### 10. STOMP Server Security: WebSocketSecurityInterceptor
* **Files:** `10_Sequence_WebSocket_Security_Interceptor.puml` / `10_Sequence_WebSocket_Security_Interceptor.svg`
* **UML Type:** Sequence Diagram
* **Primary Question:** How does Spring's channel interceptor validate each STOMP command (`CONNECT`, `SUBSCRIBE`, `SEND`) before allowing it through to the broker?
* **Purpose:** Models perimeter defense for the STOMP broker in backend (`WebSocketSecurityInterceptor.java`): HMAC-SHA256 authentication on `CONNECT`, in-memory rate limiting (max 60 requests/minute) on `SUBSCRIBE`, and strict payload limitation to 64 KB on `SEND`, throwing controlled exceptions translated into error frames.

### 11. Global Security Lifecycle: JWT Authentication and Multi-Protocol Authorization
* **Files:** `11_Sequence_Global_JWT_Authentication.puml` / `11_Sequence_Global_JWT_Authentication.svg`
* **UML Type:** Sequence Diagram
* **Primary Question:** How is the JWT token passed from initial issuance in the host application through filter interception and controllers in the toolkit?
* **Purpose:** Models cross-cutting identity flow: JWT issuance upon login in the host application's `AuthController`, persistence in `tokenService` (LocalStorage), and injection into HTTP headers `Authorization: Bearer` intercepted by `AuthTokenFilter` and validated via `JwtUtils` on protected endpoints.

### 12. Centralized Exception Handling with Spring Boot (@RestControllerAdvice)
* **Files:** `12_Sequence_Global_Exception_Handling.puml` / `12_Sequence_Global_Exception_Handling.svg`
* **UML Type:** Sequence Diagram
* **Primary Question:** How does a domain exception (`ResourceNotFoundException`) flow from service to transform into a standardized HTTP response?
* **Purpose:** Models failure capture in backend: `ResourceNotFoundException` thrown from `BaseService` bubbles up to `DispatcherServlet` and is intercepted by `ExceptionHandlerController`, returning a normalized `ErrorMessage` DTO with HTTP 404 status and ISO timestamp.

---

## ⚙️ LEVEL 3: ALGORITHMIC FLOWS AND PURE LOGICAL METHODS (13 - 19)

### 13. Flowchart of the parseSearchQuery Algorithm (searchEngine.ts)
* **Files:** `13_Flow_parseSearchQuery_searchEngine.puml` / `13_Flow_parseSearchQuery_searchEngine.svg`
* **UML Type:** Activity / Flow Diagram
* **Primary Question:** How does the algorithm tokenize and syntactically parse a search query in a single pass with guaranteed O(n) complexity?
* **Purpose:** Models the manual single-pass tokenizer and parser with guaranteed **O(n)** complexity. Describes key character discrimination (`isKeyChar`), colon delimiter detection (`:`), safe skipping without superlinear backtracking (`ReDoS prevention`), and bifurcated parsing of quoted vs. simple values.

### 14. Flowchart of the Search Pipeline and LRU Cache (useSearchEngine & searchData)
* **Files:** `14_Flow_searchData_Filter_Evaluation.puml` / `14_Flow_searchData_Filter_Evaluation.svg`
* **UML Type:** Activity / Flow Diagram
* **Primary Question:** How are filter matches evaluated and how does the LRU cache manage in-memory frequent queries?
* **Purpose:** Models client-side filtering pipeline: checking and updating `LRUCache` in hook `useSearchEngine.ts`, nested property extraction (`getNestedValue`), flexible text normalization `normalizeLoose` (NFD, no diacritics or symbols), matching modes (`exact`, `contains`, `startsWith`), and boolean logical combination (`AND` / `OR`).

### 15. Flowchart of Schema Inference: buildFieldsFromEntity (EditFormGenerator.tsx)
* **Files:** `15_Flow_buildFieldsFromEntity_EditFormGenerator.puml` / `15_Flow_buildFieldsFromEntity_EditFormGenerator.svg`
* **UML Type:** Activity / Flow Diagram
* **Primary Question:** What is the algorithmic decision tree to infer HTML input control types from JavaScript object attributes?
* **Purpose:** Models frontend introspection algorithm: primary key `'id'` exclusion and decision tree inferring controls (`select`, `number`, `checkbox`, `date`, `password`, `email`, `text`), automatic label capitalization, and merging custom configurations (`fieldConfig`).

### 16. Flowchart of Connection and Subscriptions: WebSocketManager (webSocketManager.ts)
* **Files:** `16_Flow_WebSocketManager_Connection_Management.puml` / `16_Flow_WebSocketManager_Connection_Management.svg`
* **UML Type:** Activity / Flow Diagram
* **Primary Question:** What are the deterministic steps for connection initialization, URL resolution, and asynchronous event handling in the WebSocket client?
* **Purpose:** Models `initConnection()` logic: algorithmic URL resolution (`buildSocketUrl`), transport selection (SockJS vs. RFC 6455 native WebSocket), JWT credential injection, fault-tolerant automatic resubscription (`resubscribeAll`), and error handler branches.

### 17. Flowchart of Batch Transactional Update: updateSome (BaseService.java)
* **Files:** `17_Flow_BaseService_updateSome_Transactional.puml` / `17_Flow_BaseService_updateSome_Transactional.svg`
* **UML Type:** Activity / Flow Diagram
* **Primary Question:** How does the backend guarantee transactional atomicity and validation during batch updates in `updateSome`?
* **Purpose:** Models execution of `@Transactional updateSome`: list size parity validation between IDs and entities, fail-fast lookup on non-existent IDs (automatic rollback), invocation of hook method `updateEntityFields` (Template Method pattern), and consolidated save via `saveAll`.

### 18. Flowchart of Permission Evaluation: navigateToUnauthorized (DoNotHackMyAppHelper.ts)
* **Files:** `18_Flow_DoNotHackMyApp_Authorization_Verification.puml` / `18_Flow_DoNotHackMyApp_Authorization_Verification.svg`
* **UML Type:** Activity / Flow Diagram
* **Primary Question:** What is the hierarchical evaluation order for client-side authorization and access conditions?
* **Purpose:** Models client-side access control logic: hierarchical evaluation among custom function (`checkAuth`), boolean explicit bypass, and standard rule `checkAuthDefault` (unconditional grant to `Authority.ADMIN` or exact role match), alongside rendering abortion upon denial.

### 19. Flowchart of Version History and Undo/Redo: MassEditWizard (MassEditWizard.tsx)
* **Files:** `19_Flow_MassEditWizard_UndoRedo_History.puml` / `19_Flow_MassEditWizard_UndoRedo_History.svg`
* **UML Type:** Activity / Flow Diagram
* **Primary Question:** How do the `EditTuple<T>` data structure, `activeVersion` pointer, truncation after Undo, and final batch preparation operate before dispatching to backend?
* **Purpose:** Models the in-memory version control algorithm in `MassEditWizard.tsx`: reactive tuple initialization (`original`, `versions`, `activeVersion`), mutation detection with `hasChanges`, version truncation and stacking in `applyUpdate`, in-memory backward and forward navigation (`undo` and `redo` without network calls), and final filtering of confirmed edits in `confirmAll` for delegation to the backend transactional endpoint.
