package de.jpaw.bonaparte.dsl.generator.tsapi

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassReference
import org.eclipse.emf.ecore.util.EcoreUtil
import java.util.LinkedHashMap
import java.util.Map

class TsRequestClassifier {
    enum Pattern {
        SEARCH, LEAN_SEARCH, CRUD_SURROGATE, CRUD_STRING, CRUD_COMPOSITE,
        CRUD_MODULE, RESOLVE, RESOLVE_MANY, SPECIAL, UNKNOWN
    }

    enum ResponsePattern {
        SEARCH, CRUD, RESOLVE, RESOLVE_MANY, LEAN_SEARCH, SERVICE, DIRECT, VOID
    }

    static class RequestInfo {
        public ClassDefinition request
        public Pattern pattern = Pattern.UNKNOWN
        public String dtoName
        public ClassReference dtoRef
        public ClassReference responseDtoRef
        public String responseDtoName
        public String refName
        public String trackingName
        public ClassReference responseRef
        public ResponsePattern responsePattern = ResponsePattern.VOID
    }

    def static RequestInfo classify(ClassDefinition request) {
        if (request.isAbstract)
            return null

        var ClassDefinition current = request
        var Map<String, ClassReference> bindings = new LinkedHashMap
        while (current.extendsClass !== null && current.extendsClass.classRef !== null) {
            val parentRef = current.extendsClass
            val parent = parentRef.classRef
            val pattern = patternFor(parent.name)
            if (pattern != Pattern.UNKNOWN) {
                val info = new RequestInfo
                info.request = request
                info.pattern = pattern
                info.responseRef = findResponseRef(request)
                info.responsePattern = responsePattern(info.responseRef)
                if (info.responsePattern == ResponsePattern.SEARCH) {
                    info.responseDtoRef = responsePayload(info.responseRef, "SearchResponse")
                    info.responseDtoName = referenceName(info.responseDtoRef)
                }
                if (isSearchOrCrud(pattern) && info.responseRef !== null
                        && !hasExpectedResponse(info.responseRef, pattern))
                    info.pattern = Pattern.SPECIAL
                if (isSearchOrCrud(pattern)) {
                    val dtoIndex = if (pattern == Pattern.CRUD_SURROGATE || pattern == Pattern.CRUD_COMPOSITE) 1 else 0
                    if (dtoIndex < parentRef.classRefGenericParms.size)
                        info.dtoRef = resolvedCopy(parentRef.classRefGenericParms.get(dtoIndex), bindings, 0)
                }
                switch (pattern) {
                    case SEARCH: {
                        info.dtoName = genericName(parentRef, bindings, 0)
                        info.trackingName = genericName(parentRef, bindings, 1)
                    }
                    case CRUD_SURROGATE: {
                        info.refName = genericName(parentRef, bindings, 0)
                        info.dtoName = genericName(parentRef, bindings, 1)
                        info.trackingName = genericName(parentRef, bindings, 2)
                    }
                    case CRUD_STRING: {
                        info.dtoName = genericName(parentRef, bindings, 0)
                        info.trackingName = genericName(parentRef, bindings, 1)
                    }
                    case CRUD_COMPOSITE: {
                        info.refName = genericName(parentRef, bindings, 0)
                        info.dtoName = genericName(parentRef, bindings, 1)
                        info.trackingName = genericName(parentRef, bindings, 2)
                    }
                    case CRUD_MODULE: {
                        info.dtoName = genericName(parentRef, bindings, 0)
                        if (parent.extendsClass !== null && parent.extendsClass.classRef !== null
                                && parent.extendsClass.classRef.name == "CrudCompositeKeyRequest")
                            info.refName = genericName(parent.extendsClass, bindings, 0)
                    }
                    case RESOLVE:
                        info.refName = genericName(parentRef, bindings, 0)
                    case LEAN_SEARCH: {
                    }
                    case RESOLVE_MANY: {
                    }
                    case SPECIAL: {
                    }
                    case UNKNOWN: {
                    }
                }
                return info
            }

            val parentBindings = new LinkedHashMap<String, ClassReference>
            val parameters = parent.genericParameters
            for (i : 0 ..< Math.min(parameters.size, parentRef.classRefGenericParms.size))
                parentBindings.put(parameters.get(i).name,
                    resolveReference(parentRef.classRefGenericParms.get(i), bindings, 0))
            current = parent
            bindings = parentBindings
        }
        return null
    }

    def private static ClassReference findResponseRef(ClassDefinition request) {
        var ClassDefinition current = request
        var Map<String, ClassReference> bindings = new LinkedHashMap
        while (current !== null) {
            if (current.returnsClassRef !== null)
                return resolvedCopy(current.returnsClassRef, bindings, 0)
            val parentRef = current.extendsClass
            if (parentRef === null || parentRef.classRef === null)
                return null
            val parent = parentRef.classRef
            val parentBindings = new LinkedHashMap<String, ClassReference>
            val parameters = parent.genericParameters
            for (i : 0 ..< Math.min(parameters.size, parentRef.classRefGenericParms.size))
                parentBindings.put(parameters.get(i).name,
                    resolvedCopy(parentRef.classRefGenericParms.get(i), bindings, 0))
            bindings = parentBindings
            current = parent
        }
        return null
    }

