# 7. Configuration Reference

All generator behavior is controlled by **`bonaparte`-prefixed settings**. The configuration is read
by [`BonScriptPreferences`](../de.jpaw.bonaparte.dsl/src/de/jpaw/bonaparte/dsl/BonScriptPreferences.xtend)
through a `ConfigReader` with prefix `bonaparte`.

## How a setting is resolved

For a setting named `name`, `ConfigReader.getProp(name, default)` looks, in order:

1. **System property** `bonaparte.<name>` — e.g. `-Dbonaparte.TypeScript=true`.
2. **Environment variable** `bonaparte_<name>` — e.g. `bonaparte_TypeScript=true`.
3. The **default** value.

> Note the separator difference: system properties use a **dot** (`bonaparte.TypeScript`),
> environment variables use an **underscore** (`bonaparte_TypeScript`).

## Static vs dynamic settings

There is an important subtlety about *when* a setting is read:

- **Static settings** are read once into `currentPrefs` fields at class-load time. Changing the
  environment after the JVM has started does **not** affect them.
- **Dynamic settings** are re-read from the `ConfigReader` on every call, so environment variables
  (and system properties) apply at call time.

The TypeScript-related getters (`getDoTypeScript`, `getDoTypeScriptApi`, `getTsModule`,
`getTsModulesFile`, `getTsExternalModulesFile`, `getTsNpmPackage`, `getTsIncludedModules`) are
**dynamic**. This is what allows the Maven `properties-maven-plugin` to set `bonaparte.TypeScript`
as a system property at `initialize` time and have it picked up later in the build (see
[Maven Integration](06-maven-integration.md)).

## Full settings table

| Setting | Type | Default | Static/Dynamic | Effect |
|---------|------|---------|----------------|--------|
| `WarnByte` | boolean | `true` | static | Warn when a `byte` field is used. |
| `WarnFloat` | boolean | `false` | static | Warn when a `float` field is used. |
| `DebugOut` | boolean | `false` | static | Run the debug generator (extra diagnostic output). |
| `DateTime` | boolean | `true` | static | Use `java.time` (`true`) vs `org.joda.time` (`false`) for date/time types. |
| `doJava` | boolean | `true` | static | Run the Java generator. |
| `doXsd` | boolean | `true` | static | Emit XSD/JAXB artifacts (annotations, `package-info`, `jaxb.index`). |
| `TypeScript` | boolean | `false` | **dynamic** | Run the TypeScript model generator. |
| `TypeScriptApi` | boolean | `false` | **dynamic** | Run the TypeScript API generator. |
| `TypeScript.module` | string | `null` | **dynamic** | The module id this build produces (Eclipse). |
| `TypeScript.modulesFile` | string | `null` | **dynamic** | Properties file `<artifactId>=<npm-package>,<entry-point>`. |
| `TypeScript.externalModulesFile` | string | `null` | **dynamic** | Properties file for modules not in the reactor. |
| `TypeScript.npmPackage` | string | `null` | **dynamic** | Fallback npm package scope. |
| `TypeScript.includedModules` | string | `null` | **dynamic** | Comma list of additional modules to generate. |
| `jakarta` | boolean | `true` | static | Use `jakarta.*` (`true`) vs `javax.*` (`false`) XML namespace. |
| `Externalize` | boolean | `false` | static | Default `Externalizable` when not set per class/package. |
| `HazelcastDs` | boolean | `false` | static | Default Hazelcast `DataSerializable` mode. |
| `HazelcastId` | boolean | `false` | static | Default Hazelcast identified-data-serializable mode. |
| `HazelcastPo` | boolean | `false` | static | Default Hazelcast portable mode. |
| `FactoryId` | int | `26` | static | Default Hazelcast factory id. |
| `xsdDefault` | boolean | `false` | static | XSD: use default (unqualified) form. |
| `xsdRootSeparateFile` | boolean | `true` | static | XSD: emit each root in a separate file. |
| `xsdBundleSubfolders` | boolean | `false` | static | XSD: organize schemas into bundle subfolders. |
| `xsdExtensions` | boolean | `false` | static | XSD: emit extension schemas. |

## Derived values

Some getters combine raw settings:

### `getDateTimePackage()`

```
"java.time"        if doDateTime
"org.joda.time"    otherwise
```

### `getHazelSupport()`

Combines the three `Hazelcast*` booleans into a single `XHazelcast`:

| `HazelcastPo` | `HazelcastId` / `HazelcastDs` | Result |
|---------------|-------------------------------|--------|
| `true` | either also `true` | `BOTH` |
| `true` | neither | `PORTABLE` |
| `false` | `HazelcastDs` `true` | `IDENTIFIED_DATA_SERIALIZABLE` |
| `false` | `HazelcastId` `true` | `DATA_SERIALIZABLE` |
| `false` | neither | `NOHAZEL` |

### `getExternalizable()`

```
EXT    if Externalize
NOEXT  otherwise
```

## Hardcoded (not configurable) constants

A few values are **fixed constants**, not settings. Do not look for a property to change them:

| Constant | Value | Where |
|----------|-------|-------|
| `bonaparteClassDefaultPackagePrefix` | `de.jpaw.bonaparte.pojos` | [`JavaPackages`](../de.jpaw.bonaparte.dsl/src/de/jpaw/bonaparte/dsl/generator/java/JavaPackages.xtend) |
| `bonaparteInterfacesPackage` | `de.jpaw.bonaparte.core` | [`XUtil`](../de.jpaw.bonaparte.dsl/src/de/jpaw/bonaparte/dsl/generator/XUtil.xtend) |

The Java package prefix *can* be overridden per package in the `.bon` file (the `(prefix)` clause),
but the *default* prefix when none is given is the constant above.

## Examples

```bash
# Java + XSD only (the defaults)
mvn generate-sources

# Also generate TypeScript models
mvn generate-sources -Dts=true

# Also generate TypeScript API clients
mvn generate-sources -Dts-api=true

# Force javax instead of jakarta
mvn generate-sources -Dbonaparte.jakarta=false

# Use Joda-Time instead of java.time
mvn generate-sources -Dbonaparte.DateTime=false

# Via environment variable (note the underscore)
bonaparte_TypeScript=true mvn generate-sources
```

## See also

- [Maven Integration](06-maven-integration.md) — how these settings are wired into a build.
- [Java Generator](03-java-generator.md) · [TypeScript Generator](04-typescript-generator.md) ·
  [TypeScript API Generator](05-typescript-api-generator.md) — what each setting controls.
