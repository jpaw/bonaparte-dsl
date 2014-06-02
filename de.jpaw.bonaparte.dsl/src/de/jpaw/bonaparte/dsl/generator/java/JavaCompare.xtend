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

class JavaCompare {
    private static final Logger logger = Logger.getLogger(JavaCompare)
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
        	logger.error("Field " + f.name + " of class " + d.name + " is not required, but used as a Comparable criteria")
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

    def private static writeCompareSub(FieldDefinition i, DataTypeExtension ref, String index, String tindex) {
        switch (getJavaDataType(i.datatype)) {
        case "byte []":     '''Arrays.equals(«index», «tindex»)'''
        case "ByteArray":   '''«index».contentEquals(«tindex»)'''
        case "BigDecimal":  '''BigDecimalTools.equals(«index», «ref.elementaryDataType.decimals», «tindex», «ref.elementaryDataType.decimals»)'''     // was: «index».compareTo(«tindex») == 0'''  // do not use equals!!!
        // case "Double":      '''«index».compareTo(«tindex») == 0''' // difference to equals is for NaN values
        // case "Float":       '''«index».compareTo(«tindex») == 0''' // difference to equals is for NaN values
        default:            '''«index».equals(«tindex»)'''
        }
    }

    def private static writeCompareStuff(FieldDefinition i, String index, String tindex, String end) {
        val ref = DataTypeExtension::get(i.datatype)
        return '''
            «IF ref.category == DataCategory::OBJECT»
                ((«index» == null && «tindex» == null) || («index» != null && «index».hasSameContentsAs(«tindex»)))«end»
            «ELSE»
                «IF DataTypeExtension::get(i.datatype).isPrimitive»
                    «index» == «tindex»«end»
                «ELSE»
                    ((«index» == null && «tindex» == null) || («index» != null && «writeCompareSub(i, ref, index, tindex)»))«end»
                «ENDIF»
            «ENDIF»
        '''
    }

    def public static writeHash(FieldDefinition i, DataTypeExtension ref) {
        if (ref.isPrimitive) {
            if (i.isArray !== null)
                return '''(«i.name» == null ? 0 : Arrays.hashCode(«i.name»))'''
            else {
                // isMap, isSet and isList cannot be true, they don't work with primitives...
                // a single primitive type....
                switch (ref.javaType) {
                case "Float":   '''(new Float(«i.name»).hashCode())'''
                case "Double":  '''(new Double(«i.name»).hashCode())'''
                case "Boolean": '''(«i.name» ? 1231 : 1237)'''  // as in Boolean.hashCode() according to Java specs
                case "Long":    '''(int)(«i.name»^(«i.name»>>>32))'''  // as in Java Long
                case "Integer": '''«i.name»'''
                default:         '''(int)«i.name»'''  // byte, short, char
                }
            }
        } else {
            if (i.isArray !== null)
                return '''(«i.name» == null ? 0 : Arrays.deepHashCode(«i.name»))'''
            else if (i.aggregate)
                return '''(«i.name» == null ? 0 : «i.name».hashCode())'''  // List, Map and Set have a usable implementation
            else {
                // a single non-primitive type (Boxed or Joda or Date?)....
                if (ref.javaType !== null && ref.javaType.equals("byte []"))
                    // special treatment required, again!
                    return '''(«i.name» == null ? 0 : Arrays.hashCode(«i.name»))'''     // straightforward recursion
                else if ("BigDecimal".equals(ref.javaType))
                    return '''BigDecimalTools.hashCode(«i.name», «ref.elementaryDataType.decimals»)'''   // specific implementation with scaling
                else
                    return '''(«i.name» == null ? 0 : «i.name».hashCode())'''           // standard implementation
            }
        }
    }

    def public static writeHash(ClassDefinition d) '''
        @Override
        public int hashCode() {
            int _hash = «IF d.extendsClass !== null»super.hashCode()«ELSE»997«ENDIF»;
            «FOR i:d.fields»
                _hash = 29 * _hash + «writeHash(i, DataTypeExtension::get(i.datatype))»;
            «ENDFOR»
            return _hash;
        }

        '''

