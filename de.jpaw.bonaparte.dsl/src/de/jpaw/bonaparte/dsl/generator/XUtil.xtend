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

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.DataType
import de.jpaw.bonaparte.dsl.bonScript.ElementaryDataType
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.bonScript.GenericsDef
import de.jpaw.bonaparte.dsl.bonScript.MapModifier
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition
import de.jpaw.bonaparte.dsl.bonScript.PropertyUse
import de.jpaw.bonaparte.dsl.bonScript.XBeanNames
import de.jpaw.bonaparte.dsl.bonScript.XRequired
import de.jpaw.bonaparte.dsl.bonScript.XVisibility
import de.jpaw.bonaparte.dsl.bonScript.XXmlAccess
import java.util.ArrayList
import java.util.List
import org.apache.log4j.Logger
import org.eclipse.emf.ecore.EObject

class XUtil {
    private static Logger logger = Logger.getLogger(XUtil)
    public static final String bonaparteInterfacesPackage = "de.jpaw.bonaparte.core"

    def public static ClassDefinition getParent(ClassDefinition d) {
        d?.getExtendsClass?.referenceDataType as ClassDefinition
    }

    def public static ClassDefinition getRoot(ClassDefinition d) {
        var dd = d
        while (dd.parent != null)
            dd = dd.parent
        return dd
    }

