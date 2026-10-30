# Documentación Técnica de Diagramas de Arquitectura y Diseño
## Proyecto: Spring-React CRUD Toolkit & Accelerator (Framework Full-Stack)

Este documento centraliza y detalla la totalidad de los **19 diagramas** que modelan la arquitectura estructural, la interacción dinámica entre componentes, el perímetro de seguridad y los algoritmos lógicos fundamentales del framework **Spring-React CRUD Toolkit**.

Los diagramas están organizados bajo una rigurosa jerarquía que va **desde el más alto nivel arquitectónico hasta el más bajo nivel algorítmico**, cumpliendo estrictamente con el principio prioritario de **"Responsabilidad Documental Única" (Single Documentary Responsibility)**: cada diagrama responde a una pregunta principal y delega los detalles de otras perspectivas en diagramas especializados mediante referencias cruzadas explícitas.

---

## 🏛️ NIVEL 1: ARQUITECTURA GLOBAL Y ESTRUCTURAL (01 - 04)

### 01. Arquitectura Global Full-Stack del Framework
* **Archivos:** `01_Componente_Arquitectura_Global_Toolkit.puml` / `01_Componente_Arquitectura_Global_Toolkit.svg`
* **Tipo UML:** Diagrama de Componentes
* **Pregunta principal:** ¿Cómo se estructuran los módulos del frontend, los protocolos de red y las capas del backend en una arquitectura desacoplada?
* **Propósito:** Visión holística desacoplada del framework completo. Modela la interacción entre los 5 módulos del frontend (Formularios, Listas/Edición Masiva, Búsqueda en Cliente, Seguridad/Rutas y WebSocket en tiempo real), los contratos de transporte REST (JSON) y STOMP, y las 4 capas limpias del backend en Spring Boot 3 (`toolkit.configuration.jwt`, `toolkit.security`, `toolkit.controller`, `toolkit.service`, `toolkit.repository`) con el Broker STOMP y la base de datos relacional.

### 02. Arquitectura Modular de Componentes del Frontend
* **Archivos:** `02_Componente_Arquitectura_Frontend_Toolkit.puml` / `02_Componente_Arquitectura_Frontend_Toolkit.svg`
* **Tipo UML:** Diagrama de Componentes
* **Pregunta principal:** ¿Cuáles son las dependencias y límites modulares de los componentes UI dentro del paquete `src/components`?
* **Propósito:** Mapa de dependencias e interfaces internas del paquete `src/components`. Detalla la relación entre `ListGenerator`, `ListSortBar`, `ListPagination`, `MassEditWizard`, `ReviewModal`, `SearchBar`, `useSearchEngine`, `searchEngine` (con `LRUCache`), `FormGenerator`, `EditFormGenerator`, `FormInput`, `DoNotHackMyApp`, `ButtonLink` y `webSocketManager`.

### 03. Jerarquía de Clases Genéricas del Backend
* **Archivos:** `03_Clase_Jerarquia_Generica_Backend.puml` / `03_Clase_Jerarquia_Generica_Backend.svg`
* **Tipo UML:** Diagrama de Clases
* **Pregunta principal:** ¿Cómo se estructuran los tipos genéricos base y las abstracciones CRUD en Spring Boot 3?
* **Propósito:** Estructura pura de abstracciones en Spring Boot 3 bajo los paquetes canónicos `toolkit.*`. Modela `BaseEntity`, `NamedEntity`, el contrato `BaseRepository<T, D, I>`, la clase base transaccional `BaseService<T, I>` con soporte de `updateSome` y hooks Template Method, su variante desacoplada `BaseServiceWithDTO<T, D, I>` conectada a `EntityMapper<T, D>`, y los controladores REST `BaseRestController<T, I>` y `BaseRestControllerWithDTO<T, D, I>`, utilizando asociaciones dirigidas estándar según OMG UML 2.5.1.

### 04. Arquitectura de Pruebas Unitarias con Clases Dobles (Dummies & Mocks)
* **Archivos:** `04_Clase_Arquitectura_Testing_Unitario_Dummies.puml` / `04_Clase_Arquitectura_Testing_Unitario_Dummies.svg`
* **Tipo UML:** Diagrama de Clases
* **Pregunta principal:** ¿Cómo validan las suites de pruebas unitarias los contratos genéricos del toolkit sin depender de bases de datos externas?
* **Propósito:** Diseño del arnés de pruebas unitarias (`src/test/java/toolkit`). Demuestra cómo las clases dummy autocontenidas del paquete `toolkit.model.dummy` (`TestEntity`, `TestDTO`, `TestService`, `TestRepository`, `TestController`) permiten a las suites `BaseServiceTest`, `BaseRestControllerTest`, `BaseServiceWithDTOTest` y `BaseRestControllerWithDTOTest` validar el comportamiento CRUD transversal, el control de excepciones y los endpoints HTTP de forma totalmente aislada con Mockito y MockMvc.

