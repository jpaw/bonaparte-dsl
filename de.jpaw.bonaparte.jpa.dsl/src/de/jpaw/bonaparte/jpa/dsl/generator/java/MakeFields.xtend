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
package de.jpaw.bonaparte.jpa.dsl.generator.java

import de.jpaw.bonaparte.dsl.generator.DataCategory
import static extension de.jpaw.bonaparte.dsl.generator.Util.*
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.jpa.dsl.generator.YUtil.*
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.bonScript.PropertyUse
import java.util.List
import de.jpaw.bonaparte.dsl.generator.java.JavaBeanValidation
import de.jpaw.bonaparte.jpa.dsl.bDDL.ElementCollectionRelationship
import de.jpaw.bonaparte.jpa.dsl.bDDL.EntityDefinition
import de.jpaw.bonaparte.dsl.bonScript.Visibility
import de.jpaw.bonaparte.dsl.bonScript.XVisibility
import de.jpaw.bonaparte.jpa.dsl.bDDL.EmbeddableDefinition
import de.jpaw.bonaparte.jpa.dsl.bDDL.EmbeddableUse
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.jpa.dsl.bDDL.BDDLPackageDefinition
import de.jpaw.bonaparte.jpa.dsl.BDDLPreferences

class JavaFieldWriter {
    val static final String JAVA_OBJECT_TYPE = "BonaPortable";
    val static final String EXC_CVT_ARG = ", de.jpaw.bonaparte.core.RuntimeExceptionConverter.INSTANCE"
    val static final String JDBC4TYPE = "Date";  // choose Calendar or Date
    final boolean useUserTypes;
    final String fieldVisibility;

    def private static String makeVisibility(Visibility v) {
        var XVisibility fieldScope
        if (v !== null && v.x !== null)
            fieldScope = v.x
        if (fieldScope === null || fieldScope == XVisibility::DEFAULT)
            ""
        else
            fieldScope.toString() + " "
    }

    def public static final defineVisibility(EntityDefinition e) {
        val myPackage = e.eContainer as BDDLPackageDefinition
        return makeVisibility(if(e.visibility !== null) e.visibility else myPackage.getVisibility)
    }

    new(EntityDefinition e) {
        this.useUserTypes = !(e.eContainer as BDDLPackageDefinition).isNoUserTypes;
        this.fieldVisibility = defineVisibility(e);
    }

    new(EmbeddableDefinition e) {
        this.useUserTypes = !(e.eContainer as BDDLPackageDefinition).isNoUserTypes;
        this.fieldVisibility = makeVisibility((e.eContainer as BDDLPackageDefinition).getVisibility);
    }

    // the same, more complex scenario
    def private static JavaDataType2NoName(FieldDefinition i, boolean skipIndex, String dataClass) {
        if (skipIndex || i.properties.hasProperty(PROP_UNROLL))
            dataClass
        else if (i.isArray !== null)
            dataClass + "[]"
        else if (i.isSet !== null)
            "Set<" + dataClass + ">"
        else if (i.isList !== null)
            "List<" + dataClass + ">"
        else if (i.isMap !== null)
            "Map<" + i.isMap.indexType + "," + dataClass + ">"
        else
            dataClass
    }

    // temporal types for UserType mappings (OR mapper specific extensions)
    def private writeField(FieldDefinition c, DataTypeExtension ref, String myName, boolean useUserType, String replacementType, CharSequence defaultValue, CharSequence extraAnnotationType) '''
        «IF useUserType»
            «fieldVisibility»«c.JavaDataType2NoName(false, ref.javaType)» «myName»;
        «ELSE»
            «IF extraAnnotationType !== null»@Temporal(TemporalType.«extraAnnotationType»)«ENDIF»
            «fieldVisibility»«c.JavaDataType2NoName(false, replacementType)» «myName»«defaultValue»;
        «ENDIF»
    '''

