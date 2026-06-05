---
title: Spring Boot audit patterns
slug: spring-boot-audit-patterns
aliases: [spring-security-audit, spring-mvc-audit]
---

{% raw %}

> **TL;DR:** Spring's dependency-injection + auto-config does a lot of work invisibly. Audits target: missing `@PreAuthorize`, `@RequestParam`/`@RequestBody` reaching ORM raw queries, SpEL injection via `@Value` / `@Cacheable` / Spring Data `@Query`, Actuator endpoint exposure, and Spring Security filter-chain ordering bugs. Layer this on top of [[java-code-auditing]].

## Common bug patterns

### 1. Authorization on the wrong layer
Spring Security's filter chain runs before controller dispatch — but `@PreAuthorize` runs *after* method binding. Mass-assignment can happen on a request body before authz fires.
- Audit: every controller method binding `@RequestBody`, then check whether `@PreAuthorize` checks the *resource* (not just the user role). `@PreAuthorize("hasRole('USER')")` is presence; `@PreAuthorize("@authz.canEdit(#id, principal)")` is resource-bound.
- Method-level security must be enabled (`@EnableMethodSecurity` or older `@EnableGlobalMethodSecurity`); without it, `@PreAuthorize` is a no-op annotation.

### 2. Mass assignment via `@RequestBody`
Default Jackson binding hydrates every settable field on the target. Binding directly to a JPA `@Entity` exposes every column, including `roles`, `isAdmin`, `passwordHash`. Use a DTO; copy to entity inside the service.
```java
// BAD
public ResponseEntity<User> update(@RequestBody User u) { return repo.save(u); }

// GOOD
public ResponseEntity<User> update(@RequestBody UserUpdateDTO d) {
    User u = repo.findById(d.id()).orElseThrow();
    u.setName(d.name()); // explicit allowed fields only
    return repo.save(u);
}
```

### 3. SpEL injection
SpEL evaluation happens in several places where attacker input can land:
- `@Value("#{systemProperties['user.name']}")` — fine; `@Value("#{T(...).method(${userInput})}")` if anyone is doing that — RCE.
- Spring Data `@Query("... where x = ?#{ [0] }")` — SpEL inside JPQL parameter; attacker-controlled positional substitution.
- `@Cacheable(key="#input")` where `input` contains `T(java.lang.Runtime).getRuntime().exec(...)` style → RCE.
- See [[expression-injection]].

### 4. JPA / ORM raw queries
- `EntityManager.createNativeQuery("SELECT * FROM users WHERE name='" + name + "'")` → SQLi.
- `@Query(value="... where x = '" + "...")` with concat — same.
- Spring Data JPA derived methods (`findByNameAndAge(...)`) are safe; raw `@Query(nativeQuery=true)` is not unless parameterised with `:name`.

### 5. Actuator endpoint exposure
- `management.endpoints.web.exposure.include=*` ships in many dev profiles and accidentally to prod.
- `/actuator/env`, `/actuator/heapdump`, `/actuator/threaddump`, `/actuator/loggers` leak secrets / dump memory.
- `/actuator/gateway/refresh` + Spring Cloud Config `/actuator/env` `POST` with `eureka.client.serviceUrl` change → SSRF / RCE chain (the classic Spring Cloud SnakeYAML chain, CVE-2022-22963 family).
- Audit `application*.yml` for actuator config; default to `health,info` exposure only.

### 6. Spring Cloud / Gateway specifics
- SpEL in routing predicates evaluated server-side.
- `spring.cloud.function.routing-expression` — multiple CVEs (CVE-2022-22963).
- `RoutePredicateHandlerMapping` user-supplied headers reaching SpEL.

### 7. Spring4Shell-family (CVE-2022-22965)
- Class-binder reaching `class.module.classLoader.resources.context.parent.pipeline.first.*` via parameter name in form data. Requires JDK 9+, WAR deployment, `disallowedFields` left default.
- Audit `@InitBinder` for missing `dataBinder.setDisallowedFields("class.*", "Class.*")` on JDK 9+ apps using class-binding.

### 8. CSRF
- Default ON for stateful flows; auto-disabled for stateless `@RestController` if Spring Security 6 detects API style. Verify state machine.
- API endpoints with cookie auth and CSRF disabled = CSRF on every action.

### 9. SSRF in `RestTemplate` / `WebClient`
- `restTemplate.getForObject(userUrl, ...)` no allowlist.
- `WebClient.create(userBaseUrl)` — base URL controlled.
- Reactor Netty default follows redirects; combine with DNS rebinding ([[dns-rebinding]]).

### 10. Filter-chain ordering bugs
- Custom auth filter registered *after* `SecurityFilterChain` resource resolution → routes that don't match a filter pattern bypass auth.
- `@WebFilter` vs `FilterRegistrationBean` order. Audit `order` value; lower runs earlier. A logging filter at order 0 + auth at order 100 means the logging runs unauthenticated.

## Grep starter
```bash
rg -n '@RequestBody\s+\w+ \w+ *,?' -g '*Controller.java' | head -50  # mass-assign candidates
rg -n '@PreAuthorize|@Secured|@RolesAllowed' src/main/java         # presence; verify per-route coverage
rg -n 'createNativeQuery|nativeQuery\s*=\s*true' .                 # raw JPA
rg -n 'management\.endpoints\.web\.exposure' src/main/resources    # actuator scope
rg -n 'SpelExpressionParser|StandardEvaluationContext' .           # SpEL surface
rg -n 'RestTemplate|WebClient\.create' .                           # SSRF
```

## References
- [Spring Security reference](https://docs.spring.io/spring-security/reference/)
- [Spring Boot Actuator exposure](https://docs.spring.io/spring-boot/docs/current/reference/htmlsingle/#actuator.endpoints)
- [Trail of Bits — Spring4Shell deep dive](https://blog.trailofbits.com/2022/04/01/spring4shell-our-pov/)
- [PortSwigger research — SpEL](https://portswigger.net/research)
- See also: [[java-code-auditing]], [[expression-injection]], [[dangerous-java-sinks]]

{% endraw %}
