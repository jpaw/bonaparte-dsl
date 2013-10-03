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
import de.jpaw.persistence.dsl.bDDL.Relationship
import org.apache.log4j.Logger

import static extension de.jpaw.persistence.dsl.generator.YUtil.*
import de.jpaw.bonaparte.dsl.generator.XUtil
import de.jpaw.persistence.dsl.bDDL.OneToMany
import java.util.List
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition

class MakeRelationships {
    private static Logger logger = Logger.getLogger(MakeRelationships)
    
    def static private makeJoin(Relationship m, int i, boolean readonly, List<FieldDefinition> childPkColumns) '''
        @JoinColumn(name="«m.referencedFields.columnName.get(i).name.java2sql»", referencedColumnName="«childPkColumns.get(i).name.java2sql»"«IF readonly», insertable=false, updatable=false«ENDIF»)
    '''

    def private static boolean nonOptional(Relationship m, EntityDefinition e) {
        var oneOptional = false
        for (c : m.referencedFields.columnName)
            if (!XUtil::isRequired(c)) {
                oneOptional = true
                if (m.fetchType != null && m.fetchType == "LAZY")
                    logger.error("fetch type lazy not possible with optional join fields: " + e.name + "." + c.name);
            }
        return !oneOptional
    }
    
    def public static optArgs(String ... args) {
        args.filterNull.join('(',', ', ')', [it])
    }
    
    /*
    def public static optArgs(String arg1, String arg2) {
        if (arg1 == null && arg2 == null)
            return ''''''
        if (arg1 != null && arg2 != null)
            return '''(«arg1», «arg2»)'''
        if (arg1 != null)
            return '''(«arg1»)'''
        else        
            return '''(«arg2»)'''
    }  */
    
    def private static writeJoinColumns(Relationship m, boolean readOnly, EntityDefinition childObject) {
        val childPkColumns = childObject.pk?.columnName ?: childObject.pkPojo?.fields ?: childObject.embeddablePk.name.pojoType.fields
        '''
            «IF m.referencedFields.columnName.size == 1»
                «m.makeJoin(0, readOnly, childPkColumns)»
            «ELSE»
                @JoinColumns({
                   «(0 .. m.referencedFields.columnName.size-1).map[m.makeJoin(it, readOnly, childPkColumns)].join(', ')»
                })
            «ENDIF»
        '''
    }
    
    def public static writeRelationships(EntityDefinition e, String fieldVisibility) '''
        «FOR m : e.manyToOnes»
            @ManyToOne«optArgs(
                if (m.fetchType != null) '''fetch=FetchType.«m.fetchType»''',
                if (m.nonOptional(e)) '''optional=false'''
            )»
            «m.writeJoinColumns(true, m.childObject)»
            «m.writeFGS(fieldVisibility, m.childObject.name, "", false)»
        «ENDFOR»
        
        «FOR m : e.oneToOnes»
            @OneToOne«optArgs(
                if (m.relationship.fetchType != null) '''fetch=FetchType.«m.relationship.fetchType»''',
                if (m.relationship.nonOptional(e)) 'optional=false',
                if (m.cascade) 'cascade=CascadeType.ALL' 
            )»
            «m.relationship.writeJoinColumns(!m.cascade, m.relationship.childObject)»
            «m.relationship.writeFGS(fieldVisibility, m.relationship.childObject.name, "", m.cascade)»
        «ENDFOR»
        
        «FOR m : e.oneToManys»
            @OneToMany«optArgs(
                'orphanRemoval=true',
                'cascade=CascadeType.ALL',
                if (m.relationship.fetchType != null) '''fetch=FetchType.«m.relationship.fetchType»'''
            )»
            «m.relationship.writeJoinColumns(false, e)»
            «IF m.collectionType == 'Map'»
                @MapKey(name="«m.mapKey»")
            «ENDIF»
            «m.relationship.writeFGS(fieldVisibility, m.o2mTypeName, ''' = new «m.getInitializer»()''', true)»
        «ENDFOR»
    '''
    
    def private static writeFGS(Relationship m, String fieldVisibility, CharSequence type, String initializer, boolean doSetter) '''
        «fieldVisibility»«type» «m.name»«initializer»;

        public «type» get«m.name.toFirstUpper»() {
            return «m.name»;
        }
        «IF doSetter»
            public void set«m.name.toFirstUpper»(«type» «m.name») {
                this.«m.name» = «m.name»;
            }
        «ENDIF»
    '''
    
    def private static o2mTypeName(OneToMany m)
        '''«m.collectionType»<«IF m.collectionType == 'Map'»«m.mapKey», «ENDIF»«m.relationship.childObject.name»>'''
        
    def private static getInitializer(OneToMany m) {
        switch (m.collectionType) {
            case 'List': '''Array«m.o2mTypeName»'''
            case 'Set':  '''LinkedHash«m.o2mTypeName»'''   // LinkedHashSet preferred over HashSet due to certain ordering guarantee
            case 'Map':  '''Hash«m.o2mTypeName»'''
        }
    }
}
