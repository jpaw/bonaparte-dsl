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
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition

import static de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*

class JavaEnumSet {

    def static writeEnumSetDefinition(EnumSetDefinition d) {
        val eName = d.myEnum.name
        val bitmapType = d.indexType ?: "int"       // default to int
        val bitmapTypeWrapper = d.mapEnumSetIndex
        val nameComponent = bitmapType.toFirstUpper
        val diType = if (nameComponent == "String") "AlphanumericEnumSetDataItem" else "NumericEnumSetDataItem";

//        val nullTest = if (d.nullWhenEmpty) ''' || _es.isEmpty()'''
//        val nullObject = if (d.nullWhenEmpty) '''new «d.name»(«IF bitmapType == "String"»""«ELSE»0«ENDIF»)''' else '''null'''

        return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git
        package «getBonPackageName(d)»;

        import java.util.Iterator;
        import org.joda.time.Instant;

        import de.jpaw.enums.Abstract«nameComponent»EnumSet;
        import de.jpaw.bonaparte.enums.Bona«nameComponent»EnumSet;
        import de.jpaw.bonaparte.core.MessageParser;
        import de.jpaw.bonaparte.pojos.meta.EnumSetDefinition;
        import de.jpaw.bonaparte.pojos.meta.IndexType;
        import de.jpaw.bonaparte.pojos.meta.«diType»;

        «IF d.myEnum.package !== d.package»
            import «getBonPackageName(d.myEnum)».«eName»;
        «ENDIF»

        «IF d.javadoc !== null»
            «d.javadoc»
        «ENDIF»
        «IF d.isDeprecated || (d.eContainer as PackageDefinition).isDeprecated»
            @Deprecated
        «ENDIF»
        public final class «d.name» extends Abstract«nameComponent»EnumSet<«eName»> implements Bona«nameComponent»EnumSet<«eName»> {
            private static final long serialVersionUID = «getSerialUID(d.myEnum) * 37L»L;

            private static final «eName»[] VALUES = «eName».values();
            private static final int NUMBER_OF_INSTANCES = VALUES.length;

            «d.writeEnumSetMetaData(bitmapTypeWrapper)»

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

            public «d.name»(final «bitmapType» bitmap) {
                super(bitmap);
            }

            public static «d.name» ofTokens(final «eName»... args) {
                return new «d.name»(bitmapOf(args));
            }

            // add code for a singleField adapter (was used for enum serialization, now done by message composers
            //public «bitmapType» marshal() {
            //    return getBitmap();
            //}

            // factory used by message parsers
            public static <E extends Exception> «d.name» unmarshal(«diType» _di, MessageParser<E> _p) throws E {
                «bitmapTypeWrapper» _bitmap = _p.read«bitmapTypeWrapper»4EnumSet(_di);
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

    def private static writeEnumSetMetaData(EnumSetDefinition d, String indexType) {
        val myPackage = d.package

        return '''
            private static final String _PARTIALLY_QUALIFIED_CLASS_NAME = "«getPartiallyQualifiedClassName(d)»";
            private static final String _PARENT = null;
            private static final String _BUNDLE = «IF (myPackage.bundle !== null)»"«myPackage.bundle»"«ELSE»null«ENDIF»;

            // extended meta data (for the enhanced interface)
            private static final EnumSetDefinition my$MetaData = new EnumSetDefinition(
                «d.name».class,
                false,
                true,
                _PARTIALLY_QUALIFIED_CLASS_NAME,
                _PARENT,
                _BUNDLE,
                Instant.now(),
                null,
                // now specific enumset items
                IndexType.«indexType.toUpperCase»,
                «d.myEnum.name».enum$MetaData()
            );

            // get all the meta data in one go
            static public EnumSetDefinition enumset$MetaData() {
                return my$MetaData;
            }

            «JavaMeta.writeCommonMetaData»
        '''
    }
}
