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
import de.jpaw.persistence.dsl.bDDL.Inheritance
import de.jpaw.persistence.dsl.bDDL.EntityDefinition
import de.jpaw.persistence.dsl.generator.YUtil
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
// using JCL here, because it is already a project dependency, should switch to slf4j
import org.apache.commons.logging.Log
import org.apache.commons.logging.LogFactory
import static extension de.jpaw.persistence.dsl.generator.YUtil.*
import static extension de.jpaw.persistence.dsl.generator.sql.SqlEnumOut.*
import static extension de.jpaw.persistence.dsl.generator.sql.SqlViewOut.*
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import de.jpaw.bonaparte.dsl.bonScript.EnumDefinition
import de.jpaw.bonaparte.dsl.generator.Delimiter
import java.util.Set
import java.util.HashSet

class SqlDDLGeneratorMain implements IGenerator {
    private static Log logger = LogFactory::getLog("de.jpaw.persistence.dsl.generator.sql.SqlDDLGeneratorMain") // jcl
    var int indexCount
    val Set<EnumDefinition> enumsRequired = new HashSet<EnumDefinition>(100)

    def makeSqlFilename(EObject e, DatabaseFlavour databaseFlavour, String basename, String object) {
        return "sql/" + databaseFlavour.toString + "/" + object + "/" + basename + ".sql";
    }

