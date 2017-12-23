/*
 * generated by Xtext 2.13.0
 */
package de.jpaw.bonaparte.jpa.dsl.ui

import de.jpaw.bonaparte.dsl.ui.BonAntlrTokenToAttributeIdMapper
import de.jpaw.bonaparte.dsl.ui.Highlighter
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtext.ui.editor.preferences.LanguageRootPreferencePage
import org.eclipse.xtext.ui.editor.syntaxcoloring.AbstractAntlrTokenToAttributeIdMapper
import org.eclipse.xtext.ui.editor.syntaxcoloring.IHighlightingConfiguration

/**
 * Use this class to register components to be used within the Eclipse IDE.
 */
@FinalFieldsConstructor
class BDDLUiModule extends AbstractBDDLUiModule {
    def Class<? extends LanguageRootPreferencePage> bindLanguageRootPreferencePage() {
        return BDDLConfiguration;
    }
    def Class<? extends IHighlightingConfiguration> bindIHighlightingConfiguration() {
        return Highlighter;
    }
    def Class<? extends AbstractAntlrTokenToAttributeIdMapper> bindAbstractAntlrTokenToAttributeIdMapper() {
        return BonAntlrTokenToAttributeIdMapper;
    }
}
