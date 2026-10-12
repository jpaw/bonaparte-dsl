# Implementation Plan — TypeScript Import Resolution

> **Purpose:** Remove fragile package-depth arithmetic from generated TypeScript imports while preserving the current BON package layout and npm entry-point contract.
> **Reference:** The Java generator's `ImportCollector` is the conceptual model: collect resolved BON types, then render imports from canonical package identity. TypeScript needs a module specifier rather than a Java classpath name.

## Status (2026-10-11)

| Phase | State | Notes |
|---|---|---|
| 0 Current behavior audit | ✅ done | Model, API, and module-index imports now use canonical BON identity collection; path-based import resolution and downstream verification are complete. |
| 1 Resolver contract | ✅ done | Resolver API, output-path contract, unresolved-input behavior, and fail-fast simple-name collision policy are defined and implemented. |
| 2 Central path resolution | ✅ done | `TsModuleResolver` derives same-entrypoint and runtime-support specifiers from generated paths; cross-module mapping is preserved. |
| 3 Generator migration | ✅ done | Model, API-client, module-index, and runtime-support imports use the shared resolver. |
| 4 Regression coverage | ✅ done | 34 generator tests pass, covering default/entry-point layouts, API imports, runtime support, collisions, inherited generic request fields, wire metadata, and Java-only flags. |
| 5 Consumer verification | ✅ done | Java 21 generator reactor and install passed; a28/Takko generation checks passed; t9t ng-packagr built all 28 entry points. The consumer script validates generation/module closure, not a28/Takko TypeScript compilation. |

## Current State

- `TypeScriptBonScriptGeneratorMain.xtend` and `TsApiClientGenerator.xtend` now use `TsModuleResolver` to derive relative imports from generated source and target paths.
- Runtime-support imports prefer the configured npm package; standalone generation resolves the generated `rpc-core` location through the same path-based resolver.
- `TsModuleResolver.java` already owns Maven-module identification, generated entry-point output folders, dependency-closure validation, and cross-module package specifiers. Preserve this behavior.
- Generated TypeScript files are laid out under `ts/<entry-point>/<BON-package-path>/` when entry points are configured, and under `ts/<BON-package-path>/` otherwise.
- Generator tests cover same-module imports, cross-module entry-point mappings, runtime-support imports, collision errors, and both generated output layouts.

## Design

Use one import-resolution path based on generated module locations, not an assumed relationship between BON package depth and output-directory depth.

1. Keep cross-module imports as stable npm entry-point specifiers from `TsModuleResolver` (for example, `@scope/package/base`). Continue failing when a configured dependency closure omits a referenced module.
2. For types in the same generated entry point, derive a relative module specifier from the generated source and target file paths. Normalize separators to `/`, omit `.ts`, and prefix `./` when required by TypeScript module resolution. A generated specifier may still contain `../`; its depth must come from the actual output paths rather than a loop over BON package segments.
3. For runtime support (`RpcClient`, `BonaPortable`, and unwrap helpers), prefer the configured npm package specifier. In standalone generation without that setting, resolve from the known generated `rpc-core` output location using the same path calculation instead of counting package depth.
4. Keep the current output directory and entry-point mapping unchanged. Do not introduce `tsconfig` aliases or new package exports unless implementation proves the existing generated layout cannot express a valid specifier.
5. Centralize this behavior in `TsModuleResolver.java` unless implementation reveals a compelling reason for a separate TypeScript import-resolver class. Keep the existing import maps/collections in Xtend generators; change how their references are rendered, not how model types are discovered.

## Phase 1 — Resolver Contract

### Java Generator Parity Audit

The Java generator is split into focused helpers while the TypeScript generator currently combines model output in `TypeScriptBonScriptGeneratorMain`. Parity does not mean porting JVM integration code verbatim: TypeScript emits structural wire contracts rather than executable `BonaPortable` domain classes. Complete the following decisions before broadening this import-resolution change.

#### Required for TypeScript wire-contract correctness

