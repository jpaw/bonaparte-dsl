package de.jpaw.bonaparte.dsl.generator.tsapi

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassReference
import de.jpaw.bonaparte.dsl.generator.ts.TsImportCollector
import de.jpaw.bonaparte.dsl.generator.ts.TsModuleResolver
import de.jpaw.bonaparte.dsl.generator.ts.TypeScriptBonScriptGeneratorMain
import java.util.ArrayList
import java.util.LinkedHashMap
import java.util.LinkedHashSet
import java.util.List
import java.util.Map
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess2

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*

class TsApiClientGenerator {
    def void doGenerate(Resource resource, IFileSystemAccess2 fsa) {
        if (!TsModuleResolver.isCurrentModule(resource))
            return

        val groups = new LinkedHashMap<String, List<TsRequestClassifier.RequestInfo>>
        for (source : resource.resourceSet.resources.filter[source | TsModuleResolver.isCurrentModule(source)]) {
            for (request : source.allContents.toIterable.filter(typeof(ClassDefinition))) {
                val info = TsRequestClassifier.classify(request)
                if (info !== null && info.pattern != TsRequestClassifier.Pattern.UNKNOWN) {
                    val apiClass = TsNaming.apiClassName(request.package.name, info.dtoName, request.name,
                        info.pattern)
                    val groupKey = request.package.name + "|" + apiClass
                    var requests = groups.get(groupKey)
                    if (requests === null) {
                        requests = new ArrayList<TsRequestClassifier.RequestInfo>
                        groups.put(groupKey, requests)
                    }
                    requests.add(info)
                }
            }
        }

        for (group : groups.values) {
            val first = group.head.request
            val apiClass = TsNaming.apiClassName(first.package.name, group.head.dtoName,
                group.head.request.name, group.head.pattern)
                fsa.generateFile(TsModuleResolver.generatedFile(first, apiClass),
                writeApi(first.package.name, apiClass, group))
        }
        if (TsModuleResolver.currentEntryPoint(resource) !== null)
            fsa.generateFile(TsModuleResolver.outputFolder(resource) + "api-index.ts",
                writeApiIndex(groups.values))
    }

    def private static CharSequence writeApiIndex(Iterable<List<TsRequestClassifier.RequestInfo>> groups) {
        val exports = new LinkedHashMap<String, String>
        for (group : groups) {
            val first = group.head.request
            val apiClass = TsNaming.apiClassName(first.package.name, group.head.dtoName,
                first.name, group.head.pattern)
            val modulePath = "./" + TsModuleResolver.packagePath(first) + "/" + apiClass
            val publicApiName = uniqueExportName(apiClass, first.package.name, exports)
            val apiSpecifier = if (publicApiName == apiClass) apiClass else apiClass + " as " + publicApiName
            exports.put(publicApiName, "export { " + apiSpecifier + " } from '" + modulePath + "';")
            for (info : group.filter[hasNamedExtras(it)]) {
                val extrasName = extrasTypeName(info)
                val publicExtrasName = uniqueExportName(extrasName, first.package.name, exports)
                val extrasSpecifier = if (publicExtrasName == extrasName) extrasName else extrasName + " as " + publicExtrasName
                exports.put(publicExtrasName, "export type { " + extrasSpecifier + " } from '" + modulePath + "';")
            }
        }
        val out = new StringBuilder
        out.append(TypeScriptBonScriptGeneratorMain.GENERATED_COMMENT).append("\n\n")
        if (groups.empty)
            out.append("export {};\n")
        for (entry : exports.values)
            out.append(entry).append("\n")
        out
    }

    def private static String uniqueExportName(String name, String packageName, Map<String, String> exports) {
        if (!exports.containsKey(name))
            return name
        val qualifier = packageName.split("\\.").filter[!equals("t9t") && !equals("api")]
            .map[capitalize(it)].join
        val simpleName = if (name.startsWith("Api")) name.substring(3) else name
        var candidate = (if (qualifier.empty) "Generated" else qualifier) + simpleName
        var suffix = 2
        while (exports.containsKey(candidate)) {
            candidate = (if (qualifier.empty) "Generated" else qualifier) + simpleName + suffix
            suffix++
        }
        candidate
    }