---

## 🔄 NIVEL 2: COORDINACIÓN Y SECUENCIA ENTRE COMPONENTES (05 - 12)

### 05. Orquestación Integral de Componentes por ListGenerator
* **Archivos:** `05_Secuencia_ListGenerator_Coordinacion_Componentes.puml` / `05_Secuencia_ListGenerator_Coordinacion_Componentes.svg`
* **Tipo UML:** Diagrama de Secuencia
* **Pregunta principal:** ¿Cómo coordina `ListGenerator` el flujo de eventos, ordenación, filtrado, paginación y lanzamiento de edición masiva entre sus componentes dependientes?
* **Propósito:** Modela a `ListGenerator` como coordinador maestro de UI: validación de seguridad previa delegada en `DoNotHackMyAppHelper` (diagramas 08 y 18), pipeline de datos (`raw -> sortedData -> filteredData -> paginatedData`), coordinación de `ListSortBar`, filtrado reactivo con `SearchBar`, paginación sincronizada con `ListPagination`, atajos de teclado y lanzamiento del modal `MassEditWizard` (delegando en los diagramas 07 y 19).

### 06. Inferencia Dinámica de Esquemas y Ciclo de Vida de Formularios
* **Archivos:** `06_Secuencia_FormGenerator_Inferencia_Esquemas.puml` / `06_Secuencia_FormGenerator_Inferencia_Esquemas.svg`
* **Tipo UML:** Diagrama de Secuencia
* **Pregunta principal:** ¿Cómo interactúan el usuario, el generador de formularios, React Hook Form y la API REST durante el ciclo de vida del formulario?
* **Propósito:** Modela el ciclo de vida de `EditFormGenerator` y `FormGenerator`. Muestra la inferencia del esquema a partir del objeto en memoria delegando el algoritmo detallado en el diagrama 15 (`buildFieldsFromEntity`), la suscripción no controlada mediante referencias en **React Hook Form**, la validación en cliente y la persistencia vía REST PUT/POST.

### 07. Ciclo de Edición Masiva (MassEditWizard): Revisión y Persistencia Atómica
* **Archivos:** `07_Secuencia_MassEditWizard_UndoRedo_Persistencia.puml` / `07_Secuencia_MassEditWizard_UndoRedo_Persistencia.svg`
* **Tipo UML:** Diagrama de Secuencia
* **Pregunta principal:** ¿Cuáles son las interacciones temporales y el intercambio de mensajes entre el usuario, el asistente de edición masiva, el formulario, el modal de revisión y los endpoints transaccionales de persistencia?
* **Propósito:** Modela el flujo de modificación múltiple: edición secuencial de filas, registro de mutaciones delegando la manipulación de la pila de versiones en el diagrama de actividades 19 (`Historial Undo/Redo`), revisión previa diferencial en `ReviewModal`, y envío del lote al endpoint `PUT /some` para su persistencia atómica en el backend (delegando el proceso `@Transactional` en el diagrama de actividades 17).

### 08. Guardia de Seguridad y Control de Acceso en Cliente (DoNotHackMyApp)
* **Archivos:** `08_Secuencia_DoNotHackMyApp_Guardia_Rutas.puml` / `08_Secuencia_DoNotHackMyApp_Guardia_Rutas.svg`
* **Tipo UML:** Diagrama de Secuencia
* **Pregunta principal:** ¿Cómo intercepta `navigateToUnauthorized` el montaje de un componente protegido y qué bifurcaciones de secuencia produce?
* **Propósito:** Modela la intercepción previa al renderizado en `ListGenerator` y `EditFormGenerator`. Evalúa los permisos delegando el árbol de decisión en el diagrama de actividades 18 (`navigateToUnauthorized`), y representa las dos rutas de interacción: interrupción y redirección inmediata a `/do-not-hack-my-app` vs. renderizado autorizado.

### 09. Ciclo de Vida y Gestión de Suscripciones en Cliente (WebSocketManager)
* **Archivos:** `09_Secuencia_WebSocketManager_CicloVida_Suscripciones.puml` / `09_Secuencia_WebSocketManager_CicloVida_Suscripciones.svg`
* **Tipo UML:** Diagrama de Secuencia
* **Pregunta principal:** ¿Cómo se coordinan en el tiempo el registro de suscripciones, la conexión STOMP sobre WebSockets y la entrega de mensajes en el cliente?
* **Propósito:** Modela la colaboración temporal del cliente STOMP (`webSocketManager.ts`): encolado previo de tópicos en memoria, resolución de conexión delegando la lógica algorítmica de URL y transporte en el diagrama 16, handshake autenticado con JWT, suscripciones automáticas, despacho reactivo de eventos JSON y desconexión controlada.

