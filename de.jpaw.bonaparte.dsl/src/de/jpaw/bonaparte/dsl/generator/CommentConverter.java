package de.jpaw.bonaparte.dsl.generator;

import javax.inject.Inject;

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

    // a value converter for qualified IDs
    @ValueConverter(rule = "QualifiedId")
    public IValueConverter<String> FQN() {
        return mFQNValueConverter;
    }

    // a value converter for qualified IDs plus .* wildcard
    @ValueConverter(rule = "QualifiedIdWithWildcard")
    public IValueConverter<String> FQNwW() {
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
//
//public class QualifiedIdConverter extends DefaultTerminalConverters {
//    @ValueConverter(rule = "QualifiedId")
//    public IValueConverter<String> QualifiedId() {
//        return new AbstractToStringConverter<String>() {
//
//        }
//    }
//}
//
//public IValueConverter<Integer> ElementBound() {
//    return new IValueConverter<Integer>() {
//        public Integer toValue(String string, AbstractNode node) {
//            if (Strings.isEmpty(string))
//                throw new ValueConverterException("Couldn't convert empty string to int", node, null);
//            else if ("*".equals(string.trim()))
//                return -1;
//            try {
//                return Integer.parseInt(string);
//            } catch (NumberFormatException e) {
//                throw new ValueConverterException("Couldn't convert '"+string+"' to int", node, e);
//            }
//        }
