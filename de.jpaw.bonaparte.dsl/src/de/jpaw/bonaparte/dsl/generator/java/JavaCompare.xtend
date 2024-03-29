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
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.DataCategory
import org.apache.log4j.Logger
import java.util.Map
import de.jpaw.bonaparte.dsl.bonScript.XXmlAccess

class JavaCompare {
    private static final Logger LOGGER = Logger.getLogger(JavaCompare)
    private static final Map<String,String> JAVA_PRIMITIVE_TO_WRAPPER = #{
        "byte" -> "Byte",
        "short" -> "Short",
        "int" -> "Integer",
        "long" -> "Long",
        "float" -> "Float",
        "double" -> "Double",
        "boolean" -> "Boolean",
        "char" -> "Character"
    }

    def private static writeCompareToField(ClassDefinition d, FieldDefinition f) {
        val ref = DataTypeExtension::get(f.datatype)
        if (!f.isRequired)
            LOGGER.error("Field " + f.name + " of class " + d.name + " is not required, but used as a Comparable criteria")
        if (ref.isPrimitive) {
            // must use the wrapper. use some autoboxing here
            return '''
                _i = «JAVA_PRIMITIVE_TO_WRAPPER.get(f.datatype.getJavaDataType)».valueOf(«f.name»).compareTo(_o.«f.name»);
                if (_i != 0)
                    return _i;
            '''
        } else {
            // is an object anyway
            return '''
                _i = «f.name».compareTo(_o.«f.name»);
                if (_i != 0)
                    return _i;
            '''
        }
    }
    // only invoked if d.orderedByList != null
    def public static writeComparable(ClassDefinition d) '''
        @Override
        public int compareTo(«d.name» _o) {
            int _i;
            «FOR f: d.orderedByList.field»
                «writeCompareToField(d, f)»
            «ENDFOR»
            return 0;  // objects are the same
        }
    '''

    /** Creates a comparison of two fields (same members of different class instances) when the first is known not to be null. */
    def private static writeCompareSub(FieldDefinition i, DataTypeExtension ref, String index, String tindex) {
        if (ref.category == DataCategory::OBJECT) {
            if (ref.objectDataType?.externalType !== null) {
                // external type. use equals() or compareTo()
                if (ref.objectDataType.useCompareToInsteadOfEquals)
                    // FIXME: there is an issue here, as elements of Lists will always be compared using equals(), also for types where we want to use compareTo()!
                    return '''«index».compareTo(«tindex») == 0'''
                else
                    return '''«index».equals(«tindex»)'''
            } else {
                // regular bonaportable. use "sameContents" method
                return '''«index».equals(«tindex»)'''
            }
        }
        // not object. treat elementary data types next
        switch (getJavaDataType(i.datatype)) {
        case "byte []":     '''Arrays.equals(«index», «tindex»)'''
        case "BigDecimal":  '''(«tindex» != null && «index».compareTo(«tindex») == 0)'''
        // case "BigDecimal":  '''BigDecimalTools.equals(«index», «ref.elementaryDataType.decimals», «tindex», «ref.elementaryDataType.decimals»)'''     // was: «index».compareTo(«tindex») == 0'''
        // case "Double":      '''«index».compareTo(«tindex») == 0''' // difference to equals is for NaN values
        // case "Float":       '''«index».compareTo(«tindex») == 0''' // difference to equals is for NaN values
        default:            '''«index».equals(«tindex»)'''
        }
    }

    /** Creates a comparison of two fields (same members of different class instances) when both can be null. */
    def public static doCompareWithNull(String a, String b, CharSequence complex) {
        return '''(«a» == null ? «b» == null : «complex»)'''
    }

    /** Creates a comparison of two fields (same members of different class instances) when both can be null, for a specific instance (array index / Map/List/Set member). */
    def private static writeCompareStuff(FieldDefinition i, String index, String tindex, String end) {
        val ref = DataTypeExtension::get(i.datatype)
        return '''
            «IF ref.isPrimitive»
                «index» == «tindex»«end»
            «ELSE»
                «doCompareWithNull(index, tindex, writeCompareSub(i, ref, index, tindex))»«end»
            «ENDIF»
        '''
    }

    /** Write a hashcode expression for a single primitive field. */
    def public static writePrimitiveSimpleHash(FieldDefinition i, DataTypeExtension ref) {
        switch (ref.javaType) {
        case "Float":   '''Float.hashCode(«i.name»)'''
        case "Double":  '''Double.hashCode(«i.name»)'''
        case "Boolean": '''(«i.name» ? 1231 : 1237)'''  // as in Boolean.hashCode() according to Java specs
        case "Long":    '''(int)(«i.name»^(«i.name»>>>32))'''  // as in Java Long
        case "Integer": '''«i.name»'''
        default:        '''(int)«i.name»'''  // byte, short, char
        }
    }

    /** Write a hashcode expression for a single non primitive field. (Needs null check, and special treatment for BigDecimal, for compatibility with our equals() implementation). */
    def public static writeNonPrimitiveSimpleHash(FieldDefinition i, DataTypeExtension ref) {
        switch (ref.javaType) {
        case "byte []":
            // special treatment required, again!
            return '''(«i.name» == null ? 0 : Arrays.hashCode(«i.name»))'''     // straightforward recursion
        case "BigDecimal":
            return '''BigDecimalTools.hashCode(«i.name», «ref.elementaryDataType.decimals»)'''   // specific implementation with scaling
        default:
            return '''(«i.name» == null ? 0 : «i.name».hashCode())'''           // standard implementation
        }
    }

    def public static writeHash(FieldDefinition i, DataTypeExtension ref) {
        if (ref.isPrimitive) {
            if (i.isArray !== null)
                return '''(«i.name» == null ? 0 : Arrays.hashCode(«i.name»))'''
            else {
                // isMap, isSet and isList cannot be true, they don't work with primitives...
                // a single primitive type....
                return writePrimitiveSimpleHash(i, ref)
            }
        } else {
            if (i.isArray !== null)
                return '''(«i.name» == null ? 0 : Arrays.deepHashCode(«i.name»))'''
            else if (i.aggregate)
                return '''(«i.name» == null ? 0 : «i.name».hashCode())'''  // List, Map and Set have a usable implementation
            else {
                // a single non-primitive type (Boxed or Joda or Date?)....
                return writeNonPrimitiveSimpleHash(i, ref)
            }
        }
    }

    def private static doCacheHashHere(ClassDefinition d) {
        return !d.abstract && d.parentCacheHash && (d.isImmutable || d.freezable)
    }
    def private static writeHashSub(ClassDefinition d) '''
        int _hash = «IF d.extendsClass !== null»super.hashCode() * 31 + «ENDIF»PQON$HASH;
        «FOR i:d.fields»
            _hash = 29 * _hash + «writeHash(i, DataTypeExtension::get(i.datatype))»;
        «ENDFOR»
    '''

    def public static writeHash(ClassDefinition d) '''
        «IF d.doCacheHashHere»
            «IF d.getRelevantXmlAccess == XXmlAccess::FIELD»
                @XmlTransient
            «ENDIF»
            private transient int _hash$cache = 0;

            @Override
            public int hashCode() {
                if (_hash$cache != 0)
                    return _hash$cache;
                «d.writeHashSub»
                «IF d.root.isImmutable»
                    _hash$cache = _hash;  // store the value for subsequent invocations
                «ELSE»
                    if (was$Frozen())
                        _hash$cache = _hash;  // store the value for subsequent invocations
                «ENDIF»
                return _hash;
            }
        «ELSE»
            @Override
            public int hashCode() {
                «d.writeHashSub»
                return _hash;
            }
        «ENDIF»

        '''

    def public static writeComparisonCode(ClassDefinition d) '''
        // see http://www.artima.com/lejava/articles/equality.html for all the pitfalls with equals()...
        @Override
        public boolean equals(Object _that) {
            if (this == _that)
                return true;
            if (_that == null || getClass() != _that.getClass())
                return false;
            return equalsSub(_that);
        }

        «IF d.extendsClass !== null»
        @Override
        «ENDIF»
        protected boolean equalsSub(Object __that) {
            «d.name»«genericDef2StringAsParams(d.genericParameters)» _that = («d.name»«genericDef2StringAsParams(d.genericParameters)»)__that;
            «IF d.extendsClass !== null»
                return super.equalsSub(_that)
            «ELSE»
                return true
            «ENDIF»
            «FOR i:d.fields»
                «IF i.aggregate»
                    && ((«i.name» == null && _that.«i.name» == null) || («i.name» != null && _that.«i.name» != null && xCompareSub$«i.name»(_that)))
                «ELSE»
                    && «writeCompareStuff(i, i.name, "_that." + i.name, "")»
                «ENDIF»
            «ENDFOR»
            ;
        }
        «FOR i:d.fields»
            «IF i.isArray !== null»
                private boolean xCompareSub$«i.name»(«d.name»«genericDef2StringAsParams(d.genericParameters)» _that) {
                    // both «i.name» and _that «i.name» are known to be not null
                    if («i.name».length != _that.«i.name».length)
                        return false;
                    for (int _i = 0; _i < «i.name».length; ++_i)
                        if (!(«writeCompareStuff(i, i.name + "[_i]", "_that." + i.name + "[_i]", "))")»
                            return false;
                    return true;
                }
            «ENDIF»
            «IF i.isList !== null»
                private boolean xCompareSub$«i.name»(«d.name»«genericDef2StringAsParams(d.genericParameters)» _that) {
                    // both «i.name» and _that «i.name» are known to be not null
                    if («i.name».size() != _that.«i.name».size())
                        return false;
                    // indexed access is not optional, but sequential access will be left for later optimization
                    for (int _i = 0; _i < «i.name».size(); ++_i)
                        if (!(«writeCompareStuff(i, i.name + ".get(_i)", "_that." + i.name + ".get(_i)", "))")»
                            return false;
                    return true;
                }
            «ENDIF»
            «IF i.isSet !== null»
                private boolean xCompareSub$«i.name»(«d.name»«genericDef2StringAsParams(d.genericParameters)» _that) {
                    // both «i.name» and _that «i.name» are known to be not null
                    if («i.name».size() != _that.«i.name».size())
                        return false;
                    return «i.name».equals(_that.«i.name»);
                }
            «ENDIF»
            «IF i.isMap !== null»
                private boolean xCompareSub$«i.name»(«d.name»«genericDef2StringAsParams(d.genericParameters)» _that) {
                    // both «i.name» and _that «i.name» are known to be not null
                    if («i.name».size() != _that.«i.name».size())
                        return false;
                    // method is to verify all entries are the same
                    for (Map.Entry<«i.isMap.indexType», «JavaDataTypeNoName(i, true)»> _i : «i.name».entrySet()) {
                        «JavaDataTypeNoName(i, true)» _t = _that.«i.name».get(_i.getKey());
                        if (!(«writeCompareStuff(i, "_i.getValue()", "_t", "))")»
                            return false;
                    }
                    return true;
                }
            «ENDIF»
        «ENDFOR»
    '''
}
