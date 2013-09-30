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
import de.jpaw.bonaparte.dsl.bonScript.ElementaryDataType
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension

import static de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.dsl.generator.DataTypeExtensions2.*
import de.jpaw.bonaparte.dsl.bonScript.EnumDefinition
import de.jpaw.bonaparte.dsl.bonScript.DataType
import de.jpaw.bonaparte.dsl.bonScript.GenericsDef

class JavaDeserialize {

    def private static makeRead(String fieldname, ElementaryDataType i, DataTypeExtension ref, boolean isRequired) {
        switch i.name.toLowerCase {
        // numeric (non-float) types
        case 'byte':      '''p.readByte      ("«fieldname»", «!isRequired», «ref.effectiveSigned»)'''
        case 'short':     '''p.readShort     ("«fieldname»", «!isRequired», «ref.effectiveSigned»)'''
        case 'long':      '''p.readLong      ("«fieldname»", «!isRequired», «ref.effectiveSigned»)'''
        case 'int':       '''p.readInteger   ("«fieldname»", «!isRequired», «ref.effectiveSigned»)'''
        case 'integer':   '''p.readInteger   ("«fieldname»", «!isRequired», «ref.effectiveSigned»)'''
        case 'number':    '''p.readNumber    ("«fieldname»", «!isRequired», «i.length», «ref.effectiveSigned»)'''
        case 'decimal':   '''p.readBigDecimal("«fieldname»", «!isRequired», «i.length», «i.decimals», «ref.effectiveSigned», «ref.effectiveRounding», «ref.effectiveAutoScale»)'''
        // float/double, char and boolean
        case 'float':     '''p.readFloat     ("«fieldname»", «!isRequired», «ref.effectiveSigned»)'''
        case 'double':    '''p.readDouble    ("«fieldname»", «!isRequired», «ref.effectiveSigned»)'''
        case 'boolean':   '''p.readBoolean   ("«fieldname»", «!isRequired»)'''
        case 'char':      '''p.readCharacter ("«fieldname»", «!isRequired»)'''
        case 'character': '''p.readCharacter ("«fieldname»", «!isRequired»)'''
        // text
        case 'uppercase': '''p.readString    ("«fieldname»", «!isRequired», «i.length», «ref.effectiveTrim», «ref.effectiveTruncate», false, false)'''
        case 'lowercase': '''p.readString    ("«fieldname»", «!isRequired», «i.length», «ref.effectiveTrim», «ref.effectiveTruncate», false, false)'''
        case 'ascii':     '''p.readString    ("«fieldname»", «!isRequired», «i.length», «ref.effectiveTrim», «ref.effectiveTruncate», false, false)'''
        case 'unicode':   '''p.readString    ("«fieldname»", «!isRequired», «i.length», «ref.effectiveTrim», «ref.effectiveTruncate», «ref.effectiveAllowCtrls», true)'''
        // special
        case 'uuid':      '''p.readUUID      ("«fieldname»", «!isRequired»)'''
        case 'binary':    '''p.readByteArray ("«fieldname»", «!isRequired», «i.length»)'''
        case 'raw':       '''p.readRaw       ("«fieldname»", «!isRequired», «i.length»)'''
        case 'calendar':  '''p.readCalendar  ("«fieldname»", «!isRequired», «i.doHHMMSS», «i.length»)'''
        case 'timestamp': '''p.readDayTime("«fieldname»", «!isRequired», «i.doHHMMSS», «i.length»)'''
        case 'day':       '''p.readDay("«fieldname»", «!isRequired»)'''
        case 'object':    '''p.readObject("«fieldname»", BonaPortable.class, «!isRequired», true)'''
        }
    }

    def private static String getKnownSupertype(DataType d) {
        if (d.isObject)
            return "BonaPortable"
        if (d.elementaryDataType != null)
            return d.elementaryDataType.name
        // this must be a generics ref. Return the static type for now, but later extend to the runtime type!
        switch type : d.referenceDataType {
        	GenericsDef : {
                return if (type.^extends != null) getKnownSupertype(type.^extends) else "BonaPortable"
        	}
        	ClassDefinition : {
        		return type.name
        	}
        }
        return "FIXME! no supertype resolved!"
    }

