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
import de.jpaw.bonaparte.dsl.generator.DataCategory

class JavaSerialize {

    def private static makeWrite(FieldDefinition i, String indexedName, ElementaryDataType e, DataTypeExtension ref) {
        if (ref.isPrimitive || ref.category == DataCategory.OBJECT)
            return '''w.addField(meta$$«i.name», «indexedName»);'''
        val String grammarName = e.name.toLowerCase;
        if (grammarName.equals("enum")) {       // enums to be written as their ordinals or tokens, the meta for the enum as well as the expansion are provided
            '''w.addEnum(meta$$«i.name», meta$$«i.name»$token, «indexedName»);'''
        } else if (grammarName.equals("xenum")) {       // xenums to be written as their tokens, the meta for the enum as well as the expansion are provided
            '''w.addEnum(meta$$«i.name», meta$$«i.name»$token, «indexedName»);'''
        } else if (ref.isWrapper) {  // boxed types: separate call for Null, else unbox!
            '''if («indexedName» == null) w.writeNull(meta$$«i.name»); else w.addField(meta$$«i.name», «indexedName»);'''
        } else {
            '''w.addField(meta$$«i.name», «indexedName»);'''
        }
    }

    def private static makeWrite2(ClassDefinition d, FieldDefinition i, String index) '''
        «IF resolveElem(i.datatype) != null»
            «makeWrite(i, index, resolveElem(i.datatype), DataTypeExtension::get(i.datatype))»
        «ELSE»
            w.addField(meta$$«i.name», (BonaPortable)«index»);
        «ENDIF»
    '''

    def private static makeFoldedWrite2(ClassDefinition d, FieldDefinition i, String index) '''
        «IF resolveElem(i.datatype) != null»
            «makeWrite(i, index, resolveElem(i.datatype), DataTypeExtension::get(i.datatype))»
        «ELSE»
            if («index» == null) {
                w.writeNull(meta$$«i.name»);
            } else if (pfc.getComponent() == null) {
                w.addField(meta$$«i.name», (BonaPortable)«index»);             // full / recursive object output
            } else {
                // write a specific subcomponent
                «index».foldedOutput(w, pfc.getComponent());   // recurse specific field
            }
        «ENDIF»
    '''

    def public static writeSerialize(ClassDefinition d) '''
        /* serialize the object into a String. uses implicit toString() member functions of elementary data types */
        @Override
        public <_E extends Exception> void serializeSub(MessageComposer<_E> w) throws _E {
            «IF d.extendsClass != null»
                // recursive call of superclass first
                super.serializeSub(w);
                w.writeSuperclassSeparator();
            «ENDIF»
            «FOR i:d.fields»
                «IF i.isAggregate»
                    if («i.name» == null) {
                        w.writeNullCollection(meta$$«i.name»);
                    } else {
                        «IF i.isArray != null»
                            w.startArray(meta$$«i.name», «i.name».length, 0);
                            for (int _i = 0; _i < «i.name».length; ++_i)
                                «makeWrite2(d, i, indexedName(i))»
                            w.terminateArray();
                        «ELSEIF i.isList != null || i.isSet != null»
                            w.startArray(meta$$«i.name», «i.name».size(), 0);
                            for («JavaDataTypeNoName(i, true)» _i : «i.name»)
                                «makeWrite2(d, i, indexedName(i))»
                            w.terminateArray();
                        «ELSE»
                            w.startMap(meta$$«i.name», «i.name».size());
                            for (Map.Entry<«i.isMap.indexType»,«JavaDataTypeNoName(i, true)»> _i : «i.name».entrySet()) {
                                // write (key, value) tuples
                                w.addField(StaticMeta.MAP_INDEX_META_«i.isMap.indexType.toUpperCase», _i.getKey());
                                «makeWrite2(d, i, indexedName(i))»
                            }
                            w.terminateArray();
                        «ENDIF»
                    }
                «ELSE»
                    «makeWrite2(d, i, indexedName(i))»
                «ENDIF»
            «ENDFOR»
        }

    '''

    def public static writeFoldedSerialize(ClassDefinition d) '''
        /* serialize selected fields of the object. */
        @Override
        public <_E extends Exception> void foldedOutput(MessageComposer<_E> w, ParsedFoldingComponent pfc) throws _E {
            String _n = pfc.getFieldname();
            «FOR i:d.fields»
                if (_n.equals("«i.name»")) {
                    «IF !i.isAggregate»
                        «makeFoldedWrite2(d, i, indexedName(i))»
                    «ELSE»
                        if («i.name» == null) {
                            w.writeNullCollection(meta$$«i.name»);
                        } else {
                            «IF i.isArray != null»
                                if (pfc.index < 0) {
                                    w.startArray(meta$$«i.name», «i.name».length, 0);
                                    for (int _i = 0; _i < «i.name».length; ++_i) {
                                        «makeFoldedWrite2(d, i, indexedName(i))»
                                    }
                                    w.terminateArray();
                                } else {
                                    if (pfc.index < «i.name».length) {
                                        // output single element
                                        «makeFoldedWrite2(d, i, i.name + "[pfc.index]")»
                                    }
                                }
                            «ELSEIF i.isList != null»
                                if (pfc.index < 0) {
                                    w.startArray(meta$$«i.name», «i.name».size(), 0);
                                    for («JavaDataTypeNoName(i, true)» _i : «i.name») {
                                        «makeFoldedWrite2(d, i, indexedName(i))»
                                    }
                                    w.terminateArray();
                                } else {
                                    if (pfc.index < «i.name».size()) {
                                        // output single element
                                        «makeFoldedWrite2(d, i, i.name + ".get(pfc.index)")»
                                    }
                                }
                            «ELSEIF i.isSet != null»
                                w.startArray(meta$$«i.name», «i.name».size(), 0);
                                for («JavaDataTypeNoName(i, true)» _i : «i.name») {
                                    «makeFoldedWrite2(d, i, indexedName(i))»
                                }
                                w.terminateArray();
                            «ELSE»
                                «IF i.isMap.indexType == "String"»
                                    if (pfc.alphaIndex == null) {
                                «ELSE»
                                    if (pfc.index < 0) {
                                «ENDIF»
                                    w.startMap(meta$$«i.name», «i.name».size());
                                    for (Map.Entry<«i.isMap.indexType»,«JavaDataTypeNoName(i, true)»> _i : «i.name».entrySet()) {
                                        // write (key, value) tuples
                                        w.addField(StaticMeta.MAP_INDEX_META_«i.isMap.indexType.toUpperCase», _i.getKey());
                                        «makeFoldedWrite2(d, i, indexedName(i))»
                                    }
                                    w.terminateArray();
                                } else {
                                    «IF i.isMap.indexType == "String"»
                                        «makeFoldedWrite2(d, i, i.name + ".get(pfc.alphaIndex)")»
                                    «ELSEIF i.isMap.indexType == "Integer"»
                                        «makeFoldedWrite2(d, i, i.name + ".get(Integer.valueOf(pfc.index))")»
                                    «ELSE»
                                        «makeFoldedWrite2(d, i, i.name + ".get(Long.valueOf((long)pfc.index))")»
                                    «ENDIF»
                                }
                            «ENDIF»
                        }
                    «ENDIF»
                    return;
                }
            «ENDFOR»
            // not found
            «IF d.extendsClass != null»
                super.foldedOutput(w, pfc);
            «ENDIF»
        }

   '''
}
