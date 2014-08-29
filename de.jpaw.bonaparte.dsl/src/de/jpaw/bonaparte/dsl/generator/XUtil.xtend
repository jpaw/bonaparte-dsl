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

import java.util.List

import de.jpaw.bonaparte.dsl.bonScript.ElementaryDataType
import de.jpaw.bonaparte.dsl.bonScript.DataType
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.bonScript.GenericsDef
import de.jpaw.bonaparte.dsl.bonScript.XRequired
import de.jpaw.bonaparte.dsl.bonScript.ClassReference
import org.apache.log4j.Logger;
import de.jpaw.bonaparte.dsl.bonScript.MapModifier
import de.jpaw.bonaparte.dsl.bonScript.PropertyUse
import org.eclipse.emf.ecore.EObject
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition
import de.jpaw.bonaparte.dsl.bonScript.XVisibility
import de.jpaw.bonaparte.dsl.bonScript.XBeanNames
import java.util.ArrayList
import de.jpaw.bonaparte.dsl.bonScript.XXmlAccess
import de.jpaw.bonaparte.dsl.bonScript.XEnumDefinition
import de.jpaw.bonaparte.dsl.BonScriptPreferences

class XUtil {
    private static Logger logger = Logger.getLogger(XUtil)
    public static final String bonaparteInterfacesPackage = "de.jpaw.bonaparte.core"

    def public static xEnumFactoryName(DataTypeExtension ref) {
        ref.elementaryDataType.xenumType.getRoot.name + ".myFactory"
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

    def public static PackageDefinition getPackageOrNull(EObject ee) {
        var e = ee
        while (e !== null) {
            if (e.eIsProxy)
                logger.warn("Is a proxy only: " + e.eClass.name)
            if (e instanceof PackageDefinition)
                return e
            if (e.eClass.name == "PackageDefinition") {
                if (e instanceof PackageDefinition) {
                    logger.warn("*** RESOLVED *** ")
                    return e
                }
                logger.warn("*** NOT RESOLVED *** ")
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
        return d.getRoot.immutable
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
    def public static getXmlNs(ClassDefinition d) {
        d.xmlNs ?: getPackage(d).xmlNs     // default to no XMLAccess annotations
    }
    def public static getRelevantXmlAccess(XEnumDefinition d) {
        var XXmlAccess t = d.xmlAccess?.x ?: getPackage(d).xmlAccess?.x ?: null     // default to no XMLAccess annotations
        return if (t == XXmlAccess::NOXML || BonScriptPreferences.getNoXML) null else t
    }
    def public static getXmlNs(XEnumDefinition d) {
        d.xmlNs ?: getPackage(d).xmlNs     // default to no XMLAccess annotations
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
    
    def public static String genericRef2String(ClassReference r) {
        if (r.plainObject)
            return "BonaPortable"
        if (r.genericsParameterRef !== null)
            return r.genericsParameterRef.name
        if (r.classRef !== null) {
            if (r.classRef.externalType !== null)
                return r.classRef.externalType.qualifiedName
            else
                return r.classRef.name + genericArgs2String(r.classRefGenericParms)
        }

        logger.error("*** FIXME: class reference with all null fields ***")
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

    def public static int mapIndexID(MapModifier i) {
        if (i.indexType == "String")
            return 1
        if (i.indexType == "Integer")
            return 2
        if (i.indexType == "Long")
            return 3
        return 0  // should not happen
    }
    def public static int mapIndexLength(MapModifier i) {
        if (i.indexType == "String")
            return 255
        if (i.indexType == "Integer")
            return 9
        if (i.indexType == "Long")
            return 18
        return 0  // should not happen
    }

    def public static loopStart(FieldDefinition i) '''
        «IF i.isArray !== null»
            if («i.name» != null)
                for (int _i = 0; _i < «i.name».length; ++_i)
        «ELSEIF i.isList !== null || i.isSet !== null»
            if («i.name» != null)
                for («JavaDataTypeNoName(i, true)» _i : «i.name»)
        «ELSEIF i.isMap !== null»
            if («i.name» != null)
                for (Map.Entry<«i.isMap.indexType»,«JavaDataTypeNoName(i, true)»> _i : «i.name».entrySet())
        «ENDIF»
        '''

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
                    logger.error("requiredness of field " + i.name + " in class " + (i.eContainer as ClassDefinition).name
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
        import de.jpaw.util.ToStringHelper;
        import de.jpaw.util.ApplicationException;
        import de.jpaw.util.DayTime;
        import de.jpaw.util.ByteUtil;
        import de.jpaw.util.BigDecimalTools;
        import de.jpaw.util.IntegralLimits;
        import «BonScriptPreferences.getDateTimePackage».Instant;
        import «BonScriptPreferences.getDateTimePackage».LocalTime;
        import «BonScriptPreferences.getDateTimePackage».LocalDate;
        import «BonScriptPreferences.getDateTimePackage».LocalDateTime;
    '''
    
    def public static enumForEnumOrXenum(DataTypeExtension ref) {
        if (ref.elementaryDataType?.xenumType !== null)
            ref.elementaryDataType?.xenumType.myEnum
        else 
            ref.elementaryDataType?.enumType
    }
    
    // returns true if this an enum or an xenum which can have an instance of null
    def public static isASpecialEnumWithEmptyStringAsNull(FieldDefinition f) {
        val ref = DataTypeExtension.get(f.datatype)
        if (ref.enumMaxTokenLength < 0)
            return false
        val avalues = ref.enumForEnumOrXenum.avalues
//        if (avalues === null)
//          return false
        return avalues.map[token].contains("")
    }
    def public static idForEnumTokenNull(FieldDefinition f) {
        val ref = DataTypeExtension.get(f.datatype)
        if (ref.enumMaxTokenLength < 0)
            null
        else
            ref.enumForEnumOrXenum.avalues.findFirst[token.empty]?.name
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
        !cd.unfreezable && (cd.parent === null || cd.parent.isFreezable(remainingDepth-1)) && 
            !cd.fields.exists[isArray !== null || (datatype.elementaryDataType !== null && #[ "raw", "object", "bonaportable" ].contains(datatype.elementaryDataType.name.toLowerCase))] &&
            !cd.genericParameters.exists[extends !== null && !extends.isFreezable(remainingDepth-1)]
    }
    
    def public static boolean isFreezable(ClassDefinition cd) {
        cd.isFreezable(100)
    }
    
    def public static int getEffectiveFactoryId(ClassDefinition cd) {
        val pkg = cd.getPackage
        if (pkg.hazelcastFactoryId == 0)
            return BonScriptPreferences.currentPrefs.defaulthazelcastFactoryId
        else
            return pkg.hazelcastFactoryId
    }
    
    def public static String getAdapterClassName(ClassDefinition cd) {
        return cd.bonaparteAdapterClass ?: cd.externalType.qualifiedName
    }
}