    def private static makeRead2(ClassDefinition d, FieldDefinition it, String end) '''
        «IF datatype.pointsToElementaryDataType»
            «makeRead(name, datatype.findElementaryDataType, DataTypeExtension::get(datatype), isRequired)»«end»
        «ELSEIF datatype.referenceDataType instanceof EnumDefinition»
        	«getPackageName(datatype.referenceDataType)».«datatype.referenceDataType.name».«IF (datatype.enumMaxTokenLength >= 0)»factory(p.readString("«name»", «!isRequired», «datatype.enumMaxTokenLength», true, false, false, true))«ELSE»valueOf(p.readInteger("«name»", «!isRequired», false))«ENDIF»«end»
        «ELSE»
            («DataTypeExtension::get(datatype).javaType»)p.readObject("«name»", «getKnownSupertype(datatype)».class, «!isRequired», «DataTypeExtension.get(datatype).orSuperClass»)«end»
        «ENDIF»
    '''

/*
    def private static exceptionOrNull(ClassDefinition d, FieldDefinition i) {
        if (i.isAggregateRequired)
            '''throw new MessageParserException(MessageParserException.ILLEGAL_EXPLICIT_NULL, "«i.name»", 0, "«d.name»");'''
        else
            '''«i.name» = null;'''      // just a regular assignment
    }
   */

    def public static writeDeserialize(ClassDefinition d) '''
            @Override
            public <E extends Exception> void deserialize(MessageParser<E> p) throws E {
            //public void deserialize(MessageParser p) throws MessageParserException {
                int _length;
                // String embeddingObject = p.setCurrentClass(getPartiallyQualifiedClassName); // backup for the class name currently parsed
                «IF d.extendsClass != null»
                    super.deserialize(p);
                «ENDIF»
                p.setClassName(PARTIALLY_QUALIFIED_CLASS_NAME);  // just for debug info
                «FOR i:d.fields»
                    «IF i.datatype.isEnum»
                        try {  // for possible EnumExceptions
                    «ENDIF»
                    «IF i.isArray != null»
                        _length = p.parseArrayStart("«i.name»", «!i.isAggregateRequired», «i.isArray.maxcount», 0);
                        if (_length < 0) {
                            «i.name» = null;
                        } else {
                            «IF resolveElem(i.datatype) != null && getJavaDataType(i.datatype).equals("byte []")»
                                «i.name» = new byte [«if (i.isArray.maxcount > 0) i.isArray.maxcount else "_length"»][];  // Java weirdness: dimension swapped to first pair of brackets!
                            «ELSE»
                                «i.name» = new «if (resolveElem(i.datatype) != null) getJavaDataType(i.datatype) else DataTypeExtension::get(i.datatype).javaType»[«if (i.isArray.maxcount > 0) i.isArray.maxcount else "_length"»];
                            «ENDIF»
                            for (int _i = 0; _i < _length; ++_i)
                                «i.name»[_i] = «makeRead2(d, i, ";")»
                            p.parseArrayEnd();
                        }
                    «ELSEIF i.isList != null»
                        _length = p.parseArrayStart("«i.name»", «!i.isAggregateRequired», «i.isList.maxcount», 0);
                        if (_length < 0) {
                            «i.name» = null;
                        } else {
                            «i.name» = new ArrayList<«JavaDataTypeNoName(i, true)»>(_length);
                            for (int _i = 0; _i < _length; ++_i)
                                «i.name».add(«makeRead2(d, i, ");")»
                            p.parseArrayEnd();
                        }
                    «ELSEIF i.isSet != null»
                        _length = p.parseArrayStart("«i.name»", «!i.isAggregateRequired», «i.isSet.maxcount», 0);
                        if (_length < 0) {
                            «i.name» = null;
                        } else {
                            «i.name» = new HashSet<«JavaDataTypeNoName(i, true)»>(_length);
                            for (int _i = 0; _i < _length; ++_i)
                                «i.name».add(«makeRead2(d, i, ");")»
                            p.parseArrayEnd();
                        }
                    «ELSEIF i.isMap != null»
                        _length = p.parseMapStart("«i.name»", «!i.isAggregateRequired», «mapIndexID(i.isMap)»);
                        if (_length < 0) {
                            «i.name» = null;
                        } else {
                            «i.name» = new HashMap<«i.isMap.indexType», «JavaDataTypeNoName(i, true)»>(_length);
                            for (int _i = 0; _i < _length; ++_i) {
                                «IF i.isMap.indexType == "String"»
                                    «i.isMap.indexType» _key = p.readString("«i.name»", false, 255, false, false, true, true);
                                «ELSE»
                                    «i.isMap.indexType» _key = p.read«i.isMap.indexType»("«i.name»", false, true);
                                «ENDIF»
                                «i.name».put(_key, «makeRead2(d, i, ");")»
                            }
                            p.parseArrayEnd();
                        }
                    «ELSE»
                        «i.name» = «makeRead2(d, i, ";")»
                    «ENDIF»
                    «IF i.datatype.isEnum»
                         } catch (EnumException e) {
                             // convert type of exception to the only one allowed (as indiated by interface generics parameter). Enrich with additional data useful to locate the error, if exception type allows.
                             throw p.enumExceptionConverter(e);
                         }
                    «ENDIF»
                «ENDFOR»
                p.eatParentSeparator();
                // p.setCurrentClass(embeddingObject); // ignore result
            }
    '''

}
