---
name: ios16-swiftui-mvvm-architecture
description: iOS16+ SwiftUI MVVM architecture design and review guidance for team base frameworks. Use when Codex needs to design, audit, refactor, or extend an iOS16+ SwiftUI project that uses Swift Concurrency, NavigationStack, networking, dependency injection, modular features, testability, or a reusable team architecture foundation.
---

# iOS16 SwiftUI MVVM Architecture

## Overview

Use this skill to design or review an iOS16+ SwiftUI architecture base for team projects. Treat MVVM as the presentation pattern, and require explicit boundaries around domain, data, infrastructure, routing, dependency injection, concurrency, observability, and testing.

## Operating Mode

1. Inspect the repository before proposing architecture.
2. Identify the current layering, dependency direction, state ownership, navigation model, networking model, persistence model, concurrency boundaries, and test coverage.
3. Compare the implementation against the baseline below.
4. Return findings first, ordered by severity, with concrete file references when reviewing existing code.
5. When asked to implement, make scoped changes that preserve existing product behavior and improve the architecture incrementally.

## Baseline Architecture

Prefer this dependency direction:

`App -> Feature -> Domain -> Data -> Infrastructure`

Use these responsibilities:

- `App`: app entry, dependency graph composition, root router/session, environment switching, app lifecycle.
- `Feature`: SwiftUI views, view models, feature route registration, feature-specific UI state.
- `Domain`: use cases, business rules, domain models, repository protocols.
- `Data`: repository implementations, DTO mapping, API definitions, persistence adapters.
- `Infrastructure`: network client, auth/token management, logging, analytics, configuration, cache, keychain, clock/UUID abstractions.
- `DesignSystem`: colors, typography, spacing, reusable controls, loading/empty/error states.
- `TestingSupport`: mocks, fake transports, deterministic clocks/UUIDs, fixture loaders, preview dependencies.

## MVVM Rules

- Keep SwiftUI `View` values declarative and thin.
- Let `ViewModel` own presentation state and user intents, and mark it `@MainActor`.
- Avoid singletons inside feature view models; inject protocols or dependency containers.
- Keep DTO parsing, repository calls, token refresh, persistence, and analytics outside views.
- Model UI state explicitly, for example `idle/loading/content/empty/error`, instead of scattering booleans.
- Prefer domain/use-case methods over feature view models calling network services directly.

## Commenting Rules

- 新增或修改重要架构代码时，必须同步添加简洁的中文注释，方便中文团队成员快速理解设计意图。
- 重点注释依赖注入组合根、actor/并发边界、路由/登录拦截决策、网络重试/token 刷新逻辑、Repository 数据映射、测试替身等不直观的位置。
- 注释优先解释“为什么需要这个边界/设计”，不要重复代码表面含义。
- 简单属性赋值、明显的 SwiftUI 布局、自解释模型字段不要逐行注释，避免噪音。

## Swift Concurrency Rules

- Use async/await as the default asynchronous API.
- Mark UI-facing observable objects `@MainActor`.
- Keep network, persistence, and CPU work off the main actor unless state mutation requires it.
- Preserve cancellation at every boundary; do not convert cancellation into generic failure.
- Avoid unstructured `Task {}` inside routers and views unless it is tied to UI lifecycle or a user event.
- Protect shared mutable state with actors, main actor isolation, or immutable value flow.
- Add injectable `Clock`-like seams for debounce, retry, and timeout logic when tests need determinism.

## Routing Rules

- Use `NavigationStack` and typed `Hashable` routes for SwiftUI navigation.
- Keep route parsing, auth gating, tab selection, and deep-link continuation centralized.
- Avoid feature views mutating unrelated tab paths directly.
- Define route ownership so each feature registers destinations without one monolithic route file becoming a merge hotspot.
- Put back/gesture interception policy on typed routes or router-owned navigation state, not inside scattered SwiftUI pages.
- For iOS16 SwiftUI, intercept `NavigationStack` path shrink for system back and use a thin UIKit bridge only when controlling the edge-swipe gesture is required.

## Networking Rules

- Separate endpoint description, request building, transport, response decoding, error mapping, auth refresh, retry policy, and logging.
- Avoid `@MainActor` on the entire networking service; only session/token UI state should be main-actor-bound.
- Inject `URLSession`/transport, base URL, encoders/decoders, auth provider, logger, and crypto.
- Store tokens in Keychain or an injected secure storage abstraction; never keep production tokens only in memory.
- Return typed domain results from repositories; do not leak raw `Data` into features except at infrastructure boundaries.

## Preflight Architecture Work

- Establish app configuration and feature flags before business modules multiply.
- Establish a single observability entry for logs, analytics, and error reporting; do not call third-party SDKs directly from ViewModel/View/Repository.
- Establish design tokens for spacing, radius, typography, and common colors before UI pages copy magic numbers.
- Provide preview/testing dependencies from the composition root, not from feature-local singletons.
- Decide cache/offline policy, localization/accessibility rules, CI checks, and module ownership early, because these are expensive to retrofit.
- Define a single error presentation mapper before screens multiply; ViewModels should not each invent alert titles, retry text, and login-expired copy.
- Inject time and random ID generation before adding retry, debounce, refresh token, or analytics trace logic; otherwise tests become slow and flaky.
- Start cache/offline behind a protocol even with an in-memory implementation, then graduate hot paths to disk/SQLite/CoreData when product policy is clear.
- Split route destination registration by feature once the route file grows; avoid a single `AppRouteViews.swift` becoming a constant merge conflict.
- Add architecture checks to CI early: build, unit tests, optional lint, no ViewModel direct third-party SDK access, no feature direct Keychain/network singleton access.

## Review Checklist

Check for these gaps before calling a project a team-ready base:

- Dependency injection and environment composition are explicit and testable.
- App configuration, feature flags, design tokens, observability, and preview dependencies are centralized.
- Feature modules can be added without editing many unrelated central files.
- Network layer has real `URLSession` transport, retry/timeout, typed decoding, auth refresh coordination, and observability.
- App has environment configuration for dev/staging/prod.
- Auth/session has secure persistence and launch-time restoration.
- Persistence/cache strategy exists where product data needs offline or fast startup behavior.
- Time, UUID, cache, and error presentation are injectable and covered by tests.
- Design system exists and avoids feature-local duplicated styling.
- Error handling and empty/loading states are consistent across features.
- Unit tests cover router, URL parsing, paging, networking, token refresh, repositories, and view models.
- UI tests cover critical navigation and auth-gated flows.
- Preview/fake dependencies allow screens to render without live services.
- CI can build, test, lint, and enforce architecture boundaries.

## Output Format

When reviewing a codebase, respond in this shape:

1. Short architecture summary.
2. Findings ordered by severity, each with file reference and impact.
3. Missing base capabilities grouped by priority.
4. Recommended target structure.
5. Next implementation steps that can be done incrementally.

Keep recommendations concrete and compatible with iOS16+ SwiftUI.
