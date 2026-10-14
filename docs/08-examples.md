# 8. Worked Examples

This chapter walks through real `.bon` sources from the `t9t` and `bonaparte-java` projects and
shows what the generators produce. The goal is to connect the abstract rules in the previous
chapters to concrete input/output pairs.

## Example 1 — t9t `ssm.bon` (DTO + request)

The scheduler-service module (`t9t-ssm-api`) is a good end-to-end example because it exercises
packages, type aliases, alpha enums, enumsets, a ref/key hierarchy, a DTO, and CRUD/search
requests.

### 1.1 The `.bon` source (DTO)

`t9t-ssm-api/src/main/bon/dto/ssm.bon` (abridged):

```bon
import api.*
import t9t.base.types.*
import t9t.base.api.*
import t9t.core.*

/** In this package, the scheduler service related items are defined. (SSM API module)
 * RTTI values in range 200-299
 */
package (com.arvatosystems) t9t.ssm {
    default private unsigned trim noControlChars;
    properties noJava, simpleref, qualifierFor,
        tenantCategory is com.arvatosystems.t9t.annotations.TenantCategory(),
        searchprefix is com.arvatosystems.t9t.annotations.SearchPrefix(),
        notupdatable is com.arvatosystems.t9t.annotations.NotUpdatable,
        dropdown is com.arvatosystems.t9t.annotations.UseDropDownInUI(),
        ref is com.arvatosystems.t9t.annotations.IsObjectRef;

    type schedulerId is t9tShortId;

    enum SchedulerSetupRecurrenceType {
        SECONDLY    = "s",
        MINUTELY    = "m",
        HOURLY      = "h",
        DAILY       = "D",
        WEEKLY      = "W",
        MONTHLY     = "M",
        YEARLY      = "Y",
        FAST        = "F",
        CRON_NATIVE = "C"
    }

    enum SchedulerConcurrencyType {
        RUN_PARALLEL  = "P",
        SKIP_INSTANCE = "S",
        KILL_PREVIOUS = "K",
        CUSTOM        = "C"
    }

    class SchedulerSetupRef RTTI 200 extends Ref {}

    final class SchedulerSetupKey extends SchedulerSetupRef {
        required schedulerId schedulerId;
    }

    class SchedulerSetupDTO extends SchedulerSetupRef {
        required schedulerId schedulerId properties notupdatable;
        required boolean isActive properties active;
        optional shortText name;
        required (CannedRequestRef..., CannedRequestDTO) request
            properties ref, dropdown="cannedRequestId", searchprefix="cannedRequest";
        required userId userId properties dropdown="userId";
        optional Uuid apiKey;
        optional shortText languageCode;
        optional timestamp validFrom;
        optional timestamp validTo;
        // ...
    }
}
```

Key points:

- `package (com.arvatosystems) t9t.ssm` — the `(com.arvatosystems)` clause sets the **Java**
  package prefix, so the generated Java classes land in `com.arvatosystems.t9t.ssm`. The
  **TypeScript** module path is derived from the package name `t9t.ssm`.
- `default private unsigned trim noControlChars` — package-level defaults applied to every field.
- `properties ... is <annotation>` — declares named properties that map to Java annotations.
- `type schedulerId is t9tShortId` — a type alias; `t9tShortId` is a `String`-backed short id.
- The enums are **alpha enums** (each constant has a string token), so on the wire they are
  serialized as their token (`"s"`, `"m"`, …), not as ordinals.
- `SchedulerSetupRef` / `SchedulerSetupKey` / `SchedulerSetupDTO` form a ref → key → DTO
  hierarchy, which is what the API generator recognizes as a CRUD pattern.

### 1.2 The `.bon` source (request)

`t9t-ssm-api/src/main/bon/request/ssm.bon` (abridged):