    def private CharSequence writeColumnType(FieldDefinition c, String myName, boolean doBeanVal) {
        val prefs = BDDLPreferences.currentPrefs
        val DataTypeExtension ref = DataTypeExtension::get(c.datatype)
        
        if (ref.objectDataType !== null) {
            if (c.properties.hasProperty(PROP_SERIALIZED)) {

                // use byte[] Java type and assume same as Object
                return '''
                    «fieldVisibility»byte [] «myName»;'''
            } else if (c.properties.hasProperty(PROP_REF)) {

                // plain old Long as an artificial key / referencing is done by application
                // can optionally have a ManyToOne object mapping in a Java superclass, with insertable=false, updatable=false
                return '''
                    «fieldVisibility»Long «myName»;'''
            } else if (ref.objectDataType.isSingleField) {         // depending on settings, either convert a usertype directly or use a JPA 2.1 Converter and insert the field 1:1 here
                if (BDDLPreferences.currentPrefs.doUserTypeForSFExternals) {
                    // 1:1 use of the field, work is done in the Converter
                    return '''
                        «fieldVisibility»«ref.objectDataType.externalType.simpleName» «myName»;'''           // qualifiedName required?
                } else {
                    // manual conversion in the getters / setters. Use the converted field here. Recursive call of the same method. (Nested conversions won't work!)
                    // repeat the bean val annotations here. Due to the type, the first ones will at maximum have been NotNull, and the second won#t repeat that because first fields are always nullable.
                    return '''
                        «JavaBeanValidation::writeAnnotations(c, ref, doBeanVal)»
                        «writeColumnType(ref.objectDataType.firstField, myName, doBeanVal)»
                    '''
                }
            } else if (c.properties.hasProperty("ManyToOne")) {     // TODO: undocumented and also unused feature. Remove it?
                // child object, create single-sided many to one annotations as well
                val params = c.properties.getProperty("ManyToOne")
                return '''
                @ManyToOne«IF params !== null»(«params»)«ENDIF»
                «IF c.properties.getProperty("JoinColumn") !== null»
                    @JoinColumn(«c.properties.getProperty("JoinColumn")»)
                «ELSEIF c.properties.getProperty("JoinColumnRO") !== null»
                    @JoinColumn(«c.properties.getProperty("JoinColumnRO")», insertable=false, updatable=false)  // have a separate Long property field for updates
                «ENDIF»
                «fieldVisibility»«c.JavaDataTypeNoName(false)» «myName»;'''
            }
        }
        return switch (ref.category) {
            case DataCategory.ENUM:
                writeField(c, ref, myName, prefs.doUserTypeForEnum,          "Integer", makeEnumNumDefault(c, ref), null)
            case DataCategory.ENUMALPHA:
                writeField(c, ref, myName, prefs.doUserTypeForEnumAlpha,     "String", makeEnumAlphanumDefault(c, ref), null)
            case DataCategory.XENUM:
                writeField(c, ref, myName, prefs.doUserTypeForXEnum,         "String", makeEnumAlphanumDefault(c, ref), null)
            case DataCategory.ENUMSET:
                writeField(c, ref, myName, prefs.doUserTypeForEnumset,       ref.elementaryDataType.enumsetType.mapEnumSetIndex, null, null)
            case DataCategory.ENUMSETALPHA:
                writeField(c, ref, myName, prefs.doUserTypeForEnumset,      "String", null, null)
            case DataCategory.XENUMSET:
                writeField(c, ref, myName, prefs.doUserTypeForEnumset,      "String", null, null)
            default: {
                switch (ref.javaType) {
                    case "LocalTime":
                        writeField(c, ref, myName, useUserTypes, JDBC4TYPE, null, "TIME")
                    case "LocalDateTime":
                        writeField(c, ref, myName, useUserTypes, JDBC4TYPE, null, "TIMESTAMP")
                    case "LocalDate":
                        writeField(c, ref, myName, useUserTypes, JDBC4TYPE, null, "DATE")
                    case "Instant":
                        writeField(c, ref, myName, useUserTypes, JDBC4TYPE, null, "TIMESTAMP")
                    case "ByteArray":
                        writeField(c, ref, myName, useUserTypes, "byte []", null, null)
                    case JAVA_OBJECT_TYPE: '''
                        // @Lob
                        «writeField(c, ref, myName, false, "byte []", null, null)»
                    '''
                    default: '''
                        «fieldVisibility»«JavaDataTypeNoName(c, c.properties.hasProperty(PROP_UNROLL))» «myName»;
                    '''
                }
            }
        }
    }

    def private static makeEnumNumDefault(FieldDefinition f, DataTypeExtension ref) {
        if (ref.effectiveEnumDefault && (!f.aggregate || f.properties.hasProperty(PROP_UNROLL))) ''' = 0''' else ''''''
    }

    def private static makeEnumAlphanumDefault(FieldDefinition f, DataTypeExtension ref) {
        if (ref.effectiveEnumDefault && (!f.aggregate || f.properties.hasProperty(PROP_UNROLL))) ''' = "«ref.
            elementaryDataType.enumType.avalues.get(0).token.escapeString2Java»"''' else ''''''
    }

