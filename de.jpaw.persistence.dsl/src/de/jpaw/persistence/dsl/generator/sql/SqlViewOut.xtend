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

import static extension de.jpaw.persistence.dsl.generator.YUtil.*
import de.jpaw.persistence.dsl.bDDL.EntityDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition

class SqlViewOut {
    static var String separator

    def private static setSeparator(String newval) {
        separator = newval
        return ""  // do not output anything
    }
    
    def private static createColumn(FieldDefinition i, String prefix) {
        val ref = DataTypeExtension::get(i.datatype)
        val cn = columnName(i)
        if (ref.enumMaxTokenLength != DataTypeExtension::NO_ENUM)
            '''«ref.elementaryDataType.enumType.name»2s(«prefix».«cn») as «cn»'''
        else
            '''«prefix».«cn» AS «cn»'''
    }
    
    def private static createColumns(ClassDefinition c, String prefix) '''
        «IF c != null»
            «IF c.extendsClass != null»
                «createColumns(c.extendsClass.classRef, prefix)»
            «ENDIF»
            -- columns of java class «c.name»
            «FOR i : c.fields»
                «IF i.isArray == null && i.isList == null»
                    «separator»«createColumn(i, prefix)»«setSeparator(", ")»
                «ENDIF»
            «ENDFOR»
        «ENDIF»
    '''
    
    def private static recurseInheritance(EntityDefinition e, DatabaseFlavour databaseFlavour, boolean includeTracking, int level) '''
        «IF e.^extends != null»
            «recurseInheritance(e.^extends, databaseFlavour, includeTracking, level)»
            «createColumns(e.pojoType, "t" + level)»
        «ELSE»
            «IF includeTracking»
                «createColumns(e.tableCategory.trackingColumns, "t" + level)»
            «ENDIF»
            «createColumns(e.tenantClass, "t" + level)»
            «createColumns(e.pojoType, "t" + level)»
        «ENDIF»
    '''
    
    // TODO FIXME: not yet implemented is JOIN inheritance
    def public static createView(EntityDefinition e, DatabaseFlavour databaseFlavour, boolean includeTracking, String suffix) '''
        CREATE OR REPLACE VIEW «mkTablename(e, false)»«suffix» AS SELECT«setSeparator("")»
            «recurseInheritance(e, databaseFlavour, includeTracking, 0)»
        FROM «mkTablename(e, false)» t0;
    '''
}