    def private static ClassReference resolvedCopy(ClassReference ref, Map<String, ClassReference> bindings, int depth) {
        if (depth > 16)
            return EcoreUtil.copy(ref)
        if (ref.genericsParameterRef !== null) {
            val actual = bindings.get(ref.genericsParameterRef.name)
            if (actual !== null && actual !== ref)
                return resolvedCopy(actual, bindings, depth + 1)
        }
        val copy = EcoreUtil.copy(ref)
        copy.classRef = ref.classRef
        copy.classRefGenericParms.clear
        for (argument : ref.classRefGenericParms)
            copy.classRefGenericParms.add(resolvedCopy(argument, bindings, depth + 1))
        return copy
    }

    def private static ResponsePattern responsePattern(ClassReference response) {
        if (response === null || response.classRef === null)
            return ResponsePattern.VOID
        val type = response.classRef
        if (hasAncestor(type, "SearchResponse"))
            return ResponsePattern.SEARCH
        if (hasAncestor(type, "CrudAnyKeyResponse"))
            return ResponsePattern.CRUD
        if (hasAncestor(type, "RefResolverResponse"))
            return ResponsePattern.RESOLVE
        if (hasAncestor(type, "MassResolverResponse"))
            return ResponsePattern.RESOLVE_MANY
        if (hasAncestor(type, "LeanSearchResponse"))
            return ResponsePattern.LEAN_SEARCH
        if (type.name == "ServiceResponse")
            return ResponsePattern.VOID
        if (hasAncestor(type, "ServiceResponse"))
            return ResponsePattern.SERVICE
        return ResponsePattern.DIRECT
    }

    def private static ClassReference responsePayload(ClassReference response, String ancestorName) {
        var ClassReference current = response
        for (depth : 0 ..< 64) {
            if (current === null || current.classRef === null)
                return null
            val type = current.classRef
            if (type.name == ancestorName)
                return if (current.classRefGenericParms.empty) null else current.classRefGenericParms.head
            val bindings = new LinkedHashMap<String, ClassReference>
            for (index : 0 ..< Math.min(type.genericParameters.size, current.classRefGenericParms.size))
                bindings.put(type.genericParameters.get(index).name, current.classRefGenericParms.get(index))
            current = if (type.extendsClass === null) null else resolvedCopy(type.extendsClass, bindings, 0)
        }
        return null
    }

    def private static boolean hasExpectedResponse(ClassReference response, Pattern pattern) {
        if (response.classRef === null)
            return false
        if (pattern == Pattern.SEARCH)
            return hasAncestor(response.classRef, "SearchResponse")
        return hasAncestor(response.classRef, "CrudAnyKeyResponse")
    }

    def private static boolean isSearchOrCrud(Pattern pattern) {
        pattern == Pattern.SEARCH || pattern == Pattern.CRUD_SURROGATE
                || pattern == Pattern.CRUD_STRING || pattern == Pattern.CRUD_COMPOSITE
                || pattern == Pattern.CRUD_MODULE
    }

    def private static boolean hasAncestor(ClassDefinition type, String ancestorName) {
        var ClassDefinition current = type
        while (current !== null) {
            if (current.name == ancestorName)
                return true
            current = if (current.extendsClass !== null) current.extendsClass.classRef else null
        }
        return false
    }

    def private static Pattern patternFor(String name) {
        switch (name) {
            case "SearchRequest": Pattern.SEARCH
            case "LeanSearchRequest": Pattern.LEAN_SEARCH
            case "CrudSurrogateKeyRequest": Pattern.CRUD_SURROGATE
            case "CrudStringKeyRequest": Pattern.CRUD_STRING
            case "CrudCompositeKeyRequest": Pattern.CRUD_COMPOSITE
            case "CrudModuleCfgRequest": Pattern.CRUD_MODULE
            case "RefResolverRequest": Pattern.RESOLVE
            case "MassResolverRequest": Pattern.RESOLVE_MANY
            case "RequestParameters": Pattern.SPECIAL
            default: Pattern.UNKNOWN
        }
    }

    def private static String genericName(ClassReference ref, Map<String, ClassReference> bindings, int index) {
        if (index >= ref.classRefGenericParms.size)
            return null
        val resolved = resolveReference(ref.classRefGenericParms.get(index), bindings, 0)
        return referenceName(resolved)
    }

    def private static String referenceName(ClassReference resolved) {
        if (resolved === null)
            return null
        if (resolved.plainObject)
            return "BonaPortable"
        if (resolved.classRef !== null)
            return resolved.classRef.name
        if (resolved.genericsParameterRef !== null)
            return resolved.genericsParameterRef.name
        return null
    }

    def private static ClassReference resolveReference(ClassReference ref, Map<String, ClassReference> bindings, int depth) {
        if (depth > 16 || ref.genericsParameterRef === null)
            return ref
        val actual = bindings.get(ref.genericsParameterRef.name)
        if (actual === null || actual === ref)
            return ref
        return resolveReference(actual, bindings, depth + 1)
    }
}