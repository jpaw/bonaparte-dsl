package de.jpaw.bonaparte.dsl.generator.ts;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Properties;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.resource.Resource;

import de.jpaw.bonaparte.dsl.BonScriptPreferences;
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition;

public final class TsModuleResolver {
    private static final String POM_PROPERTIES = "META-INF/maven/";
    private static final String MODULES_PROPERTY_SEPARATOR = ",";
    private static final String PORTABLE_OWNER_MODULE = "bonaparte-core";
    private static final String PORTABLE_OWNER_IMPORT = "@arvato-systems-jacs/bonaparte/bonaparte-core";

    private TsModuleResolver() {
    }

    public static boolean isCurrentModule(Resource resource) {
        TsGenerationContext context = TsGenerationContext.from(resource);
        if (context != null)
            return "bon".equals(resource.getURI().fileExtension())
                && context.currentOwner().equals(context.owner(resource.getURI()));
        String currentModule = BonScriptPreferences.getTsModule();
        String resourceModule = moduleId(resource.getURI());
        if (resourceModule == null)
            return true;
        return currentModule != null && currentModule.equals(resourceModule);
    }

    public static boolean isSameModule(EObject left, EObject right) {
        if (left.eResource() == null || right.eResource() == null)
            return true;
        TsGenerationContext context = TsGenerationContext.from(left.eResource());
        if (context != null)
            return context.owner(left.eResource().getURI()).equals(context.owner(right.eResource().getURI()));
        String leftModule = moduleId(left.eResource().getURI());
        String rightModule = moduleId(right.eResource().getURI());
        return leftModule == null || rightModule == null || leftModule.equals(rightModule);
    }

    public static boolean isSameModule(Resource left, Resource right) {
        TsGenerationContext context = TsGenerationContext.from(left);
        if (context != null)
            return "bon".equals(left.getURI().fileExtension()) && "bon".equals(right.getURI().fileExtension())
                && context.owner(left.getURI()).equals(context.owner(right.getURI()));
        String leftModule = moduleId(left.getURI());
        String rightModule = moduleId(right.getURI());
        if (leftModule == null || rightModule == null)
            return isCurrentModule(left) && isCurrentModule(right);
        return leftModule.equals(rightModule);
    }

    public static boolean isIncludedModule(Resource resource) {
        String resourceModule = moduleId(resource.getURI());
        String includedModules = BonScriptPreferences.getTsIncludedModules();
        if (resourceModule == null || includedModules == null || includedModules.isBlank())
            return false;
        for (String module : includedModules.split(MODULES_PROPERTY_SEPARATOR)) {
            if (resourceModule.equals(module.trim()))
                return true;
        }
        return false;
    }

    public static String typeGuard(String typeName, String pqon) {
        return "export function is" + typeName + "(value: unknown): value is " + typeName + " {\n"
                + "    return typeof value === \"object\" && value !== null && (value as Record<string, unknown>)[\"@PQON\"] === \""
                + pqon + "\";\n"
                + "}\n";
    }

    public static String crossModuleImport(EObject from, EObject target) {
        if (from.eResource() == null || target.eResource() == null)
            return null;
        TsGenerationContext context = TsGenerationContext.from(from.eResource());
        if (context != null) {
            TsGenerationContext.Owner sourceOwner = context.owner(from.eResource().getURI());
            TsGenerationContext.Owner targetOwner = context.owner(target.eResource().getURI());
            return sourceOwner.equals(targetOwner) ? null : targetOwner.importSpecifier();
        }
        String currentModule = moduleId(from.eResource().getURI());
        String targetModule = moduleId(target.eResource().getURI());
        if (currentModule == null || targetModule == null || currentModule.equals(targetModule))
            return null;

        String externalModulesFile = BonScriptPreferences.getTsExternalModulesFile();
        if (externalModulesFile != null && !externalModulesFile.isBlank()) {
            Properties externalModules = loadModules(externalModulesFile);
            if (externalModules.containsKey(targetModule))
                return importSpecifier(targetModule, externalModules);
        }

        String modulesFile = BonScriptPreferences.getTsModulesFile();
        if (modulesFile == null || modulesFile.isBlank()) {
            String npmPackage = BonScriptPreferences.getTsNpmPackage();
            if (npmPackage != null && !npmPackage.isBlank())
                return npmPackage + "/" + targetModule;
            throw new IllegalStateException("Cross-module TypeScript import from " + currentModule + " to "
                    + targetModule + " requires bonaparte.TypeScript.modulesFile");
        }

        Properties modules = loadModules(modulesFile);
        if (!modules.containsKey(targetModule))
            throw new IllegalStateException("TypeScript dependency closure for " + currentModule
                    + " does not contain module " + targetModule);
        return importSpecifier(targetModule, modules);
    }

