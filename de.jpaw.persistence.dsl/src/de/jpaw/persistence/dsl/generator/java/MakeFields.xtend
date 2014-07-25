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
package de.jpaw.persistence.dsl.generator.java

import de.jpaw.bonaparte.dsl.generator.DataCategory
import static extension de.jpaw.bonaparte.dsl.generator.Util.*
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.persistence.dsl.generator.YUtil.*
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.bonScript.PropertyUse
import java.util.List
import de.jpaw.bonaparte.dsl.generator.java.JavaBeanValidation
import de.jpaw.persistence.dsl.bDDL.ElementCollectionRelationship
import de.jpaw.persistence.dsl.bDDL.EntityDefinition
import de.jpaw.persistence.dsl.bDDL.PackageDefinition
import de.jpaw.bonaparte.dsl.bonScript.Visibility
import de.jpaw.bonaparte.dsl.bonScript.XVisibility
import de.jpaw.persistence.dsl.bDDL.EmbeddableDefinition
import de.jpaw.persistence.dsl.bDDL.EmbeddableUse

class JavaFieldWriter {
    val static final String JAVA_OBJECT_TYPE = "BonaPortable";
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
        val myPackage = e.eContainer as PackageDefinition
        return makeVisibility(if(e.visibility !== null) e.visibility else myPackage.visibility)
    }

    new(EntityDefinition e) {
        this.useUserTypes = !(e.eContainer as PackageDefinition).noUserTypes;
        this.fieldVisibility = defineVisibility(e);
    }

    new(EmbeddableDefinition e) {
        this.useUserTypes = !(e.eContainer as PackageDefinition).noUserTypes;
        this.fieldVisibility = makeVisibility((e.eContainer as PackageDefinition).visibility);
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
    def private writeTemporalFieldAndAnnotation(FieldDefinition c, String extraAnnotationType, String fieldType,
        String myName) '''
        @Temporal(TemporalType.«extraAnnotationType»)
        «fieldVisibility»«c.JavaDataType2NoName(false, fieldType)» «myName»;
    '''

    // temporal types for UserType mappings (OR mapper specific extensions)
    def private writeField(FieldDefinition c, String fieldType, String myName, CharSequence defaultValue) '''
        «fieldVisibility»«c.JavaDataType2NoName(false, fieldType)» «myName»«defaultValue»;
    '''

    def private writeColumnType(FieldDefinition c, String myName) {
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
            } else if (c.properties.hasProperty("ManyToOne")) {

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
        switch (ref.enumMaxTokenLength) {
            case DataTypeExtension::NO_ENUM:
                switch (ref.javaType) {
                    case "LocalTime":
                        if (useUserTypes)
                            writeField(c, ref.javaType, myName, "")
                        else
                            writeTemporalFieldAndAnnotation(c, "TIME", JDBC4TYPE, myName)
                    case "LocalDateTime":
                        if (useUserTypes)
                            writeField(c, ref.javaType, myName, "")
                        else
                            writeTemporalFieldAndAnnotation(c, "TIMESTAMP", JDBC4TYPE, myName)
                    case "LocalDate":
                        if (useUserTypes)
                            writeField(c, ref.javaType, myName, "")
                        else
                            writeTemporalFieldAndAnnotation(c, "DATE", JDBC4TYPE, myName)
                    case "Instant":
                        if (useUserTypes)
                            writeField(c, ref.javaType, myName, "")
                        else
                            writeTemporalFieldAndAnnotation(c, "TIMESTAMP", JDBC4TYPE, myName)
                    case "ByteArray":
                        writeField(c, if(useUserTypes) "ByteArray" else "byte []", myName, "")
                    case JAVA_OBJECT_TYPE: '''
                        // @Lob
                        «writeField(c, "byte []", myName, "")»
                    '''
                    default: '''
                        «fieldVisibility»«JavaDataTypeNoName(c, c.properties.hasProperty(PROP_UNROLL))» «myName»;
                    '''
                }
            case DataTypeExtension::ENUM_NUMERIC:
                writeField(c, "Integer", myName, makeEnumNumDefault(c, ref))
            default:
                writeField(c, if(ref.allTokensAscii) "String" else "Integer", myName, makeEnumAlphanumDefault(c, ref))
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

    // write a @Size annotation for string based types
    def private static sizeSpec(FieldDefinition c) {
        val ref = DataTypeExtension::get(c.datatype);
        if (ref.category == DataCategory::STRING)
            return ''', length=«ref.elementaryDataType.length»'''
        if (ref.elementaryDataType !== null && ref.elementaryDataType.name.toLowerCase.equals("decimal"))
            return ''', precision=«ref.elementaryDataType.length», scale=«ref.elementaryDataType.decimals»'''
        return ''''''
    }

    // return true, if this is a list with lower number of elements strictly less than the upper bound.
    // In such a case, the list could be shorter, and elements therefore cannot be assumed to be not null
    def private static isPartOfVariableLengthList(FieldDefinition c) {
        c.isList !== null && c.isList.mincount < c.isList.maxcount
    }

    def private static substitutedJavaTypeScalar(FieldDefinition i) {
        val ref = DataTypeExtension::get(i.datatype);
        if (ref.objectDataType !== null) {
            if (i.properties.hasProperty(PROP_REF))
                return "Long"
        }
        return i.JavaDataTypeNoName(i.properties.hasProperty(PROP_UNROLL))
    }

    def private writeGetter(FieldDefinition i, String myName) {
        val ref = DataTypeExtension::get(i.datatype);
        val theEnum = ref.enumForEnumOrXenum
        return '''
            public «i.substitutedJavaTypeScalar» get«myName.toFirstUpper»() {
                «IF JAVA_OBJECT_TYPE.equals(ref.javaType) ||
                (ref.objectDataType !== null && hasProperty(i.properties, PROP_SERIALIZED))»
                    if («myName» == null)
                        return null;
                    try {
                        «IF hasProperty(i.properties, PROP_COMPACT)»
                            CompactByteArrayParser _bap = new CompactByteArrayParser(«myName», 0, -1);
                        «ELSE»
                            ByteArrayParser _bap = new ByteArrayParser(«myName», 0, -1);
                        «ENDIF»
                        return «IF ref.objectDataType !== null»(«JavaDataTypeNoName(i, false)»)«ENDIF»_bap.readObject("«myName»", «IF ref.objectDataType !== null»«JavaDataTypeNoName(i, false)»«ELSE»BonaPortable«ENDIF».class, true, true);
                    } catch (MessageParserException _e) {
                        DeserializeExceptionHandler.exceptionHandler("«myName»", «myName», _e, getClass(), get$Key().toString());
                        return null;
                    }
                «ELSEIF ref.enumMaxTokenLength == DataTypeExtension::NO_ENUM»
                    «IF ref.category == DataCategory::OBJECT»
                        return «myName»;
                    «ELSEIF ref.javaType.equals("LocalTime")»
                        return «myName»«IF !useUserTypes» == null ? null : LocalTime.from«JDBC4TYPE»Fields(«myName»)«ENDIF»;
                    «ELSEIF ref.javaType.equals("LocalDate")»
                        return «myName»«IF !useUserTypes» == null ? null : LocalDate.from«JDBC4TYPE»Fields(«myName»)«ENDIF»;
                    «ELSEIF ref.javaType.equals("LocalDateTime")»
                        return «myName»«IF !useUserTypes» == null ? null : LocalDateTime.from«JDBC4TYPE»Fields(«myName»)«ENDIF»;
                    «ELSEIF ref.javaType.equals("ByteArray")»
                        return «myName»«IF !useUserTypes» == null ? null : new ByteArray(«myName», 0, -1)«ENDIF»;
                    «ELSEIF ref.javaType.equals("byte []")»
                        return ByteUtil.deepCopy(«myName»);       // deep copy
                    «ELSE»
                        return «myName»;
                    «ENDIF»
                «ELSEIF ref.enumMaxTokenLength == DataTypeExtension::ENUM_NUMERIC || !ref.allTokensAscii»
                    return «ref.elementaryDataType.enumType.name».valueOf(«myName»);
                «ELSEIF ref.category == DataCategory.XENUM»
                    return «ref.xEnumFactoryName».getByTokenWithNull(«myName»);
                «ELSE»
                    «IF i.isASpecialEnumWithEmptyStringAsNull»
                        // special mapping of null to the enum value with the empty string token
                        return «myName» == null ? «theEnum.name».«i.idForEnumTokenNull» : «theEnum.name».factory(«myName»);
                    «ELSE»
                        return «theEnum.name».factory(«myName»);
                    «ENDIF»
                «ENDIF»
            }
        '''
    }

    def private writeSetter(FieldDefinition i, String myName) {
        val ref = DataTypeExtension::get(i.datatype);
        // val theEnum = if(ref.enumMaxTokenLength != DataTypeExtension::ENUM_NUMERIC) ref.enumForEnumOrXenum
        return '''
            public void set«myName.toFirstUpper»(«i.substitutedJavaTypeScalar» «myName») {
                «IF JAVA_OBJECT_TYPE.equals(ref.javaType) ||
                (ref.objectDataType !== null && hasProperty(i.properties, PROP_SERIALIZED))»
                    if («myName» == null) {
                        this.«myName» = null;
                    } else {
                        «IF hasProperty(i.properties, PROP_COMPACT)»
                            CompactByteArrayComposer _bac = new CompactByteArrayComposer();
                        «ELSE»
                            ByteArrayComposer _bac = new ByteArrayComposer();
                        «ENDIF»
                        _bac.addField(StaticMeta.OUTER_BONAPORTABLE, «myName»);
                        this.«myName» = _bac.getBytes();
                    }
                «ELSEIF ref.enumMaxTokenLength == DataTypeExtension::NO_ENUM»
                    «IF ref.category == DataCategory::OBJECT»
                        this.«myName» = «myName»;
                    «ELSEIF ref.javaType.equals("LocalDate") || ref.javaType.equals("LocalDateTime") || ref.javaType.equals("LocalTime")»
                        this.«myName» = «IF useUserTypes»«myName»«ELSE»DayTime.to«JDBC4TYPE»(«myName»)«ENDIF»;
                    «ELSEIF ref.javaType.equals("ByteArray")»
                        this.«myName» = «IF useUserTypes»«myName»«ELSE»«myName» == null ? null : «myName».getBytes()«ENDIF»;
                    «ELSEIF ref.javaType.equals("byte []")»
                        this.«myName» = ByteUtil.deepCopy(«myName»);       // deep copy
                    «ELSE»
                        this.«myName» = «myName»;
                    «ENDIF»
                «ELSEIF ref.enumMaxTokenLength == DataTypeExtension::ENUM_NUMERIC || !ref.allTokensAscii»
                    this.«myName» = «myName» == null ? null : «myName».ordinal();
                «ELSEIF ref.category == DataCategory.XENUM»
                    this.«myName» = («myName» == null || «myName» == «ref.xEnumFactoryName».getNullToken()) ? null : «myName».getToken();
                «ELSE»
                    «IF i.isASpecialEnumWithEmptyStringAsNull»
                        this.«myName» = («myName» == null || «myName» == «ref.elementaryDataType.enumType.name».«i.idForEnumTokenNull») ? null : «myName».getToken();
                    «ELSE»
                        this.«myName» = «myName» == null ? null : «myName».getToken();
                    «ENDIF»
                «ENDIF»
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

    def private static nullableAnnotationPart(FieldDefinition f) {
        if (f.isRequired && !f.isPartOfVariableLengthList && !f.isASpecialEnumWithEmptyStringAsNull)
            ", nullable=false"
    }
    
    // write the definition of a single column (entities or Embeddables)
    def public writeColStuff(FieldDefinition f, List<ElementCollectionRelationship> el, boolean doBeanVal, String myName,
        List<EmbeddableUse> embeddables) {
        val relevantElementCollection = el?.findFirst[name == f]
        val relevantEmbeddable = embeddables?.findFirst[field == f]
        // val emb = relevantEmbeddable?.name?.pojoType
        val embName = relevantEmbeddable?.name?.name
        // val ref = DataTypeExtension::get(f.datatype);

        return '''
            «IF relevantElementCollection !== null && f.aggregate»
                «ElementCollections::writePossibleCollectionOrRelation(f, relevantElementCollection)»
                «IF relevantEmbeddable === null»
                    @Column(name="«myName.java2sql»"«f.nullableAnnotationPart»)
                    «f.writeColumnType(myName)»
                    «f.writeGetter(myName)»
                    «f.writeSetter(myName)»
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
                @Column(name="«myName.java2sql»"«f.nullableAnnotationPart»«f.sizeSpec»«IF hasProperty(f.properties,
                "noinsert")», insertable=false«ENDIF»«IF hasProperty(f.properties, "noupdate")», updatable=false«ENDIF»)
                «f.properties.optionalAnnotation("version", "@Version")»
                «f.properties.optionalAnnotation("lob", "@Lob")»
                «f.properties.optionalAnnotation("lazy", "@Basic(fetch=LAZY)")»
                «IF !f.isASpecialEnumWithEmptyStringAsNull»
                    «JavaBeanValidation::writeAnnotations(f, DataTypeExtension::get(f.datatype), doBeanVal)»
                «ENDIF»
                «f.writeColumnType(myName)»
                «f.writeGetter(myName)»
                «f.writeSetter(myName)»
            «ENDIF»
        '''
    }
}
