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

class XUtil {
    def public static ClassDefinition getParent(ClassDefinition d) {
        if (d == null || d.getExtendsClass == null)
            return null;
        d.getExtendsClass.getClassRef
    }

    def public static ClassDefinition getRoot(ClassDefinition d) {
        var dd = d
        while (getParent(dd) != null)
            dd = getParent(dd)
        return dd
    }
    
    def public static boolean isImmutable(ClassDefinition d) {
        return getRoot(d).immutable
    }
    
    def public static String genericRef2String(ClassReference r) {
        if (r.plainObject)
            return "BonaPortable"
        if (r.genericsParameterRef != null)
            return r.genericsParameterRef.name
        if (r.classRef != null)
            return r.classRef.name + genericArgs2String(r.classRefGenericParms)
        return "*** FIXME: class reference with all null fields ***"        
    }
    
    def public static genericArgs2String(List<ClassReference> args) {
        if (args == null)
            return ""
        '''«FOR a : args BEFORE '<' SEPARATOR ', ' AFTER '>'»«genericRef2String(a)»«ENDFOR»'''        
    }
    
    def public static genericDef2String(List<GenericsDef> args) {
        if (args == null)
            return ""
        '''«FOR a : args BEFORE '<' SEPARATOR ', ' AFTER '>'»«a.name»«IF a.^extends != null» extends «genericRef2String(a.^extends)»«ENDIF»«ENDFOR»'''        
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
    // Utility methods
    def public static getPartiallyQualifiedClassName(ClassDefinition d) {
        JavaPackages::getPackage(d).name + "." + d.name  
    }
    // create a serialVersionUID which depends on class name and revision, plus the same for any parent classes only
    def public static long getSerialUID(ClassDefinition d) {
        var long myUID = getPartiallyQualifiedClassName(d).hashCode()
        if (d.revision != null)
            myUID = 97L * myUID + d.revision.hashCode()
        if (d.extendsClass != null && d.extendsClass.classRef != null)
            myUID = 131L * myUID + getSerialUID(d.extendsClass.classRef)   // recurse parent classes
        return myUID
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
        if (i.isList != null) "_i" else i.name + (if (i.isArray != null) "[_i]" else "")
    }
    
    def public static loopStart(FieldDefinition i) '''
        «IF i.isArray != null»
            if («i.name» != null)
                for (int _i = 0; _i < «i.name».length; ++_i)
        «ELSEIF i.isList != null»
            if («i.name» != null)
                for («JavaDataTypeNoName(i, true)» _i : «i.name»)
        «ENDIF»
        '''
        
    def public static String getJavaDataType(DataType d) {
        val ref = DataTypeExtension::get(d)
        if (ref.isPrimitive)
            ref.elementaryDataType.name
        else
            ref.javaType
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
        else if (i.isList != null)
            "List<" + dataClass + ">" 
        else
            dataClass
    }
    
    def public static isRequired(FieldDefinition i) {
        var ref = DataTypeExtension::get(i.datatype)
        if (ref.elementaryDataType != null && !ref.wasUpperCase)
            return true  // TODO: this could be a contradiction to an "optional" specification. Are the validators complete?

        // DEBUG
        //if (i.name.equals("fields"))
        //    System::out.println("fields.required = " + i.required + ", defaultreq = " + ref.defaultRequired)
        // if we have an object, it is nullable by default, unless some explicit or
        var XRequired req = if (i.required != null) i.required.x else ref.defaultRequired
        if (req != null)
            return req == XRequired::REQUIRED
        else
            return false
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
}