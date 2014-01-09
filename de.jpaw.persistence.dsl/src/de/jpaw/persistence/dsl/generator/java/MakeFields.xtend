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

class JavaFieldWriter {
    val static final String JAVA_OBJECT_TYPE = "BonaPortable";
    val static final String CALENDAR = "Calendar";
    final boolean useUserTypes;
    final String fieldVisibility;
    
    def private static String makeVisibility(Visibility v) {
        var XVisibility fieldScope
        if (v != null && v.x != null)
            fieldScope = v.x
        if (fieldScope == null || fieldScope == XVisibility::DEFAULT)
            ""
        else
            fieldScope.toString() + " "
    }

	def public static final defineVisibility(EntityDefinition e) {
        val myPackage = e.eContainer as PackageDefinition
        return makeVisibility(if (e.visibility != null) e.visibility else myPackage.visibility)
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
        else if (i.isArray != null)
            dataClass + "[]"
        else if (i.isSet != null)
            "Set<" + dataClass + ">"
        else if (i.isList != null)
            "List<" + dataClass + ">"
        else if (i.isMap != null)
            "Map<" + i.isMap.indexType + "," + dataClass + ">"
        else
            dataClass
    }

    // temporal types for UserType mappings (OR mapper specific extensions)
    def private writeTemporalFieldAndAnnotation(FieldDefinition c, String type, String fieldType, String myName) '''
        @Temporal(TemporalType.«type»)
        «fieldVisibility»«c.JavaDataType2NoName(false, fieldType)» «myName»;
    '''
    // temporal types for UserType mappings (OR mapper specific extensions)
    def private writeField(FieldDefinition c, String fieldType, String myName) '''
        «fieldVisibility»«c.JavaDataType2NoName(false, fieldType)» «myName»;
    '''

