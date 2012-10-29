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
import static extension de.jpaw.persistence.dsl.generator.java.ZUtil.*

class ZUtil {
    
    def public static recurseDataGetter(ClassDefinition d, ClassDefinition stopper) '''
        «IF d != stopper»
            «d.extendsClass?.classRef?.recurseDataGetter(stopper)»
            // auto-generated data getter for «d.name»
            «FOR i:d.fields»
                _r.set«Util::capInitial(i.name)»(get«Util::capInitial(i.name)»());
            «ENDFOR»
        «ENDIF»
    '''
    
    def public static recurseDataSetter(ClassDefinition d, ClassDefinition stopper) '''
        «IF d != stopper»
            «d.extendsClass?.classRef?.recurseDataSetter(stopper)»
            // auto-generated data setter for «d.name»
            «FOR i:d.fields»
                set«Util::capInitial(i.name)»(_d.get«Util::capInitial(i.name)»());
            «ENDFOR»
        «ENDIF»
    '''
}
