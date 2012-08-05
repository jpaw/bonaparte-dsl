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

package de.jpaw.bonaparte.dsl.generator.java

import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.XVisibility
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.Util

class JavaFieldsGettersSetters {
    
    def private static JavaDataTypeNoName(FieldDefinition i) {
        var String dataClass
        //fieldDebug(i)
        if (resolveElem(i.datatype) != null)
            dataClass = getJavaDataType(i.datatype)
        else {
            if (resolveObj(i.datatype) == null)
                throw new RuntimeException("INTERNAL ERROR object type not set for field of type object for " + i.name);
            dataClass = resolveObj(i.datatype).name
        }
        if (i.isArray != null)
            // dataClass + "[" + (if (i.isArray.maxcount > 0) i.isArray.maxcount) + "]" 
            dataClass + "[]" 
        else
            dataClass
    }

    def private static makeVisbility(FieldDefinition i) {
        var XVisibility fieldScope = DataTypeExtension::get(i.datatype).visibility
        if (fieldScope == null || fieldScope == XVisibility::DEFAULT)
            ""
        else
            fieldScope.toString() + " " 
    } 
    

    def public static writeFields(ClassDefinition d) '''
            // fields
            «FOR i:d.fields»
                «makeVisbility(i)»«JavaDataTypeNoName(i)» «i.name»;
                public «JavaDataTypeNoName(i)» get«Util::capInitial(i.name)»() {
                    return «i.name»;
                }
                public void set«Util::capInitial(i.name)»(«JavaDataTypeNoName(i)» «i.name») {
                    this.«i.name» = «i.name»;
                }
            «ENDFOR»
    '''
}