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

    def private static makeLengthCheck(FieldDefinition i, String fieldname, DataTypeExtension ref) '''
        «IF ref.javaType.equals("String")»
            if («fieldname».length() > «ref.elementaryDataType.length»)
                throw new ObjectValidationException(ObjectValidationException.TOO_LONG,
                                                    "«i.name».length=" + «fieldname».length() + " > «ref.elementaryDataType.length»",
                                                    _PARTIALLY_QUALIFIED_CLASS_NAME);
            «IF ref.elementaryDataType.minLength > 0»
                if («fieldname».length() < «ref.elementaryDataType.minLength»)
                    throw new ObjectValidationException(ObjectValidationException.TOO_SHORT,
                                                        "«i.name».length=" + «fieldname».length() + " < «ref.elementaryDataType.minLength»",
                                                        _PARTIALLY_QUALIFIED_CLASS_NAME);
            «ENDIF»
        «ELSEIF ref.javaType.equals("BigDecimal")»
            BigDecimalTools.validate(«fieldname», meta$$«i.name», _PARTIALLY_QUALIFIED_CLASS_NAME);
        «ENDIF»
    '''

    def private static makePatternCheck(FieldDefinition i, String fieldname, DataTypeExtension ref) '''
        «IF ref.elementaryDataType.regexp !== null»
            Matcher _m =  regexp$«i.name».matcher(«fieldname»);
            if (!_m.find())
                throw new ObjectValidationException(ObjectValidationException.NO_PATTERN_MATCH, "«i.name»", _PARTIALLY_QUALIFIED_CLASS_NAME);
        «ENDIF»
        «IF ref.isUpperCaseOrLowerCaseSpecialType»
            if (!CharTestsASCII.is«IF ref.elementaryDataType.name.toLowerCase.equals("uppercase")»UpperCase«ELSE»LowerCase«ENDIF»(«fieldname»))
                throw new ObjectValidationException(ObjectValidationException.NO_PATTERN_MATCH, "«i.name»", _PARTIALLY_QUALIFIED_CLASS_NAME);
        «ENDIF»
    '''

    def private static writeObjectValidationCode(FieldDefinition i, String fieldname, DataTypeExtension ref) {
        if (ref.category == DataCategory::OBJECT && ref.objectDataType?.externalType === null && !ref.isJsonField) {
            return '''
                «fieldname».validate();
            '''
        }
    }

    /** Writes a condition, but only if it contains actual code to perform. */
    def private static CharSequence nestBlocks(CharSequence optionalCondition, CharSequence optionalWorkToDo) {
        if (optionalWorkToDo === null || optionalWorkToDo.length == 0)
            return null
        else if (optionalCondition !== null)
            return '''
                «optionalCondition»{
                    «optionalWorkToDo»
                }
            '''
        else
            return optionalWorkToDo
    }

    /** Generates a check for the aggregate, if the aggregate is required, and a condition wrapper in case the aggregate is optional. */
    def private static CharSequence writeValidationCodeForSingleField(FieldDefinition i) {
        val isAggregate = i.aggregate
        val isOptionalAggregate = isAggregate && !i.isAggregateRequired
        return '''
            «IF isAggregate && !isOptionalAggregate»
                if («i.name» == null) // initial check for aggregate type itself, it may not be null
                    throw new ObjectValidationException(ObjectValidationException.MAY_NOT_BE_BLANK, "«i.name»", _PARTIALLY_QUALIFIED_CLASS_NAME);
            «ENDIF»
            «nestBlocks(if (isOptionalAggregate) '''if («i.name» != null) ''', i.writeValidationCodeForSingleField2)»
        '''
    }

    /** Writes validation code for a whole aggregate, where the aggregate itself is known not to be null. Invokes field level checks. */
    def private static CharSequence writeValidationCodeForSingleField2(FieldDefinition i) {
        return '''
            «IF i.aggregateMaxSize > 0»
                «i.writeSizeCheck»
            «ENDIF»
            «nestBlocks(loopStart(i, false), i.writeValidationCodeForSingleField3)»
        '''
    }

    /** Writes validation code for a single instance within an aggregate or for a scalar field. */
    def private static CharSequence writeValidationCodeForSingleField3(FieldDefinition i) {
        val ref = DataTypeExtension::get(i.datatype)
        return '''
            «IF i.isRequired && !ref.isPrimitive»
                if («indexedName(i)» == null)
                    throw new ObjectValidationException(ObjectValidationException.MAY_NOT_BE_BLANK, "«i.name»", _PARTIALLY_QUALIFIED_CLASS_NAME);
            «ENDIF»
            «nestBlocks(if (!i.isRequired && !ref.isPrimitive) '''if («indexedName(i)» != null) ''', i.writeValidationCodeForSingleField4(ref))»
        '''
    }

    /** Writes validation code for a single instance within an aggregate or for a scalar field, where the field is known to be not null. */
    def private static CharSequence writeValidationCodeForSingleField4(FieldDefinition i, DataTypeExtension ref) {
        val fieldname = indexedName(i)
        return '''
            «writeObjectValidationCode(i, fieldname, ref)»
            «IF ref.category == DataCategory::STRING || ref.javaType == "BigDecimal"»
                «makeLengthCheck(i, fieldname, ref)»
            «ENDIF»
            «IF resolveElem(i.datatype) !== null && (resolveElem(i.datatype).regexp !== null || ref.isUpperCaseOrLowerCaseSpecialType)»
                «makePatternCheck(i, fieldname, ref)»
            «ENDIF»
        '''
    }

    def public static writeValidationCode(ClassDefinition d) '''
        @Override
        public void validate() throws ObjectValidationException {
            // perform checks for required fields
            «IF d.haveCustomAddons»
                «d.name»Addons.preprocess(this);
            «ENDIF»
            «IF d.extendsClass !== null»
                super.validate();
            «ENDIF»
            «FOR i:d.fields»
                «i.writeValidationCodeForSingleField»
            «ENDFOR»
            «IF d.haveCustomAddons»
                «d.name»Addons.validate(this);
            «ENDIF»
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
