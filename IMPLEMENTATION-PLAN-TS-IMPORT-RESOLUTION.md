# Implementation Plan — TypeScript Import Resolution

> **Purpose:** Remove fragile package-depth arithmetic from generated TypeScript imports while preserving the current BON package layout and npm entry-point contract.
> **Reference:** The Java generator's `ImportCollector` is the conceptual model: collect resolved BON types, then render imports from canonical package identity. TypeScript needs a module specifier rather than a Java classpath name.

## Status (2026-10-11)

| Phase | State | Notes |
|---|---|---|
| 0 Current behavior audit | ✅ done | Same-module model and API imports count package segments; cross-module imports already use `TsModuleResolver` and the configured entry-point map. Runtime-support fallbacks also count package depth. |
| 1 Resolver contract | ⬜ not started | Specify path behavior and backward-compatibility requirements before implementation. |
| 2 Central path resolution | ⬜ not started | Add a single resolver for generated-file module specifiers; retain existing cross-module mapping. |
| 3 Generator migration | ⬜ not started | Route model, API-client, and runtime-support imports through the resolver. |
| 4 Regression coverage | ⬜ not started | Cover package depth, sibling/nested paths, mapped entry points, and runtime support. |
| 5 Consumer verification | ⬜ not started | Run the BON suite and build representative generated npm entry points. |

## Current State

- `TypeScriptBonScriptGeneratorMain.xtend` builds same-module imports by splitting BON package names and appending a computed number of `../` segments.
- `TsApiClientGenerator.xtend` contains a second copy of that relative-import calculation.
- `bonaPortablePath` and `rpcClientPath` have separate depth-based fallbacks for `rpc-core` imports. When an npm package is configured, these use the package specifier instead.
- `TsModuleResolver.java` already owns Maven-module identification, generated entry-point output folders, dependency-closure validation, and cross-module package specifiers. Preserve this behavior.
- Generated TypeScript files are laid out under `resources/ts/<entry-point>/<BON-package-path>/` when entry points are configured, and under `resources/ts/<BON-package-path>/` otherwise.
- Existing generator tests assert same-module imports, cross-module entry-point mappings, and runtime-support imports. Extend those tests rather than creating a separate test module.

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

- [ ] **`ImportCollector`** — introduce a TypeScript import collector keyed by canonical BON identity rather than simple name. Detect same-simple-name references before inserting them into `Map<String, EObject>`; either emit deterministic aliases and use them in rendered field/generic types, or fail with an actionable generation error. Apply the same policy to model files, API files, and module indexes.
- [ ] **`JavaPackages`** — centralize TypeScript package path, PQON, generated filename, and entry-point identity alongside import resolution. Verify package prefixes intentionally do not affect TypeScript PQONs, and test two BON packages whose simple type names collide.
- [ ] **`JavaEnum`** — preserve the current ordinal/token wire representation, but decide whether TypeScript also needs generated token/name lookup helpers, null-token handling, and enum schema metadata. Add tests for empty-string tokens, deprecated packages, and invalid/duplicate token behavior.
- [ ] **`JavaXEnum`** — replace the unconstrained `type X = string` only if consumers need the closed token union available from the xenum inheritance chain. At minimum, document and test why xenum base enum values, inherited values, abstract/final semantics, maximum token length, and null-token behavior are intentionally erased.
- [ ] **`JavaEnumSet`** — decide whether enum sets remain wire primitives or also receive named/branded TypeScript aliases and exported artifacts. Preserve numeric versus string bitmap representation while retaining enough identity to distinguish different enum-set definitions in APIs.
- [ ] **`JavaXEnumSet`** — decide whether xenum sets remain `string` or receive a named/branded alias tied to the referenced xenum; generate and export the artifact if identity is required.
- [ ] **`JavaFieldsGettersSetters`** — preserve field defaults and schema constraints that affect callers. TypeScript interfaces currently encode requiredness but discard `defaultString`, effective enum defaults, aggregate min/max counts, string lengths/patterns, case constraints, and field property metadata; define whether these belong in generated constants, runtime schemas, or separate metadata output.
- [ ] **`JavaConstructor`** — no class constructors are needed for interface-only output, but decide whether generated request/build helpers should apply BON defaults and require inherited mandatory fields. Test generic inheritance and inherited required fields in API parameter types.
- [ ] **`JavaMeta`** — define a portable TypeScript metadata contract if runtime validation, generic UI generation, or schema inspection is expected. Cover field category, multiplicity, map key type, requiredness, constraints, object bounds, revision, parent, properties, factory/class IDs, RTTI, and enum/xenum metadata; otherwise document metadata as deliberately server-only.
- [ ] **`JavaRtti`** — decide whether numeric RTTI is part of the TypeScript wire/runtime contract in addition to `@PQON`. Generate it through metadata rather than executable instance methods if required.
- [ ] **`JavaValidate` / `JavaBeanValidation`** — decide on generated runtime validation (for example a standard schema library) versus compile-time-only interfaces. If validation is in scope, cover required values, aggregate cardinality, string length/regexp/case, numeric precision, nested object validation, and inherited constraints from the same canonical metadata.
- [ ] **`JavaSerialize` / `JavaDeserialize`** — document the exact JSON/RPC wire mapping as the TypeScript contract and add round-trip fixtures against Java output. Cover enum ordinals versus tokens, enum-set bitmaps, xenum tokens, instant units, raw/binary encoding, null collection elements, map key coercion, polymorphic `@PQON`, external/adapted types, and inherited fields.
- [ ] **`JavaOpenApiOutput`** — avoid a second independent constraint implementation. If TypeScript schemas or OpenAPI-derived clients are generated, derive descriptions, deprecation, required/nullable state, bounds, examples, and defaults from the same metadata model used for validation.

