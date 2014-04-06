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

import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.persistence.dsl.bDDL.ElementCollectionRelationship

class ElementCollections {
    
    def static private makeJoin(ElementCollectionRelationship ec, int i)
        '''@JoinColumn(name="«ec.keyColumns.get(i)»")'''
        
    def private static writeJoinColumns(ElementCollectionRelationship ec, FieldDefinition c) {
        if (ec.keyColumns.size == 1) {
            '''«ec.makeJoin(0)»'''
        } else {
            '''{«(0 .. ec.keyColumns.size-1).map[ec.makeJoin(it)].join(', ')»}'''
        }
    }
    
    def public static CharSequence writePossibleCollectionOrRelation(FieldDefinition c, ElementCollectionRelationship it) '''
        @ElementCollection«IF fetchType != null»(fetch=FetchType.«fetchType»)«ENDIF»
        @CollectionTable(name="«tablename»", joinColumns=«writeJoinColumns(c)»)
        «IF mapKey != null»
            @MapKeyColumn(name="«mapKey»"«IF mapKeySize > 0 && c.isMap.indexType == "String"», length=«mapKeySize»«ENDIF»)
        «ENDIF»
    '''
}