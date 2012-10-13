/*
 * generated by Xtext
 */
package de.jpaw.persistence.dsl.ui;

import org.eclipse.ui.plugin.AbstractUIPlugin;
import org.eclipse.xtext.ui.editor.syntaxcoloring.AbstractAntlrTokenToAttributeIdMapper;
import org.eclipse.xtext.ui.editor.syntaxcoloring.IHighlightingConfiguration;

import de.jpaw.bonaparte.dsl.ui.BonAntlrTokenToAttributeIdMapper;
import de.jpaw.bonaparte.dsl.ui.Highlighter;

/**
 * Use this class to register components to be used within the IDE.
 */
public class BDDLUiModule extends de.jpaw.persistence.dsl.ui.AbstractBDDLUiModule {
    public BDDLUiModule(AbstractUIPlugin plugin) {
        super(plugin);
    }
    
	public Class<? extends IHighlightingConfiguration> bindIHighlightingConfiguration() {
		return Highlighter.class;
	}

/*	// contributed by org.eclipse.xtext.generator.parser.antlr.XtextAntlrGeneratorFragment
	public Class<? extends org.eclipse.jface.text.rules.ITokenScanner> bindITokenScanner() {
		return AbstractTokenScanner.class;
	} */

	public Class<? extends AbstractAntlrTokenToAttributeIdMapper> bindAbstractAntlrTokenToAttributeIdMapper() {
		return BonAntlrTokenToAttributeIdMapper.class ;
	}
}