    def public static writeComparisonCode(ClassDefinition d) '''
        // see http://www.artima.com/lejava/articles/equality.html for all the pitfalls with equals()...
        @Override
        public boolean equals(Object _that) {
            if (_that == null)
                return false;
            if (!(_that instanceof «d.name»))
                return false;
            if (this == _that)
                return true;
            return equalsSub((BonaPortable)_that);
        }

        // same function, but with second argument of (almost) known type
        @Override
        public boolean hasSameContentsAs(BonaPortable _that) {
            if (_that == null)
                return false;
            if (!(_that instanceof «d.name»))
                return false;
            if (this == _that)
                return true;
            return equalsSub(_that);
        }

        «IF d.extendsClass !== null»
        @Override
        «ENDIF»
        protected boolean equalsSub(BonaPortable _that) {
            «d.name»«genericDef2StringAsParams(d.genericParameters)» that = («d.name»«genericDef2StringAsParams(d.genericParameters)»)_that;
            «IF d.extendsClass !== null»
                return super.equalsSub(_that)
            «ELSE»
                return true
            «ENDIF»
            «FOR i:d.fields»
                «IF i.aggregate»
                    && ((«i.name» == null && that.«i.name» == null) || («i.name» != null && that.«i.name» != null && xCompareSub$«i.name»(that)))
                «ELSE»
                    && «writeCompareStuff(i, i.name, "that." + i.name, "")»
                «ENDIF»
            «ENDFOR»
            ;
        }
        «FOR i:d.fields»
            «IF i.isArray !== null»
                private boolean xCompareSub$«i.name»(«d.name»«genericDef2StringAsParams(d.genericParameters)» that) {
                    // both «i.name» and that «i.name» are known to be not null
                    if («i.name».length != that.«i.name».length)
                        return false;
                    for (int _i = 0; _i < «i.name».length; ++_i)
                        if (!(«writeCompareStuff(i, i.name + "[_i]", "that." + i.name + "[_i]", "))")»
                            return false;
                    return true;
                }
            «ENDIF»
            «IF i.isList !== null»
                private boolean xCompareSub$«i.name»(«d.name»«genericDef2StringAsParams(d.genericParameters)» that) {
                    // both «i.name» and that «i.name» are known to be not null
                    if («i.name».size() != that.«i.name».size())
                        return false;
                    // indexed access is not optional, but sequential access will be left for later optimization
                    for (int _i = 0; _i < «i.name».size(); ++_i)
                        if (!(«writeCompareStuff(i, i.name + ".get(_i)", "that." + i.name + ".get(_i)", "))")»
                            return false;
                    return true;
                }
            «ENDIF»
            «IF i.isSet !== null»
                private boolean xCompareSub$«i.name»(«d.name»«genericDef2StringAsParams(d.genericParameters)» that) {
                    // both «i.name» and that «i.name» are known to be not null
                    if («i.name».size() != that.«i.name».size())
                        return false;
                    return «i.name».equals(that.«i.name»);
                }
            «ENDIF»
            «IF i.isMap !== null»
                private boolean xCompareSub$«i.name»(«d.name»«genericDef2StringAsParams(d.genericParameters)» that) {
                    // both «i.name» and that «i.name» are known to be not null
                    if («i.name».size() != that.«i.name».size())
                        return false;
                    // method is to verify all entries are the same
                    for (Map.Entry<«i.isMap.indexType», «JavaDataTypeNoName(i, true)»> _i : «i.name».entrySet()) {
                        «JavaDataTypeNoName(i, true)» _t = that.«i.name».get(_i.getKey());
                        if (!(«writeCompareStuff(i, "_i.getValue()", "_t", "))")»
                            return false;
                    }
                    return true;
                }
            «ENDIF»
        «ENDFOR»
    '''
}
