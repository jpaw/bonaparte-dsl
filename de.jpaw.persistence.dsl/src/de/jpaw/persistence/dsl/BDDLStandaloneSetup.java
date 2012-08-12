
package de.jpaw.persistence.dsl;

/**
 * Initialization support for running Xtext languages 
 * without equinox extension registry
 */
public class BDDLStandaloneSetup extends BDDLStandaloneSetupGenerated{

	public static void doSetup() {
		new BDDLStandaloneSetup().createInjectorAndDoEMFRegistration();
	}
}

