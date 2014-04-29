package de.jpaw.bonaparte.dsl

@Data
public class ConfigReader {
	String prefix;
	
	def String getProp(String name, String defaultValue) {
		var String result
		try {
			result = System.getProperty(prefix + "." + name)
			if (result != null)
				return result
		} catch (Exception e) {
			System.out.println('''Exception «e» while accessing system property «prefix».«name»''')
		}
		try {
			result = System.getenv(prefix + "_" + name)
		} catch (Exception e) {
			System.out.println('''Exception «e» while accessing environment variable «prefix»_«name»''')
		}
		System.out.println('''Setting «prefix».«name» is «result ?: defaultValue»''')
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
	static private final boolean warnDateDefault = configReader.getProp("WarnDate", true);
	static private final boolean warnByteDefault = configReader.getProp("WarnByte", true);
	static private final boolean warnFloatDefault = configReader.getProp("WarnFloat", false);
	static private final boolean doDebugOutDefault = configReader.getProp("DebugOut", false);
	static private final boolean defaultExternalizeDefault = configReader.getProp("Externalize", false);


	public boolean warnDate = warnDateDefault;
	public boolean warnByte = warnByteDefault;
	public boolean warnFloat = warnFloatDefault;
	public boolean doDebugOut = doDebugOutDefault;
	public boolean defaultExternalize = defaultExternalizeDefault;
	
	public static BonScriptPreferences currentPrefs = new BonScriptPreferences
}
