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

package de.jpaw.bonaparte.jpa.dsl.generator.sql

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.Delimiter
import de.jpaw.bonaparte.jpa.dsl.bDDL.EntityDefinition
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.jpa.dsl.generator.YUtil.*
import de.jpaw.bonaparte.jpa.dsl.bDDL.Inheritance
import de.jpaw.bonaparte.dsl.generator.DataCategory

class SqlViewOut {

    def private static createColumn(FieldDefinition i, String prefix, String myName, DatabaseFlavour databaseFlavour) {
        val ref = DataTypeExtension::get(i.datatype)
        val cn = myName.java2sql
        if (ref.category == DataCategory.ENUM || ref.category == DataCategory.ENUMALPHA)
            '''«ref.elementaryDataType.enumType.name.javaEnum2sql(databaseFlavour, 2)»2s(«prefix».«cn») AS «cn»'''
        else
            '''«prefix».«cn» AS «cn»'''
    }

    def private static CharSequence createColumns(ClassDefinition cl, String prefix, Delimiter d, EntityDefinition e, DatabaseFlavour databaseFlavour) {
        recurse(cl, null, false,
            [ !properties.hasProperty(PROP_NODDL) ],
            e.embeddables,
            [ '''-- columns of java class «name»
              '''],
            [ fld, myName, req | '''«d.get»«fld.createColumn(prefix, myName, databaseFlavour)»
              ''']
        )
    }

    // TODO: lower part to be fixed to allow embeddables in joined parts
    def private static CharSequence recurseInheritance(EntityDefinition e, DatabaseFlavour databaseFlavour, boolean includeTracking, int level, Delimiter d) '''
        «IF e.extends === null || !e.usesJoinInheritance»
            «IF includeTracking»
                «createColumns(e.tableCategory.trackingColumns, "t" + level, d, e, databaseFlavour)»
            «ENDIF»
            «createColumns(e.tenantClass, "t" + level, d, e, databaseFlavour)»
            «createColumns(e.pojoType, "t" + level, d, e, databaseFlavour)»
        «ELSE»
            «recurseInheritance(e.^extends, databaseFlavour, includeTracking, level+1, d)»
            -- columns of joined java class «e.pojoType.name»
            «FOR i: e.pojoType.fields»
                «d.get»«i.createColumn("t"+level, i.name, databaseFlavour)»
            «ENDFOR»
        «ENDIF»
    '''

    def private static boolean usesJoinInheritance(EntityDefinition e) {
        if (e.xinheritance !== null && e.xinheritance == Inheritance::JOIN)
            return true
        return (e.extends !== null) && e.extends.usesJoinInheritance
    }

    def private static CharSequence joinedTables(EntityDefinition e, int level) {
        if (e.extends === null || !e.usesJoinInheritance)
            return ''''''
        return ''', «mkTablename(e.extends, false)» t«level+1»«joinedTables(e.extends, level+1)»'''
    }

    def private static CharSequence joinConditions(EntityDefinition e, int level) {
        if (e.extends === null || !e.usesJoinInheritance)
            return ''''''
        return '''«IF level == 0» WHERE «ELSE» AND «ENDIF»t0.objectRef = t«level+1».objectRef«joinConditions(e.extends, level+1)»'''
    }

    def public static createView(EntityDefinition e, DatabaseFlavour databaseFlavour, boolean includeTracking, String suffix) '''
        CREATE OR REPLACE VIEW «mkTablename(e, false)»«suffix» AS SELECT
            «recurseInheritance(e, databaseFlavour, includeTracking, 0, new Delimiter("", ", "))»
        FROM «mkTablename(e, false)» t0«e.joinedTables(0)»«e.joinConditions(0)»;
    '''
}
