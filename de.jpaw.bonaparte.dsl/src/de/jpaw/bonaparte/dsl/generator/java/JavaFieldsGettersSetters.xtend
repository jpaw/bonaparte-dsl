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
import de.jpaw.bonaparte.dsl.bonScript.XXmlAccess
import de.jpaw.bonaparte.dsl.generator.DataCategory
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.XUtil
import java.util.HashMap
import java.util.Map
import java.util.concurrent.atomic.AtomicBoolean

import static extension de.jpaw.bonaparte.dsl.generator.Util.*
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*

class JavaFieldsGettersSetters {
    val static String xmlInterfaceAnnotation = "@XmlAnyElement"   // "@XmlElement(type=Object.class)"
    val static Map<String,String> xmlAdapterMap = new HashMap<String,String> => [
        put("byte",     "Byte")
        put("short",    "Short")
        put("int",      "Integer")
        put("integer",  "Integer")
        put("long",     "Long")
        put("bigDecimal", "Decimal")
    ]

    def private static xmlAnnotation(XEnumDefinition d) '''
        @XmlJavaTypeAdapter(«d.root.bonPackageName».«d.root.name»XmlAdapter.class)
    '''
    def private static xmlJsonAnnotation(FieldDefinition i, DataTypeExtension ref) '''
        @XmlJavaTypeAdapter(de.jpaw.bonaparte.xml.XmlJsonAdapter.class)
    '''

    def private static xmlTemporalAnnotation(DataTypeExtension ref) {
        switch (ref.javaType) {
            case 'LocalDate':     return '''@XmlSchemaType(name="date")'''
            case 'LocalTime':     return '''@XmlSchemaType(name="time")'''
            case 'LocalDateTime': return '''@XmlSchemaType(name="dateTime")'''
            case 'Instant':       return null
            default:              return null
        }
    }

    def private static xmlAnnotation(DataTypeExtension ref) {
        val namePart = xmlAdapterMap.get(ref.javaType.toFirstLower)
        val decimals = ref.elementaryDataType.decimals
        if (decimals > 0 && namePart !== null)
            return '''
                @XmlJavaTypeAdapter(de.jpaw.xml.jaxb.scaledFp.Scaled«namePart»Adapter«decimals»«IF ref.effectiveRounding»Round«ELSE»Exact«ENDIF».class)
            '''
    }

