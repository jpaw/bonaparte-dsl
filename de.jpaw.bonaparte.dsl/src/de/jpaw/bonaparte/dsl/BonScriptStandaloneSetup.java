
package de.jpaw.bonaparte.dsl;

import de.jpaw.bonaparte.dsl.generator.BonScriptGenerator;

/**
 * Initialization support for running Xtext languages
 * without equinox extension registry
 */
public class BonScriptStandaloneSetup extends BonScriptStandaloneSetupGenerated{

    public static void doSetup() {
        BonScriptGenerator.activateFilter();
        new BonScriptStandaloneSetup().createInjectorAndDoEMFRegistration();
    }
}

