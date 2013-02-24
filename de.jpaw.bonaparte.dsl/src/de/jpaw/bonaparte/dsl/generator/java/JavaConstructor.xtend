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

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import de.jpaw.bonaparte.dsl.generator.Separator

/* DISCLAIMER: Validation is work in progress. Neither direct validation nor JSR 303 annotations are complete */

class JavaConstructor {
    def private static allFields(Separator s, ClassDefinition d, boolean withTypes) '''
        «IF d.extendsClass != null && d.extendsClass.classRef != null»
            «allFields(s, d.extendsClass.classRef, withTypes)»
        «ENDIF»
        «FOR i : d.fields»
            «s.current»«IF withTypes»«JavaDataTypeNoName(i, false)» «ENDIF»«i.name»«s.setCurrent(", ")»
        «ENDFOR»
    '''
    
    def private static int countAllFields(ClassDefinition d) {
        var int sum = d.fields.size
        if (d.extendsClass != null && d.extendsClass.classRef != null)
            sum = sum + countAllFields(d.extendsClass.classRef)
        return sum 
    }
    
    def public static writeConstructorCode(Separator s, ClassDefinition d) '''
        // default no-argument constructor
        public «d.name»() {
            «IF d.extendsClass != null && d.extendsClass.classRef != null»
                super();
            «ENDIF»
        }
        
        «IF countAllFields(d) > 0»
            // default all-arguments constructor
            public «d.name»(«s.setCurrent("")»«allFields(s, d, true)») {
                «IF d.extendsClass != null && d.extendsClass.classRef != null»
                    super(«s.setCurrent("")»«allFields(s, d.extendsClass.classRef, false)»);
                «ENDIF»
                «FOR i : d.fields»
                    this.«i.name» = «i.name»;
                «ENDFOR»
            }
        «ENDIF»
     '''
}
