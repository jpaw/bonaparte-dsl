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
    def public static getMediumClassName(ClassDefinition d) {
        (d.eContainer as PackageDefinition).name + "." + d.name  
    }
    
    // convert an Xtend boolean to Java source token
    def public static b2A(boolean f) {
        if (f) "true" else "false"
    }
    
    def public static String getJavaDataType(DataType d) {
        val ref = DataTypeExtension::get(d)
        if (ref.isPrimitive)
            ref.elementaryDataType.name
        // else if (ref.javaType.equals("enum"))    // not required, covered by DatTypeExtension class!
        //    ref.elementaryDataType.enumType.name
        else
            ref.javaType
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

}