```bon
package (com.arvatosystems) t9t.ssm.request {
    default private unsigned trim noControlChars;
    properties noJava, simpleref;

    class SchedulerSetupCrudRequest
        extends CrudSurrogateKeyRequest<SchedulerSetupRef, SchedulerSetupDTO, FullTrackingWithVersion> {
        optional Boolean suppressResponseParameters;
    }

    class SchedulerSetupSearchRequest
        extends SearchRequest<SchedulerSetupDTO, FullTrackingWithVersion> {
        optional Boolean suppressResponseParameters;
    }

    class LeanSchedulerSetupSearchRequest extends LeanSearchRequest {}

    class ClearAllRequest extends RequestParameters {}

    class UpdateSchedulerDataRequest extends RequestParameters {
        required enum api.OperationType operationType;
        required schedulerId schedulerId;
        optional (SchedulerSetupDTO) setup;
    }

    class DealWithPriorJobInstancesRequest extends RequestParameters
        return DealWithPriorJobInstancesResponse {
        required f42Ref schedulerSetupRef;
    }

    class DealWithPriorJobInstancesResponse extends ServiceResponse {
        required boolean invokeNewInstance;
    }

    class PerformScheduledJobWithCheckRequest extends RequestParameters {
        required f42Ref schedulerSetupRef;
        required enum SchedulerConcurrencyType concurrencyType;
        required (RequestParameters...) request;
    }
}
```

The `extends CrudSurrogateKeyRequest<...>` and `extends SearchRequest<...>` base classes are the
signals the **API generator** uses to emit a full CRUD/search client (see
[TypeScript API Generator](05-typescript-api-generator.md)).

### 1.3 Generated TypeScript model — `SchedulerSetupDTO.ts`

Output: `t9t-ssm-jpa/src/generated/ts/t9t-ssm-api/t9t/ssm/SchedulerSetupDTO.ts` (abridged):

```ts
// autogenerated by bonaparte DSL. Do not modify, changes will be lost.
import type { BonaPortable } from "@arvato-systems-jacs/t9t-api";
import type { SchedulerSetupRef } from "./SchedulerSetupRef";
import type { CannedRequestRef } from "@arvato-systems-jacs/t9t-api/t9t-core-api";
import type { SchedulerSetupRecurrenceType } from "./SchedulerSetupRecurrenceType";

export const SchedulerSetupDTOPQON = "t9t.ssm.SchedulerSetupDTO" as const;

export interface SchedulerSetupDTO extends Omit<SchedulerSetupRef, '@PQON'> {
    /**
     * @bonaparte.required true
     * @bonaparte.minLength 1
     * @bonaparte.maxLength 16
     * @bonaparte.property notupdatable
     */
    schedulerId: string;
    /**
     * @bonaparte.required true
     * @bonaparte.property active
     */
    isActive: boolean;
    /**
     * @bonaparte.required false
     * @bonaparte.maxLength 80
     */
    name?: string | null;
    /**
     * @bonaparte.required true
     * @bonaparte.property ref
     * @bonaparte.property dropdown="cannedRequestId"
     * @bonaparte.property searchprefix="cannedRequest"
     */
    request: CannedRequestRef;
    /**
     * @bonaparte.required false
     * @bonaparte.wireFormat iso-8601-string
     */
    validFrom?: string | null;
}
```

Observe the mapping rules in action:

- `extends Omit<SchedulerSetupRef, '@PQON'>` — the DTO **extends** its parent ref, and the
  inherited `@PQON` discriminator is omitted (each class carries its own).
- `required` fields are non-optional; `optional` fields become `?: T | null`.
- The `schedulerId` alias resolves to `string` with `minLength`/`maxLength` from `t9tShortId`.
- Every field carries `@bonaparte.*` JSDoc metadata (required, length, properties, wire format).
- `timestamp` fields are typed `string` with `@bonaparte.wireFormat iso-8601-string`.

### 1.4 Generated TypeScript API — `SchedulerSetupApi.ts`

Output: `t9t-ssm-jpa/src/generated/ts/t9t-ssm-api/t9t/ssm/request/SchedulerSetupApi.ts`
(abridged):

