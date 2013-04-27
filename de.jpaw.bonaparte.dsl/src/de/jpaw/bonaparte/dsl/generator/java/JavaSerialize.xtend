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
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.Util

class JavaSerialize {
   
    def private static makeWrite(String indexedName, ElementaryDataType e, DataTypeExtension ref) {
        val String grammarName = e.name.toLowerCase;
        if (grammarName.equals("unicode"))  // special treatment if Unicode and / or escaped characters must be checked for
            '''w.addUnicodeString(«indexedName», «e.length», «ref.effectiveAllowCtrls»);'''
        else if (grammarName.equals("timestamp") || grammarName.equals("calendar"))
            '''w.addField(«indexedName», «e.doHHMMSS», «e.length»);'''
        else if (ref.javaType.equals("String") || grammarName.equals("raw") || grammarName.equals("binary"))
            '''w.addField(«indexedName», «e.length»);'''
        else if (grammarName.equals("decimal"))
            '''w.addField(«indexedName», «e.length», «e.decimals», «ref.effectiveSigned»);'''
        else if (grammarName.equals("number"))
            '''w.addField(«indexedName», «e.length», «ref.effectiveSigned»);'''
        else if (grammarName.equals("day") && !Util::useJoda())
            '''w.addField(«indexedName», -1);'''
        else if (grammarName.equals("enum")) {       // enums to be written as their ordinals or tokens
            if (ref.enumMaxTokenLength >= 0) {
                // alphanumeric enum
                if (ref.allTokensAscii)
                    '''if («indexedName» == null) w.writeNull(); else w.addField(«indexedName».getToken(), «ref.enumMaxTokenLength»);'''
                else
                    '''if («indexedName» == null) w.writeNull(); else w.addUnicodeString(«indexedName».getToken(), «ref.enumMaxTokenLength», false);'''
            } else {
                // numeric enum
                '''if («indexedName» == null) w.writeNull(); else w.addField(«indexedName».ordinal());'''
            }
        } else // primitive or boxed type or object
            '''«IF !ref.isPrimitive»if («indexedName» == null) w.writeNull(); else «ENDIF»w.addField(«indexedName»);'''
    }

    def private static makeWrite2(ClassDefinition d, FieldDefinition i, String index) '''
        «IF resolveElem(i.datatype) != null»
            «makeWrite(index, resolveElem(i.datatype), DataTypeExtension::get(i.datatype))»
        «ELSE»
            w.addField((BonaPortable)«index»);
        «ENDIF»
    '''
    
    def public static writeSerialize(ClassDefinition d) '''
        /* serialize the object into a String. uses implicit toString() member functions of elementary data types */
        @Override
        public <E extends Exception> void serializeSub(MessageComposer<E> w) throws E {
            «IF d.extendsClass != null»
                // recursive call of superclass first
                super.serializeSub(w);
            «ENDIF»
            «FOR i:d.fields»
                «IF i.isArray != null || i.isList != null»
                    if («i.name» == null) {
                        w.writeNull();
                    } else {
                        «IF i.isArray != null»
                            w.startArray(«i.name».length, «i.isArray.maxcount», 0);
                            for (int _i = 0; _i < «i.name».length; ++_i)
                                «makeWrite2(d, i, indexedName(i))»
                            w.terminateArray();
                        «ELSE»
                            w.startArray(«i.name».size(), «i.isList.maxcount», 0);
                            for («JavaDataTypeNoName(i, true)» _i : «i.name»)
                                «makeWrite2(d, i, indexedName(i))»
                            w.terminateArray();
                        «ENDIF»
                    }
                «ELSEIF i.isMap != null»
                    if («i.name» == null) {
                        w.writeNull();
                    } else {
                        w.startMap(«i.name».size(), «mapIndexID(i.isMap)»);
                        for (Map.Entry<«i.isMap.indexType»,«JavaDataTypeNoName(i, true)»> _i : «i.name».entrySet()) {
                            // write (key, value) tuples
                            «IF i.isMap.indexType == "String"»
                                w.addField(_i.getKey(), 255);
                            «ELSE»
                                w.addField(_i.getKey());
                            «ENDIF»
                            «makeWrite2(d, i, indexedName(i))»
                        }
                        w.terminateArray();
                    }
                «ELSE»
                    «makeWrite2(d, i, indexedName(i))»
                «ENDIF»
            «ENDFOR»
            w.writeSuperclassSeparator();
        }

   '''    
}