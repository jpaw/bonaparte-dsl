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
        if (ref.category == DataCategory.ENUM || ref.category == DataCategory.XENUM || ref.category == DataCategory.ENUMALPHA) {        
            return '''_w.addEnum(meta$$«i.name», meta$$«i.name»$token, «indexedName»);''' // enums / xenums to be written as their ordinals or tokens, the meta for the enum as well as the expansion are provided
        } else if (ref.category == DataCategory.ENUMSET || ref.category == DataCategory.ENUMSETALPHA || ref.category == DataCategory.XENUMSET) { // enum sets to be written by their marshalled data. A null check is required.
            '''if («indexedName» == null) _w.writeNull(meta$$«i.name»); else _w.addField(meta$$«i.name», «indexedName».marshal());'''
        } else if (ref.isWrapper) {  // boxed types: separate call for Null, else unbox!
            '''if («indexedName» == null) _w.writeNull(meta$$«i.name»); else _w.addField(meta$$«i.name», «indexedName»);'''
        } else {
            '''_w.addField(meta$$«i.name», «indexedName»);'''
        }
    }

    def private static makeWrite(FieldDefinition i, String indexedName, ClassDefinition objectType, DataTypeExtension ref) {
        if (objectType?.externalType === null) {
            // regular bonaportable
            return '''_w.addField(meta$$«i.name», (BonaPortable)«indexedName»);'''
        } else {
            // custom types (external types)
            val cc = '''if (!_w.addExternal(meta$$«i.name», «indexedName»))'''
            // the marshaller is a regular method if no external adapter is provided, else a static method of the adapter class
            val marshaller = if (objectType.bonaparteAdapterClass !== null) '''«objectType.adapterClassName».marshal(«indexedName»)''' else '''«indexedName».marshal()'''
            if (objectType.singleField) {
                // delegate to first field or the proxy. As that can be a primitive type, must do a null check here...
                val metaName = '''«objectType.name».meta$$«objectType.firstField.name»'''
                return '''«cc» { if («indexedName» == null) _w.writeNull(«metaName»); else _w.addField(«metaName», «marshaller»); }'''
            } else {
                return '''«cc» _w.addField(meta$$«i.name», «marshaller»);'''
            }
        }
    }
    
    def private static makeWrite2(ClassDefinition d, FieldDefinition i, String index) {
        val ref = DataTypeExtension::get(i.datatype)
        if (ref.elementaryDataType !== null)
            return makeWrite(i, index, ref.elementaryDataType, ref)
        else
            return makeWrite(i, index, ref.objectDataType, ref)
    }

    def private static makeFoldedWrite2(ClassDefinition d, FieldDefinition i, String index)  {
        val ref = DataTypeExtension::get(i.datatype)
        if (ref.elementaryDataType !== null)
            return makeWrite(i, index, ref.elementaryDataType, ref)
        else
            return '''
                if («index» == null) {
                    _w.writeNull(meta$$«i.name»);
                } else if (_pfc.getComponent() == null) {
                    // full / recursive object output
                    «makeWrite(i, index, ref.objectDataType, ref)»
                } else {
                    «IF ref.objectDataType?.externalType === null»
                        // write a specific subcomponent
                        «index».foldedOutput(_w, _pfc.getComponent());   // recurse specific field
                    «ELSE»
                        // no op. Cannot output components of external data types
                    «ENDIF»
                }
            '''
    }

    def public static writeSerialize(ClassDefinition d) '''
        /* serialize the object into a String. uses implicit toString() member functions of elementary data types */
        @Override
        public <_E extends Exception> void serializeSub(MessageComposer<_E> _w) throws _E {
            «IF d.extendsClass !== null»
                // recursive call of superclass first
                super.serializeSub(_w);
                _w.writeSuperclassSeparator();
            «ENDIF»
            «FOR i:d.fields»
                «IF i.isAggregate»
                    if («i.name» == null) {
                        _w.writeNullCollection(meta$$«i.name»);
                    } else {
                        «IF i.isArray !== null»
                            _w.startArray(meta$$«i.name», «i.name».length, 0);
                            for (int _i = 0; _i < «i.name».length; ++_i)
                                «makeWrite2(d, i, indexedName(i))»
                            _w.terminateArray();
                        «ELSEIF i.isList !== null || i.isSet !== null»
                            _w.startArray(meta$$«i.name», «i.name».size(), 0);
                            for («JavaDataTypeNoName(i, true)» _i : «i.name»)
                                «makeWrite2(d, i, indexedName(i))»
                            _w.terminateArray();
                        «ELSE»
                            _w.startMap(meta$$«i.name», «i.name».size());
                            for (Map.Entry<«i.isMap.indexType»,«JavaDataTypeNoName(i, true)»> _i : «i.name».entrySet()) {
                                // write (key, value) tuples
                                _w.addField(StaticMeta.MAP_INDEX_META_«i.isMap.indexType.toUpperCase», _i.getKey());
                                «makeWrite2(d, i, indexedName(i))»
                            }
                            _w.terminateArray();
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
        public <_E extends Exception> void foldedOutput(MessageComposer<_E> _w, ParsedFoldingComponent _pfc) throws _E {
            String _n = _pfc.getFieldname();
            «FOR i:d.fields»
                if (_n.equals("«i.name»")) {
                    «IF !i.isAggregate»
                        «makeFoldedWrite2(d, i, indexedName(i))»
                    «ELSE»
                        if («i.name» == null) {
                            _w.writeNullCollection(meta$$«i.name»);
                        } else {
                            «IF i.isArray !== null»
                                if (_pfc.index < 0) {
                                    _w.startArray(meta$$«i.name», «i.name».length, 0);
                                    for (int _i = 0; _i < «i.name».length; ++_i) {
                                        «makeFoldedWrite2(d, i, indexedName(i))»
                                    }
                                    _w.terminateArray();
                                } else {
                                    if (_pfc.index < «i.name».length) {
                                        // output single element
                                        «makeFoldedWrite2(d, i, i.name + "[_pfc.index]")»
                                    }
                                }
                            «ELSEIF i.isList !== null»
                                if (_pfc.index < 0) {
                                    _w.startArray(meta$$«i.name», «i.name».size(), 0);
                                    for («JavaDataTypeNoName(i, true)» _i : «i.name») {
                                        «makeFoldedWrite2(d, i, indexedName(i))»
                                    }
                                    _w.terminateArray();
                                } else {
                                    if (_pfc.index < «i.name».size()) {
                                        // output single element
                                        «makeFoldedWrite2(d, i, i.name + ".get(_pfc.index)")»
                                    }
                                }
                            «ELSEIF i.isSet !== null»
                                _w.startArray(meta$$«i.name», «i.name».size(), 0);
                                for («JavaDataTypeNoName(i, true)» _i : «i.name») {
                                    «makeFoldedWrite2(d, i, indexedName(i))»
                                }
                                _w.terminateArray();
                            «ELSE»
                                «IF i.isMap.indexType == "String"»
                                    if (_pfc.alphaIndex == null) {
                                «ELSE»
                                    if (_pfc.index < 0) {
                                «ENDIF»
                                    _w.startMap(meta$$«i.name», «i.name».size());
                                    for (Map.Entry<«i.isMap.indexType»,«JavaDataTypeNoName(i, true)»> _i : «i.name».entrySet()) {
                                        // write (key, value) tuples
                                        _w.addField(StaticMeta.MAP_INDEX_META_«i.isMap.indexType.toUpperCase», _i.getKey());
                                        «makeFoldedWrite2(d, i, indexedName(i))»
                                    }
                                    _w.terminateArray();
                                } else {
                                    «IF i.isMap.indexType == "String"»
                                        «makeFoldedWrite2(d, i, i.name + ".get(_pfc.alphaIndex)")»
                                    «ELSEIF i.isMap.indexType == "Integer"»
                                        «makeFoldedWrite2(d, i, i.name + ".get(Integer.valueOf(_pfc.index))")»
                                    «ELSE»
                                        «makeFoldedWrite2(d, i, i.name + ".get(Long.valueOf((long)_pfc.index))")»
                                    «ENDIF»
                                }
                            «ENDIF»
                        }
                    «ENDIF»
                    return;
                }
            «ENDFOR»
            // not found
            «IF d.extendsClass !== null»
                super.foldedOutput(_w, _pfc);
            «ENDIF»
        }

   '''
}
