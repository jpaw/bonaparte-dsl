 /*
  * Copyright 2012 Michael Bischoff
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
  * You may obtain a copy of the License at
  *
  *   http://www.apache.org/licenses/LICENSE-2.0
  *
  * Unless required by applicable law or agreed to in writing, software
  * distributed under the License is distributed on an "AS IS" BASIS,
  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  * See the License for the specific language governing permissions and
  * limitations under the License.
  */

package de.jpaw.bonaparte.dsl.generator

import com.google.common.base.Joiner
import com.google.common.base.Splitter
import com.google.common.collect.Lists
import de.jpaw.bonaparte.dsl.BonScriptPreferences
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassReference
import de.jpaw.bonaparte.dsl.bonScript.DataType
import de.jpaw.bonaparte.dsl.bonScript.ElementaryDataType
import de.jpaw.bonaparte.dsl.bonScript.EnumSetDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.bonScript.GenericsDef
import de.jpaw.bonaparte.dsl.bonScript.MapModifier
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition
import de.jpaw.bonaparte.dsl.bonScript.PropertyUse
import de.jpaw.bonaparte.dsl.bonScript.XBeanNames
import de.jpaw.bonaparte.dsl.bonScript.XEnumDefinition
import de.jpaw.bonaparte.dsl.bonScript.XRequired
import de.jpaw.bonaparte.dsl.bonScript.XVisibility
import de.jpaw.bonaparte.dsl.bonScript.XXmlAccess
import java.util.ArrayList
import java.util.List
import org.apache.log4j.Logger
import org.eclipse.emf.ecore.EObject

class XUtil {
    private static Logger LOGGER = Logger.getLogger(XUtil)
    public static final String bonaparteInterfacesPackage   = "de.jpaw.bonaparte.core"
    public static final String PROP_ACTIVE                  = "active";
    public static final String PROP_ATTRIBUTE               = "xmlAttribute";
    public static final String PROP_UPPERCASE               = "xmlUppercase";  // upper case for a single element (first char)
    public static final String PROP_ALL_UPPERCASE           = "xmlAllUppercase";  // upper case for a single element (all characters)
    public static final String PROP_XML_ID                  = "xmlId";            // separate name


    def public static xEnumFactoryName(DataTypeExtension ref) {
        ref.elementaryDataType.xenumType.root.name + ".myFactory"
    }
    def public static ClassDefinition getParent(ClassDefinition d) {
        d?.getExtendsClass?.getClassRef
    }

    def public static ClassDefinition getRoot(ClassDefinition d) {
        var dd = d
        while (dd.parent !== null)
            dd = dd.parent
        return dd
    }
    def public static XEnumDefinition getRoot(XEnumDefinition d) {
        var dd = d
        while (dd.extendsXenum !== null)
            dd = dd.extendsXenum
        return dd
    }

    def public static DataTypeExtension getRootDataType(FieldDefinition f) {
        f.datatype.rootDataType
    }

    def public static DataTypeExtension getRootDataType(DataType dt) {
        return DataTypeExtension::get(dt)
    }

    def public static PackageDefinition getPackageOrNull(EObject ee) {
        var e = ee
        while (e !== null) {
            if (e.eIsProxy)
                LOGGER.warn("Is a proxy only: " + e.eClass.name)
            if (e instanceof PackageDefinition)
                return e
            if (e.eClass.name == "PackageDefinition") {
                if (e instanceof PackageDefinition) {
                    LOGGER.warn("*** RESOLVED *** ")
                    return e
                }
                LOGGER.warn("*** NOT RESOLVED *** ")
                // what now?
            }
            e = e.eContainer
        }
        return null
    }
    /** Returns the package in which an object is defined in. Expectation is that there is a class of type PackageDefinition containing it at some level.
     * If this cannot be found, throw an Exception, because callers assume the result is not null and would throw a NPE anyway.
     */
    def public static getPackage(EObject ee) {
        val e = ee.packageOrNull
        if (e !== null)
            return e
        throw new Exception("getPackage() called for " + (ee?.toString() ?: "NULL"))
    }

    def public static boolean isRootImmutable(ClassDefinition d) {
        return d.root.immutable
    }

    def public static boolean parentCacheHash(ClassDefinition d) {
        if (d === null)
            return false
        return d.doCacheHash || parentCacheHash(d.parent)
    }

