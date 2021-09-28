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
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.Util

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition

class JavaOpenApiOutput {

    def static writeImports() '''
        import io.swagger.v3.oas.annotations.Schema;
    '''

    def static writeAnnotations(ClassDefinition d, FieldDefinition i, DataTypeExtension ref, boolean additionalNullableCondition) {
        if (d.package.doSwagger) {
            val b = new StringBuilder
            b.append("@Schema(description=\"");
            b.append(Util::escapeString2Java(i.javadoc))
            b.append("\"");
            
            if (i.isIsDeprecated) {
                b.append(", deprecated=true")
            }

            if (i.isRequired && !ref.isPrimitive && !i.isASpecialEnumWithEmptyStringAsNull && !additionalNullableCondition)
                b.append(", required=true")
            else
                b.append(", nullable=true")
            
            //
            if (ref.elementaryDataType !== null && !i.aggregate) {
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
                        b.append(ref.elementaryDataType.name.toLowerCase().equals("uppercase") ? "A-Z" : "a-z")
                        b.append("]*\"");
                    }
//                    «IF ref.elementaryDataType.regexp !== null»
//                        @«jakartaPrefix».validation.constraints.Pattern(regexp="\\A«Util::escapeString2Java(ref.elementaryDataType.regexp)»\\z")
//                    «ENDIF»
                    val ex = i.properties.getProperty(PROP_EXAMPLE)
                    if (ex !== null && ex.length > 0) {
                        b.append(", example=\"")
                        b.append(Util::escapeString2Java(ex))
                        b.append("\"")
                    }
                }
            }
            
            b.append(")\n")
            return b.toString
        }
        return ""
    }
}
