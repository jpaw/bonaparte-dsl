/*
 * generated by Xtext
 */
package de.jpaw.bonaparte.dsl.ui;

import org.eclipse.ui.plugin.AbstractUIPlugin;
//import org.eclipse.xtext.common.types.xtext.AbstractTypeScopeProvider;
//import org.eclipse.xtext.common.types.xtext.ui.JdtBasedSimpleTypeScopeProvider;
import org.eclipse.xtext.ui.editor.syntaxcoloring.AbstractAntlrTokenToAttributeIdMapper;
import org.eclipse.xtext.ui.editor.syntaxcoloring.IHighlightingConfiguration;

import de.jpaw.bonaparte.dsl.ui.scoping.BonaparteGlobalScopeProvider;
//import org.eclipse.xtext.ui.editor.syntaxcoloring.AbstractTokenScanner;

/**
 * Customizations provided: Highlighting for Javadoc style comments.
 */
public class BonScriptUiModule extends de.jpaw.bonaparte.dsl.ui.AbstractBonScriptUiModule {
    public BonScriptUiModule(AbstractUIPlugin plugin) {
        super(plugin);
    }

    public Class<? extends org.eclipse.xtext.ui.editor.preferences.LanguageRootPreferencePage> bindLanguageRootPreferencePage() {
        return BonScriptConfiguration.class;
    }

    public Class<? extends IHighlightingConfiguration> bindIHighlightingConfiguration() {
        return Highlighter.class;
    }

/*  // contributed by org.eclipse.xtext.generator.parser.antlr.XtextAntlrGeneratorFragment
    public Class<? extends org.eclipse.jface.text.rules.ITokenScanner> bindITokenScanner() {
        return AbstractTokenScanner.class;
    } */

    public Class<? extends AbstractAntlrTokenToAttributeIdMapper> bindAbstractAntlrTokenToAttributeIdMapper() {
        return BonAntlrTokenToAttributeIdMapper.class ;
    }

    public Class<? extends org.eclipse.xtext.scoping.IGlobalScopeProvider> bindIGlobalScopeProvider() {
        return BonaparteGlobalScopeProvider.class;
    }

    // repeat it here because the src-gen code is recreated
    // contributed by org.eclipse.xtext.ui.generator.projectWizard.SimpleProjectWizardFragment
    public Class<? extends org.eclipse.xtext.ui.wizard.IProjectCreator> bindIProjectCreator() {
        return de.jpaw.bonaparte.dsl.ui.wizard.BonScriptProjectCreator.class;
    }

}
