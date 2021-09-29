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
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.Util

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*

class JavaOpenApiOutput {

    def static writeImports() '''
        import io.swagger.v3.oas.annotations.media.Schema;
    '''

    def static writeAnnotations(ClassDefinition d, FieldDefinition i, DataTypeExtension ref, boolean additionalNullableCondition) {
        if (d.package.doSwagger) {
            val b = new StringBuilder
            b.append("@Schema(description=\"");
            if (i.comment !== null) {
                b.append(Util::escapeString2Java(i.comment))
            }
            b.append("\"");

            if (i.isIsDeprecated) {
                b.append(", deprecated=true")
            }

            if (i.aggregate) {
                if (i.isAggregateRequired)
                    b.append(", required=true")
                else
                    b.append(", nullable=true")
                // TODO: min / max entries of list? Is part of swagger schema, but not supported in @Schema annotation currently (version 2.1.10)
            } else {
                if (i.isRequired && !ref.isPrimitive && !i.isASpecialEnumWithEmptyStringAsNull && !additionalNullableCondition)
                    b.append(", required=true")
                else
                    b.append(", nullable=true")
                
                //
                if (ref.elementaryDataType !== null) {
                    val lowercaseName = ref.elementaryDataType.name.toLowerCase()
    //                «IF ref.elementaryDataType.name.toLowerCase().equals("number")»
    //                    @Digits(integer=«ref.elementaryDataType.length», fraction=0)
    //                «ELSEIF ref.elementaryDataType.name.toLowerCase().equals("decimal")»
    //                    @Digits(integer=«ref.elementaryDataType.length - ref.elementaryDataType.decimals», fraction=«ref.elementaryDataType.decimals»)
                    if (ref.javaType.equals("String")) {
                        if (ref.elementaryDataType.minLength > 0) {
                            b.append(", minLength=")
                            b.append(ref.elementaryDataType.minLength);
                        }
                        b.append(", maxLength=");
                        b.append(ref.elementaryDataType.length)

                        if (ref.isUpperCaseOrLowerCaseSpecialType) {
                            b.append(", pattern=\"[");
                            b.append(lowercaseName.equals("uppercase") ? "A-Z" : "a-z")
                            b.append("]*\"");
                        }
    //                    «IF ref.elementaryDataType.regexp !== null»
    //                        @«jakartaPrefix».validation.constraints.Pattern(regexp="\\A«Util::escapeString2Java(ref.elementaryDataType.regexp)»\\z")
    //                    «ENDIF»
                    } else {
                        // check for numeric types
                        switch (lowercaseName) {
                            case 'byte':    addLimits(b, ref, Byte.MAX_VALUE)
                            case 'short':   addLimits(b, ref, Short.MAX_VALUE)
                            case 'int':     addLimits(b, ref, Integer.MAX_VALUE)
                            case 'integer': addLimits(b, ref, Integer.MAX_VALUE)
                            case 'long':    addLimits(b, ref, Long.MAX_VALUE)
                            case 'float':   addPositive(b, ref)
                            case 'double':     addPositive(b, ref)
                            case 'fixedpoint': addPositive(b, ref)
                            case 'decimal':    addPositive(b, ref)
                        }
                    }
                    val ex = i.exampleString ?: i.properties.getProperty(PROP_EXAMPLE)
                    if (ex !== null && ex.length > 0) {
                        b.append(", example=\"")
                        b.append(Util::escapeString2Java(ex))
                        b.append("\"")
                    }
                    if (i.defaultString !== null) {
                        b.append(", defaultValue=\"")
                        b.append(Util::escapeString2Java(i.defaultString))
                        b.append("\"")
                    }
                }
            }

            b.append(")\n")
            return b.toString
        }
        return ""
    }
    
    def private static void addPositive(StringBuilder b, DataTypeExtension ref) {
        if (ref.effectiveSigned) {
            b.append(", minimum=\"0\"")
        }
    }

    def private static void addLimits(StringBuilder b, DataTypeExtension ref, long maxValueByType) {
        val long maxVal = if (ref.elementaryDataType.length == 0) maxValueByType else maxByNumberOfDigits(ref.elementaryDataType.length);
        b.append(", minimum=\"")
        b.append(ref.effectiveSigned ? Long.toString(-maxVal - (ref.elementaryDataType.length == 0 ? 1L : 0L)) : "0")
        b.append("\"")
        b.append(", maximum=\"")
        b.append(Long.toString(maxVal))
        b.append("\"")
    }

    static val maxVals = #[ 0L,
        9L, 99L, 999L, 9_999L, 99_999L, 999_999L,
        9_999_999L, 99_999_999L, 999_999_999L,
        9_999_999_999L, 99_999_999_999L, 999_999_999_999L,
        9_999_999_999_999L, 99_999_999_999_999L, 999_999_999_999_999L,
        9_999_999_999_999_999L, 99_999_999_999_999_999L, 999_999_999_999_999_999L
    ];

    def static long maxByNumberOfDigits(int digits) {
        return maxVals.get(digits)
    }
}
