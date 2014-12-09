 /*
  * Copyright 2014 Michael Bischoff
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

import de.jpaw.bonaparte.dsl.bonScript.EnumSetDefinition

import static de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*

class JavaEnumSet {
    
    def static public writeEnumSetDefinition(EnumSetDefinition d) {
        val eName = d.myEnum.name
        val myPackage = getPackage(d)

        return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git
        package «getPackageName(d)»;
        
        import java.util.Iterator;
        import de.jpaw.enums.AbstractEnumSet;
        import de.jpaw.bonaparte.enums.BonaEnumSet;
        
        «IF d.myEnum.package !== d.package»
            import «getPackageName(d.myEnum)».«eName»;
        «ENDIF»
        
        «IF d.javadoc !== null»
            «d.javadoc»
        «ENDIF»
        «IF d.isDeprecated»
        @Deprecated
        «ENDIF»
        public final class «d.name» extends AbstractEnumSet<«eName»> implements BonaEnumSet<«eName»> {
            private static final long serialVersionUID = «getSerialUID(d.myEnum) * 37L»L;
            
            private static final «eName»[] VALUES = «eName».values();

            private static final int NUMBER_OF_INSTANCES = VALUES.length;
            private static final String _PARTIALLY_QUALIFIED_CLASS_NAME = "«getPartiallyQualifiedClassName(d)»";
            private static final String _PARENT = null;
            private static final String _BUNDLE = «IF (myPackage.bundle !== null)»"«myPackage.bundle»"«ELSE»null«ENDIF»;

            «JavaMeta.writeCommonMetaData»

            @Override
            public final int getMaxOrdinal() {
                return NUMBER_OF_INSTANCES;
            }

            @Override
            public final Iterator<«eName»> iterator() {
                return new SetOfEnumsIterator<«eName»>(VALUES, getBitmap());
            }

            public «d.name»() {
                super();
            }

            public «d.name»(final int bitmap) {
                super(bitmap);
            }

            public static «d.name» of(final «eName»... arg) {
                int val = 0;
                for (int i = 0; i < arg.length; ++i)
                    val |= 1 << arg[i].ordinal();
                return new «d.name»(val);
            }
        }
    '''    
    }
}