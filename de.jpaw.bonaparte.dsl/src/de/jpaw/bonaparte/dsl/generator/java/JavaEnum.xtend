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
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import de.jpaw.bonaparte.dsl.BonScriptPreferences

class JavaEnum {
    val static final boolean codegenJava7 = false    // set to true to generate String switches for enum

    def static public boolean hasNullToken(EnumDefinition ed) {
        ed.avalues !== null && ed.avalues.exists[token == ""]
    }
    def static public nameForNullToken(EnumDefinition ed) {
        if (ed.avalues !== null)
            return ed.avalues.findFirst[token.empty]?.name
    }
    def static public boolean isAlphaEnum(EnumDefinition d) {
        d.avalues !== null && !d.avalues.empty
    }
    def static public writeEnumDefinition(EnumDefinition d) {
        var int counter = -1
        val isAlphaEnum = d.isAlphaEnum
        val isSpecialAlpha = isAlphaEnum && d.avalues.exists[token == ""]
        val myInterface = if (isAlphaEnum) "BonaTokenizableEnum" else "BonaNonTokenizableEnum"
        return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git
        package «getBonPackageName(d)»;

        import com.google.common.collect.ImmutableList;
        import «BonScriptPreferences.getDateTimePackage».Instant;

        import de.jpaw.bonaparte.pojos.meta.EnumDefinition;
        import de.jpaw.bonaparte.enums.«myInterface»;

        «d.javadoc»
        «IF d.isDeprecated»
            @Deprecated
        «ENDIF»
        public enum «d.name» implements «myInterface» {
            «IF !isAlphaEnum»
                «FOR v:d.values SEPARATOR ', '»«v»«ENDFOR»;
            «ELSE»
                «FOR v:d.avalues SEPARATOR ', '»«v.name»("«v.token»")«ENDFOR»;

                private final String _token;

                /** Constructs an enum by its token. */
                private «d.name»(String _token) {
                    this._token = _token;
                }

                /** Retrieves the token for a given instance. Never returns null. */
                @Override
                public String getToken() {
                    return _token;
                }

                /** static factory method«IF codegenJava7» (requires Java 7)«ENDIF».
                  * Null is passed through, a non-null parameter will return a non-null response. */
                public static «d.name» factory(String _token) {
                    if (_token != null) {
                        «IF codegenJava7»
                            switch (_token) {
                            «FOR v:d.avalues»
                                case "«v.token»": return «v.name»;
                            «ENDFOR»
                            default: throw new IllegalArgumentException("Enum «d.name» has no token " + _token + "!");
                            }
                        «ELSE»
                            «FOR v:d.avalues»
                                if (_token.equals("«v.token»")) return «v.name»;
                            «ENDFOR»
                            throw new IllegalArgumentException("Enum «d.name» has no token " + _token + "!");
                        «ENDIF»
                    }
                    return null;
                }

                // static method to return the instance with the null token, or null if no such exists
                public static «d.name» getNullToken() {
                    return «d.avalues.findFirst[token == ""]?.name ?: "null"»;
                }

                /** Same as factory(), but returns the special enum instance with a tokens of zero length (in case such a token exists) for null. */
                public static «d.name» factoryNWZ(String _token) {
                    return «IF isSpecialAlpha»_token == null ? «d.avalues.findFirst[token == ""].name» : «ENDIF»factory(_token);
                }

                /** Retrieves the token for a given instance. Returns null for the zero length token. */
                public static String getTokenNWZ(«d.name» _obj) {
                    return _obj == null«IF isSpecialAlpha» || _obj == «d.avalues.findFirst[token == ""].name»«ENDIF» ? null : _obj.getToken();
                }
            «ENDIF»

            private static final long serialVersionUID = «getSerialUID(d)»L;

            «d.writeEnumMetaData»

            /** Returns the enum instance which has the ordinal as specified by the parameter. Returns null for a null parameter.
              * valueOf by default only exists for String type parameters for enums. */
            public static «d.name» valueOf(Integer ordinal) {
                if (ordinal != null) {
                    switch (ordinal.intValue()) {
                    «IF d.avalues === null || d.avalues.size() == 0»
                        «FOR v:d.values»
                            case «Integer::valueOf(counter = counter + 1).toString()»: return «v»;
                        «ENDFOR»
                    «ELSE»
                        «FOR v:d.avalues»
                            case «Integer::valueOf(counter = counter + 1).toString()»: return «v.name»;
                        «ENDFOR»
                    «ENDIF»
                    default: throw new IllegalArgumentException("Enum «d.name» has no instance for ordinal " + ordinal.toString());
                    }
                }
                return null;
            }
        }
        '''
    }

    def private static writeEnumMetaData(EnumDefinition d) {
        val isAlphaEnum = d.isAlphaEnum
        val myPackage = d.package
        return '''
            private static final String _PARTIALLY_QUALIFIED_CLASS_NAME = "«getPartiallyQualifiedClassName(d)»";
            private static final String _PARENT = null;
            private static final String _BUNDLE = «IF (myPackage.bundle !== null)»"«myPackage.bundle»"«ELSE»null«ENDIF»;

            private static final ImmutableList<String> _ids = new ImmutableList.Builder<String>()
                «IF !isAlphaEnum»
                    «FOR id: d.values»
                        .add("«id»")
                    «ENDFOR»
                «ELSE»
                    «FOR id: d.avalues»
                        .add("«id.name»")
                    «ENDFOR»
                «ENDIF»
               .build();
            «IF isAlphaEnum»
                private static final ImmutableList<String> _tokens = new ImmutableList.Builder<String>()
                    «FOR id: d.avalues»
                        .add("«id.token»")
                    «ENDFOR»
                    .build();
            «ENDIF»

            // extended meta data (for the enhanced interface)
            private static final EnumDefinition my$MetaData = new EnumDefinition(
                «d.name».class,
                false,
                true,
                _PARTIALLY_QUALIFIED_CLASS_NAME,
                _PARENT,
                _BUNDLE,
                Instant.now(),
                null,
                // now specific enum items
                «IF isAlphaEnum»
                    «JavaXEnum.getInternalMaxLength(d, 0)»,
                    «d.hasNullToken»,
                    _ids,
                    _tokens
                «ELSE»
                    -1,
                    false,
                    _ids,
                    null
                «ENDIF»
            );

            // get all the meta data in one go
            static public EnumDefinition enum$MetaData() {
                return my$MetaData;
            }

            «JavaMeta.writeCommonMetaData»
        '''
    }
}