    def public static getRelevantXmlAccess(ClassDefinition d) {
        var XXmlAccess t = d.xmlAccess?.x ?: getPackage(d).xmlAccess?.x ?: null     // default to no XMLAccess annotations
        return if (t == XXmlAccess::NOXML || BonScriptPreferences.getNoXML) null else t
    }

    /** Reverses the ordering of the simple components of a qualified ID, for example from com.foo.bar.mega to mega.bar.foo.com. */
    def public static reverseIDs(String s) {
        Joiner.on(".").join(Lists.reverse(Splitter.on('.').split(s).toList))
    }

    /** Computes the schema name abbreviation. */
    def static schemaToken(PackageDefinition pkg) {
        if (pkg.xmlNsPrefix.nullOrEmpty)   // the case empty is used in the JAVA generated package info file, but not for xsd file creation
            return pkg.name.replace('.', '_')
        return pkg.xmlNsPrefix
    }
    /** Computes the full URL for the schema. */
    def public static effectiveXmlNs(EObject d) {
        val pkg = d.package
        return pkg.xmlNs ?: '''http://«IF pkg.prefix !== null»«pkg.prefix.reverseIDs»«ELSE»www.jpaw.de«ENDIF»/schema/«pkg.schemaToken».xsd'''
    }

    def public static getRelevantXmlAccess(XEnumDefinition d) {
        var XXmlAccess t = d.xmlAccess?.x ?: getPackage(d).xmlAccess?.x ?: null     // default to no XMLAccess annotations
        return if (t == XXmlAccess::NOXML || BonScriptPreferences.getNoXML) null else t
    }
    def public static needsXmlObjectType(FieldDefinition f) {
        if (f.datatype.objectDataType !== null) {
            f.datatype.objectDataType.needsXmlObjectType
        } else {
            val ref = DataTypeExtension::get(f.datatype)
            ref !== null && ref.elementaryDataType?.name == 'Object'
        }
    }
    def public static boolean needsXmlObjectType(ClassReference r) {
        r.plainObject || (r.genericsParameterRef !== null && r.genericsParameterRef.hasNoBound)
    }
    def public static boolean hasNoBound(GenericsDef rd) {
        rd.extends === null || rd.extends.needsXmlObjectType
    }
    // return null if the object is a generic BonaPortable, or the java type if it is bounded by a specific object
    def public static ClassDefinition getLowerBound(ClassReference r) {
        if (r === null || r.plainObject)
            return null;
        if (r.genericsParameterRef !== null)
            return getLowerBound(r.genericsParameterRef.extends);
        return r.classRef
    }

    // determines of an instance of potentialSubClass can be assigned to superClass.
    // in case of generics, lower bounds are used.
    // superClass may not be null
    def public static boolean isSuperClassOf(ClassDefinition superClass, ClassReference potentialSubClass) {
        val currentLowerBound = potentialSubClass?.lowerBound
        if (currentLowerBound === null)
            return false
        if (superClass == currentLowerBound)
            return true
        return superClass.isSuperClassOf(currentLowerBound.extendsClass)
    }

    def public static String externalName(ClassDefinition cd) {
        if (cd.useFqn)
            return cd.externalType.qualifiedName    // qualifiedName desired due to possible naming conflict
        else
            return cd.externalType.simpleName       // qualifiedName should not be required, we added the import!
    }

    def public static String genericRef2String(ClassReference r) {
        if (r.plainObject)
            return "BonaPortable"
        if (r.genericsParameterRef !== null)
            return r.genericsParameterRef.name
        if (r.classRef !== null) {
            if (r.classRef.externalType !== null) {
                return r.classRef.externalName
            } else {
                return r.classRef.name + genericArgs2String(r.classRefGenericParms)
            }
        }

        LOGGER.error("*** FIXME: class reference with all null fields ***")
        return "*** FIXME: class reference with all null fields ***"
    }

    def public static genericArgs2String(List<ClassReference> args) {
        if (args === null)
            return ""
        '''«FOR a : args BEFORE '<' SEPARATOR ', ' AFTER '>'»«genericRef2String(a)»«ENDFOR»'''
    }

    def public static genericDef2String(List<GenericsDef> args) {
        if (args === null)
            return ""
        '''«FOR a : args BEFORE '<' SEPARATOR ', ' AFTER '>'»«a.name» extends «IF a.^extends !== null»«genericRef2String(a.^extends)»«ELSE»BonaPortable«ENDIF»«ENDFOR»'''
    }

