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

    def private static jsonJavaType(FieldDefinition c, String nativetype) {
        if (c.properties.hasProperty(PROP_COMPACT))
            return "byte []"
        else if (c.properties.hasProperty(PROP_NATIVE))
            return nativetype
        else
            return "String" // default storage type
    }

    def private CharSequence writeColumnType(FieldDefinition c, String myName, boolean doBeanVal) {
        val prefs = BDDLPreferences.currentPrefs
        val DataTypeExtension ref = DataTypeExtension::get(c.datatype)

        if (ref.objectDataType !== null) {
            if (c.properties.hasProperty(PROP_SERIALIZED)) {

                // use byte[] Java type and assume same as Object
                if (prefs.doUserTypeForBonaPortable)
                    return '''«fieldVisibility»«JavaDataTypeNoName(c, c.properties.hasProperty(PROP_UNROLL))» «myName»;'''
                else
                    return '''«fieldVisibility»byte [] «myName»;'''
            } else if (c.properties.hasProperty(PROP_REF)) {

                // plain old Long as an artificial key / referencing is done by application
                // can optionally have a ManyToOne object mapping in a Java superclass, with insertable=false, updatable=false
                // FIXME: The type is not always a Long, it is defined by the target entity
                return '''«fieldVisibility»Long «myName»;'''
            } else if (ref.objectDataType.isSingleField) {         // depending on settings, either convert a usertype directly or use a JPA 2.1 Converter and insert the field 1:1 here
                if (BDDLPreferences.currentPrefs.doUserTypeForSFExternals) {
                    // 1:1 use of the field, work is done in the Converter
                    return '''«fieldVisibility»«ref.objectDataType.externalName» «myName»;'''           // qualifiedName required?
                } else {
                    val newField = ref.objectDataType.firstField
                    val newRef = DataTypeExtension::get(newField.datatype)
                    // manual conversion in the getters / setters. Use the converted field here. Recursive call of the same method. (Nested conversions won't work!)
                    // repeat the bean val annotations here. Due to the type, the first ones will at maximum have been NotNull, and the second won't repeat that because first fields are always nullable.
                    return '''
                        «JavaBeanValidation::writeAnnotations(newField, newRef, doBeanVal, !c.isNotNullField)»
                        «writeColumnType(newField, myName, doBeanVal)»
                    '''
                }
//            } else if (c.properties.hasProperty("ManyToOne")) {     // TODO: undocumented and also unused feature. Remove it?
//                // child object, create single-sided many to one annotations as well
//                val params = c.properties.getProperty("ManyToOne")
//                return '''
//                @ManyToOne«IF params !== null»(«params»)«ENDIF»
//                «IF c.properties.getProperty("JoinColumn") !== null»
//                    @JoinColumn(«c.properties.getProperty("JoinColumn")»)
//                «ELSEIF c.properties.getProperty("JoinColumnRO") !== null»
//                    @JoinColumn(«c.properties.getProperty("JoinColumnRO")», insertable=false, updatable=false)  // have a separate Long property field for updates
//                «ENDIF»
//                «fieldVisibility»«c.JavaDataTypeNoName(false)» «myName»;'''
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

                    case DataTypeExtension.JAVA_JSON_TYPE:
                        writeField(c, ref, myName, false, c.jsonJavaType("NativeJsonObject"),  null, null)
                    case DataTypeExtension.JAVA_ARRAY_TYPE:
                        writeField(c, ref, myName, false, c.jsonJavaType("NativeJsonArray"),   null, null)
                    case DataTypeExtension.JAVA_ELEMENT_TYPE:
                        writeField(c, ref, myName, false, c.jsonJavaType("NativeJsonElement"), null, null)
                    case DataTypeExtension.JAVA_OBJECT_TYPE:
                        if (prefs.doUserTypeForBonaPortable)
                            return '''«fieldVisibility»«JavaDataTypeNoName(c, c.properties.hasProperty(PROP_UNROLL))» «myName»;'''
                        else
                            '''
                                // @Lob
                                «writeField(c, ref, myName, false, "byte []", null, null)»
                            '''
                    default: '''«fieldVisibility»«JavaDataTypeNoName(c, c.properties.hasProperty(PROP_UNROLL))» «myName»;'''
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

        if (ref.category == DataCategory::ENUMSETALPHA && !prefs.doUserTypeForEnumset) {
            val es = ref.elementaryDataType.enumsetType
            return ''', length=«ref.enumMaxTokenLength * es.myEnum.avalues.size»'''     // same size as in SqlMapping
        }

        if ((ref.category == DataCategory::XENUM && !prefs.doUserTypeForXEnum) ||
            (ref.category == DataCategory::ENUMALPHA && !prefs.doUserTypeForEnumAlpha))
            return ''', length=«ref.enumMaxTokenLength»'''

        if (ref.elementaryDataType !== null && ref.elementaryDataType.name.toLowerCase.equals("decimal"))
            return ''', precision=«ref.elementaryDataType.length», scale=«ref.elementaryDataType.decimals»'''
        if (ref.category == DataCategory::BASICNUMERIC && ref.elementaryDataType !== null && ref.elementaryDataType.length > 0)
            return ''', precision=«ref.elementaryDataType.length»'''  // stored fixed point numbers as integral numbers on the DB, but refer to their max number of digits

        // use manual specification as a last resort (for example for serialized fields if lob is not desired)
        if (c.properties.hasProperty(PROP_LENGTH))
            return ''', length=«c.properties.getProperty(PROP_LENGTH)»'''
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

    def private static String writeUnmarshaller(String fieldname, String exceptionClass, CharSequence expression) '''
        try {
            return «expression»;
        } catch («exceptionClass» _e) {
            DeserializeExceptionHandler.exceptionHandler("«fieldname»", «fieldname», _e, getClass(), ret$Key());  // throws
            return null; // make JAVA happy
        }
    '''

    def private writeGetterAndSetter(FieldDefinition i, String myName, ClassDefinition optionalClass) {
        val prefs = BDDLPreferences.currentPrefs
        val ref = DataTypeExtension::get(i.datatype);
        val theEnum = ref.enumForEnumOrXenum
        val nwz = i.properties.hasProperty(PROP_NULL_WHEN_ZERO)
        val nwzData = i.properties.getProperty(PROP_NULL_WHEN_ZERO)
        val dtoName = if (optionalClass !== null) optionalClass.name else "NO_SERIALIZED_DATA_IN_PK_ALLOWED"  // optionalClass will be null if we are creating data for a PK. That should be OK

        var String getter = '''return «myName»;'''
        var String setter = '''«myName» = _x;'''

        if (ref.category == DataCategory.ENUM) {
            if (!prefs.doUserTypeForEnum) {
                getter = '''return «ref.elementaryDataType.enumType.name».valueOf(«myName»);'''
                setter = '''«myName» = _x == null ? null : _x.ordinal();'''
            }
        } else if (ref.category == DataCategory.ENUMALPHA) {
            if (!prefs.doUserTypeForEnumAlpha) {
                getter = '''return «theEnum.name».factoryNWZ(«myName»);'''
                setter = '''«myName» = «ref.elementaryDataType.enumType.name».getTokenNWZ(_x);'''
            }
        } else if (ref.category == DataCategory.XENUM) {
            if (!prefs.doUserTypeForXEnum) {
                getter = '''return «ref.xEnumFactoryName».getByTokenWithNull(«myName»);'''
                setter = '''«myName» = _x == null || _x == «ref.xEnumFactoryName».getNullToken() ? null : _x.getToken();'''
            }
        } else if (ref.category == DataCategory.OBJECT) {
            if (DataTypeExtension.JAVA_OBJECT_TYPE.equals(ref.javaType) || (ref.objectDataType !== null && hasProperty(i.properties, PROP_SERIALIZED))) {
                // BonaPortable or Object with "serialized" property
                if (!prefs.doUserTypeForBonaPortable) {
                    val prefix = if (i.properties.hasProperty(PROP_COMPACT)) "Compact"
                    val expectedClass = if (ref.objectDataType !== null) i.JavaDataTypeNoName(false) else "BonaPortable"
                    getter = writeUnmarshaller(myName, "MessageParserException", '''«prefix»ByteArrayParser.unmarshal(«myName», «dtoName».meta$$«myName», «expectedClass».class)''')
                    setter = '''«myName» = «prefix»ByteArrayComposer.marshal(«dtoName».meta$$«myName», _x);'''
                } // else stay with the default (fall through)
            } else if (ref.elementaryDataType !== null) {
                // JSON, ARRAY or ELEMENT
                if (DataTypeExtension.JAVA_ELEMENT_TYPE.equals(ref.javaType)) {
                    // Element => store in compact serialized form by default
                    if (i.properties.hasProperty(PROP_COMPACT)) {
                        getter = writeUnmarshaller(myName, "MessageParserException", '''CompactByteArrayParser.unmarshalElement(«myName», «dtoName».meta$$«myName»)''')
                        setter = '''«myName» = CompactByteArrayComposer.marshalAsElement(«dtoName».meta$$«myName», _x);'''
                    } else if (i.properties.hasProperty(PROP_NATIVE)) {
                        // assign the wrapper object
                        getter = '''return «myName» == null ? null : «myName».getData();'''
                        setter = '''«myName» = _x == null ? null : new NativeJsonElement(_x);'''
                    } else {
                        // default: text JSON
                        getter = writeUnmarshaller(myName, "JsonException", '''«myName» == null ? null : new JsonParser(«myName», false).parseElement()''')
                        setter = '''«myName» = BonaparteJsonEscaper.asJson(_x);'''
                    }
                } else if (DataTypeExtension.JAVA_ARRAY_TYPE.equals(ref.javaType)) {
                    // Element => store in compact serialized form by default
                    if (i.properties.hasProperty(PROP_COMPACT)) {
                        getter = writeUnmarshaller(myName, "MessageParserException", '''CompactByteArrayParser.unmarshalArray(«myName», «dtoName».meta$$«myName»)''')
                        setter = '''«myName» = CompactByteArrayComposer.marshalAsArray(«dtoName».meta$$«myName», _x);'''
                    } else if (i.properties.hasProperty(PROP_NATIVE)) {
                        // assign the wrapper object
                        getter = '''return «myName» == null ? null : «myName».getData();'''
                        setter = '''«myName» = _x == null ? null : new NativeJsonArray(_x);'''
                    } else {
                        // default: text JSON
                        getter = writeUnmarshaller(myName, "JsonException", '''«myName» == null ? null : new JsonParser(«myName», false).parseArray()''')
                        setter = '''«myName» = BonaparteJsonEscaper.asJson(_x);'''
                    }
                } else if (DataTypeExtension.JAVA_JSON_TYPE.equals(ref.javaType)) {
                    // Element => store in compact serialized form by default
                    if (i.properties.hasProperty(PROP_COMPACT)) {
                        getter = writeUnmarshaller(myName, "MessageParserException", '''CompactByteArrayParser.unmarshalJson(«myName», «dtoName».meta$$«myName»)''')
                        setter = '''«myName» = CompactByteArrayComposer.marshalAsJson(«dtoName».meta$$«myName», _x);'''
                    } else if (i.properties.hasProperty(PROP_NATIVE)) {
                        // assign the wrapper object
                        getter = '''return «myName» == null ? null : «myName».getData();'''
                        setter = '''«myName» = _x == null ? null : new NativeJsonObject(_x);'''
                    } else {
                        // default: text JSON
                        getter = writeUnmarshaller(myName, "JsonException", '''«myName» == null ? null : new JsonParser(«myName», false).parseObject()''')
                        setter = '''«myName» = BonaparteJsonEscaper.asJson(_x);'''
                    }
                } else {
                    // JSON: fall through (done via user type)
                }
            } else if (ref.objectDataType !== null) {
                // anything else with object type
                if (ref.objectDataType.isSingleField && !prefs.doUserTypeForSFExternals) {
                    val extraArg =
                        if (i.datatype.extraParameterString !== null)
                            '''«i.datatype.extraParameterString», '''
                        else if (i.datatype.extraParameter !== null)
                            '''get«i.datatype.extraParameter.name.toFirstUpper»(), '''
                    // check for a possible exception converter parameter
                    val exceptionConverterArg = if (ref.objectDataType.exceptionConverter) EXC_CVT_ARG
                    getter = '''return «myName» == null ? «IF nwz»new «ref.javaType»(«nwzData»)«ELSE»null«ENDIF» : «ref.objectDataType.adapterClassName».unmarshal(«extraArg»«myName»«exceptionConverterArg»);'''
                    setter = '''«myName» = _x == null«IF nwz» || _x.isEmpty()«ENDIF» ? null : «IF ref.objectDataType.bonaparteAdapterClass === null»_x.marshal()«ELSE»«ref.objectDataType.bonaparteAdapterClass».marshal(_x)«ENDIF»;'''
                }
            }
            // fall through to default
        } else if (ref.category == DataCategory::XENUMSET || ref.category == DataCategory::ENUMSET || ref.category == DataCategory::ENUMSETALPHA) {
            if (!prefs.doUserTypeForEnumset) {
                getter = '''return «myName» == null ? «IF nwz»new «ref.javaType»(«nwzData»)«ELSE»null«ENDIF» : new «ref.javaType»(«myName»);'''
                setter = '''«myName» = _x == null«IF nwz» || _x.isEmpty()«ENDIF» ? null : _x.getBitmap();'''
            }
        } else if (ref.javaType.equals("LocalTime") || ref.javaType.equals("LocalDate") || ref.javaType.equals("LocalDateTime")) {
            if (!useUserTypes) {
                getter = '''return «myName» == null ? null : «ref.javaType».from«JDBC4TYPE»Fields(«myName»);'''
                setter = '''«myName» = DayTime.to«JDBC4TYPE»(_x);'''
            }
        } else if (ref.javaType.equals("Instant")) {
            if (!useUserTypes) {
                getter = '''return «myName» == null ? null : new Instant(«myName»);'''
                setter = '''«myName» = _x == null ? null ? _x.to«JDBC4TYPE»();'''
            }
        } else if (ref.javaType.equals("ByteArray")) {
            if (!useUserTypes) {
                getter = '''return «myName» == null ? null : new ByteArray(«myName», 0, -1);'''
                setter = '''«myName» = _x == null ? null : _x.getBytes();'''
            }
        } else if (ref.javaType.equals("byte []")) {
            // no second condition here? Adding a user type for byte arrays does not make sense.
            getter = '''return ByteUtil.deepCopy(«myName»);       // deep copy'''
            setter = '''«myName» = ByteUtil.deepCopy(_x);       // deep copy'''
        } // else stay with the default

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
                                _r.put(_i.getKey(), _i.getValue().ret$Data());
                        «ELSE»
                            for («embName» _i : «f.name»)
                                _r.add(_i.ret$Data());
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
                                    _ec.put$Data(_i.getValue());
                                    «f.name».put(_i.getKey(), _ec);
                                }
                            «ELSE»
                                for («f.JavaDataTypeNoName(true)» _i : _d) {
                                    «embName» _ec = new «embName»();
                                    _ec.put$Data(_i);
                                    «f.name».add(_ec);
                                }
                            «ENDIF»
                        }
                    }
                «ENDIF»
            «ELSE»
                «IF f.shouldWriteColumn || relevantEmbeddable !== null»
                    @Column(name="«myName.java2sql»"«IF f.isNotNullField», nullable=false«ENDIF»«f.sizeSpec»«IF hasProperty(f.properties,
                    "noinsert")», insertable=false«ENDIF»«IF hasProperty(f.properties, "noupdate")», updatable=false«ENDIF»)
                    «f.properties.optionalAnnotation("version", "@Version")»
                    «f.properties.optionalAnnotation("lob", "@Lob")»
                    «f.properties.optionalAnnotation("lazy", "@Basic(fetch=FetchType.LAZY)")»
                    «JavaBeanValidation::writeAnnotations(f, DataTypeExtension::get(f.datatype), doBeanVal, !f.isNotNullField)»
                    «f.writeColumnType(myName, doBeanVal)»
                    «f.writeGetterAndSetter(myName, optionalClass)»
                «ENDIF»
            «ENDIF»
        '''
    }
    
    def public static boolean shouldWriteColumn(FieldDefinition c) {
        val ref = DataTypeExtension::get(c.datatype)
        if (ref.objectDataType === null)
            return true;  // any elementary data type filters already applied before
        // is an object reference: here we only do fields if they are ref or serialized 
        if (c.properties.hasProperty(PROP_REF) || c.properties.hasProperty(PROP_SIMPLEREF) || c.properties.hasProperty(PROP_SERIALIZED))
            return true
        // if the referenced object is a single-field adapter, then as well
        if (ref.objectDataType.isSingleField)
            return true
        return false
    }
}
