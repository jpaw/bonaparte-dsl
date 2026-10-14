# 2. DSL Syntax

This document describes the `.bon` language. The grammar is defined in
[`BonScript.xtext`](../de.jpaw.bonaparte.dsl/src/de/jpaw/bonaparte/dsl/BonScript.xtext). It is an
Xtext grammar that *with* `org.eclipse.xtext.xbase.Xtype`, which is what allows fields to reference
arbitrary Java types (`is com.foo.Bar`) and to use Java annotations.

> **Rule of thumb:** every component either uses `{ }` to wrap its body, or a `;` to terminate the
> directive.

## File structure

A `.bon` file is a `Model`: zero or more `import` statements followed by zero or more `package`
blocks.

```bon
import t9t.base.types.*
import t9t.base.api.*

package (com.arvatosystems) t9t.ssm {
    default private unsigned trim noControlChars;
    // ... type definitions, enums, classes ...
}
```

### Imports

```bon
import <qualified.id>          // import a single type
import <qualified.id>.*        // import a whole package (wildcard)
```

Imports use Java-style qualified names. Wildcard imports are common in real `.bon` files.

## Packages

```bon
(javadoc)?
('@Deprecated')?
package ('(' prefix=QualifiedId ')')? name=QualifiedId
    ('XML' xmlAccess (UPPERCASE | ALL_UPPERCASE)?
         ('NAMESPACE' ns)? & ('NAMESPACEPREFIX' prefix)?
         & ('ELEMENTFORMDEFAULT' form)? & ('ATTRIBUTEFORMDEFAULT' form)?)?
    (noExt | Ext)?                       // Externalizable
    (noHazelcast | DataSer | IdDataSer | Portable | IdDataSerAndPortable)?
    (noBeanVal | BeanVal)?               // Bean Validation
    (noJavaBeanNames | JavaBeanNames | onlyJavaBeanNames)?
    ('bundle' bundle=QualifiedId)?
    ('factoryId' INT)?
    ('swagger')?
{
    (defaults)?                          // package-level FieldDefaultsDefinition
    ('properties' (inherited | prop (',' prop)*) ';')?
    (type | enum | enumset | xenum | xenumset | class)*
}
```

Key points:

- **`prefix`** — the Java package prefix. If omitted, the default `de.jpaw.bonaparte.pojos` is used.
  In `t9t` the prefix is almost always `(com.arvatosystems)`. The prefix is *not* stored in the
  serialized form; only the package `name` is.
