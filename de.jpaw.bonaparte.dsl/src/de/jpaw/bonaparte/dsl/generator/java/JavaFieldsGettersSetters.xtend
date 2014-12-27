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
import de.jpaw.bonaparte.dsl.bonScript.XBeanNames
import de.jpaw.bonaparte.dsl.bonScript.XEnumDefinition
import de.jpaw.bonaparte.dsl.bonScript.XVisibility
import de.jpaw.bonaparte.dsl.bonScript.XXmlAccess
import de.jpaw.bonaparte.dsl.generator.DataCategory
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.XUtil
import java.util.HashMap
import java.util.Map

import static extension de.jpaw.bonaparte.dsl.generator.Util.*
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*

class JavaFieldsGettersSetters {
    val static String xmlInterfaceAnnotation = "@XmlAnyElement"   // "@XmlElement(type=Object.class)"
    val static Map<String,String> xmlAdapterMap = new HashMap<String,String> => [
        put("byte", "Byte")
        put("short", "Short")
        put("int", "Integer")
        put("integer", "Integer")
        put("long", "Long")
    ]
    
    def private static xmlAnnotation(XEnumDefinition d) '''
        @XmlJavaTypeAdapter(«d.root.bonPackageName».«d.root.name»XmlAdapter.class)
    '''
    
    def private static xmlAnnotation(DataTypeExtension ref) {
        val namePart = xmlAdapterMap.get(ref.javaType.toFirstLower)
        val decimals = ref.elementaryDataType.decimals
        if (decimals > 0 && namePart !== null)
            return '''
                @XmlJavaTypeAdapter(de.jpaw.xml.jaxb.scaledFp.Scaled«namePart»Adapter«decimals»«IF ref.effectiveRounding»Round«ELSE»Exact«ENDIF».class)
            '''
    }
     
    def private static writeDefaultValue(FieldDefinition i, DataTypeExtension ref, boolean effectiveAggregate) {
        if (effectiveAggregate)  // Only write defaults if we are not in an array / set / map etc.
            return ''''''
            
        if (i.defaultString === null) {
            // check for enum defaults, these use a different mechanism.
            if ((ref.category == DataCategory.ENUM || ref.category == DataCategory.ENUMALPHA || ref.category == DataCategory.XENUM) && ref.enumMaxTokenLength >= -1 && ref.effectiveEnumDefault) {
                switch (ref.enumMaxTokenLength) {
                case -1:        // numeric enum
                    return ''' = «JavaDataTypeNoName(i, false)».«ref.elementaryDataType.enumType.values.get(0)»'''        // the first one is the default
                default:        // alphanumeric enum    
                    return ''' = «JavaDataTypeNoName(i, false)».«ref.elementaryDataType.enumType.avalues.get(0).name»'''  // the first one is the default
                }
            }
            ''''''
        } else
            if (ref.javaType.equals("String"))
                ''' = "«i.defaultString.escapeString2Java»"'''
            else
                ''' = «i.defaultString»'''
    }

    // output regular as well as Javadoc style comments
    def public static writeFieldComments(FieldDefinition i) '''
        «IF i.comment !== null»
            // «i.comment» !
        «ENDIF»
        «IF i.javadoc !== null»
            «i.javadoc»
        «ENDIF»
    '''

    def private static writeAnnotationProperties(FieldDefinition i, ClassDefinition d) {
        i.properties.filter[key.annotationReference !== null].map['''@«key.annotationReference.qualifiedName»«IF value !== null»("«value.escapeString2Java»")«ENDIF»'''].join('\n')    
    }
    
    def private static writeIfDeprecated(FieldDefinition i) {
        if (i.isDeprecated)
            return "@Deprecated"
    }
        
    def private static writeOneField(ClassDefinition d, FieldDefinition i, boolean doBeanVal) {
        val ref = DataTypeExtension::get(i.datatype)
        val v = getFieldVisibility(d, i)
        // val isImmutable = '''«IF isImmutable(d)»final «ENDIF»'''   // does not work, as we generate the deSerialization!
        // System::out.println('''writing one field «d.name»:«i.name» needs XmlAccess=«i.needsXmlObjectType» has XmlAccess «d.getRelevantXmlAccess»''')
        
        return '''
            «i.writeFieldComments»
            «JavaBeanValidation::writeAnnotations(i, ref, doBeanVal)»
            «i.writeAnnotationProperties(d)»
            «IF d.getRelevantXmlAccess == XXmlAccess::FIELD»
                «IF i.needsXmlObjectType»
                    «xmlInterfaceAnnotation»
                «ENDIF»
                «IF ref.category == DataCategory.XENUM»
                    «ref.elementaryDataType.xenumType.xmlAnnotation»
                «ENDIF»
                «IF ref.category == DataCategory.BASICNUMERIC»
                    «ref.xmlAnnotation»
                «ENDIF»
            «ENDIF»
            «i.writeIfDeprecated»
            «IF v != XVisibility::DEFAULT»«v» «ENDIF»«JavaDataTypeNoName(i, false)» «i.name»«writeDefaultValue(i, ref, i.aggregate)»;
        '''
    }

