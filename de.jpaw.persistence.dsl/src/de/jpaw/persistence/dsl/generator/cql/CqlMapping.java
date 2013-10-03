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

package de.jpaw.persistence.dsl.generator.cql;

import java.util.HashMap;
import java.util.Map;

import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition;
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension;
import de.jpaw.bonaparte.dsl.generator.XUtil;

// mapping of database vendor specific information

public class CqlMapping {
    // a lookup to determine the database vendor-specific data type to use for a given grammar type.
    static protected Map<String,String> dataTypeCqlCassandra = new HashMap<String, String>(32);
    static {
        dataTypeCqlCassandra.put("boolean",   "boolean");
        dataTypeCqlCassandra.put("int",       "int");
        dataTypeCqlCassandra.put("integer",   "int");
        dataTypeCqlCassandra.put("long",      "bigint");
        dataTypeCqlCassandra.put("float",     "float");
        dataTypeCqlCassandra.put("double",    "double");
        dataTypeCqlCassandra.put("number",    "int");
        dataTypeCqlCassandra.put("decimal",   "decimal");
        dataTypeCqlCassandra.put("byte",      "int");                          // unsupported
        dataTypeCqlCassandra.put("short",     "int");                          // unsupported
        dataTypeCqlCassandra.put("char",      "varchar");
        dataTypeCqlCassandra.put("character", "varchar");

        dataTypeCqlCassandra.put("uuid",      "uuid");
        dataTypeCqlCassandra.put("binary",    "blob");
        dataTypeCqlCassandra.put("raw",       "blob");
        dataTypeCqlCassandra.put("day",       "timestamp");
        dataTypeCqlCassandra.put("timestamp", "timestamp");
        dataTypeCqlCassandra.put("calendar",  "timestamp");

        dataTypeCqlCassandra.put("uppercase", "ascii");
        dataTypeCqlCassandra.put("lowercase", "ascii");
        dataTypeCqlCassandra.put("ascii",     "ascii");
        dataTypeCqlCassandra.put("unicode",   "text");                         // difference of text and varchar? is there any?
        dataTypeCqlCassandra.put("enum",      "int");                          // mapping to numeric or varchar is done by entity class getter/setter
        dataTypeCqlCassandra.put("object",    "blob");                         // serialized form of an object
        dataTypeCqlCassandra.put("string",    "text");
    }

    static String cqlType(FieldDefinition c) throws Exception {
        String datatype;
        DataTypeExtension ref;
        try {
            ref = DataTypeExtension.get(c.getDatatype());
        } catch (Exception ee) {
            throw new Exception("Cannot get datatype extension for fieldDefinition " + c.getName(), ee);
        }
        if (ref.objectDataType != null) {
            if (XUtil.hasProperty(c.getProperties(), "serialized")) {
                datatype = "raw";  // assume artificial ID
            } else {
                datatype = "long";  // assume artificial ID
            }
        } else {
            datatype = ref.elementaryDataType.getName().toLowerCase();
        }
        if (ref.enumMaxTokenLength >= 0) {
            // alphanumeric enum! use other type!
            datatype = "unicode";
        }
        
        datatype = dataTypeCqlCassandra.get(datatype);
        if (ref.allTokensAscii && (ref.enumMaxTokenLength >= 0)) {
            datatype = "text"; // enum special
        }
        if (datatype == null)
            return "*** UNMAPPED data type for " + c.getName() + " ***";

        if (ref.elementaryDataType != null && !c.getDatatype().equals("object") && c.isIsAggregateRequired()) {
            // some chance for a collection data type
            if (c.getIsList() != null) {
                return "list<" + datatype + ">";
            }
            if (c.getIsSet() != null) {
                return "set<" + datatype + ">";
            }
            if (c.getIsMap() != null) {
                String indexType = c.getIsMap().getIndexType();
                String index = "text";
                if (indexType.equals("Integer"))
                    index = "int";
                else if (indexType.equals("Long"))
                    index = "bigint";
                return "map<" + index + "," + datatype + ">";
            }
            throw new Exception("array not possible for  fieldDefinition " + c.getName());
        }
        return datatype;
    }
}