    def public static getPackageOrNull(EObject ee) {
        var e = ee
        while (e != null) {
            if (e.eIsProxy)
                logger.warn("Is a proxy only: " + e.eClass.name)
            if (e instanceof PackageDefinition)
                return e as PackageDefinition
            if (e.eClass.name == "PackageDefinition") {
                if (e instanceof PackageDefinition) {
                    logger.warn("*** RESOLVED *** ")
                    return e as PackageDefinition
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
        if (e != null)
            return e
        throw new Exception("getPackage() called for " + (ee?.toString() ?: "NULL"))
    }

    def public static boolean isImmutable(ClassDefinition d) {
        return d.getRoot.immutable
    }

    def public static getRelevantXmlAccess(ClassDefinition d) {
        var XXmlAccess t = d.xmlAccess?.x ?: getPackage(d).xmlAccess?.x ?: null     // default to no XMLAccess annotations
        return if (t == XXmlAccess::NOXML) null else t
    }
    def public static getXmlNs(ClassDefinition d) {
        d.xmlNs ?: getPackage(d).xmlNs     // default to no XMLAccess annotations
    }
    def public static needsXmlObjectType(FieldDefinition f) {
        if (f.datatype != null) {
            f.datatype.needsXmlObjectType
        } else {
            val ref = DataTypeExtension::get(f.datatype)
            ref != null && ref.elementaryDataType?.name == 'Object'
        }
    }
    
    def static ClassDefinition getObjectDataType(DataType dt) {
    	dt.referenceDataType as ClassDefinition
    }
    
    def public static boolean needsXmlObjectType(DataType r) {
        r.isObject || (r.referenceDataType instanceof GenericsDef && (r.referenceDataType as GenericsDef).hasNoBound)
    }
    
    def public static boolean hasNoBound(GenericsDef rd) {
        rd.extends == null || rd.extends.needsXmlObjectType
    }
    
    def static isObject(DataType dt) {
    	dt?.elementaryDataType?.name == "Object" 
    }
    
    def public static String genericDataType2String(DataType r) {
        if (r.isObject)
            return "BonaPortable"
        if (r.elementaryDataType != null) {
        	return r.elementaryDataType.name
        }
        val params = if (r.classRefGenericParms.empty) {''} else {
        	'<'+r.classRefGenericParms.map[genericDataType2String(it)].join(', ')+'>'
        }
        return r.referenceDataType.name+params
    }

    def public static genericDef2String(List<GenericsDef> args) {
        if (args == null)
            return ""
        '''«FOR a : args BEFORE '<' SEPARATOR ', ' AFTER '>'»«a.name»«IF a.^extends != null» extends «genericDataType2String(a.^extends)»«ENDIF»«ENDFOR»'''
    }

    def public static genericDef2StringAsParams(List<GenericsDef> args) {
        if (args == null)
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

    // convert a String to Java source token, keeping nulls
    def public static s2A(String s) {
        if (s == null) return "null" else return '''"«Util::escapeString2Java(s)»"'''
    }

    def public static indexedName(FieldDefinition i) {
        if (i.isList != null || i.isSet != null) "_i" else if (i.isMap != null) "_i.getValue()" else if (i.isArray != null) i.name + "[_i]" else i.name
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
        «IF i.isArray != null»
            if («i.name» != null)
                for (int _i = 0; _i < «i.name».length; ++_i)
        «ELSEIF i.isList != null || i.isSet != null»
            if («i.name» != null)
                for («JavaDataTypeNoName(i, true)» _i : «i.name»)
        «ELSEIF i.isMap != null»
            if («i.name» != null)
                for (Map.Entry<«i.isMap.indexType»,«JavaDataTypeNoName(i, true)»> _i : «i.name».entrySet())
        «ENDIF»
        '''

    def public static loopMaxCount(FieldDefinition i) {
        if (i.isArray != null)
            return i.isArray.maxcount
        else if (i.isList != null)
            return i.isList.maxcount
        else if (i.isSet != null)
            return i.isSet.maxcount
        else if (i.isMap != null)
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
    
    // the same, more complex scenario
    def public static JavaDataTypeNoName(FieldDefinition i, boolean skipIndex) {
        var String dataClass
        //fieldDebug(i)
        if (resolveElem(i.datatype) != null)
            dataClass = getJavaDataType(i.datatype)
        else {
            dataClass = DataTypeExtension::get(i.datatype).javaType
        }
        if (skipIndex)
            dataClass
        else if (i.isArray != null)
            dataClass + "[]"
        else if (i.isSet != null)
            "Set<" + dataClass + ">"
        else if (i.isList != null)
            "List<" + dataClass + ">"
        else if (i.isMap != null)
            "Map<" + i.isMap.indexType + "," + dataClass + ">"
        else
            dataClass
    }

    def public static boolean isRequired(FieldDefinition i) {
    	// field is explicitly set to optional
    	if (i.required?.x != null) {
    		return i.required.x != XRequired.OPTIONAL
    	}
        var ref = DataTypeExtension::get(i.datatype)
        if (ref.isRequired != null) {
            if (i.required != null && i.required.x != null) {
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
		if (i.required != null)
            return i.required.x	== XRequired::REQUIRED
			
        // neither ref.isRequired is set nor an explicit specification made.  Fall back to defaults of the embedding class or package
		
        // DEBUG
        //if (i.name.equals("fields"))
        //    System::out.println("fields.required = " + i.required + ", defaultreq = " + ref.defaultRequired)
        // if we have an object, it is nullable by default, unless some explicit or
        if (ref.defaultRequired != null)
            return ref.defaultRequired == XRequired::REQUIRED
        else
            return false  // no specification at all means optional
    }

    def public static condText(boolean flag, String text) {
        if (flag) text else ""
    }

    def public static vlr(String text1, String l, String r, String otherwise) {
        if (text1 != null) l + text1 + r else otherwise
    }
    def public static nvl(String text1, String otherwise) {
        if (text1 != null) text1 else otherwise
    }
    def public static nnvl(String text1, String text2, String otherwise) {
        if (text1 != null) text1 else if (text2 != null) text2 else otherwise
    }

    // moved from persistence / YUtil:
    def public static boolean hasProperty(List <PropertyUse> properties, String key) {
        if (properties != null)
            for (p : properties)
                if (key.equals(p.key.name))
                    return true
        return false
    }

    def public static String getProperty(List <PropertyUse> properties, String key) {
        if (properties != null)
            for (p : properties)
                if (key.equals(p.key.name))
                    return p.value
        return null
    }

    // determines if the field is an aggregate type (array / list / map and possibly later additional
    def public static boolean isAggregate(FieldDefinition c) {
        return c.isArray != null || c.isList != null || c.isSet != null || c.isMap != null
    }
    // determines if the field is an aggregate type (array / list / map and possibly later additional
    def public static int aggregateMaxSize(FieldDefinition c) {
        if (c.isArray != null)
            return c.isArray.maxcount
        if (c.isList != null)
            return c.isList.maxcount
        if (c.isSet != null)
            return c.isSet.maxcount
        if (c.isMap != null)
            return c.isMap.maxcount
        0        
    }

    def public static getFieldVisibility(ClassDefinition d, FieldDefinition i) {
        (i.visibility ?: d.defaults?.visibility ?: getPackage(d).defaults?.visibility)?.x ?: XVisibility::DEFAULT
    }

    def public static List<FieldDefinition> allFields(ClassDefinition cl) {
        val result = new ArrayList<FieldDefinition>(50)
        switch ext : cl.extendsClass?.referenceDataType {
        	ClassDefinition :
	        	result.addAll(ext.allFields)
        }
        result.addAll(cl.fields)
        return result
    }

    def public static writeDefaultImports() '''
        import java.util.Arrays;
        import java.util.List;
        import java.util.ArrayList;
        import java.util.regex.Pattern;
        import java.util.regex.Matcher;
        import java.util.GregorianCalendar;
        import java.util.Calendar;
        import java.util.UUID;
        import java.util.HashSet;
        import java.util.LinkedHashSet;
        import java.util.Set;
        import java.util.HashMap;
        import java.util.Map;
        import java.util.concurrent.ConcurrentHashMap;
        import java.util.concurrent.ConcurrentMap;
        import java.math.BigDecimal;
        import de.jpaw.util.EnumException;
        import de.jpaw.util.ByteArray;
        import de.jpaw.util.CharTestsASCII;
        import de.jpaw.util.ToStringHelper;
        import de.jpaw.util.ApplicationException;
        import de.jpaw.util.DayTime;
        import de.jpaw.util.ByteUtil;
        import de.jpaw.util.BigDecimalTools;
        import org.joda.time.LocalDate;
        import org.joda.time.LocalDateTime;
    '''
    
    def public static isASpecialEnumWithEmptyStringAsNull(FieldDefinition f) {
        val ref = DataTypeExtension.get(f.datatype)
        ref.enumMaxTokenLength >= 0 && ref.elementaryDataType.enumType.avalues.map[token].contains("")
    }
    def public static idForEnumTokenNull(FieldDefinition f) {
        val ref = DataTypeExtension.get(f.datatype)
        if (ref.enumMaxTokenLength < 0)
            null
        else
            ref.elementaryDataType.enumType.avalues.findFirst[token.empty]?.name
    }

}
