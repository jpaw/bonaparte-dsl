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
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.DataCategory

import static extension de.jpaw.bonaparte.dsl.generator.DataTypeExtension.*
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension

class JavaFrozen {
    def private static boolean supportsFreeze(DataTypeExtension ref) {
        return !ref.isJsonField &&
          (ref.objectDataType === null || (!ref.objectDataType.immutable && ref.objectDataType.externalType === null))
    }

    def private static boolean noFreezeBecauseImmutable(DataTypeExtension ref) {
        return (ref.elementaryDataType !== null
            && ref.category != DataCategory.OBJECT
            && ref.category != DataCategory.ENUMSET
            && ref.category != DataCategory.ENUMSETALPHA
            && ref.category != DataCategory.XENUMSET
          ) || (ref.objectDataType !== null && ref.objectDataType.immutable);
    }

    def private static invokeFreezeMethod(DataTypeExtension ref, String applyOnWhat) {
        if (ref.isJsonField)
            return '''FreezeTools.freeze(«applyOnWhat»);'''
        if (ref.supportsFreeze)
            return '''«applyOnWhat».freeze();'''
    }

    def private static getFrozenClone(DataTypeExtension ref, String applyOnWhat) {
        if (ref.isJsonField)
            return '''FrozenCloneTools.frozenClone(«applyOnWhat»)'''
        if (ref.supportsFreeze)
            return '''(«applyOnWhat» == null ? null : «applyOnWhat».ret$FrozenClone())'''
        else
            return applyOnWhat  // no .freeze() required / exists, return the identity
    }

    def private static getMutableClone(DataTypeExtension ref, String applyOnWhat) {
        if (ref.isJsonField)
            return '''_deepCopy ? MutableCloneTools.mutableClone(«applyOnWhat», _unfreezeCollections) : «applyOnWhat»'''
        if (ref.supportsFreeze)
            return '''_deepCopy && «applyOnWhat» != null ? «applyOnWhat».ret$MutableClone(_deepCopy, _unfreezeCollections) : «applyOnWhat»'''
        else
            return applyOnWhat  // no .freeze() required / exists, return the identity. The condition is irrelevant in this case
    }

    // write the code to freeze one field.
    def private static writeFreezeField(FieldDefinition i, ClassDefinition cd) {
        val ref = i.datatype.get
        if (ref.noFreezeBecauseImmutable) {
            // Lists which contain optional fields (nulls) must use something else
            if (i.isList !== null && !i.isRequired) {
                return '''«i.name» = «i.name» == null ? null : Collections.unmodifiableList(new ArrayList(«i.name»));'''
            }
            if (i.aggregate) {  // Set, Map, List are possible here, classes which contain arrays are not freezable!
                val token = i.aggregateToken
                '''
                // copy unless the «token» is null
                if («i.name» != null)
                    «i.name» = Collections.unmodifiable«token»(«i.name»);
                '''
            } else {
                // nothing to do
                return null
            }
        } else {
            if (i.isList !== null) {
                '''
                if («i.name» != null) {
                    final List<«ref.javaType»> _b = new ArrayList(«i.name».size());
                    for («ref.javaType» _i: «i.name») {
                        if (_i != null)
                            «ref.invokeFreezeMethod("_i")»
                        _b.add(_i);
                    }
                    «i.name» = Collections.unmodifiableList(_b);
                }
                '''
            } else if (i.isSet !== null) {
                '''
                if («i.name» != null) {
                    final Set<«ref.javaType»> _b = new HashSet(«i.name».size() * 2);
                    for («ref.javaType» _i: «i.name») {
                        if (_i != null)
                            «ref.invokeFreezeMethod("_i")»
                        _b.add(_i);
                    }
                    «i.name» = Collections.unmodifiableSet(_b);
                }
                '''
            } else if (i.isMap !== null) {
                val genericsArg = '''<«IF (i.isMap !== null)»«i.isMap.indexType», «ENDIF»«ref.javaType»>'''
                '''
                if («i.name» != null) {
                    final Map«genericsArg» _b = new HashMap(«i.name».size());
                    for (Map.Entry«genericsArg» _i: «i.name».entrySet()) {
                        if (_i.getValue() != null)
                            «ref.invokeFreezeMethod("_i.getValue()")»
                        _b.put(_i.getKey(), _i.getValue());
                    }
                    «i.name» = Collections.unmodifiableMap(_b);
                }
                '''
            } else {
                // scalar object. Do nothing if it is external or immutable
                if (ref.supportsFreeze)
                    return '''
                        if («i.name» != null) {
                            «i.name».freeze();
                        }
                    '''
            }
        }
    }

