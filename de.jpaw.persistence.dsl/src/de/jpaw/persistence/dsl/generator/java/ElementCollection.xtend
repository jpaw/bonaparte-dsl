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
import de.jpaw.persistence.dsl.bDDL.ManyToOneRelationship
import org.apache.commons.logging.Log
import org.apache.commons.logging.LogFactory

import static extension de.jpaw.persistence.dsl.generator.YUtil.*
import de.jpaw.bonaparte.dsl.generator.XUtil
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.persistence.dsl.bDDL.ElementCollectionRelationship

class ElementCollections {
    private static Log logger = LogFactory::getLog("de.jpaw.persistence.dsl.generator.java.ElementCollections") // jcl
    
    def static private makeJoin(ElementCollectionRelationship ec, int i)
        '''@JoinColumn(name="«ec.keyColumns.get(i)»")'''
        
    def private static writeJoinColumns(ElementCollectionRelationship ec, FieldDefinition c, EntityDefinition e) {
        if (ec.keyColumns.size == 1) {
            '''«ec.makeJoin(0)»'''
        } else {
            '''{«(0 .. ec.keyColumns.size-1).map[ec.makeJoin(it)].join(', ')»}'''
        }
    }
    
    def public static CharSequence writePossibleCollectionOrRelation(FieldDefinition c, EntityDefinition e) {
        if (e.elementCollections == null)
            return ''''''
        e.elementCollections.filter[name == c].map[ '''
            @ElementCollection«IF fetchType != null»(fetch=FetchType.«fetchType»)«ENDIF»
            @CollectionTable(name="«tablename»", joinColumns=«writeJoinColumns(c, e)»)
            «IF mapKey != null»
                @MapKeyColumn(name="«mapKey»"«IF mapKeySize > 0 && c.isMap.indexType == "String"», length=«mapKeySize»«ENDIF»)
            «ENDIF»
        ''' ].join
    }
}