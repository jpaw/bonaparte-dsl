# Bonaparte DSL — Usage Documentation

Bonaparte DSL is an [Xtext](https://www.eclipse.org/Xtext/)-based domain-specific language for
defining **external interfaces and persistence models**. From a single `.bon` source file it
generates fast, low-GC Java serialization/deserialization classes, XSD schemas, and — optionally —
TypeScript model types and Angular RPC API clients.

This documentation set explains the language, the three main generators, how to wire them into a
Maven project, and the full configuration surface. Real examples are drawn from the
[`t9t`](https://github.com/arvato-systems-jacs/t9t) and
[`bonaparte-java`](https://github.com/arvato-systems-jacs/bonaparte-java) projects.

## Documentation Index

| # | Document | What it covers |
|---|----------|----------------|
| 1 | [Overview](01-overview.md) | What Bonaparte is, the module layout, the generator pipeline, and the support libraries. |
| 2 | [DSL Syntax](02-dsl-syntax.md) | The `.bon` language: packages, imports, typedefs, classes, fields, enums, generics, properties, defaults. |
| 3 | [Java Generator](03-java-generator.md) | `JavaBonScriptGeneratorMain` — what it emits per definition type, file layout, annotations, and code sections. |
| 4 | [TypeScript Generator](04-typescript-generator.md) | `TypeScriptBonScriptGeneratorMain` — wire-format rules, per-type output, the module system, and JSDoc metadata. |
| 5 | [TypeScript API Generator](05-typescript-api-generator.md) | `TsApiClientGenerator` — request classification, response patterns, and the generated Angular API classes. |
| 6 | [Maven Integration](06-maven-integration.md) | How to add the generators to a project: `xtext-maven-plugin`, `bonaparte-typescript-maven-plugin`, ownership model, npm packaging. |
| 7 | [Configuration Reference](07-configuration-reference.md) | Every `bonaparte.*` system property / `BONAPARTE_*` environment variable with its default. |
| 8 | [Examples](08-examples.md) | Worked examples using real `.bon` sources from `t9t` and `bonaparte-java`, with the generated output. |

## The Three Generators

The three generators documented in depth are:

| Generator | Source | Purpose |
|-----------|--------|---------|
| **Java** | `de.jpaw.bonaparte.dsl/src/de/jpaw/bonaparte/dsl/generator/java/JavaBonScriptGeneratorMain.xtend` | Emits Java POJOs with hand-rolled, low-GC `serialize`/`deserialize`, validation, comparison, RTTI, and optional JAXB / Externalizable / Hazelcast / Bean-Validation support. |
| **TypeScript** | `de.jpaw.bonaparte.dsl/src/de/jpaw/bonaparte/dsl/generator/ts/TypeScriptBonScriptGeneratorMain.xtend` | Emits TypeScript model types (interfaces, enums, enumsets) that mirror the wire format, organized into npm modules. |
| **TypeScript API** | `de.jpaw.bonaparte.dsl/src/de/jpaw/bonaparte/dsl/generator/tsapi/TsApiClientGenerator.xtend` | Emits Angular `@Injectable` API client classes that wrap RPC calls for recognized request/response patterns (search, CRUD, resolve, …). |

All three are driven by the same orchestrator, `BonScriptGenerator`, which reads the model once and
dispatches to each enabled generator. See [Overview](01-overview.md) for the full pipeline.

## Quick Start

1. Read the [DSL Syntax](02-dsl-syntax.md) to write your first `.bon` file.
2. Add the generators to your build — see [Maven Integration](06-maven-integration.md).
3. Tune behavior with the [Configuration Reference](07-configuration-reference.md).
4. Study the [Examples](08-examples.md) to see real input → output pairs.

## Repository Layout (relevant modules)

```
bonaparte-dsl/
├── de.jpaw.bonaparte.dsl/          # The Xtext DSL: grammar, generators, preferences
│   └── src/de/jpaw/bonaparte/dsl/
│       ├── BonScript.xtext          # The grammar
│       ├── BonScriptPreferences.xtend        # Config system
│       ├── generator/
│       │   ├── BonScriptGenerator.xtend          # Orchestrator
│       │   ├── java/JavaBonScriptGeneratorMain.xtend
│       │   ├── ts/TypeScriptBonScriptGeneratorMain.xtend
│       │   ├── tsapi/TsApiClientGenerator.xtend
│       │   ├── xsd/                              # XSD schema generator
│       │   └── debug/                            # Debug output generator
│       └── ...
├── de.jpaw.bonaparte.dsl.tests/    # Unit tests
├── de.jpaw.bonaparte.dsl.ui/       # Eclipse UI (editor, quickfixes)
├── de.jpaw.bonaparte.dsl.ide/      # Eclipse IDE (content assist, validation)
├── de.jpaw.bonaparte.dsl.feature/  # Eclipse feature
├── de.jpaw.bonaparte.dsl.target/   # Eclipse target platform
├── de.jpaw.bonaparte.jpa.dsl/      # Companion JPA/BDDL DSL (separate grammar)
├── bonaparte-typescript-maven-plugin/  # Maven plugin for TS generation
└── de.jpaw.updatesite/             # Eclipse update site
```

The generated Java code is compiled against the **`bonaparte-java`** runtime library
(`de.jpaw.bonaparte`), and the generated TypeScript is compiled against the **`bonaparte-core`**
npm package. See [Overview](01-overview.md#support-libraries) for details.
