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

package de.jpaw.bonaparte.jpa.dsl.generator.java

import de.jpaw.bonaparte.jpa.dsl.bDDL.ConverterDefinition
import de.jpaw.bonaparte.dsl.generator.java.ImportCollector

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.jpa.dsl.generator.YUtil.*
import static extension de.jpaw.bonaparte.dsl.generator.java.JavaEnum.*

/** Create output for JPA 2.1 type converters. */
class Converters {
    
    def public static CharSequence writeTypeConverter(ConverterDefinition e) {
        val String myPackageName = e.bddlPackageName
        val ImportCollector imports = new ImportCollector(myPackageName)
        var dbType = "XXXX"
        var srcType = "YYY"
        var marshal = "toString()"      // full expression
        var unmarshal = "parse()" 
        var String m = null             // short form: auto-adds return obj == null ? null : $m;
        var String unm = null           // short form: auto-adds return col == null ? null : $unm;

        if (e.myEnum !== null) {
            val isAlphaEnum = e.myEnum.isAlphaEnum
            imports.addImport(e.myEnum)
            srcType = e.myEnum.name
            if (!isAlphaEnum) {
                dbType = "Integer"
                m = "obj.ordinal()"
                unmarshal = '''return «srcType».valueOf(col);''' 
            } else {
                dbType = "String"
                marshal = '''return «srcType».getTokenNWZ(obj);'''
                unmarshal = '''return «srcType».factoryNWZ(col);''' 
            }
        } else if (e.myXEnum !== null) {
            imports.addImport(e.myXEnum)
            dbType = "String"
            srcType = e.myXEnum.name
            marshal = '''return (obj == null || obj.getToken().length() == 0) ? null : obj.getToken();'''
            unm = '''«e.myXEnum.root.name».myFactory.getByTokenWithNull(col)'''
        } else if (e.myEnumset !== null) {
            imports.addImport(e.myEnumset)
            dbType = e.myEnumset.mapEnumSetIndex
            srcType = e.myEnumset.name
            m = "obj.getBitmap()"
            unm = '''new «srcType»(col)'''
        } else if (e.myXEnumset !== null) {
            imports.addImport(e.myXEnumset)
            dbType = "String"
            srcType = e.myXEnumset.name
            m = "obj.getBitmap()"
            unm = '''new «srcType»(col)'''
        } else if (e.myAdapter !== null) {
            val exceptionArg = if (e.myAdapter.exceptionConverter) ", de.jpaw.bonaparte.core.RuntimeExceptionConverter.INSTANCE"
            if (!e.myAdapter.useFqn)
                imports.addImport(e.myAdapter.externalType.qualifiedName)
            dbType = e.myAdapter.firstField.JavaDataTypeNoName(true)
            srcType = e.myAdapter.externalName
            m = '''«IF e.myAdapter.bonaparteAdapterClass !== null»«e.myAdapter.bonaparteAdapterClass».marshal(obj)«ELSE»obj.marshal()«ENDIF»'''
            unm = '''«e.myAdapter.adapterClassName».unmarshal(col«exceptionArg»)'''
        }
        
        return '''
            // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
            // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
            // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git
            package «myPackageName»;
            
            import javax.persistence.AttributeConverter;
            import javax.persistence.Converter;
            
            «imports.createImports»
            
            «e.javadoc»
            // @SuppressWarnings("all")
            «IF e.isDeprecated»
                @Deprecated
            «ENDIF»
            @Converter(autoApply=true)
            public class «e.name» implements AttributeConverter<«srcType»,«dbType»> {
                @Override
                public «dbType» convertToDatabaseColumn(«srcType» obj) {
                    «IF m !== null»
                        return obj == null ? null : «m»;
                    «ELSE»
                        «marshal»
                    «ENDIF»
                }
                
                @Override
                public «srcType» convertToEntityAttribute(«dbType» col) {
                    «IF unm !== null»
                        return col == null ? null : «unm»;
                    «ELSE»
                        «unmarshal»
                    «ENDIF»
                }
            }
        '''        
    }   
}