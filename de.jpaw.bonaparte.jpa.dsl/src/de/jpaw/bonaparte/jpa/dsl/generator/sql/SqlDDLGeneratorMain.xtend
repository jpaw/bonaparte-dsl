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
import de.jpaw.bonaparte.dsl.bonScript.EnumDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.Delimiter
import de.jpaw.bonaparte.jpa.dsl.BDDLPreferences
import de.jpaw.bonaparte.jpa.dsl.bDDL.ElementCollectionRelationship
import de.jpaw.bonaparte.jpa.dsl.bDDL.EmbeddableUse
import de.jpaw.bonaparte.jpa.dsl.bDDL.EntityDefinition
import de.jpaw.bonaparte.jpa.dsl.bDDL.Inheritance
import de.jpaw.bonaparte.jpa.dsl.generator.RequiredType
import de.jpaw.bonaparte.jpa.dsl.generator.YUtil
import java.util.HashSet
import java.util.List
import java.util.Set
import org.apache.log4j.Logger
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator

import static de.jpaw.bonaparte.jpa.dsl.generator.sql.SqlEnumOut.*
import static de.jpaw.bonaparte.jpa.dsl.generator.sql.SqlEnumOutOracle.*

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.jpa.dsl.generator.YUtil.*
import static extension de.jpaw.bonaparte.jpa.dsl.generator.sql.SqlViewOut.*
import de.jpaw.bonaparte.dsl.generator.DataCategory

class SqlDDLGeneratorMain implements IGenerator {
    private static Logger LOGGER = Logger.getLogger(SqlDDLGeneratorMain)
    var int indexCount
    val Set<EnumDefinition> enumsRequired = new HashSet<EnumDefinition>(100)

    var private BDDLPreferences prefs

    def makeSqlFilename(EObject e, DatabaseFlavour databaseFlavour, String basename, String object) {
        return "sql/" + databaseFlavour.toString + "/" + object + "/" + basename + ".sql";
    }