- [x] **`ImportCollector`** — introduce a TypeScript import collector keyed by canonical BON identity rather than simple name. Detect same-simple-name references before inserting them into `Map<String, EObject>`; either emit deterministic aliases and use them in rendered field/generic types, or fail with an actionable generation error. Apply the same policy to model files, API files, and module indexes. Implemented canonical-identity storage and fail-fast collisions across all three paths; generated regressions pass.
- [x] **`JavaPackages`** — centralize TypeScript package path, PQON, generated filename, and entry-point identity alongside import resolution. Verify package prefixes intentionally do not affect TypeScript PQONs, and test two BON packages whose simple type names collide. Implemented in `TsModuleResolver`; prefix and cross-package simple-name collision regressions pass.
- [x] **`JavaEnum`** — preserve the current ordinal/token wire representation, but decide whether TypeScript also needs generated token/name lookup helpers, null-token handling, and enum schema metadata. Add tests for empty-string tokens, deprecated packages, and invalid/duplicate token behavior. Keep generated constants and value unions as the compile-time wire contract; empty tokens remain `""`, package deprecation propagates, and reverse factories/null normalization/schema metadata remain outside the TypeScript surface. Duplicate and overlong tokens are rejected by the BON validator and tested.
- [x] **`JavaXEnum`** — replace the unconstrained `type X = string` only if consumers need the closed token union available from the xenum inheritance chain. At minimum, document and test why xenum base enum values, inherited values, abstract/final semantics, maximum token length, and null-token behavior are intentionally erased. Keep named xenum aliases open as `string`: Java xenum factories compose token enums across inheritance and may expose runtime descendants outside the current TypeScript compilation; abstract/final and max-length constraints govern Java construction/validation, not the wire token. Empty tokens remain representable as `""`, while nullable BON fields carry nullability. Regression covers base/inherited tokens, abstract/final declarations, max length, and null-token cases.
- [x] **`JavaEnumSet`** — decide whether enum sets remain wire primitives or also receive named/branded TypeScript aliases and exported artifacts. Preserve numeric versus string bitmap representation while retaining enough identity to distinguish different enum-set definitions in APIs. Generate unique-symbol branded `number`/`string` aliases, collect model imports by BON identity, and export aliases from module indexes; tests cover numeric and string bitmaps.
- [x] **`JavaXEnumSet`** — decide whether xenum sets remain `string` or receive a named/branded alias tied to the referenced xenum; generate and export the artifact if identity is required. Generate a branded string alias containing both set and referenced-xenum PQON identities; model imports and module-index exports are covered.
- [x] **`JavaFieldsGettersSetters`** — preserve caller-relevant field defaults and constraints as descriptive `@bonaparte.*` JSDoc tags immediately above interface fields. Emit explicit defaults (quoted for strings, unquoted for numeric values), effective enum defaults, requiredness, aggregate kind/count bounds, map key type, string length/pattern/case constraints, numeric precision/scale, and field properties. This metadata is for tooling and code generation, not runtime validation; no validator or schema dependency is introduced. Regression covers representative values and ensures numeric precision is not mislabeled as string length.
- [x] **`JavaConstructor`** — TypeScript model declarations remain interfaces and generated API methods accept request interfaces directly; no constructor or builder is generated, and BON defaults are not silently applied. Required inherited fields remain enforced by TypeScript through the request's `extends` chain, including generic substitution. A regression verifies a concrete API parameter inherits required generic-parent fields.
- [x] **`JavaMeta`** — keep the Java reflection registry server-only: no client requirement currently calls for runtime metadata, generic UI generation, or schema inspection. TypeScript emits only caller-relevant field JSDoc tags; class revision/parent/bundle, runtime class, factory/class IDs, object bounds, and enum/xenum reflection metadata are not portable runtime exports.
- [x] **`JavaRtti`** — numeric RTTI is Java runtime/Hazelcast identity, not a serialized wire field. The TypeScript contract uses the serialized `@PQON` discriminator; regression verifies generated object interfaces expose it without leaking RTTI.
- [x] **`JavaValidate` / `JavaBeanValidation`** — retain compile-time interfaces plus descriptive field metadata; do not generate runtime validators or add a schema-library dependency without a client validation requirement. JSDoc constraints do not claim enforcement.
- [ ] **`JavaSerialize` / `JavaDeserialize`** — source inspection establishes the default JSON mappings (numeric enum ordinals, token strings, numeric/string enum bitmaps, epoch-second instants, ISO date/time strings, Base64 binary, nullable collection members, object-shaped maps with identity string keys and `_`-prefixed integer/long keys, and `@PQON` for polymorphic records); matching TypeScript types/tags have regression coverage. Keep this item open until Java-produced round-trip fixtures cover these mappings and clarify external/adapted values plus inherited fields. Alternate `JsonComposer` enum modes remain configurable and are not yet negotiated by generated metadata.
- [x] **`JavaOpenApiOutput`** — TypeScript generation currently emits neither OpenAPI documents nor runtime schemas, so Java annotation generation remains a separate server concern. If TS schema output is introduced later, project it from the same field metadata rather than maintaining independent constraint logic.

