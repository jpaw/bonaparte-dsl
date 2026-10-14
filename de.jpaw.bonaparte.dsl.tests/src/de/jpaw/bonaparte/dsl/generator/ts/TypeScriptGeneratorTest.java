package de.jpaw.bonaparte.dsl.generator.ts;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.jar.JarEntry;
import java.util.jar.JarOutputStream;

import org.eclipse.emf.common.util.TreeIterator;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.common.util.URI;
import org.eclipse.xtext.generator.GeneratorContext;
import org.eclipse.xtext.generator.InMemoryFileSystemAccess;
import org.eclipse.xtext.resource.XtextResource;
import org.eclipse.xtext.resource.XtextResourceSet;
import org.eclipse.xtext.util.CancelIndicator;
import org.eclipse.xtext.validation.CheckMode;
import org.eclipse.xtext.validation.IResourceValidator;
import org.eclipse.xtext.validation.Issue;
import org.junit.BeforeClass;
import org.junit.Test;

import com.google.inject.Injector;

import de.jpaw.bonaparte.dsl.BonScriptStandaloneSetup;
import de.jpaw.bonaparte.dsl.BonScriptMavenSetup;
import de.jpaw.bonaparte.dsl.BonScriptPreferences;
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition;
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition;
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension;
import de.jpaw.bonaparte.dsl.generator.BonScriptGenerator;
import de.jpaw.bonaparte.dsl.generator.tsapi.TsApiClientGenerator;
import de.jpaw.bonaparte.dsl.generator.tsapi.TsRequestClassifier;
import de.jpaw.bonaparte.dsl.generator.tsapi.TsNaming;

/** Parses small .bon sources and checks the TypeScript produced by the generator. */
public class TypeScriptGeneratorTest {
    private static final String ROOT = "DEFAULT_OUTPUT" + TypeScriptBonScriptGeneratorMain.GENERATED_TS_SUBFOLDER;

    private static Injector injector;

    private static final String BON_SOURCE = String.join("\n",
        "package com.acme.base {",
        "    enum SortOrder { ASC, DESC }",
        "    enum Mode { A = \"a\", B = \"b\" }",
        "    xenum TimeUnit is Mode : 1;",
        "    enumset<int> SortOrderSet is SortOrder;",
        "    enumset<String> StringSortOrderSet is SortOrder;",
        "    enumset DefaultSortOrderSet is SortOrder;",
        "    xenumset TimeUnitSet is TimeUnit;",
        "    class Base {",
        "        required long objectRef;",
        "    }",
        "    @Deprecated",
        "    class Legacy {",
        "        required long id;",
        "    }",
        "}",
        "package com.acme.auth {",
        "    type Name is unicode(30);",
        "    class Child<T> extends com.acme.base.Base {",
        "        required Name name;",
        "        optional Unicode(20) nickname;",
        "        required boolean active;",
        "        optional Integer age;",
        "        optional Instant created;",
        "        required enum com.acme.base.SortOrder order;",
        "        optional XEnum com.acme.base.TimeUnit unit;",
        "        required unicode(10) required List<5> tags;",
        "        optional Unicode(10) Map<String> labels;",
        "        optional (com.acme.base.Base) other;",
        "        optional (!T) payload;",
        "        optional Json extra;",
        "        required enumset com.acme.base.SortOrderSet modes;",
        "        required enumset com.acme.base.StringSortOrderSet stringModes;",
        "        required enumset com.acme.base.DefaultSortOrderSet defaultModes;",
        "        required xenumset com.acme.base.TimeUnitSet(10) units;",
        "        optional Object blob;",
        "        @Deprecated",
        "        optional Integer oldAge;",
        "    }",
        "}",
        "");

    private static final String CLASSIFIER_SOURCE = String.join("\n",
        "package com.acme.api {",
        "    class ServiceResponse {}",
        "    class SearchResponse<DATA, TRACKING> extends ServiceResponse {}",
        "    class ReadAllResponse<DATA, TRACKING> extends SearchResponse<!DATA, !TRACKING> {}",
        "    class LeanSearchResponse extends ServiceResponse {}",
        "    class RefResolverResponse extends ServiceResponse {}",
        "    class MassResolverResponse extends ServiceResponse {}",
        "    class CrudAnyKeyResponse<DATA, TRACKING> extends ServiceResponse {}",
        "    class CrudSurrogateResponse<DATA, TRACKING> extends CrudAnyKeyResponse<DATA, TRACKING> {}",
        "    class SearchRequest<DATA, TRACKING> return ReadAllResponse<!DATA, !TRACKING> {}",
        "    class LeanSearchRequest return LeanSearchResponse {}",
        "    class RefResolverRequest<REF> return RefResolverResponse {}",
        "    class MassResolverRequest return MassResolverResponse {}",
        "    abstract class AbstractSearch<T> extends SearchRequest<!T, Audit> {}",
        "    class DirectSearchRequest extends SearchRequest<ProductDTO, Audit> {}",
        "    class InheritedSearchRequest extends AbstractSearch<ProductDTO> {}",
        "    class CustomSearchResponse extends ServiceResponse {}",
        "    class SearchResponseWithTypes<DATA, TRACKING> {}",
        "    class BaseReturnedSearch extends SearchRequest<ProductDTO, Audit> return SearchResponseWithTypes<ProductDTO, Audit> {}",
        "    class InheritedReturnedSearch extends BaseReturnedSearch {}",
        "    class OverrideReturnedSearch extends BaseReturnedSearch return CustomSearchResponse {}",
        "    class GenericResponseBase<DATA, TRACKING> extends SearchRequest<DATA, TRACKING> return SearchResponseWithTypes<!DATA, !TRACKING> {}",
        "    class GenericReturnedSearch extends GenericResponseBase<ProductDTO, Audit> {}",
        "    class DirectLeanSearchRequest extends LeanSearchRequest {}",
        "    class DirectResolverRequest extends RefResolverRequest<ProductRef> {}",
        "    class DirectMassResolverRequest extends MassResolverRequest {}",
        "    class RequestParameters return ServiceResponse {}",
        "    class SpecialRequest extends RequestParameters {}",
        "    abstract class AbstractRequest extends RequestParameters {}",
        "    class ProductDTO {}",
        "    class Audit {}",
        "    class ProductRef {}",
        "    class Description {}",
        "}",
        "");

    private static final String API_SOURCE = String.join("\n",
        "package com.acme.api {",
        "    class ServiceResponse {}",
        "    class SearchResponse<DATA, TRACKING> extends ServiceResponse {}",
        "    class ReadAllResponse<DATA, TRACKING> extends SearchResponse<!DATA, !TRACKING> {}",
        "    class SearchCriteria { required int limit; required int offset; }",
        "    class SearchRequest<DATA, TRACKING> extends SearchCriteria return ReadAllResponse<!DATA, !TRACKING> {}",
        "    class ProductDTO {}",
        "    class FullTracking {}",
            "    class ProductSearchRequest extends SearchRequest<ProductDTO, FullTracking> { optional Unicode(20) customScope; }",
        "    class ProductSearchExtendedRequest extends ProductSearchRequest {}",
        "    class LeanSearchResponse extends ServiceResponse {}",
        "    class Description {}",
        "    class LeanSearchRequest extends SearchCriteria return LeanSearchResponse {}",
        "    class PriceListLeanSearchRequest extends LeanSearchRequest {}",
        "    class RefResolverResponse extends ServiceResponse {}",
        "    class RefResolverRequest<REF> return RefResolverResponse {}",
        "    class ProductRef {}",
        "    class ProductResolverRequest extends RefResolverRequest<ProductRef> {}",
        "    class MassResolverResponse extends ServiceResponse {}",
        "    class MassResolverRequest extends SearchCriteria return MassResolverResponse {}",
        "    class ProductMassResolverRequest extends MassResolverRequest {}",
        "}",
        "");

    private static final String POLYMORPHIC_SOURCE = String.join("\n",
        "package com.acme.auth {",
        "    abstract class AuthenticationParameters {}",
        "    final class PasswordAuthentication extends AuthenticationParameters { required unicode(16) userId; required unicode(32) password; }",
        "    final class JwtAuthentication extends AuthenticationParameters { required unicode(200) encodedJwt; }",
        "    class AuthenticationRequest { required (AuthenticationParameters...) authenticationParameters; }",
        "}",
        "");

    @BeforeClass
    public static void setup() {
        injector = new BonScriptStandaloneSetup().createInjectorAndDoEMFRegistration();
    }

    private Map<String, CharSequence> generate(String source) throws Exception {
        XtextResource res = parse(source);
        InMemoryFileSystemAccess fsa = new InMemoryFileSystemAccess();
        try {
            injector.getInstance(TypeScriptBonScriptGeneratorMain.class).doGenerate(res, fsa, new GeneratorContext());
        } finally {
            DataTypeExtension.clear();
        }
        return fsa.getTextFiles();
    }

    private Map<String, CharSequence> generateApis(String source) throws Exception {
        XtextResource res = parse(source);
        InMemoryFileSystemAccess fsa = new InMemoryFileSystemAccess();
        injector.getInstance(TsApiClientGenerator.class).doGenerate(res, fsa);
        return fsa.getTextFiles();
    }

    private XtextResource parse(String source) throws Exception {
        XtextResourceSet rs = injector.getInstance(XtextResourceSet.class);
        XtextResource res = (XtextResource) rs.createResource(URI.createURI("dummy:/test.bon"));
        res.load(new ByteArrayInputStream(source.getBytes(StandardCharsets.UTF_8)), Collections.emptyMap());
        assertTrue("parse errors: " + res.getErrors(), res.getErrors().isEmpty());
        return res;
    }

    private static ClassDefinition findClass(XtextResource resource, String name) {
        TreeIterator<EObject> contents = resource.getAllContents();
        while (contents.hasNext()) {
            EObject object = contents.next();
            if (object instanceof ClassDefinition clazz && name.equals(clazz.getName()))
                return clazz;
        }
        throw new IllegalArgumentException("Unknown BON class: " + name);
    }

    private static ClassDefinition findClass(XtextResource resource, String packageName, String name) {
        TreeIterator<EObject> contents = resource.getAllContents();
        while (contents.hasNext()) {
            EObject object = contents.next();
                if (object instanceof ClassDefinition clazz && name.equals(clazz.getName())
                    && clazz.eContainer() instanceof PackageDefinition bonPackage
                    && packageName.equals(bonPackage.getName()))
                return clazz;
        }
        throw new IllegalArgumentException("Unknown BON class: " + packageName + "." + name);
    }

    private static String norm(CharSequence s) {
        assertNotNull(s);
        return s.toString().replace("\r", "");
    }

    private static Path createModuleJar(String artifactId) throws Exception {
        Path jar = Files.createTempFile(artifactId, ".jar");
        try (JarOutputStream output = new JarOutputStream(Files.newOutputStream(jar))) {
            output.putNextEntry(new JarEntry("META-INF/maven/fixture/" + artifactId + "/pom.properties"));
            output.write(("artifactId=" + artifactId + "\n").getBytes(StandardCharsets.UTF_8));
            output.closeEntry();
        }
        return jar;
    }

    private XtextResource load(XtextResourceSet resourceSet, String source, URI uri) throws Exception {
        XtextResource resource = (XtextResource) resourceSet.createResource(uri);
        resource.load(new ByteArrayInputStream(source.getBytes(StandardCharsets.UTF_8)), Collections.emptyMap());
        assertTrue("parse errors: " + resource.getErrors(), resource.getErrors().isEmpty());
        return resource;
    }

