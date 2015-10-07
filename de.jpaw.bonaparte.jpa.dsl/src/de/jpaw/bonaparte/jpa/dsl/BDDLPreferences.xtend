package de.jpaw.bonaparte.jpa.dsl

import de.jpaw.bonaparte.dsl.ConfigReader

public class BDDLPreferences {
    static private final ConfigReader configReader = new ConfigReader("BDDL")

    // general size check options
    static private final int maxFieldnameLengthDefault              = configReader.getProp("MaxFieldLen", 30);
    static private final int maxTablenameLengthDefault              = configReader.getProp("MaxTableLen", 27);
    // allow for increased max size for Oracle VARCHAR2 (4000 => 32767 with MAX_STRING_SIZE = EXTENDED): see http://docs.oracle.com/database/121/SQLRF/sql_elements001.htm#SQLRF0021
    static private final boolean oracleExtendedVarcharDefault       = configReader.getProp("OracleExtendedVarchar", false);

    // output options
    static private final boolean doDebugOutDefault                  = configReader.getProp("DebugOut",  false);
    static private final boolean doPostgresOutDefault               = configReader.getProp("Postgres",  true);
    static private final boolean doOracleOutDefault                 = configReader.getProp("Oracle",    true);
    static private final boolean doMsSQLServerOutDefault            = configReader.getProp("MSSQL",     true);
    static private final boolean doMySQLOutDefault                  = configReader.getProp("MySQL",     false);
    static private final boolean doSapHanaOutDefault                = configReader.getProp("SapHana",   true);

    // JPA 2.1 code generation options
    static private final boolean doUserTypeForEnumDefault           = configReader.getProp("UserTypeEnum",      false);
    static private final boolean doUserTypeForEnumAlphaDefault      = configReader.getProp("UserTypeEnumAlpha", false);
    static private final boolean doUserTypeForXEnumDefault          = configReader.getProp("UserTypeXEnum",     false);
    static private final boolean doUserTypeForEnumsetDefault        = configReader.getProp("UserTypeEnumset",   false);
//    static private final boolean doUserTypeForEnumsetAlphaDefault   = configReader.getProp("UserTypeEnumsetAlpha", false);
//    static private final boolean doUserTypeForXEnumsetDefault       = configReader.getProp("UserTypeXEnumset", false);
    static private final boolean doUserTypeForSFExternalsDefault    = configReader.getProp("UserTypeSingleFieldExternals", false);
    static private final boolean doUserTypeForBonaPortableDefault   = configReader.getProp("UserTypeBonaPortable", false);

    // general size check options
    public int maxFieldnameLength               = maxFieldnameLengthDefault
    public int maxTablenameLength               = maxTablenameLengthDefault
    public boolean oracleExtendedVarchar        = oracleExtendedVarcharDefault

    // output options
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

    public static BDDLPreferences currentPrefs = new BDDLPreferences
}
