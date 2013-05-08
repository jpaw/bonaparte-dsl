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
import de.jpaw.bonaparte.dsl.generator.XUtil
import de.jpaw.bonaparte.dsl.generator.DataCategory
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.dsl.generator.JavaPackages.*
import static extension de.jpaw.bonaparte.dsl.generator.java.JavaRtti.*
import static extension de.jpaw.persistence.dsl.generator.YUtil.*
import static extension de.jpaw.persistence.dsl.generator.java.ZUtil.*
import de.jpaw.persistence.dsl.bDDL.PackageDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.ImportCollector
import de.jpaw.bonaparte.dsl.bonScript.PropertyUse
import java.util.List
import de.jpaw.persistence.dsl.bDDL.Inheritance
import de.jpaw.bonaparte.dsl.bonScript.XVisibility
import de.jpaw.bonaparte.dsl.bonScript.Visibility

class JavaDDLGeneratorMain implements IGenerator {
    val String JAVA_OBJECT_TYPE = "BonaPortable";
    val String calendar = "Calendar";
    var FieldDefinition haveIntVersion = null
    var haveActive = false
    var boolean useUserTypes = true;
    var String fieldVisibility = "";
    
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

    override void doGenerate(Resource resource, IFileSystemAccess fsa) {
        // java
        for (e : resource.allContents.toIterable.filter(typeof(EntityDefinition))) {
            if (!e.noJava) {
                var boolean compositeKey = false;
                if (e.pk != null && e.pk.columnName.size > 1) {
                    // write a separate class for the composite key
                    fsa.generateFile(getJavaFilename(getPackageName(e), e.name + "Key"), e.javaKeyOut)
                    compositeKey = true
                }
                fsa.generateFile(getJavaFilename(getPackageName(e), e.name), e.javaEntityOut(compositeKey))
            }
        }
        for (d : resource.allContents.toIterable.filter(typeof(PackageDefinition))) {
            // write a package-info.java file, if javadoc on package level exists
            if (d.javadoc != null) {
                fsa.generateFile(getJavaFilename(getPackageName(d), "package-info"), '''
                    // This source has been automatically created by the bonaparte persistence DSL. Do not modify, changes will be lost.
                    // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
                    // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git
                    
                    «d.javadoc» 
                    package «getPackageName(d)»;
                ''')
            }
        }
    }
    
    // temporal types for Calendar (standard JPA types, conversion in getters / setters)
    def private writeTemporal(FieldDefinition c, String type) '''
        @Temporal(TemporalType.«type»)
        «IF c.isArray != null»
            «fieldVisibility»«calendar»[] «c.name»;
        «ELSEIF c.isList != null»
            «fieldVisibility»List <«calendar»> «c.name»;
        «ELSE»
            «fieldVisibility»«calendar» «c.name»;
        «ENDIF»
    '''
    
    // temporal types for UserType mappings (OR mapper specific extensions)
    def private writeTemporalFieldAndAnnotation(FieldDefinition c, String type, String fieldType) '''
        @Temporal(TemporalType.«type»)
        «writeTemporalField(c, fieldType)»
    '''
    
    def private writeTemporalField(FieldDefinition c, String fieldType) '''
        «IF c.isArray != null»
            «fieldVisibility»«fieldType»[] «c.name»;
        «ELSEIF c.isList != null»
            «fieldVisibility»List <«fieldType»> «c.name»;
        «ELSE»
            «fieldVisibility»«fieldType» «c.name»;
        «ENDIF»
    '''
    
