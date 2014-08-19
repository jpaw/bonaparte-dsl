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
import de.jpaw.bonaparte.dsl.generator.DataCategory
import de.jpaw.bonaparte.dsl.generator.Util

/* DISCLAIMER: Validation is work in progress. Neither direct validation nor JSR 303 annotations are complete */

class JavaValidate {

    def public static writePatterns(ClassDefinition d) '''
        «FOR i: d.fields»
            «IF resolveElem(i.datatype) !== null && resolveElem(i.datatype).regexp !== null»
                private static final Pattern regexp$«i.name» = Pattern.compile("\\A«Util::escapeString2Java(resolveElem(i.datatype).regexp)»\\z");
            «ENDIF»
        «ENDFOR»
    '''

    def private static makeLengthCheck(FieldDefinition i, String index, DataTypeExtension ref) '''
        «IF !ref.isPrimitive»if («index» != null) «ENDIF»{
            «IF ref.javaType.equals("String")»
                if («index».length() > «ref.elementaryDataType.length»)
                    throw new ObjectValidationException(ObjectValidationException.TOO_LONG,
                                                        "«i.name».length=" + «index».length() + " > «ref.elementaryDataType.length»",
                                                        _PARTIALLY_QUALIFIED_CLASS_NAME);
                «IF ref.elementaryDataType.minLength > 0»
                    if («index».length() < «ref.elementaryDataType.minLength»)
                        throw new ObjectValidationException(ObjectValidationException.TOO_SHORT,
                                                            "«i.name».length=" + «index».length() + " < «ref.elementaryDataType.minLength»",
                                                            _PARTIALLY_QUALIFIED_CLASS_NAME);
                «ENDIF»
            «ELSEIF ref.javaType.equals("BigDecimal")»
                BigDecimalTools.validate(«index», meta$$«i.name», _PARTIALLY_QUALIFIED_CLASS_NAME);
            «ENDIF»
        }
    '''

