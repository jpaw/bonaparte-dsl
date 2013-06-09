 /*
  * Copyright 2012,2013 Michael Bischoff
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

package de.jpaw.bonaparte.dsl.generator.java

import de.jpaw.bonaparte.dsl.bonScript.EnumDefinition

import static de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*

/* DISCLAIMER: Validation is work in progress. Neither direct validation nor JSR 303 annotations are complete */

class JavaEnum {
    val static final boolean codegenJava7 = false    // set to true to generate String switches for enum
    
    def static public writeEnumDefinition(EnumDefinition d) {
        var int counter = -1
        val isAlphaEnum = d.avalues != null && d.avalues.size() != 0
        return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git 
        package «getPackageName(d)»;
        
        import de.jpaw.util.EnumException;  // TODO change as soon as bonaparte-java-1.5.3 has been rolled out
        import de.jpaw.enums.TokenizableEnum;
        
        «IF d.javadoc != null»
            «d.javadoc»
        «ENDIF»        

        public enum «d.name» «IF isAlphaEnum»implements TokenizableEnum «ENDIF»{
            «IF !isAlphaEnum»
                «FOR v:d.values SEPARATOR ', '»«v»«ENDFOR»;
            «ELSE»
                «FOR v:d.avalues SEPARATOR ', '»«v.name»("«v.token»")«ENDFOR»;
                
                // constructor by token
                private String _token; 
                private «d.name»(String _token) {
                    this._token = _token;
                }

                // token retrieval
                @Override
                public String getToken() {
                    return _token;
                }
                
                // static factory method.«IF codegenJava7» Requires Java 7«ENDIF»
                public static «d.name» factory(String _token) throws EnumException {
                    if (_token != null) {
                        «IF codegenJava7»
                            switch (_token) {
                            «FOR v:d.avalues»
                                case "«v.token»": return «v.name»;  
                            «ENDFOR»
                            default: throw new EnumException(EnumException.INVALID_NUM, _token);
                            }
                        «ELSE»
                            «FOR v:d.avalues»
                                if (_token.equals("«v.token»")) return «v.name»;  
                            «ENDFOR»
                            throw new EnumException(EnumException.INVALID_NUM, _token);
                        «ENDIF»
                    }
                    return null;
                }
            «ENDIF»
                
            public static «d.name» valueOf(Integer ordinal) throws EnumException {
                if (ordinal != null) { 
                    switch (ordinal.intValue()) {
                    «IF d.avalues == null || d.avalues.size() == 0»
                        «FOR v:d.values»
                            case «Integer::valueOf(counter = counter + 1).toString()»: return «v»;  
                        «ENDFOR»
                    «ELSE»
                        «FOR v:d.avalues»
                            case «Integer::valueOf(counter = counter + 1).toString()»: return «v.name»;  
                        «ENDFOR»
                    «ENDIF»
                    default: throw new EnumException(EnumException.INVALID_NUM, ordinal.toString());
                    }
                }
                return null;
            }
        }
        '''
    }
}
