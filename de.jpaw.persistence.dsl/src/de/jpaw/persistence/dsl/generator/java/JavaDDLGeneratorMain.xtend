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
import de.jpaw.bonaparte.dsl.generator.ImportCollector

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
        switch (ref.enumMaxTokenLength) {
        case DataTypeExtension::NO_ENUM:
            switch (ref.javaType) {
            case "GregorianCalendar":  writeTemporal(c, "TIMESTAMP")
            case "LocalDateTime":      writeTemporal(c, "TIMESTAMP")
            case "DateTime":           writeTemporal(c, "DATE")
            default:                   '''        
                «JavaDataTypeNoName(c, false)» «c.name»;
                '''
            }
        case DataTypeExtension::ENUM_NUMERIC: '''        
                Integer «c.name»;
            '''
        default: '''
                «IF ref.allTokensAscii»String«ELSE»Integer«ENDIF» «c.name»
            '''
        }
    }
    
    def private optionalVersionAnnotation(FieldDefinition c) {
        if (c.properties != null)
            for (p : c.properties)
                if (p.key.name.equals("version"))
                    return '''
                    @Version
                    '''
        return ''''''
    }
    
    def public recurseColumns(ClassDefinition cl, FieldDefinition pkColumn) '''
        «cl.extendsClass?.recurseColumns(pkColumn)»
        // table columns of java class «cl.name»
        «FOR c : cl.fields»
            «IF c == pkColumn»
                @Id
            «ENDIF»
            @Column(name="«YUtil::columnName(c)»")
            «optionalVersionAnnotation(c)»
            «writeColumnType(c)»
        «ENDFOR»
    '''

    def private writeGetter(FieldDefinition i) {
        val ref = DataTypeExtension::get(i.datatype);
        if (ref.enumMaxTokenLength == DataTypeExtension::NO_ENUM) {
            if (ref.javaType == null)
                return "return " + i.name + ";"
            if (ref.javaType.equals("LocalDate"))
                return "return LocalDate.fromCalendarFields(" + i.name + ");"
            else if (ref.javaType.equals("LocalDateTime"))
                return "return LocalDateTime.fromCalendarFields(" + i.name + ");"
            else
                return "return " + i.name + ";"
        } else if (ref.enumMaxTokenLength == DataTypeExtension::ENUM_NUMERIC || !ref.allTokensAscii) {
            return "return " + ref.elementaryDataType.enumType.name + ".valueOf(" + i.name + ");" 
        } else {
            return "try { return " + ref.elementaryDataType.enumType.name + ".factory(" + i.name + "); } catch (Exception e) { return null; }"
        }
    }
    def private writeSetter(FieldDefinition i) {
        val ref = DataTypeExtension::get(i.datatype);
        if (ref.enumMaxTokenLength == DataTypeExtension::NO_ENUM) {
            if (ref.javaType == null)
                return '''this.«i.name» = «i.name»;'''
            if (ref.javaType.equals("LocalDate") || ref.javaType.equals("LocalDateTime"))
                return '''this.«i.name» = DayTime.toGregorianCalendar(«i.name»);'''
            else
                return '''this.«i.name» = «i.name»;'''
        } else if (ref.enumMaxTokenLength == DataTypeExtension::ENUM_NUMERIC || !ref.allTokensAscii) {
            return '''this.«i.name» = «i.name».ordinal();''' 
        } else {
            return '''this.«i.name» = «i.name».getToken();'''
        }
    }
    
    def private writeGettersSetters(ClassDefinition d) '''
        «d.extendsClass?.writeGettersSetters»
        // auto-generated getters and setters of «d.name»
        «FOR i:d.fields»
            public «JavaDataTypeNoName(i, false)» get«Util::capInitial(i.name)»() «IF DataTypeExtension::get(i.datatype).enumMaxTokenLength != DataTypeExtension::NO_ENUM»throws EnumException «ENDIF»{
                «writeGetter(i)»
            }
            public void set«Util::capInitial(i.name)»(«JavaDataTypeNoName(i, false)» «i.name») {
                «writeSetter(i)»
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
    
    // same code as in JavaBonScriptGenerator...
    def private collectImports(ClassDefinition d, ImportCollector imports) {
        // collect all imports for this class (make sure we don't duplicate any)
        for (i : d.fields) {
            var ref = DataTypeExtension::get(i.datatype)
            // referenced objects
            if (ref.objectDataType != null)
                imports.addImport(getPackageName(ref.objectDataType), ref.objectDataType.name)
            // referenced enums
            if (ref.elementaryDataType != null && ref.elementaryDataType.name.toLowerCase().equals("enum"))
                imports.addImport(getPackageName(ref.elementaryDataType.enumType), ref.elementaryDataType.enumType.name)
        }
        // return parameters of specific methods 
        //recurseMethods(d, true)
        // finally, possibly the parent object
        if (d.extendsClass != null)
            imports.addImport(getPackageName(d.extendsClass), d.extendsClass.name)
    }
    
    def private javaEntityOut(EntityDefinition e) {
        val String myPackageName = getPackageName(e)
        val ImportCollector imports = new ImportCollector(myPackageName)
        e.tableCategory.trackingColumns?.collectImports(imports)
        e.pojoType.collectImports(imports)
        
        imports.addImport(myPackageName, e.name)  // add myself as well
        
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
        import javax.persistence.Version;
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
        «imports.createImports»
        
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