    override void doGenerate(Resource resource, IFileSystemAccess fsa) {
        enumsRequired.clear
        // SQL DDLs
        for (e : resource.allContents.toIterable.filter(typeof(EntityDefinition))) {
            logger.info("start code output of main table for " + e.name)
            // System::out.println("start code output of main table for " + e.name)
            makeTables(fsa, e, false)
            if (e.tableCategory != null && e.tableCategory.historyCategory != null) {
                // do histories as well
                logger.info("    doing history table as well, due to category " + e.tableCategory.name);
                // System::out.println("    doing history table as well, due to category " + e.tableCategory.name);
                makeTables(fsa, e, true)
            }
            collectEnums(e)
            makeViews(fsa, e, false, "_nt")
            makeViews(fsa, e, true, "_v")      // enums included, also create a view
        }
        // enum mapping functions
        for (e : enumsRequired) {
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::POSTGRES, e.name, "Function"), postgresEnumFuncs(e))
        }
    }

    def public static CharSequence recurseColumns(ClassDefinition cl, ClassDefinition stopAt, DatabaseFlavour databaseFlavour, Delimiter d) {
        recurse(cl, stopAt, false,
            [ true ],
            [ '''-- table columns of java class «it.name»
              '''],
            [ '''«d.get»«SqlColumns::doColumn(it, databaseFlavour)»
              ''']
        )
    }


    // recurse through all
    def private void recurseEnumCollection(ClassDefinition c) {
        var ClassDefinition citer = c
        while (citer != null) {
            for (i : citer.fields) {
                val ref = DataTypeExtension::get(i.datatype)
                if (ref.enumMaxTokenLength != DataTypeExtension::NO_ENUM)
                    enumsRequired.add(ref.elementaryDataType.enumType)
            }
            if (citer.extendsClass != null)
                citer = citer.extendsClass.classRef
            else
                citer = null
        }
    }

    def private void collectEnums(EntityDefinition e) {
        recurseEnumCollection(e.tableCategory.trackingColumns)
        recurseEnumCollection(e.pojoType)
        recurseEnumCollection(e.tenantClass)
    }

    def private void makeViews(IFileSystemAccess fsa, EntityDefinition e, boolean withTracking, String suffix) {
        var tablename = mkTablename(e, false) + suffix
        fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,   tablename, "View"), e.createView(DatabaseFlavour::ORACLE, withTracking, suffix))
        fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::POSTGRES, tablename, "View"), e.createView(DatabaseFlavour::POSTGRES, withTracking, suffix))
    }

    def private void makeTables(IFileSystemAccess fsa, EntityDefinition e, boolean doHistory) {
        var tablename = mkTablename(e, doHistory)
        // System::out.println("    tablename is " + tablename);
        fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,   tablename, "Table"), e.sqlDdlOut(DatabaseFlavour::ORACLE, doHistory))
        fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::POSTGRES, tablename, "Table"), e.sqlDdlOut(DatabaseFlavour::POSTGRES, doHistory))
        fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,   tablename, "Synonym"), e.sqlSynonymOut(DatabaseFlavour::ORACLE, doHistory))
    }

    def public doDiscriminator(EntityDefinition t, DatabaseFlavour databaseFlavour) {
        if (t.discriminatorTypeInt) {
            switch (databaseFlavour) {
            case DatabaseFlavour::ORACLE:    return '''«t.discname» NUMBER(9) DEFAULT 0 NOT NULL'''
            case DatabaseFlavour::POSTGRES:  return '''«t.discname» integer DEFAULT 0 NOT NULL'''
            }
        } else {
            switch (databaseFlavour) {
            case DatabaseFlavour::ORACLE:    return '''«t.discname» VARCHAR2(30) DEFAULT '«t.discriminatorValue»' NOT NULL'''
            case DatabaseFlavour::POSTGRES:  return '''«t.discname» VARCHAR(30) DEFAULT '«t.discriminatorValue»' NOT NULL'''
            }
        }
    }

    def indexCounter() {
        return indexCount = indexCount + 1
    }

    def sqlSynonymOut(EntityDefinition t, DatabaseFlavour databaseFlavour, boolean doHistory) {
        val String tablename = YUtil::mkTablename(t, doHistory)
        '''CREATE OR REPLACE PUBLIC SYNONYM «tablename» FOR «tablename»;'''
    }

    def sqlDdlOut(EntityDefinition t, DatabaseFlavour databaseFlavour, boolean doHistory) {
        val String tablename = YUtil::mkTablename(t, doHistory)
        val EntityDefinition baseEntity = t.getInheritanceRoot() // for derived tables, the original (root) table
        var myCategory = t.tableCategory
        if (doHistory)
            myCategory = myCategory.historyCategory
        var String tablespaceData = null
        var String tablespaceIndex = null
        val ClassDefinition stopAt = if (t.inheritanceRoot.xinheritance == Inheritance::JOIN) t.^extends?.pojoType else null // stop column recursion for JOINed tables
        if (SqlMapping::supportsTablespaces(databaseFlavour)) {
            tablespaceData  = mkTablespaceName(t, false, myCategory)
            tablespaceIndex = mkTablespaceName(t, true,  myCategory)
        }
        // System::out.println("      tablename is " + tablename);

        var grantGroup = myCategory.grantGroup
        val d = new Delimiter("  ", ", ")
        indexCount = 0
        return '''
        -- This source has been automatically created by the bonaparte DSL (persistence addon). Do not modify, changes will be lost.
        -- The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        -- The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git

        CREATE TABLE «tablename» (
            «IF stopAt == null»
                «t.tableCategory.trackingColumns?.recurseColumns(null, databaseFlavour, d)»
            «ENDIF»
            «baseEntity.tenantClass?.recurseColumns(null, databaseFlavour, d)»
            «IF t.discname != null»
                «d.get»«doDiscriminator(t, databaseFlavour)»
            «ENDIF»
            «IF baseEntity.pk != null && stopAt != null»
                «FOR c : baseEntity.pk.columnName»
                    «d.get»«SqlColumns::doColumn(c, databaseFlavour)»
                «ENDFOR»
            «ENDIF»
            «t.pojoType.recurseColumns(stopAt, databaseFlavour, d)»
        )«IF tablespaceData != null» TABLESPACE «tablespaceData»«ENDIF»;

        «IF baseEntity.pk != null»
            ALTER TABLE «tablename» ADD CONSTRAINT «tablename»_pk PRIMARY KEY (
                «FOR c : baseEntity.pk.columnName SEPARATOR ', '»«columnName(c)»«ENDFOR»
            )«IF tablespaceIndex != null» USING INDEX TABLESPACE «tablespaceIndex»«ENDIF»;
        «ENDIF»
        «IF !doHistory»
            «FOR i : t.index»
                CREATE «IF i.isUnique»UNIQUE «ENDIF»INDEX «tablename»_«IF i.isUnique»u«ELSE»i«ENDIF»«indexCounter» ON «tablename»(
                    «FOR c : i.columnName SEPARATOR ', '»«columnName(c)»«ENDFOR»
                )«IF tablespaceIndex != null» TABLESPACE «tablespaceIndex»«ENDIF»;
            «ENDFOR»
        «ENDIF»
        «IF grantGroup != null && grantGroup.grants != null»
            «FOR g : grantGroup.grants»
                «IF g.permissions != null && g.permissions.permissions != null»
                    GRANT «FOR p : g.permissions.permissions SEPARATOR ','»«p.toString»«ENDFOR» ON «tablename» TO «g.roleOrUserName»;
                «ENDIF»
            «ENDFOR»
        «ENDIF»

        «IF stopAt == null»
            «t.tableCategory.trackingColumns?.recurseComments(null, tablename)»
        «ENDIF»
        «baseEntity.tenantClass?.recurseComments(null, tablename)»
        «IF t.discname != null»
            COMMENT ON COLUMN «tablename».«t.discname» IS 'autogenerated JPA discriminator column';
        «ENDIF»
        «t.pojoType.recurseComments(stopAt, tablename)»
    '''
    }
}
