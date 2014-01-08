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
import de.jpaw.bonaparte.dsl.generator.DataCategory
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.Util

import static extension de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import java.util.Map

class JavaMeta {
    private static final Map<String,Integer> TOTAL_DIGITS = #{ 'byte' -> 2, 'short' -> 4, 'int' -> 9, 'long' -> 18, 'float' -> 9, 'double' -> 15, 'integer' -> 9 }
    private static final Map<String,Integer> DECIMAL_DIGITS = #{ 'byte' -> 0, 'short' -> 0, 'int' -> 0, 'long' -> 0, 'float' -> 9, 'double' -> 15, 'integer' -> 0 }
    
    def private static makeMeta(ClassDefinition d, FieldDefinition i) {
        val ref = DataTypeExtension::get(i.datatype)
        val elem = ref.elementaryDataType
        var String multi
        var String classname
        var String visibility = getFieldVisibility(d, i).getName()
        var String ext = ""  // category specific data
        var String extraItem = null  // category specific data

        if (i.isArray != null)
            multi = "Multiplicity.ARRAY, 0, " + i.isArray.mincount + ", " + i.isArray.maxcount
        else if (i.isList != null)
            multi = "Multiplicity.LIST, 0, " + i.isList.mincount + ", " + i.isList.maxcount
        else if (i.isSet != null)
            multi = "Multiplicity.SET, 0, " + i.isSet.mincount + ", " + i.isSet.maxcount
        else if (i.isMap != null)
            multi = "Multiplicity.MAP, " + mapIndexID(i.isMap) + ", " + i.isMap.mincount + ", " + i.isMap.maxcount
        else
            multi = "Multiplicity.SCALAR, 0, 0, 0"

        switch (ref.category) {
        case DataCategory::BASICNUMERIC: {
            classname = "BasicNumericElementaryDataItem"
            val type = ref.javaType.toLowerCase
            ext = ''', «b2A(ref.effectiveSigned)», «TOTAL_DIGITS.get(type)», «DECIMAL_DIGITS.get(type)»'''
            }
        case DataCategory::NUMERIC: {
            classname = "NumericElementaryDataItem"
            ext = ''', «b2A(ref.effectiveSigned)», «elem.length», «elem.decimals», «b2A(ref.effectiveRounding)», «b2A(ref.effectiveAutoScale)»'''
            }
        case DataCategory::STRING: {
            classname = "AlphanumericElementaryDataItem"
            ext = ''', «b2A(ref.effectiveTrim)», «b2A(ref.effectiveTruncate)», «b2A(ref.effectiveAllowCtrls)», «b2A(!elem.name.toLowerCase.equals("unicode"))», «elem.length», «elem.minLength», «s2A(elem.regexp)»'''
            }
        case DataCategory::ENUM: {
            classname = "EnumDataItem"
            if (ref.enumMaxTokenLength >= 0)
                // separate item for the token
                extraItem = '''
                    protected static final AlphanumericElementaryDataItem meta$$«i.name»$token = new AlphanumericElementaryDataItem(Visibility.«visibility», «b2A(i.isRequired)», "«i.name»$token", «multi», DataCategory.STRING,
                        "String", false, «i.isAggregateRequired», true, false, false, false, «ref.enumMaxTokenLength», 0, null);
                '''
            else
                extraItem = '''
                    protected static final BasicNumericElementaryDataItem meta$$«i.name»$token = new BasicNumericElementaryDataItem(Visibility.«visibility», «b2A(i.isRequired)», "«i.name»$token", «multi», DataCategory.NUMERIC,
                        "int", true, «i.isAggregateRequired», false, 4, 0);  // assume 4 digits
                '''
            ext = ''', "«elem.enumType.partiallyQualifiedClassName»", null'''
        }
        case DataCategory::TEMPORAL: {
            classname = "TemporalElementaryDataItem"
            ext = ''', «elem.length», «elem.doHHMMSS»'''
            }
        case DataCategory::OBJECT: {
            classname = "ObjectReference"
            if (elem != null) {
                 // just "Object
                ext = ''', true, "BonaPortable", null'''
            } else {
                ext = ''', «b2A(ref.orSuperClass)», "«ref.javaType»", «ref.javaType».class$MetaData()'''
            }
        }
        case DataCategory::BINARY: {
            classname = "BinaryElementaryDataItem"
            ext = ''', «elem.length»'''
            }
        default: {
            classname = "MiscElementaryDataItem"
            ext = ''''''
            }
        }
        return '''
            «extraItem»
            protected static final «classname» meta$$«i.name» = new «classname»(Visibility.«visibility», «b2A(i.isRequired)», "«i.name»", «multi», DataCategory.«ref.category.name»,
                "«ref.javaType»", «b2A(ref.isPrimitive)», «i.isAggregateRequired»«ext»);
            '''
    }

