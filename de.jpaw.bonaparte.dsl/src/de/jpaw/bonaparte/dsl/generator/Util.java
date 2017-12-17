 /*
  * Copyright 2012 Michael Bischoff
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
  * You may obtain a copy of the License at
  *
  *   http://www.apache.org/licenses/LICENSE-2.0
  *
  * Unless required by applicable law or agreed to in writing, software
  * distributed under the License is distributed on an "AS IS" BASIS,
  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  * See the License for the specific language governing permissions and
  * limitations under the License.
  */

package de.jpaw.bonaparte.dsl.generator;

public class Util {
    // we want to avoid extra dependencies in the poms of our users,
    // otherwise Apache commons text: StringEscapeUtils.escapeJava could also have been used (but that is 2 to 4 times slower...).
	private static final char [] HEX_DIGITS = "0123456789ABCDEF".toCharArray();
	
    static public String escapeString2Java(final String s) {
        if (!needsEscaping(s))
            return s;  // shortcut - avoid buffer allocation unless required
        final StringBuilder sb = new StringBuilder(s.length() * 2);  // rough estimate on size
        for (int i = 0; i < s.length(); ++i) {
            int c = 0xffff & s.charAt(i);
            if (c < 0x20) {
                switch (c) {
                case '\b':
                    sb.append('\\');
                    sb.append('b');
                    break;
                case '\t':
                    sb.append('\\');
                    sb.append('t');
                    break;
                case '\n':
                    sb.append('\\');
                    sb.append('n');
                    break;
                case '\f':
                    sb.append('\\');
                    sb.append('f');
                    break;
                case '\r':
                    sb.append('\\');
                    sb.append('r');
                    break;
                default:
//                    sb.append(String.format("\\%o", c));      // 1 or 2 octal digits
                    //sb.append(String.format("\\u%04x", c));        // 4 hex digits - Apache commons compatibility
                	appendHex(sb, c);
                    break;
                }
            } else if (c > 0x7e) {
                // Unicode escape
//                sb.append(String.format("\\u%04x", c));        // 4 hex digits
            	appendHex(sb, c);
            } else {
                // printable ASCII character
                switch (c) {
//                case '\'':  -- not done in Apache commons
                case '\"':
                case '\\':
                    sb.append('\\');
                    sb.append((char)c);
                    break;
                default:
                    sb.append((char)c);
                    break;
                }
            }
        }
        return sb.toString();
    }
    
    private static void appendHex(StringBuilder sb, int c) {
    	sb.append('\\');
    	sb.append('u');
    	sb.append(HEX_DIGITS[0xf & (c >> 12)]);
    	sb.append(HEX_DIGITS[0xf & (c >>  8)]);
    	sb.append(HEX_DIGITS[0xf & (c >>  4)]);
    	sb.append(HEX_DIGITS[0xf &  c]);
    }

    // return false if the string contains a non-ASCII printable character, else true
    private static boolean needsEscaping(final String s) {
        if (s != null) {
            for (int i = 0; i < s.length(); ++i) {
                int c = s.charAt(i);
                if (c < 0x20 || c > 0x7e)
                    return true;
                switch (c) {
                case '\'':
                case '\"':
                case '\\':
                    return true;
                }
            }
        }
        return false;
    }

    // return false if the string contains a non-ASCII printable character, else true
    public static boolean isAsciiString(String s) {
        if (s != null) {
            for (int i = 0; i < s.length(); ++i) {
                int c = s.charAt(i);
                if (c < 0x20 || c > 0x7e)
                    return false;
            }
        }
        return true;
    }

}
