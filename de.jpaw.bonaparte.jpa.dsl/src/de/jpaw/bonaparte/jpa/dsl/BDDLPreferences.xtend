package de.jpaw.bonaparte.jpa.dsl

import de.jpaw.bonaparte.dsl.ConfigReader

class BDDLPreferences {
    static final ConfigReader configReader = new ConfigReader("BDDL")

    // general size check options
    static final int maxFieldnameLengthDefault              = configReader.getProp("MaxFieldLen", 60);
    static final int maxTablenameLengthDefault              = configReader.getProp("MaxTableLen", 57);
    // allow for increased max size for Oracle VARCHAR2 (4000 => 32767 with MAX_STRING_SIZE = EXTENDED): see http://docs.oracle.com/database/121/SQLRF/sql_elements001.htm#SQLRF0021
    static final boolean oracleExtendedVarcharDefault       = configReader.getProp("OracleExtendedVarchar", false);

    // output options
    static final boolean doIndexesDefault                   = configReader.getProp("IndexCreation", false);
    static final boolean doDebugOutDefault                  = configReader.getProp("DebugOut",  false);
    static final boolean doPostgresOutDefault               = configReader.getProp("Postgres",  true);
    static final boolean doOracleOutDefault                 = configReader.getProp("Oracle",    false);
    static final boolean doMsSQLServerOutDefault            = configReader.getProp("MSSQL",     false);
    static final boolean doMySQLOutDefault                  = configReader.getProp("MySQL",     false);
    static final boolean doSapHanaOutDefault                = configReader.getProp("SapHana",   false);

    // JPA 2.1 code generation options
    static final boolean doUserTypeForEnumDefault           = configReader.getProp("UserTypeEnum",      false);
    static final boolean doUserTypeForEnumAlphaDefault      = configReader.getProp("UserTypeEnumAlpha", false);
    static final boolean doUserTypeForXEnumDefault          = configReader.getProp("UserTypeXEnum",     false);
    static final boolean doUserTypeForEnumsetDefault        = configReader.getProp("UserTypeEnumset",   false);
//    static final boolean doUserTypeForEnumsetAlphaDefault   = configReader.getProp("UserTypeEnumsetAlpha", false);
//    static final boolean doUserTypeForXEnumsetDefault       = configReader.getProp("UserTypeXEnumset", false);
    static final boolean doUserTypeForSFExternalsDefault    = configReader.getProp("UserTypeSingleFieldExternals", false);
    static final boolean doUserTypeForBonaPortableDefault   = configReader.getProp("UserTypeBonaPortable",         false);
    static final boolean doUserTypeForJsonDefault           = configReader.getProp("UserTypeJson",                 false);

    // general size check options
    public int maxFieldnameLength               = maxFieldnameLengthDefault
    public int maxTablenameLength               = maxTablenameLengthDefault
    public boolean oracleExtendedVarchar        = oracleExtendedVarcharDefault

    // output options
    public boolean doIndexes                    = doIndexesDefault
    public boolean doDebugOut                   = doDebugOutDefault
    public boolean doPostgresOut                = doPostgresOutDefault
    public boolean doOracleOut                  = doOracleOutDefault
    public boolean doMsSQLServerOut             = doMsSQLServerOutDefault
    public boolean doMySQLOut                   = doMySQLOutDefault
    public boolean doSapHanaOut                 = doSapHanaOutDefault

    // JPA 2.1 code generation options
    public boolean doUserTypeForEnum            = doUserTypeForEnumDefault
    public boolean doUserTypeForEnumAlpha       = doUserTypeForEnumAlphaDefault
    public boolean doUserTypeForXEnum           = doUserTypeForXEnumDefault
    public boolean doUserTypeForEnumset         = doUserTypeForEnumsetDefault
//    public boolean doUserTypeForEnumsetAlpha    = doUserTypeForEnumsetAlphaDefault
//    public boolean doUserTypeForXEnumset        = doUserTypeForXEnumsetDefault
    public boolean doUserTypeForSFExternals     = doUserTypeForSFExternalsDefault
    public boolean doUserTypeForBonaPortable    = doUserTypeForBonaPortableDefault
    public boolean doUserTypeForJson            = doUserTypeForJsonDefault

    public static BDDLPreferences currentPrefs = new BDDLPreferences
}
