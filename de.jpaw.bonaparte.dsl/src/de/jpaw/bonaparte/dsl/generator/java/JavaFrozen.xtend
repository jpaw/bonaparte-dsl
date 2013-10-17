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
import de.jpaw.bonaparte.dsl.bonScript.XXmlAccess
import de.jpaw.bonaparte.dsl.generator.DataCategory

import static extension de.jpaw.bonaparte.dsl.generator.DataTypeExtension.*
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*

class JavaFrozen {
    
    // write the code to freeze one field.
    def private static writeFreezeField(FieldDefinition i, ClassDefinition cd) {
        val ref = i.datatype.get
        if (ref.elementaryDataType != null && ref.category != DataCategory.OBJECT) {
            if (i.aggregate) {
                val token = i.aggregateToken
                '''
                // copy unless the «token» is immutable already (or null)
                if («i.name» != null && !(«i.name» instanceof Immutable«token»))
                    «i.name» = Immutable«token».copyOf(«i.name»);
                '''
            } else {
                // nothing to do
                ''''''
            }
        } else {
            if (i.isList != null || i.isSet != null) {
                val token = i.aggregateToken
                '''
                if («i.name» != null) {
                    Immutable«token».Builder<«ref.javaType»> _b = Immutable«token».Builder<«ref.javaType»>.builder();
                    for («ref.javaType» _i: «i.name»)
                        if (_i != null) {
                            _i.freeze();
                            _b.add(_i);
                        }
                    «i.name» = _b.build();
                }
                '''
            } else if (i.isMap != null) {
                val genericsArg = '''<«IF (i.isMap != null)»«i.isMap.indexType», «ENDIF»«ref.javaType»>''' 
                '''
                if («i.name» != null) {
                    ImmutableMap.Builder<«genericsArg»> _b = ImmutableMap.Builder<«genericsArg»>.builder();
                    for (ImmutableSet<Map.Entry«genericsArg»> _i: «i.name»)
                        if (_i.value != null) {
                            _i.value.freeze();
                            _b.put(_i);
                        }
                    «i.name» = _b.build();
                }
                '''
            } else {
                // scalar object
                '''
                if («i.name» != null) {
                    «i.name».freeze();
                }
                '''
            }
        }                

    }
    