    def private static CharSequence writeApi(String packageName, String apiClass,
            List<TsRequestClassifier.RequestInfo> requests) {
        val imports = new TsImportCollector
        for (info : requests) {
            imports.add(info.request)
            if (info.dtoRef !== null)
                collectTypeImports(info.dtoRef, imports)
            if (info.responseDtoRef !== null)
                collectTypeImports(info.responseDtoRef, imports)
            if (info.refName !== null) {
                val refType = findType(info.request, info.refName)
                if (refType !== null)
                    imports.add(refType)
                for (subclass : refSubclasses(info))
                    imports.add(subclass)
            }
            if (info.responseRef !== null)
                collectTypeImports(info.responseRef, imports)
        }

        val out = new StringBuilder
        out.append(TypeScriptBonScriptGeneratorMain.GENERATED_COMMENT).append("\n\n")
        out.append("import { inject, Injectable } from '@angular/core';\n")
        out.append("import { Observable, map } from 'rxjs';\n")
        out.append("import type { BonaPortable } from '")
            .append(TsModuleResolver.runtimeSupportImport(requests.head.request, apiClass, "bona-portable"))
            .append("';\n")
        out.append("import { RpcClient } from '")
            .append(TsModuleResolver.runtimeSupportImport(requests.head.request, apiClass, "rpc-client"))
            .append("';\n")
        val unwraps = new LinkedHashSet<String>
        for (info : requests.filter[responsePattern != TsRequestClassifier.ResponsePattern.DIRECT]) {
            unwraps.add(unwrapName(info.responsePattern))
            if (isCrud(info.pattern))
                unwraps.add("unwrapVoid")
        }
        if (!unwraps.empty)
            out.append("import { ").append(unwraps.join(", ")).append(" } from '")
                .append(TsModuleResolver.runtimeSupportImport(requests.head.request, apiClass, "unwrap"))
                .append("';\n")
        for (info : requests.filter[responsePattern == TsRequestClassifier.ResponsePattern.LEAN_SEARCH]) {
            val description = findDescription(info.request, info.responseRef.classRef.package.name)
            if (description !== null) {
                imports.add(description)
            }
        }
        for (type : imports.types) {
            val name = TsImportCollector.simpleName(type)
            val importedName = TsModuleResolver.importedTypeName(requests.head.request, type)
            out.append("import type { ").append(importedName)
            if (importedName != name)
                out.append(" as ").append(name)
            out.append(" } from \"")
                .append(TsModuleResolver.importPath(requests.head.request, apiClass, type, name))
                .append("\";\n")
        }
        for (info : requests.filter[hasNamedExtras(it)])
            out.append("\n").append(writeExtrasInterface(info))
        for (info : requests)
            out.append("\nconst ").append(info.request.name).append("PQON = \"")
                .append(TsModuleResolver.pqon(info.request)).append("\";\n")
        out.append("\n@Injectable({ providedIn: 'root' })\n")
        out.append("export class ").append(apiClass).append(" {\n")
        out.append("    private readonly rpc = inject(RpcClient);\n")
        val usedMethods = new LinkedHashSet<String>
        for (info : requests) {
            var methodName = TsNaming.methodName(info.request.name, info.pattern, info.dtoName)
            if (isCrud(info.pattern))
                methodName = "execute" + (if (methodName.startsWith("create")) methodName.substring(6) else "")
            if (!usedMethods.add(methodName)) {
                methodName = methodName + capitalize(info.request.name)
                usedMethods.add(methodName)
            }
            val wireType = if (info.responseRef === null) "void" else renderType(info.responseRef)
            val resultType = resultType(info, wireType)
            val paramsType = requestParameterType(info)
            val paramsValue = if (hasPaging(info.pattern)) "{ ...params, offset: params.offset ?? 0 }" else "params"
            out.append("\n    ").append(methodName).append("(params: ").append(paramsType)
                .append("): Observable<").append(resultType).append("> {\n")
            out.append("        return this.rpc.call<").append(wireType).append(">(")
                .append(info.request.name).append("PQON, ").append(paramsValue).append(")")
            if (info.responsePattern != TsRequestClassifier.ResponsePattern.DIRECT)
                out.append(".pipe(map(").append(unwrapExpression(info)).append("))")
            out.append(";\n")
            out.append("    }\n")
            if (isCrud(info.pattern))
                out.append(writeCrudMethods(info, methodName))
        }
        out.append("}\n")
        return out
    }

    def private static String requestParameterType(TsRequestClassifier.RequestInfo info) {
        val excluded = new ArrayList<String>
        excluded.add("'@PQON'")
        if (hasPaging(info.pattern))
            excluded.add("'offset'")
        if (hasNamedExtras(info))
            for (field : info.request.fields)
                excluded.add("'" + field.name + "'")
        var result = "Omit<" + info.request.name + ", " + excluded.join(" | ") + ">"
        if (hasPaging(info.pattern))
            result += " & { offset?: number }"
        if (hasNamedExtras(info))
            result += " & " + extrasTypeName(info)
        return result
    }

    def private static CharSequence writeExtrasInterface(TsRequestClassifier.RequestInfo info) {
        "export interface " + extrasTypeName(info) + " extends Pick<" + info.request.name + ", "
            + extraFieldNames(info) + "> {}\n"
    }

