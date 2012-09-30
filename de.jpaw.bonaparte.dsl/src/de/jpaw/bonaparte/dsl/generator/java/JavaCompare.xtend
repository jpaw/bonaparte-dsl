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

class JavaCompare {
    
    def private static writeCompareSub(FieldDefinition i, String index) {
        switch (getJavaDataType(i.datatype).toLowerCase) {
        case "byte []":             '''Arrays.equals(«index», that.«index»)'''
        case "bytearray":           '''«index».contentEquals(that.«index»)'''
        case "gregoriancalendar":   '''«index».compareTo(that.«index») == 0'''
        default:                    '''«index».equals(that.«index»)'''
        }
    } 
    
    
    // TODO: do float and double need special handling as well? (Double.compare(a, b) ?)
    def private static writeCompareStuff(FieldDefinition i, String index, String end) ''' 
        «IF resolveObj(i.datatype) != null || (resolveElem(i.datatype) != null && resolveElem(i.datatype).name.toLowerCase.equals("object"))»
            ((«index» == null && that.«index» == null) || «index».hasSameContentsAs(that.«index»))«end»
        «ELSE»
            «IF DataTypeExtension::get(i.datatype).isPrimitive»
                «index» == that.«index»«end»
            «ELSE»
                ((«index» == null && that.«index» == null) || «writeCompareSub(i, index)»)«end»
            «ENDIF»
        «ENDIF»
    '''

    def public static writeHash(FieldDefinition i, ClassDefinition d, DataTypeExtension ref) {
        if (ref.isPrimitive) {
            if (i.isArray != null)
                return '''(«i.name» == null ? 0 : Arrays.hashCode(«i.name»))'''
            else if (i.isList != null)
                return '''(«i.name» == null ? 0 : «i.name».hashCode())'''  // List has a good implementation
            else {
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
            if (i.isArray != null)
                return '''(«i.name» == null ? 0 : Arrays.deepHashCode(«i.name»))'''
            else if (i.isList != null)
                return '''(«i.name» == null ? 0 : «i.name».hashCode())'''  // List has a good implementation
            else {
                // a single non-primitive type (Boxed or Joda or Date?)....
                if (ref.javaType != null && ref.javaType.equals("byte []"))
                    // special treatment required, again!
                    return '''(«i.name» == null ? 0 : Arrays.hashCode(«i.name»))'''   // straightforward recursion
                else       
                    return '''(«i.name» == null ? 0 : «i.name».hashCode())'''   // straightforward recursion
            }
        }
    }                    
    
    def public static writeComparisonCode(ClassDefinition d) '''
        @Override
        public int hashCode() {
            int _hash = «IF d.extendsClass != null»super.hashCode()«ELSE»997«ENDIF»;
            «FOR i:d.fields»
                _hash = 29 * _hash + «writeHash(i, d, DataTypeExtension::get(i.datatype))»;
            «ENDFOR»
            return _hash;              
        }

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

        «IF d.extendsClass != null»
        @Override
        «ENDIF»
        protected boolean equalsSub(BonaPortable _that) {
            «d.name» that = («d.name»)_that;
            «IF d.extendsClass != null»
                return super.equalsSub(_that)
            «ELSE»
                return true
            «ENDIF»
            «FOR i:d.fields»
                «IF i.isArray != null || i.isList != null»
                    && ((«i.name» == null && that.«i.name» == null) || («i.name» != null && that.«i.name» != null && arrayCompareSub$«i.name»(that)))
                «ELSE»
                    && «writeCompareStuff(i, i.name, "")»
                «ENDIF»
            «ENDFOR»
            ;
        }
        «FOR i:d.fields»
            «IF i.isArray != null»
                private boolean arrayCompareSub$«i.name»(«d.name» that) {
                    // both «i.name» and that «i.name» are known to be not null
                    if («i.name».length != that.«i.name».length)
                        return false;
                    for (int _i = 0; _i < «i.name».length; ++_i)
                        if (!(«writeCompareStuff(i, i.name + "[_i]", "))")»
                            return false;
                    return true;
                }
            «ENDIF»
            «IF i.isList != null»
                private boolean arrayCompareSub$«i.name»(«d.name» that) {
                    // both «i.name» and that «i.name» are known to be not null
                    if («i.name».size() != that.«i.name».size())
                        return false;
                    // indexed access is not optional, but sequential access will be left for later optimization 
                    for (int _i = 0; _i < «i.name».size(); ++_i)
                        if (!(«writeCompareStuff(i, i.name + ".get(_i)", "))")»
                            return false;
                    return true;
                }
            «ENDIF»
        «ENDFOR»
    '''
}
/*
 *                         Iterator<«JavaDataTypeNoName(i, true)» _l = that.iterator();
                        for («JavaDataTypeNoName(i, true)» _i : «i.name») {
                            if (!_l.hasNext())
                                return false;
                            «JavaDataTypeNoName(i, true)» _j = _l.next();
                            if (!(«writeCompareStuff(i, "e", "))")»
                                return false;
                        return true;
 
 */