    def public static genericDef2StringAsParams(List<GenericsDef> args) {
        if (args === null)
            return ""
        '''«FOR a : args BEFORE '<' SEPARATOR ', ' AFTER '>'»«a.name»«ENDFOR»'''
    }

    // get the elementary data object after resolving typedefs
    // uses caching to keep overall running time at O(1) per call
    def public static ElementaryDataType resolveElem(DataType d) {
        DataTypeExtension::get(d).elementaryDataType
    }

    // get the class / object reference after resolving typedefs
    // uses caching to keep overall running time at O(1) per call
    def public static ClassDefinition resolveObj(DataType d) {
        DataTypeExtension::get(d).objectDataType
    }

    // convert an Xtend boolean to Java source token
    def public static b2A(boolean f) {
        if (f) "true" else "false"
    }

    // convert an Xtend boolean to Java source token
    def public static B2A(Boolean f) {
        if (f === null) return "null"
        if (f) "true" else "false"
    }

    // convert a String to Java source token, keeping nulls
    def public static s2A(String s) {
        if (s === null) return "null" else return '''"«Util::escapeString2Java(s)»"'''
    }

    def public static indexedName(FieldDefinition i) {
        if (i.isList !== null || i.isSet !== null) "_i" else if (i.isMap !== null) "_i.getValue()" else if (i.isArray !== null) i.name + "[_i]" else i.name
    }

//    def public static int mapIndexID(MapModifier i) {
//        if (i.indexType == "String")
//            return 1
//        if (i.indexType == "Integer")
//            return 2
//        if (i.indexType == "Long")
//            return 3
//        return 0  // should not happen
//    }
    def public static int mapIndexLength(MapModifier i) {
        if (i.indexType == "String")
            return 255
        if (i.indexType == "Integer")
            return 9
        if (i.indexType == "Long")
            return 18
        return 0  // should not happen
    }

    def public static loopStart(FieldDefinition i, boolean withNullCheck) {
        val check = if (withNullCheck) '''if («i.name» != null) ''';
        if (i.isArray !== null)
            return '''«check»for (int _i = 0; _i < «i.name».length; ++_i) '''
        if (i.isList !== null || i.isSet !== null)
            return '''«check»for («JavaDataTypeNoName(i, true)» _i : «i.name») '''
        if (i.isMap !== null)
            return '''«check»for (Map.Entry<«i.isMap.indexType»,«JavaDataTypeNoName(i, true)»> _i : «i.name».entrySet()) '''
        return null
    }

    def public static loopMaxCount(FieldDefinition i) {
        if (i.isArray !== null)
            return i.isArray.maxcount
        else if (i.isList !== null)
            return i.isList.maxcount
        else if (i.isSet !== null)
            return i.isSet.maxcount
        else if (i.isMap !== null)
            return i.isMap.maxcount  // currently not yet supported
        return 0
    }

    def public static String getJavaDataType(DataType d) {
        val ref = DataTypeExtension::get(d)
        if (ref.isPrimitive)
            ref.elementaryDataType.name
        else
            ref.javaType
    }

    def public static String getNameCapsed(String fieldname, ClassDefinition d) {
        if (d.beanNames == XBeanNames::ONLY_BEAN_NAMES)
            return fieldname.beanName
        else
            return fieldname.toFirstUpper
    }

    def public static String getBeanName(String fieldname) {
        if (fieldname.length >= 2) {
            if (Character::isLowerCase(fieldname.charAt(0)) && Character.isUpperCase(fieldname.charAt(1)))
                return fieldname
        }
        return fieldname.toFirstUpper
    }

    def public static getBeanNames(ClassDefinition d) {
        d.doBeanNames?.x ?: getPackage(d).doBeanNames?.x ?: XBeanNames::BEAN_AND_SIMPLE_NAMES  // default to creation of no bean validation annotations
    }

    def public static aggregateOf(FieldDefinition i, String dataClass) {
         if (i.isArray !== null)
            dataClass + "[]"
        else if (i.isSet !== null)
            "Set<" + dataClass + ">"
        else if (i.isList !== null)
            "List<" + dataClass + ">"
        else if (i.isMap !== null)
            "Map<" + i.isMap.indexType + "," + dataClass + ">"
        else
            dataClass
    }
    // the same, more complex scenario
    def public static JavaDataTypeNoName(FieldDefinition i, boolean skipIndex) {
        var String dataClass
        //fieldDebug(i)
        if (resolveElem(i.datatype) !== null)
            dataClass = getJavaDataType(i.datatype)
        else {
            dataClass = DataTypeExtension::get(i.datatype).javaType
        }
        if (skipIndex)
            dataClass
        else
            i.aggregateOf(dataClass)
    }

