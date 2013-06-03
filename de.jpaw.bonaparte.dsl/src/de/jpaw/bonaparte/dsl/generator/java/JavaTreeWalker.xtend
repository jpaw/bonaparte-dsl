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
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.DataCategory
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension

import static de.jpaw.bonaparte.dsl.generator.XUtil.*

class JavaTreeWalker {
    
    def public static writeTreeWalkerCode(ClassDefinition d) '''
        @Override
        public void treeWalkString(StringConverter _cvt) {
            «IF d.extendsClass != null»
                super.treeWalkString(_cvt);
            «ENDIF»
            «FOR i:d.fields»
                «treeWalkSub(d, i, DataTypeExtension::get(i.datatype))»
            «ENDFOR»
        }
     '''
     
     def private static treeWalkSub(ClassDefinition d, FieldDefinition i, DataTypeExtension ref) {
         if (ref.category == DataCategory::STRING) {
             // String field, which must be processed. This still can be a List or an Array
             if (i.isArray != null)
                return '''«i.name» = _cvt.convertArray(«i.name», meta$$«i.name»);'''
             if (i.isList != null)
                return '''«i.name» = _cvt.convertList(«i.name», meta$$«i.name»);'''
             if (i.isSet != null)
                return '''«i.name» = _cvt.convertSet(«i.name», meta$$«i.name»);'''
             if (i.isMap != null)
                return '''«i.name» = _cvt.convertMap(«i.name», meta$$«i.name»);'''
             return '''«i.name» = _cvt.convert(«i.name», meta$$«i.name»);'''
         }
         if (ref.category == DataCategory::OBJECT) {
             // subobjects. Here we run through the list or array, and invoke the method on any sub-object
             return '''
                «loopStart(i)»
                if («indexedName(i)» != null)
                    «indexedName(i)».treeWalkString(_cvt);
             '''
         }
         // else nothing to do
         return ''''''
     }
}