    public static String importPath(EObject from, String fromTypeName, EObject target, String targetTypeName) {
        if (from == null || target == null)
            throw new IllegalArgumentException("Cannot resolve TypeScript import: source and target BON types are required");
        if (fromTypeName == null || fromTypeName.isBlank() || targetTypeName == null || targetTypeName.isBlank())
            throw new IllegalArgumentException("Cannot resolve TypeScript import without generated source and target names");
        String crossModule = crossModuleImport(from, target);
        if (crossModule != null)
            return crossModule;
        return relativeSpecifier(generatedTypePath(from, fromTypeName), generatedTypePath(target, targetTypeName));
    }

    public static String importedTypeName(EObject from, EObject target) {
        if (crossModuleImport(from, target) == null)
            return TsImportCollector.simpleName(target);
        return TsModuleExportNames.exportNameInModule(target);
    }

    public static String runtimeSupportImport(EObject from, String fromTypeName, String supportModule) {
        if (from == null)
            throw new IllegalArgumentException("Cannot resolve TypeScript runtime import without a source BON type");
        if (fromTypeName == null || fromTypeName.isBlank() || supportModule == null || supportModule.isBlank())
            throw new IllegalArgumentException("Cannot resolve TypeScript runtime import without generated source and support names");
        if ("bona-portable".equals(supportModule) || TsMetaRuntimeSource.MODULE_NAME.equals(supportModule)) {
            Resource resource = from.eResource();
            if (!generatesPortableSupport(resource))
                return PORTABLE_OWNER_IMPORT;
            String folder = resource == null ? outputFolder() : outputFolder(resource);
            return relativeSpecifier(generatedTypePath(from, fromTypeName), Paths.get(folder, supportModule));
        }
        TsGenerationContext context = TsGenerationContext.from(from.eResource());
        if (context != null)
            return context.dependencyOwner("com.arvato-systems.t9t", "t9t-base-api").npmPackage();
        String npmPackage = BonScriptPreferences.getTsNpmPackage();
        if (npmPackage != null && !npmPackage.isBlank())
            return npmPackage;
        Path source = generatedTypePath(from, fromTypeName);
        Path target = Paths.get("ts", "rpc-core", supportModule);
        return relativeSpecifier(source, target);
    }

    public static boolean generatesPortableSupport(Resource resource) {
        TsGenerationContext context = TsGenerationContext.from(resource);
        if (context != null)
            return PORTABLE_OWNER_MODULE.equals(context.owner(resource.getURI()).artifactId());
        String artifactId = resource == null ? null : moduleId(resource.getURI());
        if (artifactId == null)
            artifactId = BonScriptPreferences.getTsModule();
        return artifactId == null || artifactId.isBlank() || PORTABLE_OWNER_MODULE.equals(artifactId);
    }

    public static String packagePath(EObject type) {
        PackageDefinition bonPackage = bonPackage(type);
        if (bonPackage == null)
            throw new IllegalArgumentException("Cannot resolve BON package for TypeScript type "
                    + TsImportCollector.simpleName(type));
        return packagePath(bonPackage.getName());
    }

    public static String packagePath(String bonPackageName) {
        if (bonPackageName == null || bonPackageName.isBlank())
            throw new IllegalArgumentException("Cannot resolve TypeScript path without a BON package name");
        return bonPackageName.replace('.', '/');
    }

    public static String qualifiedExportName(EObject type) {
        PackageDefinition bonPackage = bonPackage(type);
        if (bonPackage == null)
            throw new IllegalArgumentException("Cannot qualify TypeScript export name for "
                    + TsImportCollector.simpleName(type));
        StringBuilder name = new StringBuilder();
        for (String segment : bonPackage.getName().split("\\.")) {
            if (!segment.isEmpty())
                name.append(Character.toUpperCase(segment.charAt(0))).append(segment.substring(1));
        }
        return name.append(TsImportCollector.simpleName(type)).toString();
    }

    public static String pqon(EObject type) {
        PackageDefinition bonPackage = bonPackage(type);
        if (bonPackage == null)
            throw new IllegalArgumentException("Cannot resolve PQON for TypeScript type "
                    + TsImportCollector.simpleName(type));
        return bonPackage.getName() + "." + TsImportCollector.simpleName(type);
    }

    public static String generatedFile(EObject packageOwner, String generatedName) {
        if (packageOwner == null || generatedName == null || generatedName.isBlank())
            throw new IllegalArgumentException("Cannot resolve TypeScript output without a BON type and generated name");
        return outputFolder(packageOwner.eResource()) + packagePath(packageOwner) + "/" + generatedName + ".ts";
    }

