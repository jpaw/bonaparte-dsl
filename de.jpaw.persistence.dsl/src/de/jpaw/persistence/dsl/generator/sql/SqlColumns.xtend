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

import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.XUtil
import de.jpaw.persistence.dsl.generator.YUtil
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension

class SqlColumns {
    // TODO: check if column is in PK (then ssume implicit NOT NULL)
    def public static nullconstraint(FieldDefinition c) {
        if (XUtil::isRequired(c)) " NOT NULL" else ""
    }
    def public static mkDefaults(FieldDefinition c, DatabaseFlavour databaseFlavour) {
        val ref = DataTypeExtension::get(c.datatype)
        if (YUtil::hasProperty(c.properties, "currentUser"))
            SqlMapping::getCurrentUser(databaseFlavour)
        else if (YUtil::hasProperty(c.properties, "currentTimestamp"))
            SqlMapping::getCurrentTimestamp(databaseFlavour)
        else if (c.defaultString != null)
            SqlMapping::getDefault(c, databaseFlavour, c.defaultString)
        else
            ""
    }

    def public static doColumn(FieldDefinition c, DatabaseFlavour databaseFlavour) '''
        «YUtil::columnName(c)» «SqlMapping::sqlType(c, databaseFlavour)»«mkDefaults(c, databaseFlavour)»«nullconstraint(c)»
    '''
}