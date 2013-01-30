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
import de.jpaw.bonaparte.dsl.bonScript.XVisibility
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.Util

class JavaFieldsGettersSetters {

    // this one does not work. Why not?
    def private static doubleEscapes(String in) {
        var StringBuilder out = new StringBuilder(2 * in.length)
        var int i = 0
        while (i < in.length) {
            var c = in.charAt(i)
            if (c == '\\')
                out.append("\\\\")
            else
                out.append(c)
            i = i+1
        }
        return out    
    }
    
    def private static makeVisbility(FieldDefinition i) {
        var XVisibility fieldScope = DataTypeExtension::get(i.datatype).visibility
        if (i.visibility != null && i.visibility.x != null)
            fieldScope = i.visibility.x
        if (fieldScope == null || fieldScope == XVisibility::DEFAULT)
            ""
        else
            fieldScope.toString() + " " 
    } 
    
    def private static writeDefaultValue(FieldDefinition i, DataTypeExtension ref) {
        if (i.defaultString == null)
            ''''''
        else    
            if (ref.javaType.equals("String"))
                ''' = "«Util::escapeString2Java(i.defaultString)»"'''
            else
                ''' = «i.defaultString»'''
    }
    
    def private static writeOneField(ClassDefinition d, FieldDefinition i, boolean doBeanVal) {
        val ref = DataTypeExtension::get(i.datatype)
        
        return '''
            «IF i.comment != null»
                // «i.comment» !
            «ENDIF»
            «IF i.javadoc != null»
                «i.javadoc»
            «ENDIF»        
            «IF doBeanVal»
                «IF i.isRequired && !ref.isPrimitive»
                    @NotNull
                «ENDIF»
                «IF ref.elementaryDataType != null && i.isArray == null && i.isList == null»
                    «IF ref.elementaryDataType.name.toLowerCase().equals("number")»
                        @Digits(integer=«ref.elementaryDataType.length», fraction=0)
                    «ELSEIF ref.elementaryDataType.name.toLowerCase().equals("decimal")»
                        @Digits(integer=«ref.elementaryDataType.length - ref.elementaryDataType.decimals», fraction=«ref.elementaryDataType.decimals»)
                    «ELSEIF ref.javaType.equals("String")»
                        @Size(«IF ref.elementaryDataType.minLength > 0»min=«ref.elementaryDataType.minLength», «ENDIF»max=«ref.elementaryDataType.length»)
                        «IF ref.isUpperCaseOrLowerCaseSpecialType»
                            @javax.validation.constraints.Pattern(regexp="\\A[«IF ref.elementaryDataType.name.toLowerCase().equals("uppercase")»A-Z«ELSE»a-z«ENDIF»]*\\z")
                        «ENDIF»
                        «IF ref.elementaryDataType.regexp != null»
                            @javax.validation.constraints.Pattern(regexp="\\A«doubleEscapes(ref.elementaryDataType.regexp)»\\z")
                        «ENDIF»
                    «ENDIF»
                «ENDIF»
            «ENDIF»
            «makeVisbility(i)»«JavaDataTypeNoName(i, false)» «i.name»«writeDefaultValue(i, ref)»;
        '''
    }
   
    // TODO: Setters might need to check string max length, and also clone for (Gregorian)Calendar and byte arrays?
    def public static writeFields(ClassDefinition d, boolean doBeanVal) '''
        // fields as defined in DSL
        «FOR i:d.fields»
            «writeOneField(d, i, doBeanVal)»
        «ENDFOR»
    '''
                
    def public static writeGettersSetters(ClassDefinition d) '''
        // auto-generated getters and setters 
        «FOR i:d.fields»
            public «JavaDataTypeNoName(i, false)» get«Util::capInitial(i.name)»() {
                return «i.name»;
            }
            public void set«Util::capInitial(i.name)»(«JavaDataTypeNoName(i, false)» «i.name») {
                this.«i.name» = «i.name»;
            }
        «ENDFOR»
    '''
}