    // write the code to freeze one field into another class
    def private static writeFreezeFieldCopy(FieldDefinition i, ClassDefinition cd) {
        val ref = i.datatype.get
        if (ref.noFreezeBecauseImmutable) {
            if (i.aggregate) {
                val token = i.aggregateToken
                '''
                // copy unless the «token» is null
                if («i.name» != null)
                    _new.«i.name» = Collections.unmodifiable«token»(new «token.typeOfAggregate»«token»(«i.name»));
                else
                    _new.«i.name» = «i.name»;
                '''
            } else {
                '''
                    _new.«i.name» = «i.name»;
                '''
            }
        } else {
            // collection of something. We need a cast if type type is a generic one.
            val genericsRef = i.datatype.objectDataType?.genericsParameterRef
            val optionalCast = if (genericsRef !== null) '''(«genericsRef.name»)'''
            if (i.isList !== null) {
                '''
                if («i.name» != null) {
                    final List<«ref.javaType»> _b = new ArrayList(«i.name».size());
                    for («ref.javaType» _i: «i.name») {
                        _b.add(«optionalCast»«ref.getFrozenClone("_i")»);
                    }
                    _new.«i.name» = Collections.unmodifiableList(_b);
                } else {
                    _new.«i.name» = null;
                }
                '''
            } else if (i.isSet !== null) {
                '''
                if («i.name» != null) {
                    final Set<«ref.javaType»> _b = new HashSet(«i.name».size() * 2);
                    for («ref.javaType» _i: «i.name») {
                        _b.add(«optionalCast»«ref.getFrozenClone("_i")»);
                    }
                    _new.«i.name» = Collections.unmodifiableSet(_b);
                } else {
                    _new.«i.name» = null;
                }
                '''
            } else if (i.isMap !== null) {
                val genericsArg = '''<«IF (i.isMap !== null)»«i.isMap.indexType», «ENDIF»«ref.javaType»>'''
                '''
                if («i.name» != null) {
                    final Map«genericsArg» _b = new HashMap(«i.name».size());
                    for (Map.Entry«genericsArg» _i: «i.name».entrySet())
                        _b.put(_i.getKey(), «optionalCast»«ref.getFrozenClone("_i.getValue()")»);
                    _new.«i.name» = Collections.unmodifiableMap(_b);
                } else {
                    _new.«i.name» = null;
                }
                '''
            } else {
                // scalar object
                return '''_new.«i.name» = «ref.getFrozenClone(i.name)»;'''
            }
        }
    }

    // write the code to copy one field into a mutable copy
    def private static writeToMutableFieldCopy(FieldDefinition i, ClassDefinition cd) {
        val ref = i.datatype.get
        if (!i.aggregate) {
            if (ref.noFreezeBecauseImmutable) {
                '''
                _new.«i.name» = «i.name»;
                '''
            } else {
                '''
                _new.«i.name» = «ref.getMutableClone(i.name)»;
                '''
            }
        } else {
            // collection of something.
            '''
            if («i.name» == null || !_unfreezeCollections) {
                _new.«i.name» = «i.name»;
            } else {
                // unfreeze collection
                «IF ref.noFreezeBecauseImmutable»
                    «IF i.isArray !== null»
                        _new.«i.name» = Arrays.copyOf(«i.name», «i.name».length);
                    «ELSEIF i.isList !== null»
                        _new.«i.name» = new Array«i.JavaDataTypeNoName(false)»(«i.name».size());
                        _new.«i.name».addAll(«i.name»);
                    «ELSEIF i.isSet !== null»
                        _new.«i.name» = new Hash«i.JavaDataTypeNoName(false)»(«i.name».size());
                        _new.«i.name».addAll(«i.name»);
                    «ELSEIF i.isMap !== null»
                        _new.«i.name» = new Hash«i.JavaDataTypeNoName(false)»(«i.name».size());
                        _new.«i.name».putAll(«i.name»);
                    «ENDIF»
                «ELSE»
                    «IF i.isArray !== null»
                        _new.«i.name» = Arrays.copyOf(«i.name», «i.name».length);
                        «IF ref.supportsFreeze»
                            if (_deepCopy) {
                                for (int _i = 0; _i < «i.name».length; ++_i)
                                    if (_new.«i.name»[_i] != null)
                                        _new.«i.name»[_i] = _new.«i.name»[_i].ret$MutableClone(_deepCopy, _unfreezeCollections);
                            }
                        «ENDIF»
                    «ELSEIF i.isList !== null»
                        _new.«i.name» = new ArrayList<«i.JavaDataTypeNoName(true)»>(«i.name».size());
                        for («i.JavaDataTypeNoName(true)» _e : «i.name»)
                            _new.«i.name».add(«ref.getMutableClone("_e")»);
                    «ELSEIF i.isSet !== null»
                        _new.«i.name» = new HashSet<«i.JavaDataTypeNoName(true)»>(«i.name».size());
                        for («i.JavaDataTypeNoName(true)» _e : «i.name»)
                            _new.«i.name».add(«ref.getMutableClone("_e")»);
                    «ELSEIF i.isMap !== null»
                        _new.«i.name» = new Hash«i.JavaDataTypeNoName(false)»(«i.name».size());
                        for (Map.Entry<«i.isMap.indexType», «ref.javaType»> _e : «i.name».entrySet())
                            _new.«i.name».put(_e.getKey(), «ref.getMutableClone("_e.getValue()")»);
                    «ENDIF»
                «ENDIF»
            }
            '''
        }
    }