    def private static makePatternCheck(FieldDefinition i, String index, DataTypeExtension ref) '''
        «IF !ref.isPrimitive»if («index» != null) «ENDIF»{
            «IF ref.elementaryDataType.regexp !== null»
                Matcher _m =  regexp$«i.name».matcher(«index»);
                if (!_m.find())
                    throw new ObjectValidationException(ObjectValidationException.NO_PATTERN_MATCH, "«i.name»", _PARTIALLY_QUALIFIED_CLASS_NAME);
            «ENDIF»
            «IF ref.isUpperCaseOrLowerCaseSpecialType»
                if (!CharTestsASCII.is«IF ref.elementaryDataType.name.toLowerCase.equals("uppercase")»UpperCase«ELSE»LowerCase«ENDIF»(«index»))
                    throw new ObjectValidationException(ObjectValidationException.NO_PATTERN_MATCH, "«i.name»", _PARTIALLY_QUALIFIED_CLASS_NAME);
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
        @Override
        public void validate() throws ObjectValidationException {
            // perform checks for required fields
            «IF d.haveCustomValidator»
                if («d.name»Validator.validate(this))
                    return;
            «ENDIF»
            «IF d.extendsClass !== null»
                super.validate();
            «ENDIF»
            «FOR i:d.fields»
                «IF i.aggregate && i.isAggregateRequired»
                    if («i.name» == null)   // initial check for aggregate type itself, it may not be NULL
                        throw new ObjectValidationException(ObjectValidationException.MAY_NOT_BE_BLANK,
                                                    "«i.name»", _PARTIALLY_QUALIFIED_CLASS_NAME);
                «ENDIF»
                «IF i.isRequired && !DataTypeExtension::get(i.datatype).isPrimitive»
                    «loopStart(i)»
                    if («indexedName(i)» == null)
                        throw new ObjectValidationException(ObjectValidationException.MAY_NOT_BE_BLANK,
                                                    "«i.name»", _PARTIALLY_QUALIFIED_CLASS_NAME);
                «ENDIF»
                «IF i.aggregateMaxSize > 0»
                    «IF !i.isAggregateRequired»
                        if («i.name» != null) {
                            «i.writeSizeCheck»
                        }
                    «ELSE»
                        «i.writeSizeCheck»
                    «ENDIF»
                «ENDIF»
                «IF DataTypeExtension::get(i.datatype).category == DataCategory::OBJECT»
                    «loopStart(i)»
                    «makeValidate(i, indexedName(i))»
                «ENDIF»
            «ENDFOR»
            «FOR i:d.fields»
                «IF DataTypeExtension::get(i.datatype).category == DataCategory::STRING || DataTypeExtension::get(i.datatype).javaType == "BigDecimal"»
                    «loopStart(i)»
                    «makeLengthCheck(i, indexedName(i), DataTypeExtension::get(i.datatype))»
                «ENDIF»
                «IF resolveElem(i.datatype) !== null && (resolveElem(i.datatype).regexp !== null || DataTypeExtension::get(i.datatype).isUpperCaseOrLowerCaseSpecialType)»
                    «loopStart(i)»
                    «makePatternCheck(i, indexedName(i), DataTypeExtension::get(i.datatype))»
                «ENDIF»
            «ENDFOR»
        }
    '''

    
    def private static writeSizeCheck(FieldDefinition i) {
        if (i.isArray !== null) '''
            «IF i.isArray.mincount > 0»
                if («i.name».length < «i.isArray.mincount»)
                    throw new ObjectValidationException(ObjectValidationException.NOT_ENOUGH_ELEMENTS, "«i.name»: «i.isArray.mincount», " + «i.name».length, _PARTIALLY_QUALIFIED_CLASS_NAME);
                if («i.name».length > «i.isArray.maxcount»)
                    throw new ObjectValidationException(ObjectValidationException.TOO_MANY_ELEMENTS, "«i.name»: «i.isArray.maxcount», " + «i.name».length, _PARTIALLY_QUALIFIED_CLASS_NAME);
            «ENDIF»
        ''' else if (i.isList !== null) '''
            «IF i.isList.mincount > 0»
                if («i.name».size() < «i.isList.mincount»)
                    throw new ObjectValidationException(ObjectValidationException.NOT_ENOUGH_ELEMENTS, "«i.name»: «i.isList.mincount», " + «i.name».size(), _PARTIALLY_QUALIFIED_CLASS_NAME);
                if («i.name».size() > «i.isList.maxcount»)
                    throw new ObjectValidationException(ObjectValidationException.TOO_MANY_ELEMENTS, "«i.name»: «i.isList.maxcount», " + «i.name».size(), _PARTIALLY_QUALIFIED_CLASS_NAME);
            «ENDIF»
        ''' else if (i.isSet !== null) '''
            «IF i.isSet.mincount > 0»
                if («i.name».size() < «i.isSet.mincount»)
                    throw new ObjectValidationException(ObjectValidationException.NOT_ENOUGH_ELEMENTS, "«i.name»: «i.isSet.mincount», " + «i.name».size(), _PARTIALLY_QUALIFIED_CLASS_NAME);
                if («i.name».size() > «i.isSet.maxcount»)
                    throw new ObjectValidationException(ObjectValidationException.TOO_MANY_ELEMENTS, "«i.name»: «i.isSet.maxcount», " + «i.name».size(), _PARTIALLY_QUALIFIED_CLASS_NAME);
            «ENDIF»
        ''' else if (i.isMap !== null) '''
            «IF i.isMap.mincount > 0»
                if («i.name».size() < «i.isMap.mincount»)
                    throw new ObjectValidationException(ObjectValidationException.NOT_ENOUGH_ELEMENTS, "«i.name»: «i.isMap.mincount», " + «i.name».size(), _PARTIALLY_QUALIFIED_CLASS_NAME);
                if («i.name».size() > «i.isMap.maxcount»)
                    throw new ObjectValidationException(ObjectValidationException.TOO_MANY_ELEMENTS, "«i.name»: «i.isMap.maxcount», " + «i.name».size(), _PARTIALLY_QUALIFIED_CLASS_NAME);
            «ENDIF»
        ''' else ''''''
    }
}
