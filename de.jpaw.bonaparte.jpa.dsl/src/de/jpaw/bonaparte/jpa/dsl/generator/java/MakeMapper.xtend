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

package de.jpaw.bonaparte.jpa.dsl.generator.java

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.jpa.dsl.bDDL.EmbeddableUse
import java.util.List

import static de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*
import static de.jpaw.bonaparte.jpa.dsl.generator.YUtil.*
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*

class MakeMapper {
    def private static simpleGetter(FieldDefinition i, boolean setter) {
        if (!hasProperty(i.properties, PROP_NOJAVA)) {
            var getMe = '''get«i.name.toFirstUpper»()'''
            if (hasProperty(i.properties, PROP_SIMPLEREF))
                getMe = '''new «i.JavaDataTypeNoName(true)»(«getMe»)'''
            else if (hasProperty(i.properties, PROP_REF))
                return null
            if (setter)
                getMe = '''_r.set«i.name.toFirstUpper»(«getMe»);'''
            return getMe
        }
        return null
    }

    def private static List<String> recurseDataGetter(ClassDefinition cl, boolean setter) {
        return cl.allFields.map[simpleGetter(setter)].filterNull.toList
    }

    def private static returnAsType(ClassDefinition cl) '''
        «IF cl.immutable»
            return new «cl.name»(«cl.recurseDataGetter(false).join(', ')»);
        «ELSE»
            «cl.name» _r = new «cl.name»();
            «cl.recurseDataGetter(true).join('\n')»
            return _r;
         «ENDIF»
    '''

    def private static simpleSetter(String variable, ClassDefinition pojo, List<FieldDefinition> fieldsToIgnore) '''
        «FOR i:pojo.fields»
            «IF !hasProperty(i.properties, PROP_NOJAVA) && !inList(fieldsToIgnore, i)»
                «IF hasProperty(i.properties, PROP_SIMPLEREF)»
                    set«i.name.toFirstUpper»(«variable».get«i.name.toFirstUpper»().«i.properties.getProperty(PROP_SIMPLEREF)»);
                «ELSEIF !hasProperty(i.properties, PROP_REF)»
                    set«i.name.toFirstUpper»(«variable».get«i.name.toFirstUpper»());
                «ENDIF»
            «ENDIF»
        «ENDFOR»
    '''
    def private static CharSequence recurseDataSetter(ClassDefinition cl, List<FieldDefinition> fieldsToIgnore, List<EmbeddableUse> embeddables) '''
        «IF cl.extendsClass?.classRef !== null»
            «recurseDataSetter(cl.extendsClass?.classRef, fieldsToIgnore, embeddables)»
        «ENDIF»
        «simpleSetter("_d", cl, fieldsToIgnore)»
    '''


    def public static writeDataMapperMethods(ClassDefinition pojo, boolean isRootEntity, ClassDefinition rootPojo, List<EmbeddableUse> embeddables,
        List<FieldDefinition> fieldsNotToSet) '''
        @Override
        public String ret$DataPQON() {
            return "«getPartiallyQualifiedClassName(pojo)»";
        }
        @Override
        public Class<? extends «rootPojo.name»> ret$DataClass() {
            return «pojo.name».class;
        }
        «IF isRootEntity»
        public static Class<«pojo.name»> class$DataClass() {
            return «pojo.name».class;
        }
        public static String class$DataPQON() {
            return "«getPartiallyQualifiedClassName(pojo)»";
        }
        «ENDIF»
        @Override
        public «pojo.name» ret$Data() {
            «pojo.returnAsType»
        }
        @Override
        public void put$Data(«rootPojo.name» _d) {
            «IF isRootEntity»
                «recurseDataSetter(pojo, fieldsNotToSet, embeddables)»
            «ELSE»
                super.put$Data(_d);
                if (_d instanceof «pojo.name») {
                    «pojo.name» _dd = («pojo.name»)_d;
                    // auto-generated data setter for «pojo.name»
                    «simpleSetter("_dd", pojo, fieldsNotToSet)»
                }
            «ENDIF»
        }
    '''

    def public static writeTrackingMapperMethods(ClassDefinition pojo, String pojoname) '''
        public static Class<«pojoname»> class$TrackingClass() {
            «IF pojo === null»
                return null;
            «ELSE»
                return «pojoname».class;
            «ENDIF»
        }
        @Override
        public String ret$TrackingPQON() {
            «IF pojo === null»
                return null;
            «ELSE»
                return "«getPartiallyQualifiedClassName(pojo)»";
            «ENDIF»
        }
        @Override
        public Class<«pojoname»> ret$TrackingClass() {
            «IF pojo === null»
                return null;
            «ELSE»
                return «pojoname».class;
            «ENDIF»
        }

        @Override
        public «pojoname» ret$Tracking() {
            «IF pojo === null»
                return null;
            «ELSE»
                «pojo.returnAsType»
            «ENDIF»
        }
        @Override
        public void put$Tracking(«pojoname» _d) {
            «IF pojo !== null»
                «recurseDataSetter(pojo, null, null)»
            «ENDIF»
        }
    '''
}
