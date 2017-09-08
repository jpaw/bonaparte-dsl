 /*
  * Copyright 2014 Michael Bischoff
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

import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.jpa.dsl.bDDL.EmbeddableUse
import de.jpaw.bonaparte.jpa.dsl.bDDL.EntityDefinition
import de.jpaw.bonaparte.jpa.dsl.generator.RequiredType
import java.util.ArrayList
import java.util.List

import static extension de.jpaw.bonaparte.jpa.dsl.generator.YUtil.*
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.DataCategory
import de.jpaw.bonaparte.jpa.dsl.bDDL.ColumnNameMappingDefinition

class SqlTriggerOut {

    def static private recurseTrigger(EntityDefinition e, FieldDefinition f, List<EmbeddableUse> embeddables,
        (FieldDefinition, String, RequiredType) => CharSequence func) {
        // println('''trigger field for «f.name» in «e.name»''')
        return f.writeFieldWithEmbeddedAndList(embeddables, null, null, RequiredType::DEFAULT, false, "", func)
    }

    def static private recurseTrigger(EntityDefinition e, List<FieldDefinition> columns,
        (FieldDefinition, String, RequiredType) => CharSequence func) {
        val embeddables = e.theEmbeddables
        return '''
            «FOR c : columns»
                «e.recurseTrigger(c, embeddables, func)»
            «ENDFOR»
        '''
    }

    def private static buildNvl(FieldDefinition f, ColumnNameMappingDefinition nmd) {
        val colname = f.name.java2sql(nmd)
        val ref = DataTypeExtension::get(f.datatype)
        var nullReplacement = "' '"
        // find out the cases when we need a different default
        // TODO: unsure which default to use for UUID
        switch (ref.category) {
        case DataCategory.BASICNUMERIC: nullReplacement = "0"
        case DataCategory.NUMERIC: nullReplacement = "0"
        case DataCategory.ENUM: nullReplacement = "0"  // only numeric enums
        case DataCategory.ENUMSET: nullReplacement = "0"
        case DataCategory.MISC: if (ref.javaType.toLowerCase == "boolean") nullReplacement = "0" else if (ref.javaType.toLowerCase == "uuid") nullReplacement = null
        case DataCategory.TEMPORAL: nullReplacement = "TO_DATE('19700101', 'YYYYMMDD')"
        case DataCategory.BINARY: nullReplacement = null
        default: {}
        }
        if (nullReplacement === null)
            return ''':OLD.«colname» <> :NEW.«colname»'''
        else
            return '''NVL(:OLD.«colname», «nullReplacement») <> NVL(:NEW.«colname», «nullReplacement»)'''
    }

    def private static v(FieldDefinition f, boolean categorySetting, CharSequence regularData) {
        val ref = DataTypeExtension::get(f.datatype)
        val isTechUser = f.properties.hasProperty(PROP_CURRENT_USER) && ref.category == DataCategory.STRING
        val isTimestamp = f.properties.hasProperty(PROP_CURRENT_TIMESTAMP) && ref.category == DataCategory.TEMPORAL
        if (categorySetting && !f.properties.hasProperty(PROP_NOUPDATE) && (isTechUser || isTimestamp)) {
            // is special field
            if (isTechUser) {
                return ''', SUBSTR(USER, 1, «ref.elementaryDataType.length»)'''
            } else if (ref.elementaryDataType.length == 0) {
                // temporal field with seconds precision
                return ''', SYSDATE'''
            } else {
                // temporal field with sub-second precision
                return ''', SYSTIMESTAMP'''
            }
        } else {
            // regular field
            return regularData
        }
    }

    def public static triggerOutOracle(EntityDefinition e) {
        val baseTablename = mkTablename(e, false)
        val tablename = mkTablename(e, true)
        val historyCategory = e.tableCategory.historyCategory
        val myPrimaryKeyColumns = e.primaryKeyColumns ?: new ArrayList<FieldDefinition>(0) // here, myPrimaryKeyColumns may not be null
        val nonPrimaryKeyColumns = e.nonPrimaryKeyColumns(true) ?: new ArrayList<FieldDefinition>(0)
        val nmd = e.nameMapping
        println('''Creating ORACLE trigger for table «baseTablename», writing to «tablename». PK columns are «myPrimaryKeyColumns.map[name].join(', ')»''')
        // create an additional list to provide an ordered collection of both lists, but without repeated field names,
        // in the ordering of the original lists. For natural keys to work, it is essential that the comparison is based on the field names only!
        val keyFieldNames = myPrimaryKeyColumns.map[name]
        val allColumns = new ArrayList<FieldDefinition>(myPrimaryKeyColumns)
        nonPrimaryKeyColumns.filter[!keyFieldNames.contains(it.name)].forEach[allColumns.add(it)]

        return '''
            -- This source has been automatically created by the bonaparte DSL (bonaparte.jpa addon). Do not modify, changes will be lost.
            -- The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
            -- The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git

            CREATE OR REPLACE TRIGGER «baseTablename»_tr
                AFTER INSERT OR DELETE OR UPDATE ON «baseTablename»
                REFERENCING NEW AS NEW OLD AS OLD
                FOR EACH ROW
            DECLARE
                next_seq_    NUMBER(20) := 0;
                change_type_ VARCHAR2(1 CHAR);
            BEGIN
                IF INSERTING THEN
                    change_type_ := 'I';
                END IF;
                IF UPDATING THEN
                    change_type_ := 'U';
                    «IF myPrimaryKeyColumns.size > 0»
                        -- deny attempts to change a primary key column
                        IF «FOR c : myPrimaryKeyColumns SEPARATOR ' OR '»«c.buildNvl(nmd)»«ENDFOR» THEN
                            RAISE DUP_VAL_ON_INDEX;
                        END IF;
                    «ENDIF»
                END IF;
                SELECT «e.tableCategory.historySequenceName».NEXTVAL INTO next_seq_ FROM DUAL;
                IF INSERTING OR UPDATING THEN
                    INSERT INTO «tablename» (
                        «historyCategory.historySequenceColumn»
                        , «historyCategory.historyChangeTypeColumn»
                        «e.recurseTrigger(allColumns, [ fld, myName, reqType | ''', «myName.java2sql(nmd)»'''])»
                    ) VALUES (
                        next_seq_
                        , change_type_
                        «e.recurseTrigger(allColumns, [ fld, myName, reqType | fld.v(historyCategory.actualData, ''', :NEW.«myName.java2sql(nmd)»''') ])»
                    );
                END IF;
                IF DELETING THEN
                    INSERT INTO «tablename» (
                        «historyCategory.historySequenceColumn»
                        , «historyCategory.historyChangeTypeColumn»
                        «e.recurseTrigger(allColumns, [ fld, myName, reqType | ''', «myName.java2sql(nmd)»'''])»
                    ) VALUES (
                        next_seq_
                        , 'D'
                        «e.recurseTrigger(allColumns, [ fld, myName, reqType | fld.v(historyCategory.actualData, ''', :OLD.«myName.java2sql(nmd)»''') ])»
                    );
                END IF;
            END;
            /
        '''
    }

    def private static buildNe(FieldDefinition f, ColumnNameMappingDefinition nmd) {
        val colname = f.name.java2sql(nmd)
        return '''OLD.«colname» <> NEW.«colname»'''
    }

    def public static triggerOutPostgres(EntityDefinition e) {
        val baseTablename = mkTablename(e, false)
        val tablename = mkTablename(e, true)
        val historyCategory = e.tableCategory.historyCategory
        val myPrimaryKeyColumns = e.primaryKeyColumns ?: new ArrayList<FieldDefinition>(0) // here, myPrimaryKeyColumns may not be null
        val nonPrimaryKeyColumns = e.nonPrimaryKeyColumns(true) ?: new ArrayList<FieldDefinition>(0)
        val nmd = e.nameMapping
        println('''Creating POSTGRES trigger for table «baseTablename», writing to «tablename». PK columns are «myPrimaryKeyColumns.map[name].join(', ')»''')
        // create an additional list to provide an ordered collection of both lists, but without repeated field names,
        // in the ordering of the original lists. For natural keys to work, it is essential that the comparison is based on the field names only!
        val keyFieldNames = myPrimaryKeyColumns.map[name]
        val allColumns = new ArrayList<FieldDefinition>(myPrimaryKeyColumns)
        nonPrimaryKeyColumns.filter[!keyFieldNames.contains(it.name)].forEach[allColumns.add(it)]

        // in postgres, there is no CREATE OR REPLACE TRIGGER.
        // We need 3 statements instead:
        // 1) a function
        // 2) a DROP TRIGGER IF EXISTS (see https://www.postgresql.org/docs/9.4/static/sql-droptrigger.html)
        // 3) a CREATE TRIGGER
        return '''
            -- This source has been automatically created by the bonaparte DSL (bonaparte.jpa addon). Do not modify, changes will be lost.
            -- The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
            -- The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git

            CREATE OR REPLACE FUNCTION «baseTablename»_tp() RETURNS TRIGGER AS $«baseTablename»_td$
            DECLARE
                next_seq_ BIGINT;
            BEGIN
                SELECT NEXTVAL('«e.tableCategory.historySequenceName»') INTO next_seq_;
                IF (TG_OP = 'INSERT') THEN
                    INSERT INTO «tablename» (
                        «historyCategory.historySequenceColumn»
                        , «historyCategory.historyChangeTypeColumn»
                        «e.recurseTrigger(allColumns, [ fld, myName, reqType | ''', «myName.java2sql(nmd)»'''])»
                    ) VALUES (
                        next_seq_, 'I'
                        «e.recurseTrigger(allColumns, [ fld, myName, reqType | fld.v(historyCategory.actualData, ''', NEW.«myName.java2sql(nmd)»''') ])»
                    );
                    RETURN NEW;
                END IF;
                IF (TG_OP = 'UPDATE') THEN
                    «IF myPrimaryKeyColumns.size > 0»
                        -- deny attempts to change a primary key column
                        IF «FOR c : myPrimaryKeyColumns SEPARATOR ' OR '»«c.buildNe(nmd)»«ENDFOR» THEN
                            RAISE EXCEPTION 'Cannot change primary key column to different value';
                        END IF;
                    «ENDIF»
                    INSERT INTO «tablename» (
                        «historyCategory.historySequenceColumn»
                        , «historyCategory.historyChangeTypeColumn»
                        «e.recurseTrigger(allColumns, [ fld, myName, reqType | ''', «myName.java2sql(nmd)»'''])»
                    ) VALUES (
                        next_seq_, 'U'
                        «e.recurseTrigger(allColumns, [ fld, myName, reqType | fld.v(historyCategory.actualData, ''', NEW.«myName.java2sql(nmd)»''') ])»
                    );
                    RETURN NEW;
                END IF;
                IF (TG_OP = 'DELETE') THEN
                    INSERT INTO «tablename» (
                        «historyCategory.historySequenceColumn»
                        , «historyCategory.historyChangeTypeColumn»
                        «e.recurseTrigger(allColumns, [ fld, myName, reqType | ''', «myName.java2sql(nmd)»'''])»
                    ) VALUES (
                        next_seq_, 'D'
                        «e.recurseTrigger(allColumns, [ fld, myName, reqType | fld.v(historyCategory.actualData, ''', OLD.«myName.java2sql(nmd)»''') ])»
                    );
                    RETURN OLD;
                END IF;
                RETURN NULL;
            END;
            $«baseTablename»_td$ LANGUAGE plpgsql;

            DROP TRIGGER IF EXISTS «baseTablename»_tr ON «baseTablename»;

            CREATE TRIGGER «baseTablename»_tr
                AFTER INSERT OR DELETE OR UPDATE ON «baseTablename»
                FOR EACH ROW EXECUTE PROCEDURE «baseTablename»_tp();
        '''
        // TODO: check if we should use SECURITY DEFINER, as recommended in https://www.postgresql.org/docs/9.5/static/sql-createfunction.html
        // SECURITY DEFINER
        // -- Set a secure search_path: trusted schema(s), then 'pg_temp'.
        // SET search_path = admin, pg_temp;
    }
}
