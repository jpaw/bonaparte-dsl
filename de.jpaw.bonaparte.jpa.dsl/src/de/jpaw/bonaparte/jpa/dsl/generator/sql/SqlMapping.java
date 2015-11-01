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

package de.jpaw.bonaparte.jpa.dsl.generator.sql;

import java.util.HashMap;
import java.util.Map;

import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition;
import de.jpaw.bonaparte.dsl.generator.DataCategory;
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension;
import de.jpaw.bonaparte.dsl.generator.XUtil;
import de.jpaw.bonaparte.dsl.generator.java.JavaMeta;
import de.jpaw.bonaparte.jpa.dsl.BDDLPreferences;
import de.jpaw.bonaparte.jpa.dsl.bDDL.ElementCollectionRelationship;
import de.jpaw.bonaparte.jpa.dsl.generator.YUtil;

// mapping of database vendor specific information

// identifier lengths:
// ORACLE: 30 characters
// Postgres: 60 characters
// SAP HANA: 127 characters

public class SqlMapping {
    // a lookup to determine the database vendor-specific data type to use for a given grammar type.
    // (LANGUAGE / DATABASE VENDOR SPECIFIC: SQL Oracle)
    static protected Map<String,String> dataTypeSqlOracle = new HashMap<String, String>(40);
    static {  // see http://docs.oracle.com/cd/E11882_01/server.112/e26088/sql_elements001.htm#i45441 for reference
        // we avoid the ANSI data types for Oracle, because I think the native ones have better performance
        dataTypeSqlOracle.put("boolean",   "number(1)");                // Oracle has no boolean type
        dataTypeSqlOracle.put("int",       "number(#length)");          // no specific type available for Oracle
        dataTypeSqlOracle.put("integer",   "number(#length)");          // no specific type available for Oracle
        dataTypeSqlOracle.put("long",      "number(#length)");          // no specific type available for Oracle
        dataTypeSqlOracle.put("float",     "binary_float");
        dataTypeSqlOracle.put("double",    "binary_double");
        dataTypeSqlOracle.put("number",    "number(#length)");
        dataTypeSqlOracle.put("decimal",   "number(#length,#precision)");
        dataTypeSqlOracle.put("byte",      "number(#length)");
        dataTypeSqlOracle.put("short",     "number(#length)");
        dataTypeSqlOracle.put("char",      "varchar2(1 char)");
        dataTypeSqlOracle.put("character", "varchar2(1 char)");

        dataTypeSqlOracle.put("uuid",      "raw(16)");                      // not yet supported by grammar!
        dataTypeSqlOracle.put("binary",    "raw(#length)");                 // only up to 2000 bytes, use BLOB if more!
        dataTypeSqlOracle.put("raw",       "raw(#length)");                 // only up to 2000 bytes, use BLOB if more!
        dataTypeSqlOracle.put("day",       "date");                         // Oracle has no day without a time field
        dataTypeSqlOracle.put("timestamp", "timestamp(#length)");           // timestamp(0) should become DATE
        dataTypeSqlOracle.put("instant",   "timestamp(#length)");           // timestamp(0) should become DATE
        dataTypeSqlOracle.put("time",      "timestamp(#length)");           // timestamp(0) should become DATE

        dataTypeSqlOracle.put("uppercase", "varchar2(#length)");            // only up to 4000 characters, use CLOB if more!
        dataTypeSqlOracle.put("lowercase", "varchar2(#length)");            // only up to 4000 characters, use CLOB if more!
        dataTypeSqlOracle.put("ascii",     "varchar2(#length)");            // only up to 4000 characters, use CLOB if more!
        dataTypeSqlOracle.put("unicode",   "varchar2(#length char)");       // only up to 4000 characters, use CLOB if more!
        dataTypeSqlOracle.put("enum",      "number(4)");                    // mapping to numeric or varchar is done by entity class getter/setter
        dataTypeSqlOracle.put("object",    "blob");                         // serialized form of an object
        dataTypeSqlOracle.put("json",      "clob");                         // JSON object
        dataTypeSqlOracle.put("element",   "varchar2(4000)");               // JSON any type, but expected to be short
        dataTypeSqlOracle.put("string",    "varchar2(#length)");            // only up to 4000 characters, use CLOB if more!
    }
    static protected Map<String,String> dataTypeSqlPostgres = new HashMap<String, String>(40);
    static { // see http://www.postgresql.org/docs/9.1/static/datatype.html for reference
        dataTypeSqlPostgres.put("boolean",   "boolean");
        dataTypeSqlPostgres.put("int",       "integer");
        dataTypeSqlPostgres.put("integer",   "integer");
        dataTypeSqlPostgres.put("long",      "bigint");
        dataTypeSqlPostgres.put("float",     "real");
        dataTypeSqlPostgres.put("double",    "double precision");
        dataTypeSqlPostgres.put("number",    "numeric(#length)");           // numeric and decimal are equivalent in Postgres
        dataTypeSqlPostgres.put("decimal",   "decimal(#length,#precision)"); // numeric and decimal are equivalent in Postgres
        dataTypeSqlPostgres.put("byte",      "smallint");                   // there is no Postgres single byte numeric datatype
        dataTypeSqlPostgres.put("short",     "smallint");
        dataTypeSqlPostgres.put("char",      "char(1)");
        dataTypeSqlPostgres.put("character", "char(1)");

        dataTypeSqlPostgres.put("uuid",      "uuid");
        dataTypeSqlPostgres.put("binary",    "bytea");
        dataTypeSqlPostgres.put("raw",       "bytea");
        dataTypeSqlPostgres.put("day",       "date");
        dataTypeSqlPostgres.put("instant",   "timestamp(#length)");
        dataTypeSqlPostgres.put("timestamp", "timestamp(#length)");
        dataTypeSqlPostgres.put("time",      "time(#length)");

        dataTypeSqlPostgres.put("uppercase", "varchar(#length)");
        dataTypeSqlPostgres.put("lowercase", "varchar(#length)");
        dataTypeSqlPostgres.put("ascii",     "varchar(#length)");
        dataTypeSqlPostgres.put("unicode",   "varchar(#length)");
        dataTypeSqlPostgres.put("enum",      "smallint");
        dataTypeSqlPostgres.put("object",    "bytea");                       // mapping to numeric or varchar is done by entity class getter/setter
        dataTypeSqlPostgres.put("json",      "jsonb");                       // JSON object (native)
        dataTypeSqlPostgres.put("element",   "text");                        // JSON any type
        dataTypeSqlPostgres.put("string",    "varchar(#length)");            // only up to 4000 characters, use CLOB if more!
    }
    static protected Map<String,String> dataTypeSqlMsSQLServer = new HashMap<String, String>(40);
    static { // see http://www.w3schools.com/sql/sql_datatypes.asp for reference
        dataTypeSqlMsSQLServer.put("boolean",   "bit");
        dataTypeSqlMsSQLServer.put("int",       "int");
        dataTypeSqlMsSQLServer.put("integer",   "int");
        dataTypeSqlMsSQLServer.put("long",      "bigint");
        dataTypeSqlMsSQLServer.put("float",     "float");
        dataTypeSqlMsSQLServer.put("double",    "double");
        dataTypeSqlMsSQLServer.put("number",    "decimal(#length)");
        dataTypeSqlMsSQLServer.put("decimal",   "decimal(#length,#precision)"); // numeric and decimal are equivalent in MS SQL server
        dataTypeSqlMsSQLServer.put("byte",      "tinyint");
        dataTypeSqlMsSQLServer.put("short",     "smallint");
        dataTypeSqlMsSQLServer.put("char",      "char(1)");
        dataTypeSqlMsSQLServer.put("character", "char(1)");

        dataTypeSqlMsSQLServer.put("uuid",      "varbinary(16)");
        dataTypeSqlMsSQLServer.put("binary",    "varbinary(#length)");
        dataTypeSqlMsSQLServer.put("raw",       "varbinary(#length)");
        dataTypeSqlMsSQLServer.put("day",       "date");
        dataTypeSqlMsSQLServer.put("instant",   "datetime2(#length)");
        dataTypeSqlMsSQLServer.put("timestamp", "datetime2(#length)");
        dataTypeSqlMsSQLServer.put("time",      "datetime2(#length)");

        dataTypeSqlMsSQLServer.put("uppercase", "varchar(#length)");
        dataTypeSqlMsSQLServer.put("lowercase", "varchar(#length)");
        dataTypeSqlMsSQLServer.put("ascii",     "varchar(#length)");
        dataTypeSqlMsSQLServer.put("unicode",   "nvarchar(#length)");
        dataTypeSqlMsSQLServer.put("enum",      "smallint");
        dataTypeSqlMsSQLServer.put("object",    "varbinary(MAX)");
        dataTypeSqlMsSQLServer.put("json",      "nvarchar(MAX");                 // JSON object
        dataTypeSqlMsSQLServer.put("element",   "nvarchar(4000)");               // JSON any type, but expected to be short
        dataTypeSqlMsSQLServer.put("string",    "nvarchar(#length)");            // only up to 4000 characters, use CLOB if more!
    }
    static protected Map<String,String> dataTypeSqlMySQL = new HashMap<String, String>(40);
    static { // see http://dev.mysql.com/doc/refman/5.6/en/data-types.html
        dataTypeSqlMySQL.put("boolean",   "boolean");                    // synonym for tinyint(1)
        dataTypeSqlMySQL.put("int",       "integer");
        dataTypeSqlMySQL.put("integer",   "integer");
        dataTypeSqlMySQL.put("long",      "bigint");
        dataTypeSqlMySQL.put("float",     "real");
        dataTypeSqlMySQL.put("double",    "double precision");
        dataTypeSqlMySQL.put("number",    "numeric(#length)");           // numeric and decimal are equivalent in Postgres
        dataTypeSqlMySQL.put("decimal",   "decimal(#length,#precision)"); // numeric and decimal are equivalent in Postgres
        dataTypeSqlMySQL.put("byte",      "tinyint");                    // there is no Postgres single byte numeric datatype
        dataTypeSqlMySQL.put("short",     "smallint");
        dataTypeSqlMySQL.put("char",      "char(1)");
        dataTypeSqlMySQL.put("character", "char(1)");

        dataTypeSqlMySQL.put("uuid",      "varbinary(16)");
        dataTypeSqlMySQL.put("binary",    "BLOB");
        dataTypeSqlMySQL.put("raw",       "BLOB");
        dataTypeSqlMySQL.put("day",       "date");
        dataTypeSqlMySQL.put("instant",   "timestamp(#length)");
        dataTypeSqlMySQL.put("timestamp", "datetime(#length)");
        dataTypeSqlMySQL.put("time",      "time(#length)");

        dataTypeSqlMySQL.put("uppercase", "varchar(#length)");
        dataTypeSqlMySQL.put("lowercase", "varchar(#length)");
        dataTypeSqlMySQL.put("ascii",     "varchar(#length)");
        dataTypeSqlMySQL.put("unicode",   "TEXT");
        dataTypeSqlMySQL.put("enum",      "smallint");
        dataTypeSqlMySQL.put("object",    "BLOB");                      // mapping to numeric or varchar is done by entity class getter/setter
        dataTypeSqlMySQL.put("json",      "CLOB");                      // JSON object
        dataTypeSqlMySQL.put("element",   "nvarchar(4000)");            // JSON any type, but expected to be short
        dataTypeSqlMySQL.put("string",    "TEXT");                      // only up to 4000 characters, use CLOB if more!
    }
    static protected Map<String,String> dataTypeSqlSapHana = new HashMap<String, String>(40);
    static {  // see https://help.sap.com/saphelp_hanaplatform/helpdata/en/20/a1569875191014b507cf392724b7eb/content.htm
        dataTypeSqlSapHana.put("boolean",   "number(1)");                // Oracle has no boolean type
        dataTypeSqlSapHana.put("int",       "integer");
        dataTypeSqlSapHana.put("integer",   "integer");
        dataTypeSqlSapHana.put("long",      "bigint");
        dataTypeSqlSapHana.put("float",     "real");
        dataTypeSqlSapHana.put("double",    "double");
        dataTypeSqlSapHana.put("number",    "decimal(#length)");
        dataTypeSqlSapHana.put("decimal",   "decimal(#length,#precision)");
        dataTypeSqlSapHana.put("byte",      "tinyint");                      // ATTN: this one is unsigned (an unsigned 1 byte char)!!!!
        dataTypeSqlSapHana.put("short",     "smallint");
        dataTypeSqlSapHana.put("char",      "nvarchar(1)");
        dataTypeSqlSapHana.put("character", "nvarchar(1)");

        dataTypeSqlSapHana.put("uuid",      "varbinary(16)");               // not yet supported by grammar!
        dataTypeSqlSapHana.put("binary",    "varbinary(#length)");          // only up to 2000 bytes, use BLOB if more!
        dataTypeSqlSapHana.put("raw",       "varbinary(#length)");          // only up to 2000 bytes, use BLOB if more!
        dataTypeSqlSapHana.put("day",       "date");                        // Oracle has no day without a time field
        dataTypeSqlSapHana.put("timestamp", "timestamp(#length)");          // timestamp(0) should become seconddate
        dataTypeSqlSapHana.put("instant",   "timestamp(#length)");          // timestamp(0) should become seconddate
        dataTypeSqlSapHana.put("time",      "time");                        // only length 0 supported

        dataTypeSqlSapHana.put("uppercase", "varchar(#length)");            // only up to 5000 characters, use CLOB if more!
        dataTypeSqlSapHana.put("lowercase", "varchar(#length)");            // only up to 5000 characters, use CLOB if more!
        dataTypeSqlSapHana.put("ascii",     "varchar(#length)");            // only up to 5000 characters, use CLOB if more!
        dataTypeSqlSapHana.put("unicode",   "nvarchar(#length)");           // only up to 5000 characters, use NCLOB if more!
        dataTypeSqlSapHana.put("enum",      "smallint");                    // mapping to numeric or varchar is done by entity class getter/setter
        dataTypeSqlSapHana.put("object",    "blob");                        // serialized form of an object
        dataTypeSqlSapHana.put("json",      "nclob");                       // JSON object
        dataTypeSqlSapHana.put("element",   "nvarchar(4000)");              // JSON any type, but expected to be short
        dataTypeSqlSapHana.put("string",    "nvarchar(#length)");           // only up to 5000 characters, use CLOB if more!
    }