    // checks if null can be assigned to a field. If the field is an aggregate, this relates to the aggregate itself, not its members.
    // for primitives, false is returned.
    def public static boolean cannotBeNull(FieldDefinition it) {
        if (aggregate) isAggregateRequired else isRequired
    }

    def public static boolean isRequired(FieldDefinition i) {
        var ref = DataTypeExtension::get(i.datatype)
        if (ref.isRequired !== null) {
            if (i.required !== null && i.required.x !== null) {
                // both are defined. Check for consistency
                if (ref.isRequired != i.required.x) {
                    // late plausi check:
                    LOGGER.error("requiredness of field " + i.name + " in class " + (i.eContainer as ClassDefinition).name
                        + " relabeled from " + ref.isRequired + " to " + i.required.x
                        + ". This is inconsistent.")
                }
            }
            return ref.isRequired == XRequired::REQUIRED
        }
        // now check if an explicit specification has been made
        if (i.required !== null)
            return i.required.x == XRequired::REQUIRED

        // neither ref.isRequired is set nor an explicit specification made.  Fall back to defaults of the embedding class or package

        // DEBUG
        //if (i.name.equals("fields"))
        //    System::out.println("fields.required = " + i.required + ", defaultreq = " + ref.defaultRequired)
        // if we have an object, it is nullable by default, unless some explicit or
        if (ref.defaultRequired !== null)
            return ref.defaultRequired == XRequired::REQUIRED
        else
            return false  // no specification at all means optional
    }

    def public static condText(boolean flag, String text) {
        if (flag) text else ""
    }

    def public static vlr(String text1, String l, String r, String otherwise) {
        if (text1 !== null) l + text1 + r else otherwise
    }
    def public static nvl(String text1, String otherwise) {
        if (text1 !== null) text1 else otherwise
    }
    def public static nnvl(String text1, String text2, String otherwise) {
        if (text1 !== null) text1 else if (text2 !== null) text2 else otherwise
    }

    // moved from persistence / YUtil:
    def public static boolean hasProperty(List <PropertyUse> properties, String key) {
        if (properties !== null)
            for (p : properties)
                if (key.equals(p.key.name))
                    return true
        return false
    }

    def public static String getProperty(List <PropertyUse> properties, String key) {
        if (properties !== null)
            for (p : properties)
                if (key.equals(p.key.name))
                    return p.value
        return null
    }

    // determines if the field is an aggregate type (array / list / map and possibly later additional
    def public static boolean isAggregate(FieldDefinition c) {
        return c.isArray !== null || c.isList !== null || c.isSet !== null || c.isMap !== null
    }
    // determines if the field is an aggregate type (array / list / map and possibly later additional
    def public static aggregateToken(FieldDefinition c) {
        if (c.isArray !== null)
            return "[]"
        if (c.isList !== null)
            return "List"
        if (c.isSet !== null)
            return "Set"
        if (c.isMap !== null)
            return "Map"
        null
    }
    // determines if the field is an aggregate type (array / list / map and possibly later additional
    def public static int aggregateMaxSize(FieldDefinition c) {
        if (c.isArray !== null)
            return c.isArray.maxcount
        if (c.isList !== null)
            return c.isList.maxcount
        if (c.isSet !== null)
            return c.isSet.maxcount
        if (c.isMap !== null)
            return c.isMap.maxcount
        0
    }

    def public static getFieldVisibility(ClassDefinition d, FieldDefinition i) {
        (i.visibility ?: d.defaults?.visibility ?: getPackage(d).defaults?.visibility)?.x ?: XVisibility::DEFAULT
    }

    def public static List<FieldDefinition> allFields(ClassDefinition cl) {
        if (cl.extendsClass?.classRef === null)
            return cl.fields;
        // at least 2 lists to combine
        val result = new ArrayList<FieldDefinition>(50)
        result.addAll(cl.extendsClass?.classRef.allFields)
        result.addAll(cl.fields)
        return result
    }

