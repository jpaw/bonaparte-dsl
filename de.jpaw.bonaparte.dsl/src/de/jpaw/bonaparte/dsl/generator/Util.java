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

import org.apache.commons.lang.StringEscapeUtils;
import org.apache.log4j.Logger;

public class Util {
    private static Logger logger = Logger.getLogger(Util.class);
    static private Boolean runningInEclipse = null; 
    
    static public boolean autodetectMavenRun() {
        if (runningInEclipse == null) {
            // allocate a Boolean and set it to true, if we detect an Eclipse environment variable
            if (System.getProperty("eclipse.vm") != null ||
                System.getProperty("eclipse.launcher") != null ||
                System.getProperty("eclipse.vmargs") != null) {
                runningInEclipse = Boolean.TRUE;
                logger.info("Found an eclipse system property - assuming we're within Eclipse");
            } else {
                runningInEclipse = Boolean.FALSE;
                logger.info("Found NO eclipse system property - assuming we're running from maven");
            }
        }
        return !runningInEclipse;
    }
    
    static public String escapeString2Java(String s) {
        return StringEscapeUtils.escapeJava(s);
    }

    // return false if the string contains a non-ASCII printable character, else true
    public static boolean isAsciiString(String s) {
        if (s != null) {
            for (int i = 0; i < s.length(); ++i) {
                int c = (int)s.charAt(i);
                if (c < 0x20 || c > 0x7f)
                    return false;
            }
        }
        return true;
    }

}