    static private int lengthForAlphaEnumColumn(DataTypeExtension ref) {
        return ref.enumMaxTokenLength == 0 ? 1 : ref.enumMaxTokenLength;
    }

    static String sqlType(FieldDefinition c, DatabaseFlavour databaseFlavour) throws Exception {
        String datatype;
        DataTypeExtension ref;
        try {
            ref = DataTypeExtension.get(c.getDatatype());
        } catch (Exception ee) {
            throw new Exception("Cannot get datatype extension for fieldDefinition " + c.getName(), ee);
        }
        int columnLength;
        int columnDecimals;
        if (ref.objectDataType != null) {
            if (XUtil.hasProperty(c.getProperties(), YUtil.PROP_SERIALIZED)) {
                String value = XUtil.getProperty(c.getProperties(), YUtil.PROP_SERIALIZED);
                datatype = "raw";  // assume artificial ID
                columnLength = value == null ? 2000 : Integer.valueOf(value);
                columnDecimals = 0;
            } else {
                datatype = "long";  // assume artificial ID
                columnLength = 20;  // backwards compatibility for long!  TODO: deleteme, it's one digit too much!
                columnDecimals = 0;
            }
        } else if (ref.elementaryDataType != null) {
            if (ref.category == DataCategory.ENUMSET) {
                datatype = ref.elementaryDataType.getEnumsetType().getIndexType();
                datatype = datatype == null ? "integer" : datatype.toLowerCase();
                columnLength = JavaMeta.TOTAL_DIGITS.get(datatype);
                columnDecimals = 0;
            } else if (ref.category == DataCategory.ENUMSETALPHA) {
                datatype = "unicode";
                columnLength = ref.enumMaxTokenLength;
                columnDecimals = 0;
            } else if (ref.category == DataCategory.XENUMSET) {
                datatype = "unicode";
                columnLength = ref.elementaryDataType.getLength();
                columnDecimals = 0;
            } else {
                datatype = ref.elementaryDataType.getName().toLowerCase();
                columnLength = ref.elementaryDataType.getLength();
                columnDecimals = ref.elementaryDataType.getDecimals();
                if (datatype.equals("json") || datatype.equals("element")) {
                    // JSON types either map to a native type (stored under the "json" entry, or compact form (shared from "object") or text (element)
                    if (XUtil.hasProperty(c.getProperties(), YUtil.PROP_COMPACT)) {
                        datatype = "object";    // treat as object
                    } else if (XUtil.hasProperty(c.getProperties(), YUtil.PROP_NATIVE)) {
                        datatype = "json";      // treat as native object (assignment is redundant for json type)
                    } else {
                        // fall back to textual form, mapping stored with "element"
                        datatype = "element";   // assignment is redundant for type "element"
                    }
                }
                if (columnLength == 0) {
                    // get some meaningful default for integral values
                    Integer maxLength = JavaMeta.TOTAL_DIGITS.get(datatype);
                    if (maxLength != null) {
                        // yes, we got some default!
                        if (maxLength == 19)
                            maxLength = 20;  // backwards compatibility for long!  TODO: deleteme, it's one digit too much!
                        columnLength = maxLength;
                    }
                }
            }
        } else {
            // never reached
            datatype = "UNDEFINED";
            columnLength = 777;
            columnDecimals = 0;
        }
        if (ref.enumMaxTokenLength >= 0) {
            // alphanumeric enum! use other type!
            datatype = "unicode";
        }

        String columnLengthString = Integer.valueOf(columnLength).toString();
        // System.out.println(databaseFlavour.toString() + ": Length of " + c.getName() + " is " + columnLengthString);

        switch (databaseFlavour) {
        case ORACLE:
            boolean extendedVarchar = BDDLPreferences.currentPrefs.oracleExtendedVarchar;
            datatype = dataTypeSqlOracle.get(datatype);
            if (columnLength > (extendedVarchar ? 32767 : 2000)) {
                if (datatype.startsWith("raw")) {
                    datatype = "blob";
                } else if ((columnLength > (extendedVarchar ? 32767 : 4000)) && datatype.startsWith("varchar2")) {
                    datatype = "clob";
                }
            } else if ((columnLength == 0) && datatype.equals("timestamp(#length)")) {
                datatype = "date";  // better performance, less memory consumption
            }
            if (ref.enumMaxTokenLength >= 0) {
                datatype = "varchar2(" + lengthForAlphaEnumColumn(ref) + ")";
            }
            break;
        case POSTGRES:
            datatype = dataTypeSqlPostgres.get(datatype);
            if (ref.enumMaxTokenLength >= 0) {
                datatype = "varchar(" + lengthForAlphaEnumColumn(ref) + ")";
            }
            break;
        case MSSQLSERVER:
            datatype = dataTypeSqlMsSQLServer.get(datatype);
            if (ref.enumMaxTokenLength >= 0) {
                datatype = "nvarchar(" + lengthForAlphaEnumColumn(ref) + ")";
            }
            if (columnLength > 8000) {
                columnLengthString = "MAX";
                // System.out.println("*** using MAX ***");
            }
            break;
        case MYSQL:
//            String bkp = datatype;
            datatype = dataTypeSqlMySQL.get(datatype);
            if (ref.enumMaxTokenLength >= 0) {
                datatype = "varchar(" + lengthForAlphaEnumColumn(ref) + ")";
            }

//            if (datatype == null)
//                System.out.println("null for " + bkp);
            // special treatment TEXT and BLOB
            if (datatype.equals("TEXT")) {
                // UTF-8 factor is 4 with utf8mb4
                // type depends on length
                columnLength = 4 * columnLength;
                if (columnLength <= 65535)
                    datatype = String.format("varchar(%d)", columnLength);
                else
                    datatype = "mediumtext";
            } else if (datatype.equals("BLOB")) {
                if (columnLength <= 65535)
                    datatype = String.format("varbinary(%d)", columnLength);
                else
                    datatype = "mediumblob";
            }
            break;
        case SAPHANA:
            datatype = dataTypeSqlSapHana.get(datatype);
            if (columnLength > 5000) {
                if (datatype.startsWith("varbinary")) {
                    datatype = "blob";
                } else if (datatype.startsWith("varchar")) {
                    datatype = "clob";
                } else if (datatype.startsWith("nvarchar")) {
                    datatype = "nclob";
                }
            } else if ((columnLength == 0) && datatype.equals("timestamp(#length)")) {
                datatype = "seconddate";  // better performance, less memory consumption
            }
            if (ref.enumMaxTokenLength >= 0) {
                datatype = "nvarchar(" + lengthForAlphaEnumColumn(ref) + ")";
            }
            break;
        }
        if (datatype == null)
            return "*** UNMAPPED data type for " + c.getName() + " in dialect " + databaseFlavour.toString() + " ***";

        //System.out.println("DEBUG: dataype = " + datatype + "(type " + c.getName() + ")");
        //System.out.println("DEBUG: length = " + Integer.valueOf(ref.elementaryDataType.getLength()).toString());
        //System.out.println("DEBUG: precision = " + Integer.valueOf(ref.elementaryDataType.getDecimals()).toString());
//        if (ref.enumMaxTokenLength >= 0) {
//            // special case for alphanumeric enums, again!
//            // TODO: this code should be redundant, see above!
//            return datatype.replace("#length",    Integer.valueOf(ref.enumMaxTokenLength).toString());
//        }
        return datatype.replace("#length", columnLengthString).replace("#precision", Integer.valueOf(columnDecimals).toString());
    }

