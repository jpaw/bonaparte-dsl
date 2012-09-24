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
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension

/* DISCLAIMER: Validation is work in progress. Neither direct validation nor JSR 303 annotations are complete */

class JavaValidate {
    
    def public static writePatterns(ClassDefinition d) '''
        // regexp patterns. TODO: add check for uniqueness
        «FOR i: d.fields»
            «IF resolveElem(i.datatype) != null && resolveElem(i.datatype).regexp != null»
                private static final Pattern regexp$«i.name» = Pattern.compile("\\A«resolveElem(i.datatype).regexp»\\z");
            «ENDIF»
        «ENDFOR»
    '''

    def private static makeLengthCheck(FieldDefinition i, String index, DataTypeExtension ref) '''
        «IF !ref.isPrimitive»if («index» != null) «ENDIF»{
            «IF ref.javaType.equals("String")»
                if («index».length() > «ref.elementaryDataType.length»)
                    throw new ObjectValidationException(ObjectValidationException.TOO_LONG,
                                                        "«index».length=" + «index».length() + " > «ref.elementaryDataType.length»",
                                                        PARTIALLY_QUALIFIED_CLASS_NAME);
                «IF ref.elementaryDataType.minLength > 0»
                    if («index».length() < «ref.elementaryDataType.minLength»)
                        throw new ObjectValidationException(ObjectValidationException.TOO_SHORT,
                                                            "«index».length=" + «index».length() + " < «ref.elementaryDataType.minLength»",
                                                            PARTIALLY_QUALIFIED_CLASS_NAME);
                «ENDIF»
            «ENDIF»
        }
    '''
            
    def private static makePatternCheck(FieldDefinition i, String index, DataTypeExtension ref) '''
        «IF !ref.isPrimitive»if («index» != null) «ENDIF»{
            «IF ref.elementaryDataType.regexp != null» 
                Matcher _m =  regexp$«i.name».matcher(«index»);
                if (!_m.find())
                    throw new ObjectValidationException(ObjectValidationException.NO_PATTERN_MATCH,
                                                        "«index»", PARTIALLY_QUALIFIED_CLASS_NAME);
            «ENDIF»
            «IF ref.isUpperCaseOrLowerCaseSpecialType»
                if (!CharTestsASCII.is«IF ref.elementaryDataType.name.toLowerCase.equals("uppercase")»UpperCase«ELSE»LowerCase«ENDIF»(«index»))
                    throw new ObjectValidationException(ObjectValidationException.NO_PATTERN_MATCH,
                                                        "«index»", PARTIALLY_QUALIFIED_CLASS_NAME);
            «ENDIF»
        }
    '''

    def private static makeValidate(FieldDefinition i, String index) '''
        «IF i.isRequired»
            «index».validate();      // check object (!= null checked before)
        «ELSE»
            if («index» != null)
                «index».validate();  // check object
        «ENDIF»
    '''
    
    def public static writeValidationCode(ClassDefinition d) '''
        // TODO: validation is still work in progress and must be extensively redesigned
        @Override
        public void validate() throws ObjectValidationException {
            // perform checks for required fields
            «IF d.extendsClass != null»
                super.validate();
            «ENDIF»
            «FOR i:d.fields»
                «IF i.isRequired && !DataTypeExtension::get(i.datatype).isPrimitive»
                    «loopStart(i)»
                    if («indexedName(i)» == null)
                        throw new ObjectValidationException(ObjectValidationException.MAY_NOT_BE_BLANK,
                                                    "«indexedName(i)»", PARTIALLY_QUALIFIED_CLASS_NAME);
                «ENDIF»
                «IF resolveObj(i.datatype) != null»
                    «loopStart(i)»
                    «makeValidate(i, indexedName(i))»
                «ENDIF»
            «ENDFOR»
            «FOR i:d.fields»
                «IF resolveElem(i.datatype) != null && DataTypeExtension::get(i.datatype).javaType.equals("String")»
                    «loopStart(i)»
                    «makeLengthCheck(i, indexedName(i), DataTypeExtension::get(i.datatype))»
                «ENDIF»
                «IF resolveElem(i.datatype) != null && (resolveElem(i.datatype).regexp != null || DataTypeExtension::get(i.datatype).isUpperCaseOrLowerCaseSpecialType)»
                    «loopStart(i)»
                    «makePatternCheck(i, indexedName(i), DataTypeExtension::get(i.datatype))»
                «ENDIF»
            «ENDFOR»
        }
    '''
}