    private static void assertRelativeImportResolves(Map<String, CharSequence> files, String sourcePath,
            String specifier, String targetPath) {
        String resolved = Path.of(sourcePath).getParent().resolve(specifier + ".ts").normalize().toString()
            .replace('\\', '/');
        assertEquals(targetPath, resolved);
        assertTrue("missing generated target " + resolved, files.containsKey(resolved));
    }

    @Test
    public void generatesOneFilePerTypeInPackageFolders() throws Exception {
        Map<String, CharSequence> files = generate(BON_SOURCE);
        for (String f : new String[] { "base/SortOrder", "base/Mode", "base/TimeUnit", "base/SortOrderSet",
            "base/StringSortOrderSet", "base/TimeUnitSet", "base/Base", "auth/Child" })
            assertTrue("missing " + f + " in " + files.keySet(), files.containsKey(ROOT + "com/acme/" + f + ".ts"));
    }

    @Test
    public void enumsAndXEnums() throws Exception {
        Map<String, CharSequence> files = generate(BON_SOURCE);
        // plain enums are serialized as numeric ordinals
        String plain = norm(files.get(ROOT + "com/acme/base/SortOrder.ts"));
        assertTrue(plain, plain.contains("export const SortOrder = {"));
        assertTrue(plain, plain.contains("ASC: 0,"));
        assertTrue(plain, plain.contains("DESC: 1"));
        assertTrue(plain, plain.contains("export type SortOrder = (typeof SortOrder)[keyof typeof SortOrder];"));
        // alphanumeric enums use the token as value
        String alpha = norm(files.get(ROOT + "com/acme/base/Mode.ts"));
        assertTrue(alpha, alpha.contains("A: \"a\","));
        assertTrue(alpha, alpha.contains("B: \"b\""));
        assertTrue(norm(files.get(ROOT + "com/acme/base/TimeUnit.ts")).contains("export type TimeUnit = string;"));
    }

    @Test
    public void alphaEnumPreservesEmptyTokenAndDeprecatedPackage() throws Exception {
        String source = String.join("\n",
            "@Deprecated package com.acme.legacy {",
            "    enum Status { EMPTY = \"\", READY = \"ready\" }",
            "}",
            "");
        String status = norm(generate(source).get(ROOT + "com/acme/legacy/Status.ts"));

        assertTrue(status, status.contains("/** @deprecated */"));
        assertTrue(status, status.contains("EMPTY: \"\","));
        assertTrue(status, status.contains("READY: \"ready\""));
        assertTrue(status, status.contains("export type Status = (typeof Status)[keyof typeof Status];"));
    }

    @Test
    public void xenumInheritanceAndMetadataRemainOpenStringWireTypes() throws Exception {
        String source = String.join("\n",
            "package com.acme.xenums {",
            "    enum RootTokens { ROOT = \"root\", EMPTY = \"\" }",
            "    xenum RootStatus is RootTokens : 6;",
            "    enum ChildTokens { CHILD = \"child\" }",
            "    xenum ChildStatus is ChildTokens extends RootStatus;",
            "    abstract xenum AbstractStatus is ChildTokens extends RootStatus;",
            "    final xenum FinalStatus is RootTokens : 6;",
            "    class StatusHolder { required XEnum RootStatus root; optional XEnum ChildStatus child; }",
            "}",
            "");
        Map<String, CharSequence> files = generate(source);

        for (String name : new String[] { "RootStatus", "ChildStatus", "AbstractStatus", "FinalStatus" }) {
            String xenum = norm(files.get(ROOT + "com/acme/xenums/" + name + ".ts"));
            assertTrue(xenum, xenum.contains("export type " + name + " = string;"));
            assertFalse(xenum, xenum.contains("ROOT") || xenum.contains("CHILD") || xenum.contains("MAX_TOKEN_LENGTH"));
        }
        String holder = norm(files.get(ROOT + "com/acme/xenums/StatusHolder.ts"));
        assertTrue(holder, holder.contains("root: RootStatus;"));
        assertTrue(holder, holder.contains("child?: ChildStatus | null;"));
    }

    @Test
    public void enumValidatorRejectsDuplicateAndOverlongTokens() throws Exception {
        String overlongToken = "x".repeat(64);
        String source = String.join("\n",
            "package com.acme.invalid {",
            "    enum Duplicate { FIRST = \"same\", SECOND = \"same\" }",
            "    enum Overlong { VALUE = \"" + overlongToken + "\" }",
            "}",
            "");
        XtextResource resource = parse(source);
        List<Issue> issues = injector.getInstance(IResourceValidator.class)
            .validate(resource, CheckMode.ALL, CancelIndicator.NullImpl);

        assertTrue(issues.toString(), issues.stream().anyMatch(issue -> issue.getMessage().contains("duplicate token in enum: same")));
        assertTrue(issues.toString(), issues.stream().anyMatch(issue -> issue.getMessage().contains("Token is too long (max 63 characters")));
    }

    @Test
    public void interfaceWithInheritanceAndImports() throws Exception {
        String base = norm(generate(BON_SOURCE).get(ROOT + "com/acme/base/Base.ts"));
        assertTrue(base, base.contains("export const BasePQON = \"com.acme.base.Base\" as const;"));
        assertTrue(base, base.contains("export interface Base {"));
        assertTrue(base, base.contains("objectRef: number;"));

        String child = norm(generate(BON_SOURCE).get(ROOT + "com/acme/auth/Child.ts"));
        assertTrue(child, child.contains("import type { Base } from \"../base/Base\";"));
        assertTrue(child, child.contains("import type { SortOrder } from \"../base/SortOrder\";"));
        assertTrue(child, child.contains("import type { TimeUnit } from \"../base/TimeUnit\";"));
        assertTrue(child, child.contains("import type { SortOrderSet } from \"../base/SortOrderSet\";"));
        assertTrue(child, child.contains("import type { StringSortOrderSet } from \"../base/StringSortOrderSet\";"));
        assertTrue(child, child.contains("import type { TimeUnitSet } from \"../base/TimeUnitSet\";"));
        assertTrue(child, child.contains("export const ChildPQON = \"com.acme.auth.Child\" as const;"));
        assertTrue(child, child.contains("export interface Child<T = unknown> extends Omit<Base, '@PQON'> {"));
        assertTrue(child, child.contains("'@PQON': typeof ChildPQON;"));
    }

    @Test
    public void fieldMetadataPreservesDefaultsConstraintsAndProperties() throws Exception {
        String source = String.join("\n",
            "package com.acme.metadata {",
            "    properties displayName;",
            "    enum Status { ACTIVE = \"active\", INACTIVE = \"inactive\" }",
            "    enum Rank { LOW, HIGH }",
            "    enumset<int> RankSet is Rank;",
            "    class Metadata {",
            "        required unicode(3..20) regexp \"[A-Z]+\" code default \"ABC\" properties displayName=\"Code\";",
            "        optional Uppercase(12) normalized;",
            "        optional decimal(9,2) amount default \"12.50\";",
            "        required instant created;",
            "        required day businessDay;",
            "        required raw(16) rawBytes;",
            "        required binary(24) binaryData;",
            "        required enum Status default status;",
            "        required enum Rank rank;",
            "        required enumset RankSet ranks;",
            "        required Integer required List<1..5> values;",
            "        optional Integer Map<String, 2..8> entries;",
            "        optional Integer Map<Integer, 2..8> numericEntries;",
            "    }",
            "}",
            "");
        String metadata = norm(generate(source).get(ROOT + "com/acme/metadata/Metadata.ts"));

        assertTrue(metadata, metadata.contains("@bonaparte.default \"ABC\""));
        assertTrue(metadata, metadata.contains("@bonaparte.minLength 3"));
        assertTrue(metadata, metadata.contains("@bonaparte.maxLength 20"));
        assertTrue(metadata, metadata.contains("@bonaparte.pattern \"[A-Z]+\""));
        assertTrue(metadata, metadata.contains("@bonaparte.property displayName=\"Code\""));
        assertTrue(metadata, metadata.contains("@bonaparte.case uppercase"));
        assertTrue(metadata, metadata.contains("@bonaparte.default 12.50"));
        assertTrue(metadata, metadata.contains("@bonaparte.precision 9"));
        assertTrue(metadata, metadata.contains("@bonaparte.scale 2"));
        assertFalse(metadata, metadata.contains("@bonaparte.maxLength 9"));
        assertTrue(metadata, metadata.contains("created: number;"));
        assertTrue(metadata, metadata.contains("@bonaparte.wireFormat epoch-seconds"));
        assertTrue(metadata, metadata.contains("businessDay: string;"));
        assertTrue(metadata, metadata.contains("@bonaparte.wireFormat iso-8601-string"));
        assertTrue(metadata, metadata.contains("rawBytes: string;"));
        assertTrue(metadata, metadata.contains("@bonaparte.encoding base64"));
        assertTrue(metadata, metadata.contains("@bonaparte.maxBytes 16"));
        assertTrue(metadata, metadata.contains("binaryData: string;"));
        assertTrue(metadata, metadata.contains("@bonaparte.default \"active\""));
        assertTrue(metadata, metadata.contains("@bonaparte.wireFormat enum-token-string"));
        assertTrue(metadata, metadata.contains("@bonaparte.wireFormat numeric-enum-ordinal"));
        assertTrue(metadata, metadata.contains("@bonaparte.wireFormat numeric-enum-bitmap"));
        assertTrue(metadata, metadata.contains("@bonaparte.aggregate list required"));
        assertTrue(metadata, metadata.contains("@bonaparte.minCount 1"));
        assertTrue(metadata, metadata.contains("@bonaparte.maxCount 5"));
        assertTrue(metadata, metadata.contains("@bonaparte.aggregate map optional"));
        assertTrue(metadata, metadata.contains("@bonaparte.mapKey string"));
        assertTrue(metadata, metadata.contains("@bonaparte.jsonMapKeyFormat identity"));
        assertTrue(metadata, metadata.contains("@bonaparte.mapKey integer"));
        assertTrue(metadata, metadata.contains("@bonaparte.jsonMapKeyFormat underscore-prefixed-decimal"));
        assertTrue(metadata, metadata.contains("@bonaparte.minCount 2"));
        assertTrue(metadata, metadata.contains("@bonaparte.maxCount 8"));
        assertTrue(metadata.indexOf("@bonaparte.default \"ABC\"") < metadata.indexOf("code:"));
    }

