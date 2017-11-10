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

import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.jpa.dsl.bDDL.BDDLPackageDefinition
import de.jpaw.bonaparte.jpa.dsl.bDDL.ColumnNameMappingDefinition
import de.jpaw.bonaparte.jpa.dsl.bDDL.EntityDefinition
import de.jpaw.bonaparte.jpa.dsl.bDDL.OneToMany
import de.jpaw.bonaparte.jpa.dsl.bDDL.Relationship
import java.util.List

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.jpa.dsl.generator.YUtil.*

class MakeRelationships {

    // nmd2 is own entity, nmd1 is for child entity
    def static private makeJoin(Relationship m, int i, boolean readonly, List<FieldDefinition> childPkColumns, String joinColumnDirective, ColumnNameMappingDefinition nmd1, ColumnNameMappingDefinition nmd2) '''
        @JoinColumn(name="«m.referencedFields.columnName.get(i).name.java2sql(nmd1)»", referencedColumnName="«childPkColumns.get(i).name.java2sql(nmd2)»"«IF readonly», insertable=false, updatable=false«ENDIF»«IF joinColumnDirective !== null», «joinColumnDirective»«ENDIF»)
    '''

    // new method, taking attributes from referenced column
    def static private makeJoin(Relationship m, int i, List<FieldDefinition> childPkColumns, ColumnNameMappingDefinition nmd1, ColumnNameMappingDefinition nmd2) {
        val refcol = childPkColumns.get(i)
        '''
            @JoinColumn(name="«m.referencedFields.columnName.get(i).name.java2sql(nmd1)»", referencedColumnName="«refcol.name.java2sql(nmd2)»"«refcol.fieldAnnotations»)
        '''
    }

    def private static boolean nonOptional(Relationship m, EntityDefinition e) {
        var oneOptional = false
        for (c : m.referencedFields.columnName)
            if (!c.isRequired) {
                oneOptional = true
            }
        return !oneOptional
    }

    def public static optArgs(String ... args) {
        args.filterNull.join('(',', ', ')', [it])
    }

    def private static writeJoinColumns(Relationship m, boolean readOnly, EntityDefinition childObject, String joinColumnDirective, ColumnNameMappingDefinition myNmd) {
        val childPkColumns = childObject.primaryKeyColumns0
        val otherNmd = childObject.nameMapping
        '''
            «IF m.referencedFields.columnName.size == 1»
                «m.makeJoin(0, readOnly, childPkColumns, joinColumnDirective, otherNmd, myNmd)»
            «ELSE»
                @JoinColumns({
                   «(0 .. m.referencedFields.columnName.size-1).map[m.makeJoin(it, readOnly, childPkColumns, joinColumnDirective, otherNmd, myNmd)].join(', ')»
                })
            «ENDIF»
        '''
    }

    // new method, taking attributes from referenced column
    def private static writeJoinColumns(Relationship m, EntityDefinition childObject, ColumnNameMappingDefinition myNmd) {
        val childPkColumns = childObject.primaryKeyColumns0
        val otherNmd = childObject.nameMapping
        '''
            «IF m.referencedFields.columnName.size == 1»
                «m.makeJoin(0, childPkColumns, otherNmd, myNmd)»
            «ELSE»
                @JoinColumns({
                   «(0 .. m.referencedFields.columnName.size-1).map[m.makeJoin(it, childPkColumns, otherNmd, myNmd)].join(', ')»
                })
            «ENDIF»
        '''
    }

    // make the join column not updateable if a "properties ref" has been specified, i.e. a separate Long field will be generated in the entity.
    // in this case, it is assumed that the Long field is used for updates.
    def private static isReadOnly(Relationship m) {
        val f = m.referencedFields.columnName.get(0)
        val ref = DataTypeExtension::get(f.datatype)
        return ref.elementaryDataType !== null || f.properties.hasProperty(PROP_REF)  // either we decleared to want that "Long" field, or it is defined as a long anyway
    }

    def public static writeRelationships(EntityDefinition e, String fieldVisibility) {
        val forceSetters = e.forceSetters || (e.eContainer as BDDLPackageDefinition).forceSetters
        val myNmd = e.nameMapping
        return '''
        «FOR m : e.manyToOnes»
            @ManyToOne«optArgs(
                if (m.relationship.fetchType !== null) '''fetch=FetchType.«m.relationship.fetchType»''',
                if (m.relationship.nonOptional(e)) '''optional=false'''
            )»
            «m.relationship.writeJoinColumns(m.relationship.isReadOnly, m.relationship.childObject, null, myNmd)»
            «m.relationship.writeFGS(fieldVisibility, m.relationship.childObject.name, "", forceSetters || m.forceSetters || !m.relationship.isReadOnly, true)»
        «ENDFOR»

        «FOR m : e.oneToOnes»
            @OneToOne«optArgs(
                if (m.relationship.fetchType !== null) '''fetch=FetchType.«m.relationship.fetchType»''',
                if (m.relationship.nonOptional(e)) 'optional=false',
                if (m.orphanRemoval) 'orphanRemoval=true',
                if (m.cascade)       'cascade=CascadeType.ALL'
            )»
            «m.relationship.writeJoinColumns(!m.cascade, m.relationship.childObject, m.joinColumnDirective, myNmd)»
            «m.relationship.writeFGS(fieldVisibility, m.relationship.childObject.name, "", true, true)»
        «ENDFOR»

        «FOR m : e.oneToManys»
            @OneToMany«optArgs(
                if (m.relationship.fetchType !== null) '''fetch=FetchType.«m.relationship.fetchType»''',
                if (m.orphanRemoval) 'orphanRemoval=true',
                if (m.cascade)       'cascade=CascadeType.ALL'
            )»
            «m.relationship.writeJoinColumns(false, e, m.joinColumnDirective, myNmd)»
            «IF m.collectionType == 'Map'»
                @MapKey(name="«m.mapKey»")
            «ENDIF»
            «m.relationship.writeFGS(fieldVisibility, m.o2mTypeName, ''' = new «m.getInitializer»()''', forceSetters || m.forceSetters, false)»
        «ENDFOR»
    '''
    }

    def private static writeFGS(Relationship m, String fieldVisibility, CharSequence type, String initializer, boolean doSetter, boolean doThis) '''
        «fieldVisibility»«type» «m.name»«initializer»;

        public «type» get«m.name.toFirstUpper»() {
            «IF doThis && m.fetchType !== null && m.fetchType == "LAZY"»
                return «m.name» == null ? null : «m.name».ret$Self();  // we want the resolved instance, not a proxy!
            «ELSE»
                return «m.name»;
            «ENDIF»
        }
        «IF doSetter»
            public void set«m.name.toFirstUpper»(«type» «m.name») {
                this.«m.name» = «m.name»;
            }
        «ENDIF»
    '''

    def private static o2mTypeName(OneToMany m)
        '''«m.collectionType»<«IF m.collectionType == 'Map'»«m.indexType», «ENDIF»«m.relationship.childObject.name»>'''

    def private static getInitializer(OneToMany m) {
        switch (m.collectionType) {
            case 'List': '''Array«m.o2mTypeName»'''
            case 'Set':  '''LinkedHash«m.o2mTypeName»'''   // LinkedHashSet preferred over HashSet due to certain ordering guarantee
            case 'Map':  '''Hash«m.o2mTypeName»'''
        }
    }
}
