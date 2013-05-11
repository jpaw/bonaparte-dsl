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
  
package de.jpaw.persistence.dsl.generator.sql

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.Delimiter
import de.jpaw.persistence.dsl.bDDL.EntityDefinition
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.persistence.dsl.generator.YUtil.*

class SqlViewOut {
    
    def private static createColumn(FieldDefinition i, String prefix) {
        val ref = DataTypeExtension::get(i.datatype)
        val cn = columnName(i)
        if (ref.enumMaxTokenLength != DataTypeExtension::NO_ENUM)
            '''«ref.elementaryDataType.enumType.name»2s(«prefix».«cn») AS «cn»'''
        else
            '''«prefix».«cn» AS «cn»'''
    }
    
    def public static CharSequence createColumns(ClassDefinition cl, String prefix, Delimiter d) {
        recurse(cl, null, false,
            [ true ],
            [ '''-- columns of java class «it.name»
              '''],
            [ '''«d.get»«createColumn(it, prefix)»
              ''']
        )
    }    
    
    def private static CharSequence recurseInheritance(EntityDefinition e, DatabaseFlavour databaseFlavour, boolean includeTracking, int level, Delimiter d) '''
        «IF e.^extends != null»
            «recurseInheritance(e.^extends, databaseFlavour, includeTracking, level, d)»
            «createColumns(e.pojoType, "t" + level, d)»
        «ELSE»
            «IF includeTracking»
                «createColumns(e.tableCategory.trackingColumns, "t" + level, d)»
            «ENDIF»
            «createColumns(e.tenantClass, "t" + level, d)»
            «createColumns(e.pojoType, "t" + level, d)»
        «ENDIF»
    '''
    
    // TODO FIXME: not yet implemented is JOIN inheritance
    def public static createView(EntityDefinition e, DatabaseFlavour databaseFlavour, boolean includeTracking, String suffix) '''
        CREATE OR REPLACE VIEW «mkTablename(e, false)»«suffix» AS SELECT
            «recurseInheritance(e, databaseFlavour, includeTracking, 0, new Delimiter("", ", "))»
        FROM «mkTablename(e, false)» t0;
    '''
}