    @Test
    public void classMetadataExposesConstraintsPropertiesAndAggregates() throws Exception {
        String source = String.join("\n",
            "package com.acme.metadata {",
            "    properties displayName, tag;",
            "    enum Status { ACTIVE = \"active\", INACTIVE = \"inactive\" }",
            "    class Metadata {",
            "        properties tag=\"a\\\"b\";",
            "        required unicode(3..20) regexp \"[A-Z]+\" code default \"ABC\" properties displayName=\"Code\", tag;",
            "        optional Uppercase(12) normalized;",
            "        optional Decimal(9,2) amount;",
            "        required binary(24) binaryData;",
            "        required enum Status status default \"inactive\";",
            "        required Integer required List<1..5> values;",
            "        optional Integer Map<String, 2..8> entries;",
            "    }",
            "}",
            "");
        Map<String, CharSequence> files = generate(source);
        String metadata = norm(files.get(ROOT + "com/acme/metadata/Metadata.ts"));

        assertTrue(metadata, metadata.contains("import type { TsClassMeta } from \"../../../bona-meta\";"));
        assertTrue(metadata, metadata.contains("export const MetadataMeta: TsClassMeta = {"));
        assertTrue(metadata, metadata.contains("pqon: MetadataPQON,"));
        assertFalse(metadata, metadata.contains("parent:"));
        assertTrue(metadata, metadata.contains("props: { \"tag\": \"a\\\"b\" },"));
        assertTrue(metadata, metadata.contains("propsInherited: false,"));
        assertTrue(metadata, metadata.contains("\"code\": { required: true, default: \"ABC\", minLength: 3, maxLength: 20,"
            + " pattern: \"[A-Z]+\", props: { \"displayName\": \"Code\", \"tag\": true } },"));
        assertTrue(metadata, metadata.contains("\"normalized\": { required: false, maxLength: 12, case: \"uppercase\","));
        assertTrue(metadata, metadata.contains("precision: 9, scale: 2, props: {} },"));
        assertTrue(metadata, metadata.contains("\"binaryData\": { required: true, maxBytes: 24, props: {} },"));
        assertTrue(metadata, metadata.contains("\"status\": { required: true, default: \"inactive\", props: {} },"));
        assertTrue(metadata, metadata.contains("aggregate: { kind: \"list\", minCount: 1, maxCount: 5 },"));
        assertTrue(metadata, metadata.contains("aggregate: { kind: \"map\", minCount: 2, maxCount: 8 },"));

        String index = norm(files.get(ROOT + "index.ts"));
        assertTrue(index, index.contains("export { MetadataMeta } from './com/acme/metadata/Metadata';"));
        assertTrue(index, index.contains("export { bonAllFields, bonClassProp, bonValidate } from './bona-meta';"));
        String runtime = norm(files.get(ROOT + "bona-meta.ts"));
        assertTrue(runtime, runtime.contains("export interface TsClassMeta {"));
        assertTrue(runtime, runtime.contains("export function bonValidate("));
    }

    @Test
    public void classMetadataLinksParentObjectTypesAndReferenceTargets() throws Exception {
        String source = String.join("\n",
            "package com.acme.refs {",
            "    properties ref, searchprefix, dropdown, tag;",
            "    class UserRef {}",
            "    class UserKey extends UserRef { required long id; }",
            "    class UserDTO extends UserRef {",
            "        properties tag=\"user\";",
            "        required unicode(20) name;",
            "    }",
            "    class AdminDTO extends UserDTO {",
            "        properties inherited;",
            "        required boolean root;",
            "    }",
            "    class Holder {",
            "        optional (UserRef...,UserDTO) userRef properties ref, searchprefix=\"user\", dropdown=\"userId\";",
            "        optional (UserRef...,UserKey) keyRef properties ref;",
            "        optional (UserRef...,UserKey) notARef;",
            "        optional (UserDTO) plain;",
            "        optional (Holder) self;",
            "    }",
            "}",
            "");
        Map<String, CharSequence> files = generate(source);

        String admin = norm(files.get(ROOT + "com/acme/refs/AdminDTO.ts"));
        assertTrue(admin, admin.contains("import { UserDTOMeta } from \"./UserDTO\";"));
        assertTrue(admin, admin.contains("parent: () => UserDTOMeta,"));
        assertTrue(admin, admin.contains("propsInherited: true,"));

        String user = norm(files.get(ROOT + "com/acme/refs/UserDTO.ts"));
        assertTrue(user, user.contains("parent: () => UserRefMeta,"));
        assertTrue(user, user.contains("propsInherited: false,"));
        assertTrue(user, user.contains("props: { \"tag\": \"user\" },"));

        String holder = norm(files.get(ROOT + "com/acme/refs/Holder.ts"));
        assertTrue(holder, holder.contains("import { UserRefMeta } from \"./UserRef\";"));
        assertTrue(holder, holder.contains("import { UserDTOMeta } from \"./UserDTO\";"));
        assertTrue(holder, holder.contains("import { UserKeyMeta } from \"./UserKey\";"));
        assertFalse(holder, holder.contains("import { HolderMeta }"));
        assertTrue(holder, holder.contains("\"userRef\": { required: false, props: { \"ref\": true,"
            + " \"searchprefix\": \"user\", \"dropdown\": \"userId\" }, objectType: () => UserRefMeta,"
            + " refTarget: () => UserDTOMeta },"));
        assertTrue(holder, holder.contains("\"keyRef\": { required: false, props: { \"ref\": true },"
            + " objectType: () => UserRefMeta, refTarget: () => UserKeyMeta },"));
        assertTrue(holder, holder.contains("\"notARef\": { required: false, props: {}, objectType: () => UserRefMeta },"));
        assertTrue(holder, holder.contains("\"plain\": { required: false, props: {}, objectType: () => UserDTOMeta },"));
        assertTrue(holder, holder.contains("\"self\": { required: false, props: {}, objectType: () => HolderMeta },"));
    }

    @Test
    public void resolvesImportsFromGeneratedPathsInDefaultAndEntrypointLayouts() throws Exception {
        String source = String.join("\n",
            "package com.acme.deep {",
            "    class Same {}",
            "    class Source {",
            "        required (Same) same;",
            "        required (com.acme.deep.branch.Nested) nested;",
            "        required (com.acme.other.Sibling) sibling;",
            "    }",
            "}",
            "package com.acme.deep.branch { class Nested {} }",
            "package com.acme.other { class Sibling {} }",
            "");
        String previousModule = BonScriptPreferences.currentPrefs.tsModule;
        String previousModulesFile = BonScriptPreferences.currentPrefs.tsModulesFile;
        String previousNpmPackage = BonScriptPreferences.currentPrefs.tsNpmPackage;
        try {
            BonScriptPreferences.currentPrefs.tsModule = null;
            BonScriptPreferences.currentPrefs.tsModulesFile = null;
            BonScriptPreferences.currentPrefs.tsNpmPackage = null;
            Map<String, CharSequence> defaultFiles = generate(source);
            String defaultSourcePath = ROOT + "com/acme/deep/Source.ts";
            String defaultOutput = norm(defaultFiles.get(defaultSourcePath));
            assertTrue(defaultOutput, defaultOutput.contains("from \"./Same\";"));
            assertTrue(defaultOutput, defaultOutput.contains("from \"./branch/Nested\";"));
            assertTrue(defaultOutput, defaultOutput.contains("from \"../other/Sibling\";"));
            assertRelativeImportResolves(defaultFiles, defaultSourcePath, "./Same", ROOT + "com/acme/deep/Same.ts");
            assertRelativeImportResolves(defaultFiles, defaultSourcePath, "./branch/Nested",
                ROOT + "com/acme/deep/branch/Nested.ts");
            assertRelativeImportResolves(defaultFiles, defaultSourcePath, "../other/Sibling",
                ROOT + "com/acme/other/Sibling.ts");

            Path modulesFile = Files.createTempFile("ts-import-modules", ".properties");
            Files.writeString(modulesFile, "fixture-api=@fixture/package,fixture\n");
            BonScriptPreferences.currentPrefs.tsModule = "fixture-api";
            BonScriptPreferences.currentPrefs.tsModulesFile = modulesFile.toString();
            Map<String, CharSequence> entrypointFiles = generate(source);
            String entrypointSourcePath = ROOT + "fixture/com/acme/deep/Source.ts";
            String entrypointOutput = norm(entrypointFiles.get(entrypointSourcePath));
            assertTrue(entrypointOutput, entrypointOutput.contains("from \"./Same\";"));
            assertTrue(entrypointOutput, entrypointOutput.contains("from \"./branch/Nested\";"));
            assertTrue(entrypointOutput, entrypointOutput.contains("from \"../other/Sibling\";"));
            assertRelativeImportResolves(entrypointFiles, entrypointSourcePath, "./Same",
                ROOT + "fixture/com/acme/deep/Same.ts");
            assertRelativeImportResolves(entrypointFiles, entrypointSourcePath, "./branch/Nested",
                ROOT + "fixture/com/acme/deep/branch/Nested.ts");
            assertRelativeImportResolves(entrypointFiles, entrypointSourcePath, "../other/Sibling",
                ROOT + "fixture/com/acme/other/Sibling.ts");
            Files.deleteIfExists(modulesFile);
        } finally {
            BonScriptPreferences.currentPrefs.tsModule = previousModule;
            BonScriptPreferences.currentPrefs.tsModulesFile = previousModulesFile;
            BonScriptPreferences.currentPrefs.tsNpmPackage = previousNpmPackage;
            DataTypeExtension.clear();
        }
    }

    @Test
    public void standaloneRuntimeImportsResolveFromGeneratedPaths() throws Exception {
        String previousModule = BonScriptPreferences.currentPrefs.tsModule;
        String previousModulesFile = BonScriptPreferences.currentPrefs.tsModulesFile;
        String previousNpmPackage = BonScriptPreferences.currentPrefs.tsNpmPackage;
        try {
            BonScriptPreferences.currentPrefs.tsModule = null;
            BonScriptPreferences.currentPrefs.tsModulesFile = null;
            BonScriptPreferences.currentPrefs.tsNpmPackage = null;
            XtextResource resource = parse(BON_SOURCE);
            String expectedModelPath = TsModuleResolver.runtimeSupportImport(findClass(resource, "Base"),
                "Base", "bona-portable");
            Map<String, CharSequence> modelFiles = generate(BON_SOURCE);
            String model = modelFiles.values().stream().map(TypeScriptGeneratorTest::norm)
                .filter(content -> content.contains("export interface Base {")).findFirst().orElseThrow();
            assertTrue(model, model.contains("import type { BonaPortable } from \"" + expectedModelPath + "\";"));

            XtextResource apiResource = parse(API_SOURCE);
            ClassDefinition apiRequest = findClass(apiResource, "ProductSearchRequest");
            String expectedApiPortable = TsModuleResolver.runtimeSupportImport(apiRequest, "ProductApi", "bona-portable");
            String expectedApiClient = TsModuleResolver.runtimeSupportImport(apiRequest, "ProductApi", "rpc-client");
            String expectedApiUnwrap = TsModuleResolver.runtimeSupportImport(apiRequest, "ProductApi", "unwrap");
            String api = generateApis(API_SOURCE).values().stream().map(TypeScriptGeneratorTest::norm)
                .filter(content -> content.contains("export class ProductApi")).findFirst().orElseThrow();
            assertTrue(api, api.contains("from '" + expectedApiPortable + "';"));
            assertTrue(api, api.contains("from '" + expectedApiClient + "';"));
            assertTrue(api, api.contains("from '" + expectedApiUnwrap + "';"));
        } finally {
            BonScriptPreferences.currentPrefs.tsModule = previousModule;
            BonScriptPreferences.currentPrefs.tsModulesFile = previousModulesFile;
            BonScriptPreferences.currentPrefs.tsNpmPackage = previousNpmPackage;
            DataTypeExtension.clear();
        }
    }

    @Test
    public void rejectsAmbiguousSimpleNamesWithCanonicalIdentities() throws Exception {
        String source = String.join("\n",
            "package com.acme.one { class Shared {} }",
            "package com.acme.two { class Shared {} }",
            "package com.acme.use {",
            "    class Consumer {",
            "        required (com.acme.one.Shared) first;",
            "        required (com.acme.two.Shared) second;",
            "    }",
            "}",
            "");
        try {
            XtextResource resource = parse(source);
            ClassDefinition first = findClass(resource, "com.acme.one", "Shared");
            ClassDefinition second = findClass(resource, "com.acme.two", "Shared");
            TsImportCollector imports = new TsImportCollector();
            assertTrue(imports.add(first));
            assertEquals("com.acme.one.Shared", TsImportCollector.bonIdentity(imports.getTypes().iterator().next()));
            try {
                imports.add(second);
                throw new AssertionError("Expected an actionable TypeScript name collision");
            } catch (IllegalStateException e) {
                assertCanonicalCollision(e);
            }
        } catch (IllegalStateException e) {
            assertCanonicalCollision(e);
        }
    }

