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

package de.jpaw.bonaparte.jpa.dsl.generator.java

import de.jpaw.bonaparte.jpa.dsl.bDDL.EntityDefinition
import de.jpaw.bonaparte.dsl.generator.DataCategory
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.jpa.dsl.generator.YUtil.*
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import java.util.List
import de.jpaw.bonaparte.jpa.dsl.generator.PrimaryKeyType

class EqualsHash {
    /////////////////////////////////////////////////////////////////////
    // hashCode
    /////////////////////////////////////////////////////////////////////
    
    def private static hashSub33(FieldDefinition i) {
        val myIndexList = i.indexList
        return '''
            «IF myIndexList !== null»
                «myIndexList.map[i.name + it].map['''(«it» == null ? 0 : «it».hashCode())'''].join('\n+ ')»
            «ELSE»
                («i.name» == null ? 0 : «i.name».hashCode())
            «ENDIF»
        '''
    }
    
    def private static writeHashExpressionForSingleField(FieldDefinition i, DataTypeExtension ref) {
        if (ref.isPrimitive) {
            if (i.isArray !== null)
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
            if (i.isArray !== null)
                return '''(«i.name» == null ? 0 : Arrays.deepHashCode(«i.name»))'''
            else if (i.aggregate)  // List, Map, Set
                return i.hashSub33
            else {
                // a single non-primitive type (Boxed or Joda or Date?)....
                if (ref.javaType !== null && (ref.javaType.equals("byte []") || ref.javaType.equals("BonaPortable")))
                    // special treatment required, again! (but not for ByteArray, we do this with usertypes now as well...) 
                    return '''(«i.name» == null ? 0 : Arrays.hashCode(«i.name»))'''   // straightforward recursion
                else
                    return '''(«i.name» == null ? 0 : «i.name».hashCode())'''   // straightforward recursion
            }
        }
    }

    def private static writeHashSubForListOfFields(List<FieldDefinition> fields) '''
        «IF fields !== null»
            «FOR i:fields»
                _hash = 29 * _hash + «writeHashExpressionForSingleField(i, DataTypeExtension::get(i.datatype))»;
            «ENDFOR»
        «ENDIF»
    '''
    def private static CharSequence writeHashSubForAllClassFields(ClassDefinition d) '''
        «d.extendsClass?.classRef?.writeHashSubForAllClassFields»
        «d.fields.writeHashSubForListOfFields»
    '''
    
    def public static writeHashMethodForClassPlusExtraFields(ClassDefinition cls, List<FieldDefinition> fields) '''
        @Override
        public int hashCode() {
            int _hash = 997;
            «cls?.writeHashSubForAllClassFields»
            «fields?.writeHashSubForListOfFields»
            return _hash;
        }
    '''
    
    /////////////////////////////////////////////////////////////////////
    // combined equals and hashCode (for entities embeddable key)
    /////////////////////////////////////////////////////////////////////
    
    def private static writeEqualsAndHashCodeForEmbeddable(EntityDefinition e, String name) '''
        @Override
        public int hashCode() {
            return «name» == null ? -1 : «name».hashCode();
        }
        @Override
        public boolean equals(Object _that) {
            if (this == _that)
                return true;
            if (_that == null || getClass() != _that.getClass())
                return false;
            return «name» != null && «name».equals(((«e.name»)_that).«name»);
        }
    '''
        
    /////////////////////////////////////////////////////////////////////
    // equals
    /////////////////////////////////////////////////////////////////////

    // equals delegator to ensure correct type. anything below is using the appropriate type    
    def private static writeEqualsDelegator(EntityDefinition e, CharSequence codeToInsert) '''
        @Override
        public boolean equals(Object _that) {
            if (this == _that)
                return true;
            if (_that == null || getClass() != _that.getClass())  // !(_that instanceof «e.name») (take care of proxies?)
                return false;
            return equalsSub(_that);
        }
        «IF e.extendsClass !== null»
        @Override
        «ENDIF»
        protected boolean equalsSub(Object _that) {
            «e.name» __that = («e.name»)_that;
            «codeToInsert»
        }
    '''

    
    // only caller in next method
    def private static writeCompareStuffSub(FieldDefinition i, String index) {
        switch (getJavaDataType(i.datatype)) {
        case "BonaPortable":        '''Arrays.equals(«index», __that.«index»)'''  // mapped to byte []
        case "byte []":             '''Arrays.equals(«index», __that.«index»)'''
        case "BigDecimal":          '''«index».compareTo(__that.«index») == 0'''  // we want the comparison to be "true" if the values are the same on the database
//        case "Instant":             '''«index».compareTo(__that.«index») == 0'''  // mapped to Calendar or Date or using userdata fields
//        case "LocalTime":           '''«index».compareTo(__that.«index») == 0'''  // mapped to Calendar or Date or using userdata fields
//        case "LocalDate":           '''«index».compareTo(__that.«index») == 0'''  // mapped to Calendar or Date or using userdata fields
//        case "LocalDateTime":       '''«index».compareTo(__that.«index») == 0'''  // mapped to Calendar or Date or using userdata fields
        default:                    '''«index».equals(__that.«index»)'''
        }
    }