#### Optional TypeScript runtime parity

- [ ] **`JavaCompare`** — decide whether consumers need generated structural equality, hashing, or `orderedByList` comparators. Do not port Java `equals`/`hashCode` mechanically; define JavaScript semantics for decimals, binary values, arrays, sets, maps, nulls, and polymorphic objects first.
- [ ] **`JavaFrozen`** — decide whether BON immutable/freezable semantics should produce `readonly` properties and `ReadonlyArray`/readonly-map types, runtime deep-freeze helpers, or remain server-only. Current interfaces are mutable even for immutable BON classes.
- [ ] **`JavaTreeWalker`** — decide whether metadata-driven traversal/conversion is needed for client-side normalization, string conversion, or generic forms. Implement it against portable metadata rather than emitting methods on interfaces.

#### Intentionally JVM-specific unless a consumer requirement appears

- [ ] **`JavaExternalize`** — record Java `Externalizable` binary integration as not applicable to TypeScript; add no port unless browser/Node binary compatibility becomes an explicit requirement.
- [ ] **`JavaHazelSupport`** — record Hazelcast serialization and factory/class interfaces as server-only; retain IDs only through portable metadata if clients consume them.
- [ ] **`Jaxb`** — record JAXB annotations, adapters, `jaxb.index`, and `package-info.java` as JVM/XML binding concerns. Treat XML client generation as a separate feature if required.
- [ ] **`JavaBonScriptGeneratorMain`** — add a documented TypeScript generation policy for Java-only declarations and flags: whether `noJava`, external types/adapters, package deprecation, abstract/final/immutable markers, interfaces, reference/key/tracking classes, custom annotations, and XML/Swagger switches are ignored, mapped, or rejected. Add diagnostics for unsupported constructs that would otherwise be silently weakened.

The import-resolution implementation in Phases 1–5 should directly address `ImportCollector` and `JavaPackages`. The remaining items are follow-up decisions unless tests show that the current TypeScript wire shape is already incorrect.

- [ ] Define a resolver API that accepts the source BON object, source generated type name, target BON object, and target generated type name.
- [ ] Establish each generated source/target path from `outputFolder(Resource)`, BON package path, and generated filename.
- [ ] Define behavior for absent resources, unresolved targets, same-package targets, same-entrypoint targets, cross-entrypoint targets, and unconfigured standalone generation.
- [ ] Preserve the current public output contracts: type-only model imports, configured npm entry-point specifiers across modules, and no file extensions.
- [ ] Decide collision handling for two referenced types with the same TypeScript simple name. Prefer a clear generation error or deterministic alias over silently emitting an ambiguous import; keep this scoped to import correctness.

