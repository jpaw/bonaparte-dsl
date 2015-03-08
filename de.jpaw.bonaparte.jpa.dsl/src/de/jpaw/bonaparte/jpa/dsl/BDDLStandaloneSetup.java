
package de.jpaw.bonaparte.jpa.dsl;

import de.jpaw.bonaparte.jpa.dsl.BDDLStandaloneSetupGenerated;

/**
 * Initialization support for running Xtext languages
 * without equinox extension registry
 */
public class BDDLStandaloneSetup extends BDDLStandaloneSetupGenerated{

    public static void doSetup() {
        // Injector inj =
        new BDDLStandaloneSetup().createInjectorAndDoEMFRegistration();
    }
}

