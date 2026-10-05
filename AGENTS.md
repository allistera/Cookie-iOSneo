# AGENTS.md

## Purpose and scope

Build and maintain a fully native iOS application using Swift and SwiftUI. Deliver the smallest correct implementation of the requested behaviour, using current stable Apple APIs, readable code, and verifiable quality gates.

These instructions apply to all first-party application code, extensions, local Swift packages, previews, tests, and supporting build configuration in this repository.

**MUST**, **MUST NOT**, and **REQUIRED** are mandatory. Do not silently relax them. Follow the active agent's instruction hierarchy and applicable directory-level instructions. Report material conflicts rather than choosing whichever instruction makes delivery easier. Exceptions require explicit maintainer approval and a narrow, documented justification.

This document does not independently authorise production deployment, App Store submission, destructive operations, or changes to account access and signing credentials.

## 1. Inspect before changing

- Read the repository documentation, applicable agent instructions, dependency manifests, build settings, lint configuration, and GitHub Actions workflows before implementation.
- Inspect the working tree and preserve unrelated user changes. Do not overwrite, revert, stage, or commit work you did not create for the task.
- Identify the real app targets, shared schemes, source roots, deployment targets, package dependencies, test plans, and required CI checks. Do not invent names, paths, destinations, or commands.
- Search for an existing implementation before adding a helper, component, service, model, or dependency.
- For substantial work, state the intended change, affected areas, and verification approach briefly. For small changes, proceed without unnecessary ceremony. Resolve routine questions from the repository; ask only when a material requirement cannot be inferred safely.

Inspect the selected Apple toolchain on a supported macOS host:

```bash
xcodebuild -version
xcrun swift --version
xcrun --sdk iphoneos --show-sdk-version
xcrun --find swift-format
swiftlint version
```

These are inspection commands, not proof that the application builds or passes lint.

## 2. Current stable toolchain and APIs

- For a new project, use the latest publicly released stable Xcode, its supported Swift compiler, and the current stable iOS SDK. Verify versions against official Apple and Swift documentation at setup. Do not infer current versions from memory. [1]
- Pin the exact Xcode version/build and compatible formatter/linter versions in the repository's tooling configuration and CI. Record the SDK, Swift compiler, language mode, and minimum supported OS. Normal builds MUST NOT resolve a floating `latest` toolchain.
- Use **Swift 6 language mode** for new targets. The compiler version and language mode are separate settings. Do not disable concurrency checking or downgrade language mode to conceal errors.
- Preserve established deployment targets. For a new app with no stated compatibility requirement, default to the latest stable iOS major release and record that product assumption. Do not raise an existing minimum OS without approval.
- “Latest components” means the newest suitable **shipping, public Apple APIs** compatible with the approved toolchain and deployment target. It does not mean adopting every new API, framework, or feature.
- Before using an unfamiliar or recently introduced API, verify its actual signature, supported platforms, minimum OS, and deprecation status in official documentation or the selected SDK. Never invent a symbol or modifier.
- Gate newer runtime APIs with appropriate availability checks and a functional native fallback where older supported systems require one. Runtime availability checks cannot make a missing symbol compile against an older SDK.
- Do not introduce beta-only APIs, release-candidate toolchains, private APIs, or experimental compiler features into the production baseline without explicit approval.
- Upgrade dependencies and toolchains deliberately. Do not turn ordinary feature work into an unrelated migration.

## 3. Fully native implementation

All new first-party iOS application implementation MUST be written in Swift. Use SwiftUI for the application lifecycle, scenes, and UI by default. [2]

**Prohibited application technologies:** React Native, Flutter, Ionic, Capacitor, Cordova, JavaScript-driven application screens, HTML/CSS screen implementations, and web views used as the application shell.

UIKit is native and is permitted through a small Swift-written bridge when a concrete requirement cannot reasonably be met with supported SwiftUI APIs. Document the capability gap, isolate the adapter, and verify lifecycle, layout, and accessibility. Do not depend on private view hierarchies or introspection hacks.

Use the appropriate Apple browser or authentication APIs for required external web content and sign-in flows. This exception does not permit implementing the app's own screens as a website.