    def private writeColumnType(FieldDefinition c) {
        val DataTypeExtension ref = DataTypeExtension::get(c.datatype)
        if (ref.objectDataType != null && hasProperty(c.properties, "serialized")) {
            // use byte[] Java type and assume same as Object
            return '''
                        «fieldVisibility»byte [] «c.name»;'''
        }
        switch (ref.enumMaxTokenLength) {
        case DataTypeExtension::NO_ENUM:
            if (useUserTypes) {
                switch (ref.javaType) {
                case "Calendar":            writeTemporalFieldAndAnnotation(c, "TIMESTAMP", calendar)
                case "DateTime":            writeTemporalFieldAndAnnotation(c, "DATE", calendar)
                case "LocalDateTime":       writeTemporalField(c, ref.javaType)
                case "LocalDate":           writeTemporalField(c, ref.javaType)
                case "ByteArray":           '''
                        «fieldVisibility»ByteArray «c.name»;'''
                case JAVA_OBJECT_TYPE:      '''
                        // @Lob
                        «fieldVisibility»byte [] «c.name»;
                    '''
                default:                   '''        
                    «fieldVisibility»«JavaDataTypeNoName(c, false)» «c.name»;
                    '''
                }
            } else {
                switch (ref.javaType) {
                case "Calendar":            writeTemporal(c, "TIMESTAMP")
                case "LocalDateTime":       writeTemporal(c, "TIMESTAMP")
                case "DateTime":            writeTemporal(c, "DATE")
                case "ByteArray":           '''
                        «fieldVisibility»byte [] «c.name»;'''
                case JAVA_OBJECT_TYPE:      '''
                        // @Lob
                        «fieldVisibility»byte [] «c.name»;
                    '''
                default:                   '''        
                    «fieldVisibility»«JavaDataTypeNoName(c, false)» «c.name»;
                    '''
                }
            }
        case DataTypeExtension::ENUM_NUMERIC: '''        
                «fieldVisibility»Integer «c.name»;
            '''
        default: '''
                «fieldVisibility»«IF ref.allTokensAscii»String«ELSE»Integer«ENDIF» «c.name»;
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
    
    // write a @Size annotation for string based types
    def private optionalSizeSpecForStrings(FieldDefinition c) {
        val ref = DataTypeExtension::get(c.datatype);
        if (ref.category == DataCategory::STRING)
            return '''@Size(«IF ref.elementaryDataType.minLength > 0»min=«ref.elementaryDataType.minLength», «ENDIF»max=«ref.elementaryDataType.length»)
            '''
        return ''''''
    }
    
    // write the definition of a single column
    def private singleColumn(FieldDefinition c) '''
            @Column(name="«columnName(c)»"«IF hasProperty(c.properties, "noinsert")», insertable=false«ENDIF»«IF hasProperty(c.properties, "noupdate")», updatable=false«ENDIF»)
            «optionalAnnotation(c.properties, "version", "@Version")»
            «optionalAnnotation(c.properties, "lob",     "@Lob")»
            «optionalAnnotation(c.properties, "lazy",    "@Basic(fetch=LAZY)")»
            «IF XUtil::isRequired(c)»
                @NotNull
            «ENDIF»
            «optionalSizeSpecForStrings(c)»
            «writeColumnType(c)»
    '''
    
    def private boolean inList(List<FieldDefinition> pkColumns, FieldDefinition c) {
        for (i : pkColumns)
            if (i == c)
                return true
        return false    
    }
    
    def public CharSequence recurseColumns(ClassDefinition cl, List<FieldDefinition> pkColumns, boolean excludePkColumns, ClassDefinition stopper) '''
        «IF cl != stopper»
            «cl.extendsClass?.classRef?.recurseColumns(pkColumns, excludePkColumns, stopper)»
            // table columns of java class «cl.name»
            «FOR c : cl.fields»
                «IF pkColumns != null && pkColumns.size == 1 && c == pkColumns.get(0)»
                    @Id
                «ENDIF»
                «IF (!excludePkColumns || !inList(pkColumns, c)) && !hasProperty(c.properties, "noJava")»
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
        «ENDIF»
    '''

    def private writeGetter(FieldDefinition i) {
        val ref = DataTypeExtension::get(i.datatype);
        return '''
            public «JavaDataTypeNoName(i, false)» get«Util::capInitial(i.name)»() «writeException(DataTypeExtension::get(i.datatype), i)»{
                «IF JAVA_OBJECT_TYPE.equals(ref.javaType) || (ref.objectDataType != null && hasProperty(i.properties, "serialized"))»
                    if («i.name» == null)
                        return null;
                    ByteArrayParser _bap = new ByteArrayParser(«i.name», 0, -1);
                    return «IF ref.objectDataType != null»(«JavaDataTypeNoName(i, false)»)«ENDIF»_bap.readObject("«i.name»", «IF ref.objectDataType != null»«JavaDataTypeNoName(i, false)»«ELSE»BonaPortable«ENDIF».class, true, true);
                «ELSEIF ref.enumMaxTokenLength == DataTypeExtension::NO_ENUM»
                    «IF ref.category == DataCategory::OBJECT»
                        return «i.name»;
                    «ELSEIF ref.javaType.equals("LocalDate")»
                        return «i.name»«IF !useUserTypes» == null ? null : LocalDate.fromCalendarFields(«i.name»)«ENDIF»;
                    «ELSEIF ref.javaType.equals("LocalDateTime")»
                        return «i.name»«IF !useUserTypes» == null ? null : LocalDateTime.fromCalendarFields(«i.name»)«ENDIF»;
                    «ELSEIF ref.javaType.equals("ByteArray")»
                        return «i.name»«IF !useUserTypes» == null ? null : new ByteArray(«i.name», 0, -1)«ENDIF»;
                    «ELSEIF ref.javaType.equals("byte []")»
                        return ByteUtil.deepCopy(«i.name»);       // deep copy
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
                «IF JAVA_OBJECT_TYPE.equals(ref.javaType) || (ref.objectDataType != null && hasProperty(i.properties, "serialized"))»
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
                        this.«i.name» = «IF useUserTypes»«i.name»«ELSE»DayTime.toGregorianCalendar(«i.name»)«ENDIF»;
                    «ELSEIF ref.javaType.equals("ByteArray")»
                        this.«i.name» = «IF useUserTypes»«i.name»«ELSE»«i.name» == null ? null : «i.name».getBytes()«ENDIF»;
                    «ELSEIF ref.javaType.equals("byte []")»
                        this.«i.name» = ByteUtil.deepCopy(«i.name»);       // deep copy
                    «ELSE»
                        this.«i.name» = «i.name»;
                    «ENDIF»
                «ELSEIF ref.enumMaxTokenLength == DataTypeExtension::ENUM_NUMERIC || !ref.allTokensAscii»
                     this.«i.name» = «i.name» == null ? null : «i.name».ordinal();
                «ELSE»
                    this.«i.name» = «i.name» == null ? null : «i.name».getToken();
                «ENDIF»
            }
        '''
    }
    
    def private writeException(DataTypeExtension ref, FieldDefinition c) {
        if (ref.enumMaxTokenLength != DataTypeExtension::NO_ENUM)
            return "throws EnumException "
        else if (JAVA_OBJECT_TYPE.equals(ref.javaType) || (ref.objectDataType != null && hasProperty(c.properties, "serialized"))) {
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
    
    
    def private writeStubs(EntityDefinition e) '''
        «IF e.^extends == null»
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
        «ENDIF»
    '''
     
    def private writeInterfaceMethods(EntityDefinition e, String pkType, String trackingType) '''
        «IF e.^extends == null»
        // static methods
        //public static int class$rtti() {
        //    return «e.pojoType.name».class$rtti();
        //}
        public static Class<«pkType»> class$KeyClass() {
            return «pkType».class;
        }
        public static Class<«trackingType»> class$TrackingClass() {
            «IF e.tableCategory.trackingColumns == null»
                return null;
            «ELSE»
                return «trackingType».class;
            «ENDIF»
        }
        
                
        @Override
        public Class<«pkType»> get$KeyClass() {
            return «pkType».class;
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
        public «trackingType» get$Tracking() throws ApplicationException {
            «IF e.tableCategory.trackingColumns == null»
                return null;
            «ELSE»
                «e.tableCategory.trackingColumns.name» _r = new «e.tableCategory.trackingColumns.name»();
                «recurseDataGetter(e.tableCategory.trackingColumns, null)»
                return _r;
            «ENDIF»
        }
        @Override
        public void set$Tracking(«trackingType» _d) {
            «IF e.tableCategory.trackingColumns != null»
                «recurseDataSetter(e.tableCategory.trackingColumns, null, null)»
            «ENDIF»
        }
        «ENDIF»
    '''

    def private CharSequence writeStaticFindByMethods(ClassDefinition d, EntityDefinition e, ClassDefinition stopper) '''
        «IF d != stopper»
            «d.extendsClass?.classRef?.writeStaticFindByMethods(e, stopper)»
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
        «ENDIF»
    '''
    
    def private i2s(Inheritance i) {
        switch (i) {
        case Inheritance::SINGLE_TABLE: return "SINGLE_TABLE"
        case Inheritance::JOIN: return "JOINED"
        case Inheritance::TABLE_PER_CLASS: return "TABLE_PER_CLASS"
        }
    }
    
    def private wrImplements(EntityDefinition e, String pkType, String trackingType) {
        if (e.noMapper)
            '''BonaPersistableNoData<«pkType», «trackingType»>'''
        else
            '''BonaPersistable<«pkType», «e.pojoType.name», «trackingType»>'''
    }
    
    def private static String makeVisibility(Visibility v) {
        var XVisibility fieldScope
        if (v != null && v.x != null)
            fieldScope = v.x
        if (fieldScope == null || fieldScope == XVisibility::DEFAULT)
            ""
        else
            fieldScope.toString() + " " 
    }
    
    def private javaEntityOut(EntityDefinition e, boolean compositeKey) {
        val String myPackageName = getPackageName(e)
        val ImportCollector imports = new ImportCollector(myPackageName)
        var ClassDefinition stopper = null
        val myPackage = e.eContainer as PackageDefinition 
        imports.recurseImports(e.tableCategory.trackingColumns, true)
        imports.recurseImports(e.pojoType, true)
        // reset tracking flags
        haveIntVersion = null
        haveActive = false
        fieldVisibility = makeVisibility(if (e.visibility != null) e.visibility else myPackage.visibility)
        useUserTypes = !myPackage.noUserTypes            
            
        imports.addImport(myPackageName, e.name)  // add myself as well
        imports.addImport(e.pojoType);
        imports.addImport(e.tableCategory.trackingColumns);
        if (e.^extends != null) {
            imports.addImport(getPackageName(e.^extends), e.^extends.name)
            stopper = e.^extends.pojoType
        }            
            
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
        «IF e.xinheritance != null && e.xinheritance != Inheritance::NONE»
        import javax.persistence.Inheritance;
        import javax.persistence.InheritanceType;
        «ENDIF»
        «IF e.discname != null»
        import javax.persistence.DiscriminatorType;
        import javax.persistence.DiscriminatorColumn;
        import javax.persistence.DiscriminatorValue;
        «ENDIF»
        «IF e.^extends != null»
        import javax.persistence.DiscriminatorValue;
        «ENDIF»
        «IF e.mappedSuperclass || e.isAbstract»
        import javax.persistence.MappedSuperclass;
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
        import javax.validation.constraints.NotNull;
        import javax.validation.constraints.Size;
        import java.util.Arrays;
        import java.util.List;
        import java.util.ArrayList;
        import java.util.regex.Pattern;
        import java.util.regex.Matcher;
        import java.util.GregorianCalendar;
        import java.util.Calendar;
        import java.util.UUID;
        import java.io.Serializable;
        import java.math.BigDecimal;
        
        «IF e.noMapper»
        import de.jpaw.bonaparte.jpa.BonaPersistableNoData;
        «ELSE»
        import de.jpaw.bonaparte.jpa.BonaPersistable;
        «ENDIF»
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
        
        «IF e.javadoc != null»
            «e.javadoc»
        «ENDIF»
        «IF e.isAbstract || e.mappedSuperclass»
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
        «IF e.xinheritance != null && e.xinheritance != Inheritance::NONE»
        @Inheritance(strategy=InheritanceType.«i2s(e.xinheritance)»)
        «ENDIF»
        «IF e.discname != null»
        @DiscriminatorColumn(name="«e.discname»", discriminatorType=DiscriminatorType.«IF e.discriminatorTypeInt»INTEGER«ELSE»STRING«ENDIF»)
        @DiscriminatorValue(«IF e.discriminatorTypeInt»"0"«ELSE»"«Util::escapeString2Java(e.discriminatorValue)»"«ENDIF»)
        «ELSEIF e.^extends != null»
        @DiscriminatorValue("«Util::escapeString2Java(e.discriminatorValue)»")
        «ENDIF»
        «ENDIF»
        «IF e.isDeprecated || e.pojoType.isDeprecated»
        @Deprecated
        «ENDIF»
        public class «e.name»«IF e.extendsClass != null» extends «e.extendsClass.name»«ENDIF»«IF e.extendsJava != null» extends «e.extendsJava»«ENDIF»«IF e.^extends != null» extends «e.^extends.name»«ELSE» implements «wrImplements(e, pkType, trackingType)»«IF e.implementsInterface != null», «e.implementsInterface»«ENDIF»«ENDIF» {
            «IF stopper == null && compositeKey»
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
            «IF stopper == null»«e.tableCategory.trackingColumns?.recurseColumns(pkColumns, compositeKey, null)»«ENDIF»
            «e.pojoType.recurseColumns(pkColumns, compositeKey, stopper)»
            «e.inheritanceRoot.tenantClass?.recurseColumns(pkColumns, false, null)»
            «IF stopper == null»«EqualsHash::writeEqualsAndHashCode(e, compositeKey)»«ENDIF»
            «writeStubs(e)»
            «writeInterfaceMethods(e, pkType, trackingType)»
            «IF (!e.noMapper)»
                «MakeMapper::writeMapperMethods(e, pkType, trackingType)»
            «ENDIF»
            «writeStaticFindByMethods(e.pojoType, e, stopper)»
        }
        '''
    }
    def private javaKeyOut(EntityDefinition e) {
        val String myPackageName = getPackageName(e)
        val ImportCollector imports = new ImportCollector(myPackageName)
        imports.recurseImports(e.pojoType, true)
            
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
        import java.util.Calendar;
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