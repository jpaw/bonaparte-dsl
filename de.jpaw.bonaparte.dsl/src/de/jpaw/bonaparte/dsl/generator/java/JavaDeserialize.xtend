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
import de.jpaw.bonaparte.dsl.bonScript.ClassReference
import de.jpaw.bonaparte.dsl.bonScript.ElementaryDataType
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension

import static de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import de.jpaw.bonaparte.dsl.generator.XUtil

class JavaDeserialize {
    def private static makeRead(String fieldname, ElementaryDataType i, DataTypeExtension ref) {
        switch i.name.toLowerCase {
        // numeric (non-float) types
        case 'byte':      '''p.readByte      (meta$$«fieldname»)'''
        case 'short':     '''p.readShort     (meta$$«fieldname»)'''
        case 'long':      '''p.readLong      (meta$$«fieldname»)'''
        case 'int':       '''p.readInteger   (meta$$«fieldname»)'''
        case 'integer':   '''p.readInteger   (meta$$«fieldname»)'''
        case 'number':    '''p.readBigInteger(meta$$«fieldname»)'''
        case 'decimal':   '''p.readBigDecimal(meta$$«fieldname»)'''
        // float/double, char and boolean
        case 'float':     '''p.readFloat     (meta$$«fieldname»)'''
        case 'double':    '''p.readDouble    (meta$$«fieldname»)'''
        case 'boolean':   '''p.readBoolean   (meta$$«fieldname»)'''
        case 'char':      '''p.readCharacter (meta$$«fieldname»)'''
        case 'character': '''p.readCharacter (meta$$«fieldname»)'''
        // text
        case 'uppercase': '''p.readString    (meta$$«fieldname»)'''
        case 'lowercase': '''p.readString    (meta$$«fieldname»)'''
        case 'ascii':     '''p.readString    (meta$$«fieldname»)'''
        case 'unicode':   '''p.readString    (meta$$«fieldname»)'''
        // special
        case 'uuid':      '''p.readUUID      (meta$$«fieldname»)'''
        case 'binary':    '''p.readByteArray (meta$$«fieldname»)'''
        case 'raw':       '''p.readRaw       (meta$$«fieldname»)'''
        case 'time':      '''p.readTime      (meta$$«fieldname»)'''
        case 'instant':   '''p.readInstant   (meta$$«fieldname»)'''
        case 'timestamp': '''p.readDayTime   (meta$$«fieldname»)'''
        case 'day':       '''p.readDay       (meta$$«fieldname»)'''
                          
        // enum
        case 'enum':      '''«getPackageName(i.enumType)».«i.enumType.name».«IF (ref.enumMaxTokenLength >= 0)»factory(p.readString(meta$$«fieldname»$token))«ELSE»valueOf(p.readInteger(meta$$«fieldname»$token))«ENDIF»'''
        case 'xenum':     '''p.readXEnum(meta$$«fieldname», «XUtil.xEnumFactoryName(ref)»)'''  // must reference the actual type just to ensure that the class is loaded and values initialized!
        case 'object':    '''p.readObject(meta$$«fieldname», BonaPortable.class)'''
        }
    }

    def private static String getKnownSupertype(ClassReference d) {
        if (d.plainObject)
            return "BonaPortable"
        if (d.classRef !== null)
            return d.classRef.name
        // this must be a generics ref. Return the static type for now, but later extend to the runtime type!
        if (d.genericsParameterRef !== null) {
            if (d.genericsParameterRef.^extends !== null)
                return getKnownSupertype(d.genericsParameterRef.^extends)
            else
                return "BonaPortable"  // unspecified type
        }
        return "FIXME! no supertype resolved!"
    }

    def private static makeRead(FieldDefinition i, ClassDefinition objectType, DataTypeExtension ref) {
        val defaultExpression = '''p.readObject(meta$$«i.name», «getKnownSupertype(ref.genericsRef)».class)'''
        if (objectType?.externalType === null) {
            // regular bonaportable
            return '''(«ref.javaType»)«defaultExpression»'''
        } else {
            // custom types (external types)
            if (objectType.singleField) {
                if (objectType.staticExternalMethods) {
                    // can use the adapter directly, without type information
                    return '''«objectType.adapterClassName».unmarshal(meta$$«i.name», p)'''
                } else {
                    // use the instance itself / and no adapter
                    return '''«objectType.externalType.qualifiedName».unmarshal(meta$$«i.name», p)'''
                }
            } else {
                if (objectType.staticExternalMethods) {
                    return '''«objectType.adapterClassName».fromBonaPortable(«defaultExpression»)'''
                } else {
                    return '''«objectType.externalType.qualifiedName».fromBonaPortable(«defaultExpression»)'''
                }
            }
        }
    }
    
