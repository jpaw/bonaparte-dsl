# 4. TypeScript Generator

The TypeScript model generator is
[`TypeScriptBonScriptGeneratorMain`](../de.jpaw.bonaparte.dsl/src/de/jpaw/bonaparte/dsl/generator/ts/TypeScriptBonScriptGeneratorMain.xtend).
It extends Xtext's `AbstractGenerator` and is enabled by `bonaparte.TypeScript` (default **false**).
It turns every definition in a `.bon` resource into **TypeScript type definitions** — one file per
class / enum / xenum — plus the module scaffolding (`index.ts`, `package.json`, etc.).

> This generator produces *types only*. The Angular API *clients* are produced by the separate
> [TypeScript API Generator](05-typescript-api-generator.md).

## When it runs

`doGenerate` first checks `TsModuleResolver.isCurrentModule(resource)`. If the resource does not
belong to the module being built, nothing is emitted. Otherwise it iterates over the current module
*and* any **included modules** (see [Module system](#module-system)) and, for each, emits:

| Definition | File | Writer |
|------------|------|--------|
| `EnumDefinition` | `ts/<entry>/<pkg>/<Name>.ts` | `writeEnum` |
| `XEnumDefinition` | `ts/<entry>/<pkg>/<Name>.ts` | `writeXEnum` |
| `EnumSetDefinition` | `ts/<entry>/<pkg>/<Name>.ts` | `writeEnumSet` |
| `XEnumSetDefinition` | `ts/<entry>/<pkg>/<Name>.ts` | `writeXEnumSet` |
| `ClassDefinition` | `ts/<entry>/<pkg>/<Name>.ts` | `writeInterface` |
| (module) | `ts/<entry>/bona-portable.ts` | `bonaPortableSource` (only if the module generates portable support) |
| (module) | `ts/<entry>/package.json` | `entryPointPackageJson` |
| (module) | `ts/<entry>/ng-package.json` | `entryPointNgPackageJson` |
| (module) | `ts/<entry>/index.ts` | `writeModuleIndex` |
| (module) | `ts/<entry>/api-index.ts` | a stub `export {};` (filled in by the API generator) |

`<entry>` is the module's entry point (its `artifactId`), or empty when there is no module context.

## Wire-format rules

The generator's header documents the wire format it targets (verified against a live bonaparte
server). These rules drive the JSDoc `@bonaparte.wireFormat` metadata and the TS type choices:

- Plain (non-alpha) enums → **numeric ordinals**.
- Alpha enums → **token strings**.
- `instant` → **epoch seconds** (`number`).
- `day`, `time`, `timestamp` → **strings**.
- `enumset` (numeric index) → **integer bitmap**.
- `xenumset` → **string**.
- JSON binary fields → **Base64** strings; JSON map keys are strings, with integer/long keys
  prefixed by `_`.
- Every object carries a `'@PQON'` field with the partially-qualified object name.
- List elements may be `null` (fixed-size lists contain nulls).
- Plain `Object` / `Element` → `BonaPortable`.

## Per-type output

### Enums

- **Alpha enum** → a `const` object of token strings plus a union type:
  ```ts
  export const AlphaColor = { RED: "R", GREEN: "G", BLUE: "B" } as const;
  export type AlphaColor = (typeof AlphaColor)[keyof typeof AlphaColor];
  ```
- **Numeric enum** → a `const` object of ordinal values plus a union type (same shape, numeric
  values).

### XEnum

```ts
export type XColor = string;
```

An `xenum` is a string-backed type.

### EnumSet

A **branded** type so it is not interchangeable with a plain number:

```ts
export type Colormap = number & { readonly [ColormapBrand]: "pqon" };
```

If the index type is string-based (`s...`), the brand is over `string` instead of `number`.

### XEnumSet

A branded `string` type.

### Classes → interfaces

`writeInterface` emits, for each class:

1. An import of `BonaPortable` (from the module's portable support or the `bonaparte-core` package)
   plus type imports for referenced types.
2. A `const` for the PQON:
   ```ts
   export const SchedulerSetupDTOPQON = "t9t.ssm.SchedulerSetupDTO" as const;
   ```
3. The interface, extending its parent (omitting the parent's `@PQON`):
   ```ts
   export interface SchedulerSetupDTO extends Omit<SchedulerSetupRef, '@PQON'> {
       '@PQON': typeof SchedulerSetupDTOPQON;
       // ... fields ...
   }
   ```
4. A **type guard** `isX(value: unknown): value is X` — emitted only when the parent lives in a
   *different* module (cross-module inheritance needs an explicit guard).

### `bona-portable.ts`

When a module generates portable support (its `artifactId` is `bonaparte-core`, or no module is
set), it emits:

```ts
export interface BonaPortable {
    '@PQON': string;
    [key: string]: unknown;
}
```

## Type mapping

`tsBaseType` maps bonaparte data types to TypeScript:

| Bonaparte type | TypeScript |
|----------------|------------|
| `boolean` | `boolean` |
| `byte` `short` `int` `integer` `long` `float` `double` `decimal` `number` `fixedpoint` | `number` |
| `char` `character` `uuid` `day` `ascii` `unicode` `uppercase` `lowercase` `timestamp` `time` `raw` `binary` | `string` |
| `instant` | `number` (epoch seconds) |
| `json` | `Record<string, unknown>` |
| `array` | `unknown[]` |
| `object` `element` | `BonaPortable` |

`tsFieldType` then applies collection/optionality rules:

- Collections (array/list/set) → `(T | null)[]`.
- Maps → `Record<string, T | null>`.
- Optional scalars → `T | null` with a `?` modifier.

### Polymorphism

If a class is abstract and has concrete descendants *in the same module*, the generated type is a
**union of the descendant names** rather than a single interface.

## JSDoc metadata tags

Every field carries JSDoc `@bonaparte.*` tags that downstream tooling (the API generator, runtime
unwrap helpers, and editors) consume:

| Tag | Meaning |
|-----|---------|
| `@bonaparte.required` | Field is required. |
| `@bonaparte.default` | Default value. |
| `@bonaparte.aggregate` | `array` \| `list` \| `set` \| `map` (plus `required`/`optional`). |
| `@bonaparte.minCount` / `@bonaparte.maxCount` | Collection size bounds. |
| `@bonaparte.mapKey` | Map key type. |
| `@bonaparte.jsonMapKeyFormat` | `identity` or `underscore-prefixed-decimal`. |
| `@bonaparte.wireFormat` | `numeric-enum-ordinal` \| `enum-token-string` \| `string-enum-bitmap` \| `numeric-enum-bitmap` \| `epoch-seconds` \| `iso-8601-string`. |
| `@bonaparte.encoding` | e.g. `base64`. |
| `@bonaparte.maxBytes` | Max byte length. |
| `@bonaparte.minLength` / `@bonaparte.maxLength` / `@bonaparte.pattern` / `@bonaparte.case` | String constraints. |
| `@bonaparte.precision` / `@bonaparte.scale` | Numeric precision/scale. |
| `@bonaparte.property` | `key=value` for each attached property. |

## Runtime metadata

The JSDoc tags are comments only. For code that needs the same information at runtime (forms,
dropdowns, validation), every class file also exports a `<Name>Meta` constant of type `TsClassMeta`:

```ts
export const ApiKeyDTOMeta: TsClassMeta = {
    pqon: ApiKeyDTOPQON,
    parent: () => ApiKeyRefMeta,
    props: {},                 // class properties
    propsInherited: false,     // "properties inherited": look up missing class properties in the parent
    own: {                     // fields declared by this class only
        "userRef": { required: true, props: { "ref": true, "searchprefix": "user", "dropdown": "userId" },
                     objectType: () => UserRefMeta, refTarget: () => UserDTOMeta },
        "name": { required: false, maxLength: 80, props: {} },
    },
};
```

- `props` contains **all** properties of the field or class as `Record<string, string | true>`
  (`true` for a property without value).
- `objectType` is the declared class of an object field; `refTarget` is the secondary type of a
  reference field declared as `(UserRef...,UserDTO)` that carries the `ref` property.
- `parent`, `objectType` and `refTarget` are thunks, so circular references between files are safe.

The types and helpers live in `bona-meta.ts`, which `bonaparte-core` emits next to `bona-portable.ts`
and exports from its index:

| Export | Purpose |
|--------|---------|
| `TsClassMeta`, `TsFieldMeta`, `BonaProps` | Metadata types. |
| `bonAllFields(meta)` | Own and inherited fields; a child field replaces a parent field of the same name. |
| `bonClassProp(meta, key)` | Class property, following `parent` when `propsInherited` is set. |
| `bonValidate(meta, value)` | Advisory check of required, length, pattern, case, precision/scale, byte size and count constraints. |

`bonValidate` returns a list of `BonValidationIssue` (`path`, `rule`, `limit`, `actual`). It never throws
and nothing calls it implicitly; the server remains authoritative.

## Module system

Module resolution is handled by
[`TsModuleResolver`](../de.jpaw.bonaparte.dsl/src/de/jpaw/bonaparte/dsl/generator/ts/TsModuleResolver.java).
It answers three questions:

1. **Is this resource the current module?** (`isCurrentModule`) — via the active
   `TsGenerationContext` owner, or the `bonaparte.TypeScript.module` preference.
2. **Is this resource an included module?** (`isIncludedModule`) — from the
   `bonaparte.TypeScript.includedModules` comma list.
3. **How do I import a type from another module?** (`crossModuleImport` / `importPath`) — either a
   relative path (same module) or an npm specifier (`<npmPackage>/<artifactId>`).

The output folder is `ts/<entryPoint>/` (or `ts/` when there is no module). The `bonaparte-core`
module owns `bona-portable.ts`; other modules import it from
`@arvato-systems-jacs/bonaparte/bonaparte-core`.

See [Maven Integration](06-maven-integration.md) for how the module ownership context is built in a
Maven build.

## Configuration knobs

| Setting | Effect |
|---------|--------|
| `bonaparte.TypeScript` | Master switch (default `false`). |
| `bonaparte.TypeScript.module` | The module id this build is producing (Eclipse). |
| `bonaparte.TypeScript.modulesFile` | Properties file mapping `<artifactId>=<npm-package>,<entry-point>`. |
| `bonaparte.TypeScript.externalModulesFile` | Properties file for modules that are *not* in the reactor. |
| `bonaparte.TypeScript.npmPackage` | Fallback npm package scope. |
| `bonaparte.TypeScript.includedModules` | Comma list of modules to also generate. |

See the [Configuration Reference](07-configuration-reference.md) for the full table.

## See also

- [TypeScript API Generator](05-typescript-api-generator.md) — the Angular clients.
- [Examples](08-examples.md) — a real `.bon` class and its generated TS interface.
