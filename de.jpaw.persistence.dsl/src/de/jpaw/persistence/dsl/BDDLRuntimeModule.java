/*
 * generated by Xtext
 */
package de.jpaw.persistence.dsl;

// import org.eclipse.xtext.scoping.impl.ImportUriGlobalScopeProvider;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;

import de.jpaw.persistence.dsl.scoping.BDDLScopeProvider;

/**
 * Use this class to register components to be used at runtime / without the Equinox extension registry.
 */
public class BDDLRuntimeModule extends de.jpaw.persistence.dsl.AbstractBDDLRuntimeModule {
    private static Log logger = LogFactory.getLog("de.jpaw.persistence.dsl.BDDLRuntimeModule"); // jcl
    public BDDLRuntimeModule() {
        logger.info("BDDL Runtime module constructed");
    }
    
    // must bind my subclass of ImportedNamespaceAwareScopeProvider here!
    // for implicit importedNamespace
    @Override
    public Class<? extends org.eclipse.xtext.scoping.IScopeProvider> bindIScopeProvider() {
        logger.info("BDDL Value converter bound");
        return BDDLScopeProvider.class;
    }

    // bind global scope provider for importURI
    /*
    @Override
    public Class<? extends org.eclipse.xtext.scoping.IGlobalScopeProvider> bindIGlobalScopeProvider() {
        return ImportUriGlobalScopeProvider.class;
    } */
}