    def public static writeDefaultImports() '''
        import java.util.Arrays;
        import java.util.Collections;
        import java.util.List;
        import java.util.ArrayList;
        import java.util.regex.Pattern;
        import java.util.regex.Matcher;
        import java.util.UUID;
        import java.util.HashSet;
        import java.util.LinkedHashSet;
        import java.util.Set;
        import java.util.HashMap;
        import java.util.Map;
        import java.util.concurrent.ConcurrentHashMap;
        import java.util.concurrent.ConcurrentMap;
        import java.math.BigInteger;
        import java.math.BigDecimal;
        import de.jpaw.util.ByteArray;
        import de.jpaw.util.CharTestsASCII;
        import de.jpaw.util.ApplicationException;
        import de.jpaw.util.ByteUtil;
        import de.jpaw.util.IntegralLimits;
        import de.jpaw.bonaparte.util.ToStringHelper;
        import de.jpaw.bonaparte.util.DayTime;
        import de.jpaw.bonaparte.util.FreezeTools;
        import de.jpaw.bonaparte.util.FrozenCloneTools;
        import de.jpaw.bonaparte.util.MutableCloneTools;
        import de.jpaw.bonaparte.util.BigDecimalTools;
        import «BonScriptPreferences.getDateTimePackage».Instant;
        import «BonScriptPreferences.getDateTimePackage».LocalTime;
        import «BonScriptPreferences.getDateTimePackage».LocalDate;
        import «BonScriptPreferences.getDateTimePackage».LocalDateTime;
    '''

    // returns an enum if any indirection of the type references it
    def public static enumForEnumOrXenum(DataTypeExtension ref) {
        val e = ref.elementaryDataType
        if (e === null)
            return null
        if (e.enumType !== null)
            return e.enumType
        else if (e.xenumType !== null)
            return e.xenumType.myEnum
        else if (e.enumsetType !== null)
            return e.enumsetType.myEnum
        else if (e.xenumsetType !== null)
            return e.xenumsetType.myXEnum.myEnum
        else
            return null
    }

    // returns true if this an enum or an xenum which can have an instance of null
    def public static isASpecialEnumWithEmptyStringAsNull(FieldDefinition f) {
        val ref = DataTypeExtension.get(f.datatype)
        if (ref.category != DataCategory.ENUMALPHA && ref.category != DataCategory.XENUM)
            return false
        val avalues = ref.enumForEnumOrXenum.avalues
        return avalues.map[token].contains("")
    }
    def public static idForEnumTokenNull(FieldDefinition f) {
        val ref = DataTypeExtension.get(f.datatype)
        if (ref.category == DataCategory.ENUMALPHA || ref.category == DataCategory.XENUM)
            return ref.enumForEnumOrXenum.avalues.findFirst[token.empty]?.name
        else
            return null
    }

    // freezable checks can be cyclic! We know the class hierarchy is acyclic, so a assume all OK if no issue found after a certain nesting depth

    def private static boolean isFreezable(ClassReference it, int remainingDepth) {
        if (remainingDepth <= 0)
            return true
        classRef === null || (classRef.isFreezable(remainingDepth-1) && !classRefGenericParms.exists[!isFreezable(remainingDepth-1)])
    }

    // a class is considered to be freezable if it does not contain any mutable and non freezable subtypes.
    // by deduction, this means that immutable classes must also be considered as freezable, because they are immutable itself.
    // (the recursive definition of freezable would not work otherwise).
    // Therefore, in order to determine if a class can have both states, frozen and unfrozen, the correct condition is (freezable && !immutable)
    def public static boolean isFreezable(ClassReference it) {
        it.isFreezable(100)
    }

    def private static boolean isFreezable(ClassDefinition cd, int remainingDepth) {
        if (remainingDepth <= 0)
            return true
        return !cd.unfreezable
          && (cd.parent === null || cd.parent.isFreezable(remainingDepth-1))
          && !cd.fields.exists[isArray !== null || (datatype.elementaryDataType !== null && datatype.elementaryDataType.name.toLowerCase == "raw")]
          && !cd.genericParameters.exists[extends !== null && !extends.isFreezable(remainingDepth-1)]
    }

    def public static boolean isFreezable(ClassDefinition cd) {
        cd.isFreezable(100)
    }

