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

package de.jpaw.persistence.dsl.generator.cql

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.Delimiter
import de.jpaw.persistence.dsl.bDDL.NoSQLEntityDefinition
import java.util.List
import org.apache.log4j.Logger
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator

import static extension de.jpaw.persistence.dsl.generator.YUtil.*
import static extension de.jpaw.persistence.dsl.generator.cql.CUtil.*

class CqlDDLGeneratorMain implements IGenerator {
    private static Logger logger = Logger.getLogger(CqlDDLGeneratorMain)
    var int indexCount

    def makeSqlFilename(EObject e, String basename, String object) {
        return "cql/" + object + "/" + basename + ".cql";
    }

    override void doGenerate(Resource resource, IFileSystemAccess fsa) {
        // CQL DDLs
        for (e : resource.allContents.toIterable.filter(typeof(NoSQLEntityDefinition))) {
            logger.info("start code output of main table for " + e.name)
            // System::out.println("start code output of main table for " + e.name)
            makeTables(fsa, e, false)
            if (e.tableCategory != null && e.tableCategory.historyCategory != null) {
                // do histories as well
                logger.info("    doing history table as well, due to category " + e.tableCategory.name);
                // System::out.println("    doing history table as well, due to category " + e.tableCategory.name);
                makeTables(fsa, e, true)
            }
        }
    }

    def public static CharSequence recurseColumns(ClassDefinition cl, Delimiter d) {
        recurse(cl, null, false,
            [ true ],
              null,
            [ '''-- table columns of java class «name»
              '''],
            [ fld, myName, reqType | 
            '''«CqlColumns::doDdlColumn(fld, d, myName)»
              ''']
        )
    }

    def private void makeTables(IFileSystemAccess fsa, NoSQLEntityDefinition e, boolean doHistory) {
        var tablename = mkTablename(e, doHistory)
        // System::out.println("    tablename is " + tablename);
        fsa.generateFile(makeSqlFilename(e, tablename, "Table"), e.cqlDdlOut(doHistory))
    }

    def public doDiscriminator(NoSQLEntityDefinition t) {
        if (t.discriminatorTypeInt) {
            '''«t.discname» int'''
        } else {
            '''«t.discname» text'''
        }
    }

    def indexCounter() {
        return indexCount = indexCount + 1
    }
    
    def cqlDdlOut(NoSQLEntityDefinition t, boolean doHistory) {
        val String tablename = t.mkTablename(doHistory)
        val NoSQLEntityDefinition baseEntity = t.inheritanceRoot// for derived tables, the original (root) table
        var myCategory = t.tableCategory
        if (doHistory)
            myCategory = myCategory.historyCategory
        // System::out.println("      tablename is " + tablename);

        val d = new Delimiter("  ", ", ")
        indexCount = 0
        
        return '''
        -- This source has been automatically created by the bonaparte DSL (persistence addon). Do not modify, changes will be lost.
        -- The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        -- The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git

        CREATE TABLE «tablename» (
            «t.tableCategory.trackingColumns?.recurseColumns(d)»
            «baseEntity.tenantClass?.recurseColumns(d)»
            «t.pojoType.recurseColumns(d)»
            «IF t.discname != null»
                «d.get»«doDiscriminator(t)»
            «ENDIF»
            , PRIMARY KEY (
            «IF baseEntity.partitionKey != null»
                («baseEntity.partitionKey.columnName.map[name.java2sql].join(', ')»), «baseEntity.pkPojo.fields.filter[!baseEntity.partitionKey.columnName.map[name].contains(name)].map[name.java2sql].join(', ')»
            «ELSE»
                «baseEntity.pkPojo.fields.map[name.java2sql].join(', ')»
            «ENDIF»
            )
        );

        «IF !doHistory»
            «FOR i : t.index»
                CREATE INDEX «tablename»_i«indexCounter» ON «tablename» («i.columnName.name.java2sql»);
            «ENDFOR»
        «ENDIF»
    '''
    }
}