#### Optional TypeScript runtime parity

- [ ] **`JavaCompare`** — decide whether consumers need generated structural equality, hashing, or `orderedByList` comparators. Do not port Java `equals`/`hashCode` mechanically; define JavaScript semantics for decimals, binary values, arrays, sets, maps, nulls, and polymorphic objects first.
- [ ] **`JavaFrozen`** — decide whether BON immutable/freezable semantics should produce `readonly` properties and `ReadonlyArray`/readonly-map types, runtime deep-freeze helpers, or remain server-only. Current interfaces are mutable even for immutable BON classes.
- [ ] **`JavaTreeWalker`** — decide whether metadata-driven traversal/conversion is needed for client-side normalization, string conversion, or generic forms. Implement it against portable metadata rather than emitting methods on interfaces.

#### Intentionally JVM-specific unless a consumer requirement appears

- [ ] **`JavaExternalize`** — record Java `Externalizable` binary integration as not applicable to TypeScript; add no port unless browser/Node binary compatibility becomes an explicit requirement.
- [ ] **`JavaHazelSupport`** — record Hazelcast serialization and factory/class interfaces as server-only; retain IDs only through portable metadata if clients consume them.
- [ ] **`Jaxb`** — record JAXB annotations, adapters, `jaxb.index`, and `package-info.java` as JVM/XML binding concerns. Treat XML client generation as a separate feature if required.
- [x] **`JavaBonScriptGeneratorMain`** — document current policy: TypeScript emits declared BON classes even when `nojava` suppresses Java generation; external Java types/adapters and Java-only annotations/flags do not alter the structural BON-field interface; package/type/field deprecation is mapped to JSDoc; abstract types remain usable interfaces and are expanded to concrete descendant unions when polymorphic fields permit; final/immutable/freezable, XML/Swagger/bean-validation, RTTI, reference/key/tracking and custom Java annotation semantics are not represented. A regression covers `nojava`, abstract/final inheritance, immutable, XML, and Swagger modifiers. Unsupported semantics remain intentionally descriptive/erased, not silently promised as TypeScript behavior.

The import-resolution implementation in Phases 1–5 addressed `ImportCollector` and `JavaPackages`. The remaining required items below are the active parity decisions; optional runtime and JVM-specific items remain follow-up scope.

- [x] Define a resolver API that accepts the source BON object, source generated type name, target BON object, and target generated type name.
- [x] Establish each generated source/target path from `outputFolder(Resource)`, BON package path, and generated filename.
- [x] Define behavior for absent resources, unresolved targets, same-package targets, same-entrypoint targets, cross-entrypoint targets, and unconfigured standalone generation.
- [x] Preserve the current public output contracts: type-only model imports, configured npm entry-point specifiers across modules, and no file extensions.
- [x] Decide collision handling for two referenced types with the same TypeScript simple name. Prefer a clear generation error or deterministic alias over silently emitting an ambiguous import; keep this scoped to import correctness.

## Phase 2 — Central Path Resolution

**Primary file:** `de.jpaw.bonaparte.dsl/src/de/jpaw/bonaparte/dsl/generator/ts/TsModuleResolver.java`

- [x] Add same-entrypoint import resolution using normalized generated output paths and `Path.relativize` or an equivalent path utility.
- [x] Ensure the resolver returns `./Name` for same-directory imports and valid slash-separated specifiers for sibling/nested package paths.
- [x] Reuse `crossModuleImport` and the module map for cross-entrypoint imports; do not replace these with filesystem-relative imports.
- [x] Add a runtime-support resolver targeting the generated `rpc-core` modules, respecting `bonaparte.TypeScript.npmPackage` when configured.
- [x] Avoid changing `outputFolder`, module ownership, or dependency-closure semantics unless a test demonstrates a necessary correction.