Prefer Apple frameworks. Add a runtime dependency only for a current unmet requirement after checking the native alternative, maintenance status, licence, security implications, and integration cost. Obtain approval before adding it. Use Swift Package Manager for approved new runtime dependencies and commit the application's `Package.resolved`. Build-time tools such as SwiftLint are not cross-platform UI runtimes.

## 4. DRY, YAGNI, and KISS

### DRY — Don't Repeat Yourself

- Maintain one authoritative implementation of each business rule, validation rule, mapping, and source of mutable state.
- Reuse existing components and utilities when they represent the same responsibility.
- Extract common code when it should change together. Similar syntax with different business meaning is not automatically duplication.
- Prefer a focused function, view, or concrete type over a universal abstraction with configuration flags.
- Derive values rather than maintaining duplicate mutable copies. Introduce a cache only for a demonstrated need, with explicit ownership and invalidation.

### YAGNI — You Aren't Gonna Need It

- Every addition MUST satisfy a current acceptance criterion or a demonstrated correctness, security, accessibility, or operational requirement.
- Do not add speculative features, empty modules, placeholder services, unused configuration, generic repositories, dependency-injection containers, or extension points “for later”.
- Do not introduce persistence, analytics, authentication, caching, offline synchronisation, AI, widgets, or background work unless the feature requires them.
- Remove dead code introduced by the change. Do not leave commented-out alternatives or production stubs in place of required behaviour.

### KISS — Keep It Simple

- Choose the simplest design that meets the requirement without hiding errors or weakening safety.
- Prefer composition, value types, explicit dependencies, descriptive names, and straightforward control flow.
- Do not mandate a view model per view, a protocol per type, a repository per entity, or an architectural framework for a small feature.
- Avoid clever operators, unnecessary inheritance, oversized managers, service locators, and mutable application-wide singletons.
- Do not refactor unrelated working code solely to match a preferred style.

## 5. Architecture and state ownership

Keep UI composition, business decisions, and external I/O distinguishable. Views may own presentation state and small presentation-only calculations; they MUST NOT perform networking, persistence operations, or substantial business processing inside `body`.

Organise code by the repository's existing feature boundaries. Introduce a shared component only for genuine shared responsibility. Introduce a protocol when a real boundary, alternate implementation, or test substitute justifies it. Use explicit initialiser injection; do not make every dependency globally accessible.

For new SwiftUI state models, use Observation where supported: [3]

- Use `@State private` for view-owned state, including a view-owned `@Observable` reference when its lifetime belongs to that view.
- Use `@Binding` when a child needs to mutate parent-owned value state.
- Pass an injected observable model directly when bindings are unnecessary; use `@Bindable` when a binding to its properties is required.
- Use environment injection for genuinely shared, appropriately scoped dependencies, not as an undocumented service locator.
- Do not copy changing parent inputs into persistent local state. Document intentional one-time initial-state seeding.
- Do not introduce `ObservableObject`, `@Published`, or `@StateObject` for a new Observation-compatible model. Preserve those APIs when required by an existing integration or supported platform constraint; do not mislabel them as universally deprecated.

Use stable model identifiers for dynamic collections and navigation. Do not generate identity during rendering or use array offsets for mutable, reorderable data. Keep frequently changing state close to the smallest view subtree that reads it.

## 6. Native components and system appearance

Choose the native component that matches the interaction. This table specifies implementation defaults, not features to add. Verify each API against the approved SDK. [2]

| Requirement | Default implementation |
| --- | --- |
| Hierarchical navigation | `NavigationStack`; typed route values where programmatic navigation is needed |
| Adaptive multicolumn navigation | `NavigationSplitView` when the content structure warrants it |
| Top-level destinations | Native `TabView` and current `Tab` APIs |
| Forms and collections | `Form`, `List`, `Section`, and appropriate native grids |
| Actions and input | `Button`, `Toggle`, `Picker`, `Menu`, and native text controls |
| Search and status | `.searchable`, `ProgressView`, and `ContentUnavailableView` |
| Presentation | Native sheets, popovers, alerts, and confirmation dialogs |
| Sharing and media selection | `ShareLink`, `Transferable`, and `PhotosPicker` |
| Maps and charts | MapKit and Swift Charts when required |
| Structured local persistence | SwiftData when persistence requirements fit its capabilities |

