
package de.jpaw.bonaparte.dsl;

/**
 * Initialization support for running Xtext languages
 * without equinox extension registry
 */
public class BonScriptStandaloneSetup extends BonScriptStandaloneSetupGenerated{

    public static void doSetup() {
        new BonScriptStandaloneSetup().createInjectorAndDoEMFRegistration();
    }
}

