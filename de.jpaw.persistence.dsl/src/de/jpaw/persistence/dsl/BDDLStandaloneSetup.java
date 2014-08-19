
package de.jpaw.persistence.dsl;

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

