package de.jpaw.bonaparte.dsl.ui;

import org.eclipse.swt.SWT;
import org.eclipse.swt.graphics.RGB;
import org.eclipse.xtext.ui.editor.syntaxcoloring.DefaultHighlightingConfiguration;
import org.eclipse.xtext.ui.editor.syntaxcoloring.IHighlightingConfiguration;
import org.eclipse.xtext.ui.editor.syntaxcoloring.IHighlightingConfigurationAcceptor;
import org.eclipse.xtext.ui.editor.utils.TextStyle;

public class Highlighter extends DefaultHighlightingConfiguration implements IHighlightingConfiguration {
    protected static final String JAVADOC_COMMENT = "JAVADOC_COMMENT";
    private static final String JAVADOC_KEYWORD = "Javadoc";

    @Override
    public void configure(IHighlightingConfigurationAcceptor acceptor) {
        super.configure(acceptor);
        acceptor.acceptDefaultHighlighting(JAVADOC_COMMENT, JAVADOC_KEYWORD, JavadocTextStyle());
    }

    public TextStyle JavadocTextStyle() {
        TextStyle textStyle = new TextStyle();
        textStyle.setColor(new RGB(63,95,191));
        textStyle.setStyle(SWT.ITALIC);
        return textStyle;
    }
}
