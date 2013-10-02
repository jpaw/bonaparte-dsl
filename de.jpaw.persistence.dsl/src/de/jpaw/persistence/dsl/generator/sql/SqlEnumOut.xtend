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

import de.jpaw.bonaparte.dsl.bonScript.EnumDefinition
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition

import static de.jpaw.persistence.dsl.generator.YUtil.*

class SqlEnumOut {
    def private static postgresEnumFuncsNumeric(EnumDefinition e) '''
        -- convert a token (as stored in DB tables) of enum «(e.eContainer as PackageDefinition).name».«e.name» into the more readable symbolic constant string
        CREATE OR REPLACE FUNCTION «e.name»2s(token INTEGER) RETURNS VARCHAR
            IMMUTABLE STRICT
            AS $$
        DECLARE
        BEGIN
            «FOR i : 0 .. e.values.size - 1»
                IF token = «i» THEN
                    RETURN '«quoteSQL(e.values.get(i))»';
                END IF;
            «ENDFOR»
            RETURN '~';  -- token for undefined mapping
        END;
        $$ LANGUAGE plpgsql;

        -- convert a constant string of enum «(e.eContainer as PackageDefinition).name».«e.name» into the token used for DB table storage (which matches the Java enum ordinal())
        CREATE OR REPLACE FUNCTION «e.name»2t(token VARCHAR) RETURNS INTEGER
            IMMUTABLE STRICT
            AS $$
        DECLARE
        BEGIN
            «FOR i : 0 .. e.values.size - 1»
                IF token = '«quoteSQL(e.values.get(i))»' THEN
                    RETURN «i»;
                END IF;
            «ENDFOR»
            RETURN -1;  -- token for undefined mapping
        END;
        $$ LANGUAGE plpgsql;
        '''

    def private static postgresEnumFuncsAlpha(EnumDefinition e) '''
        -- convert a token (as stored in DB tables) of enum «(e.eContainer as PackageDefinition).name».«e.name» into the more readable symbolic constant string
        CREATE OR REPLACE FUNCTION «e.name»2s(token VARCHAR) RETURNS VARCHAR
            IMMUTABLE STRICT
            AS $$
        DECLARE
        BEGIN
            «FOR a : e.avalues»
                IF token = '«quoteSQL(a.token)»' THEN
                    RETURN '«quoteSQL(a.name)»';
                END IF;
            «ENDFOR»
            RETURN '~';  -- token for undefined mapping
        END;
        $$ LANGUAGE plpgsql;

        -- convert a constant string of enum «(e.eContainer as PackageDefinition).name».«e.name» into the token used for DB table storage
        CREATE OR REPLACE FUNCTION «e.name»2t(token VARCHAR) RETURNS VARCHAR
            IMMUTABLE STRICT
            AS $$
        DECLARE
        BEGIN
            «FOR a : e.avalues»
                IF token = '«quoteSQL(a.name)»' THEN
                    RETURN '«quoteSQL(a.token)»';
                END IF;
            «ENDFOR»
            RETURN '~';  -- token for undefined mapping
        END;
        $$ LANGUAGE plpgsql;
        '''

    def public static postgresEnumFuncs(EnumDefinition e) {
        if (e.avalues != null && !e.avalues.empty)
            postgresEnumFuncsAlpha(e)
        else
            postgresEnumFuncsNumeric(e)
    }
}