```ts
// autogenerated by bonaparte DSL. Do not modify, changes will be lost.
import { inject, Injectable } from '@angular/core';
import { Observable, map } from 'rxjs';
import type { BonaPortable } from '@arvato-systems-jacs/t9t-api';
import { RpcClient } from '@arvato-systems-jacs/t9t-api';
import { unwrapCrud, unwrapVoid, unwrapSearch } from '@arvato-systems-jacs/t9t-api';
import type { SchedulerSetupCrudRequest } from "./SchedulerSetupCrudRequest";
import type { SchedulerSetupRef } from "../SchedulerSetupRef";
import type { SchedulerSetupKey } from "../SchedulerSetupKey";
import type { SchedulerSetupDTO } from "../SchedulerSetupDTO";
import type { CrudSurrogateKeyResponse } from "@arvato-systems-jacs/t9t-api/t9t-base-api";
import type { SchedulerSetupSearchRequest } from "./SchedulerSetupSearchRequest";
import type { ReadAllResponse } from "@arvato-systems-jacs/t9t-api/t9t-base-api";
import type { FullTrackingWithVersion } from "@arvato-systems-jacs/t9t-api/t9t-base-api";

export interface SchedulerSetupCrudRequestExtras
    extends Pick<SchedulerSetupCrudRequest, 'suppressResponseParameters'> {}

const SchedulerSetupCrudRequestPQON = "t9t.ssm.request.SchedulerSetupCrudRequest";

@Injectable({ providedIn: 'root' })
export class SchedulerSetupApi {
    private readonly rpc = inject(RpcClient);

    create(data: SchedulerSetupDTO, extras: ... = {}): Observable<SchedulerSetupDTO> {
        return this.rpc.call<CrudSurrogateKeyResponse<SchedulerSetupDTO, TrackingBase>>(
            SchedulerSetupCrudRequestPQON,
            { ...extras, crud: 'C', onlyActive: false, data }).pipe(map(unwrapCrud<SchedulerSetupDTO>));
    }

    read(key: number, extras: ... = {}): Observable<SchedulerSetupDTO> {
        return this.rpc.call<CrudSurrogateKeyResponse<SchedulerSetupDTO, TrackingBase>>(
            SchedulerSetupCrudRequestPQON,
            { ...extras, crud: 'R', onlyActive: false, key }).pipe(map(unwrapCrud<SchedulerSetupDTO>));
    }

    update(key: number, data: Partial<SchedulerSetupDTO>, extras: ... = {}): Observable<SchedulerSetupDTO> {
        return this.rpc.call<CrudSurrogateKeyResponse<SchedulerSetupDTO, TrackingBase>>(
            SchedulerSetupCrudRequestPQON,
            { ...extras, crud: 'U', onlyActive: false, key, data }).pipe(map(unwrapCrud<SchedulerSetupDTO>));
    }

    delete(key: number, extras: ... = {}): Observable<void> {
        return this.rpc.call<CrudSurrogateKeyResponse<SchedulerSetupDTO, TrackingBase>>(
            SchedulerSetupCrudRequestPQON,
            { ...extras, crud: 'D', onlyActive: false, key }).pipe(map(unwrapVoid));
    }

    readByNaturalKey(naturalKey: SchedulerSetupRef | SchedulerSetupKey | SchedulerSetupDTO,
                     extras: ... = {}): Observable<SchedulerSetupDTO> {
        return this.rpc.call<CrudSurrogateKeyResponse<SchedulerSetupDTO, TrackingBase>>(
            SchedulerSetupCrudRequestPQON,
            { ...extras, crud: 'R', onlyActive: false, naturalKey }).pipe(map(unwrapCrud<SchedulerSetupDTO>));
    }

    search(params: Omit<SchedulerSetupSearchRequest, '@PQON' | 'offset' | 'suppressResponseParameters'>
           & { offset?: number } & SchedulerSetupSearchRequestExtras): Observable<SchedulerSetupDTO[]> {
        return this.rpc.call<ReadAllResponse<SchedulerSetupDTO, FullTrackingWithVersion>>(
            SchedulerSetupSearchRequestPQON,
            { ...params, offset: params.offset ?? 0 }).pipe(map(unwrapSearch<SchedulerSetupDTO>));
    }
}
```

The generator recognized the `CrudSurrogateKeyRequest` / `SearchRequest` base classes and emitted:

- An `@Injectable` Angular service with an injected `RpcClient`.
- `create` / `read` / `update` / `delete` methods that set `crud: 'C' | 'R' | 'U' | 'D'`.
- `*ByNaturalKey` variants that accept the ref/key/DTO union.
- A `search` method that unwraps a `ReadAllResponse` into an array.
- `*Extras` interfaces that `Pick` the optional `suppressResponseParameters` field.

### 1.5 The barrel — `index.ts`

Output: `t9t-ssm-jpa/src/generated/ts/t9t-ssm-api/index.ts` (abridged):