### 10. Seguridad en Servidor STOMP: WebSocketSecurityInterceptor
* **Archivos:** `10_Secuencia_Seguridad_WebSocket_Interceptor.puml` / `10_Secuencia_Seguridad_WebSocket_Interceptor.svg`
* **Tipo UML:** Diagrama de Secuencia
* **Pregunta principal:** ¿Cómo valida el interceptor de canales de Spring cada comando STOMP (`CONNECT`, `SUBSCRIBE`, `SEND`) antes de permitir el paso al broker?
* **Propósito:** Modela la defensa perimetral del broker STOMP en backend (`WebSocketSecurityInterceptor.java`): autenticación HMAC-SHA256 en `CONNECT`, rate limiting en memoria (máximo 60 peticiones/minuto) en `SUBSCRIBE`, y limitación estricta de payloads a 64 KB en `SEND` emitiendo excepciones controladas traducidas a frames de error.

### 11. Ciclo Global de Seguridad: Autenticación JWT y Autorización Multi-Protocolo
* **Archivos:** `11_Secuencia_Autenticacion_JWT_Global.puml` / `11_Secuencia_Autenticacion_JWT_Global.svg`
* **Tipo UML:** Diagrama de Secuencia
* **Pregunta principal:** ¿Cómo se transfiere el token JWT desde la emisión inicial en la aplicación host hasta la intercepción de peticiones en los filtros y controladores del toolkit?
* **Propósito:** Modela el flujo transversal de identidad: emisión de JWT tras login en el `AuthController` de la aplicación host, persistencia en `tokenService` (LocalStorage), e inyección en cabeceras HTTP `Authorization: Bearer` interceptadas por `AuthTokenFilter` y validadas con `JwtUtils` en los endpoints protegidos.

### 12. Manejo Centralizado de Excepciones con Spring Boot (@RestControllerAdvice)
* **Archivos:** `12_Secuencia_Gestion_Excepciones_Global.puml` / `12_Secuencia_Gestion_Excepciones_Global.svg`
* **Tipo UML:** Diagrama de Secuencia
* **Pregunta principal:** ¿Cómo fluye una excepción de dominio (`ResourceNotFoundException`) desde el servicio hasta transformarse en una respuesta HTTP estandarizada?
* **Propósito:** Modela la captura de fallos en el backend: `ResourceNotFoundException` lanzada desde `BaseService` burbujea hacia el `DispatcherServlet` y es capturada por `ExceptionHandlerController`, retornando un DTO `ErrorMessage` normalizado con código HTTP 404 y timestamp ISO.

---

## ⚙️ NIVEL 3: FLUJOS ALGORÍTMICOS Y MÉTODOS LÓGICOS PUROS (13 - 19)

### 13. Diagrama de Flujo del Algoritmo parseSearchQuery (searchEngine.ts)
* **Archivos:** `13_Flujo_parseSearchQuery_searchEngine.puml` / `13_Flujo_parseSearchQuery_searchEngine.svg`
* **Tipo UML:** Diagrama de Actividad / Flujo
* **Pregunta principal:** ¿Cómo tokeniza y analiza sintácticamente una consulta de búsqueda en una única pasada con complejidad garantizada O(n)?
* **Propósito:** Modela el tokenizador y parser manual single-pass de complejidad garantizada **O(n)**. Describe la discriminación de caracteres clave (`isKeyChar`), la detección de delimitador dos puntos (`:`), el salto seguro sin retroceso superlineal (`ReDoS prevention`), y el parseo bifurcado de valores entrecomillados vs. valores simples.

### 14. Diagrama de Flujo del Pipeline de Búsqueda y Caché LRU (useSearchEngine & searchData)
* **Archivos:** `14_Flujo_searchData_Evaluacion_Filtros.puml` / `14_Flujo_searchData_Evaluacion_Filtros.svg`
* **Tipo UML:** Diagrama de Actividad / Flujo
* **Pregunta principal:** ¿Cómo se evalúan las coincidencias de filtros y cómo gestiona la caché LRU las consultas frecuentes en memoria?
* **Propósito:** Modela el pipeline de filtrado en cliente: comprobación y actualización de `LRUCache` en el hook `useSearchEngine.ts`, extracción de propiedades anidadas (`getNestedValue`), normalización flexible de texto `normalizeLoose` (NFD, sin diacríticos ni símbolos), modos de coincidencia (`exact`, `contains`, `startsWith`), y combinación lógica booleana (`AND` / `OR`).