    @Test
    public void rejectsAmbiguousNamesInGeneratedModelsModuleIndexesAndApis() throws Exception {
        String modelSource = String.join("\n",
            "package com.acme.one { class Shared {} }",
            "package com.acme.two { class Shared {} }",
            "package com.acme.use {",
            "    class Consumer {",
            "        required (com.acme.one.Shared) first;",
            "        required (com.acme.two.Shared) second;",
            "    }",
            "}",
            "");
        try {
            generate(modelSource);
            throw new AssertionError("Expected model import collision");
        } catch (IllegalStateException e) {
            assertCanonicalCollision(e);
        }

        String indexSource = String.join("\n",
            "package apip { class Ref {} }",
            "package apiw { class Ref {} }",
            "");
        String index = norm(generate(indexSource).get(ROOT + "index.ts"));
        assertTrue(index, index.contains("export { RefPQON as ApipRefPQON } from './apip/Ref';"));
        assertTrue(index, index.contains("export type { Ref as ApipRef } from './apip/Ref';"));
        assertTrue(index, index.contains("export { RefPQON as ApiwRefPQON } from './apiw/Ref';"));
        assertTrue(index, index.contains("export type { Ref as ApiwRef } from './apiw/Ref';"));

        String apiSource = String.join("\n",
            "package com.acme.one { class Shared {} }",
            "package com.acme.two { class Shared {} }",
            "package com.acme.api {",
            "    class ServiceResponse {}",
            "    class SearchResponse<DATA, TRACKING> extends ServiceResponse {}",
            "    class ReadAllResponse<DATA, TRACKING> extends SearchResponse<!DATA, !TRACKING> {}",
            "    class SearchRequest<DATA, TRACKING> return ReadAllResponse<!DATA, !TRACKING> {}",
            "    class CollisionSearchRequest extends SearchRequest<com.acme.one.Shared, com.acme.two.Shared> {}",
            "}",
            "");
        try {
            generateApis(apiSource);
            throw new AssertionError("Expected API import collision");
        } catch (IllegalStateException e) {
            assertCanonicalCollision(e);
        } finally {
            DataTypeExtension.clear();
        }
    }

    private static void assertCanonicalCollision(IllegalStateException e) {
        assertTrue(e.getMessage(), e.getMessage().contains("com.acme.one.Shared"));
        assertTrue(e.getMessage(), e.getMessage().contains("com.acme.two.Shared"));
    }

    @Test
    public void abstractObjectFieldsUseConcreteDescendantUnion() throws Exception {
        Map<String, CharSequence> files = generate(POLYMORPHIC_SOURCE);
        String request = norm(files.get(ROOT + "com/acme/auth/AuthenticationRequest.ts"));

        assertTrue(request, request.contains("import type { PasswordAuthentication } from \"./PasswordAuthentication\";"));
        assertTrue(request, request.contains("import type { JwtAuthentication } from \"./JwtAuthentication\";"));
        assertTrue(request, request.contains("authenticationParameters: PasswordAuthentication | JwtAuthentication;"));
    }

    @Test
    public void fieldTypesAndOptionality() throws Exception {
        String child = norm(generate(BON_SOURCE).get(ROOT + "com/acme/auth/Child.ts"));
        assertField(child, "name: string;");                     // typedef resolved, required
        assertField(child, "nickname?: string | null;");         // optional scalar
        assertField(child, "active: boolean;");
        assertField(child, "age?: number | null;");
        assertField(child, "created?: number | null;");          // instants are epoch seconds
        assertField(child, "order: SortOrder;");
        assertField(child, "unit?: TimeUnit | null;");
        assertField(child, "tags: (string | null)[];");          // required list, elements may be null
        assertField(child, "labels?: Record<string, string>;");  // map
        assertField(child, "other?: Base | null;");
        assertField(child, "payload?: T | null;");               // generics parameter
        assertField(child, "extra?: Record<string, unknown> | null;");
        assertField(child, "modes: SortOrderSet;");
        assertField(child, "stringModes: StringSortOrderSet;");
        assertField(child, "defaultModes: DefaultSortOrderSet;");
        assertField(child, "units: TimeUnitSet;");
        assertField(child, "blob?: BonaPortable | null;");       // plain Object
        assertField(child, "oldAge?: number | null;");           // deprecated field still generated
    }

    @Test
    public void everyObjectHasPqonField() throws Exception {
        Map<String, CharSequence> files = generate(BON_SOURCE);
        for (String f : new String[] { "base/Base", "base/Legacy", "auth/Child" }) {
            String generated = norm(files.get(ROOT + "com/acme/" + f + ".ts"));
            assertTrue(f, generated.contains("'@PQON': typeof"));
            assertFalse(f, generated.toLowerCase().contains("rtti"));
        }
    }

    @Test
    public void javaOnlyClassAndPackageFlagsDoNotWeakenTypeScriptWireInterfaces() throws Exception {
        String source = String.join("\n",
            "package com.acme.flags XML FIELD swagger {",
            "    abstract class Base { required unicode(20) id; }",
            "    final class Leaf extends Base { required unicode(30) value; }",
            "    immutable class Frozen { required int count; }",
            "    class NoJavaHelper nojava { required boolean enabled; }",
            "}",
            "");
        Map<String, CharSequence> files = generate(source);
        String base = norm(files.get(ROOT + "com/acme/flags/Base.ts"));
        String leaf = norm(files.get(ROOT + "com/acme/flags/Leaf.ts"));
        String frozen = norm(files.get(ROOT + "com/acme/flags/Frozen.ts"));
        String helper = norm(files.get(ROOT + "com/acme/flags/NoJavaHelper.ts"));

        assertTrue(base, base.contains("export interface Base {"));
        assertTrue(leaf, leaf.contains("export interface Leaf extends Omit<Base, '@PQON'> {"));
        assertTrue(leaf, leaf.contains("value: string;"));
        assertTrue(frozen, frozen.contains("count: number;"));
        assertFalse(frozen, frozen.contains("readonly"));
        assertTrue(helper, helper.contains("export interface NoJavaHelper {"));
        assertTrue(helper, helper.contains("enabled: boolean;"));
        assertFalse(helper, helper.contains("XML") || helper.contains("swagger"));
    }

    @Test
    public void javaPackagePrefixDoesNotAffectTypeScriptPackagePathOrPqon() throws Exception {
        String source = "package (com.acme.generated) com.acme.base { class Prefixed {} }";
        Map<String, CharSequence> files = generate(source);
        String file = norm(files.get(ROOT + "com/acme/base/Prefixed.ts"));

        assertNotNull(file);
        assertTrue(file, file.contains("export const PrefixedPQON = \"com.acme.base.Prefixed\" as const;"));
        assertNull(files.get(ROOT + "com/acme/generated/com/acme/base/Prefixed.ts"));
    }

    @Test
    public void deprecatedTypesAndFieldsAreMarked() throws Exception {
        Map<String, CharSequence> files = generate(BON_SOURCE);
        String legacy = norm(files.get(ROOT + "com/acme/base/Legacy.ts"));
        assertTrue(legacy, legacy.contains("/** @deprecated */"));
        assertTrue(legacy, legacy.contains("export interface Legacy {"));
        String child = norm(files.get(ROOT + "com/acme/auth/Child.ts"));
        assertTrue(child, child.contains("/** @deprecated */"));
        assertTrue(child, child.contains("oldAge?: number | null;"));
    }

    private static void assertField(String content, String line) {
        assertTrue("expected line '" + line + "' in:\n" + content, content.lines().anyMatch(l -> l.trim().equals(line)));
    }

    @Test
    public void headerMarksFileAsGenerated() throws Exception {
        String content = norm(generate(BON_SOURCE).get(ROOT + "com/acme/auth/Child.ts"));
        assertEquals(TypeScriptBonScriptGeneratorMain.GENERATED_COMMENT, content.lines().findFirst().orElse(""));
    }

    @Test
    public void moduleMapResolvesNpmEntryPoint() {
        Properties modules = new Properties();
        modules.setProperty("t9t-base-api", "@arvato-systems-jacs/t9t-api,base");
        assertEquals("@arvato-systems-jacs/t9t-api/base",
            TsModuleResolver.importSpecifier("t9t-base-api", modules));
        assertEquals("base", TsModuleResolver.entryPoint("t9t-base-api", modules));
    }

    @Test
    public void crossModuleImportsUseMappedEntrypointsAndRejectMissingClosure() throws Exception {
        Path sourceJar = createModuleJar("fixture-source");
        Path targetJar = createModuleJar("fixture-target");
        Path modulesFile = Files.createTempFile("ts-cross-module", ".properties");
        Path externalModulesFile = Files.createTempFile("ts-external-modules", ".properties");
        String previousModule = BonScriptPreferences.currentPrefs.tsModule;
        String previousModulesFile = BonScriptPreferences.currentPrefs.tsModulesFile;
        String previousExternalModulesFile = BonScriptPreferences.currentPrefs.tsExternalModulesFile;
        try {
            XtextResourceSet resourceSet = injector.getInstance(XtextResourceSet.class);
            XtextResource source = load(resourceSet,
                "package com.acme.source { class Source { required (apiw.Ref) ref; } }",
                URI.createURI("jar:" + sourceJar.toUri() + "!/source.bon"));
            XtextResource target = load(resourceSet,
                "package apip { class Ref {} }\n"
                    + "package apiw { class Ref {} }\n"
                    + "package com.acme.target { class Target {} }",
                URI.createURI("jar:" + targetJar.toUri() + "!/target.bon"));
            ClassDefinition sourceType = findClass(source, "Source");
            ClassDefinition targetType = findClass(target, "Target");
            BonScriptPreferences.currentPrefs.tsModule = "fixture-source";
            BonScriptPreferences.currentPrefs.tsModulesFile = modulesFile.toString();
            BonScriptPreferences.currentPrefs.tsExternalModulesFile = externalModulesFile.toString();

            Files.writeString(externalModulesFile, "fixture-target=@fixture/bonaparte-api,bonaparte-core\n");
            BonScriptPreferences.currentPrefs.tsModulesFile = null;
            assertEquals("@fixture/bonaparte-api/bonaparte-core",
                TsModuleResolver.importPath(sourceType, "Source", targetType, "Target"));

            Files.writeString(externalModulesFile, "");
            BonScriptPreferences.currentPrefs.tsModulesFile = modulesFile.toString();
            Files.writeString(modulesFile, "fixture-target=@fixture/package,target\n");
            assertEquals("@fixture/package/target",
                TsModuleResolver.importPath(sourceType, "Source", targetType, "Target"));

            Files.writeString(modulesFile,
                "fixture-source=@fixture/package,source\nfixture-target=@fixture/package,target\n");
            InMemoryFileSystemAccess fsa = new InMemoryFileSystemAccess();
            injector.getInstance(TypeScriptBonScriptGeneratorMain.class)
                .doGenerate(source, fsa, new GeneratorContext());
            String generatedSource = norm(fsa.getTextFiles().get(
                ROOT + "source/com/acme/source/Source.ts"));
            assertTrue(generatedSource, generatedSource.contains(
                "import type { ApiwRef as Ref } from \"@fixture/package/target\";"));
            assertTrue(generatedSource, generatedSource.contains("ref: Ref;"));

            Files.writeString(modulesFile, "fixture-source=@fixture/package,source\n");
            try {
                TsModuleResolver.importPath(sourceType, "Source", targetType, "Target");
                throw new AssertionError("Expected missing dependency-closure mapping to fail");
            } catch (IllegalStateException e) {
                assertTrue(e.getMessage(), e.getMessage().contains("does not contain module fixture-target"));
            }
        } finally {
            BonScriptPreferences.currentPrefs.tsModule = previousModule;
            BonScriptPreferences.currentPrefs.tsModulesFile = previousModulesFile;
            BonScriptPreferences.currentPrefs.tsExternalModulesFile = previousExternalModulesFile;
            Files.deleteIfExists(sourceJar);
            Files.deleteIfExists(targetJar);
            Files.deleteIfExists(modulesFile);
            Files.deleteIfExists(externalModulesFile);
            DataTypeExtension.clear();
        }
    }

