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

package de.jpaw.bonaparte.dsl.generator.java

import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.XVisibility
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import de.jpaw.bonaparte.dsl.generator.Util

class JavaMeta {
    
    def private static makeMeta(ClassDefinition d, FieldDefinition i) {
        var ref = DataTypeExtension::get(i.datatype)
        var initDataForFieldDefinition = (if (ref.visibility == null) XVisibility::DEFAULT else ref.visibility)
            + ", " + i.isRequired
            + ", " + i.name
            + ", " + (if (i.isArray != null) "true, " + i.isArray.maxcount else "false, null")
        return "null"  // WIP
    }
    
    def public static writeMetaData(ClassDefinition d) {
        var int cnt2 = -1
        var myPackage = d.eContainer as PackageDefinition
        return '''
            // my name and revision
            private static final String PARTIALLY_QUALIFIED_CLASS_NAME = "«getPartiallyQualifiedClassName(d)»";
            private static final String REVISION = «IF d.revision != null && d.revision.length > 0»"«d.revision»"«ELSE»null«ENDIF»;
            private static final String PARENT = «IF (d.extendsClass != null)»"«getPartiallyQualifiedClassName(d.extendsClass)»"«ELSE»null«ENDIF»; 
            private static final String BUNDLE = «IF (myPackage.bundle != null)»"«myPackage.bundle»"«ELSE»null«ENDIF»; 

            // extended meta data (for the enhanced interface)
            private static final ClassDefinition my$MetaData = new ClassDefinition();
            static {
                my$MetaData.setIsAbstract(«d.isAbstract»); 
                my$MetaData.setIsFinal(«d.isFinal»);
                my$MetaData.setName(PARTIALLY_QUALIFIED_CLASS_NAME); 
                my$MetaData.setRevision(REVISION); 
                my$MetaData.setParent(PARENT);
                my$MetaData.setBundle(BUNDLE);
                my$MetaData.setSerialUID(serialVersionUID); 
                my$MetaData.setNumberOfFields(«d.fields.size»);
                FieldDefinition [] field$array = new FieldDefinition[«d.fields.size»];
                «FOR i:d.fields»
                    field$array[«(cnt2 = cnt2 + 1)»] = «makeMeta(d, i)»;
                «ENDFOR»
                my$MetaData.setFields(field$array);
                my$MetaData.setWhenLoaded(«IF Util::useJoda()»new LocalDateTime()«ELSE»DayTime.getCurrentTimestamp()«ENDIF»);
            };

            // get all the meta data in one go
            static public ClassDefinition class$MetaData() {
                return my$MetaData;
            }
            
            // some methods intentionally use the $ sign, because use in normal code is discouraged, so we expect
            // no namespace conflicts here
            // must be repeated as a member method to make it available in the (extended) interface 
            // feature of extended BonaPortable, not in the core interface
            @Override
            public ClassDefinition get$MetaData() {
                return my$MetaData;
            }
            
            // convenience functions for faster access if the metadata structure is not used
            @Override
            public String get$PQON() {
                return PARTIALLY_QUALIFIED_CLASS_NAME;
            }
            @Override
            public String get$Revision() {
                return REVISION;
            }
            @Override
            public String get$Parent() {
                return PARENT;
            }
            @Override
            public String get$Bundle() {
                return BUNDLE;
            }
    '''
    }
}