    static public String getFieldForJavaType(DatabaseFlavour databaseFlavour, String javaType, String lengthString) {
        String rawType = null;
        switch (databaseFlavour) {
        case ORACLE:
            rawType = dataTypeSqlOracle.get(javaType);
            break;
        case POSTGRES:
            rawType = dataTypeSqlPostgres.get(javaType);
            break;
        case MSSQLSERVER:
            rawType = dataTypeSqlMsSQLServer.get(javaType);
            break;
        case MYSQL:
            rawType = dataTypeSqlMySQL.get(javaType);
            break;
        case SAPHANA:
            rawType = dataTypeSqlSapHana.get(javaType);
            break;
        }
        return rawType == null ? null : rawType.replace("#length", lengthString);
    }

    static boolean supportsTablespaces(DatabaseFlavour databaseFlavour) {
        switch (databaseFlavour) {
        case ORACLE:
            return true;
        case SAPHANA:
            return false;           // HANA has them, but TODO
        default:
            return false;
        }
    }

    static public String getCurrentUser(DatabaseFlavour databaseFlavour) {
        switch (databaseFlavour) {
        case ORACLE:
            return " DEFAULT SUBSTR(USER, 1, 8)";
        case POSTGRES:
            return " DEFAULT CURRENT_USER";
        case MSSQLSERVER:
            return " DEFAULT CURRENT_USER";
        case MYSQL:
            return " DEFAULT CURRENT_USER";
        case SAPHANA:
            return "";   // could not get DEFAULT CURRENT_USER as well as SESSION_USER working 
        }
        return "";
    }