    def public static writeMetaData(ClassDefinition d) {
        var int cnt2 = -1
        var myPackage = getPackage(d)
        var propertiesInherited = (d.inheritProperties || myPackage.inheritProperties) && d.getParent != null
        return '''
            // property map
            private static final ConcurrentMap<String,String> property$Map = new ConcurrentHashMap<String,String>();

            // initializer
            protected static void class$fillProperties(ConcurrentMap<String,String> map) {
                «FOR p : d.properties»
                    map.putIfAbsent("«p.key.name»", "«IF p.value != null»«Util::escapeString2Java(p.value)»«ENDIF»");
                «ENDFOR»
                «FOR f : d.fields»
                    «FOR p : f.properties»
                        map.putIfAbsent("«f.name».«p.key.name»", "«IF p.value != null»«Util::escapeString2Java(p.value)»«ENDIF»");
                    «ENDFOR»
                «ENDFOR»
                «IF propertiesInherited»
                    // «d.getParent.name».class$fillProperties(map); // done anyway by static initializer of parent
                «ENDIF»
            }
            static {
                class$fillProperties(property$Map);
            }
            static public ConcurrentMap<String,String> class$PropertyMap() {
                return property$Map;
            }
            public ConcurrentMap<String,String> get$PropertyMap() {
                return property$Map;
            }
            static public String get$Property(String propertyname, String fieldname) {
                return property$Map.get(fieldname == null ? propertyname : fieldname + "." + propertyname);
            }

            static public String class$Property(String id) {
                «IF propertiesInherited»
                    if (property$Map.containsKey(id))
                        return property$Map.get(id);
                    else
                        return «d.getParent.name».class$Property(id);
                «ELSE»
                    return property$Map.get(id);
                «ENDIF»
            }
            static public String field$Property(String fieldname, String propertyname) {
                String id = fieldname + "." + propertyname;
                «IF propertiesInherited»
                    if (property$Map.containsKey(id))
                        return property$Map.get(id);
                    else
                        return «d.getParent.name».class$Property(id);
                «ELSE»
                    return property$Map.get(id);
                «ENDIF»
            }
            static public boolean class$hasProperty(String id) {
                «IF propertiesInherited»
                    return property$Map.containsKey(id) || «d.getParent.name».class$hasProperty(id);
                «ELSE»
                    return property$Map.containsKey(id);
                «ENDIF»
            }
            static public boolean field$hasProperty(String fieldname, String propertyname) {
                String id = fieldname + "." + propertyname;
                «IF propertiesInherited»
                    return property$Map.containsKey(id) || «d.getParent.name».class$hasProperty(id);
                «ELSE»
                    return property$Map.containsKey(id);
                «ENDIF»
            }
            public String get$Property(String id) {
                return class$Property(id);
            }

            static public Class<? extends BonaPortable> class$returns() {
                «IF d.returnsClass != null»
                    return «d.returnsClass.packageName».«d.returnsClass.name».class;
                «ELSE»
                    return «IF d.parent != null»«d.parent.name».class$returns()«ELSE»null«ENDIF»;
                «ENDIF»
            }

            @Override
            public Class<? extends BonaPortable> get$returns() {
                return class$returns();
            }


            static public Class<? extends BonaPortable> class$pk() {
                «IF d.pkClass != null»
                    return «d.pkClass.packageName».«d.pkClass.name».class;
                «ELSE»
                    return «IF d.parent != null»«d.parent.name».class$pk()«ELSE»null«ENDIF»;
                «ENDIF»
            }

            @Override
            public Class<? extends BonaPortable> get$pk() {
                return class$pk();
            }

            // my name and revision
            private static final String PARTIALLY_QUALIFIED_CLASS_NAME = "«getPartiallyQualifiedClassName(d)»";
            private static final String REVISION = «IF d.revision != null && d.revision.length > 0»"«d.revision»"«ELSE»null«ENDIF»;
            private static final String PARENT = «IF (d.extendsClass != null)»"«getPartiallyQualifiedClassName(d.getParent)»"«ELSE»null«ENDIF»;
            private static final String BUNDLE = «IF (myPackage.bundle != null)»"«myPackage.bundle»"«ELSE»null«ENDIF»;

            «FOR i : d.fields»
                «makeMeta(d, i)»
            «ENDFOR»

            // extended meta data (for the enhanced interface)
            private static final ClassDefinition my$MetaData = new ClassDefinition();
            static {
                my$MetaData.setIsAbstract(«d.isAbstract»);
                my$MetaData.setIsFinal(«d.isFinal»);
                my$MetaData.setName(PARTIALLY_QUALIFIED_CLASS_NAME);
                my$MetaData.setRevision(REVISION);
                my$MetaData.setParent(PARENT);
                my$MetaData.setBundle(BUNDLE);
                my$MetaData.setSerialUID(serialVersionUID);
                my$MetaData.setNumberOfFields(«d.fields.size»);
                FieldDefinition [] field$array = new FieldDefinition[«d.fields.size»];
                «FOR i:d.fields»
                    field$array[«(cnt2 = cnt2 + 1)»] = meta$$«i.name»;
                «ENDFOR»
                my$MetaData.setFields(field$array);
                my$MetaData.setPropertiesInherited(«propertiesInherited»);
                my$MetaData.setWhenLoaded(new LocalDateTime());
                «IF (d.extendsClass != null)»
                	my$MetaData.setParentMeta(«d.getParent.name».class$MetaData());
                «ENDIF»
            };

            // get all the meta data in one go
            static public ClassDefinition class$MetaData() {
                return my$MetaData;
            }

            // some methods intentionally use the $ sign, because use in normal code is discouraged, so we expect
            // no namespace conflicts here
            // must be repeated as a member method to make it available in the (extended) interface
            // feature of extended BonaPortable, not in the core interface
            @Override
            public ClassDefinition get$MetaData() {
                return my$MetaData;
            }

            // convenience functions for faster access if the metadata structure is not used
            @Override
            public String get$PQON() {
                return PARTIALLY_QUALIFIED_CLASS_NAME;
            }
            @Override
            public String get$Revision() {
                return REVISION;
            }
            @Override
            public String get$Parent() {
                return PARENT;
            }
            @Override
            public String get$Bundle() {
                return BUNDLE;
            }
            @Override
            public long get$Serial() {
                return serialVersionUID;
            }
        '''
    }
}
