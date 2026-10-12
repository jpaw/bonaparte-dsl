#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
dsl_root="$(cd -- "$script_dir/.." && pwd)"
a28_root="${A28_ROOT:-$dsl_root/../a28}"
takko_root="${TAKKO_ROOT:-$dsl_root/../aroma2-takko}"
plugin_version="6.6.3-SNAPSHOT"

java_home="${JAVA_HOME:-}"
if [[ -z "$java_home" && "$(uname -s)" == "Darwin" ]]; then
    java_home="$(/usr/libexec/java_home -v 21)"
fi
if [[ -z "$java_home" || ! -x "$java_home/bin/java" ]]; then
    printf 'Set JAVA_HOME to a Java 21 installation.\n' >&2
    exit 2
fi
java_version="$("$java_home/bin/java" -version 2>&1 | sed -n '1s/.*version "\([0-9]*\).*/\1/p')"
if [[ "$java_version" != "21" ]]; then
    printf 'Expected Java 21, found Java %s.\n' "${java_version:-unknown}" >&2
    exit 2
fi
export JAVA_HOME="$java_home"
export PATH="$JAVA_HOME/bin:$PATH"

for project in "$a28_root/a28-sku-api" "$takko_root/takko-api"; do
    if [[ ! -d "$project" ]]; then
        printf 'Missing consumer module: %s\n' "$project" >&2
        exit 2
    fi
done

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

printf '%s\n' \
    'bonaparte-core=@arvato-systems-jacs/bonaparte-api,bonaparte-core' \
    'bonaparte-api=@arvato-systems-jacs/bonaparte-api,bonaparte-api' \
    'bonaparte-api-auth=@arvato-systems-jacs/bonaparte-api,bonaparte-auth' \
    'bonaparte-api-media=@arvato-systems-jacs/bonaparte-api,bonaparte-media' \
    > "$tmp_dir/bonaparte-ts-external-modules.properties"

printf '%s\n' \
    't9t-base-api=@arvato-systems-jacs/t9t-api,base' \
    't9t-annotations-api=@arvato-systems-jacs/t9t-api,annotations' \
    't9t-cfg-api=@arvato-systems-jacs/t9t-api,cfg' \
    'a28-base-api=@arvato-systems-jacs/a28-api,base' \
    'commerce-api=@arvato-systems-jacs/a28-api,commerce' \
    'a28-sku-api=@arvato-systems-jacs/a28-api,sku' \
    > "$tmp_dir/a28-ts-modules.properties"

printf '%s\n' \
    't9t-base-api=@arvato-systems-jacs/t9t-api,base' \
    't9t-annotations-api=@arvato-systems-jacs/t9t-api,annotations' \
    't9t-cfg-api=@arvato-systems-jacs/t9t-api,cfg' \
    't9t-io-api=@arvato-systems-jacs/t9t-api,io' \
    't9t-core-api=@arvato-systems-jacs/t9t-api,core' \
    't9t-doc-api=@arvato-systems-jacs/t9t-api,doc' \
    'a28-base-api=@arvato-systems-jacs/a28-api,base' \
    'commerce-api=@arvato-systems-jacs/a28-api,commerce' \
    'a28-pricing-api=@arvato-systems-jacs/a28-api,pricing' \
    'a28-customer-api=@arvato-systems-jacs/a28-api,customer' \
    'a28-history-api=@arvato-systems-jacs/a28-api,history' \
    'a28-sku-api=@arvato-systems-jacs/a28-api,sku' \
    'a28-order-api=@arvato-systems-jacs/a28-api,order' \
    'takko-api=@arvato-systems-jacs/takko-api,takko' \
    > "$tmp_dir/takko-ts-modules.properties"

(cd "$dsl_root" && mvn -q install)

(cd "$a28_root" && mvn -q -pl a28-sku-api process-sources -DskipTests \
    "-Dbonaparte-plugin.version=$plugin_version" \
    -Dbonaparte.TypeScript=true \
    -Dbonaparte.TypeScript.module=a28-sku-api \
    "-Dbonaparte.TypeScript.modulesFile=$tmp_dir/a28-ts-modules.properties" \
    "-Dbonaparte.TypeScript.externalModulesFile=$tmp_dir/bonaparte-ts-external-modules.properties")

(cd "$takko_root" && mvn -q -pl takko-api process-sources -DskipTests \
    "-Dbonaparte-plugin.version=$plugin_version" \
    -Dbonaparte.TypeScript=true \
    -Dbonaparte.TypeScript.module=takko-api \
    "-Dbonaparte.TypeScript.modulesFile=$tmp_dir/takko-ts-modules.properties" \
    "-Dbonaparte.TypeScript.externalModulesFile=$tmp_dir/bonaparte-ts-external-modules.properties")

a28_ts_root="$a28_root/a28-sku-api/src/generated/ts/sku"
takko_ts_root="$takko_root/takko-api/src/generated/ts/takko"
a28_api="$a28_ts_root/t9t/a28sku/request/ProductApi.ts"
a28_mass_api="$a28_ts_root/t9t/a28sku/request/SkuApi.ts"
takko_request="$takko_ts_root/t9t/a28takko/StockProximitySearchRequest.ts"
if [[ ! -f "$a28_api" ]] || ! grep -Fq 'create(data: ProductDTO,' "$a28_api" \
    || ! grep -Fq 'resolve(params:' "$a28_api" \
    || ! grep -Fq "Omit<ProductSearchRequest, '@PQON' | 'offset'> & { offset?: number }" "$a28_api" \
    || ! grep -Fq 'ProductSearchRequestPQON, { ...params, offset: params.offset ?? 0 }' "$a28_api"; then
    printf 'Expected a28 generated API signatures were not found.\n' >&2
    exit 1
fi
if [[ ! -f "$a28_mass_api" ]] || ! grep -Fq 'resolveMany(params:' "$a28_mass_api" \
    || ! grep -Fq 'map(unwrapResolveMany)' "$a28_mass_api"; then
    printf 'Expected a28 mass-resolver API signatures were not found.\n' >&2
    exit 1
fi
if [[ ! -f "$takko_request" ]] || ! grep -Fq "'@PQON':" "$takko_request"; then
    printf 'Expected Takko generated BON request was not found.\n' >&2
    exit 1
fi
if grep -Eq '^[[:blank:]]+$' "$a28_api"; then
    printf 'Whitespace-only lines found in %s.\n' "$a28_api" >&2
    exit 1
fi

a28_count="$(find "$a28_ts_root" -type f -name '*.ts' | wc -l | tr -d '[:space:]')"
takko_count="$(find "$takko_ts_root" -type f -name '*.ts' | wc -l | tr -d '[:space:]')"
printf 'Generation checks passed: a28-sku-api emitted %s TypeScript files; takko-api emitted %s.\n' "$a28_count" "$takko_count"
printf 'This validates generation and module closure, not consumer TypeScript compilation; lower-layer npm entry points are not packaged yet.\n'
