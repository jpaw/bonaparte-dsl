# 3. Java Generator

The Java generator is
[`JavaBonScriptGeneratorMain`](../de.jpaw.bonaparte.dsl/src/de/jpaw/bonaparte/dsl/generator/java/JavaBonScriptGeneratorMain.xtend).
It extends Xtext's `AbstractGenerator` and is enabled by `bonaparte.doJava` (default **true**).
Its job is to turn every definition in a `.bon` resource into a set of Java source files that
implement fast, low-GC serialization.

## What it produces

For each definition type in the resource, `doGenerate` emits one or more files:

| Definition | Emitted file(s) | Writer |
|------------|-----------------|--------|
| `EnumSetDefinition` | `java/<pkg>/<Name>.java` | `JavaEnumSet.writeEnumSetDefinition` |
| `XEnumSetDefinition` | `java/<pkg>/<Name>.java` | `JavaXEnumSet.writeXEnumSetDefinition` |
| `EnumDefinition` | `java/<pkg>/<Name>.java` | `JavaEnum.writeEnumDefinition` |
| `XEnumDefinition` | `java/<pkg>/<Name>.java` (+ `<Name>XmlAdapter.java` when it has relevant XML access, is non-abstract, and has no `extends`) | `JavaXEnum.writeXEnumDefinition` / `writeXEnumTypeAdapter` |
| `ClassDefinition` (where `!noJava`) | `java/<pkg>/<Name>.java` | `writeClassDefinition` |
| `PackageDefinition` | `resources/<pkg>/jaxb.index` (one line per class/xenum with an XML tag) and `java/<pkg>/package-info.java` (when the package has javadoc or XML bindings) | inline |

### File layout

- **Java sources** go to `java/<package-as-path>/<Name>.java`, where the package is the
  *bonaparte package name* (see below).
- **JAXB index** goes to `resources/<package-as-path>/jaxb.index`.
- The *bonaparte package name* is `prefix + "." + name`, where `prefix` is the package's declared
  `(prefix)` or the default `de.jpaw.bonaparte.pojos` (a constant in
  [`JavaPackages`](../de.jpaw.bonaparte.dsl/src/de/jpaw/bonaparte/dsl/generator/java/JavaPackages.xtend)).

> In `t9t` the prefix is `(com.arvatosystems)`, so a class in package `t9t.ssm` is generated into
> `java/com/arvatosystems/t9t/ssm/`.

## The `package-info.java` file

When a package has javadoc or XML bindings, the generator writes a `package-info.java` that carries
the JAXB schema annotations:

- `@XmlSchema(namespace=..., elementFormDefault=..., attributeFormDefault=..., xmlns={@XmlNs(...)})`
- `@XmlJavaTypeAdapters({...})` mapping `LocalDate`, `LocalTime`, `LocalDateTime`, `Instant`,
  `MilliUnits`, `MicroUnits`, `NanoUnits`, and `ByteArray` to their JAXB adapters.

The `elementFormDefault` defaults to `QUALIFIED` when unspecified (for backwards compatibility).
The `jakarta` vs `javax` prefix is chosen by `bonaparte.jakarta` (default **true** → `jakarta`).

## The `jaxb.index` file

For each package that contains at least one non-abstract class or xenum with a relevant XML access,
a `jaxb.index` is written listing those type names (one per line). This is the standard JAXB
mechanism for controlling which classes are exposed in a schema.

## `writeClassDefinition` — the core

This is the heart of the generator. For a single `ClassDefinition` it:

1. **Collects imports** with an `ImportCollector` (recurses the class, its return type, generic
   bounds, key/pk/tracking classes).
2. **Computes the feature flags**:
   - `xmlAccess` / `withXml` — relevant XML access *and* `bonaparte.doXsd`.
   - `doExt` — `Externalizable` (class → package → `bonaparte.Externalize`).
   - `doHazel` — Hazelcast support (class → package → `bonaparte.Hazelcast*`).
   - `doBeanVal` — Bean Validation (class → package → default off).
   - `myKey` — the (recursed) primary-key class.
   - `activeColumn` — the field carrying the `active` property.
3. **Emits the class** in a fixed section order (see below).

### Decision helpers

