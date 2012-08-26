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

import de.jpaw.bonaparte.dsl.bonScript.ElementaryDataType
import de.jpaw.bonaparte.dsl.bonScript.DataType
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.bonScript.XRequired

class XUtil {
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
        (d.eContainer as PackageDefinition).name + "." + d.name  
    }
    // create a serialVersionUID which depends on class name and revision, plus the same for any parent classes only
    def public static getSerialUID(ClassDefinition d) {
        var long myUID = getPartiallyQualifiedClassName(d).hashCode()
        if (d.revision != null)
            myUID = 97L * myUID + d.revision.hashCode()
        if (d.extendsClass != null)
            myUID = 131L * myUID + getSerialUID(d.extendsClass)   // recurse parent classes
        return myUID
    }
    
    // convert an Xtend boolean to Java source token
    def public static b2A(boolean f) {
        if (f) "true" else "false"
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
        // else if (ref.javaType.equals("enum"))    // not required, covered by DatTypeExtension class!
        //    ref.elementaryDataType.enumType.name
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
            if (resolveObj(i.datatype) == null)
                throw new RuntimeException("INTERNAL ERROR object type not set for field of type object for " + i.name);
            dataClass = resolveObj(i.datatype).name
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