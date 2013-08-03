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
import de.jpaw.persistence.dsl.bDDL.ElementCollectionRelationship
import java.util.List
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.persistence.dsl.bDDL.EmbeddableUse
import de.jpaw.persistence.dsl.generator.RequiredType
import java.util.zip.Deflater

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
            makeElementCollectionTables(fsa, e, false)
        }
        // enum mapping functions
        for (e : enumsRequired) {
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::POSTGRES, e.name, "Function"), postgresEnumFuncs(e))
        }
    }

    def public static CharSequence recurseColumns(ClassDefinition cl, ClassDefinition stopAt, DatabaseFlavour databaseFlavour, Delimiter d,
        List<FieldDefinition> pkCols, List<EmbeddableUse> embeddables) {
        recurse(cl, stopAt, false,
            [ true ],
              embeddables,
            [ '''-- table columns of java class «name»
              '''],
            [ fld, myName, reqType | 
            '''«SqlColumns::doDdlColumn(fld, databaseFlavour, if (pkCols != null && pkCols.contains(fld)) RequiredType::FORCE_NOT_NULL else reqType, d, myName)»
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

    def private void makeElementCollectionTables(IFileSystemAccess fsa, EntityDefinition e, boolean doHistory) {
        for (ec : e.elementCollections) {
            if (doHistory && ec.historytablename == null) {
                // no history here
            } else {
                val tablename = if (doHistory) ec.historytablename else ec.tablename
                for (dbf: DatabaseFlavour.values)
                    fsa.generateFile(makeSqlFilename(e, dbf, tablename, "Table"), e.sqlEcOut(ec, tablename, dbf, doHistory))
                fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,      tablename, "Synonym"), tablename.sqlSynonymOut)
            }
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
        for (dbf: DatabaseFlavour.values)
            fsa.generateFile(makeSqlFilename(e, dbf,   tablename, "Table"), e.sqlDdlOut(dbf, doHistory))
        fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,   tablename, "Synonym"), tablename.sqlSynonymOut)
    }

    def public doDiscriminator(EntityDefinition t, DatabaseFlavour databaseFlavour) {
        if (t.discriminatorTypeInt) {
            switch (databaseFlavour) {
            case DatabaseFlavour::ORACLE:       return '''«t.discname» number(9) DEFAULT 0 NOT NULL'''
            case DatabaseFlavour::POSTGRES:     return '''«t.discname» integer DEFAULT 0 NOT NULL'''
            case DatabaseFlavour::MSSQLSERVER:  return '''«t.discname» int DEFAULT 0 NOT NULL'''
            }
        } else {
            switch (databaseFlavour) {
            case DatabaseFlavour::ORACLE:       return '''«t.discname» varchar2(30) DEFAULT '«t.discriminatorValue»' NOT NULL'''
            case DatabaseFlavour::POSTGRES:     return '''«t.discname» varchar(30) DEFAULT '«t.discriminatorValue»' NOT NULL'''
            case DatabaseFlavour::MSSQLSERVER:  return '''«t.discname» nvarchar(30) DEFAULT '«t.discriminatorValue»' NOT NULL'''
            }
        }
    }

    def indexCounter() {
        return indexCount = indexCount + 1
    }

    def static sqlSynonymOut(String tablename)
        '''CREATE OR REPLACE PUBLIC SYNONYM «tablename» FOR «tablename»;'''

    def sqlEcOut(EntityDefinition t, ElementCollectionRelationship ec, String tablename, DatabaseFlavour databaseFlavour, boolean doHistory) {
        val EntityDefinition baseEntity = t.getInheritanceRoot() // for derived tables, the original (root) table
        var myCategory = t.tableCategory
        if (doHistory)
            myCategory = myCategory.historyCategory
        var String tablespaceData = null
        var String tablespaceIndex = null
        if (SqlMapping::supportsTablespaces(databaseFlavour)) {
            tablespaceData  = mkTablespaceName(t, false, myCategory)
            tablespaceIndex = mkTablespaceName(t, true,  myCategory)
        }
        val d = new Delimiter("  ", ", ")
        return '''
        -- This source has been automatically created by the bonaparte DSL (persistence addon). Do not modify, changes will be lost.
        -- The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        -- The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git

        CREATE TABLE «tablename» (
            -- tenant
            «baseEntity.tenantClass?.recurseColumns(null, databaseFlavour, d, baseEntity.pk?.columnName, t.embeddables)»
            -- base table PK
            «IF baseEntity.pk != null»
                «FOR c : baseEntity.pk.columnName»
                    «SqlColumns::writeFieldSQLdoColumn(c, databaseFlavour, RequiredType::FORCE_NOT_NULL, d, t.embeddables)»
                «ENDFOR»
            «ENDIF»
            «IF ec.mapKey != null»
                -- element collection key
                , «ec.mapKey.java2sql» «SqlMapping::sqlType(ec, databaseFlavour)» NOT NULL,
            «ENDIF»
            -- contents field
            «SqlColumns::writeFieldSQLdoColumn(ec.name, databaseFlavour, RequiredType::DEFAULT, d, t.embeddables)»
        )«IF tablespaceData != null» TABLESPACE «tablespaceData»«ENDIF»;

        «IF baseEntity.pk != null»
            ALTER TABLE «tablename» ADD CONSTRAINT «tablename»_pk PRIMARY KEY (
                «FOR c : baseEntity.pk.columnName SEPARATOR ', '»«c.name.java2sql»«ENDFOR»«IF ec.mapKey != null», «ec.mapKey.java2sql»«ENDIF»
            )«IF tablespaceIndex != null» USING INDEX TABLESPACE «tablespaceIndex»«ENDIF»;
        «ENDIF»
        '''
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
                «t.tableCategory.trackingColumns?.recurseColumns(null, databaseFlavour, d, baseEntity.pk?.columnName, t.embeddables)»
            «ENDIF»
            «baseEntity.tenantClass?.recurseColumns(null, databaseFlavour, d, baseEntity.pk?.columnName, t.embeddables)»
            «IF t.discname != null»
                «d.get»«doDiscriminator(t, databaseFlavour)»
            «ENDIF»
            «IF baseEntity.pk != null && stopAt != null»
                «FOR c : baseEntity.pk.columnName»
                    «SqlColumns::writeFieldSQLdoColumn(c, databaseFlavour, RequiredType::FORCE_NOT_NULL, d, t.embeddables)»
                «ENDFOR»
            «ENDIF»
            «t.pojoType.recurseColumns(stopAt, databaseFlavour, d, baseEntity.pk?.columnName, t.embeddables)»
        )«IF tablespaceData != null» TABLESPACE «tablespaceData»«ENDIF»;

        «IF baseEntity.pk != null»
            ALTER TABLE «tablename» ADD CONSTRAINT «tablename»_pk PRIMARY KEY (
                «FOR c : baseEntity.pk.columnName SEPARATOR ', '»«c.name.java2sql»«ENDFOR»
            )«IF tablespaceIndex != null» USING INDEX TABLESPACE «tablespaceIndex»«ENDIF»;
        «ENDIF»
        «IF !doHistory»
            «FOR i : t.index»
                CREATE «IF i.isUnique»UNIQUE «ENDIF»INDEX «tablename»_«IF i.isUnique»u«ELSE»i«ENDIF»«indexCounter» ON «tablename»(
                    «FOR c : i.columnName SEPARATOR ', '»«c.name.java2sql»«ENDFOR»
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

        «IF databaseFlavour != DatabaseFlavour.MSSQLSERVER»
            «IF stopAt == null»
                «t.tableCategory.trackingColumns?.recurseComments(null, tablename, t.embeddables)»
            «ENDIF»
            «baseEntity.tenantClass?.recurseComments(null, tablename, t.embeddables)»
            «IF t.discname != null»
                COMMENT ON COLUMN «tablename».«t.discname» IS 'autogenerated JPA discriminator column';
            «ENDIF»
            «t.pojoType.recurseComments(stopAt, tablename, t.embeddables)»
        «ENDIF»
    '''
    }
}
