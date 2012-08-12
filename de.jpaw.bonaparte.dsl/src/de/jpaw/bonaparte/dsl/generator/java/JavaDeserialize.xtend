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
        case 'calendar':  '''p.readGregorianCalendar(«ref.wasUpperCase», «i.length»)'''
        case 'timestamp': if (Util::useJoda())
                             '''p.readDayTime(«ref.wasUpperCase», «i.length»)'''
                          else
                             '''p.readGregorianCalendar(«ref.wasUpperCase», «i.length»)'''
        case 'day':       if (Util::useJoda())
                             '''p.readDay(«ref.wasUpperCase»)'''
                          else
                             '''p.readGregorianCalendar(«ref.wasUpperCase», -1)'''
        // enum
        case 'enum':      '''«getPackageName(i.enumType)».«i.enumType.name».valueOf(p.readInteger(«ref.wasUpperCase», false))'''
        }
    }

    def private static makeRead2(ClassDefinition d, FieldDefinition i, String index) '''
        «IF resolveElem(i.datatype) != null»
            «i.name»«index» = «makeRead(resolveElem(i.datatype), DataTypeExtension::get(i.datatype))»;
        «ELSE»
            «i.name»«index» = («possiblyFQClassName(d, resolveObj(i.datatype))»)p.readObject(«interfaceDowncast»«possiblyFQClassName(d, resolveObj(i.datatype))».class, «b2A(!i.isRequired)», «b2A(i.datatype.orSuperClass)»);
        «ENDIF»
    '''
            
    def public static writeDeserialize(ClassDefinition d) '''
            @Override
            public void deserialise(MessageParser p) throws MessageParserException {
                int arrayLength;
                // String embeddingObject = p.setCurrentClass(getPartiallyQualifiedClassName); // backup for the class name currently parsed
                «IF d.extendsClass != null»
                    super.deserialise(p);
                    p.eatParentSeparator();
                «ENDIF»
                «FOR i:d.fields»
                    «IF i.isArray != null»
                        arrayLength = p.parseArrayStart(«i.isArray.maxcount», null, 0);
                        if (arrayLength < 0) {
                            «i.name» = null;
                        } else {
                            «IF resolveElem(i.datatype) != null && getJavaDataType(i.datatype).equals("byte []")»
                                «i.name» = new byte [«if (i.isArray.maxcount > 0) i.isArray.maxcount else "arrayLength"»][];  // Java weirdness: dimension swapped to first pair of brackets!
                            «ELSE»
                                «i.name» = new «if (resolveElem(i.datatype) != null) getJavaDataType(i.datatype) else getPackageName(resolveObj(i.datatype)) + "." + resolveObj(i.datatype).name»[«if (i.isArray.maxcount > 0) i.isArray.maxcount else "arrayLength"»];
                            «ENDIF»
                            for (int i = 0; i < arrayLength; ++i)
                                «makeRead2(d, i, "[i]")»
                            p.parseArrayEnd();
                        }
                    «ELSE»
                        «makeRead2(d, i, "")»
                    «ENDIF»
                «ENDFOR»
                // p.setCurrentClass(embeddingObject); // ignore result
            }
    '''
    
}