    // TODO: Setters might need to check string max length, and also clone for byte arrays?
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
    def private static writeOneGetter(FieldDefinition i, ClassDefinition d, String getterName) {
        val ref = DataTypeExtension::get(i.datatype)
        return '''
            «IF d.getRelevantXmlAccess == XXmlAccess::PROPERTY»
                «IF i.needsXmlObjectType»
                    «xmlInterfaceAnnotation»
                «ENDIF»
                «IF ref.category == DataCategory.XENUM»
                    «ref.elementaryDataType.xenumType.xmlAnnotation»
                «ENDIF»
                «IF ref.category == DataCategory.BASICNUMERIC»
                    «ref.xmlAnnotation»
                «ENDIF»
            «ENDIF»
            «i.writeIfDeprecated»
            public «JavaDataTypeNoName(i, false)» «getterName»() {
                return «i.name»;
            }
            «IF i.isArray !== null»
                «i.writeIfDeprecated»
                public «JavaDataTypeNoName(i, true)» «getterName»(int _i) {
                    return «i.name»[_i];
                }
            «ENDIF»
        '''
    }
    
    // write the standard setter plus maybe some indexed one
    def private static writeOneSetter(FieldDefinition i, String setterName, boolean isFreezable) {
        val ref = DataTypeExtension::get(i.datatype) 
        return
     '''
        «i.writeIfDeprecated»
        public void «setterName»(«JavaDataTypeNoName(i, false)» «i.name») {
            «IF isFreezable»
                verify$Not$Frozen();
            «ENDIF»
            this.«i.name» = «i.name»;
        }
        «IF i.isArray !== null»
            «i.writeIfDeprecated»
            public void «setterName»(int _i, «JavaDataTypeNoName(i, true)» «i.name») {
                this.«i.name»[_i] = «i.name»;
            }
        «ENDIF»
        «IF ref.category == DataCategory.XENUM»
            «IF !i.aggregate»
                «writeEnumSetterWithConverter(i, setterName, isFreezable, ref, "Enum<?>")»
             «ELSEIF i.isArray !== null»
                «i.writeIfDeprecated»
                public void «setterName»(int _index, Enum<?> «i.name») {
                    this.«i.name»[_index] = «XUtil.xEnumFactoryName(ref)».of(_i);
                }
            «ENDIF»
        «ENDIF»
    '''
    }
    
    // the following was not possible above, due to the dreaded Java type erasure:
//        «IF ref.category == DataCategory.XENUM»
//            «IF !i.aggregate»
//                «writeEnumSetterWithConverter(i, setterName, isFreezable, ref, "Enum<?>")»
//             «ELSEIF i.isList !== null»
//                «writeEnumSetterWithConverter(i, setterName, isFreezable, ref, "List<Enum<?>>")»
//             «ELSEIF i.isSet !== null»
//                «writeEnumSetterWithConverter(i, setterName, isFreezable, ref, "Set<Enum<?>>")»
//             «ELSEIF i.isArray !== null»
//                «writeEnumSetterWithConverter(i, setterName, isFreezable, ref, "Enum<?>[]")»
//                public void «setterName»(int _index, Enum<?> «i.name») {
//                    this.«i.name»[_index] = «XUtil.xEnumFactoryName(ref)».of(_i);
//                }
//            «ENDIF»
//        «ENDIF»
    
    
    
    def private static writeEnumSetterWithConverter(FieldDefinition i, String setterName, boolean isFreezable, DataTypeExtension ref, String type) '''
        // mapping setter from enum to xenum
        «i.writeIfDeprecated»
        public void «setterName»(«type» _i) {
            «IF isFreezable»
                verify$Not$Frozen();
            «ENDIF»
            this.«i.name» = «XUtil.xEnumFactoryName(ref)».of(_i);
        }
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
            «IF i.getter !== null»
                «i.writeOneGetter(d, i.getter)»
            «ENDIF»
            «IF !d.root.isImmutable»
                «IF doNames != XBeanNames::ONLY_BEAN_NAMES»
                    «i.writeOneSetter("set" + i.name.toFirstUpper, isFreezable)»
                «ENDIF»
                «IF doNames == XBeanNames::ONLY_BEAN_NAMES || (doNames == XBeanNames::BEAN_AND_SIMPLE_NAMES && i.name.toFirstUpper != i.name.beanName)»
                    «i.writeOneSetter("set" + i.name.beanName, isFreezable)»
                «ENDIF»
                «IF i.setter !== null»
                    «i.writeOneSetter(i.setter, isFreezable)»
                «ENDIF»
            «ENDIF»
        «ENDFOR»
    '''
    }
}
