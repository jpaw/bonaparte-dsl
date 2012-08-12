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

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IGenerator
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.emf.ecore.EObject
import de.jpaw.persistence.dsl.bDDL.EntityDefinition
import de.jpaw.persistence.dsl.generator.YUtil
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition

class SqlDDLGeneratorMain implements IGenerator {
    String separator

    def setSeparator(String newval) {
        separator = newval
        return ""  // do not output anything
    }
        
    def makeSqlFilename(EObject e, DatabaseFlavour databaseFlavour, String basename) {
        return "sql/" + databaseFlavour.toString + "/Table/" + basename + ".sql";
    }

    override void doGenerate(Resource resource, IFileSystemAccess fsa) {
        // java
        for (e : resource.allContents.toIterable.filter(typeof(EntityDefinition))) {
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,   e.name), e.sqlDdlOut(DatabaseFlavour::ORACLE));
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::POSTGRES, e.name), e.sqlDdlOut(DatabaseFlavour::POSTGRES));
        }
    }

    def public recurseColumns(ClassDefinition cl, DatabaseFlavour databaseFlavour) '''
        «cl.extendsClass?.recurseColumns(databaseFlavour)»
        -- table columns of java class «cl.name»
        «FOR c : cl.fields»
            «separator»«SqlColumns::doColumn(c, databaseFlavour)»«setSeparator(", ")»
        «ENDFOR»
    '''
    
    def sqlDdlOut(EntityDefinition t, DatabaseFlavour databaseFlavour) {
        val String tablename = YUtil::mkTablename(t)
        var String tablespaceData = null
        var String tablespaceIndex = null
        if (SqlMapping::supportsTablespaces(databaseFlavour)) {
            tablespaceData  = YUtil::mkTablespaceName(t, false)
            tablespaceIndex = YUtil::mkTablespaceName(t, true)
        }
        return '''
        -- This source has been automatically created by the bonaparte DSL (persistence addon). Do not modify, changes will be lost.
        -- The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        -- The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git 
        
        CREATE TABLE «tablename» (
            «setSeparator("  ")»
            «t.tableCategory.trackingColumns?.recurseColumns(databaseFlavour)»
            «t.pojoType.recurseColumns(databaseFlavour)»
        )«IF tablespaceData != null» TABLESPACE «tablespaceData»«ENDIF»;
        
        «IF t.pk != null»
            ALTER TABLE «tablename» ADD CONSTRAINT «tablename»_pk PRIMARY KEY (
                «FOR c : t.pk.columnName SEPARATOR ', '»«YUtil::columnName(c)»«ENDFOR»
            )«IF tablespaceIndex != null» USING INDEX TABLESPACE «tablespaceIndex»«ENDIF»;
        «ENDIF»
    '''
    }  
}