    def private static String extrasTypeName(TsRequestClassifier.RequestInfo info) {
        info.request.name + "Extras"
    }

    def private static String extraFieldNames(TsRequestClassifier.RequestInfo info) {
        info.request.fields.map["'" + name + "'"].join(" | ")
    }

    def private static boolean hasNamedExtras(TsRequestClassifier.RequestInfo info) {
        !info.request.fields.empty && (isCrud(info.pattern) || hasPaging(info.pattern))
    }

    def private static CharSequence writeCrudMethods(TsRequestClassifier.RequestInfo info, String executeName) {
        val dto = info.dtoName ?: "unknown"
        val ref = switch (info.pattern) {
            case CRUD_STRING: "string"
            case CRUD_SURROGATE: "number"
            default: refTypeUnion(info)
        }
        val naturalKeyRef = refTypeUnion(info)
        val suffix = if (executeName.startsWith("execute")) executeName.substring("execute".length) else ""
        val wireType = if (info.responseRef === null) "void" else renderType(info.responseRef)
        val excluded = new ArrayList<String>
        excluded.add("'@PQON'")
        excluded.add("'crud'")
        excluded.add("'data'")
        excluded.add("'onlyActive'")
        if (hasNamedExtras(info))
            for (field : info.request.fields)
                excluded.add("'" + field.name + "'")
        val extrasType = "Partial<Omit<" + info.request.name + ", " + excluded.join(" | ") + ">>"
            + (if (hasNamedExtras(info)) " & " + extrasTypeName(info) else "")
        val extrasDefault = if (info.request.fields.exists[cannotBeNull]) "" else " = {}"
        val methods = '''

            «"create" + suffix»(data: «dto», extras: «extrasType»«extrasDefault»): Observable<«dto»> {
                return this.rpc.call<«wireType»>(«info.request.name»PQON, { ...extras, crud: 'C', onlyActive: false, data }).pipe(map(unwrapCrud<«dto»>));
            }

            «"read" + suffix»(key: «ref», extras: «extrasType»«extrasDefault»): Observable<«dto»> {
                return this.rpc.call<«wireType»>(«info.request.name»PQON, { ...extras, crud: 'R', onlyActive: false, key }).pipe(map(unwrapCrud<«dto»>));
            }

            «"update" + suffix»(key: «ref», data: Partial<«dto»>, extras: «extrasType»«extrasDefault»): Observable<«dto»> {
                return this.rpc.call<«wireType»>(«info.request.name»PQON, { ...extras, crud: 'U', onlyActive: false, key, data }).pipe(map(unwrapCrud<«dto»>));
            }

            «"delete" + suffix»(key: «ref», extras: «extrasType»«extrasDefault»): Observable<void> {
                return this.rpc.call<«wireType»>(«info.request.name»PQON, { ...extras, crud: 'D', onlyActive: false, key }).pipe(map(unwrapVoid));
            }
        '''
        val naturalKeyMethods = if (info.pattern == TsRequestClassifier.Pattern.CRUD_SURROGATE) '''

            «"readByNaturalKey" + suffix»(naturalKey: «naturalKeyRef», extras: «extrasType»«extrasDefault»): Observable<«dto»> {
                return this.rpc.call<«wireType»>(«info.request.name»PQON, { ...extras, crud: 'R', onlyActive: false, naturalKey }).pipe(map(unwrapCrud<«dto»>));
            }

            «"updateByNaturalKey" + suffix»(naturalKey: «naturalKeyRef», data: Partial<«dto»>, extras: «extrasType»«extrasDefault»): Observable<«dto»> {
                return this.rpc.call<«wireType»>(«info.request.name»PQON, { ...extras, crud: 'U', onlyActive: false, naturalKey, data }).pipe(map(unwrapCrud<«dto»>));
            }

            «"deleteByNaturalKey" + suffix»(naturalKey: «naturalKeyRef», extras: «extrasType»«extrasDefault»): Observable<void> {
                return this.rpc.call<«wireType»>(«info.request.name»PQON, { ...extras, crud: 'D', onlyActive: false, naturalKey }).pipe(map(unwrapVoid));
            }
        ''' else ""
        return (methods.toString + naturalKeyMethods.toString).replaceAll("\\n(?=[ \\t]*\\S)", "\n    ")
    }

    def private static String refTypeUnion(TsRequestClassifier.RequestInfo info) {
        val refType = findType(info.request, info.refName)
        if (refType === null)
            return info.refName ?: "unknown"
        val types = new LinkedHashSet<String>
        types.add(refType.name)
        for (subclass : refSubclasses(info))
            types.add(subclass.name)
        return types.join(" | ")
    }