```ts
// autogenerated by bonaparte DSL. Do not modify, changes will be lost.
export { SchedulerSetupCrudRequestPQON } from './t9t/ssm/request/SchedulerSetupCrudRequest';
export type { SchedulerSetupCrudRequest } from './t9t/ssm/request/SchedulerSetupCrudRequest';
export { isSchedulerSetupCrudRequest } from './t9t/ssm/request/SchedulerSetupCrudRequest';
export { SchedulerSetupRecurrenceType } from './t9t/ssm/SchedulerSetupRecurrenceType';
export { SchedulerSetupRefPQON } from './t9t/ssm/SchedulerSetupRef';
export type { SchedulerSetupRef } from './t9t/ssm/SchedulerSetupRef';
export { isSchedulerSetupRef } from './t9t/ssm/SchedulerSetupRef';
export { SchedulerSetupDTOPQON } from './t9t/ssm/SchedulerSetupDTO';
export type { SchedulerSetupDTO } from './t9t/ssm/SchedulerSetupDTO';
// ...
```

For every generated type the barrel re-exports the `PQON` constant, the type, and (for classes)
the `is*` type guard.

## Example 2 — bonaparte-java `testEnum.bon` (enum variants)

`bonaparte-java/persistence-core-test/src/main/bon/enums/testEnum.bon` demonstrates the full range
of enum forms:

```bon
package testEnums {
    enum Color { RED, GREEN, BLUE }                 // numeric enum (ordinals)
    enumset Colormap is Color                        // integer bitmap
    enum AlphaColor { RED="R", GREEN="G", BLUE="B" } // alpha enum (tokens)
    enumset <String> Letterset is Alphabet           // string-backed enumset
    enum AlphaColorWithNull { RED="R", TRANSPARENT="" } // alpha enum with empty token
    xenum XColor is AlphaColor:1                     // extended enum
    xenumset XColormap is XColor                     // extended enumset
    class EnumTests BeanVal
    class TypeWithEnums {
        required xenumset XColormap(10) colors;
    }
}

package enumWithDefaults {
    default enum
    // ...
}
```

How each form is emitted:

| `.bon` form | Java | TypeScript wire format |
|-------------|------|------------------------|
| `enum Color { RED, GREEN, BLUE }` | `enum Color { RED, GREEN, BLUE }` | numeric ordinal (`0`, `1`, `2`) |
| `enumset Colormap is Color` | `EnumSet<Color>` | integer bitmap |
| `enum AlphaColor { RED="R", ... }` | `enum` with token constants | token string (`"R"`, …) |
| `enumset <String> Letterset is Alphabet` | `EnumSet` over string enum | string |
| `xenum XColor is AlphaColor:1` | extended enum class | token string |
| `xenumset XColormap is XColor` | extended enumset | string |

The `default enum` package clause makes every enum in that package an alpha enum by default.

## Example 3 — bonaparte-java `datetime.bon` (date/time types)

`bonaparte-java/persistence-core-test/src/main/bon/datetime/datetime.bon`:

```bon
package datetime {
    class Sample {
        Long key;
        Time(0) myTime0;
        Time(3) myTime3;
        Timestamp(0) myTimestamp0;
        Timestamp(3) myTimestamp3;
        Instant(0) myInstant0;
        Instant(3) myInstant3;
    }
}
```

The `(0)` / `(3)` suffix is the **precision** (fractional-seconds digits). With the default
`DateTime=true` setting these map to `java.time` types:

| `.bon` type | Java (`DateTime=true`) | Java (`DateTime=false`) |
|-------------|------------------------|--------------------------|
| `Time(p)` | `java.time.LocalTime` | `org.joda.time.LocalTime` |
| `Timestamp(p)` | `java.time.LocalDateTime` | `org.joda.time.LocalDateTime` |
| `Instant(p)` | `java.time.Instant` | `org.joda.time.Instant` |

On the TypeScript wire, `Instant` is an epoch-seconds `number`, while `Time` / `Timestamp` are
ISO-8601 strings (see [TypeScript Generator](04-typescript-generator.md)).

## Where to look

- `t9t/t9t-ssm-api/src/main/bon/` — the `.bon` sources for Example 1.
- `t9t/t9t-ssm-jpa/src/generated/ts/t9t-ssm-api/` — the generated TypeScript for Example 1.
- `bonaparte-java/persistence-core-test/src/main/bon/` — the `.bon` sources for Examples 2 & 3.

## See also

- [DSL Syntax](02-dsl-syntax.md) — the full language reference.
- [Java Generator](03-java-generator.md) · [TypeScript Generator](04-typescript-generator.md) ·
  [TypeScript API Generator](05-typescript-api-generator.md) — how each output is produced.
- [Configuration Reference](07-configuration-reference.md) — the settings that drive generation.