### 15. Diagrama de Flujo de Inferencia de Esquemas: buildFieldsFromEntity (EditFormGenerator.tsx)
* **Archivos:** `15_Flujo_buildFieldsFromEntity_EditFormGenerator.puml` / `15_Flujo_buildFieldsFromEntity_EditFormGenerator.svg`
* **Tipo UML:** Diagrama de Actividad / Flujo
* **Pregunta principal:** ¿Cuál es el árbol de decisión algorítmico para inferir tipos de control HTML a partir de los atributos de un objeto JavaScript?
* **Propósito:** Modela el algoritmo de introspección en frontend: exclusión del campo `'id'` y árbol de decisión que infiere controles (`select`, `number`, `checkbox`, `date`, `password`, `email`, `text`), capitalización automática de etiquetas y fusión de configuraciones personalizadas (`fieldConfig`).

### 16. Diagrama de Flujo de Conexión y Suscripciones: WebSocketManager (webSocketManager.ts)
* **Archivos:** `16_Flujo_WebSocketManager_Gestion_Conexion.puml` / `16_Flujo_WebSocketManager_Gestion_Conexion.svg`
* **Tipo UML:** Diagrama de Actividad / Flujo
* **Pregunta principal:** ¿Cuáles son los pasos deterministas de inicialización de conexión, resolución de URL y gestión de eventos asíncronos del cliente WebSocket?
* **Propósito:** Modela la lógica de `initConnection()`: resolución algorítmica de la URL (`buildSocketUrl`), selección de transporte (SockJS vs. WebSocket nativo RFC 6455), inyección de credenciales JWT, re-suscripción automática tolerante a fallos (`resubscribeAll`) y bifurcación de manejadores de error.

### 17. Diagrama de Flujo de Actualización en Bloque Transaccional: updateSome (BaseService.java)
* **Archivos:** `17_Flujo_BaseService_updateSome_Transaccional.puml` / `17_Flujo_BaseService_updateSome_Transaccional.svg`
* **Tipo UML:** Diagrama de Actividad / Flujo
* **Pregunta principal:** ¿Cómo garantiza el backend la atomicidad transaccional y la validación en el guardado por lotes `updateSome`?
* **Propósito:** Modela la ejecución del método `@Transactional updateSome`: validación de paridad de tamaños entre listas de IDs y entidades, recuperación con fail-fast ante IDs inexistentes (rollback automático), invocación del método hook `updateEntityFields` (patrón Template Method) y guardado consolidado mediante `saveAll`.

### 18. Diagrama de Flujo de Evaluación de Permisos: navigateToUnauthorized (DoNotHackMyAppHelper.ts)
* **Archivos:** `18_Flujo_DoNotHackMyApp_Verificacion_Autorizacion.puml` / `18_Flujo_DoNotHackMyApp_Verificacion_Autorizacion.svg`
* **Tipo UML:** Diagrama de Actividad / Flujo
* **Pregunta principal:** ¿Cuál es el orden jerárquico de comprobación de autorizaciones y condiciones de acceso en cliente?
* **Propósito:** Modela la lógica de control de acceso en cliente: evaluación jerárquica entre función personalizada (`checkAuth`), bypass explícito booleano y regla estándar `checkAuthDefault` (acceso concedido incondicional a `Authority.ADMIN` o comparación exacta de roles), junto con la interrupción del renderizado ante denegación.

### 19. Diagrama de Flujo del Historial de Versiones y Undo/Redo: MassEditWizard (MassEditWizard.tsx)
* **Archivos:** `19_Flujo_MassEditWizard_Historial_UndoRedo.puml` / `19_Flujo_MassEditWizard_Historial_UndoRedo.svg`
* **Tipo UML:** Diagrama de Actividad / Flujo
* **Pregunta principal:** ¿Cómo opera la estructura de datos `EditTuple<T>`, el puntero `activeVersion`, el truncado tras Undo y la conformación del lote final para su envío al backend?
* **Propósito:** Modela el algoritmo de control de versiones en memoria de `MassEditWizard.tsx`: inicialización de tuplas reactivas (`original`, `versions`, `activeVersion`), detección de mutaciones con `hasChanges`, truncado y apilamiento de versiones en `applyUpdate`, operaciones de retroceso y avance en memoria (`undo` y `redo` sin llamadas de red), y filtrado final de cambios confirmados en `confirmAll` para su delegación al endpoint transaccional del backend.
