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
import de.jpaw.bonaparte.dsl.generator.Util
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.dsl.generator.JavaPackages.*
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension

class JavaDeserialize {
    private static String interfaceDowncast = "(Class <? extends BonaPortable>)"  // objects implementing BonaPortableWithMeta

    def private static makeRead(ElementaryDataType i, DataTypeExtension ref) {
        switch i.name.toLowerCase {
        // numeric (non-float) types
        case 'byte':      '''p.readByte      («ref.wasUpperCase», «ref.effectiveSigned»)'''
        case 'short':     '''p.readShort     («ref.wasUpperCase», «ref.effectiveSigned»)'''
        case 'long':      '''p.readLong      («ref.wasUpperCase», «ref.effectiveSigned»)'''
        case 'int':       '''p.readInteger   («ref.wasUpperCase», «ref.effectiveSigned»)'''
        case 'integer':   '''p.readInteger   («ref.wasUpperCase», «ref.effectiveSigned»)'''
        case 'number':    '''p.readNumber    («ref.wasUpperCase», «i.length», «ref.effectiveSigned»)'''
        case 'decimal':   '''p.readBigDecimal(«ref.wasUpperCase», «i.length», «i.decimals», «ref.effectiveSigned»)'''
        // float/double, char and boolean    
        case 'float':     '''p.readFloat     («ref.wasUpperCase», «ref.effectiveSigned»)'''
        case 'double':    '''p.readDouble    («ref.wasUpperCase», «ref.effectiveSigned»)'''
        case 'boolean':   '''p.readBoolean   («ref.wasUpperCase»)'''
        case 'char':      '''p.readCharacter («ref.wasUpperCase»)'''
        case 'character': '''p.readCharacter («ref.wasUpperCase»)'''
        // text
        case 'uppercase': '''p.readString    («ref.wasUpperCase», «i.length», «ref.effectiveTrim», «ref.effectiveTruncate», false, false)'''
        case 'lowercase': '''p.readString    («ref.wasUpperCase», «i.length», «ref.effectiveTrim», «ref.effectiveTruncate», false, false)'''
        case 'ascii':     '''p.readString    («ref.wasUpperCase», «i.length», «ref.effectiveTrim», «ref.effectiveTruncate», false, false)'''
        case 'unicode':   '''p.readString    («ref.wasUpperCase», «i.length», «ref.effectiveTrim», «ref.effectiveTruncate», «ref.effectiveAllowCtrls», true)'''
        // special          
        case 'uuid':      '''p.readUUID      («ref.wasUpperCase»)'''
        case 'binary':    '''p.readByteArray («ref.wasUpperCase», «i.length»)'''
        case 'raw':       '''p.readRaw       («ref.wasUpperCase», «i.length»)'''
        case 'calendar':  '''p.readGregorianCalendar(«ref.wasUpperCase», «i.doHHMMSS», «i.length»)'''
        case 'timestamp': if (Util::useJoda())
                             '''p.readDayTime(«ref.wasUpperCase», «i.doHHMMSS», «i.length»)'''
                          else
                             '''p.readGregorianCalendar(«ref.wasUpperCase», «i.doHHMMSS», «i.length»)'''
        case 'day':       if (Util::useJoda())
                             '''p.readDay(«ref.wasUpperCase»)'''
                          else
                             '''p.readGregorianCalendar(«ref.wasUpperCase», «i.doHHMMSS», -1)'''
        // enum
        case 'enum':      '''«getPackageName(i.enumType)».«i.enumType.name».«IF (ref.enumMaxTokenLength >= 0)»factory(p.readString(«ref.wasUpperCase», «ref.enumMaxTokenLength», true, false, false, true))«ELSE»valueOf(p.readInteger(«ref.wasUpperCase», false))«ENDIF»'''
        }
    }

    def private static makeRead2(ClassDefinition d, FieldDefinition i, String end) '''
        «IF resolveElem(i.datatype) != null»
            «makeRead(resolveElem(i.datatype), DataTypeExtension::get(i.datatype))»«end»
        «ELSE»
            («possiblyFQClassName(d, resolveObj(i.datatype))»)p.readObject(«interfaceDowncast»«possiblyFQClassName(d, resolveObj(i.datatype))».class, «b2A(!i.isRequired)», «b2A(i.datatype.orSuperClass)»)«end»
        «ENDIF»
    '''
            
    def public static writeDeserialize(ClassDefinition d) '''
            @Override
            public <E extends Exception> void deserialize(MessageParser<E> p) throws E {
            //public void deserialize(MessageParser p) throws MessageParserException {
                int arrayLength;
                // String embeddingObject = p.setCurrentClass(getPartiallyQualifiedClassName); // backup for the class name currently parsed
                «IF d.extendsClass != null»
                    super.deserialize(p);
                «ENDIF»
                p.setClassName(PARTIALLY_QUALIFIED_CLASS_NAME);  // just for debug info
                «FOR i:d.fields»
                    «IF (resolveElem(i.datatype) != null) && resolveElem(i.datatype).enumType != null»
                        try {  // for possible EnumExceptions
                    «ENDIF»
                    «IF i.isArray != null || i.isList != null»
                        arrayLength = p.parseArrayStart(«if (i.isArray != null) i.isArray.maxcount else i.isList.maxcount», 0);
                        if (arrayLength < 0) {
                            «i.name» = null;
                        } else {
                            «IF i.isArray != null»
                                «IF resolveElem(i.datatype) != null && getJavaDataType(i.datatype).equals("byte []")»
                                    «i.name» = new byte [«if (i.isArray.maxcount > 0) i.isArray.maxcount else "arrayLength"»][];  // Java weirdness: dimension swapped to first pair of brackets!
                                «ELSE»
                                    «i.name» = new «if (resolveElem(i.datatype) != null) getJavaDataType(i.datatype) else getPackageName(resolveObj(i.datatype)) + "." + resolveObj(i.datatype).name»[«if (i.isArray.maxcount > 0) i.isArray.maxcount else "arrayLength"»];
                                «ENDIF»
                                for (int _i = 0; _i < arrayLength; ++_i)
                                    «i.name»[_i] = «makeRead2(d, i, ";")»
                                p.parseArrayEnd();
                            «ELSE»
                                «i.name» = new ArrayList<«JavaDataTypeNoName(i, true)»>(arrayLength);
                                for (int _i = 0; _i < arrayLength; ++_i)
                                    «i.name».add(«makeRead2(d, i, ");")»
                                p.parseArrayEnd();
                            «ENDIF»
                        }
                    «ELSE»
                        «i.name» = «makeRead2(d, i, ";")»
                    «ENDIF»
                    «IF (resolveElem(i.datatype) != null) && resolveElem(i.datatype).enumType != null»
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