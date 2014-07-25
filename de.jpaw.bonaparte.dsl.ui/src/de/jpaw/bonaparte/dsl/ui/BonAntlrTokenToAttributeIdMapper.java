package de.jpaw.bonaparte.dsl.ui;

import org.eclipse.xtext.ui.editor.syntaxcoloring.DefaultAntlrTokenToAttributeIdMapper;

public class BonAntlrTokenToAttributeIdMapper extends DefaultAntlrTokenToAttributeIdMapper {

        @Override
        protected String calculateId(String tokenName, int tokenType) {
            if ("RULE_JAVADOC_COMMENT".equals(tokenName)) {
                return Highlighter.JAVADOC_COMMENT;
            }
            return super.calculateId(tokenName, tokenType);
        }
}