| Helper | Resolution order |
|--------|------------------|
| `getExternalizable(d)` | class `isExternalizable` → package `isExternalizable` → `bonaparte.Externalize` |
| `getHazelSupport(d)` | class `doHazelcast` → package `doHazelcast` → `bonaparte.Hazelcast*` (via `getHazelSupport()`) |
| `getBeanValidation(d)` | class `doBeanValidation` → package `doBeanValidation` → `noBeanVal` |

`BonScriptPreferences.getHazelSupport()` combines the three `Hazelcast*` booleans into a single
`XHazelcast` value:

- `HazelcastPo` true → `PORTABLE` (or `BOTH` if `HazelcastId`/`HazelcastDs` also set).
- else `HazelcastDs` true → `IDENTIFIED_DATA_SERIALIZABLE`.
- else `HazelcastId` true → `DATA_SERIALIZABLE`.
- else `NOHAZEL`.

### Emitted class structure

The generated class body is emitted in this exact order:

```
// header comment (auto-generated notice)
package <pkg>;
<imports>                       // default + JAXB + Swagger + BeanVal + Externalize + Hazel
                                // + Guava Immutable* + bonaparte annotations + runtime + meta
<javadoc>
<XML annotations>               // @XmlRootElement, @XmlAccessorType, @XmlType, @XmlJavaTypeAdapter
@RelatedKey(<Key>.class)        // if a key class exists
@SuppressWarnings("all")
@Deprecated                      // if deprecated
@IsRefClass                      // if isRef
@KeyClass(<Pk>.class)            // if pkClass
@TrackingClass(<Tracking>.class) // if trackingClass
<property annotations>
public [final] [abstract] class Name<generics> [extends Parent<args>]
    implements BonaPortable[Ref] [, Comparable<Name>] [, Externalizable] [, Hazel interfaces] [, extra interfaces] {
    private static final long serialVersionUID = <uid>L;

    <JavaRtti.writeRtti>                 // RTTI constant + ret$Rtti()
    <JavaMeta.writeMetaData>             // static meta registration
    <JavaFrozen.writeFreezingCode>       // freeze support (immutable)
    <fields>                             // one per FieldDefinition (writeOneField)
    <JavaFieldsGettersSetters.writeGettersSetters>
    <JavaValidate.writePatterns>         // compiled regex patterns
    <JavaSerialize.writeSerialize>       // serialize()
    <JavaSerialize.writeFoldedSerialize> // folded (parent+child) serialize
    <JavaDeserialize.writeDeserialize>   // deserialize()
    <JavaValidate.writeValidationCode>   // validate()
    <JavaCompare.writeHash>              // hashCode()
    <JavaCompare.writeComparisonCode>    // equals()
    <JavaCompare.writeComparable>        // compareTo() (if orderedBy)
    <JavaExternalize.writeExternalize>   // writeExternal/readExternal (if doExt)
    <JavaHazelSupport.writeHazelIO>      // Hazelcast read/write (if doHazel)
    <JavaTreeWalker.writeTreeWalkerCode> // tree-walker hooks
    <JavaConstructor.writeConstructorCode>
    <Jaxb.writeDefaultAdapter>           // inner DefaultXmlAdapter (if writeXmlAdapter)
    <writeRef>                           // ret$RefP/ret$RefW/ret$Key
    toString()
    put$Active / ret$Active              // active-field accessors
}
```

### The runtime imports

Every generated class imports the bonaparte runtime from the fixed package
`de.jpaw.bonaparte.core` (constant `bonaparteInterfacesPackage` in
[`XUtil`](../de.jpaw.bonaparte.dsl/src/de/jpaw/bonaparte/dsl/generator/XUtil.xtend)):

- `BonaPortable` (and `BonaPortableRef` when the class has a ref function)
- `BonaPortableClass`, `MessageParser`, `MessageComposer`, `MessageParserException`,
  `ObjectValidationException`, `DataConverter`, `StaticMeta`
- `de.jpaw.bonaparte.annotation.*`
- `de.jpaw.bonaparte.util.DeprecationWarner`
- `de.jpaw.bonaparte.pojos.meta.*` (the `meta` package under the default prefix)

### The `implements` clause

The base interface is `BonaPortable`, or `BonaPortableRef` when the class declares a `refp`/`refw`
function. Additional interfaces are appended for:

