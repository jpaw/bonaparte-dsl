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

package de.jpaw.persistence.dsl.generator.sql

import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.persistence.dsl.bDDL.EmbeddableUse
import de.jpaw.persistence.dsl.bDDL.EntityDefinition
import de.jpaw.persistence.dsl.generator.RequiredType
import java.util.List

import static extension de.jpaw.persistence.dsl.generator.YUtil.*

class SqlTriggerOut {
    
    def static private recurseTrigger(EntityDefinition e, FieldDefinition f, List<EmbeddableUse> embeddables,
        (FieldDefinition, String, RequiredType) => CharSequence func) {
        // println('''trigger field for «f.name» in «e.name»''')
        return f.writeFieldWithEmbeddedAndList(embeddables, null, null, RequiredType::DEFAULT, false, "", func)
    }
    
    def static private recurseTrigger(EntityDefinition e, List<FieldDefinition> keys, List<FieldDefinition> data,
        (FieldDefinition, String, RequiredType) => CharSequence func) {
        val embeddables = e.theEmbeddables
        return '''
            «FOR c : keys»
                «e.recurseTrigger(c, embeddables, func)»
            «ENDFOR»
            «FOR c : data»
                «e.recurseTrigger(c, embeddables, func)»
            «ENDFOR»        
        '''
    }
    
    def public static triggerOutOracle(EntityDefinition e) {
        val tablename = mkTablename(e, true)
        val historyCategory = e.tableCategory.historyCategory
        val myPrimaryKeyColumns = e.primaryKeyColumns
        val nonPrimaryKeyColumns = e.nonPrimaryKeyColumns(true)
        
        return '''
            -- This source has been automatically created by the bonaparte DSL (persistence addon). Do not modify, changes will be lost.
            -- The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
            -- The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git

            CREATE OR REPLACE TRIGGER «tablename»_trg
                AFTER INSERT OR DELETE OR UPDATE ON «tablename»
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
                    -- deny attempts to change a primary key column
                    IF FALSE
                        «FOR c : myPrimaryKeyColumns»
                             OR NVL(:OLD.«c.name.java2sql», ' ') <> NVL(:NEW.«c.name.java2sql», ' ')
                        «ENDFOR»
                        THEN RAISE DUP_VAL_ON_INDEX;
                    END IF;
                END IF;
                SELECT «e.tableCategory.historySequenceName».NEXTVAL INTO next_seq_ FROM DUAL;
                IF INSERTING OR UPDATING THEN
                    INSERT INTO «tablename» (
                        «historyCategory.historySequenceColumn»
                        , «historyCategory.historyChangeTypeColumn»
                        «e.recurseTrigger(myPrimaryKeyColumns, nonPrimaryKeyColumns, [ fld, myName, reqType | ''', «myName.java2sql»'''])»
                    ) VALUES (
                        next_seq_
                        , change_type_
                        «e.recurseTrigger(myPrimaryKeyColumns, nonPrimaryKeyColumns, [ fld, myName, reqType | ''', :NEW.«myName.java2sql»'''])»
                    );
                END IF;
                IF DELETING THEN
                    INSERT INTO «tablename» (
                        «historyCategory.historySequenceColumn»
                        , «historyCategory.historyChangeTypeColumn»
                        «e.recurseTrigger(myPrimaryKeyColumns, nonPrimaryKeyColumns, [ fld, myName, reqType | ''', «myName.java2sql»'''])»
                    ) VALUES (
                        next_seq_
                        , 'D'
                        «e.recurseTrigger(myPrimaryKeyColumns, nonPrimaryKeyColumns, [ fld, myName, reqType | ''', :OLD.«myName.java2sql»'''])»
                    );
                END IF;
            END;
            /
        '''
    }
}