    @Test
    public void ownershipContextGeneratesCrossRepositoryImportsWithoutModuleMaps() throws Exception {
        Path sourceJar = createModuleJar("commerce-api");
        Path targetJar = createModuleJar("bonaparte-api-auth");
        try {
            XtextResourceSet resources = injector.getInstance(XtextResourceSet.class);
            URI sourceRoot = URI.createURI("jar:" + sourceJar.toUri() + "!/");
            URI targetRoot = URI.createURI("archive:" + targetJar.toUri() + "!/");
            var sourceOwner = new TsGenerationContext.Owner("com.arvato-systems.t9t", "commerce-api",
                "10.0-SNAPSHOT", "@arvato-systems-jacs/a28");
            var targetOwner = new TsGenerationContext.Owner("de.jpaw", "bonaparte-api-auth",
                "7.3.3-SNAPSHOT", "@arvato-systems-jacs/bonaparte");
            TsGenerationContext.attach(resources, new TsGenerationContext(sourceOwner, List.of(
                new TsGenerationContext.Location(sourceRoot, sourceOwner),
                new TsGenerationContext.Location(targetRoot, targetOwner))));
            XtextResource source = load(resources,
                "package commerce { class Product { required (api.auth.JwtInfo) jwt; } }",
                sourceRoot.appendSegment("commerce.bon"));
            XtextResource target = load(resources, "package api.auth { class JwtInfo {} }",
                targetRoot.appendSegment("auth.bon"));
            assertEquals("@arvato-systems-jacs/bonaparte/bonaparte-api-auth",
                TsModuleResolver.importPath(findClass(source, "Product"), "Product", findClass(target, "JwtInfo"), "JwtInfo"));
            assertTrue(TsModuleResolver.isCurrentModule(source));
            assertFalse(TsModuleResolver.isCurrentModule(target));
            var javaResource = new org.eclipse.emf.ecore.resource.impl.ResourceImpl(
                URI.createURI("java:/Objects/java.lang.Class"));
            resources.getResources().add(javaResource);
            assertFalse(TsModuleResolver.isCurrentModule(javaResource));
            assertFalse(TsModuleResolver.isSameModule(source, javaResource));
            InMemoryFileSystemAccess fsa = new InMemoryFileSystemAccess();
            injector.getInstance(TypeScriptBonScriptGeneratorMain.class)
                .doGenerate(source, fsa, new GeneratorContext());
            String output = norm(fsa.getTextFiles().get(ROOT + "commerce-api/commerce/Product.ts"));
            assertTrue(output, output.contains("import type { JwtInfo } from \"@arvato-systems-jacs/bonaparte/bonaparte-api-auth\";"));
            assertNull(fsa.getTextFiles().get(ROOT + "bonaparte-api-auth/api/auth/JwtInfo.ts"));
            try {
                TsGenerationContext.from(source).owner(URI.createURI("file:/outside/dependency.bon"));
                throw new AssertionError("Missing dependency owner must fail");
            } catch (IllegalStateException expected) {
                assertTrue(expected.getMessage(), expected.getMessage().contains("dependency closure"));
            }
        } finally {
            Files.deleteIfExists(sourceJar);
            Files.deleteIfExists(targetJar);
            DataTypeExtension.clear();
        }
    }

    @Test
    public void mavenSetupAttachesOwnershipContextAndRestoresScope() throws Exception {
        var owner = new TsGenerationContext.Owner("fixture", "fixture-api", "1.0", "@fixture/package");
        var context = new TsGenerationContext(owner,
            List.of(new TsGenerationContext.Location(URI.createURI("dummy:/"), owner)));
        TsGenerationContext previous = TsGenerationContext.active();
        try (var scope = TsGenerationContext.activate(context)) {
            XtextResourceSet resources = new BonScriptMavenSetup().createInjectorAndDoEMFRegistration()
                .getInstance(XtextResourceSet.class);
            XtextResource source = load(resources, "package fixture { class Source {} }", URI.createURI("dummy:/source.bon"));
            assertEquals(context, TsGenerationContext.from(source));
            assertEquals("ts/fixture-api/", TsModuleResolver.outputFolder(source));
            assertTrue(TsModuleResolver.isCurrentModule(source));
        }
        assertEquals(previous, TsGenerationContext.active());
    }

    @Test
    public void mavenGeneratorAttachesContextToBuilderCreatedResourceSet() throws Exception {
        var owner = new TsGenerationContext.Owner("fixture", "fixture-api", "1.0", "@fixture/package");
        var context = new TsGenerationContext(owner,
            List.of(new TsGenerationContext.Location(URI.createURI("dummy:/"), owner)));
        Injector mavenInjector;
        try (var scope = TsGenerationContext.activate(context)) {
            mavenInjector = new BonScriptMavenSetup().createInjectorAndDoEMFRegistration();
        }
        XtextResourceSet builderResources = injector.getInstance(XtextResourceSet.class);
        XtextResource source = load(builderResources, "package fixture { class Source {} }", URI.createURI("dummy:/source.bon"));
        assertNull(TsGenerationContext.from(source));
        boolean previousJava = BonScriptPreferences.currentPrefs.doJava;
        boolean previousXsd = BonScriptPreferences.currentPrefs.doXsd;
        boolean previousTypeScript = BonScriptPreferences.currentPrefs.doTypeScript;
        try {
            BonScriptPreferences.currentPrefs.doJava = false;
            BonScriptPreferences.currentPrefs.doXsd = false;
            BonScriptPreferences.currentPrefs.doTypeScript = true;
            InMemoryFileSystemAccess fsa = new InMemoryFileSystemAccess();
            mavenInjector.getInstance(BonScriptGenerator.class).doGenerate(source, fsa, new GeneratorContext());
            assertEquals(context, TsGenerationContext.from(source));
            assertNotNull(fsa.getTextFiles().get(ROOT + "fixture-api/fixture/Source.ts"));
        } finally {
            BonScriptPreferences.currentPrefs.doJava = previousJava;
            BonScriptPreferences.currentPrefs.doXsd = previousXsd;
            BonScriptPreferences.currentPrefs.doTypeScript = previousTypeScript;
            DataTypeExtension.clear();
        }
    }

    @Test
    public void ownershipContextRejectsAmbiguousRootsAndPreservesFullCoordinates() {
        var first = new TsGenerationContext.Owner("first.group", "shared-api", "1.0", "@fixture/first");
        var second = new TsGenerationContext.Owner("second.group", "shared-api", "1.0", "@fixture/second");
        assertFalse(first.equals(second));
        URI root = URI.createURI("file:/fixture/");
        var context = new TsGenerationContext(first, List.of(new TsGenerationContext.Location(root, first),
            new TsGenerationContext.Location(root, second)));
        try {
            context.owner(root.appendSegment("input.bon"));
            throw new AssertionError("Ambiguous owners must fail even when artifactIds match");
        } catch (IllegalStateException expected) {
            assertTrue(expected.getMessage(), expected.getMessage().contains("Ambiguous"));
        }
    }

    @Test
    public void ownershipContextGeneratesApiIndexWithoutLegacySettings() throws Exception {
        var owner = new TsGenerationContext.Owner("fixture", "fixture-api", "1.0", "@fixture/package");
        var runtimeOwner = new TsGenerationContext.Owner("com.arvato-systems.t9t", "t9t-base-api", "1.0", "@fixture/t9t");
        XtextResourceSet resources = injector.getInstance(XtextResourceSet.class);
        TsGenerationContext.attach(resources, new TsGenerationContext(owner,
            List.of(new TsGenerationContext.Location(URI.createURI("dummy:/"), owner),
                new TsGenerationContext.Location(URI.createURI("dummy:/runtime/"), runtimeOwner))));
        XtextResource source = load(resources, API_SOURCE, URI.createURI("dummy:/api.bon"));
        String previousModule = System.getProperty("bonaparte.TypeScript.module");
        String previousMap = System.getProperty("bonaparte.TypeScript.modulesFile");
        try {
            System.setProperty("bonaparte.TypeScript.module", "wrong-module");
            System.setProperty("bonaparte.TypeScript.modulesFile", "nonexistent-module-map.properties");
            InMemoryFileSystemAccess fsa = new InMemoryFileSystemAccess();
            injector.getInstance(TsApiClientGenerator.class).doGenerate(source, fsa);
            String index = norm(fsa.getTextFiles().get(ROOT + "fixture-api/api-index.ts"));
            assertTrue(index, index.contains("export { ProductApi }"));
            String api = norm(fsa.getTextFiles().get(ROOT + "fixture-api/com/acme/api/ProductApi.ts"));
            assertTrue(api, api.contains("import { RpcClient } from '@fixture/t9t';"));
            assertTrue(api, api.contains("} from '@fixture/t9t';"));
            assertFalse(api, api.contains("import { RpcClient } from '@fixture/package';"));
            assertNull(fsa.getTextFiles().get(ROOT + "wrong-module/api-index.ts"));
        } finally {
            restoreSystemProperty("bonaparte.TypeScript.module", previousModule);
            restoreSystemProperty("bonaparte.TypeScript.modulesFile", previousMap);
            DataTypeExtension.clear();
        }
    }

    @Test
    public void bonScriptTypeScriptSettingsReadSystemPropertiesDynamically() {
        String previousTypeScript = System.getProperty("bonaparte.TypeScript");
        String previousModule = System.getProperty("bonaparte.TypeScript.module");
        String previousModulesFile = System.getProperty("bonaparte.TypeScript.modulesFile");
        String previousNpmPackage = System.getProperty("bonaparte.TypeScript.npmPackage");
        try {
            System.setProperty("bonaparte.TypeScript", "true");
            System.setProperty("bonaparte.TypeScript.module", "fixture-api");
            System.setProperty("bonaparte.TypeScript.modulesFile", "fixture-modules.properties");
            System.setProperty("bonaparte.TypeScript.npmPackage", "@arvato-systems-jacs/t9t-api");
            assertTrue(BonScriptPreferences.getDoTypeScript());
            assertEquals("fixture-api", BonScriptPreferences.getTsModule());
            assertEquals("fixture-modules.properties", BonScriptPreferences.getTsModulesFile());
            assertEquals("@arvato-systems-jacs/t9t-api", BonScriptPreferences.getTsNpmPackage());
        } finally {
            restoreSystemProperty("bonaparte.TypeScript", previousTypeScript);
            restoreSystemProperty("bonaparte.TypeScript.module", previousModule);
            restoreSystemProperty("bonaparte.TypeScript.modulesFile", previousModulesFile);
            restoreSystemProperty("bonaparte.TypeScript.npmPackage", previousNpmPackage);
        }
    }

    @Test
    public void configuredNpmPackageProvidesDefaultSecondaryEntrypoint() {
        String previousModule = System.getProperty("bonaparte.TypeScript.module");
        String previousModulesFile = System.getProperty("bonaparte.TypeScript.modulesFile");
        String previousNpmPackage = System.getProperty("bonaparte.TypeScript.npmPackage");
        try {
            System.setProperty("bonaparte.TypeScript.module", "t9t-base-api");
            System.clearProperty("bonaparte.TypeScript.modulesFile");
            System.setProperty("bonaparte.TypeScript.npmPackage", "@arvato-systems-jacs/t9t-api");
            assertEquals("t9t-base-api", TsModuleResolver.currentEntryPoint());
        } finally {
            restoreSystemProperty("bonaparte.TypeScript.module", previousModule);
            restoreSystemProperty("bonaparte.TypeScript.modulesFile", previousModulesFile);
            restoreSystemProperty("bonaparte.TypeScript.npmPackage", previousNpmPackage);
        }
    }

