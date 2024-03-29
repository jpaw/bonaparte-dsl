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
import java.util.function.Predicate

class JavaTreeWalker {

    def public static writeTreeWalkerCode(ClassDefinition d) '''
        «d.writeGenericTreeWalkerCode("String",       "AlphanumericElementaryDataItem", true, [ category == DataCategory::STRING ])»
        «d.writeGenericTreeWalkerCode("BonaPortable", "ObjectReference",                false, [ category == DataCategory::OBJECT ])»
        «d.writeGenericTreeWalkerCode("Object",       "FieldDefinition",                false, [ true ])»
    '''

    def private static writeGenericTreeWalkerCode(ClassDefinition d, String javaType, String metadataType, boolean doAssign, Predicate<DataTypeExtension> decision) '''
        @Override
        public void treeWalk«javaType»(DataConverter<«javaType», «metadataType»> _cvt, boolean _descend) {
            «IF d.extendsClass !== null»
                super.treeWalk«javaType»(_cvt, _descend);
            «ENDIF»
            «FOR i:d.fields»
                «treeWalkSub(d, i, DataTypeExtension::get(i.datatype), javaType, doAssign, decision)»
            «ENDFOR»
        }
     '''

     def private static treeWalkSub(ClassDefinition d, FieldDefinition i, DataTypeExtension ref, String javaType, boolean doAssign, Predicate<DataTypeExtension> decision) {
         if (ref.objectDataType?.externalType !== null) // skip external types for all tree walk methods
            return null
         if (isJsonField(ref))
            return null
         if (decision.test(ref)) {
             val target = if (doAssign) i.name + " = ";
             // field which must be processed. This still can be a List or an Array
             // for types as Object or BonaPortable, which are not final, we need type casts!
             if (i.isArray !== null) {
                // special: cannot work on arrays of primitive types, they are not objects
                if (ref.isPrimitive)
                    return '''// skipping array of primitive type for «i.name»'''
                return '''«target»_cvt.convertArray(«i.name», meta$$«i.name»);'''
             }
             if (i.isList !== null)
                return '''«target»_cvt.convertList(«IF !doAssign»(List)«ENDIF»«i.name», meta$$«i.name»);'''
             if (i.isSet !== null)
                return '''«target»_cvt.convertSet(«IF !doAssign»(Set)«ENDIF»«i.name», meta$$«i.name»);'''
             if (i.isMap !== null)
                return '''«target»_cvt.convertMap(«IF !doAssign»(Map)«ENDIF»«i.name», meta$$«i.name»);'''
             return '''«target»_cvt.convert(«i.name», meta$$«i.name»);'''
         }
         if (ref.category == DataCategory::OBJECT && !isJsonField(ref)) {
             // subobjects. Here we run through the list or array, and invoke the method on any sub-object
             return '''
                 if (_descend) {
                     «loopStart(i, true)»if («indexedName(i)» != null)
                         «indexedName(i)».treeWalk«javaType»(_cvt, _descend);
                 }
             '''
         }
         // else nothing to do
         return ''''''
     }
}
