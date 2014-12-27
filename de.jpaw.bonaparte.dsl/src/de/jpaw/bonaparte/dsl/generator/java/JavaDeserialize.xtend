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
    
    def private static makeRead(String metaName, ElementaryDataType i, DataTypeExtension ref) {
        switch i.name.toLowerCase {
        // numeric (non-float) types
        case 'byte':      '''_p.readByte      («metaName»)'''
        case 'short':     '''_p.readShort     («metaName»)'''
        case 'long':      '''_p.readLong      («metaName»)'''
        case 'int':       '''_p.readInteger   («metaName»)'''
        case 'integer':   '''_p.readInteger   («metaName»)'''
        case 'number':    '''_p.readBigInteger(«metaName»)'''
        case 'decimal':   '''_p.readBigDecimal(«metaName»)'''
        // float/double, char and boolean
        case 'float':     '''_p.readFloat     («metaName»)'''
        case 'double':    '''_p.readDouble    («metaName»)'''
        case 'boolean':   '''_p.readBoolean   («metaName»)'''
        case 'char':      '''_p.readCharacter («metaName»)'''
        case 'character': '''_p.readCharacter («metaName»)'''
        // text
        case 'uppercase': '''_p.readString    («metaName»)'''
        case 'lowercase': '''_p.readString    («metaName»)'''
        case 'ascii':     '''_p.readString    («metaName»)'''
        case 'unicode':   '''_p.readString    («metaName»)'''
        // special
        case 'uuid':      '''_p.readUUID      («metaName»)'''
        case 'binary':    '''_p.readByteArray («metaName»)'''
        case 'raw':       '''_p.readRaw       («metaName»)'''
        case 'time':      '''_p.readTime      («metaName»)'''
        case 'instant':   '''_p.readInstant   («metaName»)'''
        case 'timestamp': '''_p.readDayTime   («metaName»)'''
        case 'day':       '''_p.readDay       («metaName»)'''
                          
        // enum
        case 'enum':      '''«getBonPackageName(i.enumType)».«i.enumType.name».«IF (ref.enumMaxTokenLength >= 0)»factory(_p.readString(«metaName»$token))«ELSE»valueOf(_p.readInteger(«metaName»$token))«ENDIF»'''
        case 'xenum':     '''_p.readXEnum(«metaName», «XUtil.xEnumFactoryName(ref)»)'''  // must reference the actual type just to ensure that the class is loaded and values initialized!
        
        // enum sets
        case 'enumset':   '''«ref.javaType».unmarshal(_p.read«i.enumsetType.mapEnumSetIndex»(«metaName»), _p)'''
        case 'xenumset':  '''«ref.javaType».unmarshal(_p.readString(«metaName»), _p)'''
        
        // objects
        case 'object':    '''_p.readObject(«metaName», BonaPortable.class)'''
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

    def private static CharSequence makeRead(FieldDefinition i, ClassDefinition objectType, DataTypeExtension ref, String metaPrefixOtherClass) {
        val defaultExpression = '''_p.readObject(«metaPrefixOtherClass»meta$$«i.name», «getKnownSupertype(ref.genericsRef)».class)'''
        if (objectType?.externalType === null) {
            // regular bonaportable
            return '''(«ref.javaType»)«defaultExpression»'''
        } else {
            // custom types (external types)
            // check for possible extra parameters
            val extra =
                if (i.datatype.extraParameterString !== null)
                    '''«i.datatype.extraParameterString», '''
                else if (i.datatype.extraParameter !== null)
                    '''get«i.datatype.extraParameter.name.toFirstUpper»(), '''
            // check for a possible exception converter parameter
            val exceptionConverterParameter = if (objectType.exceptionConverter) ", _p"  
            if (objectType.singleField) {
                // delegate to first field or the proxy
                return '''«objectType.adapterClassName».unmarshal(«extra»«makeRead2(objectType, objectType.fields.get(0), objectType.name + ".")»«exceptionConverterParameter»)'''
            } else {
                return '''«objectType.adapterClassName».unmarshal(«extra»«defaultExpression»«exceptionConverterParameter»)'''
            }
        }
    }
    
    def private static makeRead2(ClassDefinition d, FieldDefinition i, String metaPrefixOtherClass) {
        val ref = DataTypeExtension::get(i.datatype)
        if (ref.elementaryDataType !== null)
            return makeRead('''«metaPrefixOtherClass»meta$$«i.name»''', ref.elementaryDataType, ref)
        else        
            return makeRead(i, ref.objectDataType, ref, metaPrefixOtherClass)
    }
    def private static makeRead2(ClassDefinition d, FieldDefinition i) {
        makeRead2(d, i, null)
    }

    def public static writeDeserialize(ClassDefinition d) '''
            @Override
            public <_E extends Exception> void deserialize(MessageParser<_E> _p) throws _E {
                int _length;
                «IF d.extendsClass !== null»
                    super.deserialize(_p);
                    _p.eatParentSeparator();
                «ENDIF»
                _p.setClassName(_PARTIALLY_QUALIFIED_CLASS_NAME);  // just for debug info
                «FOR i:d.fields»
                    «IF (resolveElem(i.datatype) !== null) && (resolveElem(i.datatype).enumType !== null || resolveElem(i.datatype).xenumType !== null)»
                        try {  // for possible enum factory Exceptions
                    «ENDIF»
                    «IF i.isArray !== null»
                        _length = _p.parseArrayStart(meta$$«i.name», 0);
                        if (_length < 0) {
                            «i.name» = null;
                        } else {
                            «IF resolveElem(i.datatype) !== null && getJavaDataType(i.datatype).equals("byte []")»
                                «i.name» = new byte [«if (i.isArray.maxcount > 0) i.isArray.maxcount else "_length"»][];  // Java weirdness: dimension swapped to first pair of brackets!
                            «ELSE»
                                «i.name» = new «if (resolveElem(i.datatype) !== null) getJavaDataType(i.datatype) else DataTypeExtension::get(i.datatype).javaType»[«if (i.isArray.maxcount > 0) i.isArray.maxcount else "_length"»];
                            «ENDIF»
                            for (int _i = 0; _i < _length; ++_i)
                                «i.name»[_i] = «makeRead2(d, i)»;
                            _p.parseArrayEnd();
                        }
                    «ELSEIF i.isList !== null»
                        _length = _p.parseArrayStart(meta$$«i.name», 0);
                        if (_length < 0) {
                            «i.name» = null;
                        } else {
                            «i.name» = new ArrayList<«JavaDataTypeNoName(i, true)»>(_length);
                            for (int _i = 0; _i < _length; ++_i)
                                «i.name».add(«makeRead2(d, i)»);
                            _p.parseArrayEnd();
                        }
                    «ELSEIF i.isSet !== null»
                        _length = _p.parseArrayStart(meta$$«i.name», 0);
                        if (_length < 0) {
                            «i.name» = null;
                        } else {
                            «i.name» = new HashSet<«JavaDataTypeNoName(i, true)»>(_length);
                            for (int _i = 0; _i < _length; ++_i)
                                «i.name».add(«makeRead2(d, i)»);
                            _p.parseArrayEnd();
                        }
                    «ELSEIF i.isMap !== null»
                        _length = _p.parseMapStart(meta$$«i.name»);
                        if (_length < 0) {
                            «i.name» = null;
                        } else {
                            «i.name» = new HashMap<«i.isMap.indexType», «JavaDataTypeNoName(i, true)»>(_length);
                            for (int _i = 0; _i < _length; ++_i) {
                                «IF i.isMap.indexType == "String"»
                                    «i.isMap.indexType» _key = _p.readString(StaticMeta.MAP_INDEX_META_STRING);
                                «ELSE»
                                    «i.isMap.indexType» _key = _p.read«i.isMap.indexType»(StaticMeta.MAP_INDEX_META_«i.isMap.indexType.toUpperCase»);
                                «ENDIF»
                                «i.name».put(_key, «makeRead2(d, i)»);
                            }
                            _p.parseArrayEnd();
                        }
                    «ELSE»
                        «i.name» = «makeRead2(d, i)»;
                    «ENDIF»
                    «IF (resolveElem(i.datatype) !== null) && (resolveElem(i.datatype).enumType !== null || resolveElem(i.datatype).xenumType !== null)»
                         } catch (IllegalArgumentException e) {
                             // convert type of exception to the only one allowed (as indicated by interface generics parameter). Enrich with additional data useful to locate the error, if exception type allows.
                             throw _p.enumExceptionConverter(e);
                         }
                    «ENDIF»
                «ENDFOR»
            }
    '''

}