    def private static makeRead2(ClassDefinition d, FieldDefinition i, String end) {
        val ref = DataTypeExtension::get(i.datatype)
        if (ref.elementaryDataType !== null)
            return makeRead(i.name, ref.elementaryDataType, ref) + end
        else        
            return makeRead(i, ref.objectDataType, ref) + end
    }

    def public static writeDeserialize(ClassDefinition d) '''
            @Override
            public <_E extends Exception> void deserialize(MessageParser<_E> p) throws _E {
                int _length;
                «IF d.extendsClass !== null»
                    super.deserialize(p);
                    p.eatParentSeparator();
                «ENDIF»
                p.setClassName(_PARTIALLY_QUALIFIED_CLASS_NAME);  // just for debug info
                «FOR i:d.fields»
                    «IF (resolveElem(i.datatype) !== null) && (resolveElem(i.datatype).enumType !== null || resolveElem(i.datatype).xenumType !== null)»
                        try {  // for possible enum factory Exceptions
                    «ENDIF»
                    «IF i.isArray !== null»
                        _length = p.parseArrayStart(meta$$«i.name», 0);
                        if (_length < 0) {
                            «i.name» = null;
                        } else {
                            «IF resolveElem(i.datatype) !== null && getJavaDataType(i.datatype).equals("byte []")»
                                «i.name» = new byte [«if (i.isArray.maxcount > 0) i.isArray.maxcount else "_length"»][];  // Java weirdness: dimension swapped to first pair of brackets!
                            «ELSE»
                                «i.name» = new «if (resolveElem(i.datatype) !== null) getJavaDataType(i.datatype) else DataTypeExtension::get(i.datatype).javaType»[«if (i.isArray.maxcount > 0) i.isArray.maxcount else "_length"»];
                            «ENDIF»
                            for (int _i = 0; _i < _length; ++_i)
                                «i.name»[_i] = «makeRead2(d, i, ";")»
                            p.parseArrayEnd();
                        }
                    «ELSEIF i.isList !== null»
                        _length = p.parseArrayStart(meta$$«i.name», 0);
                        if (_length < 0) {
                            «i.name» = null;
                        } else {
                            «i.name» = new ArrayList<«JavaDataTypeNoName(i, true)»>(_length);
                            for (int _i = 0; _i < _length; ++_i)
                                «i.name».add(«makeRead2(d, i, ");")»
                            p.parseArrayEnd();
                        }
                    «ELSEIF i.isSet !== null»
                        _length = p.parseArrayStart(meta$$«i.name», 0);
                        if (_length < 0) {
                            «i.name» = null;
                        } else {
                            «i.name» = new HashSet<«JavaDataTypeNoName(i, true)»>(_length);
                            for (int _i = 0; _i < _length; ++_i)
                                «i.name».add(«makeRead2(d, i, ");")»
                            p.parseArrayEnd();
                        }
                    «ELSEIF i.isMap !== null»
                        _length = p.parseMapStart(meta$$«i.name»);
                        if (_length < 0) {
                            «i.name» = null;
                        } else {
                            «i.name» = new HashMap<«i.isMap.indexType», «JavaDataTypeNoName(i, true)»>(_length);
                            for (int _i = 0; _i < _length; ++_i) {
                                «IF i.isMap.indexType == "String"»
                                    «i.isMap.indexType» _key = p.readString(StaticMeta.MAP_INDEX_META_STRING);
                                «ELSE»
                                    «i.isMap.indexType» _key = p.read«i.isMap.indexType»(StaticMeta.MAP_INDEX_META_«i.isMap.indexType.toUpperCase»);
                                «ENDIF»
                                «i.name».put(_key, «makeRead2(d, i, ");")»
                            }
                            p.parseArrayEnd();
                        }
                    «ELSE»
                        «i.name» = «makeRead2(d, i, ";")»
                    «ENDIF»
                    «IF (resolveElem(i.datatype) !== null) && (resolveElem(i.datatype).enumType !== null || resolveElem(i.datatype).xenumType !== null)»
                         } catch (IllegalArgumentException e) {
                             // convert type of exception to the only one allowed (as indicated by interface generics parameter). Enrich with additional data useful to locate the error, if exception type allows.
                             throw p.enumExceptionConverter(e);
                         }
                    «ENDIF»
                «ENDFOR»
            }
    '''

}
