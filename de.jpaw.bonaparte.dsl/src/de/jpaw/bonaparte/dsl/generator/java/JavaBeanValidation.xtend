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
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.Util

/* DISCLAIMER: Bean Validation is work in progress. Neither JSR 303 nor JSR 349 annotations are complete. */

class JavaBeanValidation {

    def public static writeImports(boolean beanValidation) '''
        «IF beanValidation»
            import javax.validation.constraints.NotNull;
            import javax.validation.constraints.Digits;
            import javax.validation.constraints.Size;
            //import javax.validation.constraints.Pattern;  // conflicts with java.util.regexp.Pattern, use FQON instead
        «ENDIF»
    '''

    def public static writeAnnotations(FieldDefinition i, DataTypeExtension ref, boolean beanValidation, boolean additionalNullableCondition) '''
        «IF beanValidation»
            «IF i.isRequired && !ref.isPrimitive && !i.isASpecialEnumWithEmptyStringAsNull && !additionalNullableCondition»
                @NotNull
            «ENDIF»
            «IF ref.elementaryDataType !== null && !i.aggregate»
                «IF ref.elementaryDataType.name.toLowerCase().equals("number")»
                    @Digits(integer=«ref.elementaryDataType.length», fraction=0)
                «ELSEIF ref.elementaryDataType.name.toLowerCase().equals("decimal")»
                    @Digits(integer=«ref.elementaryDataType.length - ref.elementaryDataType.decimals», fraction=«ref.elementaryDataType.decimals»)
                «ELSEIF ref.javaType.equals("String")»
                    @Size(«IF ref.elementaryDataType.minLength > 0»min=«ref.elementaryDataType.minLength», «ENDIF»max=«ref.elementaryDataType.length»)
                    «IF ref.isUpperCaseOrLowerCaseSpecialType»
                        @javax.validation.constraints.Pattern(regexp="\\A[«IF ref.elementaryDataType.name.toLowerCase().equals("uppercase")»A-Z«ELSE»a-z«ENDIF»]*\\z")
                    «ENDIF»
                    «IF ref.elementaryDataType.regexp !== null»
                        @javax.validation.constraints.Pattern(regexp="\\A«Util::escapeString2Java(ref.elementaryDataType.regexp)»\\z")
                    «ENDIF»
                «ENDIF»
            «ENDIF»
        «ENDIF»
    '''

}
