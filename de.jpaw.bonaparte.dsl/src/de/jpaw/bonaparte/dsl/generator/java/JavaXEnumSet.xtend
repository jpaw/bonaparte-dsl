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

import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition
import de.jpaw.bonaparte.dsl.bonScript.XEnumSetDefinition

import static de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*

class JavaXEnumSet {

    def static writeXEnumSetDefinition(XEnumSetDefinition d) {
        val eName = d.myXEnum.name

        return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git
        package «getBonPackageName(d)»;

        import java.util.Iterator;
        import org.joda.time.Instant;

        import de.jpaw.enums.AbstractStringXEnumSet;
        import de.jpaw.bonaparte.enums.BonaStringEnumSet;
        import de.jpaw.bonaparte.core.MessageParser;
        import de.jpaw.bonaparte.pojos.meta.XEnumSetDataItem;
        import de.jpaw.bonaparte.pojos.meta.XEnumSetDefinition;

        «IF d.myXEnum.package !== d.package»
            import «getBonPackageName(d.myXEnum)».«eName»;
        «ENDIF»

        «IF d.javadoc !== null»
            «d.javadoc»
        «ENDIF»
        «IF d.isDeprecated || (d.eContainer as PackageDefinition).isDeprecated»
            @Deprecated
        «ENDIF»
        public final class «d.name» extends AbstractStringXEnumSet<«eName»> implements BonaStringEnumSet<«eName»> {
            private static final long serialVersionUID = «getSerialUID(d.myXEnum) * 37L»L;


            «d.writeXEnumSetMetaData»

            @Override
            public final int getMaxOrdinal() {
                return «eName».myFactory.size();
            }

            @Override
            public final Iterator<«eName»> iterator() {
                return new SetOfXEnumsIterator<«eName»>(getBitmap(), «eName».myFactory);
            }

            public «d.name»() {
                super();
            }

            public «d.name»(final String bitmap) {
                super(bitmap);
            }

            public static «d.name» ofTokens(final «eName»... args) {
                return new «d.name»(bitmapOf(args));
            }

            public static <E extends Exception> «d.name» unmarshal(XEnumSetDataItem _di, MessageParser<E> _p) throws E {
                String _bitmap = _p.readString4Xenumset(_di);
                return _bitmap == null ? null : new «d.name»(_bitmap);
            }

            @Override
            public «d.name» ret$MutableClone(boolean deepCopy, boolean unfreezeCollections) {
                return new «d.name»(getBitmap());
            }

            @Override
            public «d.name» ret$FrozenClone() {
                if (was$Frozen()) {
                    return this;
                } else {
                    «d.name» _new = new «d.name»(getBitmap());
                    _new.freeze();
                    return _new;
                }
            }
        }
    '''
    }

    def private static writeXEnumSetMetaData(XEnumSetDefinition d) {
        val myPackage = d.package

        return '''
            private static final String _PARTIALLY_QUALIFIED_CLASS_NAME = "«getPartiallyQualifiedClassName(d)»";
            private static final String _PARENT = null;
            private static final String _BUNDLE = «IF (myPackage.bundle !== null)»"«myPackage.bundle»"«ELSE»null«ENDIF»;

            // extended meta data (for the enhanced interface)
            private static final XEnumSetDefinition my$MetaData = new XEnumSetDefinition(
                «d.name».class,
                false,
                true,
                _PARTIALLY_QUALIFIED_CLASS_NAME,
                _PARENT,
                _BUNDLE,
                Instant.now(),
                null,
                // now specific xenumset items
                «d.myXEnum.name».xenum$MetaData()
            );

            // get all the meta data in one go
            static public XEnumSetDefinition xenumset$MetaData() {
                return my$MetaData;
            }

            «JavaMeta.writeCommonMetaData»
        '''
    }
}