Use current recommended navigation, dismissal, styling, animation, and change-observation APIs. Do not introduce deprecated APIs when a supported replacement exists. Do not describe a merely older API as deprecated without checking.

Use `Button` for actions rather than a tap gesture attached to decorative content. Use gesture APIs for actual gesture interactions. Preserve native back navigation, swipe behaviour, focus, keyboard handling, and selection where applicable.

### Liquid Glass and visual behaviour

Use the system's current appearance through native components. Apply documented Liquid Glass APIs such as `glassEffect` and `GlassEffectContainer` only when a custom control needs them and availability permits. Do not recreate system glass using arbitrary blur, opacity, shadows, or gradients. Do not apply glass indiscriminately to content cards and list rows. [4]

Do not replace standard tab bars, navigation bars, sheets, or controls with hand-built imitations merely to change their appearance. Keep branding within native interaction patterns.

## 7. Accessibility, layout, and localisation

- Use semantic colours, system text styles, and adaptive layouts. Respect light/dark appearance, Dynamic Type, Reduce Motion, Reduce Transparency, and increased contrast.
- Preserve readable content and usable controls at accessibility text sizes. Provide at least 44-by-44-point activation areas for custom touch controls unless a reviewed platform-specific exception applies.
- Give custom controls meaningful accessibility labels, values, traits, and focus order. Do not communicate essential meaning through colour, animation, sound, or haptics alone.
- Respect safe areas, keyboard changes, rotation, and supported window sizes. Read layout information from the relevant view/container rather than a global screen-size assumption.
- Use native layout tools before custom measurement machinery. Do not add a dependency or a custom layout engine for ordinary spacing.
- Localise user-facing strings with String Catalogs. Use locale-aware formatting for dates, numbers, measurements, currency, and plurals. Do not construct translated sentences through string concatenation.
- Keep previews deterministic and self-contained. Include meaningful loading, empty, error, and populated examples without live network access or production credentials.

## 8. Concurrency and responsiveness

Use Swift structured concurrency and explicit isolation. [5]

- Isolate UI-facing mutable state appropriately, normally with `@MainActor`. Use actors or other verified isolation for shared mutable non-UI resources.
- Prefer `async`/`await` and task groups over callback pyramids and ad hoc dispatch queues.
- Use `.task` or `.task(id:)` for view-lifecycle work where appropriate. Give other tasks a clear owner and cancellation policy.
- Propagate cancellation. Do not show cancellation as a user-facing failure or let stale requests overwrite newer state.
- `async` does not guarantee work runs off the main actor. Move expensive CPU work and blocking I/O to an appropriate, explicitly verified execution context.
- Do not use `Task.detached`, `@unchecked Sendable`, `nonisolated(unsafe)`, or broad `@preconcurrency` annotations merely to silence diagnostics. Any necessary use requires a reviewed safety argument.
- Do not use semaphores, synchronous waits, or arbitrary sleeps to make asynchronous code appear synchronous.
- Verify isolation and sendability under the pinned compiler. Do not assume a concurrency model from a different language mode or toolchain.

## 9. Data, errors, and security

Use `URLSession`, typed requests/responses, and `Codable` where suitable. Keep transport details outside views. Validate HTTP responses; distinguish transport, decoding, authorisation, and domain failures. Bound retries and only retry operations when their semantics make it safe. Honour cancellation and avoid duplicate submissions.

Model loading, empty, success, and failure states explicitly where relevant. Provide actionable recovery. Do not swallow errors with empty `catch` blocks, unexplained `try?`, or success-shaped fallback values. Use safe diagnostics and understandable user-facing messages.

Use SwiftData only when structured persistence is required and suitable. Respect context isolation, test migrations, and make save failures visible. Do not erase a persistent store to conceal migration problems. Preserve a suitable existing persistence layer rather than rewriting it without a requirement.

Store credentials and tokens in Keychain, not `UserDefaults`, source code, logs, or committed configuration. Use `UserDefaults`/`@AppStorage` only for appropriate non-sensitive preferences. Do not embed privileged server secrets in the application.