- **`bundle`** — a coarser grouping than a package (corresponds to an OSGi bundle).
- **`factoryId`** — the Hazelcast factory id for portable serialization.
- **`swagger`** — emit Swagger annotations for the classes in this package.
- **`properties`** — declare named properties (see [Properties](#properties)). `inherited` copies
  the properties from the enclosing scope.

### Package-level defaults

A package may declare a `default` line that sets field defaults for every class in the package:

```bon
package (com.arvatosystems) t9t.ssm {
    default private unsigned trim noControlChars;
    ...
}
```

## Field defaults

The `default` directive (usable at package *and* class level) sets defaults for the fields that
follow. Each attribute is optional and independent:

```bon
default
    (visibility)?      // public | private | protected | default
    (signed)?          // signed | unsigned   (numeric integers; default signed)
    (required)?        // required | optional (lower-case types default required)
    (trim)?            // trim | notrim       (Unicode/Ascii; default notrim)
    (enum)?            // enum | noenum       (preset enum value with first field?)
    (truncate)?        // truncate | failOnOversize
    (round)?           // round | failOnExtraDecimals   (BigDecimal)
    (autoScale)?       // autoScale | noScale           (BigDecimal)
    (allowControlChars | noControlChars)?
    (usePrimitives | useBoxed)?
;
```

| Attribute | Values | Meaning |
|-----------|--------|---------|
| `visibility` | `public` `private` `protected` `default` | Java visibility of generated fields/getters. |
| `signed` | `signed` `unsigned` | Whether integer types are signed. |
| `required` | `required` `optional` | Whether a field must be present. |
| `trim` | `trim` `notrim` | Trim leading/trailing whitespace on string types. |
| `enum` | `enum` `noenum` | Initialize enum fields to their first value by default. |
| `truncate` | `truncate` `failOnOversize` | Behavior when a string exceeds its max length. |
| `round` | `round` `failOnExtraDecimals` | Behavior when a `BigDecimal` has too many decimals. |
| `autoScale` | `autoScale` `noScale` | Always scale a `BigDecimal` to the declared digits. |
| control chars | `allowControlChars` `noControlChars` | Allow control characters in Unicode fields. |
| primitives | `usePrimitives` `useBoxed` | Use primitive (non-null) or boxed types. |

## Type definitions

A `type` is a named alias for a data type. **Important:** package defaults apply at the *location
where the type is defined*, so a typedef expands with the same features in every package that uses
it.

```bon
type name is DataType ;
```

Examples from `t9t`:

```bon
type schedulerId is t9tShortId;
type fieldName   is Ascii(64);
```

## Classes

A `class` is the main data carrier. The full rule (abridged to the meaningful parts):

```bon
(javadoc)? ('@Deprecated')?
(abstract | final)?
((not)? immutable)?                       // immutable: no setters, final fields
class name ('<' GenericsDef (',' GenericsDef)* '>')?
    (nojava)?                             // suppress Java code generation
    ('XML' xmlAccess (UPPERCASE | ALL_UPPERCASE)?)?
    ('xmlRoot' ('<' name '>')? ('=' listName '(' (min..'..')? max ')')?)?
    ('xmlTypeName' '<' name '>')?
    ('xmlAdapter')?
    (noExt | Ext)?
    (noHazelcast | DataSer | IdDataSer | Portable | IdDataSerAndPortable)?
    (noBeanVal | BeanVal)?
    (noJavaBeanNames | JavaBeanNames | onlyJavaBeanNames)?
    ('RTTI' ('+')? INT)?                  // numeric runtime type information
    ('classId' INT)?                      // Hazelcast class id
    ('revision' STRING)?
    ('extends' ClassReference)?
    ('orderedBy' '(' field (',' field)* ')')?
    ('implements' JvmType (',' JvmType)* )?
    ('customAddons')?
    ('return' ClassReference)?            // the response type for a request
    ('isRef')?                             // this is a reference superclass
    (('pk' ClassDefinition) | ('isPk')?)  // primary key class / this is a pk class
    (('refp' STRING) | ('refw' STRING))?  // ref projection / widening functions
    (('keyp' STRING) | ('keyw' STRING))?  // key projection / widening functions
    ('tracking' ClassDefinition)?         // tracking columns
    ('cacheHash')?
    ('noAllFieldsConstructor')?
    ('is' JvmType ('adapter' QualifiedId)? ('needExtraParam')? ('singleField')?
        ('useFqn')? ('withExceptionConverter')? ('ordered')?)?
{
    (defaults)?
    ('properties' (inherited | PropertyUse (',' PropertyUse)*) ';')?
    FieldDefinition*
}
```

### Class modifiers explained

| Modifier | Meaning |
|----------|---------|
| `abstract` / `final` | Standard Java class modifiers. |
| `immutable` (or `not immutable`) | No setters, final fields; requires an all-args constructor. |
| `nojava` | Do not generate Java for this class (used when a class only feeds other generators). |
| `RTTI n` | Numeric runtime type id. `RTTI +n` adds to the parent's RTTI. Used for polymorphic dispatch. |
| `classId n` | Hazelcast class id. |
| `revision "x"` | A revision string; folded into the `serialVersionUID`. |
| `extends Ref` | Inheritance. The reference may be generic (see [Generics](#generics)). |
| `orderedBy (a, b)` | Fields used for `Comparable` ordering. |
| `implements I` | Implement additional Java interfaces. |
| `return Resp` | Declare the response type for a request class (used by the TS API generator). |
| `isRef` | Marks this class as a *reference* superclass (at most one per hierarchy). |
| `pk SomeClass` / `isPk` | Designate the primary-key class, or mark this class as one. |
| `refp` / `refw` | Ref projection / widening function names. |
| `keyp` / `keyw` | Key projection / widening function names. |
| `tracking T` | Reference the tracking-columns class. |
| `is com.foo.Bar` | The class is an *adapter* for the external Java type `com.foo.Bar`. |

### Generics

Classes can be generic:

```bon
class SearchResponse<DATA, TRACKING extends TrackingBase,
                     LIST_WITH_TENANT extends DataWithTracking<!DATA, !TRACKING>>
    extends SinkCreatedResponse { ... }
```

- A `GenericsDef` is `name ('extends' ClassReference)?`.
- Inside the body, a generic parameter is referenced with a leading `!`, e.g. `!DATA`.
- The `!` prefix means "use the bound / the parameter itself" rather than a concrete class.

### Class references

A `ClassReference` can be:

- `Object` — the plain object type.
- `!genericsParameter` — a generic parameter (e.g. `!DATA`).
- `ClassRef` or `ClassRef<A, B>` — a concrete (possibly parameterized) class.

## Fields

A field is the most frequently written construct:

```bon
(javadoc)? ('@Deprecated')?
(visibility)? (required | optional)?
DataType
    (('required')? (ArrayModifier | ListModifier | SetModifier | MapModifier))?
name ('altGetter' ID)? ('altSetter' ID)?
('is' metaName=STRING)?
('default' STRING)?
('example' STRING)?
('properties' PropertyUse (',' PropertyUse)*)?
;
(SL_COMMENT)?
```

### Field attributes

| Attribute | Meaning |
|-----------|---------|
| `visibility` | `public` / `private` / `protected` / `default`. |
| `required` / `optional` | Presence requirement. |
| `altGetter` / `altSetter` | Override the generated getter/setter name (corner cases like `mTimestamp`). |
| `is "metaName"` | Use an unusual name for JSON I/O metadata. |
| `default "value"` | A default value expression. |
| `example "value"` | An example value (used by Swagger). |
| `properties ...` | Attach named properties (see [Properties](#properties)). |

### Collection modifiers

| Modifier | Syntax | Meaning |
|----------|--------|---------|
| Array | `[min..max]` | Fixed/bounded array. |
| List | `List<min..max>` | Ordered list. |
| Set | `Set<min..max>` | Unordered set. |
| Map | `Map<IndexType, min..max>` | Map; index type is `String`, `Integer`, or `Long`. |

The `min..max` bounds are optional. A field may also be marked `required` in front of the modifier
to make the collection itself required (not just its elements).

## Data types

A `DataType` is one of:

1. **Elementary data type** (see table below).
2. **Object reference** — `('ClassRef' ('...')? (',' 'ClassRef2' ('...')?)?)` optionally followed by
   `for <field|string>`. The `...` means "or a superclass". Parentheses are required to disambiguate
   from a typedef reference.
3. **Type reference** — a `TypeDefinition` or a qualified name.

### Elementary data types

| Type | Syntax | Notes |
|------|--------|-------|
| `boolean` / `Boolean` | — | |
| `day` / `Day` | — | 8-digit `YYYYMMDD`. |
| `char` / `character` | — | |
| `uuid` / `Uuid` | — | |
| `object` / `Object` | — | Plain object. |
| `json` / `Json` | — | Arbitrary JSON. |
| `element` / `Element` | — | XML element. |
| `array` / `Array` | — | |
| `enum` / `Enum` | `enum EnumType (default)?` | Reference to an `enum`. |
| `xenum` / `XEnum` | `xenum XEnumType (default)?` | Reference to an `xenum`. |
| `enumset` / `Enumset` | `enumset EnumSetType` | Reference to an `enumset`. |
| `xenumset` / `XEnumset` | `xenumset XEnumSetType (length)` | Reference to an `xenumset`. |
| `instant` / `Instant` | `(length)? (hhmmss)?` | `java.time.Instant` (or Joda). |
| `timestamp` / `Timestamp` | `(length)?` | |
| `time` / `Time` | `(length)?` | |
| `ascii` / `Ascii` / `uppercase` / `lowercase` / `unicode` / `Unicode` | `(min..max) (trimming)? (truncating)? (allowControlChars)? ('regexp' STRING)?` | String types with length bounds. |
| `fixedPoint` / `FixedPoint` | `(length, decimals)? (rounding)?` | Fixed-point units. |
| `decimal` / `Decimal` | `(length, decimals)? (rounding)? (autoScale)?` | `BigDecimal`. |
| `number` / `Number` | `(length)` | `BigInteger`. |
| `byte`/`short`/`integer`/`int`/`long` (+ boxed) | `(length, decimals)? (rounding)?` | Integers, optionally bounded. |
| `float` / `double` (+ boxed) | — | |
| `raw` / `binary` | `(length)` | Byte array (`raw` mutable, `binary` immutable). |

## Enums

### Numeric enum

```bon
enum Color { RED, GREEN, BLUE }
```

Values are assigned ordinal positions starting at 0.

### Alphabetic (token) enum

```bon
enum AlphaColor { RED="R", GREEN="G", BLUE="B" }
```

Each value carries a string token. An empty token (`TRANSPARENT=""`) maps to a null value.

### Enum set

```bon
enumset Colormap is Color;                 // numeric index (default int)
enumset <String> Letterset is Alphabet;    // string-indexed
enumset <byte|short|int|long> Name is Enum;
```

An `enumset` is a bitmap over an enum. The index type defaults to `int`.

### XEnum (external enum)

```bon
xenum XColor is AlphaColor : 1;            // bound to an enum, max length 1
xenum XName is SomeEnum extends OtherXenum;
```

An `xenum` wraps an enum as a string-backed type, optionally bounded by a max length
(`:N ascii|unicode`) or by extending another `xenum`.

### XEnumSet

```bon
xenumset XColormap is XColor;
```

A set over an `xenum`.

## Properties

Properties are named, optionally annotation-backed markers that can be declared at package level
and applied to classes/fields.

### Declaration (package level)

```bon
properties
    inherited,                       // or a list of declarations:
    name is com.foo.Annotation(),    // bind a property to a Java annotation
    name is com.foo.Annotation(),    // no args
    name is com.foo.Annotation[](),  // multi-arg annotation
    plainName                        // a property with no annotation
;
```

### Usage (class / field level)

```bon
properties active, notupdatable, dropdown="userId", searchprefix="cannedRequest";
```

A `PropertyUse` is `key ('=' STRING)?`. The value is optional.

Properties are the mechanism by which `t9t` attaches semantic markers (e.g. `active`, `ref`,
`notupdatable`, `dropdown`) that other tools (JPA mapping, UI generation, the TS JSDoc metadata)
consume.

## A complete, realistic example

From `t9t-ssm-api/src/main/bon/request/ssm.bon`:

```bon
import t9t.base.types.*
import t9t.base.api.*
import t9t.base.crud.*
import t9t.base.search.*
import t9t.ssm.*

package (com.arvatosystems) t9t.ssm.request {
    default private unsigned trim noControlChars;
    properties noJava, simpleref,
        tenantCategory is com.arvatosystems.t9t.annotations.TenantCategory(),
        searchprefix is com.arvatosystems.t9t.annotations.SearchPrefix(),
        ref is com.arvatosystems.t9t.annotations.IsObjectRef;

    class SchedulerSetupCrudRequest
        extends CrudSurrogateKeyRequest<SchedulerSetupRef, SchedulerSetupDTO, FullTrackingWithVersion> {
        optional Boolean suppressResponseParameters;
    }

    class SchedulerSetupSearchRequest
        extends SearchRequest<SchedulerSetupDTO, FullTrackingWithVersion> {
        optional Boolean suppressResponseParameters;
    }

    class LeanSchedulerSetupSearchRequest extends LeanSearchRequest {}

    class DealWithPriorJobInstancesRequest extends RequestParameters
        return DealWithPriorJobInstancesResponse {
        required f42Ref schedulerSetupRef;
    }

    class DealWithPriorJobInstancesResponse extends ServiceResponse {
        required boolean invokeNewInstance;
    }
}
```

This single package produces (with the TS generators enabled):

- TypeScript model interfaces for each request/response class.
- An Angular `SchedulerSetupApi` client with `create`/`read`/`update`/`delete`/`search` methods
  (see [Examples](08-examples.md)).

## See also

- [Java Generator](03-java-generator.md) — how classes/fields become Java.
- [TypeScript Generator](04-typescript-generator.md) — how they become TS types.
- [TypeScript API Generator](05-typescript-api-generator.md) — how requests become API clients.
- [Examples](08-examples.md) — more real `.bon` sources and their output.
