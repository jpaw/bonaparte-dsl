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

package de.jpaw.persistence.dsl.generator.java

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IGenerator
import org.eclipse.xtext.generator.IFileSystemAccess
import de.jpaw.persistence.dsl.bDDL.EntityDefinition
import de.jpaw.bonaparte.dsl.generator.Util
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.dsl.generator.JavaPackages.*
//import static extension de.jpaw.bonaparte.dsl.generator.java.JavaFieldsGettersSetters.*
//import static extension de.jpaw.persistence.dsl.generator.java.JavaFieldsGettersSetters.*
import de.jpaw.persistence.dsl.bDDL.PackageDefinition
import de.jpaw.persistence.dsl.generator.YUtil
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension

class JavaDDLGeneratorMain implements IGenerator {
    // create the filename to store a generated java class source in. Assumes subdirectory ./java
    def private static getJavaFilename(String pkg, String name) {
        return "java/" + pkg.replaceAll("\\.", "/") + "/" + name + ".java"
    }
    def public static getPackageName(PackageDefinition p) {
        (if (p.prefix == null) bonaparteClassDefaultPackagePrefix else p.prefix) + "." + p.name  
    }
    
    // create the package name for a class definition object
    def public static getPackageName(EntityDefinition d) {
        getPackageName(d.eContainer as PackageDefinition)
    }
    // create the filename to store the JAXB index in
    def private static getJaxbResourceFilename(String pkg) {
        return "resources/" + pkg.replaceAll("\\.", "/") + "/jaxb.index"
    }    

    override void doGenerate(Resource resource, IFileSystemAccess fsa) {
        // java
        for (e : resource.allContents.toIterable.filter(typeof(EntityDefinition))) {
            fsa.generateFile(getJavaFilename(getPackageName(e), e.name), e.javaEntityOut)
        }
    }
    
    def private writeTemporal(FieldDefinition c, String type) '''
        @Temporal(TemporalType.«type»)
        «IF c.isArray != null»
            GregorianCalendar[] «c.name»;
        «ELSEIF c.isList != null»
            List <GregorianCalendar> «c.name»;
        «ELSE»
            GregorianCalendar «c.name»;
        «ENDIF»
    '''
    
    def private writeColumnType(FieldDefinition c) {
        val DataTypeExtension ref = DataTypeExtension::get(c.datatype)
        switch (ref.javaType) {
        case "GregorianCalendar":  writeTemporal(c, "TIMESTAMP")
        case "LocalDateTime":      writeTemporal(c, "TIMESTAMP")
        case "DateTime":           writeTemporal(c, "DATE")
        default:                   '''        
            «JavaDataTypeNoName(c, false)» «c.name»;
            '''
        }
    }
    
    def public recurseColumns(ClassDefinition cl, FieldDefinition pkColumn) '''
        «cl.extendsClass?.recurseColumns(pkColumn)»
        // table columns of java class «cl.name»
        «FOR c : cl.fields»
            «IF c == pkColumn»
                @Id
            «ENDIF»
            @Column(name="«YUtil::columnName(c)»")
            «writeColumnType(c)»
        «ENDFOR»
    '''

    def private writeGettersSetters(ClassDefinition d) '''
        // auto-generated getters and setters 
        «FOR i:d.fields»
            public «JavaDataTypeNoName(i, false)» get«Util::capInitial(i.name)»() {
                «IF DataTypeExtension::get(i.datatype).javaType.equals("LocalDate")»
                    return LocalDate.fromCalendarFields(«i.name»);
                «ELSEIF DataTypeExtension::get(i.datatype).javaType.equals("LocalDateTime")»
                    return LocalDateTime.fromCalendarFields(«i.name»);
                «ELSE»
                    return «i.name»;
                «ENDIF»
            }
            public void set«Util::capInitial(i.name)»(«JavaDataTypeNoName(i, false)» «i.name») {
                «IF DataTypeExtension::get(i.datatype).javaType.equals("LocalDate")»
                    this.«i.name» = DayTime.toGregorianCalendar(«i.name»);
                «ELSEIF DataTypeExtension::get(i.datatype).javaType.equals("LocalDateTime")»
                    this.«i.name» = DayTime.toGregorianCalendar(«i.name»);
                «ELSE»
                    this.«i.name» = «i.name»;
                «ENDIF»
            }
        «ENDFOR»
    '''
       
    def private scaledExpiry(int number, String unit) {
        if (unit.startsWith("minute"))
            return number * 60
        else if (unit.startsWith("hour"))
            return number * 3600
        else if (unit.startsWith("day"))
            return number * 86400
        else
            return number
    }     
    
    def private javaEntityOut(EntityDefinition e) {
        var FieldDefinition pkColumn = null
        if (e.pk != null && e.pk.columnName.size == 1)
            pkColumn = e.pk.columnName.get(0)
        return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git 
        package «getPackageName(e)»;
        
        «IF e.tenantId != null»
        //import javax.persistence.Multitenant;  // not (yet?) there. Should be in JPA 2.1
        import org.eclipse.persistence.annotations.Multitenant;  // BAD! O-R mapper specific TODO: FIXME
        «ENDIF»
        «IF e.cacheSize != 0»
        import org.eclipse.persistence.annotations.Cache;  // BAD! O-R mapper specific TODO: FIXME
        «ENDIF»
        import javax.persistence.Entity;
        import javax.persistence.Table;
        import javax.persistence.Column;
        import javax.persistence.Id;
        import javax.persistence.Temporal;
        import javax.persistence.TemporalType;
        import java.util.Arrays;
        import java.util.List;
        import java.util.ArrayList;
        import java.util.regex.Pattern;
        import java.util.regex.Matcher;
        import java.util.GregorianCalendar;
        import java.util.UUID;
        import java.math.BigDecimal;
        import de.jpaw.util.ByteArray;
        import de.jpaw.util.CharTestsASCII;
        import de.jpaw.util.EnumException;
        import de.jpaw.util.DayTime;
        «IF Util::useJoda()»
        import org.joda.time.LocalDate;
        import org.joda.time.LocalDateTime;
        «ENDIF»
        
        @Entity
        «IF e.cacheSize != 0»
        @Cache(size=«e.cacheSize», expiry=«scaledExpiry(e.cacheExpiry, e.cacheExpiryScale)»000)
        «ENDIF»
        @Table(name="«YUtil::mkTablename(e, false)»")
        «IF e.tenantId != null»
        @Multitenant(/* SINGLE_TABLE */)
        «ENDIF»
        public class «e.name» {
            «e.tableCategory.trackingColumns?.recurseColumns(pkColumn)»
            «e.pojoType.recurseColumns(pkColumn)»
            «e.tableCategory.trackingColumns?.writeGettersSetters»
            «e.pojoType.writeGettersSetters()»
        }
        '''
    }
}