- `Comparable<Name>` — when `orderedBy` is present.
- `Externalizable` — when `doExt`.
- Hazelcast interfaces — `DataSerializable`, `BonaparteIdentifiedDataSerializable`,
  `BonapartePortable` (per the `XHazelcast` value).
- Any user-declared `implements` list.

### `serialVersionUID`

Computed by `JavaPackages.getSerialUID(d)`: a hash of the partially-qualified class name, folded
with the `revision` string (if any) and recursively with the parent class's UID. This makes the UID
stable across builds but sensitive to name/revision/inheritance changes.

### Ref / key functions (`writeRef`)

When a class declares `refp`/`refw` or `keyp`/`keyw`, the generator emits:

- `ret$RefP()` / `ret$RefW()` — the reference projection (primitive `long`) and widening
  (`Long`) accessors, derived from whichever of `refPFunction`/`refWFunction` is present.
- `ret$Key(long)` / `ret$Key(Long)` — static factory that converts a ref id into the key class
  (returns `null` for non-positive / null refs), derived from `keyPFunction`/`keyWFunction`.

### Fields (`writeOneField`)

Each field is emitted with, in order:

1. Field comments (`JavaFieldsGettersSetters.writeFieldComments`).
2. Bean-Validation annotations (`JavaBeanValidation.writeAnnotations`) — if `doBeanVal`.
3. Property annotations (`i.properties.generateAllAnnotations`).
4. JAXB field annotations (`allXmlAnnotations`) — only when XML access is `FIELD`.
5. OpenAPI/Swagger annotations (`JavaOpenApiOutput.writeAnnotations`) — if the package has `swagger`.
6. `@Deprecated` — if the field is deprecated.
7. The field declaration: `[visibility] <type> <name> [= default];`

## Helper classes

The main class delegates the per-section emission to a set of focused helpers in the same package:

| Helper | Responsibility |
|--------|----------------|
| `JavaPackages` | Package-name computation, partially-qualified names, `serialVersionUID`. |
| `ImportCollector` | Collects and de-duplicates Java imports for a class. |
| `JavaRtti` | RTTI constant and `ret$Rtti()`. |
| `JavaMeta` | Static metadata registration. |
| `JavaFrozen` | Freezing / immutability support. |
| `JavaFieldsGettersSetters` | Field comments, getters/setters, default values, XML field annotations. |
| `JavaValidate` | Regex patterns and `validate()` code. |
| `JavaSerialize` | `serialize()` and folded serialize. |
| `JavaDeserialize` | `deserialize()`. |
| `JavaCompare` | `hashCode()`, `equals()`, `compareTo()`. |
| `JavaExternalize` | `Externalizable` imports and `writeExternal`/`readExternal`. |
| `JavaHazelSupport` | Hazelcast imports and read/write support. |
| `JavaBeanValidation` | JSR-303 annotations and imports. |
| `JavaOpenApiOutput` | Swagger/OpenAPI annotations and imports. |
| `JavaTreeWalker` | Tree-walker hooks. |
| `JavaConstructor` | Constructor generation. |
| `Jaxb` | The inner `DefaultXmlAdapter`. |
| `JavaEnum` / `JavaXEnum` / `JavaEnumSet` / `JavaXEnumSet` | The non-class definition writers. |

## Configuration knobs that affect the Java generator

| Setting | Effect |
|---------|--------|
| `bonaparte.doJava` | Master switch (default `true`). |
| `bonaparte.jakarta` | `jakarta` vs `javax` XML namespace (default `true`). |
| `bonaparte.DateTime` | `java.time` vs `org.joda.time` for date/time types (default `true`). |
| `bonaparte.doXsd` | Whether JAXB annotations / `package-info` / `jaxb.index` are emitted (default `true`). |
| `bonaparte.Externalize` | Default `Externalizable` when not set per class/package (default `false`). |
| `bonaparte.HazelcastDs` / `HazelcastId` / `HazelcastPo` | Default Hazelcast mode (all default `false`). |
| `bonaparte.FactoryId` | Default Hazelcast factory id (default `26`). |

See the [Configuration Reference](07-configuration-reference.md) for the full table.

## See also

- [DSL Syntax](02-dsl-syntax.md) — the input language.
- [Examples](08-examples.md) — a real `.bon` class and the shape of its generated Java.