    def public static writeFreezingCode(ClassDefinition cd) '''
        public static boolean class$isFreezable() {
            return «cd.isFreezable»;
        }

        «IF cd.extendsClass === null»
            «IF cd.unfreezable || cd.root.immutable»
                @Override
                public final boolean was$Frozen() {
                    return «cd.root.immutable»;
                }
                protected final void verify$Not$Frozen() {
                }
            «ELSE»
                private transient boolean _was$Frozen = false;      // current state of this instance
                @Override
                public final boolean was$Frozen() {
                    return _was$Frozen;
                }
                protected final void verify$Not$Frozen() {
                    if (_was$Frozen)
                        throw new RuntimeException("Setter called for frozen instance of class " + getClass().getName());
                }
            «ENDIF»
        «ENDIF»
        @Override
        public void freeze() {
            «IF !cd.isFreezable»
                throw new RuntimeException(getClass().getName() + " is not freezable");
            «ELSEIF cd.root.immutable»
            «ELSE»
                «FOR f: cd.fields»
                    «f.writeFreezeField(cd)»
                «ENDFOR»
                «IF cd.extendsClass === null»
                    _was$Frozen = true;
                «ELSE»
                    super.freeze();
                «ENDIF»
            «ENDIF»
        }
        @Override
        public «cd.name» ret$FrozenClone() throws ObjectValidationException {
            «IF cd.abstract»
                throw new RuntimeException("This method is really not there (abstract class). Most likely someone has handcoded bonaparte classes (and missed to implement some methods).");
            «ELSE»
                «IF !cd.isFreezable»
                    throw new ObjectValidationException(ObjectValidationException.NOT_FREEZABLE, getClass().getName(), "");
                «ELSEIF cd.root.immutable»
                    return this;
                «ELSE»
                    if (was$Frozen()) // no need to copy!
                        return this;
                    «cd.name» _new = new «cd.name»();
                    frozenCloneSub(_new);
                    return _new;
                «ENDIF»
            «ENDIF»
        }
        «IF !cd.root.immutable && cd.isFreezable»
            «IF cd.parent !== null»
                @Override
                protected void frozenCloneSub(«cd.root.bonPackageName».«cd.root.name» __new) throws ObjectValidationException {
                    «cd.name» _new = («cd.name»)__new;
            «ELSE»
                protected void frozenCloneSub(«cd.name» _new) throws ObjectValidationException {
            «ENDIF»
                «FOR f: cd.fields»
                    «f.writeFreezeFieldCopy(cd)»
                «ENDFOR»
                «IF cd.extendsClass === null»
                    _new._was$Frozen = true;
                «ELSE»
                    super.frozenCloneSub(_new);
                «ENDIF»
            }
        «ENDIF»
        @Override
        public «cd.name» ret$MutableClone(boolean _deepCopy, boolean _unfreezeCollections) throws ObjectValidationException {
            «IF cd.abstract»
                throw new RuntimeException("This method is really not there (abstract class). Most likely someone has handcoded bonaparte classes (and missed to implement some methods).");
            «ELSE»
                «IF cd.root.immutable»
                    throw new ObjectValidationException(ObjectValidationException.NOT_FREEZABLE, getClass().getName(), "");
                «ELSE»
                    «cd.name» _new = new «cd.name»();
                    mutableCloneSub(_new, _deepCopy, _unfreezeCollections);
                    return _new;
                «ENDIF»
            «ENDIF»
        }
        «IF !cd.root.immutable»
            «IF cd.parent !== null»
                @Override
                protected void mutableCloneSub(«cd.root.bonPackageName».«cd.root.name» __new, boolean _deepCopy, boolean _unfreezeCollections) throws ObjectValidationException {
                    «cd.name» _new = («cd.name»)__new;
            «ELSE»
                protected void mutableCloneSub(«cd.name» _new, boolean _deepCopy, boolean _unfreezeCollections) throws ObjectValidationException {
            «ENDIF»
                «FOR f: cd.fields»
                    «f.writeToMutableFieldCopy(cd)»
                «ENDFOR»
                «IF cd.extendsClass !== null»
                    super.mutableCloneSub(_new, _deepCopy, _unfreezeCollections);
                «ENDIF»
            }
        «ENDIF»

    '''
}
