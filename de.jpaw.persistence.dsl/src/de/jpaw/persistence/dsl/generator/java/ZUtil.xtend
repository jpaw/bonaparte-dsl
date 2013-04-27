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

package de.jpaw.persistence.dsl.generator.java

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.generator.Util
import static extension de.jpaw.persistence.dsl.generator.YUtil.*
import static extension de.jpaw.persistence.dsl.generator.java.ZUtil.*      // required for batch compile?
import de.jpaw.persistence.dsl.bDDL.EntityDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition

class ZUtil {
    
    def public static CharSequence recurseDataGetter(ClassDefinition d, ClassDefinition stopper) '''
        «IF d != stopper»
            «d.extendsClass?.classRef?.recurseDataGetter(stopper)»
            // auto-generated data getter for «d.name»
            «FOR i:d.fields»
                «IF !hasProperty(i.properties, "noJava")»
                    _r.set«Util::capInitial(i.name)»(get«Util::capInitial(i.name)»());
                «ENDIF»
            «ENDFOR»
        «ENDIF»
    '''
    
    def public static CharSequence recurseDataSetter(ClassDefinition d, ClassDefinition stopper, EntityDefinition avoidKeyOf) '''
        «IF d != stopper»
            «d.extendsClass?.classRef?.recurseDataSetter(stopper, avoidKeyOf)»
            // auto-generated data setter for «d.name»
            «FOR i:d.fields»
                «IF (avoidKeyOf == null || !isKeyField(avoidKeyOf, i)) && !hasProperty(i.properties, "noJava")»
                    set«Util::capInitial(i.name)»(_d.get«Util::capInitial(i.name)»());
                «ENDIF»
            «ENDFOR»
        «ENDIF»
    '''
    
    def public static isKeyField(EntityDefinition e, FieldDefinition f) {
        if (e.pk != null) {
            for (FieldDefinition i: e.pk.columnName) {
                if (i == f)
                    return true
            }
        }
        return false
    }
}
