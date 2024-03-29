package de.jpaw.bonaparte.dsl

import de.jpaw.bonaparte.dsl.bonScript.XExternalizable
import de.jpaw.bonaparte.dsl.bonScript.XHazelcast
import org.eclipse.xtend.lib.annotations.Data
import org.apache.log4j.Logger

@Data
public class ConfigReader {
    private static final Logger LOGGER = Logger.getLogger(ConfigReader);
    String prefix;

    def String getProp(String name, String defaultValue) {
        var String result
        try {
            result = System.getProperty(prefix + "." + name)
            if (result !== null)
                return result
        } catch (Exception e) {
            LOGGER.error('''Exception «e» while accessing system property «prefix».«name»''')
        }
        try {
            result = System.getenv(prefix + "_" + name)
            LOGGER.debug('''Setting «prefix».«name» is «result ?: defaultValue»''')
        } catch (Exception e) {
            LOGGER.error('''Exception «e» while accessing environment variable «prefix»_«name»''')
        }
        return result ?: defaultValue
    }

    def boolean getProp(String name, boolean defaultValue) {
        return Boolean.valueOf(getProp(name, defaultValue.toString))
    }
    def int getProp(String name, int defaultValue) {
        return Integer.valueOf(getProp(name, defaultValue.toString))
    }
}

public class BonScriptPreferences {
    static private final ConfigReader configReader = new ConfigReader("bonaparte")
    static private final boolean warnByteDefault                = configReader.getProp("WarnByte", true);
    static private final boolean warnFloatDefault               = configReader.getProp("WarnFloat", false);
    static private final boolean doDebugOutDefault              = configReader.getProp("DebugOut", false);
    static private final boolean doDateTimeDefault              = configReader.getProp("DateTime", true);
    static private final boolean noXmlDefault                   = configReader.getProp("noXML", false);
    static private final boolean jakartaOutputDefault           = configReader.getProp("jakarta", true);  // use jakarta instead of javax
    static private final boolean defaultExternalizeDefault      = configReader.getProp("Externalize", false);
    static private final boolean defaultHazelcastDsDefault      = configReader.getProp("HazelcastDs", false);
    static private final boolean defaultHazelcastIdDefault      = configReader.getProp("HazelcastId", false);
    static private final boolean defaultHazelcastPoDefault      = configReader.getProp("HazelcastPo", false);
    static private final int defaulthazelcastFactoryIdDefault   = configReader.getProp("FactoryId", 26);

    static private final boolean defaultXsdDefault              = configReader.getProp("xsdDefault", false);
    static private final boolean defaultXsdRootSeparateFile     = configReader.getProp("xsdRootSeparateFile", true);
    static private final boolean defaultXsdBundleSubfolders     = configReader.getProp("xsdBundleSubfolders", false);
    static private final boolean defaultXsdExtensions           = configReader.getProp("xsdExtensions", false);

    public boolean warnByte                 = warnByteDefault;
    public boolean warnFloat                = warnFloatDefault;
    public boolean doDebugOut               = doDebugOutDefault;
    public boolean doDateTime               = doDateTimeDefault;
    public boolean noXML                    = noXmlDefault;
    public boolean jakartaOutput            = jakartaOutputDefault;
    public boolean defaultExternalize       = defaultExternalizeDefault;
    public boolean defaultHazelcastDs       = defaultHazelcastDsDefault;
    public boolean defaultHazelcastId       = defaultHazelcastIdDefault;
    public boolean defaultHazelcastPo       = defaultHazelcastPoDefault;
    public int defaulthazelcastFactoryId    = defaulthazelcastFactoryIdDefault;

    public boolean xsdDefault               = defaultXsdDefault;
    public boolean xsdRootSeparateFile      = defaultXsdRootSeparateFile;
    public boolean xsdBundleSubfolders      = defaultXsdBundleSubfolders;
    public boolean xsdExtensions            = defaultXsdExtensions;

    public static BonScriptPreferences currentPrefs = new BonScriptPreferences

    def public static String getDateTimePackage() {
        return if (currentPrefs.doDateTime) "java.time" else "org.joda.time"
    }
    def public static getHazelSupport() {
        if (currentPrefs.defaultHazelcastPo) {
            if (currentPrefs.defaultHazelcastId || currentPrefs.defaultHazelcastDs)
                return XHazelcast.BOTH
            else
                return XHazelcast.PORTABLE
        } else {
            if (currentPrefs.defaultHazelcastDs)
                return XHazelcast.IDENTIFIED_DATA_SERIALIZABLE
            else if (currentPrefs.defaultHazelcastId)
                return XHazelcast.DATA_SERIALIZABLE
            else
                return XHazelcast.NOHAZEL
        }
    }
    def public static getExternalizable() {
        if (currentPrefs.defaultExternalize)
            return XExternalizable.EXT
        else
            return XExternalizable.NOEXT
    }
    def public static getNoXML() {
        return currentPrefs.noXML
    }
}
