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
import de.jpaw.bonaparte.dsl.generator.DataCategory
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.dsl.generator.JavaPackages.*
import static extension de.jpaw.bonaparte.dsl.generator.java.JavaRtti.*
import static extension de.jpaw.persistence.dsl.generator.YUtil.*
import de.jpaw.persistence.dsl.bDDL.PackageDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.ImportCollector
import de.jpaw.bonaparte.dsl.bonScript.PropertyUse
import java.util.List

class JavaDDLGeneratorMain implements IGenerator {
    val String JAVA_OBJECT_TYPE = "BonaPortable";
    var FieldDefinition haveIntVersion = null
    var haveActive = false
    
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
            var boolean compositeKey = false;
            if (e.pk != null && e.pk.columnName.size > 1) {
                // write a separate class for the composite key
                fsa.generateFile(getJavaFilename(getPackageName(e), e.name + "Key"), e.javaKeyOut)
                compositeKey = true
            }
            fsa.generateFile(getJavaFilename(getPackageName(e), e.name), e.javaEntityOut(compositeKey))
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
            case "GregorianCalendar":   writeTemporal(c, "TIMESTAMP")
            case "LocalDateTime":       writeTemporal(c, "TIMESTAMP")
            case "DateTime":            writeTemporal(c, "DATE")
            case "ByteArray":           '''byte [] «c.name»;'''
            case JAVA_OBJECT_TYPE:      '''
                    @Lob
                    byte [] «c.name»;
                '''
            default:                   '''        
                «JavaDataTypeNoName(c, false)» «c.name»;
                '''
            }
        case DataTypeExtension::ENUM_NUMERIC: '''        
                Integer «c.name»;
            '''
        default: '''
                «IF ref.allTokensAscii»String«ELSE»Integer«ENDIF» «c.name»;
            '''
        }
    }
    
  
    def private optionalAnnotation(List <PropertyUse> properties, String key, String annotation) {
        '''«IF hasProperty(properties, key)»«annotation»«ENDIF»'''
    }
    
    def private setIntVersion(FieldDefinition c) {
        haveIntVersion = c
        return ""
    }
    def private setHaveActive() {
        haveActive = true
        return ""
    }
    
    // write the definition of a single column
    def private singleColumn(FieldDefinition c) '''
            @Column(name="«columnName(c)»"«IF hasProperty(c.properties, "noinsert")», insertable=false«ENDIF»«IF hasProperty(c.properties, "noupdate")», updatable=false«ENDIF»)
            «optionalAnnotation(c.properties, "version", "@Version")»
            «optionalAnnotation(c.properties, "lob",     "@Lob")»
            «optionalAnnotation(c.properties, "lazy",    "@Basic(fetch=LAZY)")»
            «writeColumnType(c)»
    '''
    
    def private boolean inList(List<FieldDefinition> pkColumns, FieldDefinition c) {
        for (i : pkColumns)
            if (i == c)
                return true
        return false    
    }
    
    def public recurseColumns(ClassDefinition cl, List<FieldDefinition> pkColumns, boolean excludePkColumns) '''
        «cl.extendsClass?.classRef?.recurseColumns(pkColumns, excludePkColumns)»
        // table columns of java class «cl.name»
        «FOR c : cl.fields»
            «IF pkColumns != null && pkColumns.size == 1 && c == pkColumns.get(0)»
                @Id
            «ENDIF»
            «IF !excludePkColumns || !inList(pkColumns, c)»
                «singleColumn(c)»
                «writeGetter(c)»
                «writeSetter(c)»
                «IF hasProperty(c.properties, "version")»
                    «IF JavaDataTypeNoName(c, false).equals("int") || JavaDataTypeNoName(c, false).equals("Integer")»
                        «setIntVersion(c)»
                    «ENDIF»
                    // specific getter/setters for the version field
                    public void set$Version(«JavaDataTypeNoName(c, false)» _v) {
                        set«Util::capInitial(c.name)»(_v);
                    }
                    public «JavaDataTypeNoName(c, false)» get$Version() {
                        return get«Util::capInitial(c.name)»();
                    }
                «ENDIF»
                «IF hasProperty(c.properties, "active")»
                    «setHaveActive»
                    // specific getter/setters for the active flag (TODO: verify that this is a boolean!)
                    public void set$Active(boolean _a) {
                        set«Util::capInitial(c.name)»(_a);
                    }
                    public boolean get$Active() {
                        return get«Util::capInitial(c.name)»();
                    }
                «ENDIF»
            «ENDIF»
        «ENDFOR»
    '''

    def private writeGetter(FieldDefinition i) {
        val ref = DataTypeExtension::get(i.datatype);
        return '''
            public «JavaDataTypeNoName(i, false)» get«Util::capInitial(i.name)»() «writeException(DataTypeExtension::get(i.datatype))»{
                «IF JAVA_OBJECT_TYPE.equals(ref.javaType)»
                    if («i.name» == null)
                        return null;
                    ByteArrayParser _bap = new ByteArrayParser(«i.name», 0, -1);
                    return _bap.readObject(BonaPortable.class, true, true);
                «ELSEIF ref.enumMaxTokenLength == DataTypeExtension::NO_ENUM»
                    «IF ref.category == DataCategory::OBJECT»
                        return «i.name»;
                    «ELSEIF ref.javaType.equals("LocalDate")»
                        return LocalDate.fromCalendarFields(«i.name»);
                    «ELSEIF ref.javaType.equals("LocalDateTime")»
                        return LocalDateTime.fromCalendarFields(«i.name»);
                    «ELSEIF ref.javaType.equals("byte []")»
                        return ByteUtil.deepCopy(«i.name»);       // deep copy
                    «ELSEIF ref.javaType.equals("ByteArray")»
                        return new ByteArray(«i.name», 0, -1);
                    «ELSE»
                        return «i.name»;
                    «ENDIF»
                «ELSEIF ref.enumMaxTokenLength == DataTypeExtension::ENUM_NUMERIC || !ref.allTokensAscii»
                    return «ref.elementaryDataType.enumType.name».valueOf(«i.name»);
                «ELSE»
                    return «ref.elementaryDataType.enumType.name».factory(«i.name»);
                «ENDIF»
            }
        '''
    }
    
    def private writeSetter(FieldDefinition i) {
        val ref = DataTypeExtension::get(i.datatype);
        return '''
            public void set«Util::capInitial(i.name)»(«JavaDataTypeNoName(i, false)» «i.name») {
                «IF JAVA_OBJECT_TYPE.equals(ref.javaType)»
                    if («i.name» == null) {
                        this.«i.name» = null;
                    } else {
                        ByteArrayComposer _bac = new ByteArrayComposer();
                        _bac.addField(«i.name»);
                        this.«i.name» = _bac.getBytes();
                    }
                «ELSEIF ref.enumMaxTokenLength == DataTypeExtension::NO_ENUM»
                    «IF ref.category == DataCategory::OBJECT»
                        this.«i.name» = «i.name»;
                    «ELSEIF ref.javaType.equals("LocalDate") || ref.javaType.equals("LocalDateTime")»
                        this.«i.name» = DayTime.toGregorianCalendar(«i.name»);
                    «ELSEIF ref.javaType.equals("byte []")»
                        this.«i.name» = ByteUtil.deepCopy(«i.name»);       // deep copy
                    «ELSEIF ref.javaType.equals("ByteArray")»
                        this.«i.name» = «i.name».getBytes();  // deep copy of contents
                    «ELSE»
                        this.«i.name» = «i.name»;
                    «ENDIF»
                «ELSEIF ref.enumMaxTokenLength == DataTypeExtension::ENUM_NUMERIC || !ref.allTokensAscii»
                     this.«i.name» = «i.name».ordinal();
                «ELSE»
                    this.«i.name» = «i.name».getToken();
                «ENDIF»
            }
        '''
    }
    
    def private writeException(DataTypeExtension ref) {
        if (ref.enumMaxTokenLength != DataTypeExtension::NO_ENUM)
            return "throws EnumException "
        else if (JAVA_OBJECT_TYPE.equals(ref.javaType)) {
            return "throws MessageParserException "
        } else
            return ""
    }
    
       
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
                imports.addImport(ref.objectDataType)
            if (ref.genericsRef != null)
                imports.addImport(ref.genericsRef)
            // referenced enums
            if (ref.category == DataCategory::ENUM)
                imports.addImport(ref.elementaryDataType.enumType)
        }
        // return parameters of specific methods 
        //recurseMethods(d, true)
        // finally, possibly the parent object
        if (d.extendsClass != null && d.extendsClass.classRef != null)
            imports.addImport(d.extendsClass.classRef)
    }
    
    def private recurseDataGetter(ClassDefinition d) '''
        «d.extendsClass?.classRef?.recurseDataGetter»
        // auto-generated data getter for «d.name»
        «FOR i:d.fields»
            _r.set«Util::capInitial(i.name)»(get«Util::capInitial(i.name)»());
        «ENDFOR»
    '''
    
    def private recurseDataSetter(ClassDefinition d) '''
        «d.extendsClass?.classRef?.recurseDataSetter»
        // auto-generated data setter for «d.name»
        «FOR i:d.fields»
            set«Util::capInitial(i.name)»(_d.get«Util::capInitial(i.name)»());
        «ENDFOR»
    '''
    
    def private writeStubs(EntityDefinition e) '''
        «writeRtti(e.pojoType)»
        «IF !haveActive»
            // no isActive column in this entity, create stubs to satisfy interface 
            public void set$Active(boolean _a) {
                throw new RuntimeException("Entity «e.name» does not have an isActive field");
            }
            public boolean get$Active() {
                return true;  // no isActive column => all rows are active by default
            }
        «ENDIF»
        «IF haveIntVersion == null»
            // no version column of type int or Integer, write stub
            public void set$IntVersion(int _v) {
                throw new RuntimeException("Entity «e.name» does not have an integer type version field");
            }
            public int get$IntVersion() {
                return -1;
            }
        «ELSE»        
            // version column of type int or Integer exists, write proxy
            public void set$IntVersion(int _v) {
                set«Util::capInitial(haveIntVersion.name)»(_v);
            }
            public int get$IntVersion() {
                return get«Util::capInitial(haveIntVersion.name)»();
            }
        «ENDIF»
        '''
                
    def private writeInterfaceMethods(EntityDefinition e, String pkType, String trackingType) '''
        @Override
        public Class<«pkType»> get$KeyClass() {
            return «pkType».class;
        }
        @Override
        public String get$DataPQON() {
            return "«getPartiallyQualifiedClassName(e.pojoType)»";
        }
        @Override
        public Class<«e.pojoType.name»> get$DataClass() {
            return «e.pojoType.name».class;
        }
        @Override
        public String get$TrackingPQON() {
            «IF e.tableCategory.trackingColumns == null»
                return null;
            «ELSE»
                return "«getPartiallyQualifiedClassName(e.tableCategory.trackingColumns)»";
            «ENDIF»
        }
        @Override
        public Class<«trackingType»> get$TrackingClass() {
            «IF e.tableCategory.trackingColumns == null»
                return null;
            «ELSE»
                return «trackingType».class;
            «ENDIF»
        }
        
        @Override
        public «pkType» get$Key() throws ApplicationException {
            «IF pkType.equals("Serializable")»
                return null;  // FIXME! not yet implemented!
            «ELSE»
                «IF e.pk.columnName.size > 1»
                    return key; // FIXME! do deep copy & data type conversions
                «ELSE»
                    return «e.pk.columnName.get(0).name»;
                «ENDIF»
            «ENDIF»
        }
        @Override
        public void set$Key(«pkType» _k) {
            «IF pkType.equals("Serializable")»
                // FIXME! not yet implemented!!!
            «ELSE»
                «IF e.pk.columnName.size > 1»
                    key = _k;   // FIXME! do deep copy & data type conversions
                «ELSE»
                    set«Util::capInitial(e.pk.columnName.get(0).name)»(_k);  // no direct assigned due to possible enum or temporal type, with implied conversions 
                «ENDIF»
            «ENDIF»
        }
        @Override
        public «e.pojoType.name» get$Data() throws ApplicationException {
            «e.pojoType.name» _r = new «e.pojoType.name»();
            «recurseDataGetter(e.pojoType)»
            return _r;
        }
        @Override
        public void set$Data(«e.pojoType.name» _d) {
            «recurseDataSetter(e.pojoType)»
        }
        @Override
        public «trackingType» get$Tracking() throws ApplicationException {
            «IF e.tableCategory.trackingColumns == null»
                return null;
            «ELSE»
                «e.tableCategory.trackingColumns.name» _r = new «e.tableCategory.trackingColumns.name»();
                «recurseDataGetter(e.tableCategory.trackingColumns)»
                return _r;
            «ENDIF»
        }
        @Override
        public void set$Tracking(«trackingType» _d) {
            «IF e.tableCategory.trackingColumns != null»
                «recurseDataSetter(e.tableCategory.trackingColumns)»
            «ENDIF»
        }
    '''

    def private writeStaticFindByMethods(ClassDefinition d, EntityDefinition e) '''
        «d.extendsClass?.classRef?.writeStaticFindByMethods(e)»
        «FOR i:d.fields»
            «IF hasProperty(i.properties, "findBy")»
                public static «e.name» findBy«Util::capInitial(i.name)»(EntityManager _em, «JavaDataTypeNoName(i, false)» _key) {
                    try {
                        TypedQuery<«e.name»> _query = _em.createQuery("SELECT u FROM «e.name» u WHERE u.«i.name» = ?1", «e.name».class);
                        return _query.setParameter(1, _key).getSingleResult();
                    } catch (NoResultException e) {
                        return null;
                    }
                }
            «ELSEIF hasProperty(i.properties, "listBy")»
                public static List<«e.name»> listBy«Util::capInitial(i.name)»(EntityManager _em, «JavaDataTypeNoName(i, false)» _key) {
                    try {
                        TypedQuery<«e.name»> _query = _em.createQuery("SELECT u FROM «e.name» u WHERE u.«i.name» = ?1", «e.name».class);
                        return _query.setParameter(1, _key).getResultList();
                    } catch (NoResultException e) {
                        return null;
                    }
                }
            «ENDIF»
            «IF hasProperty(i.properties, "listActiveBy")»
                public static List<«e.name»> listBy«Util::capInitial(i.name)»(EntityManager _em, «JavaDataTypeNoName(i, false)» _key) {
                    try {
                        TypedQuery<«e.name»> _query = _em.createQuery("SELECT u FROM «e.name» u WHERE u.«i.name» = ?1 AND isActive = true", «e.name».class);
                        return _query.setParameter(1, _key).getResultList();
                    } catch (NoResultException e) {
                        return null;
                    }
                }
            «ENDIF»
        «ENDFOR»
    '''
    
                
    def private javaEntityOut(EntityDefinition e, boolean compositeKey) {
        val String myPackageName = getPackageName(e)
        val ImportCollector imports = new ImportCollector(myPackageName)
        e.tableCategory.trackingColumns?.collectImports(imports)
        e.pojoType.collectImports(imports)
        // reset tracking flags
        haveIntVersion = null
        haveActive = false
            
        imports.addImport(myPackageName, e.name)  // add myself as well
        imports.addImport(e.pojoType);
        imports.addImport(e.tableCategory.trackingColumns);
            
        var List<FieldDefinition> pkColumns = null
        var String pkType = "Serializable"
        var String trackingType = "BonaPortable"
        if (e.pk != null) {
            pkColumns = e.pk.columnName
            if (pkColumns.size > 1)
                pkType = e.name + "Key"
            else
                pkType = pkColumns.get(0).JavaDataTypeNoName(true) 
        }
            
        if (e.tableCategory.trackingColumns != null) {
            trackingType = e.tableCategory.trackingColumns.name
        }
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
        «IF e.cacheable»
        import javax.persistence.Cacheable;
        «ENDIF»
        «IF e.isAbstract»
        @MappedSuperclass
        «ENDIF»
        import javax.persistence.EntityManager;
        import javax.persistence.Entity;
        import javax.persistence.Table;
        import javax.persistence.Version;
        import javax.persistence.Column;
        import javax.persistence.Lob;
        import javax.persistence.Basic;
        import javax.persistence.FetchType;
        import javax.persistence.Id;
        import javax.persistence.Temporal;
        import javax.persistence.TemporalType;
        import javax.persistence.NoResultException;
        import javax.persistence.TypedQuery;
        import javax.persistence.EmbeddedId;
        import java.util.Arrays;
        import java.util.List;
        import java.util.ArrayList;
        import java.util.regex.Pattern;
        import java.util.regex.Matcher;
        import java.util.GregorianCalendar;
        import java.util.UUID;
        import java.io.Serializable;
        import java.math.BigDecimal;
        «IF e.isDeprecated || e.pojoType.isDeprecated»
        import java.lang.annotation.Deprecated;
        «ENDIF»
        
        import de.jpaw.bonaparte.jpa.BonaPersistable;
        import de.jpaw.bonaparte.core.BonaPortable;
        import de.jpaw.bonaparte.core.ByteArrayComposer;
        import de.jpaw.bonaparte.core.ByteArrayParser;
        import de.jpaw.bonaparte.core.MessageParserException;
        import de.jpaw.util.ByteArray;
        import de.jpaw.util.CharTestsASCII;
        import de.jpaw.util.EnumException;
        import de.jpaw.util.ApplicationException;
        import de.jpaw.util.DayTime;
        import de.jpaw.util.ByteUtil;
        «IF Util::useJoda()»
        import org.joda.time.LocalDate;
        import org.joda.time.LocalDateTime;
        «ENDIF»
        «imports.createImports»
        
        «IF e.isAbstract»
        @MappedSuperclass
        «ELSE»
        @Entity
        «IF e.cacheable»
        @Cacheable(true)
        «ENDIF»
        «IF e.cacheSize != 0»
        @Cache(size=«e.cacheSize», expiry=«scaledExpiry(e.cacheExpiry, e.cacheExpiryScale)»000)
        «ENDIF»
        @Table(name="«mkTablename(e, false)»")
        «IF e.tenantId != null»
        @Multitenant(/* SINGLE_TABLE */)
        «ENDIF»
        «ENDIF»
        «IF e.isDeprecated || e.pojoType.isDeprecated»
        @Deprecated
        «ENDIF»
        public «IF e.isFinal»final «ENDIF»class «e.name» «IF e.extendsClass != null»extends «e.extendsClass.name»«ENDIF» implements BonaPersistable<«pkType», «e.pojoType.name», «trackingType»>«IF e.implementsInterface != null», «e.implementsInterface»«ENDIF» {
            «IF compositeKey»
                @EmbeddedId
                «e.name»Key key;
                // forwarding getters and setters
                «FOR i:e.pk.columnName»
                    public void set«Util::capInitial(i.name)»(«JavaDataTypeNoName(i, false)» _x) {
                        key.set«Util::capInitial(i.name)»(_x);
                    }
                    public «JavaDataTypeNoName(i, false)» get«Util::capInitial(i.name)»() {
                        return key.get«Util::capInitial(i.name)»();
                    }
                «ENDFOR»
                
            «ENDIF»
            «e.tableCategory.trackingColumns?.recurseColumns(pkColumns, compositeKey)»
            «e.pojoType.recurseColumns(pkColumns, compositeKey)»
            «EqualsHash::writeEqualsAndHashCode(e, compositeKey)»
            «writeStubs(e)»
            «writeInterfaceMethods(e, pkType, trackingType)»
            «writeStaticFindByMethods(e.pojoType, e)»
        }
        '''
    }
    def private javaKeyOut(EntityDefinition e) {
        val String myPackageName = getPackageName(e)
        val ImportCollector imports = new ImportCollector(myPackageName)
        e.pojoType.collectImports(imports)
            
        imports.addImport(myPackageName, e.name + "Key")  // add myself as well
            
        return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git 
        package «getPackageName(e)»;
        
        import javax.persistence.EntityManager;
        import javax.persistence.Embeddable;
        import javax.persistence.Column;
        import javax.persistence.EmbeddedId;
        import javax.persistence.Temporal;
        import javax.persistence.TemporalType;
        import java.util.Arrays;
        import java.util.List;
        import java.util.ArrayList;
        import java.util.regex.Pattern;
        import java.util.regex.Matcher;
        import java.util.GregorianCalendar;
        import java.util.UUID;
        import java.io.Serializable;
        import java.math.BigDecimal;
        
        import de.jpaw.bonaparte.core.BonaPortable;
        import de.jpaw.bonaparte.core.ByteArrayComposer;
        import de.jpaw.bonaparte.core.ByteArrayParser;
        import de.jpaw.bonaparte.core.MessageParserException;
        import de.jpaw.util.ByteArray;
        import de.jpaw.util.CharTestsASCII;
        import de.jpaw.util.EnumException;
        import de.jpaw.util.ApplicationException;
        import de.jpaw.util.DayTime;
        import de.jpaw.util.ByteUtil;
        «IF Util::useJoda()»
        import org.joda.time.LocalDate;
        import org.joda.time.LocalDateTime;
        «ENDIF»
        «imports.createImports»
        
        @Embeddable
        public class «e.name»Key implements Serializable {
            «FOR col : e.pk.columnName»
                «singleColumn(col)»
                «writeGetter(col)»
                «writeSetter(col)»
            «ENDFOR»
            «EqualsHash::writeHash(null, e.pk.columnName)»
            «EqualsHash::writeKeyEquals(e, e.pk.columnName)»
        }
        '''
    }
}