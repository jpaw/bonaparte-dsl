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

import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.ElementaryDataType
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.dsl.generator.JavaPackages.*
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension

class JavaExternalize {
    def private static makeWrite(String indexedName, ElementaryDataType e, DataTypeExtension ref) {
        (if (ref.isPrimitive) "" else '''if («indexedName» == null) _out.writeByte(ExternalizableConstants.NULL_FIELD); else ''') +
        switch (ref.javaType) {
            case "String":    '''ExternalizableComposer.writeString (_out, «indexedName»);'''
            case "Boolean":   '''ExternalizableComposer.writeBoolean(_out, «indexedName»);'''
            case "Float":     '''ExternalizableComposer.writeFloat  (_out, «indexedName»);'''
            case "Double":    '''ExternalizableComposer.writeDouble (_out, «indexedName»);'''
            case "Byte":      '''ExternalizableComposer.writeVarInt (_out, «indexedName»);'''
            case "Short":     '''ExternalizableComposer.writeVarInt (_out, «indexedName»);'''
            case "Integer":   '''ExternalizableComposer.writeVarInt (_out, «indexedName»);'''
            case "Long":      '''ExternalizableComposer.writeVarLong(_out, «indexedName»);'''
            case "Character": '''ExternalizableComposer.writeChar   (_out, «indexedName»);'''
            case "UUID":      '''ExternalizableComposer.writeUUID   (_out, «indexedName»);'''
            case "byte []":   '''ExternalizableComposer.writeRaw    (_out, «indexedName»);'''
            case "ByteArray": '''ExternalizableComposer.writeByteArray(_out, «indexedName»);'''
            case "BigDecimal":'''ExternalizableComposer.writeDecimal(_out, «indexedName»);'''
            case "GregorianCalendar":'''ExternalizableComposer.writeGregorianCalendar(_out, «e.doHHMMSS», «indexedName»);'''
            case "LocalDateTime":    '''ExternalizableComposer.writeLocalDateTime(_out, «e.doHHMMSS», «indexedName»);'''
            case "LocalDate":        '''ExternalizableComposer.writeLocalDate(_out, «indexedName»);'''
            case "BonaPortable":     '''ExternalizableComposer.writeObject(_out, «indexedName»);'''
            default:  // enums...
                if (ref.enumMaxTokenLength >= 0) {
                    '''ExternalizableComposer.writeString (_out, «indexedName».getToken());'''
                } else {
                    // numeric enum
                    '''ExternalizableComposer.writeVarInt (_out, «indexedName».ordinal());'''
                }
        }
    }
    
    def private static makeWrite2(ClassDefinition d, FieldDefinition i, String index) '''
        «IF resolveElem(i.datatype) != null»
            «makeWrite(index, resolveElem(i.datatype), DataTypeExtension::get(i.datatype))»
        «ELSE»
            ExternalizableComposer.writeObject(_out, (BonaPortable)«index»);
        «ENDIF»
    '''
    
    def public static writeExternalizeOld(ClassDefinition d) '''
        @Override
        public void writeExternal(ObjectOutput _out) throws IOException {
            «IF d.extendsClass != null»
                // recursive call of superclass first
                super.writeExternal(_out);
            «ENDIF»
            «FOR i:d.fields»
                «IF i.isArray != null || i.isList != null»
                    if («i.name» == null) {
                        _out.writeByte(ExternalizableConstants.NULL_FIELD);
                    } else {
                        «IF i.isArray != null»
                            ExternalizableComposer.startArray(_out, «i.name».length);
                            for (int _i = 0; _i < «i.name».length; ++_i)
                                «makeWrite2(d, i, indexedName(i))»
                        «ELSE»
                            ExternalizableComposer.startArray(_out, «i.name».size());
                            for («JavaDataTypeNoName(i, true)» _i : «i.name»)
                                «makeWrite2(d, i, indexedName(i))»
                        «ENDIF»
                        _out.writeByte(ExternalizableConstants.ARRAY_TERMINATOR);
                    }
                «ELSE»
                    «makeWrite2(d, i, indexedName(i))»
                «ENDIF»
            «ENDFOR»
            _out.writeByte(ExternalizableConstants.OBJECT_OR_PARENT_SEPARATOR);
        }

    '''
    
    def public static writeExternalize(ClassDefinition d) '''
        @Override
        public void writeExternal(ObjectOutput _out) throws IOException {
            serializeSub(new ExternalizableComposer(_out));
        }

    '''
        
}
  