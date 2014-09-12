package de.jpaw.bonaparte.jpa.dsl;

import org.eclipse.xtext.generator.scoping.AbstractScopingFragment;
import org.eclipse.xtext.scoping.IGlobalScopeProvider;
import org.eclipse.xtext.scoping.IScopeProvider;
import org.eclipse.xtext.scoping.impl.ImportUriGlobalScopeProvider;
// import org.eclipse.xtext.scoping.impl.ImportedNamespaceAwareLocalScopeProvider;


import de.jpaw.bonaparte.jpa.dsl.scoping.BDDLScopeProvider;

public class BDDLScopingFragment extends AbstractScopingFragment {

    @Override
    protected Class<? extends IGlobalScopeProvider> getGlobalScopeProvider() {
        return ImportUriGlobalScopeProvider.class;
    }

    @Override
    protected Class<? extends IScopeProvider> getLocalScopeProvider() {
        // return ImportedNamespaceAwareLocalScopeProvider.class;
        return BDDLScopeProvider.class;
    }

}
