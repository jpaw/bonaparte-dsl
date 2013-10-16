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
import de.jpaw.bonaparte.dsl.bonScript.XBeanNames
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import static extension de.jpaw.bonaparte.dsl.generator.Util.*
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import de.jpaw.bonaparte.dsl.bonScript.XXmlAccess

class JavaFieldsGettersSetters {
    val static String xmlInterfaceAnnotation = "@XmlAnyElement"   // "@XmlElement(type=Object.class)"

    def private static writeDefaultValue(FieldDefinition i, DataTypeExtension ref) {
        if (i.defaultString == null)
            ''''''
        else
            if (ref.javaType.equals("String"))
                ''' = "«i.defaultString.escapeString2Java»"'''
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

    def private static writeAnnotationProperties(FieldDefinition i, ClassDefinition d) {
        i.properties.filter[key.annotationName != null].map['''@«key.annotationName»«IF value != null»("«value.escapeString2Java»")«ENDIF»'''].join('\n')    
    }
        
    def private static writeOneField(ClassDefinition d, FieldDefinition i, boolean doBeanVal) {
        val ref = DataTypeExtension::get(i.datatype)
        val v = getFieldVisibility(d, i)
        // val isImmutable = '''«IF isImmutable(d)»final «ENDIF»'''   // does not work, as we generate the deSerialization!
        // System::out.println('''writing one field «d.name»:«i.name» needs XmlAccess=«i.needsXmlObjectType» has XmlAccess «d.getRelevantXmlAccess»''')
        
        return '''
            «writeFieldComments(i)»
            «JavaBeanValidation::writeAnnotations(i, ref, doBeanVal)»
            «i.writeAnnotationProperties(d)»
            «IF d.getRelevantXmlAccess == XXmlAccess::FIELD && i.needsXmlObjectType»
                «xmlInterfaceAnnotation»
            «ENDIF»
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

    // write the standard getter plus maybe some indexed one
    def private static writeOneGetter(FieldDefinition i, ClassDefinition d, String getterName) '''
        «IF d.getRelevantXmlAccess == XXmlAccess::PROPERTY && i.needsXmlObjectType»
            «xmlInterfaceAnnotation»
        «ENDIF»
        public «JavaDataTypeNoName(i, false)» «getterName»() {
            return «i.name»;
        }
        «IF i.isArray != null»
            public «JavaDataTypeNoName(i, true)» «getterName»(int _i) {
                return «i.name»[_i];
            }
        «ENDIF»
    '''
    // write the standard setter plus maybe some indexed one
    def private static writeOneSetter(FieldDefinition i, String setterName, boolean isFreezable) '''
        public void «setterName»(«JavaDataTypeNoName(i, false)» «i.name») {
            «IF isFreezable»
                verify$Not$Frozen();
            «ENDIF»
            this.«i.name» = «i.name»;
        }
        «IF i.isArray != null»
            public void «setterName»(int _i, «JavaDataTypeNoName(i, true)» «i.name») {
                this.«i.name»[_i] = «i.name»;
            }
        «ENDIF»
    '''
    
    def public static writeGettersSetters(ClassDefinition d) {
        val isFreezable = d.freezable
        val doNames = d.beanNames
    '''
        // auto-generated getters and setters
        «FOR i:d.fields»
            «IF doNames != XBeanNames::ONLY_BEAN_NAMES»
                «i.writeOneGetter(d, "get" + i.name.toFirstUpper)»
            «ENDIF»
            «IF doNames == XBeanNames::ONLY_BEAN_NAMES || (doNames == XBeanNames::BEAN_AND_SIMPLE_NAMES && i.name.toFirstUpper != i.name.beanName)»
                «i.writeOneGetter(d, "get" + i.name.beanName)»
            «ENDIF»
            «IF i.getter != null»
                «i.writeOneGetter(d, i.getter)»
            «ENDIF»
            «IF !isImmutable(d)»
                «IF doNames != XBeanNames::ONLY_BEAN_NAMES»
                    «i.writeOneSetter("set" + i.name.toFirstUpper, isFreezable)»
                «ENDIF»
                «IF doNames == XBeanNames::ONLY_BEAN_NAMES || (doNames == XBeanNames::BEAN_AND_SIMPLE_NAMES && i.name.toFirstUpper != i.name.beanName)»
                    «i.writeOneSetter("set" + i.name.beanName, isFreezable)»
                «ENDIF»
                «IF i.setter != null»
                    «i.writeOneSetter(i.setter, isFreezable)»
                «ENDIF»
            «ENDIF»
        «ENDFOR»
    '''
    }
}
