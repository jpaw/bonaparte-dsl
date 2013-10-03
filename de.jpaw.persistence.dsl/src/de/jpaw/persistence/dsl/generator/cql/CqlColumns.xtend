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

import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.Delimiter

import static extension de.jpaw.persistence.dsl.generator.YUtil.*

class CqlColumns {
    def public static doDdlColumn(FieldDefinition c, Delimiter d, String myName) {
        val String columnName = myName.java2sql
        return '''
            «d.get»«columnName» «CqlMapping::cqlType(c)»
        '''
    }

}
