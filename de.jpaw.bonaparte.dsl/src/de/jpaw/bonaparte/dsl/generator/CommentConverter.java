package de.jpaw.bonaparte.dsl.generator;

import org.eclipse.xtext.common.services.DefaultTerminalConverters;
import org.eclipse.xtext.conversion.IValueConverter;
import org.eclipse.xtext.conversion.ValueConverter;
import org.eclipse.xtext.conversion.ValueConverterException;
import org.eclipse.xtext.conversion.impl.AbstractToStringConverter;
import org.eclipse.xtext.conversion.impl.QualifiedNameValueConverter;
import org.eclipse.xtext.nodemodel.INode;

public class CommentConverter extends DefaultTerminalConverters {
	@ValueConverter(rule = "SL_COMMENT")
	public IValueConverter<String> SL_COMMENT() {
		return new AbstractToStringConverter<String>() {

			@Override
            protected String internalToValue(String string, INode node) throws ValueConverterException {
				final String START_SEQUENCE = "//";

				if (string.startsWith(START_SEQUENCE)) {
					string = string.substring(START_SEQUENCE.length()).trim();
				}
				int end = -1;
				if ((end = string.indexOf('\r')) < 0)
					end = string.indexOf('\n');
				if (end >= 0)
					string = string.substring(0, end).trim();
				return string;
            }
		};
	}

    @Inject QualifiedNameValueConverter mFQNValueConverter;
    
    @ValueConverter(rule = "QualifiedId")
    public IValueConverter<String> FQN() {
        return mFQNValueConverter;
    }
 
/*
	@Override
    public Object toValue(String string, String lexerRule, INode node) throws ValueConverterException {
	    // TODO Auto-generated method stub
	    return "toValue";
    }

	@Override
    public String toString(Object value, String lexerRule) {
	    // TODO Auto-generated method stub
	    return "toString";
    }
*/
}