    def private writeColumnType(FieldDefinition c, String myName) {
        val DataTypeExtension ref = DataTypeExtension::get(c.datatype)
        if (ref.objectDataType != null) {
            if (c.properties.hasProperty("serialized")) {
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
                    @ManyToOne«IF params != null»(«params»)«ENDIF»
                    «IF c.properties.getProperty("JoinColumn") != null»
                        @JoinColumn(«c.properties.getProperty("JoinColumn")»)
                    «ELSEIF c.properties.getProperty("JoinColumnRO") != null»
                        @JoinColumn(«c.properties.getProperty("JoinColumnRO")», insertable=false, updatable=false)  // have a separate Long property field for updates
                    «ENDIF»
                    «fieldVisibility»«c.JavaDataTypeNoName(false)» «myName»;'''
            }
        }
        switch (ref.enumMaxTokenLength) {
        case DataTypeExtension::NO_ENUM:
            switch (ref.javaType) {
            case "Calendar":        writeTemporalFieldAndAnnotation(c, "TIMESTAMP", CALENDAR, myName)
            case "DateTime":        writeTemporalFieldAndAnnotation(c, "DATE", CALENDAR, myName)
            case "LocalDateTime":   if (useUserTypes)
                                        writeField(c, ref.javaType, myName)
                                    else
                                        writeTemporalFieldAndAnnotation(c, "TIMESTAMP", CALENDAR, myName)
            case "LocalDate":       if (useUserTypes)
                                        writeField(c, ref.javaType, myName)
                                    else
                                        writeTemporalFieldAndAnnotation(c, "DATE", CALENDAR, myName)
            case "ByteArray":       writeField(c, if (useUserTypes) "ByteArray" else "byte []", myName)
            case JAVA_OBJECT_TYPE:  '''
                                        // @Lob
                                        «writeField(c, "byte []", myName)»
                                    '''
            default:                '''
                                        «fieldVisibility»«JavaDataTypeNoName(c, c.properties.hasProperty(PROP_UNROLL))» «myName»;
                                    '''
            }
        case DataTypeExtension::ENUM_NUMERIC:   writeField(c, "Integer", myName)
        default:                                writeField(c, if (ref.allTokensAscii) "String" else "Integer", myName)
        }
    }


    def private static optionalAnnotation(List <PropertyUse> properties, String key, String annotation) {
        '''«IF properties.hasProperty(key)»«annotation»«ENDIF»'''
    }

    // write a @Size annotation for string based types
    def private static sizeSpec(FieldDefinition c) {
        val ref = DataTypeExtension::get(c.datatype);
        if (ref.category == DataCategory::STRING)
            return ''', length=«ref.elementaryDataType.length»'''
        if (ref.elementaryDataType != null && ref.elementaryDataType.name.toLowerCase.equals("decimal"))
            return ''', precision=«ref.elementaryDataType.length», scale=«ref.elementaryDataType.decimals»'''
        return ''''''
    }
    
    // return true, if this is a list with lower number of elements strictly less than the upper bound.
    // In such a case, the list could be shorter, and elements therefore cannot be assumed to be not null
    def private static isPartOfVariableLengthList(FieldDefinition c) {
        c.isList != null && c.isList.mincount < c.isList.maxcount        
    } 
    
    // write the definition of a single column (entities or Embeddables)
    def private singleColumn(FieldDefinition c, List <ElementCollectionRelationship> el, boolean withBeanVal, String myName) '''
        «IF el != null && c.aggregate»
            «ElementCollections::writePossibleCollectionOrRelation(c, el)»
        «ENDIF»
        @Column(name="«myName.java2sql»"«IF c.isRequired && !c.isPartOfVariableLengthList && !c.isASpecialEnumWithEmptyStringAsNull», nullable=false«ENDIF»«c.sizeSpec»«IF hasProperty(c.properties, "noinsert")», insertable=false«ENDIF»«IF hasProperty(c.properties, "noupdate")», updatable=false«ENDIF»)
        «c.properties.optionalAnnotation("version", "@Version")»
        «c.properties.optionalAnnotation("lob",     "@Lob")»
        «c.properties.optionalAnnotation("lazy",    "@Basic(fetch=LAZY)")»
        «IF !c.isASpecialEnumWithEmptyStringAsNull»
            «JavaBeanValidation::writeAnnotations(c, DataTypeExtension::get(c.datatype), withBeanVal)»
        «ENDIF»
        «c.writeColumnType(myName)»
    '''

    def private static substitutedJavaTypeScalar(FieldDefinition i) {
        val ref = DataTypeExtension::get(i.datatype);
        if (ref.objectDataType != null) {
            if (i.properties.hasProperty(PROP_REF))
                return "Long"
        }
        return i.JavaDataTypeNoName(i.properties.hasProperty(PROP_UNROLL))
    }

    def private static writeException(DataTypeExtension ref, FieldDefinition c) {
        if (ref.enumMaxTokenLength != DataTypeExtension::NO_ENUM)
            return "throws EnumException "
        else if (JAVA_OBJECT_TYPE.equals(ref.javaType) || (ref.objectDataType != null && hasProperty(c.properties, "serialized"))) {
            return "throws MessageParserException "
        } else
            return ""
    }
    def private writeGetter(FieldDefinition i, String myName) {
        val ref = DataTypeExtension::get(i.datatype);
        return '''
            public «i.substitutedJavaTypeScalar» get«myName.toFirstUpper»() «writeException(DataTypeExtension::get(i.datatype), i)»{
                «IF JAVA_OBJECT_TYPE.equals(ref.javaType) || (ref.objectDataType != null && hasProperty(i.properties, "serialized"))»
                    if («myName» == null)
                        return null;
                    ByteArrayParser _bap = new ByteArrayParser(«myName», 0, -1);
                    return «IF ref.objectDataType != null»(«JavaDataTypeNoName(i, false)»)«ENDIF»_bap.readObject("«myName»", «IF ref.objectDataType != null»«JavaDataTypeNoName(i, false)»«ELSE»BonaPortable«ENDIF».class, true, true);
                «ELSEIF ref.enumMaxTokenLength == DataTypeExtension::NO_ENUM»
                    «IF ref.category == DataCategory::OBJECT»
                        return «myName»;
                    «ELSEIF ref.javaType.equals("LocalDate")»
                        return «myName»«IF !useUserTypes» == null ? null : LocalDate.fromCalendarFields(«myName»)«ENDIF»;
                    «ELSEIF ref.javaType.equals("LocalDateTime")»
                        return «myName»«IF !useUserTypes» == null ? null : LocalDateTime.fromCalendarFields(«myName»)«ENDIF»;
                    «ELSEIF ref.javaType.equals("ByteArray")»
                        return «myName»«IF !useUserTypes» == null ? null : new ByteArray(«myName», 0, -1)«ENDIF»;
                    «ELSEIF ref.javaType.equals("byte []")»
                        return ByteUtil.deepCopy(«myName»);       // deep copy
                    «ELSE»
                        return «myName»;
                    «ENDIF»
                «ELSEIF ref.enumMaxTokenLength == DataTypeExtension::ENUM_NUMERIC || !ref.allTokensAscii»
                    return «ref.elementaryDataType.enumType.name».valueOf(«myName»);
                «ELSE»
                    «IF i.isASpecialEnumWithEmptyStringAsNull»
                        // special mapping of null to the enum value with the empty string token
                        return «myName» == null ? «ref.elementaryDataType.enumType.name».«i.idForEnumTokenNull» : «ref.elementaryDataType.enumType.name».factory(«myName»);
                    «ELSE»
                        return «ref.elementaryDataType.enumType.name».factory(«myName»);
                    «ENDIF»
                «ENDIF»
            }
        '''
    }

    def private writeSetter(FieldDefinition i, String myName) {
        val ref = DataTypeExtension::get(i.datatype);
        return '''
            public void set«myName.toFirstUpper»(«i.substitutedJavaTypeScalar» «myName») {
                «IF JAVA_OBJECT_TYPE.equals(ref.javaType) || (ref.objectDataType != null && hasProperty(i.properties, "serialized"))»
                    if («myName» == null) {
                        this.«myName» = null;
                    } else {
                        ByteArrayComposer _bac = new ByteArrayComposer();
                        _bac.addField(StaticMeta.OUTER_BONAPORTABLE, «myName»);
                        this.«myName» = _bac.getBytes();
                    }
                «ELSEIF ref.enumMaxTokenLength == DataTypeExtension::NO_ENUM»
                    «IF ref.category == DataCategory::OBJECT»
                        this.«myName» = «myName»;
                    «ELSEIF ref.javaType.equals("LocalDate") || ref.javaType.equals("LocalDateTime")»
                        this.«myName» = «IF useUserTypes»«myName»«ELSE»DayTime.toGregorianCalendar(«myName»)«ENDIF»;
                    «ELSEIF ref.javaType.equals("ByteArray")»
                        this.«myName» = «IF useUserTypes»«myName»«ELSE»«myName» == null ? null : «myName».getBytes()«ENDIF»;
                    «ELSEIF ref.javaType.equals("byte []")»
                        this.«myName» = ByteUtil.deepCopy(«myName»);       // deep copy
                    «ELSE»
                        this.«myName» = «myName»;
                    «ENDIF»
                «ELSEIF ref.enumMaxTokenLength == DataTypeExtension::ENUM_NUMERIC || !ref.allTokensAscii»
                     this.«myName» = «myName» == null ? null : «myName».ordinal();
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
        «FOR i:e.pk.columnName»
            public void set«i.name.toFirstUpper»(«i.substitutedJavaTypeScalar» _x) {
                key.set«i.name.toFirstUpper»(_x);
            }
            public «i.substitutedJavaTypeScalar» get«i.name.toFirstUpper»() {
                return key.get«i.name.toFirstUpper»();
            }
        «ENDFOR»
	'''

    def public writeColStuff(FieldDefinition f, List<ElementCollectionRelationship> el, boolean doBeanVal, String myName) '''
        «singleColumn(f, el, doBeanVal, myName)»
        «f.writeGetter(myName)»
        «f.writeSetter(myName)»
    '''
}