## Phase 2 — Central Path Resolution

**Primary file:** `de.jpaw.bonaparte.dsl/src/de/jpaw/bonaparte/dsl/generator/ts/TsModuleResolver.java`

- [ ] Add same-entrypoint import resolution using normalized generated output paths and `Path.relativize` or an equivalent path utility.
- [ ] Ensure the resolver returns `./Name` for same-directory imports and valid slash-separated specifiers for sibling/nested package paths.
- [ ] Reuse `crossModuleImport` and the module map for cross-entrypoint imports; do not replace these with filesystem-relative imports.
- [ ] Add a runtime-support resolver targeting the generated `rpc-core` modules, respecting `bonaparte.TypeScript.npmPackage` when configured.
- [ ] Avoid changing `outputFolder`, module ownership, or dependency-closure semantics unless a test demonstrates a necessary correction.

## Phase 3 — Generator Migration

**Files:**
- `de.jpaw.bonaparte.dsl/src/de/jpaw/bonaparte/dsl/generator/ts/TypeScriptBonScriptGeneratorMain.xtend`
- `de.jpaw.bonaparte.dsl/src/de/jpaw/bonaparte/dsl/generator/ts/TsApiClientGenerator.xtend`

- [ ] Replace both duplicated same-module `importPath` implementations with the shared resolver.
- [ ] Replace the depth-counting `bonaPortablePath` and `rpcClientPath` fallbacks with runtime-support resolution.
- [ ] Keep `writeImports` and API import collection responsible for their existing model traversal and import kinds.
- [ ] Verify every remaining `../` construction in the TypeScript generator is either removed or derives from resolved generated paths; do not remove valid relative specifiers from emitted files.

## Phase 4 — Regression Coverage

**Test file:** `de.jpaw.bonaparte.dsl.tests/src/de/jpaw/bonaparte/dsl/generator/ts/TypeScriptGeneratorTest.java`

- [ ] Add generated-model cases for same-directory, sibling-package, and nested-package imports.
- [ ] Verify relative specifiers resolve to the generated target files for both default output and entry-point output layouts.
- [ ] Keep and extend the existing cross-module test to assert the configured npm entry-point import remains unchanged.
- [ ] Cover runtime support with and without `bonaparte.TypeScript.npmPackage`.
- [ ] Assert missing dependency-closure mappings still fail with the existing actionable error.
- [ ] Exercise API-client generation through the same resolver so the duplicate implementation cannot regress independently.
- [ ] Add a collision case if Phase 1 chooses explicit collision handling.

## Phase 5 — Verification

- [ ] With Java 21, run the BON TypeScript generator test reactor: `mvn -pl de.jpaw.bonaparte.dsl.tests -am verify -Dexec.skip=true`.
- [ ] Run a normal generator install to exercise MWE2 and the plugin lifecycle: `mvn -pl de.jpaw.bonaparte.dsl -am install`.
- [ ] Run `bash scripts/verify-ts-consumers.sh` to regenerate representative a28 and Takko consumers with configured module maps.
- [ ] Build the t9t API npm entry points (`mvn -pl t9t-api-ts -am verify` in the t9t repository) to prove ng-packagr resolves generated imports.
- [ ] Inspect representative generated output and confirm module-map imports and published package entry points are unchanged.

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
| 1 | Extend `TsModuleResolver` or add a `TsImportResolver`? | Extend `TsModuleResolver` first; it already owns module output folders and cross-module specifiers. Split only if the added path logic makes it incohesive. |
| 2 | Keep standalone runtime imports working without `npmPackage`? | Yes. Resolve against the known generated `rpc-core` output location rather than adding a required setting. |
| 3 | What to do with colliding TypeScript simple names? | Fail clearly or alias deterministically; decide before implementing the collector/rendering change. |