    private static Path generatedTypePath(EObject type, String typeName) {
        Resource resource = type.eResource();
        String folder = resource == null ? outputFolder() : outputFolder(resource);
        return Paths.get(folder).resolve(packagePath(type)).resolve(typeName).normalize();
    }

    private static PackageDefinition bonPackage(EObject type) {
        for (EObject current = type; current != null; current = current.eContainer()) {
            if (current instanceof PackageDefinition)
                return (PackageDefinition) current;
        }
        return null;
    }

    private static String relativeSpecifier(Path source, Path target) {
        Path relative = source.getParent().relativize(target);
        String specifier = relative.toString().replace('\\', '/');
        return specifier.startsWith(".") ? specifier : "./" + specifier;
    }

    public static String importSpecifier(String artifactId, Properties modules) {
        String[] mapping = moduleMapping(artifactId, modules);
        return mapping[0] + "/" + mapping[1];
    }

    public static String currentEntryPoint() {
        String currentModule = BonScriptPreferences.getTsModule();
        String modulesFile = BonScriptPreferences.getTsModulesFile();
        if (currentModule == null || currentModule.isBlank())
            return null;
        if (modulesFile == null || modulesFile.isBlank())
            return BonScriptPreferences.getTsNpmPackage() == null ? null : currentModule;
        return entryPoint(currentModule, loadModules(modulesFile));
    }

    public static String currentEntryPoint(Resource resource) {
        TsGenerationContext context = TsGenerationContext.from(resource);
        return context == null ? currentEntryPoint() : context.currentOwner().artifactId();
    }

    public static String outputFolder() {
        String entryPoint = currentEntryPoint();
        return entryPoint == null ? "ts/" : "ts/" + entryPoint + "/";
    }

    public static String outputFolder(Resource resource) {
        TsGenerationContext context = TsGenerationContext.from(resource);
        if (context != null)
            return "ts/" + context.owner(resource.getURI()).artifactId() + "/";
        String artifactId = moduleId(resource.getURI());
        if (artifactId == null)
            return outputFolder();
        String modulesFile = BonScriptPreferences.getTsModulesFile();
        String entryPoint = modulesFile == null || modulesFile.isBlank()
                ? artifactId : entryPoint(artifactId, loadModules(modulesFile));
        return "ts/" + entryPoint + "/";
    }

    public static boolean isModule(Resource resource, String artifactId) {
        String resourceModule = moduleId(resource.getURI());
        if (artifactId == null)
            return resourceModule == null && isCurrentModule(resource);
        return artifactId.equals(resourceModule);
    }

    public static String entryPoint(String artifactId, Properties modules) {
        return moduleMapping(artifactId, modules)[1];
    }

    private static String[] moduleMapping(String artifactId, Properties modules) {
        String[] mapping = modules.getProperty(artifactId, "").split(MODULES_PROPERTY_SEPARATOR, 2);
        if (mapping.length != 2 || mapping[0].isBlank() || mapping[1].isBlank())
            throw new IllegalStateException("Invalid or missing TypeScript module mapping for " + artifactId
                    + ": expected <npm-package>,<entry-point>");
        return new String[] { mapping[0].trim(), mapping[1].trim() };
    }

    private static Properties loadModules(String path) {
        Properties modules = new Properties();
        try (InputStream input = new FileInputStream(path)) {
            modules.load(input);
        } catch (IOException e) {
            throw new IllegalStateException("Cannot read TypeScript module map " + path, e);
        }
        return modules;
    }

    public static String moduleId(URI uri) {
        String value = uri.toString();
        if (value.startsWith("jar:") || value.startsWith("archive:"))
            return moduleIdFromJar(value);
        if (value.startsWith("file:"))
            return BonScriptPreferences.getTsModule();
        return null;
    }

    private static String moduleIdFromJar(String resourceUri) {
        int bang = resourceUri.indexOf('!');
        if (bang < 0)
            return null;
        String jarUri = resourceUri.substring(resourceUri.indexOf(':') + 1, bang);
        File jarFile = new File(URI.createURI(jarUri).toFileString());
        try (JarFile jar = new JarFile(jarFile)) {
            var entries = jar.entries();
            while (entries.hasMoreElements()) {
                JarEntry entry = entries.nextElement();
                String name = entry.getName();
                if (name.startsWith(POM_PROPERTIES) && name.endsWith("/pom.properties")) {
                    try (InputStream input = jar.getInputStream(entry)) {
                        Properties properties = new Properties();
                        properties.load(input);
                        String artifactId = properties.getProperty("artifactId");
                        if (artifactId != null)
                            return artifactId;
                    }
                }
            }
        } catch (IOException e) {
            throw new IllegalStateException("Cannot resolve BonScript module from " + jarFile, e);
        }
        return null;
    }
}