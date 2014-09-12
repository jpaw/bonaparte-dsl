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
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.jpa.dsl.generator.YUtil.*
import org.apache.log4j.Logger
import de.jpaw.bonaparte.jpa.dsl.bDDL.EmbeddableUse
import java.util.List
import de.jpaw.bonaparte.dsl.generator.Delimiter
import de.jpaw.bonaparte.jpa.dsl.generator.RequiredType

class SqlColumns {
    private static Logger LOGGER = Logger.getLogger(SqlColumns)

    // TODO: check if column is in PK (then assume implicit NOT NULL)
    def public static notNullConstraint(FieldDefinition c, RequiredType reqType) {
        if (reqType == RequiredType::FORCE_NOT_NULL ||
            (reqType == RequiredType::DEFAULT && (c.isRequired || c.properties.hasProperty(PROP_NOTNULL)) && !c.isASpecialEnumWithEmptyStringAsNull)) " NOT NULL" else ""
    }
    def public static mkDefaults(FieldDefinition c, DatabaseFlavour databaseFlavour) {
        if (hasProperty(c.properties, PROP_CURRENT_USER))
            SqlMapping::getCurrentUser(databaseFlavour)
        else if (hasProperty(c.properties, PROP_CURRENT_TIMESTAMP))
            SqlMapping::getCurrentTimestamp(databaseFlavour)
        else if (hasProperty(c.properties, PROP_SQL_DEFAULT))
            SqlMapping::getDefault(c, databaseFlavour, c.properties.getProperty(PROP_SQL_DEFAULT))
        else if (c.defaultString !== null)
            SqlMapping::getDefault(c, databaseFlavour, c.defaultString)
        else
            ""
    }

    def public static doDdlColumn(FieldDefinition c, DatabaseFlavour databaseFlavour, RequiredType reqType, Delimiter d, String myName) {
        val String columnName = myName.java2sql
        if (databaseFlavour == DatabaseFlavour::ORACLE && columnName.length > 30)
            LOGGER.error("column name " + columnName + " is too long for Oracle DBs, originating Bonaparte class is " + (c.eContainer as ClassDefinition).name);
        return '''
            «d.get»«columnName» «SqlMapping::sqlType(c, databaseFlavour)»«mkDefaults(c, databaseFlavour)»«notNullConstraint(c, reqType)»
        '''
    }

    // external entry
    def public static CharSequence writeFieldSQLdoColumn(FieldDefinition f, DatabaseFlavour databaseFlavour, RequiredType reqType, Delimiter d, List<EmbeddableUse> embeddables) {
        writeFieldWithEmbeddedAndList(f, embeddables, null, null, reqType, false, "", [ fld, myName, reqType2 | fld.doDdlColumn(databaseFlavour, reqType2, d, myName) ])
    }
}
