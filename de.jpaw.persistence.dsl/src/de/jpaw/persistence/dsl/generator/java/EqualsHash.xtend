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

package de.jpaw.persistence.dsl.generator.java

import de.jpaw.persistence.dsl.bDDL.EntityDefinition
import de.jpaw.bonaparte.dsl.generator.DataCategory
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.persistence.dsl.generator.YUtil.*
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import java.util.List
import de.jpaw.persistence.dsl.generator.PrimaryKeyType

class EqualsHash {
    def private static writeCompareSub(FieldDefinition i, String index) {
        switch (getJavaDataType(i.datatype)) {
        case "BonaPortable":        '''Arrays.equals(«index», that.«index»)''' // mapped to byte []
        case "byte []":             '''Arrays.equals(«index», that.«index»)'''
        case "ByteArray":           '''Arrays.equals(«index», that.«index»)''' // '''«index».contentEquals(that.«index»)''' is mapped to byte[]
        case "Calendar":            '''«index».compareTo(that.«index») == 0'''
        case "LocalDate":           '''«index».compareTo(that.«index») == 0'''  // is mapped to calendar
        case "LocalDateTime":       '''«index».compareTo(that.«index») == 0'''  // is mapped to calendar
        default:                    '''«index».equals(that.«index»)'''
        }
    }


    // TODO: do float and double need special handling as well? (Double.compare(a, b) ?)
    def private static writeCompareStuff(FieldDefinition i, String index, String end) '''
        «IF DataTypeExtension::get(i.datatype).category == DataCategory::OBJECT»
            ((«index» == null && that.«index» == null) || «index».equals(that.«index»))«end»
        «ELSE»
            «IF DataTypeExtension::get(i.datatype).isPrimitive»
                «index» == that.«index»«end»
            «ELSE»
                ((«index» == null && that.«index» == null) || «writeCompareSub(i, index)»)«end»
            «ENDIF»
        «ENDIF»
    '''

    def private static hashSub33(FieldDefinition i) '''
        «IF i.isList != null && i.properties.hasProperty(PROP_UNROLL)»
            «(1 .. i.isList.maxcount).map[i.name + String::format(i.indexPattern, it)].map['''(«it» == null ? 0 : «it».hashCode())'''].join('\n+ ')»
        «ELSE»
            («i.name» == null ? 0 : «i.name».hashCode())
        «ENDIF»
    '''
    
    def public static writeHash(FieldDefinition i, DataTypeExtension ref) {
        if (ref.isPrimitive) {
            if (i.isArray != null)
                return '''(«i.name» == null ? 0 : Arrays.hashCode(«i.name»))'''
            else if (i.aggregate)  // List, Map, Set
                return i.hashSub33
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
            else if (i.aggregate)  // List, Map, Set
                return i.hashSub33
            else {
                // a single non-primitive type (Boxed or Joda or Date?)....
                if (ref.javaType != null && (ref.javaType.equals("byte []") || ref.javaType.equals("ByteArray") || ref.javaType.equals("BonaPortable")))
                    // special treatment required, again!
                    return '''(«i.name» == null ? 0 : Arrays.hashCode(«i.name»))'''   // straightforward recursion
                else
                    return '''(«i.name» == null ? 0 : «i.name».hashCode())'''   // straightforward recursion
            }
        }
    }

    def private static writeHashSub2(List<FieldDefinition> l) '''
        «IF l != null»
            «FOR i:l»
                _hash = 29 * _hash + «writeHash(i, DataTypeExtension::get(i.datatype))»;
            «ENDFOR»
        «ENDIF»
    '''
    def private static CharSequence writeHashSub(ClassDefinition d) '''
        «IF d.extendsClass != null»
            «writeHashSub(d.extendsClass.referenceDataType as ClassDefinition)»
        «ENDIF»
        «writeHashSub2(d.fields)»
    '''
    def public static writeHash(ClassDefinition d, List<FieldDefinition> l) '''
        @Override
        public int hashCode() {
            int _hash = 997;
            «IF d != null»
                «writeHashSub(d)»
            «ENDIF»
            «writeHashSub2(l)»
            return _hash;
        }

        '''

    def private static writeEqualsSub(List<FieldDefinition> l) '''
        «FOR i: l»
            «IF i.isArray != null»
                && ((«i.name» == null && that.«i.name» == null) || («i.name» != null && that.«i.name» != null && arrayCompareSub$«i.name»(that)))
            «ELSEIF i.aggregate»
                «IF i.isList != null && i.properties.hasProperty(PROP_UNROLL)»
                    «(1 .. i.isList.maxcount).map[i.name + String::format(i.indexPattern, it)].map['''&& ((«it» == null && that.«it» == null) || («it» != null && «it».equals(that)))'''].join('\n')»
                «ELSE»
                    && ((«i.name» == null && that.«i.name» == null) || («i.name» != null && «i.name».equals(that)))
                «ENDIF»
            «ELSE»
                && «writeCompareStuff(i, i.name, "")»
            «ENDIF»
        «ENDFOR»
    '''

    def private static writeEquals(EntityDefinition e) '''
        @Override
        public boolean equals(Object _that) {
            if (_that == null)
                return false;
            if (!(_that instanceof «e.name»))
                return false;
            if (this == _that)
                return true;
            return equalsSub(_that);
        }

        «IF e.extendsClass != null»
        @Override
        «ENDIF»
        protected boolean equalsSub(Object _that) {
            «e.name» that = («e.name»)_that;
            «IF e.extendsClass != null»
                return super.equalsSub(_that)
            «ELSE»
                return true  // there is possible issue here if the related entity extends a Java class for relations, which declares fiels as well
            «ENDIF»
            «writeEqualsSub(e.pojoType.fields)»
            ;
        }
    '''

    def private static writeSub(EntityDefinition e, String name) '''
            @Override
            public int hashCode() {
                return «name» == null ? -1 : «name».hashCode();
            }
            public boolean equals(Object obj) {
                if (this == obj)
                    return true;
                if (obj == null || this.getClass() != obj.getClass())
                    return false;
                if («name» == null) // not yet assigned => treat it as different
                    return false;
                return this.«name».equals(((«e.name»)obj).«name»);
            }
    '''
    
    def public static writeEqualsAndHashCode(EntityDefinition e, PrimaryKeyType primaryKeyType) {
        switch (primaryKeyType) {
        case PrimaryKeyType::IMPLICIT_EMBEDDABLE:
            writeSub(e, "key")
        case PrimaryKeyType::EXPLICIT_EMBEDDABLE:
            writeSub(e, e.embeddablePk.field.name)
        case PrimaryKeyType::SINGLE_COLUMN:
            writeSub(e, e.pk.columnName.get(0).name)
        default:
            // NONE and  PrimaryKeyType::ID_CLASS:
            '''
            «writeHash(e.pojoType, null)»
            «writeEquals(e)»
        '''
        }
    }
    
    def public static writeKeyEquals(String name, List<FieldDefinition> l) '''
        @Override
        public boolean equals(Object _that) {
            if (_that == null)
                return false;
            if (!(_that instanceof «name»))
                return false;
            if (this == _that)
                return true;
            «name» that = («name»)_that;
            return true
            «l.writeEqualsSub»
            ;
        }
    '''

}