    // only caller in next method
    def private static writeCompareStuff(FieldDefinition i, String index, String end) '''
        «IF DataTypeExtension::get(i.datatype).category == DataCategory::OBJECT»
            ((«index» == null && __that.«index» == null) || «index».equals(__that.«index»))«end»
        «ELSE»
            «IF DataTypeExtension::get(i.datatype).isPrimitive»
                «index» == __that.«index»«end»
            «ELSE»
                ((«index» == null && __that.«index» == null) || «writeCompareStuffSub(i, index)»)«end»
            «ENDIF»
        «ENDIF»
    '''

    // main entry to write the code - multiple different callers.
    // __that holds an object of the same type and is not null
    def private static writeEqualsSubForListOfFields(List<FieldDefinition> l) '''
        «FOR i: l»
            «IF i.isArray !== null»
                && ((«i.name» == null && __that.«i.name» == null) || («i.name» != null && __that.«i.name» != null && arrayCompareSub$«i.name»(__that)))
            «ELSEIF i.aggregate»
                «IF i.indexList !== null»
                    «i.indexList.map[i.name + it].map['''&& ((«it» == null && __that.«it» == null) || («it» != null && «it».equals(__that)))'''].join('\n')»
                «ELSE»
                    && ((«i.name» == null && __that.«i.name» == null) || («i.name» != null && «i.name».equals(__that)))
                «ENDIF»
            «ELSE»
                && «writeCompareStuff(i, i.name, "")»
            «ENDIF»
        «ENDFOR»
    '''

    def private static notNullForNonPrimitives(FieldDefinition f) {
        val ref = DataTypeExtension::get(f.datatype)
        if (!ref.isPrimitive)
            '''
                && «f.name» != null   // not yet assigned => treat it as different
            '''
    }
    
    def private static writeEqualsConditionForListOfFields(List<FieldDefinition> fields) '''
        return true
        «FOR f : fields»
             «f.notNullForNonPrimitives»
        «ENDFOR»
        «fields.writeEqualsSubForListOfFields»
            ;
    '''
    
    def private static equalsConditionSubMethodForAllFieldsOfEntity(EntityDefinition e) '''
        «IF e.extendsClass !== null»
            return super.equalsSub(_that)
        «ELSE»
            return true  // there is possible issue here if the related entity extends a Java class for relations, which declares fields as well
        «ENDIF»
            «e.pojoType.fields.writeEqualsSubForListOfFields»
            ;
    '''


    
    def public static writeEqualsAndHashCode(EntityDefinition e, PrimaryKeyType primaryKeyType) {
        switch (primaryKeyType) {
        case PrimaryKeyType::IMPLICIT_EMBEDDABLE:       // delegates to some object (another generated class)
            writeEqualsAndHashCodeForEmbeddable(e, "key")
        case PrimaryKeyType::EXPLICIT_EMBEDDABLE:       // delegates to some object (another generated class)
            writeEqualsAndHashCodeForEmbeddable(e, e.embeddablePk.field.name)
        case PrimaryKeyType::SINGLE_COLUMN: '''
                «writeHashMethodForClassPlusExtraFields(null, e.pk.columnName)»
                «e.writeEqualsDelegator(e.pk.columnName.writeEqualsConditionForListOfFields)»
            '''
        case PrimaryKeyType::ID_CLASS: '''
                «writeHashMethodForClassPlusExtraFields(e.pkPojo, null)»
                «e.writeEqualsDelegator(e.pkPojo.fields.writeEqualsConditionForListOfFields)»
            '''
        default: '''
                «writeHashMethodForClassPlusExtraFields(e.pojoType, null)»
                «e.writeEqualsDelegator(e.equalsConditionSubMethodForAllFieldsOfEntity)»
            '''
        }
    }
    
    // invoked where the container is not an entity and therefore extends... does not work. But we know there is no parent
    def public static writeKeyEquals(String name, List<FieldDefinition> fields) '''
        @Override
        public boolean equals(Object _that) {
            if (this == _that)
                return true;
            if (_that == null || !(_that instanceof «name»))
                return false;
            «name» __that = («name»)_that;
            return true
            «fields.writeEqualsSubForListOfFields»
                ;
        }
    '''

}