## Phase 3 — Generator Migration

**Files:**
- `de.jpaw.bonaparte.dsl/src/de/jpaw/bonaparte/dsl/generator/ts/TypeScriptBonScriptGeneratorMain.xtend`
- `de.jpaw.bonaparte.dsl/src/de/jpaw/bonaparte/dsl/generator/ts/TsApiClientGenerator.xtend`

- [x] Replace both duplicated same-module `importPath` implementations with the shared resolver.
- [x] Replace the depth-counting `bonaPortablePath` and `rpcClientPath` fallbacks with runtime-support resolution.
- [x] Keep `writeImports` and API import collection responsible for their existing model traversal and import kinds.
- [x] Verify every remaining `../` construction in the TypeScript generator is either removed or derives from resolved generated paths; do not remove valid relative specifiers from emitted files.

## Phase 4 — Regression Coverage

**Test file:** `de.jpaw.bonaparte.dsl.tests/src/de/jpaw/bonaparte/dsl/generator/ts/TypeScriptGeneratorTest.java`

- [x] Add generated-model cases for same-directory, sibling-package, and nested-package imports.
- [x] Verify relative specifiers resolve to the generated target files for both default output and entry-point output layouts.
- [x] Keep and extend the existing cross-module test to assert the configured npm entry-point import remains unchanged.
- [x] Cover runtime support with and without `bonaparte.TypeScript.npmPackage`.
- [x] Assert missing dependency-closure mappings still fail with the existing actionable error.
- [x] Exercise API-client generation through the same resolver so the duplicate implementation cannot regress independently.
- [x] Add a collision case if Phase 1 chooses explicit collision handling.

## Phase 5 — Verification

- [x] With Java 21, run the BON TypeScript generator test reactor: `mvn -pl de.jpaw.bonaparte.dsl.tests -am verify -Dexec.skip=true` (34 tests passed; install the DSL bundle first so Tycho uses the current generator).
- [x] Run a normal generator install to exercise MWE2 and the plugin lifecycle: `mvn -pl de.jpaw.bonaparte.dsl -am install`.
- [x] Run `bash scripts/verify-ts-consumers.sh` to regenerate representative a28 and Takko consumers with configured module maps (176 and 13 TypeScript files emitted; generation and module closure checks passed).
- [x] Build the t9t API npm entry points (`mvn -pl t9t-api-ts -am verify` in the t9t repository) to prove ng-packagr resolves generated imports (all 28 entry points built).
- [x] Inspect representative generated output and confirm module-map imports and published package entry points are unchanged; verified relative same-package/runtime imports and configured cross-package specifiers.

## Acceptance Criteria

- No import helper determines the number of parent traversals by counting BON package-name segments.
- Same-entrypoint imports resolve from the actual generated source and target locations in both output layouts.
- Cross-entrypoint imports continue to use configured npm package/entry-point specifiers and preserve dependency-closure errors.
- Runtime-support imports resolve in configured npm builds and standalone generation without depth arithmetic.
- Generator tests, MWE2-enabled installation, representative consumer generation, and the t9t APF package build pass.
- No unrelated type-mapping, API-signature, or npm publishing behavior changes.

## Scope Boundaries

- This plan changes import resolution only; it does not alter BON type mappings, generated DTO/API shapes, module ownership, or package publishing.
- It does not require converting all internal imports to package-qualified aliases. Same-entrypoint relative imports remain appropriate if calculated from actual generated paths.
- It does not remove or replace the Java `ImportCollector`; that code is a design reference, not a target for modification.

## Open Decisions

| # | Decision | Recommendation |
|---|---|---|
| 1 | Extend `TsModuleResolver` or add a `TsImportResolver`? | Resolved: extend `TsModuleResolver`; it already owns module output folders and cross-module specifiers. |
| 2 | Keep standalone runtime imports working without `npmPackage`? | Resolved: yes, resolve against the generated `rpc-core` output location rather than adding a required setting. |
| 3 | What to do with colliding TypeScript simple names? | Resolved: fail with an actionable generation error rather than emit ambiguous imports. |
