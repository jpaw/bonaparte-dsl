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

import de.jpaw.bonaparte.dsl.generator.Util
import de.jpaw.persistence.dsl.bDDL.EntityDefinition
import static extension de.jpaw.persistence.dsl.generator.java.ZUtil.*

import static de.jpaw.bonaparte.dsl.generator.XUtil.*

import static extension de.jpaw.persistence.dsl.generator.YUtil.*

class MakeMapper {
    def public static writeMapperMethods(EntityDefinition e, String pkType, String trackingType) '''
        @Override
        public String get$DataPQON() {
            return "«getPartiallyQualifiedClassName(e.pojoType)»";
        }
        @Override
        public Class<? extends «e.getInheritanceRoot.pojoType.name»> get$DataClass() {
            return «e.pojoType.name».class;
        }
        «IF e.^extends == null»
        public static Class<«e.pojoType.name»> class$DataClass() {
            return «e.pojoType.name».class;
        }
        public static String class$DataPQON() {
            return "«getPartiallyQualifiedClassName(e.pojoType)»";
        }
        «ENDIF»
        @Override
        public «e.pojoType.name» get$Data() throws ApplicationException {
            «e.pojoType.name» _r = new «e.pojoType.name»();
            «recurseDataGetter(e.pojoType, null)»
            return _r;
        }
        @Override
        public void set$Data(«e.getInheritanceRoot.pojoType.name» _d) {
            «IF e.^extends == null»
                «recurseDataSetter(e.pojoType, null, e)»
            «ELSE»
                super.set$Data(_d);
                if (_d instanceof «e.pojoType.name») {
                    «e.pojoType.name» _dd = («e.pojoType.name»)_d;
                    // auto-generated data setter for «e.pojoType.name»
                    «FOR i:e.pojoType.fields»
                        set«Util::capInitial(i.name)»(_dd.get«Util::capInitial(i.name)»());
                    «ENDFOR»
                }
            «ENDIF»
        }
    '''
}