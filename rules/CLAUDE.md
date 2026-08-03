# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Java 17 / Spring Boot 3.3 rewrite of an existing .NET microservice (`cmcdtqg.ai.api-develop`) that provides
Knowledge Management + AI chat features (`km-ai`) for the CMCDTQG platform. It is one microservice in a larger
system that includes an Identity Service (issues JWTs), a Gateway, and other domain services. The Java code
must stay behaviorally and JSON-shape compatible with the original .NET service where noted below, since the
existing frontend was built against .NET.

A second, unrelated module (`com.ai.ptcb`) is being added inside the same codebase for a "chỉ tiêu giám sát"
(monitoring indicator) feature — see [Two entity conventions](#two-entity-conventions-comaidomain-vs-comaiptcbdomain) below.

`docs/` contains the migration reference material (Vietnamese): `docs/clean_architecture_guide.md` (how to add
a new API, in this repo's actual conventions), `docs/architecture.md` (the exhaustive .NET→Java parity checklist
— historical/aspirational, see caveat below), `docs/integration_guidelines.md` (audit override, i18n keys),
`docs/authentication_flow.md` (JWT/permission details), `docs/design-km/*` (DB & API design for the knowledge
module), `docs/ai-integration/*` (streaming chat contracts with the external AI service).

**Caveat on `docs/architecture.md`**: it documents the *intended* JSON naming convention as PascalCase
(`Success`, `Data`) to match the legacy .NET FE. The code as implemented uses **camelCase** JSON
(`success`, `data`, `message`, `code`, `metaData` — see `BaseResponseDTO`) and there is no
`PropertyNamingStrategy` configured anywhere. Trust the code/`docs/integration_guidelines.md` over that one
section of `docs/architecture.md` when in doubt.

## Build, run, test

- Build: `mvn clean package` (tests run as part of `package`; CI/Docker build skips them with `-DskipTests`)
- Run locally: `mvn spring-boot:run` (needs Postgres/Redis/Kafka reachable per `.env`, see below)
- Run all tests: `mvn test`
- Run a single test class: `mvn test -Dtest=AiKnowledgeTagServiceImplTest`
- Run a single test method: `mvn test -Dtest=AiKnowledgeTagServiceImplTest#methodName`
- Full stack via Docker: `docker-compose up -d` — builds the app image, plus Postgres and Redis containers
  (Kafka/Kafdrop are commented out in `docker-compose.yml`; point `KAFKA_SERVERS` at an external broker instead)
- Swagger UI: `http://localhost:8080/swagger-ui.html` (container) — internal app port is `8085`
  (`server.port` in `application.yml`), mapped to `8080` externally by docker-compose

Tests are plain JUnit 5 + Mockito + AssertJ, constructed manually (no `@SpringBootTest`/`@ExtendWith(MockitoExtension.class)`
in the sample tests) — mocks are built with `mock(Class)` in `@BeforeEach`, not annotated fields.

Config is loaded from `.env` (via `dotenv-java`/`spring-dotenv`, referenced as `${VAR:default}` throughout
`application.yml`). **`.env` is tracked in git and currently contains live dev DB credentials, an RSA keypair,
and API keys** — despite `.env` being listed in `.gitignore` (it was committed before the ignore rule was added).
Be careful not to leak its contents, and flag this to the user rather than "fixing" it unilaterally.

## Architecture

Clean Architecture, one Maven module, package-per-layer under `com.ai`:

| Layer | Package | Contains |
| :--- | :--- | :--- |
| API | `com.ai.api` | `*Controller` classes — thin, delegate to Service, extend `BaseController` |
| Application | `com.ai.application` | `dto/`, `service/` (+ `service/impl/`), `repository/` (Spring Data JPA interfaces), `mapper/` (MapStruct), `event/`, `scheduler/` |
| Domain | `com.ai.domain` | `entity/` (JPA entities), `enumeration/` — no framework/infra dependencies |
| Infrastructure | `com.ai.infrastructure` | `config/`, `external/` (Feign clients, Kafka producer, MinIO), `kafka/`, `persistence/` (JPA auditing), `context/` (`UserContext`), `init/` (seed data) |

Dependency rule: `infrastructure`/`api` → `application` → `domain`. Controllers never call repositories directly;
everything goes through a Service. Services never return entities to the API layer — always map to a DTO
(MapStruct mapper) first.

Steps to add a new CRUD feature (see `docs/clean_architecture_guide.md` for the full walkthrough): Entity in
`domain.entity` extending `BaseEntity` → repository interface in `application.repository` extending
`JpaRepository` → request/response DTOs in `application.dto` + MapStruct mapper → service interface +
`*ServiceImpl` in `application.service`(`.impl`) → controller in `com.ai.api` extending `BaseController`,
annotated with `@Permission`, returning `BaseResponseDTO`.

### Two entity conventions: `com.ai.domain` vs `com.ai.ptcb.domain`

There are two, deliberately different, base-entity/naming conventions in this codebase:

- **`com.ai.domain.entity.BaseEntity`** (the original AI/knowledge-management modules): English column names
  (`created_at`, `created_by`, `is_deleted`...), audit fields auto-populated via `@CreatedBy`/`@LastModifiedBy`
  + `JpaAuditorAware<String>` (`JpaAuditorAware` returns the JWT `unique_name` claim).
- **`com.ai.ptcb.domain.entity.BaseAudit`** (the newer "chỉ tiêu giám sát" / indicator module, e.g. `CbChiTieu`,
  `CbNhomChiTieu`): Vietnamese table/column names (`cb_chi_tieu`, `ngay_tao`, `da_xoa`...). Its user-id audit
  fields (`idNguoiTao`/`idNguoiSua`) are **not** annotated `@CreatedBy`/`@LastModifiedBy` — `JpaAuditorAware`
  only implements `AuditorAware<String>` (username), not `Integer` (id), so those two columns must be set
  manually in the service layer from `UserContext.getTaiKhoanId()`. Only `ngayTao`/`ngaySua` use
  `@CreatedDate`/`@LastModifiedDate`. Soft delete here is `daXoa` (not `isDeleted`).

When extending the `ptcb` module, follow its own convention (Vietnamese names, `BaseAudit`, manual user-id
audit) rather than copying `com.ai.domain`'s.

## Cross-cutting conventions

- **Response envelope**: every controller method returns `BaseResponseDTO<T>` — `success`, `data`, `message`
  (i18n-resolved), `code`, `metaData` (used for pagination). Build via `BaseResponseDTO.successResponse(...)` /
  `.failResponse(...)`, don't hand-roll the shape.
- **Errors**: throw `BusinessException` (with an i18n message key) from Service/Controller code; don't
  `try/catch` broadly. `GlobalExceptionHandler` (`@RestControllerAdvice`) converts exceptions to the response
  envelope centrally.
- **i18n**: pass message *keys* (e.g. `"linhvuc.add_success"`), not literal strings, to
  `BaseResponseDTO`/`BusinessException`. Keys live in `src/main/resources/i18n/messages{,_en,_vi}.properties`
  and are resolved by `LocalizationUtils` based on the `Ngonngu`/`ngonngu` request header (default `VN`),
  extracted in `BaseController.getLanguageKey()`.
- **Auth**: JWT (RSA256) via Spring OAuth2 Resource Server; the app only holds the RSA **public** key for
  verification. Relevant claims: `sub` (user id), `unique_name` (username), `DonViId` (org unit), `role`.
  `UserContext` (request-scoped) exposes `getTaiKhoanId()`/`getUsername()`/`getDonViId()`/`isAdmin()` without
  threading params through call stacks. Service-to-service calls under `/api/Internal/**` instead use a shared
  `InternalToken` header, checked by `InternalFilter` — no user JWT involved.
- **Authorization**: annotate service/controller methods with `@Permission(group = "...", code = "...")`;
  `PermissionAspect` (AOP, `@Before`) calls out to the Gateway via Feign (`ExternalServiceClient`) to check the
  caller's roles/permissions extracted from their JWT, except users with role `Sys_Admin`/`ADMIN`, who bypass
  the check.
- **Manual audit override**: for data ingested from external systems or background jobs (no logged-in user),
  set `AuditorContextHolder.setAuditor("SOURCE_NAME")` before saving and **always** `.clear()` it in a
  `finally` block afterwards — it's a static/ThreadLocal holder, so leaking it bleeds into unrelated requests.
- **Audit log (Kafka)**: business-data changes are published asynchronously to Kafka via `BaseKafkaProducer`
  as `NhatKyDTO`, independent of the app's own SLF4J/Logback logging.
- **Inbox processing**: `com.ai.application.service.processor.InboxProcessor` implementations (`Investor`,
  `Legal`, `News`, `IndustrialZone`) each `supports(SourceCode)` one Kafka-fed source and `process(...)` its
  `AiKnowledgeSyncInbox` messages; `EnvelopeInboxProcessor` is the shared base, `InboxWorkerServiceImpl`/
  `InboxScheduler` drive the polling loop.
- **JSONB columns**: map with Hypersistence Utils / `@JdbcTypeCode(SqlTypes.JSON)` + `columnDefinition = "jsonb"`
  (see `CbChiTieu.mappingNguonCol`), not a hand-written Hibernate `UserType`.
- **Mapping**: MapStruct only, no manual field-by-field DTO↔entity copying.
- **IDs**: `Long`/`bigint`, except the `ptcb` module's `CbChiTieu`, which is keyed by a human-assigned string
  code (`ma`), not a surrogate id.

## Deployment

GitLab CI (`.gitlab-ci.yml`) has a single manual `deploy_staging` job, gated on pushes to `staging` and the
`staging-host` runner tag: it resets the deploy server's checkout to `origin/staging`, materializes
`ENV_FILE_STAGING` as `.env`, then `docker compose build && up -d` and polls `/swagger-ui.html` for health.
Nothing is auto-deployed to `main`/`dev`; see README.md section 6 for the full variable list required in GitLab
CI/CD settings.