    def private static optionalAnnotation(List<PropertyUse> properties, String key, String annotation) {
        '''«IF properties.hasProperty(key)»«annotation»«ENDIF»'''
    }

    // write a @Size annotation for string based types and limited integral types
    def private static sizeSpec(FieldDefinition c) {
        val prefs = BDDLPreferences.currentPrefs
        val ref = DataTypeExtension::get(c.datatype);
        
        if (ref.category == DataCategory::STRING ||
            (ref.category == DataCategory::XENUMSET && !prefs.doUserTypeForEnumset))
            return ''', length=«ref.elementaryDataType.length»'''
            
        if ((ref.category == DataCategory::XENUM && !prefs.doUserTypeForXEnum) ||
            (ref.category == DataCategory::ENUMALPHA && !prefs.doUserTypeForEnumAlpha)||
            (ref.category == DataCategory::ENUMSETALPHA && !prefs.doUserTypeForEnumset))
            return ''', length=«ref.enumMaxTokenLength»'''
            
        if (ref.elementaryDataType !== null && ref.elementaryDataType.name.toLowerCase.equals("decimal"))
            return ''', precision=«ref.elementaryDataType.length», scale=«ref.elementaryDataType.decimals»'''
        if (ref.category == DataCategory::BASICNUMERIC && ref.elementaryDataType !== null && ref.elementaryDataType.length > 0)
            return ''', precision=«ref.elementaryDataType.length»'''  // stored fixed point numbers as integral numbers on the DB, but refer to their max number of digits
        return ''''''
    }

    def private static substitutedJavaTypeScalar(FieldDefinition i) {
        val ref = DataTypeExtension::get(i.datatype);
        if (ref.objectDataType !== null) {
            if (i.properties.hasProperty(PROP_REF))
                return "Long"
        }
        return i.JavaDataTypeNoName(i.properties.hasProperty(PROP_UNROLL))
    }

