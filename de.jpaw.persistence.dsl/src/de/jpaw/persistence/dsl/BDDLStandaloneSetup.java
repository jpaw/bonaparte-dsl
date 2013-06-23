
package de.jpaw.persistence.dsl;

import de.jpaw.persistence.dsl.generator.BDDLGenerator;

/**
 * Initialization support for running Xtext languages
 * without equinox extension registry
 */
public class BDDLStandaloneSetup extends BDDLStandaloneSetupGenerated{

    public static void doSetup() {
        BDDLGenerator.activateFilter();    
        new BDDLStandaloneSetup().createInjectorAndDoEMFRegistration();
    }
}