Use system transport security and trust validation. Do not disable certificate checks or broadly weaken App Transport Security to fix connectivity. Minimise permissions, request them in context, and keep required usage descriptions and privacy declarations accurate.

Use structured `Logger` diagnostics where useful. Redact private data; do not log passwords, tokens, authentication headers, or sensitive payloads. Add telemetry only for an actual requirement.

## 10. Swift code quality

- Prefer immutable values and the narrowest useful access level. Keep functions cohesive and types responsible for one understandable concern.
- Use enums and typed values instead of stringly typed state and Boolean combinations that permit invalid states.
- Avoid force unwraps, forced casts, and `try!` in production. Validate input and propagate or handle errors. Tests should use proper requirement/assertion APIs rather than crash unexpectedly.
- Do not use `fatalError` for recoverable conditions or unfinished required functionality.
- Avoid unnecessary type erasure, including `AnyView`, when ordinary composition or a view builder expresses the design.
- Do not add compatibility wrappers, speculative optimisation, or custom caching without a demonstrated need.
- Comments should explain intent, constraints, or non-obvious decisions. Keep documentation consistent with behaviour.
- Remove unused imports, declarations, temporary debug output, and unreachable branches created by the change.

## 11. Mandatory formatting and linting

**Fully linted means every first-party Swift source file has been checked successfully by the configured tools, not merely the edited files.** It does not mean “the formatter ran” or “the compiler accepted the code”.

### Tooling and configuration

For new projects, use the toolchain's **swift-format** and **SwiftLint**, with committed `.swift-format` and `.swiftlint.yml` configuration. Pin compatible versions and use the same toolchain locally and in CI. Preserve an existing approved equivalent formatter instead of adding a competing second formatter. [6], [7]

For an otherwise unconfigured new project, use four-space indentation, a 120-column formatting target, and a final newline. Keep formatter and linter rules compatible. Line wrapping must not damage URLs, literals, or readability.

Provide repository-owned commands, preferably `scripts/format.sh` and `scripts/lint.sh`, or reuse equivalent existing commands:

- The formatting command writes deterministic formatting changes. It must not touch vendored dependencies or unrelated user modifications.
- The lint command is read-only and checks the full first-party source set, including application code, extensions, packages, previews, tests, and Swift manifests.
- Exclude only genuine generated output, build products, and vendored third-party sources. Do not exclude first-party directories or tests to hide violations.
- Verify file enumeration includes new files and paths containing spaces. An unexpectedly empty source set MUST fail rather than report success.
- If the commands or configurations do not exist, establish them as part of the first implementation task before claiming that lint is enforced. Their mention in this document does not create them.

### Fail-closed gates

Run swift-format's lint mode with `--strict` and SwiftLint with strict failure behaviour. Their warnings MUST fail verification. Enable relevant correctness rules, including force-cast, force-try, and force-unwrapping checks; verify rule names against the pinned version. [6], [7]

Missing tools, incompatible versions, invalid configuration, unparseable files, and command failures MUST fail the gate. Do not use lenient mode, ignore-unparseable options, swallowed exit statuses, `|| true`, or warning-only “tool missing” scripts.

Do not add inline rule suppressions, new lint baselines, broader exclusions, lower thresholds, or weaker rules merely to pass checks. A legitimate exception requires prior approval, the smallest possible scope, and an explanation. Configure any formatter/linter overlap deliberately rather than repeatedly disabling checks during feature work.

Formatting success is not lint success. Lint success is not compiler success. Configured SwiftLint analyser rules require their separate analysis step and valid build information; plain `swiftlint lint` is not evidence that those rules ran. [7]

## 12. Tests and GitHub Actions

**Run formatting and linting locally. Do not run automated tests locally unless the user explicitly asks. Run the automated test suite through GitHub Actions.** Build or preview inspection is not a substitute for tests, and must not inadvertently invoke them.

Write meaningful tests for changed behaviour and regressions. Prefer test-first development; when using a red/green cycle, observe it through CI rather than violating the local-test restriction. Never claim a regression test failed before the fix unless that failure was actually observed.

Use **Swift Testing** for new unit tests where appropriate. Use **XCTest/XCUITest** for UI automation and capabilities that require them. Preserve existing useful tests rather than rewriting the suite solely to change frameworks. [8]