    def private writeGetterAndSetter(FieldDefinition i, String myName, ClassDefinition optionalClass) {
        val prefs = BDDLPreferences.currentPrefs
        val ref = DataTypeExtension::get(i.datatype);
        val theEnum = ref.enumForEnumOrXenum
        val nwz = i.properties.hasProperty(PROP_NULL_WHEN_ZERO)
        val nwzData = i.properties.getProperty(PROP_NULL_WHEN_ZERO)
        val dtoName = if (optionalClass !== null) optionalClass.name else "NO_SERIALIZED_DATA_IN_PK_ALLOWED"  // optionalClass will be null if we are creating data for a PK. That should be OK

        var String getter
        var String setter
                
        if (JAVA_OBJECT_TYPE.equals(ref.javaType) || (ref.objectDataType !== null && hasProperty(i.properties, PROP_SERIALIZED))) {
            getter = '''
                    if («myName» == null)
                        return null;
                    try {
                        «IF hasProperty(i.properties, PROP_COMPACT)»
                            CompactByteArrayParser _bap = new CompactByteArrayParser(«myName», 0, -1);
                        «ELSE»
                            ByteArrayParser _bap = new ByteArrayParser(«myName», 0, -1);
                        «ENDIF»
                        «IF ref.objectDataType !== null»
                            return («JavaDataTypeNoName(i, false)»)_bap.readObject(«dtoName».meta$$«myName», «JavaDataTypeNoName(i, false)».class);
                        «ELSE»
                            return _bap.readObject(«dtoName».meta$$«myName», BonaPortable.class);
                        «ENDIF»
                    } catch (MessageParserException _e) {
                        DeserializeExceptionHandler.exceptionHandler("«myName»", «myName», _e, getClass(), get$Key().toString());
                        return null;
                    }'''
            setter = '''
                    if (_x == null) {
                        «myName» = null;
                    } else {
                        «IF hasProperty(i.properties, PROP_COMPACT)»
                            CompactByteArrayComposer _bac = new CompactByteArrayComposer();
                        «ELSE»
                            ByteArrayComposer _bac = new ByteArrayComposer();
                        «ENDIF»
                        _bac.addField(StaticMeta.OUTER_BONAPORTABLE, _x);
                        «myName» = _bac.getBytes();
                    }'''
        } else if (ref.category == DataCategory.ENUM) {
            getter = '''return «IF prefs.doUserTypeForEnum»«myName»«ELSE»«ref.elementaryDataType.enumType.name».valueOf(«myName»)«ENDIF»;'''
            setter = '''«myName» = _x«IF !prefs.doUserTypeForEnum» == null ? null : _x.ordinal()«ENDIF»;'''
        } else if (ref.category == DataCategory.ENUMALPHA) {
            getter = '''return «IF prefs.doUserTypeForEnumAlpha»«myName»«ELSE»«theEnum.name».factoryNWZ(«myName»)«ENDIF»;'''
            setter = '''«myName» = «IF prefs.doUserTypeForEnumAlpha»_x«ELSE»«ref.elementaryDataType.enumType.name».getTokenNWZ(_x)«ENDIF»;'''
        } else if (ref.category == DataCategory.XENUM) {
            getter = '''return «IF prefs.doUserTypeForXEnum»«myName»«ELSE»«ref.xEnumFactoryName».getByTokenWithNull(«myName»)«ENDIF»;'''
            setter = '''«myName» = _x«IF !prefs.doUserTypeForXEnum» == null || _x == «ref.xEnumFactoryName».getNullToken() ? null : _x.getToken()«ENDIF»;'''
        } else if (ref.category == DataCategory.OBJECT) {
            getter = '''return «myName»«IF ref.objectDataType.isSingleField && !prefs.doUserTypeForSFExternals» == null ? «IF nwz»new «ref.javaType»(«nwzData»)«ELSE»null«ENDIF» : «ref.objectDataType.adapterClassName».unmarshal(«myName»«IF ref.objectDataType.exceptionConverter»«EXC_CVT_ARG»«ENDIF»)«ENDIF»;'''
            setter = '''«myName» = _x«IF ref.objectDataType.isSingleField && !prefs.doUserTypeForSFExternals» == null«IF nwz» || _x.isEmpty()«ENDIF» ? null : «IF ref.objectDataType.bonaparteAdapterClass === null»_x.marshal()«ELSE»«ref.objectDataType.bonaparteAdapterClass».marshal(_x)«ENDIF»«ENDIF»;'''
        } else if (ref.category == DataCategory::XENUMSET || ref.category == DataCategory::ENUMSET || ref.category == DataCategory::ENUMSETALPHA) {
            getter = '''return «myName»«IF !prefs.doUserTypeForEnumset» == null ? «IF nwz»new «ref.javaType»(«nwzData»)«ELSE»null«ENDIF» : new «ref.javaType»(«myName»)«ENDIF»;'''
            setter = '''«myName» = _x«IF !prefs.doUserTypeForEnumset» == null«IF nwz» || _x.isEmpty()«ENDIF» ? null : _x.getBitmap()«ENDIF»;'''
        } else if (ref.javaType.equals("LocalTime") || ref.javaType.equals("LocalDate") || ref.javaType.equals("LocalDateTime")) {
            getter = '''return «myName»«IF !useUserTypes» == null ? null : «ref.javaType».from«JDBC4TYPE»Fields(«myName»)«ENDIF»;'''
            setter = '''«myName» = «IF useUserTypes»_x«ELSE»DayTime.to«JDBC4TYPE»(_x)«ENDIF»;'''
        } else if (ref.javaType.equals("Instant")) {
            getter = '''return «myName»«IF !useUserTypes» == null ? null : new Instant(«myName»)«ENDIF»;'''
            setter = '''«myName» = _x«IF !useUserTypes» == null ? null ? _x.to«JDBC4TYPE»()«ENDIF»;'''
        } else if (ref.javaType.equals("ByteArray")) {
            getter = '''return «myName»«IF !useUserTypes» == null ? null : new ByteArray(«myName», 0, -1)«ENDIF»;'''
            setter = '''«myName» = _x«IF !useUserTypes» == null ? null : _x.getBytes()«ENDIF»;'''
        } else if (ref.javaType.equals("byte []")) {
            getter = '''return ByteUtil.deepCopy(«myName»);       // deep copy'''
            setter = '''«myName» = ByteUtil.deepCopy(_x);       // deep copy'''
        } else {
            getter = '''return «myName»;'''
            setter = '''«myName» = _x;'''
        }
            
        return '''
            «i.writeIfDeprecated»
            public «i.substitutedJavaTypeScalar» get«myName.toFirstUpper»() {
                «getter»
            }
            
            «i.writeIfDeprecated»
            public void set«myName.toFirstUpper»(«i.substitutedJavaTypeScalar» _x) {
                «setter»
            }
        '''
    }