    private static void restoreSystemProperty(String key, String value) {
        if (value == null)
            System.clearProperty(key);
        else
            System.setProperty(key, value);
    }

    @Test
    public void generatesNgPackagrSecondaryEntryPoint() throws Exception {
        Path modulesFile = Files.createTempFile("ts-modules", ".properties");
        Files.writeString(modulesFile, "fixture-api=@arvato-systems-jacs/t9t-api,auth\n");
        String previousModule = BonScriptPreferences.currentPrefs.tsModule;
        String previousModulesFile = BonScriptPreferences.currentPrefs.tsModulesFile;
        BonScriptPreferences.currentPrefs.tsModule = "fixture-api";
        BonScriptPreferences.currentPrefs.tsModulesFile = modulesFile.toString();
        try {
            XtextResource resource = parse(BON_SOURCE);
            InMemoryFileSystemAccess fsa = new InMemoryFileSystemAccess();
            injector.getInstance(TypeScriptBonScriptGeneratorMain.class)
                .doGenerate(resource, fsa, new GeneratorContext());

            Map<String, CharSequence> files = fsa.getTextFiles();
            String entryRoot = ROOT + "auth/";
            assertTrue(norm(files.get(entryRoot + "package.json")).contains("\"entryFile\": \"index.ts\""));
            assertTrue(norm(files.get(entryRoot + "ng-package.json")).contains("\"entryFile\": \"index.ts\""));
            String index = norm(files.get(entryRoot + "index.ts"));
            assertFalse(index, index.contains("export type { BonaPortable }"));
            assertNull(files.get(entryRoot + "bona-portable.ts"));
            String child = norm(files.get(entryRoot + "com/acme/auth/Child.ts"));
            assertTrue(child, child.contains("import type { BonaPortable } from \"@arvato-systems-jacs/bonaparte/bonaparte-core\";"));
            assertTrue(index, index.contains("export { ChildPQON }"));
            assertTrue(index, index.contains("export type { Child }"));
            assertTrue(index, index.contains("export type { SortOrderSet }"));
            assertTrue(index, index.contains("export type { StringSortOrderSet }"));
            assertTrue(index, index.contains("export type { TimeUnitSet }"));
            String numericSet = norm(files.get(entryRoot + "com/acme/base/SortOrderSet.ts"));
            assertTrue(numericSet, numericSet.contains("= number & { readonly [SortOrderSetBrand]"));
            String defaultNumericSet = norm(files.get(entryRoot + "com/acme/base/DefaultSortOrderSet.ts"));
            assertTrue(defaultNumericSet, defaultNumericSet.contains("= number & { readonly [DefaultSortOrderSetBrand]"));
            String xenumSet = norm(files.get(entryRoot + "com/acme/base/TimeUnitSet.ts"));
            assertTrue(xenumSet, xenumSet.contains("= string & { readonly [TimeUnitSetBrand]"));
            assertTrue(xenumSet, xenumSet.contains("xenum: \"com.acme.base.TimeUnit\""));
            String stringSet = norm(files.get(entryRoot + "com/acme/base/StringSortOrderSet.ts"));
            assertTrue(stringSet, stringSet.contains("= string & { readonly [StringSortOrderSetBrand]"));

            InMemoryFileSystemAccess apiFsa = new InMemoryFileSystemAccess();
            injector.getInstance(TsApiClientGenerator.class).doGenerate(parse(API_SOURCE), apiFsa);
            String apiIndex = norm(apiFsa.getTextFiles().get(entryRoot + "api-index.ts"));
            assertTrue(apiIndex, apiIndex.contains("export { ProductApi }"));
        } finally {
            BonScriptPreferences.currentPrefs.tsModule = previousModule;
            BonScriptPreferences.currentPrefs.tsModulesFile = previousModulesFile;
            Files.deleteIfExists(modulesFile);
            DataTypeExtension.clear();
        }
    }

    @Test
    public void apiServicesUseCorePortableTypeAndPrimaryRpcRuntime() throws Exception {
        String previousModule = BonScriptPreferences.currentPrefs.tsModule;
        String previousModulesFile = BonScriptPreferences.currentPrefs.tsModulesFile;
        String previousNpmPackage = BonScriptPreferences.currentPrefs.tsNpmPackage;
        BonScriptPreferences.currentPrefs.tsModule = "fixture-api";
        BonScriptPreferences.currentPrefs.tsModulesFile = null;
        BonScriptPreferences.currentPrefs.tsNpmPackage = "@fixture/t9t-api";
        try {
            InMemoryFileSystemAccess fsa = new InMemoryFileSystemAccess();
            injector.getInstance(TsApiClientGenerator.class).doGenerate(parse(API_SOURCE), fsa);
            String api = fsa.getTextFiles().values().stream()
                .map(TypeScriptGeneratorTest::norm)
                .filter(content -> content.contains("export class ProductApi"))
                .findFirst().orElseThrow();
            assertTrue(api, api.contains("import type { BonaPortable } from '@arvato-systems-jacs/bonaparte/bonaparte-core';"));
            assertTrue(api, api.contains("import { RpcClient } from '@fixture/t9t-api';"));
            assertTrue(api, api.contains("} from '@fixture/t9t-api';"));
        } finally {
            BonScriptPreferences.currentPrefs.tsModule = previousModule;
            BonScriptPreferences.currentPrefs.tsModulesFile = previousModulesFile;
            BonScriptPreferences.currentPrefs.tsNpmPackage = previousNpmPackage;
            DataTypeExtension.clear();
        }
    }

    @Test
    public void onlyCoreGeneratesAndExportsPortableSupport() throws Exception {
        String previousModule = BonScriptPreferences.currentPrefs.tsModule;
        String previousModulesFile = BonScriptPreferences.currentPrefs.tsModulesFile;
        String previousNpmPackage = BonScriptPreferences.currentPrefs.tsNpmPackage;
        try {
            BonScriptPreferences.currentPrefs.tsModule = "bonaparte-core";
            BonScriptPreferences.currentPrefs.tsModulesFile = null;
            BonScriptPreferences.currentPrefs.tsNpmPackage = "@arvato-systems-jacs/bonaparte";
            Map<String, CharSequence> coreFiles = generate(BON_SOURCE);
            String coreRoot = ROOT + "bonaparte-core/";
            assertTrue(norm(coreFiles.get(coreRoot + "bona-portable.ts")).contains("export interface BonaPortable"));
            assertTrue(norm(coreFiles.get(coreRoot + "index.ts")).contains("export type { BonaPortable } from './bona-portable';"));
            assertRelativeImportResolves(coreFiles, coreRoot + "com/acme/base/Base.ts", "../../../bona-portable",
                coreRoot + "bona-portable.ts");

            BonScriptPreferences.currentPrefs.tsModule = "bonaparte-api-auth";
            Map<String, CharSequence> authFiles = generate(BON_SOURCE);
            String authRoot = ROOT + "bonaparte-api-auth/";
            assertNull(authFiles.get(authRoot + "bona-portable.ts"));
            assertFalse(norm(authFiles.get(authRoot + "index.ts")).contains("export type { BonaPortable }"));
            assertTrue(norm(authFiles.get(authRoot + "com/acme/base/Base.ts")).contains(
                "import type { BonaPortable } from \"@arvato-systems-jacs/bonaparte/bonaparte-core\";"));
        } finally {
            BonScriptPreferences.currentPrefs.tsModule = previousModule;
            BonScriptPreferences.currentPrefs.tsModulesFile = previousModulesFile;
            BonScriptPreferences.currentPrefs.tsNpmPackage = previousNpmPackage;
            DataTypeExtension.clear();
        }
    }

    @Test
    public void typeGuardMatchesTheLiteralPqon() {
        assertEquals("export function isChild(value: unknown): value is Child {\n"
                + "    return typeof value === \"object\" && value !== null && (value as Record<string, unknown>)[\"@PQON\"] === \"com.acme.auth.Child\";\n"
                + "}\n", TsModuleResolver.typeGuard("Child", "com.acme.auth.Child"));
    }

    @Test
    public void classifiesDirectAndInheritedSearchRequests() throws Exception {
        XtextResource resource = parse(CLASSIFIER_SOURCE);
        TsRequestClassifier.RequestInfo direct = TsRequestClassifier.classify(
                findClass(resource, "DirectSearchRequest"));
        assertEquals(TsRequestClassifier.Pattern.SEARCH, direct.pattern);
        assertEquals("ProductDTO", direct.dtoName);
        assertEquals("Audit", direct.trackingName);
        assertEquals(TsRequestClassifier.ResponsePattern.SEARCH, direct.responsePattern);

        TsRequestClassifier.RequestInfo inherited = TsRequestClassifier.classify(
                findClass(resource, "InheritedSearchRequest"));
        assertEquals(TsRequestClassifier.Pattern.SEARCH, inherited.pattern);
        assertEquals("ProductDTO", inherited.dtoName);
        assertEquals("Audit", inherited.trackingName);
    }

    @Test
    public void skipsAbstractRequestClasses() throws Exception {
        XtextResource resource = parse(CLASSIFIER_SOURCE);
        assertNull(TsRequestClassifier.classify(findClass(resource, "AbstractRequest")));
    }

    @Test
    public void classifiesOtherRequestFamilies() throws Exception {
        XtextResource resource = parse(CLASSIFIER_SOURCE);
        assertEquals(TsRequestClassifier.Pattern.LEAN_SEARCH,
                TsRequestClassifier.classify(findClass(resource, "DirectLeanSearchRequest")).pattern);
        assertEquals(TsRequestClassifier.Pattern.RESOLVE_MANY,
                TsRequestClassifier.classify(findClass(resource, "DirectMassResolverRequest")).pattern);
        assertEquals(TsRequestClassifier.Pattern.RESOLVE,
            TsRequestClassifier.classify(findClass(resource, "DirectResolverRequest")).pattern);
        assertEquals(TsRequestClassifier.Pattern.SPECIAL,
                TsRequestClassifier.classify(findClass(resource, "SpecialRequest")).pattern);
    }

    @Test
    public void resolvesNearestInheritedResponseDeclaration() throws Exception {
        XtextResource resource = parse(CLASSIFIER_SOURCE);
        TsRequestClassifier.RequestInfo inherited = TsRequestClassifier.classify(
                findClass(resource, "InheritedReturnedSearch"));
        assertEquals("SearchResponseWithTypes", inherited.responseRef.getClassRef().getName());

        TsRequestClassifier.RequestInfo overridden = TsRequestClassifier.classify(
                findClass(resource, "OverrideReturnedSearch"));
        assertEquals("CustomSearchResponse", overridden.responseRef.getClassRef().getName());
        assertEquals(TsRequestClassifier.Pattern.SPECIAL, overridden.pattern);

        TsRequestClassifier.RequestInfo generic = TsRequestClassifier.classify(
            findClass(resource, "GenericReturnedSearch"));
        assertEquals("ProductDTO", generic.responseRef.getClassRefGenericParms().get(0).getClassRef().getName());
        assertEquals("Audit", generic.responseRef.getClassRefGenericParms().get(1).getClassRef().getName());
    }