    override void doGenerate(Resource resource, IFileSystemAccess fsa) {
        prefs = BDDLPreferences.currentPrefs
        System.out.println('''Settings are: max ID length = («prefs.maxTablenameLength», «prefs.maxFieldnameLength»), Debug=«prefs.doDebugOut», Postgres=«prefs.doPostgresOut», Oracle=«prefs.doOracleOut», MSSQL=«prefs.doMsSQLServerOut», MySQL=«prefs.doMySQLOut»''')
        enumsRequired.clear
        // SQL DDLs
        for (e : resource.allContents.toIterable.filter(typeof(EntityDefinition))) {
            LOGGER.info("start code output of main table for " + e.name)
            // System::out.println("start code output of main table for " + e.name)
            makeTables(fsa, e, false)
            if (e.tableCategory !== null && e.tableCategory.historyCategory !== null) {
                // do histories as well
                LOGGER.info("    doing history table as well, due to category " + e.tableCategory.name);
                // System::out.println("    doing history table as well, due to category " + e.tableCategory.name);
                makeTables(fsa, e, true)
                makeTriggers(fsa, e)
            }
            collectEnums(e)
            makeViews(fsa, e, false, "_nt")
            makeViews(fsa, e, true, "_v")      // enums included, also create a view
            makeElementCollectionTables(fsa, e, false)
        }
        // enum mapping functions
        for (e : enumsRequired) {
            if (prefs.doPostgresOut)
                fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::POSTGRES, e.name, "Function"), postgresEnumFuncs(e))
            if (prefs.doOracleOut)
                fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,   e.name, "Function"), oracleEnumFuncs(e))
            // TODO: HANA + MS SQL
        }
    }

    def private static CharSequence recurseColumns(ClassDefinition cl, ClassDefinition stopAt, DatabaseFlavour databaseFlavour, Delimiter d,
        List<FieldDefinition> pkCols, List<EmbeddableUse> embeddables) {
        val pkColumnNames = pkCols?.map[name]  // cannot compare fields, because they might sit in parallel objects
        recurse(cl, stopAt, false,
            [ !properties.hasProperty(PROP_NODDL) ],
              embeddables,
            [ '''-- table columns of java class «name»
              '''],
            [ fld, myName, reqType |
            '''«SqlColumns::doDdlColumn(fld, databaseFlavour, if (pkCols !== null && pkColumnNames.contains(fld.name)) RequiredType::FORCE_NOT_NULL else reqType, d, myName)»
              ''']
        )
    }


    // recurse through all
    def private void recurseEnumCollection(ClassDefinition c) {
        var ClassDefinition citer = c
        while (citer !== null) {
            for (i : citer.fields) {
                val ref = DataTypeExtension::get(i.datatype)
                if (ref.category == DataCategory.ENUM || ref.category == DataCategory.ENUMALPHA || ref.category == DataCategory.XENUM)
                    enumsRequired.add(ref.enumForEnumOrXenum)
            }
            if (citer.extendsClass !== null)
                citer = citer.extendsClass.classRef
            else
                citer = null
        }
    }

    def private void makeElementCollectionTables(IFileSystemAccess fsa, EntityDefinition e, boolean doHistory) {
        for (ec : e.elementCollections) {
            if (doHistory && ec.historytablename === null) {
                // no history here
            } else {
                val tablename = if (doHistory) ec.historytablename else ec.tablename
                if (prefs.doPostgresOut)
                    fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::POSTGRES,    tablename, "Table"), e.sqlEcOut(ec, tablename, DatabaseFlavour::POSTGRES, doHistory))
                if (prefs.doMsSQLServerOut)
                    fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::MSSQLSERVER, tablename, "Table"), e.sqlEcOut(ec, tablename, DatabaseFlavour::MSSQLSERVER, doHistory))
                if (prefs.doMySQLOut)
                    fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::MYSQL,       tablename, "Table"), e.sqlEcOut(ec, tablename, DatabaseFlavour::MYSQL, doHistory))
                if (prefs.doOracleOut) {
                    fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,      tablename, "Table"), e.sqlEcOut(ec, tablename, DatabaseFlavour::ORACLE, doHistory))
                    fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,      tablename, "Synonym"), tablename.sqlSynonymOut)
                }
                if (prefs.doSapHanaOut)
                    fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::SAPHANA,     tablename, "Table"), e.sqlEcOut(ec, tablename, DatabaseFlavour::SAPHANA, doHistory))
            }
        }
    }


    def private void collectEnums(EntityDefinition e) {
        recurseEnumCollection(e.tableCategory.trackingColumns)
        recurseEnumCollection(e.pojoType)
        recurseEnumCollection(e.tenantClass)
    }

    def private void makeViews(IFileSystemAccess fsa, EntityDefinition e, boolean withTracking, String suffix) {
        val tablename = mkTablename(e, false) + suffix
        if (prefs.doOracleOut)
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,   tablename, "View"), e.createView(DatabaseFlavour::ORACLE, withTracking, suffix))
        if (prefs.doPostgresOut)
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::POSTGRES, tablename, "View"), e.createView(DatabaseFlavour::POSTGRES, withTracking, suffix))
    }

    def private void makeTriggers(IFileSystemAccess fsa, EntityDefinition e) {
        val tablename = mkTablename(e, false)
        if (prefs.doOracleOut)
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,   tablename + "_tr", "Trigger"), SqlTriggerOut.triggerOutOracle(e))
    }

    def private void makeTables(IFileSystemAccess fsa, EntityDefinition e, boolean doHistory) {
        var tablename = mkTablename(e, doHistory)
        // System::out.println("    tablename is " + tablename);
        if (prefs.doPostgresOut)
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::POSTGRES,    tablename, "Table"), e.sqlDdlOut(DatabaseFlavour::POSTGRES, doHistory))
        if (prefs.doMsSQLServerOut)
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::MSSQLSERVER, tablename, "Table"), e.sqlDdlOut(DatabaseFlavour::MSSQLSERVER, doHistory))
        if (prefs.doMySQLOut)
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::MYSQL,       tablename, "Table"), e.sqlDdlOut(DatabaseFlavour::MYSQL, doHistory))
        if (prefs.doOracleOut) {
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,      tablename, "Table"), e.sqlDdlOut(DatabaseFlavour::ORACLE, doHistory))
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,      tablename, "Synonym"), tablename.sqlSynonymOut)
        }
        if (prefs.doSapHanaOut)
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::SAPHANA,     tablename, "Table"), e.sqlDdlOut(DatabaseFlavour::SAPHANA, doHistory))
    }

    def private static CharSequence writeFieldSQLdoColumn(FieldDefinition f, DatabaseFlavour databaseFlavour, RequiredType reqType, Delimiter d, List<EmbeddableUse> embeddables) {
        writeFieldWithEmbeddedAndList(f, embeddables, null, null, reqType, false, "", [ fld, myName, reqType2 | SqlColumns.doDdlColumn(fld, databaseFlavour, reqType2, d, myName) ])
    }

    def public doDiscriminator(EntityDefinition t, DatabaseFlavour databaseFlavour) {
        if (t.discriminatorTypeInt) {
            switch (databaseFlavour) {
            case DatabaseFlavour::POSTGRES:     return '''«t.discname» integer DEFAULT 0 NOT NULL'''
            case DatabaseFlavour::ORACLE:       return '''«t.discname» number(9) DEFAULT 0 NOT NULL'''
            case DatabaseFlavour::MSSQLSERVER:  return '''«t.discname» int DEFAULT 0 NOT NULL'''
            case DatabaseFlavour::MYSQL:        return '''«t.discname» integer DEFAULT 0 NOT NULL'''
            case DatabaseFlavour::SAPHANA:      return '''«t.discname» integer DEFAULT 0 NOT NULL'''
            }
        } else {
            switch (databaseFlavour) {
            case DatabaseFlavour::POSTGRES:     return '''«t.discname» varchar(30) DEFAULT '«t.discriminatorValue»' NOT NULL'''
            case DatabaseFlavour::ORACLE:       return '''«t.discname» varchar2(30) DEFAULT '«t.discriminatorValue»' NOT NULL'''
            case DatabaseFlavour::SAPHANA:      return '''«t.discname» nvarchar(30) DEFAULT '«t.discriminatorValue»' NOT NULL'''
            case DatabaseFlavour::MSSQLSERVER:  return '''«t.discname» nvarchar(30) DEFAULT '«t.discriminatorValue»' NOT NULL'''
            case DatabaseFlavour::MYSQL:        return '''«t.discname» varchar(30) DEFAULT '«t.discriminatorValue»' NOT NULL'''
            }
        }
    }

    def indexCounter() {
        return indexCount = indexCount + 1
    }

    def static sqlSynonymOut(String tablename) '''
        CREATE OR REPLACE PUBLIC SYNONYM «tablename» FOR «tablename»;
    '''

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
        val optionalHistoryKeyPart = if (doHistory) ''', «myCategory.historySequenceColumn»'''
        val startOfPk =
            if (ec.keyColumns !== null)
                ec.keyColumns.join(', ')
            else if (baseEntity.embeddablePk !== null)
                baseEntity.embeddablePk.name.pojoType.fields.map[name.java2sql].join(',')
            else if(baseEntity.pk !== null)
                baseEntity.pk.columnName.map[name.java2sql].join(',')
            else
                '???'

        return '''
        -- This source has been automatically created by the bonaparte DSL (bonaparte.jpa addon). Do not modify, changes will be lost.
        -- The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        -- The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git

        CREATE TABLE «tablename» (
            -- base table PK
            «IF baseEntity.pk !== null»
                «FOR c : baseEntity.pk.columnName»
                    «c.writeFieldSQLdoColumn(databaseFlavour, RequiredType::FORCE_NOT_NULL, d, t.embeddables)»
                «ENDFOR»
            «ENDIF»
            «IF ec.mapKey !== null»
                -- element collection key
                , «ec.mapKey.java2sql» «SqlMapping::sqlType(ec, databaseFlavour)» NOT NULL
            «ENDIF»
            «IF doHistory»
                , «SqlMapping.getFieldForJavaType(databaseFlavour, "long", "20")»    «myCategory.historySequenceColumn» NOT NULL
            «ENDIF»
            -- contents field
            «ec.name.writeFieldSQLdoColumn(databaseFlavour, RequiredType::DEFAULT, d, t.embeddables)»
        )«IF tablespaceData !== null» TABLESPACE «tablespaceData»«ENDIF»;

        ALTER TABLE «tablename» ADD CONSTRAINT «tablename»_pk PRIMARY KEY (
            «startOfPk»«FOR ekc : ec.extraKeyColumns», «ekc»«ENDFOR»«IF ec.mapKey !== null», «ec.mapKey.java2sql»«ENDIF»«optionalHistoryKeyPart»
        )«IF tablespaceIndex !== null» USING INDEX TABLESPACE «tablespaceIndex»«ENDIF»;
        '''
    }

    def sqlDdlOut(EntityDefinition t, DatabaseFlavour databaseFlavour, boolean doHistory) {
        val String tablename = YUtil::mkTablename(t, doHistory)
        val baseEntity = t.inheritanceRoot // for derived tables, the original (root) table
        val myPrimaryKeyColumns = t.primaryKeyColumns
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
        val theEmbeddables = t.theEmbeddables
        // System::out.println("      tablename is " + tablename);
        // System::out.println('''ENTITY «t.name» (history? «doHistory», DB = «databaseFlavour»): embeddables used are «theEmbeddables.map[name.name + ':' + field.name].join(', ')»''');
        val optionalHistoryKeyPart = if (doHistory) ''', «myCategory.historySequenceColumn»'''

        val tenantClass = if (t.tenantInJoinedTables || t.inheritanceRoot.xinheritance == Inheritance::TABLE_PER_CLASS)
            baseEntity.tenantClass
        else
            t.tenantClass  // for joined tables, only repeat the tenant if the DSL says so

        var grantGroup = myCategory.grantGroup
        val d = new Delimiter("  ", ", ")
        indexCount = 0
        return '''
        -- This source has been automatically created by the bonaparte DSL (bonaparte.jpa addon). Do not modify, changes will be lost.
        -- The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        -- The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git

        CREATE TABLE «tablename» (
            «IF stopAt === null»
                «t.tableCategory.trackingColumns?.recurseColumns(null, databaseFlavour, d, myPrimaryKeyColumns, theEmbeddables)»
            «ENDIF»
            «tenantClass?.recurseColumns(null, databaseFlavour, d, myPrimaryKeyColumns, theEmbeddables)»
            «IF t.discname !== null»
                «d.get»«doDiscriminator(t, databaseFlavour)»
            «ENDIF»
            «IF myPrimaryKeyColumns !== null && stopAt !== null»
                «FOR c : myPrimaryKeyColumns»
                    «c.writeFieldSQLdoColumn(databaseFlavour, RequiredType::FORCE_NOT_NULL, d, theEmbeddables)»
                «ENDFOR»
            «ENDIF»
            «IF doHistory»
                «d.get»«myCategory.historySequenceColumn»   «SqlMapping.getFieldForJavaType(databaseFlavour, "long", "20")» NOT NULL
                «d.get»«myCategory.historyChangeTypeColumn»   «SqlMapping.getFieldForJavaType(databaseFlavour, "char", "1")» NOT NULL
            «ENDIF»
            «t.pojoType.recurseColumns(stopAt, databaseFlavour, d, myPrimaryKeyColumns, theEmbeddables)»
        )«IF tablespaceData !== null» TABLESPACE «tablespaceData»«ENDIF»;

        «IF myPrimaryKeyColumns !== null»
            ALTER TABLE «tablename» ADD CONSTRAINT «tablename»_pk PRIMARY KEY (
                «FOR c : myPrimaryKeyColumns SEPARATOR ', '»«c.name.java2sql»«ENDFOR»«optionalHistoryKeyPart»
            )«IF tablespaceIndex !== null» USING INDEX TABLESPACE «tablespaceIndex»«ENDIF»;
        «ENDIF»
        «IF !doHistory»
            «FOR i : t.index»
                CREATE «IF i.isUnique»UNIQUE «ENDIF»INDEX «tablename»_«IF i.isUnique»u«ELSE»i«ENDIF»«indexCounter» ON «tablename»(
                    «FOR c : i.columns.columnName SEPARATOR ', '»«c.name.java2sql»«ENDFOR»
                )«IF tablespaceIndex !== null» TABLESPACE «tablespaceIndex»«ENDIF»;
            «ENDFOR»
        «ENDIF»
        «IF grantGroup !== null && grantGroup.grants !== null && databaseFlavour != DatabaseFlavour.MYSQL»
            «FOR g : grantGroup.grants»
                «IF g.permissions !== null && g.permissions.permissions !== null»
                    GRANT «FOR p : g.permissions.permissions SEPARATOR ','»«p.toString»«ENDFOR» ON «tablename» TO «g.roleOrUserName»;
                «ENDIF»
            «ENDFOR»
        «ENDIF»
        «IF databaseFlavour != DatabaseFlavour.MSSQLSERVER && databaseFlavour != DatabaseFlavour.MYSQL»

            «IF stopAt === null»
                «t.tableCategory.trackingColumns?.recurseComments(null, tablename, theEmbeddables)»
            «ENDIF»
            «tenantClass?.recurseComments(null, tablename, theEmbeddables)»
            «IF t.discname !== null»
                COMMENT ON COLUMN «tablename».«t.discname» IS 'autogenerated JPA discriminator column';
            «ENDIF»
            «IF doHistory»
                COMMENT ON COLUMN «tablename».«myCategory.historySequenceColumn» IS 'current sequence number of history entry';
                COMMENT ON COLUMN «tablename».«myCategory.historyChangeTypeColumn» IS 'type of change (C=create/insert, U=update, D=delete)';
            «ENDIF»
            «t.pojoType.recurseComments(stopAt, tablename, theEmbeddables)»
        «ENDIF»
    '''
    }
}