Keep tests deterministic and independent. Inject clocks, identifiers, persistence, and networking at real boundaries when needed. Do not depend on live services, execution order, shared mutable test state, arbitrary sleeps, or production credentials. Assert behaviour, not merely that a mock was called.

Required GitHub Actions checks MUST cover:

- Full-source formatting/linting using the same repository commands and pinned versions.
- Compilation of relevant first-party targets with Swift warnings treated as errors.
- The project's required unit, integration, and UI test suites on suitable pinned macOS/Xcode environments and supported simulator destinations.

Use shared schemes and test plans. Retain useful logs and test result bundles on failure. Existing required checks remain required; do not narrow the suite to the changed tests for final verification.

Do not remove tests, weaken assertions, disable checks, or repeatedly rerun an unexplained failure until one run happens to pass. Diagnose the cause. Report unrelated failures rather than silently omitting them.

## 13. Commit, push, and verify

For an implementation task with repository push authorisation, follow this sequence:

1. Implement the smallest complete change and its relevant tests.
2. Format changed code, review the diff, and run the full local lint gate. Resolve violations before pushing.
3. Commit only task-related changes with a descriptive message and push to the intended feature branch. Do not run local automated tests.
4. Identify the GitHub Actions runs and required checks associated with the **exact pushed commit SHA**. Inspect their status and failure logs; do not rely on an older green commit or a workflow badge.
5. Fix failures, repeat local formatting/linting, commit, push, and recheck the new SHA until required checks pass or a concrete external blocker is identified.

If pushing is not authorised or CI access is unavailable, leave the change ready for review and report which verification remains blocked. A missing workflow, pending job, skipped required check, or inaccessible result is not a passing result. Do not claim deployment readiness without evidence.

Do not force-push, rewrite unrelated history, delete branches, commit secrets, merge pull requests, modify production settings, or publish a build without the relevant explicit authorisation. Do not change branch protection or CI security controls to bypass a failure.

## 14. Definition of done

A code change is complete only when all applicable conditions are satisfied:

- The requested behaviour and acceptance criteria are implemented, including relevant loading, empty, error, cancellation, and recovery paths.
- The implementation remains native, uses verified supported APIs, and satisfies DRY, YAGNI, and KISS.
- Every first-party Swift source is covered by the full lint gate, with zero unresolved formatting or lint violations.
- Required CI compilation and tests pass for the final pushed commit, with no unresolved first-party compiler warnings.
- Changed UI has been inspected in a simulator or on a device, with relevant accessibility, appearance, localisation, and layout states checked. Record limitations when a state cannot be exercised.
- Relevant security, data migration, performance, and resource-lifecycle risks have been addressed.
- The diff contains no unrelated changes, secrets, dead code, temporary debug output, or weakened quality gates.
- Any new dependency, compatibility change, or approved exception is documented.

Scale verification to the change. A documentation-only task does not require unrelated app tests, but it MUST NOT be reported as application verification. For code changes, unavailable checks remain outstanding rather than being marked complete.

End with a brief, factual handoff: what changed, exact verification performed, lint/build/test results, commit or CI references where applicable, and remaining blockers. Never invent tool output or claim a command, review, simulator check, or test was performed when it was not.

## Technical references

Use these primary sources to verify technical details. Repository policies above may intentionally be stricter than the platform's minimum requirements. Recheck current API availability and release status when changing the toolchain.

[1]: https://developer.apple.com/xcode/system-requirements "Apple: Xcode SDKs and system requirements"
[2]: https://developer.apple.com/documentation/swiftui "Apple: SwiftUI"
[3]: https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro "Apple: Migrating to Observation"
[4]: https://developer.apple.com/videos/play/wwdc2025/323/ "Apple: Build a SwiftUI app with the new design"
[5]: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/ "Swift: Concurrency"
[6]: https://github.com/swiftlang/swift-format "Swift: swift-format documentation"
[7]: https://github.com/realm/SwiftLint "SwiftLint: Official documentation"
[8]: https://developer.apple.com/videos/play/wwdc2024/10179/ "Apple: Meet Swift Testing"
