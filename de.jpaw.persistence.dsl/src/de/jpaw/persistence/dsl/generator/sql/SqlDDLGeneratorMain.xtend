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
import de.jpaw.bonaparte.dsl.bonScript.EnumDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.Delimiter
import de.jpaw.persistence.dsl.BDDLPreferences
import de.jpaw.persistence.dsl.bDDL.ElementCollectionRelationship
import de.jpaw.persistence.dsl.bDDL.EmbeddableUse
import de.jpaw.persistence.dsl.bDDL.EntityDefinition
import de.jpaw.persistence.dsl.bDDL.Inheritance
import de.jpaw.persistence.dsl.generator.RequiredType
import de.jpaw.persistence.dsl.generator.YUtil
import java.util.ArrayList
import java.util.HashSet
import java.util.List
import java.util.Set
import org.apache.log4j.Logger
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator

import static de.jpaw.persistence.dsl.generator.sql.SqlEnumOut.*

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.persistence.dsl.generator.YUtil.*
import static extension de.jpaw.persistence.dsl.generator.sql.SqlViewOut.*

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
    	System.out.println('''Settings are: max ID length = «prefs.maxTablenameLength», «prefs.maxFieldnameLength», output = «prefs.doDebugOut», «prefs.doPostgresOut», «prefs.doOracleOut», «prefs.doMsSQLServerOut»''')
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
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::POSTGRES, e.name, "Function"), postgresEnumFuncs(e))
        }
    }

    def private static CharSequence recurseColumns(ClassDefinition cl, ClassDefinition stopAt, DatabaseFlavour databaseFlavour, Delimiter d,
        List<FieldDefinition> pkCols, List<EmbeddableUse> embeddables) {
        recurse(cl, stopAt, false,
            [ !properties.hasProperty(PROP_NODDL) ],
              embeddables,
            [ '''-- table columns of java class «name»
              '''],
            [ fld, myName, reqType | 
            '''«SqlColumns::doDdlColumn(fld, databaseFlavour, if (pkCols !== null && pkCols.contains(fld)) RequiredType::FORCE_NOT_NULL else reqType, d, myName)»
              ''']
        )
    }


    // recurse through all
    def private void recurseEnumCollection(ClassDefinition c) {
        var ClassDefinition citer = c
        while (citer !== null) {
            for (i : citer.fields) {
                val ref = DataTypeExtension::get(i.datatype)
                if (ref.enumMaxTokenLength != DataTypeExtension::NO_ENUM)
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
        		if (prefs.doOracleOut) {
                    fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,      tablename, "Table"), e.sqlEcOut(ec, tablename, DatabaseFlavour::ORACLE, doHistory))
                	fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,      tablename, "Synonym"), tablename.sqlSynonymOut)
              	}
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
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,   tablename + "_trg", "Trigger"), SqlTriggerOut.triggerOutOracle(e))
    }
    
    def private void makeTables(IFileSystemAccess fsa, EntityDefinition e, boolean doHistory) {
        var tablename = mkTablename(e, doHistory)
        // System::out.println("    tablename is " + tablename);
        if (prefs.doPostgresOut)
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::POSTGRES, tablename, "Table"), e.sqlDdlOut(DatabaseFlavour::POSTGRES, doHistory))
        if (prefs.doMsSQLServerOut)
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::MSSQLSERVER, tablename, "Table"), e.sqlDdlOut(DatabaseFlavour::MSSQLSERVER, doHistory))
        if (prefs.doOracleOut) {
            fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,   tablename, "Table"), e.sqlDdlOut(DatabaseFlavour::ORACLE, doHistory))
	        fsa.generateFile(makeSqlFilename(e, DatabaseFlavour::ORACLE,   tablename, "Synonym"), tablename.sqlSynonymOut)
	    }
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
        -- This source has been automatically created by the bonaparte DSL (persistence addon). Do not modify, changes will be lost.
        -- The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        -- The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git

        CREATE TABLE «tablename» (
            -- base table PK
            «IF baseEntity.pk !== null»
                «FOR c : baseEntity.pk.columnName»
                    «SqlColumns::writeFieldSQLdoColumn(c, databaseFlavour, RequiredType::FORCE_NOT_NULL, d, t.embeddables)»
                «ENDFOR»
            «ENDIF»
            «IF ec.mapKey !== null»
                -- element collection key
                , «ec.mapKey.java2sql» «SqlMapping::sqlType(ec, databaseFlavour)» NOT NULL
            «ENDIF»
            «IF doHistory»
            	, «SqlMapping.getFieldForJavaType(databaseFlavour, "long")»    «myCategory.historySequenceColumn» NOT NULL
            «ENDIF»
            -- contents field
            «SqlColumns::writeFieldSQLdoColumn(ec.name, databaseFlavour, RequiredType::DEFAULT, d, t.embeddables)»
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
        -- This source has been automatically created by the bonaparte DSL (persistence addon). Do not modify, changes will be lost.
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
                    «SqlColumns::writeFieldSQLdoColumn(c, databaseFlavour, RequiredType::FORCE_NOT_NULL, d, theEmbeddables)»
                «ENDFOR»
            «ENDIF»
            «IF doHistory»
            	«d.get»«SqlMapping.getFieldForJavaType(databaseFlavour, "long")»    «myCategory.historySequenceColumn» NOT NULL
            	«d.get»«SqlMapping.getFieldForJavaType(databaseFlavour, "char")»    «myCategory.historyChangeTypeColumn» NOT NULL
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
        «IF grantGroup !== null && grantGroup.grants !== null»
            «FOR g : grantGroup.grants»
                «IF g.permissions !== null && g.permissions.permissions !== null»
                    GRANT «FOR p : g.permissions.permissions SEPARATOR ','»«p.toString»«ENDFOR» ON «tablename» TO «g.roleOrUserName»;
                «ENDIF»
            «ENDFOR»
        «ENDIF»

        «IF databaseFlavour != DatabaseFlavour.MSSQLSERVER»
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
