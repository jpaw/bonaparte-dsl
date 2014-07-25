package de.jpaw.persistence.dsl

import de.jpaw.bonaparte.dsl.ConfigReader

//public interface IBDDLPreferenceProvider {
//  def public BDDLPreferences getSettings()
//}
//
//public class DefaultPreferencesProvider implements IBDDLPreferenceProvider {
//  public new() {}
//  
//  override public BDDLPreferences getSettings() {
//      BDDLPreferences.defaultPrefs
//  }
//}
public class BDDLPreferences {
    static private final ConfigReader configReader = new ConfigReader("BDDL")
    static private final int maxFieldnameLengthDefault = configReader.getProp("MaxFieldLen", 30);
    static private final int maxTablenameLengthDefault = configReader.getProp("MaxTableLen", 27);
    static private final boolean doDebugOutDefault = configReader.getProp("DebugOut", false);
    static private final boolean doPostgresOutDefault = configReader.getProp("Postgres", true);
    static private final boolean doOracleOutDefault = configReader.getProp("Oracle", true);
    static private final boolean doMsSQLServerOutDefault = configReader.getProp("MSSQL", false);
    
    public int maxFieldnameLength = maxFieldnameLengthDefault
    public int maxTablenameLength = maxTablenameLengthDefault
    public boolean doDebugOut = doDebugOutDefault
    public boolean doPostgresOut = doPostgresOutDefault
    public boolean doOracleOut = doOracleOutDefault
    public boolean doMsSQLServerOut = doMsSQLServerOutDefault
    
    public static BDDLPreferences currentPrefs = new BDDLPreferences
}