    @Test
    public void derivesApiAndVariantMethodNames() {
        assertEquals("ProductApi", TsNaming.apiClassName("com.acme.request", "ProductDTO"));
        assertEquals("A28cartApi", TsNaming.apiClassName("t9t.a28cart.request", null));
        assertEquals("createViaApi", TsNaming.methodName("ProductCrudViaApiRequest",
                TsRequestClassifier.Pattern.CRUD_SURROGATE, "ProductDTO"));
        assertEquals("searchAndEnrichment", TsNaming.methodName("LoyaltyCardSearchAndEnrichmentRequest",
                TsRequestClassifier.Pattern.SEARCH, "LoyaltyCardDTO"));
        assertEquals("searchExtended", TsNaming.methodName("SalesOrderExtendedSearchRequest",
            TsRequestClassifier.Pattern.SEARCH, "SalesOrderDTO"));
        assertEquals("reserveCoupon", TsNaming.methodName("ReserveCouponRequest",
                TsRequestClassifier.Pattern.SPECIAL, null));
        assertEquals("PriceListApi", TsNaming.apiClassName("t9t.pricing.request", null,
            "PriceListLeanSearchRequest", TsRequestClassifier.Pattern.LEAN_SEARCH));
        assertEquals("leanSearch", TsNaming.methodName("PriceListLeanSearchRequest",
            TsRequestClassifier.Pattern.LEAN_SEARCH, null));
    }

    @Test
    public void generatesApisForA28RequestExamples() throws Exception {
        String source = String.join("\n",
            "package t9t.a28coupon.request {",
            "    class ServiceResponse {}",
            "    class SearchCriteria { required int limit; required int offset; }",
            "    class SearchResponse<DATA, TRACKING> extends ServiceResponse {}",
            "    class ReadAllResponse<DATA, TRACKING> extends SearchResponse<!DATA, !TRACKING> {}",
            "    class SearchRequest<DATA, TRACKING> extends SearchCriteria return ReadAllResponse<!DATA, !TRACKING> {}",
            "    class LeanSearchResponse extends ServiceResponse {}",
            "    class Description {}",
            "    class LeanSearchRequest extends SearchCriteria return LeanSearchResponse {}",
            "    class RefResolverResponse extends ServiceResponse {}",
            "    class RefResolverRequest<REF> return RefResolverResponse {}",
            "    class CrudAnyKeyResponse<DATA, TRACKING> extends ServiceResponse {}",
            "    class CrudSurrogateResponse<DATA, TRACKING> extends CrudAnyKeyResponse<DATA, TRACKING> {}",
            "    class CrudSurrogateKeyRequest<REF, DATA, TRACKING> return CrudSurrogateResponse<!DATA, !TRACKING> {}",
            "    class RequestParameters return ServiceResponse {}",
            "    abstract class AbstractCouponRequest extends RequestParameters { required unicode(20) couponId; }",
            "    class ReserveCouponRequest extends AbstractCouponRequest {}",
            "    class SalesOrderDTO {}",
            "    class FullTracking {}",
            "    class SalesOrderSearchRequest extends SearchRequest<SalesOrderDTO, FullTracking> {}",
            "    class SalesOrderExtendedSearchRequest extends SalesOrderSearchRequest return ReadAllResponse<SalesOrderDTO, FullTracking> { optional unicode(20) customerId; }",
            "    class LoyaltyCardDTO {}",
            "    class LoyaltyCardSearchRequest extends SearchRequest<LoyaltyCardDTO, FullTracking> {}",
            "    class LoyaltyCardSearchAndEnrichmentResponse extends ReadAllResponse<LoyaltyCardDTO, FullTracking> {}",
            "    class LoyaltyCardSearchAndEnrichmentRequest extends SearchRequest<LoyaltyCardDTO, FullTracking> return LoyaltyCardSearchAndEnrichmentResponse {}",
            "    class ProductDTO {}",
            "    class ProductRef {}",
            "    class ProductCrudRequest extends CrudSurrogateKeyRequest<ProductRef, ProductDTO, FullTracking> {}",
            "    class ProductCrudViaApiRequest extends CrudSurrogateKeyRequest<ProductRef, ProductDTO, FullTracking> {}",
            "    class ProductResolverRequest extends RefResolverRequest<ProductRef> {}",
            "    class StockDTO {}",
            "    class SearchFilter {}",
            "    class StockSearchRequest extends SearchRequest<StockDTO, FullTracking> { optional (SearchFilter...) skuFilter; }",
            "    class PriceListLeanSearchRequest extends LeanSearchRequest {}",
            "}",
            "");
        Map<String, CharSequence> files = generateApis(source);

        String couponApi = norm(files.get(ROOT + "t9t/a28coupon/request/A28couponApi.ts"));
        assertTrue(couponApi, couponApi.contains("reserveCoupon(params: Omit<ReserveCouponRequest, '@PQON'>): Observable<void>"));
        assertTrue(couponApi, couponApi.contains("map(unwrapVoid)"));

        String salesOrderApi = norm(files.get(ROOT + "t9t/a28coupon/request/SalesOrderApi.ts"));
        assertTrue(salesOrderApi, salesOrderApi.contains("export interface SalesOrderExtendedSearchRequestExtras extends Pick<SalesOrderExtendedSearchRequest, 'customerId'> {}"));
        assertTrue(salesOrderApi, salesOrderApi.contains("searchExtended(params: Omit<SalesOrderExtendedSearchRequest, '@PQON' | 'offset' | 'customerId'> & { offset?: number } & SalesOrderExtendedSearchRequestExtras): Observable<SalesOrderDTO[]>"));
        assertTrue(salesOrderApi, salesOrderApi.contains("map(unwrapSearch<SalesOrderDTO>)"));

        String loyaltyCardApi = norm(files.get(ROOT + "t9t/a28coupon/request/LoyaltyCardApi.ts"));
        assertTrue(loyaltyCardApi, loyaltyCardApi.contains("searchAndEnrichment(params: Omit<LoyaltyCardSearchAndEnrichmentRequest, '@PQON' | 'offset'> & { offset?: number }): Observable<LoyaltyCardDTO[]>"));
        assertTrue(loyaltyCardApi, loyaltyCardApi.contains("map(unwrapSearch<LoyaltyCardDTO>)"));

        String productApi = norm(files.get(ROOT + "t9t/a28coupon/request/ProductApi.ts"));
        assertTrue(productApi, productApi.contains("executeViaApi(params: Omit<ProductCrudViaApiRequest, '@PQON'>): Observable<ProductDTO>"));
        assertTrue(productApi, productApi.contains("createViaApi(data: ProductDTO,"));
        assertTrue(productApi, productApi.contains("resolve(params: Omit<ProductResolverRequest, '@PQON'>): Observable<number>"));
        assertTrue(productApi, productApi.contains("map(unwrapResolve)"));

        String stockApi = norm(files.get(ROOT + "t9t/a28coupon/request/StockApi.ts"));
        assertTrue(stockApi, stockApi.contains("export interface StockSearchRequestExtras extends Pick<StockSearchRequest, 'skuFilter'> {}"));
        assertTrue(stockApi, stockApi.contains("search(params: Omit<StockSearchRequest, '@PQON' | 'offset' | 'skuFilter'> & { offset?: number } & StockSearchRequestExtras)"));

        String priceListApi = norm(files.get(ROOT + "t9t/a28coupon/request/PriceListApi.ts"));
        assertTrue(priceListApi, priceListApi.contains("leanSearch(params: Omit<PriceListLeanSearchRequest, '@PQON' | 'offset'> & { offset?: number }): Observable<Description[]>"));
        assertTrue(priceListApi, priceListApi.contains("map(unwrapLean)"));
    }

    @Test
    public void apiParametersPreserveInheritedRequiredFieldsThroughGenericParents() throws Exception {
        String source = String.join("\n",
            "package com.acme.api {",
            "    class ServiceResponse {}",
            "    class SearchResponse<DATA, TRACKING> extends ServiceResponse {}",
            "    class SearchCriteria { required int offset; }",
            "    class PayloadBase<T> extends SearchCriteria { required (!T) payload; required unicode(20) tenant; }",
            "    class SearchRequest<DATA, TRACKING> extends PayloadBase<!DATA> return SearchResponse<!DATA, !TRACKING> {}",
            "    class ProductDTO {}",
            "    class Audit {}",
            "    class ProductSearchRequest extends SearchRequest<ProductDTO, Audit> {}",
            "}",
            "");
        Map<String, CharSequence> modelFiles = generate(source);
        String payloadBase = norm(modelFiles.get(ROOT + "com/acme/api/PayloadBase.ts"));
        String searchRequest = norm(modelFiles.get(ROOT + "com/acme/api/SearchRequest.ts"));
        String productRequest = norm(modelFiles.get(ROOT + "com/acme/api/ProductSearchRequest.ts"));
        String api = norm(generateApis(source).get(ROOT + "com/acme/api/ProductApi.ts"));

        assertTrue(payloadBase, payloadBase.contains("export interface PayloadBase<T = unknown> extends Omit<SearchCriteria, '@PQON'> {"));
        assertTrue(payloadBase, payloadBase.contains("payload: T;"));
        assertTrue(payloadBase, payloadBase.contains("tenant: string;"));
        assertTrue(searchRequest, searchRequest.contains("extends Omit<PayloadBase<DATA>, '@PQON'>"));
        assertTrue(productRequest, productRequest.contains("extends Omit<SearchRequest<ProductDTO, Audit>, '@PQON'>"));
        assertTrue(api, api.contains("search(params: Omit<ProductSearchRequest, '@PQON' | 'offset'> & { offset?: number }): Observable<ProductDTO[]>"));
    }

    @Test
    public void apiNamingDoesNotRequireOrReadAnOverrideFile() throws Exception {
        String previousNamingFile = System.getProperty("bonaparte.TypeScript.apiNamingFile");
        try {
            System.setProperty("bonaparte.TypeScript.apiNamingFile", "nonexistent-api-naming.properties");
            Map<String, CharSequence> files = generateApis(API_SOURCE);
            String api = norm(files.get(ROOT + "com/acme/api/ProductApi.ts"));
            assertTrue(api, api.contains("export class ProductApi {"));
            assertTrue(api, api.contains("search(params: Omit<ProductSearchRequest, '@PQON' | 'offset' | 'customScope'>"));
        } finally {
            restoreSystemProperty("bonaparte.TypeScript.apiNamingFile", previousNamingFile);
        }
    }

    @Test
    public void concreteSearchResponseImportsTheResolvedResultDto() throws Exception {
        String source = String.join("\n",
            "package com.acme.api {",
            "    class ServiceResponse {}",
            "    class SearchResponse<DATA, TRACKING> extends ServiceResponse {}",
            "    class ReadAllResponse<DATA, TRACKING> extends SearchResponse<!DATA, !TRACKING> {}",
            "    class SearchRequest<DATA, TRACKING> return ReadAllResponse<!DATA, !TRACKING> {}",
            "    class ConcreteDTO {}",
            "    class Audit {}",
            "    class ConcreteResponse extends ReadAllResponse<ConcreteDTO, Audit> {}",
            "    class ConcreteSearchAndEnrichRequest extends SearchRequest<ConcreteDTO, Audit> return ConcreteResponse {}",
            "}", "");
        String api = norm(generateApis(source).get(ROOT + "com/acme/api/ConcreteApi.ts"));
        assertTrue(api, api.contains("import type { ConcreteDTO } from \"./ConcreteDTO\";"));
        assertTrue(api, api.contains("Observable<ConcreteDTO[]>"));
        assertTrue(api, api.contains("map(unwrapSearch<ConcreteDTO>)"));
    }

