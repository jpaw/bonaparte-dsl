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
import de.jpaw.bonaparte.dsl.generator.XUtil

class JavaMeta {
    // defines the maximum number of digits which could be encountered for a given number
    public static final Map<String,Integer> TOTAL_DIGITS = #{ 'byte' -> 3, 'short' -> 5, 'int' -> 10, 'long' -> 19, 'float' -> 9, 'double' -> 15, 'integer' -> 10, 'biginteger' -> 4000 }
    public static final Map<String,Integer> DECIMAL_DIGITS = #{ 'byte' -> 0, 'short' -> 0, 'int' -> 0, 'long' -> 0, 'float' -> 9, 'double' -> 15, 'integer' -> 0, 'biginteger' -> 0 }
    
    def private static metaVisibility(ClassDefinition d) {
        if (d.publicMeta)
            '''public'''
        else
            '''protected'''
    }
    def private static metaVisibility(ClassDefinition d, boolean forcePublic) {
        if (forcePublic || d.publicMeta)
            '''public'''
        else
            '''protected'''
    }
    
    def private static makeMeta(ClassDefinition d, FieldDefinition i) {
        val ref = DataTypeExtension::get(i.datatype)
        val elem = ref.elementaryDataType
        var String multi
        var String classname
        var String visibility = getFieldVisibility(d, i).getName()
        var String ext = ""  // category specific data
        var String extraItem = null  // category specific data
        var boolean forcePublicMeta = false

        if (i.isArray !== null)
            multi = "Multiplicity.ARRAY, 0, " + i.isArray.mincount + ", " + i.isArray.maxcount
        else if (i.isList !== null)
            multi = "Multiplicity.LIST, 0, " + i.isList.mincount + ", " + i.isList.maxcount
        else if (i.isSet !== null)
            multi = "Multiplicity.SET, 0, " + i.isSet.mincount + ", " + i.isSet.maxcount
        else if (i.isMap !== null)
            multi = "Multiplicity.MAP, " + mapIndexID(i.isMap) + ", " + i.isMap.mincount + ", " + i.isMap.maxcount
        else
            multi = "Multiplicity.SCALAR, 0, 0, 0"

        switch (ref.category) {
        case DataCategory::BASICNUMERIC: {
            classname = "BasicNumericElementaryDataItem"
            val type = ref.javaType.toLowerCase
            val len = if (elem.length > 0) elem.length else TOTAL_DIGITS.get(type)
            val frac = if (elem.length > 0) elem.decimals else DECIMAL_DIGITS.get(type)
            ext = ''', «b2A(ref.effectiveSigned)», «len», «frac», «b2A(ref.effectiveRounding)»'''
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
                    «d.metaVisibility» static final AlphanumericElementaryDataItem meta$$«i.name»$token = new AlphanumericElementaryDataItem(Visibility.«visibility», «b2A(i.isRequired)», "«i.name»$token", «multi», DataCategory.STRING,
                        "String", false, «i.isAggregateRequired», true, false, false, false, «ref.enumMaxTokenLength», 0, null);
                '''
            else
                extraItem = '''
                    «d.metaVisibility» static final BasicNumericElementaryDataItem meta$$«i.name»$token = new BasicNumericElementaryDataItem(Visibility.«visibility», «b2A(i.isRequired)», "«i.name»$token", «multi», DataCategory.NUMERIC,
                        "int", true, «i.isAggregateRequired», false, 4, 0, false);  // assume 4 digits
                '''
            ext = ''', «elem.enumType.name».enum$MetaData()'''
        }
        case DataCategory::XENUM: {
            classname = "XEnumDataItem"
            // separate item for the token. TODO: Do I need this here?
            extraItem = '''
                «d.metaVisibility» static final AlphanumericElementaryDataItem meta$$«i.name»$token = new AlphanumericElementaryDataItem(Visibility.«visibility», «b2A(i.isRequired)», "«i.name»$token", «multi», DataCategory.STRING,
                    "String", false, «i.isAggregateRequired», true, false, false, false, «ref.enumMaxTokenLength», 0, null);
                '''
            ext = ''', «elem.xenumType.name».xenum$MetaData()'''
        }
        case DataCategory::TEMPORAL: {
            classname = "TemporalElementaryDataItem"
            ext = ''', «elem.length», «elem.doHHMMSS»'''
            }
        case DataCategory::OBJECT: {
            classname = "ObjectReference"
            if (elem !== null) {
                 // just "Object"
                forcePublicMeta = true        // hack required by BDDL: serialized fields need to access the metadata, as they invoke special serializers  
                ext = ''', true, "BonaPortable", null, null, null'''
            } else {
                forcePublicMeta = i.properties.hasProperty("serialized")        // hack required by BDDL: serialized fields need to access the metadata, as they invoke special serializers  
                val myLowerBound = XUtil::getLowerBound(ref.genericsRef) // objectDataType?.extendsClass)
                val meta = if (myLowerBound === null) "null" else '''«myLowerBound.name».class$MetaData()'''
                val myLowerBound2 = ref.secondaryObjectDataType
                val meta2 = if (myLowerBound2 === null) "null" else '''«myLowerBound2.name».class$MetaData()'''
                ext = ''', «b2A(ref.orSuperClass)», "«ref.javaType»", «meta», «meta2», «B2A(ref.orSecondarySuperClass)»'''
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
            «d.metaVisibility(forcePublicMeta)» static final «classname» meta$$«i.name» = new «classname»(Visibility.«visibility», «b2A(i.isRequired)», "«i.name»", «multi», DataCategory.«ref.category.name»,
                "«ref.javaType»", «b2A(ref.isPrimitive)», «i.isAggregateRequired»«ext»);
            '''
    }

    def public static writeMetaData(ClassDefinition d) {
        val myPackage = getPackage(d)
        val propertiesInherited = (d.inheritProperties || myPackage.inheritProperties) && d.getParent !== null
        val externalPrefix = if (d.externalType !== null) 'External'
        return '''
            // property map
            private static final ImmutableMap<String,String> property$Map = new ImmutableMap.Builder<String,String>()
                «FOR p : d.properties»
                    .put("«p.key.name»", "«IF p.value !== null»«Util::escapeString2Java(p.value)»«ENDIF»")
                «ENDFOR»
                «FOR f : d.fields»
                    «FOR p : f.properties»
                        .put("«f.name».«p.key.name»", "«IF p.value !== null»«Util::escapeString2Java(p.value)»«ENDIF»")
                    «ENDFOR»
                «ENDFOR»
                .build();
                
            static public Map<String,String> class$PropertyMap() {
                return property$Map;
            }
            @Override
            @Deprecated
            public Map<String,String> get$PropertyMap() {
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
            @Override
            @Deprecated
            public String get$Property(String id) {
                return class$Property(id);
            }

            static public Class<? extends BonaPortable> class$returns() {
                «IF d.returnsClassRef !== null»
                    return «XUtil::getLowerBound(d.returnsClassRef).name».class;
                «ELSE»
                    return «IF d.parent !== null»«d.parent.name».class$returns()«ELSE»null«ENDIF»;
                «ENDIF»
            }

            @Override
            @Deprecated
            public Class<? extends BonaPortable> get$returns() {
                return class$returns();
            }


            static public Class<? extends BonaPortable> class$pk() {
                «IF d.pkClass !== null»
                    return «d.pkClass.packageName».«d.pkClass.name».class;
                «ELSE»
                    return «IF d.parent !== null»«d.parent.name».class$pk()«ELSE»null«ENDIF»;
                «ENDIF»
            }

            @Override
            @Deprecated
            public Class<? extends BonaPortable> get$pk() {
                return class$pk();
            }

            // my name and revision
            private static final String _PARTIALLY_QUALIFIED_CLASS_NAME = "«getPartiallyQualifiedClassName(d)»";
            private static final String _REVISION = «IF d.revision !== null && d.revision.length > 0»"«d.revision»"«ELSE»null«ENDIF»;
            private static final String _PARENT = «IF (d.extendsClass !== null)»"«getPartiallyQualifiedClassName(d.getParent)»"«ELSE»null«ENDIF»;
            private static final String _BUNDLE = «IF (myPackage.bundle !== null)»"«myPackage.bundle»"«ELSE»null«ENDIF»;
            private static final int PQON$HASH = _PARTIALLY_QUALIFIED_CLASS_NAME.hashCode();

            «FOR i : d.fields»
                «makeMeta(d, i)»
            «ENDFOR»

            // private (immutable) List of fields
            private static final ImmutableList<FieldDefinition> my$fields = ImmutableList.<FieldDefinition>of(
                «d.fields.map['''meta$$«name»'''].join(', ')»
            );
            
            // extended meta data (for the enhanced interface)
            private static final «externalPrefix»ClassDefinition my$MetaData = new «externalPrefix»ClassDefinition(
                «d.isAbstract»,
                «d.isFinal»,
                _PARTIALLY_QUALIFIED_CLASS_NAME,
                _PARENT,
                _BUNDLE,
                Instant.now(),
                «IF (d.extendsClass !== null)»
                    «d.getParent.name».class$MetaData(),
                «ELSE»
                    null,
                «ENDIF»
                // now specific class items
                _REVISION,
                serialVersionUID,
                «d.fields.size»,
                my$fields,
                property$Map,
                «propertiesInherited»,
                «d.root.immutable»,
                «d.freezable»
                «IF d.externalType !== null»
                    , «d.singleField»,
                    "«d.externalType.qualifiedName»",
                    "«d.adapterClassName»"
                «ENDIF»
            );

            // get all the meta data in one go
            static public ClassDefinition class$MetaData() {
                return my$MetaData;
            }

            // some methods intentionally use the $ sign, because use in normal code is discouraged, so we expect
            // no namespace conflicts here
            // must be repeated as a member method to make it available in the (extended) interface
            // feature of extended BonaPortable, not in the core interface
            @Override
            @Deprecated
            public ClassDefinition get$MetaData() {
                return my$MetaData;
            }
            @Override
            @Deprecated
            public long get$Serial() {
                return serialVersionUID;
            }
            @Override
            public String get$Revision() {
                return _REVISION;
            }

            «writeCommonMetaData»

            // the metadata instance
            public static enum BClass implements BonaPortableClass<«d.name»> {
                INSTANCE;

                public static BClass getInstance() {
                    return INSTANCE;
                }

                @Override
                public «d.name» newInstance() {
                    «IF d.abstract»
                        throw new UnsupportedOperationException("«d.name» is abstract");
                    «ELSE»
                        return new «d.name»();
                    «ENDIF»
                }

                @Override
                public Class<«d.name»> getBonaPortableClass() {
                    return «d.name».class;
                }

                @Override
                public int getFactoryId() {
                    return «d.effectiveFactoryId»;
                }
                @Override
                public int getId() {
                    «IF d.hazelcastId == 0»
                        return MY_RTTI;        // reuse of the rtti
                    «ELSE»
                        return «d.hazelcastId»;
                    «ENDIF»
                }
                @Override
                public int getRtti() {
                    return MY_RTTI;
                }
                @Override
                public String getPqon() {
                    return _PARTIALLY_QUALIFIED_CLASS_NAME;
                }
                @Override
                public boolean isFreezable() {
                    return «d.freezable»;
                }
                @Override
                public boolean isImmutable() {
                    return «d.root.immutable»;
                }
                @Override
                public String getBundle() {
                    return _BUNDLE;
                }
                @Override
                public String getRevision() {
                    return _REVISION;
                }
                @Override
                public long getSerial() {
                    return serialVersionUID;
                }
                @Override
                public ClassDefinition getMetaData() {
                    return my$MetaData;
                }
                @Override
                public BonaPortableClass<? extends BonaPortable> getParent() {
                    «IF (d.extendsClass !== null)»
                        return «d.extendsClass.classRef.name».BClass.getInstance();
                    «ELSE»
                        return null;
                    «ENDIF»
                }
                @Override
                public BonaPortableClass<? extends BonaPortable> getReturns() {
                    «IF (d.returnsClassRef !== null)»
                        return «d.returnsClassRef.classRef.name».BClass.getInstance();
                    «ELSE»
                        return null;
                    «ENDIF»
                }
                @Override
                public BonaPortableClass<? extends BonaPortable> getPrimaryKey() {
                    «IF (d.pkClass !== null)»
                        return «d.pkClass.name».BClass.getInstance();
                    «ELSE»
                        return null;
                    «ENDIF»
                }
                @Override
                public ImmutableMap<String,String> getPropertyMap() {
                    return property$Map;
                }
                @Override
                public String getClassProperty(String id) {
                    return «d.name».class$Property(id);
                }
                @Override
                public String getFieldProperty(String fieldname, String propertyname) {
                    return «d.name».field$Property(fieldname, propertyname);
                }
                @Override
                public boolean hasClassProperty(String id) {
                    return «d.name».class$hasProperty(id);
                }
                @Override
                public boolean hasFieldProperty(String fieldname, String propertyname) {
                    return «d.name».field$hasProperty(fieldname, propertyname);
                }

            }
            
            @Override
            public BonaPortableClass<? extends BonaPortable> get$BonaPortableClass() {
                return BClass.getInstance();
            }
            
        '''
    }
    
    // write the access methods for the interface BonaMeta
    def static public writeCommonMetaData() '''
        // convenience functions for faster access if the metadata structure is not used
        @Override
        public String get$PQON() {
            return _PARTIALLY_QUALIFIED_CLASS_NAME;
        }
        @Override
        public String get$Parent() {
            return _PARENT;
        }
        @Override
        public String get$Bundle() {
            return _BUNDLE;
        }
    '''
}
