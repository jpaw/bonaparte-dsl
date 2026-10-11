package de.jpaw.bonaparte.dsl.generator.ts;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Collections;
import java.util.Map;
import java.util.Properties;

import org.eclipse.emf.common.util.TreeIterator;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.common.util.URI;
import org.eclipse.xtext.generator.GeneratorContext;
import org.eclipse.xtext.generator.InMemoryFileSystemAccess;
import org.eclipse.xtext.resource.XtextResource;
import org.eclipse.xtext.resource.XtextResourceSet;
import org.junit.BeforeClass;
import org.junit.Test;

import com.google.inject.Injector;

import de.jpaw.bonaparte.dsl.BonScriptStandaloneSetup;
import de.jpaw.bonaparte.dsl.BonScriptPreferences;
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition;
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension;

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
        "    class ReadAllResponse<DATA, TRACKING> extends SearchResponse<DATA, TRACKING> {}",
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
        "    class ReadAllResponse<DATA, TRACKING> extends SearchResponse<DATA, TRACKING> {}",
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

    private static String norm(CharSequence s) {
        assertNotNull(s);
        return s.toString().replace("\r", "");
    }

    @Test
    public void generatesOneFilePerTypeInPackageFolders() throws Exception {
        Map<String, CharSequence> files = generate(BON_SOURCE);
        for (String f : new String[] { "base/SortOrder", "base/Mode", "base/TimeUnit", "base/Base", "auth/Child" })
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
    public void interfaceWithInheritanceAndImports() throws Exception {
        String base = norm(generate(BON_SOURCE).get(ROOT + "com/acme/base/Base.ts"));
        assertTrue(base, base.contains("export const BasePQON = \"com.acme.base.Base\" as const;"));
        assertTrue(base, base.contains("export interface Base {"));
        assertTrue(base, base.contains("objectRef: number;"));

        String child = norm(generate(BON_SOURCE).get(ROOT + "com/acme/auth/Child.ts"));
        assertTrue(child, child.contains("import type { Base } from \"../base/Base\";"));
        assertTrue(child, child.contains("import type { SortOrder } from \"../base/SortOrder\";"));
        assertTrue(child, child.contains("import type { TimeUnit } from \"../base/TimeUnit\";"));
        assertTrue(child, child.contains("export const ChildPQON = \"com.acme.auth.Child\" as const;"));
        assertTrue(child, child.contains("export interface Child<T = unknown> extends Omit<Base, '@PQON'> {"));
        assertTrue(child, child.contains("'@PQON': typeof ChildPQON;"));
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
        assertField(child, "modes: number;");                    // numeric enumset -> integer bitmap (required by spec)
        assertField(child, "units: string;");                    // xenumset -> string (required by spec)
        assertField(child, "blob?: BonaPortable | null;");       // plain Object
        assertField(child, "oldAge?: number | null;");           // deprecated field still generated
    }

    @Test
    public void everyObjectHasPqonField() throws Exception {
        Map<String, CharSequence> files = generate(BON_SOURCE);
        for (String f : new String[] { "base/Base", "base/Legacy", "auth/Child" })
            assertTrue(f, norm(files.get(ROOT + "com/acme/" + f + ".ts")).contains("'@PQON': typeof"));
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
            assertTrue(index, index.contains("export { ChildPQON }"));
            assertTrue(index, index.contains("export type { Child }"));

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
    public void apiServicesImportRuntimeSupportFromPrimaryPackage() throws Exception {
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
            assertTrue(api, api.contains("import type { BonaPortable } from '@fixture/t9t-api';"));
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
            "    class ReadAllResponse<DATA, TRACKING> extends SearchResponse<DATA, TRACKING> {}",
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
    public void appliesApiNamingOverrides() throws Exception {
        Path namingFile = Files.createTempFile("ts-api-naming", ".properties");
        String previousNamingFile = BonScriptPreferences.currentPrefs.tsApiNamingFile;
        try {
            Files.writeString(namingFile, "ProductSearchRequest.api=CatalogApi\nProductSearchRequest.method=findProducts\n");
            BonScriptPreferences.currentPrefs.tsApiNamingFile = namingFile.toString();
            Map<String, CharSequence> files = generateApis(API_SOURCE);
            String api = norm(files.get(ROOT + "com/acme/api/CatalogApi.ts"));
            assertTrue(api, api.contains("export class CatalogApi {"));
            assertTrue(api, api.contains("findProducts(params: Omit<ProductSearchRequest, '@PQON' | 'offset' | 'customScope'>"));
        } finally {
            BonScriptPreferences.currentPrefs.tsApiNamingFile = previousNamingFile;
            Files.deleteIfExists(namingFile);
        }
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
        assertTrue(productApi, productApi.contains("read(key: ProductRef | ProductNaturalRef,"));
        assertTrue(productApi, productApi.contains("update(key: ProductRef | ProductNaturalRef, data: Partial<ProductDTO>,"));
        assertTrue(productApi, productApi.contains("delete(key: ProductRef | ProductNaturalRef,"));
        assertTrue(productApi, productApi.contains("crud: 'C', onlyActive: false, data"));
        assertTrue(productApi, productApi.contains("crud: 'R', onlyActive: false, key"));
        assertTrue(productApi, productApi.contains("crud: 'U', onlyActive: false, key, data"));
        assertTrue(productApi, productApi.contains("crud: 'D', onlyActive: false, key"));
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