    @Test
    public void searchResultUsesOverriddenResponsePayloadInsteadOfRequestDto() throws Exception {
        String source = String.join("\n",
            "package com.acme.api {",
            "    class ServiceResponse {}",
            "    class SearchResponse<DATA, TRACKING> extends ServiceResponse {}",
            "    class ReadAllResponse<DATA, TRACKING> extends SearchResponse<!DATA, !TRACKING> {}",
            "    class SearchRequest<DATA, TRACKING> return ReadAllResponse<!DATA, !TRACKING> {}",
            "    class DeliveryOrderDTO {}",
            "    class EnrichedDeliveryDTO {}",
            "    class Audit {}",
            "    class EnrichedResponse extends ReadAllResponse<EnrichedDeliveryDTO, Audit> {}",
            "    class DeliveryOrderSearchWithParcelsRequest extends SearchRequest<DeliveryOrderDTO, Audit> return EnrichedResponse {}",
            "}", "");
        String api = norm(generateApis(source).get(ROOT + "com/acme/api/DeliveryOrderApi.ts"));
        assertTrue(api, api.contains("import type { EnrichedDeliveryDTO } from \"./EnrichedDeliveryDTO\";"));
        assertTrue(api, api.contains("Observable<EnrichedDeliveryDTO[]>"));
        assertTrue(api, api.contains("map(unwrapSearch<EnrichedDeliveryDTO>)"));
        assertFalse(api, api.contains("Observable<DeliveryOrderDTO[]>"));
    }

    @Test
    public void plainDtoResponseDoesNotUseServiceResponseUnwrapping() throws Exception {
        String source = String.join("\n",
            "package com.acme.request {",
            "    class RequestParameters {}",
            "    class CustomerStatusResponse { required boolean changed; }",
            "    class CustomerStatusRequest extends RequestParameters return CustomerStatusResponse {}",
            "}", "");
        String api = norm(generateApis(source).get(ROOT + "com/acme/request/AcmeApi.ts"));
        assertTrue(api, api.contains("Observable<CustomerStatusResponse>"));
        assertTrue(api, api.contains("return this.rpc.call<CustomerStatusResponse>(CustomerStatusRequestPQON, params);"));
        assertFalse(api, api.contains("unwrapService"));
    }

    @Test
    public void generatesGroupedTypedSearchApi() throws Exception {
        Map<String, CharSequence> files = generateApis(API_SOURCE);
        String api = norm(files.get(ROOT + "com/acme/api/ProductApi.ts"));
        assertTrue(api, api.contains("export class ProductApi {"));
        assertTrue(api, api.contains("export interface ProductSearchRequestExtras extends Pick<ProductSearchRequest, 'customScope'> {}"));
        assertTrue(api, api.contains("search(params: Omit<ProductSearchRequest, '@PQON' | 'offset' | 'customScope'> & { offset?: number } & ProductSearchRequestExtras): Observable<ProductDTO[]>"));
        assertTrue(api, api.contains("searchExtended(params: Omit<ProductSearchExtendedRequest, '@PQON' | 'offset'> & { offset?: number }): Observable<ProductDTO[]>"));
        assertTrue(api, api.contains(".pipe(map(unwrapSearch<ProductDTO>))"));
        assertTrue(api, api.contains("const ProductSearchRequestPQON = \"com.acme.api.ProductSearchRequest\";"));
        assertTrue(api, api.contains("import type { ProductSearchRequest } from \"./ProductSearchRequest\";"));
        assertTrue(api, api.contains("import type { ProductDTO } from \"./ProductDTO\";"));
        assertTrue(api, api.contains("ProductSearchRequestPQON, { ...params, offset: params.offset ?? 0 }"));
        assertTrue(api, api.contains("const ProductSearchExtendedRequestPQON = \"com.acme.api.ProductSearchExtendedRequest\";"));
        assertTrue(api, api.contains("ProductSearchExtendedRequestPQON, { ...params, offset: params.offset ?? 0 }"));
        assertTrue(api, !api.contains("unwrapLean"));

        String apiSource = String.join("\n",
            "package com.acme.api {",
            "    class ServiceResponse {}",
            "    class SearchCriteria { required int limit; required int offset; }",
            "    class LeanSearchResponse extends ServiceResponse {}",
            "    class Description {}",
            "    class LeanSearchRequest extends SearchCriteria return LeanSearchResponse {}",
            "    class PriceListLeanSearchRequest extends LeanSearchRequest {}",
            "    class RefResolverResponse extends ServiceResponse {}",
            "    class RefResolverRequest<REF> return RefResolverResponse {}",
            "    class ProductDTO {}",
            "    class ProductRef {}",
            "    class ProductNaturalRef extends ProductRef {}",
            "    class FullTracking {}",
            "    class ProductResolverRequest extends RefResolverRequest<ProductRef> {}",
            "    class CrudAnyKeyResponse<DATA, TRACKING> extends ServiceResponse {}",
            "    class CrudSurrogateResponse<DATA, TRACKING> extends CrudAnyKeyResponse<DATA, TRACKING> {}",
            "    class CrudSurrogateKeyRequest<REF, DATA, TRACKING> return CrudSurrogateResponse<!DATA, !TRACKING> {}",
            "    class ProductCrudRequest extends CrudSurrogateKeyRequest<ProductRef, ProductDTO, FullTracking> { optional Unicode(20) source; }",
            "    class ProductCrudViaApiRequest extends CrudSurrogateKeyRequest<ProductRef, ProductDTO, FullTracking> {}",
            "    class CrudStringKeyRequest<DATA, TRACKING> return CrudAnyKeyResponse<!DATA, !TRACKING> {}",
            "    class UserCrudRequest extends CrudStringKeyRequest<ProductDTO, FullTracking> {}",
            "    class CrudCompositeKeyRequest<KEY, DATA, TRACKING> return CrudAnyKeyResponse<!DATA, !TRACKING> {}",
            "    class OrderKey {}",
            "    class OrderCrudRequest extends CrudCompositeKeyRequest<OrderKey, ProductDTO, FullTracking> {}",
            "    class CrudModuleCfgRequest<DATA> extends CrudCompositeKeyRequest<ModuleConfigKey, !DATA, FullTracking> {}",
            "    class ModuleConfigKey {}",
            "    class ProductCrudModuleCfgRequest extends CrudModuleCfgRequest<ProductDTO> {}",
            "    class MassResolverResponse extends ServiceResponse {}",
            "    class MassResolverRequest extends SearchCriteria return MassResolverResponse {}",
            "    class ProductMassResolverRequest extends MassResolverRequest {}",
            "}",
            "");
        Map<String, CharSequence> otherFiles = generateApis(apiSource);
        String priceApi = norm(otherFiles.get(ROOT + "com/acme/api/PriceListApi.ts"));
        assertTrue(priceApi, priceApi.contains("params: Omit<PriceListLeanSearchRequest, '@PQON' | 'offset'> & { offset?: number }"));
        assertTrue(priceApi, priceApi.contains("PriceListLeanSearchRequestPQON, { ...params, offset: params.offset ?? 0 }"));
        assertTrue(priceApi, priceApi.contains("Observable<Description[]>"));
        assertTrue(priceApi, priceApi.contains("map(unwrapLean)"));
        String productApi = norm(otherFiles.get(ROOT + "com/acme/api/ProductApi.ts"));
        assertTrue(productApi, productApi.contains("export interface ProductCrudRequestExtras extends Pick<ProductCrudRequest, 'source'> {}"));
        assertTrue(productApi, productApi.contains("resolve(params: Omit<ProductResolverRequest, '@PQON'>): Observable<number>"));
        assertTrue(productApi, productApi.contains("map(unwrapResolve)"));
        assertTrue(productApi, productApi.contains("execute(params: Omit<ProductCrudRequest, '@PQON' | 'source'> & ProductCrudRequestExtras): Observable<ProductDTO>"));
        assertTrue(productApi, productApi.contains("import type { ProductRef } from \"./ProductRef\";"));
        assertTrue(productApi, productApi.contains("map(unwrapCrud<ProductDTO>)"));
        assertTrue(productApi, productApi.contains("create(data: ProductDTO,"));
        assertTrue(productApi, productApi.contains("extras: Partial<Omit<ProductCrudRequest, '@PQON' | 'crud' | 'data' | 'onlyActive' | 'source'>> & ProductCrudRequestExtras = {}"));
        assertTrue(productApi, productApi.contains("\n    create(data: ProductDTO,"));
        assertTrue(productApi, productApi.contains("\n        return this.rpc.call<"));
        assertTrue(productApi, !productApi.matches("(?s).*\\n[ \\t]+\\n.*"));
        assertTrue(productApi, productApi.contains("read(key: number,"));
        assertTrue(productApi, productApi.contains("update(key: number, data: Partial<ProductDTO>,"));
        assertTrue(productApi, productApi.contains("delete(key: number,"));
        assertTrue(productApi, productApi.contains("readByNaturalKey(naturalKey: ProductRef | ProductNaturalRef,"));
        assertTrue(productApi, productApi.contains("updateByNaturalKey(naturalKey: ProductRef | ProductNaturalRef, data: Partial<ProductDTO>,"));
        assertTrue(productApi, productApi.contains("deleteByNaturalKey(naturalKey: ProductRef | ProductNaturalRef,"));
        assertTrue(productApi, productApi.contains("readByNaturalKeyViaApi(naturalKey: ProductRef | ProductNaturalRef,"));
        assertTrue(productApi, productApi.contains("crud: 'C', onlyActive: false, data"));
        assertTrue(productApi, productApi.contains("crud: 'R', onlyActive: false, key"));
        assertTrue(productApi, productApi.contains("crud: 'R', onlyActive: false, naturalKey"));
        assertTrue(productApi, productApi.contains("crud: 'U', onlyActive: false, key, data"));
        assertTrue(productApi, productApi.contains("crud: 'U', onlyActive: false, naturalKey, data"));
        assertTrue(productApi, productApi.contains("crud: 'D', onlyActive: false, key"));
        assertTrue(productApi, productApi.contains("crud: 'D', onlyActive: false, naturalKey"));
        assertTrue(productApi, productApi.contains("executeViaApi(params: Omit<ProductCrudViaApiRequest, '@PQON'>)"));
        assertTrue(productApi, productApi.contains("createViaApi(data: ProductDTO,"));
        assertTrue(productApi, productApi.contains("readUser(key: string,"));
        assertTrue(productApi, productApi.contains("readOrder(key: OrderKey,"));
        assertTrue(productApi, productApi.contains("readModuleCfg(key: ModuleConfigKey,"));
        assertTrue(productApi, productApi.contains("resolveMany(params: Omit<ProductMassResolverRequest, '@PQON' | 'offset'> & { offset?: number }): Observable<number[]>"));
        assertTrue(productApi, productApi.contains("ProductMassResolverRequestPQON, { ...params, offset: params.offset ?? 0 }"));
        assertTrue(productApi, productApi.contains("map(unwrapResolveMany)"));

        String specialSource = String.join("\n",
            "package com.acme.request {",
            "    class ServiceResponse {}",
            "    class RequestParameters return ServiceResponse {}",
            "    class ReloadAllRequest extends RequestParameters {}",
            "    class DetailResponse extends ServiceResponse { required unicode(20) detail; }",
            "    class DetailRequest extends RequestParameters return DetailResponse {}",
            "}",
            "");
        Map<String, CharSequence> specialFiles = generateApis(specialSource);
        String specialApi = norm(specialFiles.get(ROOT + "com/acme/request/AcmeApi.ts"));
        assertTrue(specialApi, specialApi.contains("reloadAll(params: Omit<ReloadAllRequest, '@PQON'>): Observable<void>"));
        assertTrue(specialApi, specialApi.contains("map(unwrapVoid)"));
        assertTrue(specialApi, specialApi.contains("detail(params: Omit<DetailRequest, '@PQON'>): Observable<Omit<DetailResponse, 'returnCode'>>"));
        assertTrue(specialApi, specialApi.contains("unwrapService<DetailResponse>"));
    }
}
