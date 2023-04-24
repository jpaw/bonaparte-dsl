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

class SqlSequenceOut {

    def static createSequence(String sequencename, DatabaseFlavour databaseFlavour) {
    	switch (databaseFlavour) {
		case MSSQLSERVER: {
			return '''
				CREATE SEQUENCE [dbo].[«sequencename»] as bigint start with 0 increment by 1;
			'''
		}
		case MYSQL: {
			return '''
				CREATE SEQUENCE «sequencename» NOCACHE;
			'''
		}
		case ORACLE: {
			return '''
				CREATE SEQUENCE «sequencename» NOCACHE;
			'''
		}
		case POSTGRES: {
			return '''
				CREATE SEQUENCE «sequencename»;
			'''
		}
		case SAPHANA: {
			return '''
				CREATE SEQUENCE «sequencename»;
			'''
		}
    	}
    }
}