    def public static int getEffectiveFactoryId(ClassDefinition cd) {
        val pkg = cd.package
        if (pkg.hazelcastFactoryId == 0)
            return BonScriptPreferences.currentPrefs.defaulthazelcastFactoryId
        else
            return pkg.hazelcastFactoryId
    }
    def public static CharSequence getEffectiveClassId(ClassDefinition cd) {
        if (cd.hazelcastId == 0 && !cd.abstract && !cd.singleField)
            return "MY_RTTI"
        else
            return '''«cd.hazelcastId»'''
    }

    def public static String getAdapterClassName(ClassDefinition cd) {
        return cd.bonaparteAdapterClass ?: cd.externalName  // the adapter classname or the external type (in either qualifier or unqualified form)
    }

    def public static mapEnumSetIndex(EnumSetDefinition e) {
        if (e.indexType === null || e.indexType == "int")
            return "Integer"
        return e.indexType.toFirstUpper
    }

    // get the first field of this or a parent (for external types). Assumption is there is only one field in total (singleFirst types).
    def public static FieldDefinition getFirstField(ClassDefinition cd) {
        return if (cd.fields.size > 0) cd.fields.get(0) else cd.extendsClass.classRef.firstField
    }

    def public static writeIfDeprecated(FieldDefinition i) {
        if (i.isDeprecated)
            return "@Deprecated"
    }

    def public static ClassDefinition recursePkClass(ClassDefinition d) {
        return d.pkClass ?: if (d.isPkClass) d else d.extendsClass?.classRef?.recursePkClass
    }

    def public static ClassDefinition recurseTrackingClass(ClassDefinition d) {
        return d.trackingClass ?: d.extendsClass?.classRef?.recurseTrackingClass
    }

    def public static ClassDefinition recurseRefClass(ClassDefinition d) {
        return if (d.isIsRefClass) d else d.extendsClass?.classRef?.recurseRefClass
    }

    def public static String recurseRefP(ClassDefinition d) {
        return d.refPFunction ?: d.extendsClass?.classRef?.recurseRefP
    }
    def public static String recurseRefW(ClassDefinition d) {
        return d.refWFunction ?: d.extendsClass?.classRef?.recurseRefW
    }
    def public static String recurseKeyP(ClassDefinition d) {
        return d.keyPFunction ?: d.extendsClass?.classRef?.recurseKeyP
    }
    def public static String recurseKeyW(ClassDefinition d) {
        return d.keyWFunction ?: d.extendsClass?.classRef?.recurseKeyW
    }
    /** returns true if the class is not abstract and itself or one of its parent classes has been declared as xmlRoot. */
    def public static boolean effectiveXmlRoot(ClassDefinition d) {
        var dd = d
        if (d.isAbstract)
            return false
        while (dd !== null) {
            if (dd.isIsXmlRoot)
                return true
            dd = dd.parent
        }
        return false
    }

    def public static generateAnnotation(PropertyUse it) {
        return '''@«key.annotationReference.qualifiedName»«IF value !== null»(«IF key.withMultiArgs»«value»«ELSE»"«Util.escapeString2Java(value)»"«ENDIF»)«ENDIF»'''
    }
    def public static generateAllAnnotations(List<PropertyUse> it) {
        return filter[key.annotationReference !== null].map[generateAnnotation].join('\n')
    }

    def public static isJsonField(DataTypeExtension ref) {
        val elemType = ref.elementaryDataType?.name?.toLowerCase
        return elemType == "json" || elemType == "element" || elemType == "array"
    }

    def public static isXmlUpper(ClassDefinition cls) {
        return cls.isXmlUppercase || cls.package.isXmlUppercase
    }

    def public static isXmlAllUpper(ClassDefinition cls) {
        return cls.isXmlAllUppercase || cls.package.isXmlAllUppercase
    }

    def public static xmlName(FieldDefinition f, boolean toUpper, boolean toAllUpper) {
        val xsdId = f.properties.getProperty(PROP_XML_ID)
        return xsdId ?: f.metaName ?:
            if (toUpper || f.properties.hasProperty(PROP_UPPERCASE))
                f.name.toFirstUpper
            else if (toAllUpper || f.properties.hasProperty(PROP_ALL_UPPERCASE))
                f.name.toUpperCase
            else
                f.name
    }

    def public static typeOfAggregate(String aggregate) {
        switch (aggregate) {
            case "List": return "Array"
            case "Set": return "Hash"
            case "Map": return "Hash"
        }
    }
}
