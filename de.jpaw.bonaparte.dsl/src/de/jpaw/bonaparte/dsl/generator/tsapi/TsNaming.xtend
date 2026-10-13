package de.jpaw.bonaparte.dsl.generator.tsapi

class TsNaming {
    def static String apiClassName(String packageName, String dtoName) {
        if (dtoName !== null)
            return stripDto(dtoName) + "Api"
        val parts = packageName.split("\\.")
        var index = parts.length - 1
        while (index > 0 && (parts.get(index) == "request" || parts.get(index) == "dto"))
            index--
        return capitalize(parts.get(index)) + "Api"
    }

    def static String apiClassName(String packageName, String dtoName, String requestName,
            TsRequestClassifier.Pattern pattern) {
        if (pattern == TsRequestClassifier.Pattern.SPECIAL)
            return apiClassName(packageName, null)
        if (dtoName !== null)
            return apiClassName(packageName, dtoName)
        val entity = entityName(requestName, pattern)
        if (entity.length > 0)
            return entity + "Api"
        return apiClassName(packageName, null)
    }

    def static String methodName(String requestName, TsRequestClassifier.Pattern pattern, String dtoName) {
        val requestStem = if (requestName.endsWith("Request"))
                requestName.substring(0, requestName.length - "Request".length)
            else requestName
        val dtoStem = if (dtoName === null) entityName(requestName, pattern) else stripDto(dtoName)
        val remainder = if (dtoStem.length > 0 && requestStem.startsWith(dtoStem))
                requestStem.substring(dtoStem.length)
            else requestStem
        val method = switch (pattern) {
            case SEARCH: "search"
            case LEAN_SEARCH: "leanSearch"
            case CRUD_SURROGATE: "create"
            case CRUD_STRING: "create"
            case CRUD_COMPOSITE: "create"
            case CRUD_MODULE: "create"
            case RESOLVE: "resolve"
            case RESOLVE_MANY: "resolveMany"
            default: lowerCamel(requestStem)
        }
        val patternPrefix = switch (pattern) {
            case SEARCH: "Search"
            case LEAN_SEARCH: "LeanSearch"
            case CRUD_SURROGATE: "Crud"
            case CRUD_STRING: "Crud"
            case CRUD_COMPOSITE: "Crud"
            case CRUD_MODULE: "Crud"
            case RESOLVE: "Resolver"
            case RESOLVE_MANY: "MassResolver"
            default: ""
        }
        if (patternPrefix.length > 0) {
            val patternIndex = remainder.indexOf(patternPrefix)
            if (patternIndex >= 0) {
                val suffix = if (dtoName === null)
                        remainder.substring(patternIndex + patternPrefix.length)
                    else remainder.substring(0, patternIndex)
                        + remainder.substring(patternIndex + patternPrefix.length)
                return method + capitalize(suffix)
            }
        }
        return method
    }

    def private static String stripDto(String name) {
        if (name.endsWith("DTO")) name.substring(0, name.length - 3) else name
    }

    def private static String entityName(String requestName, TsRequestClassifier.Pattern pattern) {
        val stem = if (requestName.endsWith("Request"))
                requestName.substring(0, requestName.length - "Request".length)
            else requestName
        val marker = switch (pattern) {
            case SEARCH: "Search"
            case LEAN_SEARCH: "LeanSearch"
            case CRUD_SURROGATE: "Crud"
            case CRUD_STRING: "Crud"
            case CRUD_COMPOSITE: "Crud"
            case CRUD_MODULE: "Crud"
            case RESOLVE: "Resolver"
            case RESOLVE_MANY: "MassResolver"
            default: ""
        }
        if (marker.length == 0)
            return ""
        val index = stem.indexOf(marker)
        if (index > 0) stem.substring(0, index) else ""
    }

    def private static String lowerCamel(String name) {
        if (name.length == 0) name else name.substring(0, 1).toLowerCase + name.substring(1)
    }

    def private static String capitalize(String name) {
        if (name.length == 0) name else name.substring(0, 1).toUpperCase + name.substring(1)
    }
}