    // write the code to freeze one field.
    def private static writeFreezeFieldCopy(FieldDefinition i, ClassDefinition cd) {
        val ref = i.datatype.get
        if (ref.elementaryDataType != null && ref.category != DataCategory.OBJECT) {
            if (i.aggregate) {
                val token = i.aggregateToken
                '''
                // copy unless the «token» is immutable already (or null)
                if («i.name» != null && !(«i.name» instanceof Immutable«token»))
                    _new.«i.name» = Immutable«token».copyOf(«i.name»);
                else
                    _new.«i.name» = «i.name»;
                '''
            } else {
                '''
                    _new.«i.name» = «i.name»;
                '''
            }
        } else {
            if (i.isList != null || i.isSet != null) {
                val token = i.aggregateToken
                '''
                if («i.name» != null) {
                    Immutable«token».Builder<«ref.javaType»> _b = Immutable«token».Builder<«ref.javaType»>.builder();
                    for («ref.javaType» _i: «i.name»)
                        if (_i != null) {
                            _b.add(_i.get$FrozenClone());
                        }
                    _new.«i.name» = _b.build();
                } else {
                    _new.«i.name» = null;
                }
                '''
            } else if (i.isMap != null) {
                val genericsArg = '''<«IF (i.isMap != null)»«i.isMap.indexType», «ENDIF»«ref.javaType»>''' 
                '''
                if («i.name» != null) {
                    ImmutableMap.Builder<«genericsArg»> _b = ImmutableMap.Builder<«genericsArg»>.builder();
                    for (ImmutableSet<Map.Entry«genericsArg»> _i: «i.name»)
                        if (_i.value != null) {
                            _i.value = _i.value.get$FrozenClone();
                            _b.put(_i);
                        }
                    _new.«i.name» = _b.build();
                } else {
                    _new.«i.name» = null;
                }
                '''
            } else {
                // scalar object
                '''
                if («i.name» != null) {
                    _new.«i.name» = «i.name».get$FrozenClone();
                } else {
                    _new.«i.name» = null;
                }
                '''
            }
        }                

    }
    
    
    def public static writeFreezingCode(ClassDefinition cd) '''
        public static boolean class$isFreezable() {
            return «cd.isFreezable»;
        }
        @Override
        public boolean is$Freezable() {
            return «cd.isFreezable»;
        }
        
        «IF cd.extendsClass == null»
            «IF cd.unfreezable || cd.root.immutable»
                @Override
                public final boolean is$Frozen() {
                    return «cd.root.immutable»;
                }
                protected final void verify$Not$Frozen() {
                }
            «ELSE»
                «IF cd.getRelevantXmlAccess == XXmlAccess::FIELD»
                    @XmlTransient
                «ENDIF»
                private boolean _is$Frozen = false;      // current state of this instance
                @Override
                public final boolean is$Frozen() {
                    return _is$Frozen;
                }
                protected final void verify$Not$Frozen() {
                    if (_is$Frozen)
                        throw new RuntimeException("Setter called for frozen instance of class " + getClass().getName());
                }
            «ENDIF»
        «ENDIF»
        @Override
        public void freeze() throws ObjectValidationException {
            «IF !cd.isFreezable»
                throw new ObjectValidationException(ObjectValidationException.NOT_FREEZABLE, getClass().getName(), "");
            «ELSEIF cd.root.immutable»
            «ELSE»
                «FOR f: cd.fields»
                    «f.writeFreezeField(cd)»
                «ENDFOR»
                «IF cd.extendsClass == null»
                    _is$Frozen = true;
                «ELSE»
                    super.freeze();
                «ENDIF»
            «ENDIF»
        }
        @Override
        public «cd.name» get$FrozenClone() throws ObjectValidationException {
            «IF !cd.isFreezable»
                throw new ObjectValidationException(ObjectValidationException.NOT_FREEZABLE, getClass().getName(), "");
            «ELSEIF cd.root.immutable»
                return this;
            «ELSE»
                if (is$Frozen()) // no need to copy!
                    return this;
                «cd.name» _new = new «cd.name»();
                frozenCloneSub(_new);
                return _new;
            «ENDIF»
        }
        «IF !cd.root.immutable && cd.isFreezable»
            «IF cd.parent != null»@Override«ENDIF»
            protected void frozenCloneSub(«cd.name» _new) throws ObjectValidationException {
                «FOR f: cd.fields»
                    «f.writeFreezeFieldCopy(cd)»
                «ENDFOR»
                «IF cd.extendsClass == null»
                    _new._is$Frozen = true;
                «ELSE»
                    super.frozenCloneSub(_new);
                «ENDIF»                    
            }
        «ENDIF»
        @Override
        public «cd.name» get$MutableClone(boolean deepCopy, boolean unfreezeCollections) throws ObjectValidationException {
            «IF cd.root.immutable»
                throw new ObjectValidationException(ObjectValidationException.NOT_FREEZABLE, getClass().getName(), "");
            «ELSE»
                «cd.name» _new = new «cd.name»();
                mutableCloneSub(_new, deepCopy, unfreezeCollections);
                return _new;
            «ENDIF»
        }
        «IF !cd.root.immutable»
            «IF cd.parent != null»@Override«ENDIF»
            protected void mutableCloneSub(«cd.name» _new, boolean deepCopy, boolean unfreezeCollections) throws ObjectValidationException {
                «FOR f: cd.fields»
                    «f.writeFreezeFieldCopy(cd)»
                «ENDFOR»
                «IF cd.extendsClass != null»
                    super.mutableCloneSub(_new, deepCopy, unfreezeCollections);
                «ENDIF»                    
            }
        «ENDIF»

    '''
}