    def public buildEmbeddedId(EntityDefinition e) '''
        @EmbeddedId
        «fieldVisibility»«e.name»Key key;
        // forwarding getters and setters
        «FOR i : e.pk.columnName»
            public void set«i.name.toFirstUpper»(«i.substitutedJavaTypeScalar» _x) {
                key.set«i.name.toFirstUpper»(_x);
            }
            public «i.substitutedJavaTypeScalar» get«i.name.toFirstUpper»() {
                return key.get«i.name.toFirstUpper»();
            }
        «ENDFOR»
    '''

    def private static getInitializer(FieldDefinition f, String name, String initialLength) {
        val past = f.aggregateOf(name) + initialLength
        if (f.isList !== null)
            return "Array" + past
        else if (f.isSet !== null)
            return "LinkedHash" + past // LinkedHashSet preferred over HashSet due to certain ordering guarantee
        else if (f.isMap !== null)
            return "Hash" + past
        else
            return "ERROR, array not allowed here"
    }
    
    // write the definition of a single column (entities or Embeddables)
    def public writeColStuff(FieldDefinition f, List<ElementCollectionRelationship> el, boolean doBeanVal, String myName,
        List<EmbeddableUse> embeddables, ClassDefinition optionalClass) {
        val relevantElementCollection = el?.findFirst[name == f]
        val relevantEmbeddable = embeddables?.findFirst[field == f]
        // val emb = relevantEmbeddable?.name?.pojoType
        val embName = relevantEmbeddable?.name?.name
        // val ref = DataTypeExtension::get(f.datatype);

        return '''
            «IF relevantElementCollection !== null && f.aggregate»
                «ElementCollections::writePossibleCollectionOrRelation(f, relevantElementCollection)»
                «IF relevantEmbeddable === null»
                    @Column(name="«myName.java2sql»"«IF f.isNotNullField», nullable=false«ENDIF»)
                    «f.writeColumnType(myName, false)»
                    «f.writeGetterAndSetter(myName, optionalClass)»
                «ELSE»
                    «fieldVisibility»«f.aggregateOf(embName)» «myName» = new «f.getInitializer(embName, "(4)")»;
                    // special getter to convert from embeddable entity type into DTO
                    public «f.JavaDataTypeNoName(false)» get«myName.toFirstUpper»() {
                        if («f.name» == null || «f.name».isEmpty())
                            return null;
                        «f.JavaDataTypeNoName(false)» _r = new «f.getInitializer(f.JavaDataTypeNoName(true), '''(«f.name».size())''')»;
                        «IF f.isMap !== null»
                            for (Map.Entry<«f.isMap.indexType»,«embName»> _i : «f.name».entrySet())
                                _r.put(_i.getKey(), _i.getValue().get$Data());
                        «ELSE»
                            for («embName» _i : «f.name»)
                                _r.add(_i.get$Data());
                        «ENDIF»
                        return _r;
                    }
                    // special setter to convert from embeddable entity type into DTO
                    public void set«myName.toFirstUpper»(«f.JavaDataTypeNoName(false)» _d) {
                        «f.name».clear();
                        if (_d != null) {
                            «IF f.isMap !== null»
                                for (Map.Entry<«f.isMap.indexType»,«f.JavaDataTypeNoName(true)»> _i : _d.entrySet()) {
                                    «embName» _ec = new «embName»();
                                    _ec.set$Data(_i.getValue());
                                    «f.name».put(_i.getKey(), _ec);
                                }
                            «ELSE»
                                for («f.JavaDataTypeNoName(true)» _i : _d) {
                                    «embName» _ec = new «embName»();
                                    _ec.set$Data(_i);
                                    «f.name».add(_ec);
                                }
                            «ENDIF»
                        }
                    }
                «ENDIF»
            «ELSE»
                @Column(name="«myName.java2sql»"«IF f.isNotNullField», nullable=false«ENDIF»«f.sizeSpec»«IF hasProperty(f.properties,
                "noinsert")», insertable=false«ENDIF»«IF hasProperty(f.properties, "noupdate")», updatable=false«ENDIF»)
                «f.properties.optionalAnnotation("version", "@Version")»
                «f.properties.optionalAnnotation("lob", "@Lob")»
                «f.properties.optionalAnnotation("lazy", "@Basic(fetch=LAZY)")»
                «JavaBeanValidation::writeAnnotations(f, DataTypeExtension::get(f.datatype), doBeanVal)»
                «f.writeColumnType(myName, doBeanVal)»
                «f.writeGetterAndSetter(myName, optionalClass)»
            «ENDIF»
        '''
    }
}