    def public static writeDefaultValue(FieldDefinition i, DataTypeExtension ref, boolean effectiveAggregate) {
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

                // TODO: for map, the last one seems to be causing issue at the moment because of the non-matching type
                // probably create all classes with all possibilities is good/not good option
                // temporarily skipping in case of map since its not really used at the moment
    def public static allXmlAnnotations(FieldDefinition i, DataTypeExtension ref, boolean xmlUpper, boolean xmlAllUpper) {
        val datatype = ref.elementaryDataType?.name?.toLowerCase
        if (i.properties.hasProperty(PROP_ATTRIBUTE)) {
            return '''
                @XmlAttribute(name="«xmlName(i, xmlUpper, xmlAllUpper)»"«IF i.isRequired», required=true«ENDIF»)
            '''
        }
        val xmlId = i.properties.getProperty(PROP_XML_ID)
        return '''
            «IF i.needsXmlObjectType»
                «xmlInterfaceAnnotation»
            «ENDIF»
            «IF ref.category == DataCategory.XENUM»
                «ref.elementaryDataType.xenumType.xmlAnnotation»
            «ENDIF»
            «IF ref.category == DataCategory.TEMPORAL»
                «ref.xmlTemporalAnnotation»
            «ENDIF»
            «IF "json" == datatype»
                «xmlJsonAnnotation(i, ref)»
            «ENDIF»
            «IF i.isMap === null && (ref.category == DataCategory.BASICNUMERIC || ref.category == DataCategory.NUMERIC)»
                «ref.xmlAnnotation»
            «ENDIF»
            «IF xmlId !== null»
                @XmlElement(name="«xmlId»")
            «ELSEIF xmlUpper || i.properties.hasProperty(PROP_UPPERCASE)»
                @XmlElement(name="«i.name.toFirstUpper»")
            «ELSEIF xmlAllUpper || i.properties.hasProperty(PROP_ALL_UPPERCASE)»
                @XmlElement(name="«i.name.toUpperCase»")
            «ENDIF»
        '''
        // also see XUtil.xmlName
    }

    // write the standard getter plus maybe some indexed one
    // if getterWritten is true, then this is a subsequent call for a field which has seen a getter already.
    // That is used to declare the getter as XmlTransient
    def private static writeOneGetter(FieldDefinition i, ClassDefinition d, String getterName, AtomicBoolean initialGetter) {
        val ref = DataTypeExtension::get(i.datatype)
        val initialCall = initialGetter.getAndSet(false)
        return '''
            «ref.intJavaDoc(i, "@return")»
            «IF d.getRelevantXmlAccess == XXmlAccess::PROPERTY»
                «IF initialCall»
                    «allXmlAnnotations(i, ref, d.isXmlUpper, d.isXmlAllUppercase)»
                «ELSE»
                    @XmlTransient
                «ENDIF»
            «ENDIF»
            «i.writeIfDeprecated»
            public «JavaDataTypeNoName(i, false)» «getterName»() {
                «IF i.isDeprecated»
                    DeprecationWarner.warnGet(this, "«i.name»");
                «ENDIF»
                return «i.name»;
            }
            «IF i.isArray !== null»
                «i.writeIfDeprecated»
                public «JavaDataTypeNoName(i, true)» «getterName»(int _i) {
                    «IF i.isDeprecated»
                        DeprecationWarner.warnGet(this, "«i.name»");
                    «ENDIF»
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
        «ref.intJavaDoc(i, "@param " + i.name)»
        «i.writeIfDeprecated»
        public void «setterName»(«JavaDataTypeNoName(i, false)» «i.name») {
            «IF isFreezable»
                verify$Not$Frozen();
            «ENDIF»
            «IF i.isDeprecated»
                DeprecationWarner.warnSet(this, "«i.name»");
            «ENDIF»
            this.«i.name» = «i.name»;
        }
        «IF i.isArray !== null»
            «i.writeIfDeprecated»
            public void «setterName»(int _i, «JavaDataTypeNoName(i, true)» «i.name») {
                «IF i.isDeprecated»
                    DeprecationWarner.warnSet(this, "«i.name»");
                «ENDIF»
                this.«i.name»[_i] = «i.name»;
            }
        «ENDIF»
        «IF ref.category == DataCategory.XENUM»
            «IF !i.aggregate»
                «writeEnumSetterWithConverter(i, setterName, isFreezable, ref, "Enum<?>")»
             «ELSEIF i.isArray !== null»
                «i.writeIfDeprecated»
                public void «setterName»(int _index, Enum<?> «i.name») {
                    «IF i.isDeprecated»
                        DeprecationWarner.warnSet(this, "«i.name»");
                    «ENDIF»
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
            «IF i.isDeprecated»
                DeprecationWarner.warnSet(this, "«i.name»");
            «ENDIF»
            this.«i.name» = «XUtil.xEnumFactoryName(ref)».of(_i);
        }
    '''

    // utility method to reset the flag every loop iteration
    def private static CharSequence reset(AtomicBoolean flag) {
        flag.set(true)
        return null
    }

    def public static writeGettersSetters(ClassDefinition d) {
        val isFreezable = d.freezable
        val doNames = d.beanNames
        val initialGetter = new AtomicBoolean
    '''
        // auto-generated getters and setters
        «FOR i:d.fields»
            «initialGetter.reset»
            «IF doNames == XBeanNames::ONLY_BEAN_NAMES || (doNames == XBeanNames::BEAN_AND_SIMPLE_NAMES && i.name.toFirstUpper != i.name.beanName)»
                «i.writeOneGetter(d, "get" + i.name.beanName, initialGetter)»
            «ENDIF»
            «IF doNames != XBeanNames::ONLY_BEAN_NAMES»
                «i.writeOneGetter(d, "get" + i.name.toFirstUpper, initialGetter)»
            «ENDIF»
            «IF i.getter !== null»
                «i.writeOneGetter(d, i.getter, initialGetter)»
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
