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
import de.jpaw.bonaparte.dsl.bonScript.XVisibility
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.Util

import static de.jpaw.bonaparte.dsl.generator.XUtil.*

class JavaFieldsGettersSetters {

    def private static writeDefaultValue(FieldDefinition i, DataTypeExtension ref) {
        if (i.defaultString == null)
            ''''''
        else
            if (ref.javaType.equals("String"))
                ''' = "«Util::escapeString2Java(i.defaultString)»"'''
            else
                ''' = «i.defaultString»'''
    }

    // output regular as well as Javadoc style comments
    def public static writeFieldComments(FieldDefinition i) '''
        «IF i.comment != null»
            // «i.comment» !
        «ENDIF»
        «IF i.javadoc != null»
            «i.javadoc»
        «ENDIF»
    '''

    def private static writeOneField(ClassDefinition d, FieldDefinition i, boolean doBeanVal) {
        val ref = DataTypeExtension::get(i.datatype)
        val v = getFieldVisibility(d, i)
        // val isImmutable = '''«IF isImmutable(d)»final «ENDIF»'''   // does not work, as we generate the deSerialization!

        return '''
            «writeFieldComments(i)»
            «JavaBeanValidation::writeAnnotations(i, ref, doBeanVal)»
            «IF v != XVisibility::DEFAULT»«v» «ENDIF»«JavaDataTypeNoName(i, false)» «i.name»«writeDefaultValue(i, ref)»;
        '''
    }

    // TODO: Setters might need to check string max length, and also clone for (Gregorian)Calendar and byte arrays?
    def public static writeFields(ClassDefinition d, boolean doBeanVal) '''
        // fields as defined in DSL
        «FOR i:d.fields»
            «writeOneField(d, i, doBeanVal)»
        «ENDFOR»
        '''

    // Unused. Test to see the generated code for Lambdas.
    def public static writeFieldsWithLambda(ClassDefinition d, boolean doBeanVal) '''
        // fields as defined in DSL
        «d.fields.forEach [ writeOneField(d, it, doBeanVal) ]»
    '''

    def public static writeGettersSetters(ClassDefinition d) '''
        // auto-generated getters and setters
        «FOR i:d.fields»
            public «JavaDataTypeNoName(i, false)» get«i.name.toFirstUpper»() {
                return «i.name»;
            }
            «IF !isImmutable(d)»
                public void set«i.name.toFirstUpper»(«JavaDataTypeNoName(i, false)» «i.name») {
                    this.«i.name» = «i.name»;
                }
            «ENDIF»
        «ENDFOR»
    '''
}