    static public String getCurrentTimestamp(DatabaseFlavour databaseFlavour) {
        switch (databaseFlavour) {
        case ORACLE:
            return " DEFAULT SYSDATE";
        case POSTGRES:
            return " DEFAULT CURRENT_TIMESTAMP";
        case MSSQLSERVER:
            return " DEFAULT SYSUTCDATETIME()";
        case MYSQL:
            return " DEFAULT CURRENT_TIMESTAMP";
        case SAPHANA:
            return " DEFAULT CURRENT_UTCTIMESTAMP";
        }
        return "";
    }

    static public String getDefault(FieldDefinition c, DatabaseFlavour databaseFlavour, String value) throws Exception {
        if (value == null || value.length() == 0)
            return "";
        DataTypeExtension ref = DataTypeExtension.get(c.getDatatype());
        if ((databaseFlavour == DatabaseFlavour.ORACLE ||
             databaseFlavour == DatabaseFlavour.MYSQL ||
             databaseFlavour == DatabaseFlavour.SAPHANA ||
             databaseFlavour == DatabaseFlavour.MSSQLSERVER) && "Boolean".equals(ref.javaType)) {
            // Oracle does not know booleans, convert it to numeric!  MySQL as well.
            // MS SQL server uses BIT, which also takes 0 and 1
            if ("true".equals(value)) {
                return " DEFAULT 1";
            } else if ("false".equals(value)) {
                return " DEFAULT 0";
            } else {
                return " DEFAULT " + value; // no mapping possible, maybe it just fits !? Otherwise it will generate an error!
            }
        } else if ("String".equals(ref.javaType)) {
            return " DEFAULT '" + YUtil.quoteSQL(value) + "'";
        } else {
            return " DEFAULT " + value;
        }
    }

    // for ElementCollections
    static public String sqlType(ElementCollectionRelationship ec, DatabaseFlavour databaseFlavour) {
        if (ec.getName().getIsMap() == null)
            return "*** NO MAP ***";
        String datatype = ec.getName().getIsMap().getIndexType().toLowerCase();
        switch (databaseFlavour) {
        case ORACLE:
            datatype = dataTypeSqlOracle.get(datatype);
            break;
        case POSTGRES:
            datatype = dataTypeSqlPostgres.get(datatype);
            break;
        case MSSQLSERVER:
            datatype = dataTypeSqlMsSQLServer.get(datatype);
            break;
        case MYSQL:
            datatype = dataTypeSqlMySQL.get(datatype);
            break;
        case SAPHANA:
            datatype = dataTypeSqlSapHana.get(datatype);
            break;
        }
        return datatype.replace("#length", Integer.valueOf(ec.getMapKeySize() > 0 ? ec.getMapKeySize() : 255).toString());
    }
}