    def private static List<ClassDefinition> refSubclasses(TsRequestClassifier.RequestInfo info) {
        val refType = findType(info.request, info.refName)
        if (refType === null)
            return new ArrayList<ClassDefinition>
        val subclasses = new ArrayList<ClassDefinition>
        for (source : info.request.eResource.resourceSet.resources) {
            for (candidate : source.allContents.toIterable.filter(typeof(ClassDefinition))) {
                if (candidate !== refType && !candidate.isAbstract && extendsType(candidate, refType))
                    subclasses.add(candidate)
            }
        }
        return subclasses
    }

    def private static boolean extendsType(ClassDefinition candidate, ClassDefinition ancestor) {
        var ClassDefinition current = candidate
        while (current.extendsClass !== null && current.extendsClass.classRef !== null) {
            current = current.extendsClass.classRef
            if (current === ancestor)
                return true
        }
        return false
    }

    def private static void collectTypeImports(ClassReference ref, TsImportCollector imports) {
        if (ref.classRef !== null)
            imports.add(ref.classRef)
        for (argument : ref.classRefGenericParms)
            collectTypeImports(argument, imports)
    }

    def private static String renderType(ClassReference ref) {
        if (ref.plainObject)
            return "BonaPortable"
        if (ref.classRef !== null) {
            val arguments = ref.classRefGenericParms.map[renderType(it)]
            return ref.classRef.name + (if (arguments.empty) "" else "<" + arguments.join(", ") + ">")
        }
        if (ref.genericsParameterRef !== null)
            return ref.genericsParameterRef.name
        return "unknown"
    }

    def private static String resultType(TsRequestClassifier.RequestInfo info, String wireType) {
        switch (info.responsePattern) {
            case SEARCH: (info.responseDtoName ?: info.dtoName ?: "unknown") + "[]"
            case CRUD: if (info.dtoName === null) "unknown" else info.dtoName
            case RESOLVE: "number"
            case RESOLVE_MANY: "number[]"
            case LEAN_SEARCH: "Description[]"
            case SERVICE: "Omit<" + wireType + ", 'returnCode'>"
            case DIRECT: wireType
            case VOID: "void"
        }
    }

    def private static String unwrapExpression(TsRequestClassifier.RequestInfo info) {
        switch (info.responsePattern) {
            case SEARCH: "unwrapSearch<" + (info.responseDtoName ?: info.dtoName ?: "unknown") + ">"
            case CRUD: "unwrapCrud<" + (info.dtoName ?: "unknown") + ">"
            case RESOLVE: "unwrapResolve"
            case RESOLVE_MANY: "unwrapResolveMany"
            case LEAN_SEARCH: "unwrapLean"
            case SERVICE: "unwrapService<" + renderType(info.responseRef) + ">"
            case DIRECT: null
            case VOID: "unwrapVoid"
        }
    }

    def private static boolean isCrud(TsRequestClassifier.Pattern pattern) {
        pattern == TsRequestClassifier.Pattern.CRUD_SURROGATE
                || pattern == TsRequestClassifier.Pattern.CRUD_STRING
                || pattern == TsRequestClassifier.Pattern.CRUD_COMPOSITE
                || pattern == TsRequestClassifier.Pattern.CRUD_MODULE
    }

    def private static boolean hasPaging(TsRequestClassifier.Pattern pattern) {
        pattern == TsRequestClassifier.Pattern.SEARCH
                || pattern == TsRequestClassifier.Pattern.LEAN_SEARCH
                || pattern == TsRequestClassifier.Pattern.RESOLVE_MANY
    }

    def private static ClassDefinition findDescription(ClassDefinition request, String packageName) {
        for (resource : request.eResource.resourceSet.resources)
            for (candidate : resource.allContents.toIterable.filter(typeof(ClassDefinition)))
                if (candidate.name == "Description" && candidate.package.name == packageName)
                    return candidate
        return null
    }

    def private static ClassDefinition findType(ClassDefinition request, String typeName) {
        for (resource : request.eResource.resourceSet.resources)
            for (candidate : resource.allContents.toIterable.filter(typeof(ClassDefinition)))
                if (candidate.name == typeName)
                    return candidate
        return null
    }

    def private static String unwrapName(TsRequestClassifier.ResponsePattern pattern) {
        switch (pattern) {
            case SEARCH: "unwrapSearch"
            case CRUD: "unwrapCrud"
            case RESOLVE: "unwrapResolve"
            case RESOLVE_MANY: "unwrapResolveMany"
            case LEAN_SEARCH: "unwrapLean"
            case SERVICE: "unwrapService"
            case DIRECT: null
            case VOID: "unwrapVoid"
        }
    }

    def private static String capitalize(String name) {
        if (name.length == 0) name else name.substring(0, 1).toUpperCase + name.substring(1)
    }
}