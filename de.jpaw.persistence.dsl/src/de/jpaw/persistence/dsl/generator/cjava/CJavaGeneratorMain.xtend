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

package de.jpaw.persistence.dsl.generator.cjava

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.bonScript.Visibility
import de.jpaw.bonaparte.dsl.bonScript.XVisibility
import de.jpaw.bonaparte.dsl.generator.DataCategory
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.java.ImportCollector
import de.jpaw.persistence.dsl.bDDL.EmbeddableUse
import de.jpaw.persistence.dsl.bDDL.NoSQLEntityDefinition
import de.jpaw.persistence.dsl.bDDL.PackageDefinition
import de.jpaw.persistence.dsl.generator.RequiredType
import java.util.List
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator

import static de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*
import static de.jpaw.bonaparte.dsl.generator.java.JavaRtti.*

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.persistence.dsl.generator.YUtil.*

class CJavaDDLGeneratorMain implements IGenerator {
    val static final String JAVA_OBJECT_TYPE = "BonaPortable";
    val static final String CALENDAR = "Calendar";
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

    // create the package name for an entity
    def public static getPackageName(NoSQLEntityDefinition d) {
        getPackageName(d.eContainer as PackageDefinition)
    }

    override void doGenerate(Resource resource, IFileSystemAccess fsa) {
        // java
        for (e : resource.allContents.toIterable.filter(typeof(NoSQLEntityDefinition))) {
            fsa.generateFile(getJavaFilename(getPackageName(e), e.name), e.javaEntityOut)
        }
    }

    // the same, more complex scenario
    def public static JavaDataType2NoName(FieldDefinition i, boolean skipIndex, String dataClass) {
        if (skipIndex || i.properties.hasProperty(PROP_UNROLL))
            dataClass
        else if (i.isArray != null)
            dataClass + "[]"
        else if (i.isSet != null)
            "Set<" + dataClass + ">"
        else if (i.isList != null)
            "List<" + dataClass + ">"
        else if (i.isMap != null)
            "Map<" + i.isMap.indexType + "," + dataClass + ">"
        else
            dataClass
    }

    // temporal types for UserType mappings (OR mapper specific extensions)
    def private writeTemporalFieldAndAnnotation(FieldDefinition c, String type, String fieldType, String myName) '''
        @Temporal(TemporalType.«type»)
        «fieldVisibility»«c.JavaDataType2NoName(false, fieldType)» «myName»;
    '''
    // temporal types for UserType mappings (OR mapper specific extensions)
    def private writeField(FieldDefinition c, String fieldType, String myName) '''
        «fieldVisibility»«c.JavaDataType2NoName(false, fieldType)» «myName»;
    '''

    def private writeColumnType(FieldDefinition c) {
        val DataTypeExtension ref = DataTypeExtension::get(c.datatype)
        if (ref.objectDataType != null) {
            if (c.properties.hasProperty("serialized")) {
                // use byte[] Java type and assume same as Object
                return '''
                    «fieldVisibility»byte [] «c.name»;'''
            } else if (c.properties.hasProperty(PROP_REF)) {
                // plain old Long as an artificial key / referencing is done by application
                // can optionally have a ManyToOne object mapping in a Java superclass, with insertable=false, updatable=false
                return '''
                    «fieldVisibility»Long «c.name»;'''
            } else if (c.properties.hasProperty("ManyToOne")) {
                // child object, create single-sided many to one annotations as well
                val params = c.properties.getProperty("ManyToOne")
                return '''
                    @ManyToOne«IF params != null»(«params»)«ENDIF»
                    «IF c.properties.getProperty("JoinColumn") != null»
                        @JoinColumn(«c.properties.getProperty("JoinColumn")»)
                    «ELSEIF c.properties.getProperty("JoinColumnRO") != null»
                        @JoinColumn(«c.properties.getProperty("JoinColumnRO")», insertable=false, updatable=false)  // have a separate Long property field for updates
                    «ENDIF»
                    «fieldVisibility»«c.JavaDataTypeNoName(false)» «c.name»;'''
            }
        }
        switch (ref.enumMaxTokenLength) {
        case DataTypeExtension::NO_ENUM:
            switch (ref.javaType) {
            case "Calendar":        writeTemporalFieldAndAnnotation(c, "TIMESTAMP", CALENDAR, c.name)
            case "DateTime":        writeTemporalFieldAndAnnotation(c, "DATE", CALENDAR, c.name)
            case "LocalDateTime":   if (useUserTypes)
                                        writeField(c, ref.javaType, c.name)
                                    else
                                        writeTemporalFieldAndAnnotation(c, "TIMESTAMP", CALENDAR, c.name)
            case "LocalDate":       if (useUserTypes)
                                        writeField(c, ref.javaType, c.name)
                                    else
                                        writeTemporalFieldAndAnnotation(c, "DATE", CALENDAR, c.name)
            case "ByteArray":       writeField(c, if (useUserTypes) "ByteArray" else "byte []", c.name)
            case JAVA_OBJECT_TYPE:  '''
                                        // @Lob
                                        «writeField(c, "byte []", c.name)»
                                    '''
            default:                '''
                                        «fieldVisibility»«JavaDataTypeNoName(c, c.properties.hasProperty(PROP_UNROLL))» «c.name»;
                                    '''
            }
        case DataTypeExtension::ENUM_NUMERIC:   writeField(c, "Integer", c.name)
        default:                                writeField(c, if (ref.allTokensAscii) "String" else "Integer", c.name)
        }
    }


    def private setIntVersion(FieldDefinition c) {
        haveIntVersion = c
        return ""
    }
    def private setHaveActive() {
        haveActive = true
        return ""
    }

    // write the definition of a single column (entities or Embeddables)
    def private singleColumn(FieldDefinition c) '''
        «c.writeColumnType»
    '''

    // output a single field (which maybe expands to multiple DB columns due to embeddables and List expansion. The field could be used from an entity or an embeddable
    def private static CharSequence writeFieldWithEmbeddedAndListJ(FieldDefinition f, List<EmbeddableUse> embeddables,
            String prefix, String suffix, String currentIndex,
            boolean noListAtThisPoint, boolean noList2, String separator, (FieldDefinition, String, String) => CharSequence func) {
        // expand Lists first
        // if the elements are nullable (!f.isRequired), then any element is transferred. Otherwise, only not null elements are transferred
        val myName = f.name.asEmbeddedName(prefix, suffix)
        if (!noListAtThisPoint && f.isList != null && f.isList.maxcount > 0 && f.properties.hasProperty(PROP_UNROLL)) {
            val indexPattern = f.indexPattern;
            val notNullElements = f.isRequired
            return '''
                «(1 .. f.isList.maxcount).map[f.writeFieldWithEmbeddedAndListJ(embeddables, prefix, '''«suffix»«String::format(indexPattern, it)»''', String::format(indexPattern, it), true, false, separator, func)].join(separator)»
                «IF noList2 == false»
                    public «f.JavaDataTypeNoName(false)» get«myName.toFirstUpper()»() {
                        «f.JavaDataTypeNoName(false)» _a = new Array«f.JavaDataTypeNoName(false)»(«f.isList.maxcount»);
                        «(1 .. f.isList.maxcount).map['''«IF notNullElements»if (get«myName.toFirstUpper»«String::format(indexPattern, it)»() != null) «ENDIF»_a.add(get«myName.toFirstUpper»«String::format(indexPattern, it)»());'''].join('\n')»
                        return _a;
                    }
                    public void set«myName.toFirstUpper()»(«f.JavaDataTypeNoName(false)» _a) {
                        «(1 .. f.isList.maxcount).map['''set«myName.toFirstUpper»«String::format(indexPattern, it)»(null);'''].join('\n')»
                        if (_a == null)
                            return;
                        «(1 .. f.isList.maxcount).map['''if (_a.size() >= «it») set«myName.toFirstUpper»«String::format(indexPattern, it)»(_a.get(«it-1»));'''].join('\n')»
                    }
                «ENDIF»
                '''
        } else {
            // see if we need embeddables expansion
            val emb = embeddables.findFirst[field == f]
            if (emb != null) {
                // expand embeddable, output it instead of the original column
                val objectName = emb.name.pojoType.name
                val nameLengthDiff = f.name.length - objectName.length
                val tryDefaults = emb.prefix == null && emb.suffix == null && nameLengthDiff > 0
                val finalPrefix = if (tryDefaults && f.name.endsWith(objectName)) f.name.substring(0, nameLengthDiff) else emb.prefix             // Address homeAddress => prefix home
                val finalSuffix = if (tryDefaults && f.name.startsWith(objectName.toFirstLower)) f.name.substring(objectName.length) else emb.suffix // Amount amountBc => suffix Bc
                val newPrefix = '''«prefix»«finalPrefix»'''
                val newSuffix = '''«finalSuffix»«suffix»'''
                val fields = emb.name.pojoType.allFields  // shorthand...
                //System::out.println('''Java: «myName» defts=«tryDefaults»: nldiff=«nameLengthDiff», emb.pre=«emb.prefix», emb.suff=«emb.suffix»!''')
                //System::out.println('''Java: «myName» defts=«tryDefaults»: has in=(«prefix»,«suffix»), final=(«finalPrefix»,«finalSuffix»), new=(«newPrefix»,«newSuffix»)''')
                
                return '''
                    «IF newPrefix != "" || newSuffix != ""»
                        @AttributeOverrides({
                        «emb.name.pojoType.allFields.map[writeFieldWithEmbeddedAndListJ(emb.name.embeddables, newPrefix, newSuffix, null, false, true, ',\n',
                            [ fld, myName2, ind | '''    @AttributeOverride(name="«fld.name»«ind»", column=@Column(name="«myName2.java2sql»"))'''])].join(',\n')»
                        })
                    «ENDIF»
                    «IF emb.isPk != null»
                        @EmbeddedId
                    «ELSE»
                        @Embedded
                    «ENDIF»
                    private «emb.name.name» «myName»;
                    public «emb.name.pojoType.name» get«myName.toFirstUpper()»() {
                        if («myName» == null)
                            return null;
                        return new «emb.name.pojoType.name»(«fields.map['''«myName».get«name.toFirstUpper»()'''].join(', ')»);
                    }
                    public void set«myName.toFirstUpper()»(«emb.name.pojoType.name» _x) {
                        if (_x == null) {
                            «myName» = null;
                        } else {
                            «myName» = new «emb.name.name»();
                            «fields.map['''«myName».set«name.toFirstUpper»(_x.get«name.toFirstUpper»());'''].join('\n')»
                        }
                    }
                '''
            } else {
                // regular field
                func.apply(f, myName, currentIndex)
            }
        }
    }
    
    // a generic iterator over the fields of a specific class, plus certain super classes.
    // Using the new Xtend lambda expressions, which allows to separate looping logic from specific output formatting.
    // All inherited classes are recursed, until a "stop" class is encountered (which is used in case of JOIN inheritance).
    // The method takes two lambdas, one for the code generation of a field, a second optional one for output of group separators.
    def private static CharSequence recurseJ(ClassDefinition cl, ClassDefinition stopAt, boolean includeAggregates, (FieldDefinition) => boolean filterCondition,
        List<EmbeddableUse> embeddables,
        (ClassDefinition)=> CharSequence groupSeparator,
        (FieldDefinition, String, String) => CharSequence fieldOutput) '''
        «IF cl != stopAt»
            «cl.extendsClass?.classRef?.recurseJ(stopAt, includeAggregates, filterCondition, embeddables, groupSeparator, fieldOutput)»
            «groupSeparator?.apply(cl)»
            «FOR c : cl.fields»
                «IF (includeAggregates || !c.isAggregate || c.properties.hasProperty(PROP_UNROLL)) && filterCondition.apply(c)»
                    «c.writeFieldWithEmbeddedAndListJ(embeddables, null, null, null, false, false, "", fieldOutput)»
                «ENDIF»
            «ENDFOR»
        «ENDIF»
    '''
    
    // shorthand call for entities    
    def private CharSequence recurseColumns(ClassDefinition cl) '''
        cl.extendsClass?.classRef?.recurseColumns       // first, any parent class fields
        «FOR fld : cl.fields»
                    «fld.singleColumn»
                    «fld.writeGetter»
                    «fld.writeSetter»
                    «IF fld.properties.hasProperty(PROP_VERSION)»
                        «IF fld.JavaDataTypeNoName(false).equals("int") || fld.JavaDataTypeNoName(false).equals("Integer")»
                            «fld.setIntVersion»
                        «ENDIF»
                        // specific getter/setters for the version field
                        public void set$Version(«fld.JavaDataTypeNoName(false)» _v) {
                            set«fld.name.toFirstUpper»(_v);
                        }
                        public «fld.JavaDataTypeNoName(false)» get$Version() {
                            return get«fld.name.toFirstUpper»();
                        }
                    «ENDIF»
                    «IF fld.properties.hasProperty(PROP_ACTIVE)»
                        «setHaveActive»
                        // specific getter/setters for the active flag
                        public void set$Active(boolean _a) {
                            set«fld.name.toFirstUpper»(_a);
                        }
                        public boolean get$Active() {
                            return get«fld.name.toFirstUpper»();
                        }
                    «ENDIF»
        «ENDFOR» 
    '''

    
    def public static CharSequence recurseForCopyOf(ClassDefinition cl, ClassDefinition stopAt, List<FieldDefinition> excludes,
        (FieldDefinition, String, RequiredType) => CharSequence fieldOutput) '''
        «IF cl != stopAt»
            «cl.extendsClass?.classRef?.recurseForCopyOf(stopAt, excludes, fieldOutput)»
            «FOR c : cl.fields»
                «IF ((!c.isAggregate || c.properties.hasProperty(PROP_UNROLL)) && (excludes == null || !excludes.contains(c)) && !c.properties.hasProperty(PROP_NOJAVA))»
                    «c.writeFieldWithEmbeddedAndList(null, null, null, RequiredType::DEFAULT, false, "", fieldOutput)»
                «ENDIF»
            «ENDFOR»
        «ENDIF»
    '''
                    
    def private writeCopyOf(NoSQLEntityDefinition e, String pkType, String trackingType) '''
        @Override
        public BonoSQL mergeFrom(final BonoSQL _b) {
            «IF e.extends != null»
                super.mergeFrom(_b);
            «ENDIF»
            if (_b instanceof «e.name») {
                «e.name» _x = («e.name»)_b;
                «e.tenantClass?.recurseForCopyOf(null, null, [ fld, myName, req | '''«myName» = _x.«myName»;
                    '''])»
                «e.pojoType.recurseForCopyOf(e.extends?.pojoType, null, [ fld, myName, req | '''«myName» = _x.«myName»;
                    '''])»
            }
            return this;
        }
    '''
    
    def private static substitutedJavaTypeScalar(FieldDefinition i) {
        val ref = DataTypeExtension::get(i.datatype);
        if (ref.objectDataType != null) {
            if (i.properties.hasProperty(PROP_REF))
                return "Long"
        }
        return i.JavaDataTypeNoName(i.properties.hasProperty(PROP_UNROLL))
    }

    def private writeGetter(FieldDefinition i) {
        val myName = i.name
        val ref = DataTypeExtension::get(i.datatype);
        return '''
            public «i.substitutedJavaTypeScalar» get«myName.toFirstUpper»() «writeException(DataTypeExtension::get(i.datatype), i)»{
                «IF JAVA_OBJECT_TYPE.equals(ref.javaType) || (ref.objectDataType != null && hasProperty(i.properties, "serialized"))»
                    if («myName» == null)
                        return null;
                    ByteArrayParser _bap = new ByteArrayParser(«myName», 0, -1);
                    return «IF ref.objectDataType != null»(«JavaDataTypeNoName(i, false)»)«ENDIF»_bap.readObject("«myName»", «IF ref.objectDataType != null»«JavaDataTypeNoName(i, false)»«ELSE»BonaPortable«ENDIF».class, true, true);
                «ELSEIF ref.enumMaxTokenLength == DataTypeExtension::NO_ENUM»
                    «IF ref.category == DataCategory::OBJECT»
                        return «myName»;
                    «ELSEIF ref.javaType.equals("LocalDate")»
                        return «myName»«IF !useUserTypes» == null ? null : LocalDate.fromCalendarFields(«myName»)«ENDIF»;
                    «ELSEIF ref.javaType.equals("LocalDateTime")»
                        return «myName»«IF !useUserTypes» == null ? null : LocalDateTime.fromCalendarFields(«myName»)«ENDIF»;
                    «ELSEIF ref.javaType.equals("ByteArray")»
                        return «myName»«IF !useUserTypes» == null ? null : new ByteArray(«myName», 0, -1)«ENDIF»;
                    «ELSEIF ref.javaType.equals("byte []")»
                        return ByteUtil.deepCopy(«myName»);       // deep copy
                    «ELSE»
                        return «myName»;
                    «ENDIF»
                «ELSEIF ref.enumMaxTokenLength == DataTypeExtension::ENUM_NUMERIC || !ref.allTokensAscii»
                    return «ref.elementaryDataType.enumType.name».valueOf(«myName»);
                «ELSE»
                    return «ref.elementaryDataType.enumType.name».factory(«myName»);
                «ENDIF»
            }
        '''
    }

    def private writeSetter(FieldDefinition i) {
        val myName = i.name
        val ref = DataTypeExtension::get(i.datatype);
        return '''
            public void set«myName.toFirstUpper»(«i.substitutedJavaTypeScalar» «myName») {
                «IF JAVA_OBJECT_TYPE.equals(ref.javaType) || (ref.objectDataType != null && hasProperty(i.properties, "serialized"))»
                    if («myName» == null) {
                        this.«myName» = null;
                    } else {
                        ByteArrayComposer _bac = new ByteArrayComposer();
                        _bac.addField(«myName»);
                        this.«myName» = _bac.getBytes();
                    }
                «ELSEIF ref.enumMaxTokenLength == DataTypeExtension::NO_ENUM»
                    «IF ref.category == DataCategory::OBJECT»
                        this.«myName» = «myName»;
                    «ELSEIF ref.javaType.equals("LocalDate") || ref.javaType.equals("LocalDateTime")»
                        this.«myName» = «IF useUserTypes»«myName»«ELSE»DayTime.toGregorianCalendar(«myName»)«ENDIF»;
                    «ELSEIF ref.javaType.equals("ByteArray")»
                        this.«myName» = «IF useUserTypes»«myName»«ELSE»«myName» == null ? null : «myName».getBytes()«ENDIF»;
                    «ELSEIF ref.javaType.equals("byte []")»
                        this.«myName» = ByteUtil.deepCopy(«myName»);       // deep copy
                    «ELSE»
                        this.«myName» = «myName»;
                    «ENDIF»
                «ELSEIF ref.enumMaxTokenLength == DataTypeExtension::ENUM_NUMERIC || !ref.allTokensAscii»
                     this.«myName» = «myName» == null ? null : «myName».ordinal();
                «ELSE»
                    this.«myName» = «myName» == null ? null : «myName».getToken();
                «ENDIF»
            }
        '''
    }

    def private static writeException(DataTypeExtension ref, FieldDefinition c) {
        if (ref.enumMaxTokenLength != DataTypeExtension::NO_ENUM)
            return "throws EnumException "
        else if (JAVA_OBJECT_TYPE.equals(ref.javaType) || (ref.objectDataType != null && hasProperty(c.properties, "serialized"))) {
            return "throws MessageParserException "
        } else
            return ""
    }


    // provide getter / setter for version and active for all entities. Reason is that we can then use them in generic methods without checking
    def private writeStubs(NoSQLEntityDefinition e) '''
        «IF e.^extends == null»
            «writeRtti(e.pojoType)»
            «IF !haveActive»
                // no isActive column in this entity, create stubs to satisfy interface
                public void set$Active(boolean _a) {
                    // throw new RuntimeException("Entity «e.name» does not have an isActive field");
                }
                public boolean get$Active() {
                    return true;  // no isActive column => all rows are active by default
                }
            «ENDIF»
            «IF haveIntVersion == null»
                // no version column of type int or Integer, write stub
                public void set$IntVersion(int _v) {
                    // throw new RuntimeException("Entity «e.name» does not have an integer type version field");
                }
                public int get$IntVersion() {
                    return -1;
                }
            «ELSE»
                // version column of type int or Integer exists, write proxy
                public void set$IntVersion(int _v) {
                    set«haveIntVersion.name.toFirstUpper»(_v);
                }
                public int get$IntVersion() {
                    return get«haveIntVersion.name.toFirstUpper»();
                }
            «ENDIF»
        «ENDIF»
    '''

    def private writeInterfaceMethods(NoSQLEntityDefinition e, String pkType, String trackingType) '''
        «IF e.^extends == null»
        public static Class<«trackingType»> class$TrackingClass() {
            «IF e.tableCategory.trackingColumns == null»
                return null;
            «ELSE»
                return «trackingType».class;
            «ENDIF»
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

        public static Class<«pkType»> class$KeyClass() {
            return «pkType».class;
        }
        @Override
        public Class<«pkType»> get$KeyClass() {
            return «pkType».class;
        }
        
        @Override
        public «trackingType» get$Tracking() throws ApplicationException {
            «IF e.tableCategory.trackingColumns == null»
                return null;
            «ELSE»
                «e.tableCategory.trackingColumns.name» _r = new «e.tableCategory.trackingColumns.name»();
                «e.tableCategory.trackingColumns.recurseDataGetter(null, null)»
                return _r;
            «ENDIF»
        }
        @Override
        public void set$Tracking(«trackingType» _d) {
            // TODO
        }
        «ENDIF»
    '''

    // TODO: does not work for embeddables!  Would need dot notation for that 
    def private CharSequence writeStaticFindByMethods(ClassDefinition cl, NoSQLEntityDefinition e) {
        recurse(cl, null, false, [ true ], null, [ '''''' ], [ fld, myName, req | '''
                «IF fld.properties.hasProperty(PROP_FINDBY)»
                    public static «e.name» findBy«myName.toFirstUpper»(EntityManager _em, «fld.JavaDataTypeNoName(false)» _key) {
                        try {
                            TypedQuery<«e.name»> _query = _em.createQuery("SELECT u FROM «e.name» u WHERE u.«myName» = ?1", «e.name».class);
                            return _query.setParameter(1, _key).getSingleResult();
                        } catch (NoResultException e) {
                            return null;
                        }
                    }
                «ELSEIF fld.properties.hasProperty(PROP_LISTBY)»
                    public static List<«e.name»> listBy«myName.toFirstUpper»(EntityManager _em, «fld.JavaDataTypeNoName(false)» _key) {
                        try {
                            TypedQuery<«e.name»> _query = _em.createQuery("SELECT u FROM «e.name» u WHERE u.«myName» = ?1", «e.name».class);
                            return _query.setParameter(1, _key).getResultList();
                        } catch (NoResultException e) {
                            return null;
                        }
                    }
                «ENDIF»
                «IF fld.properties.hasProperty(PROP_LIACBY)»
                    public static List<«e.name»> listBy«myName.toFirstUpper»(EntityManager _em, «fld.JavaDataTypeNoName(false)» _key) {
                        try {
                            TypedQuery<«e.name»> _query = _em.createQuery("SELECT u FROM «e.name» u WHERE u.«myName» = ?1 AND isActive = true", «e.name».class);
                            return _query.setParameter(1, _key).getResultList();
                        } catch (NoResultException e) {
                            return null;
                        }
                    }
                «ENDIF»
            ''']
        )
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
    

    def private javaEntityOut(NoSQLEntityDefinition e) {
        val String myPackageName = getPackageName(e)
        val ImportCollector imports = new ImportCollector(myPackageName)
        val myPackage = e.eContainer as PackageDefinition

        imports.recurseImports(e.tableCategory.trackingColumns, true)
        imports.recurseImports(e.pojoType, true)
        // reset tracking flags
        haveIntVersion = null
        haveActive = false
        fieldVisibility = makeVisibility(if (e.visibility != null) e.visibility else myPackage.visibility)
        useUserTypes = !myPackage.noUserTypes

        imports.addImport(myPackageName, e.name)  // add myself as well
        imports.addImport(e.pojoType);  // TODO: not needed, see above?
        imports.addImport(e.tableCategory.trackingColumns);
        if (e.^extends != null) {
            imports.addImport(getPackageName(e.^extends), e.^extends.name)
        }
        imports.addImport(e.pkPojo)
        

        var String trackingType = "BonaPortable"
        val String pkType = e.pkPojo.name
        if (e.tableCategory.trackingColumns != null) {
            trackingType = e.tableCategory.trackingColumns.name
        }
        return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git
        package «getPackageName(e)»;

        «writeDefaultImports»
        import java.io.Serializable;
        import com.datastax.driver.core.Session;
        import com.datastax.driver.core.PreparedStatement;
        import com.datastax.driver.core.BoundStatement;

        import de.jpaw.bonaparte.datastax.KeyClass;
        import de.jpaw.bonaparte.datastax.DataClass;
        import de.jpaw.bonaparte.datastax.TrackingClass;
        import de.jpaw.bonaparte.datastax.BonoSQL;
        import «bonaparteInterfacesPackage».BonaPortable;
        import «bonaparteInterfacesPackage».ByteArrayComposer;
        import «bonaparteInterfacesPackage».ByteArrayParser;
        import «bonaparteInterfacesPackage».MessageParserException;
        «imports.createImports»

        «IF e.javadoc != null»
            «e.javadoc»
        «ENDIF»
        @DataClass(«e.pojoType.name».class)
        «IF e.tableCategory.trackingColumns != null»
            @TrackingClass(«e.tableCategory.trackingColumns.name».class)
        «ENDIF»
        @KeyClass(«pkType».class)
            
        «IF e.isDeprecated || e.pojoType.isDeprecated»
            @Deprecated
        «ENDIF»
        public class «e.name»«IF e.^extends != null» extends «e.^extends.name»«ELSE» implements BonoSQL<«pkType»,«e.pojoType.name»,«e.name»>«IF e.implementsInterface != null», «e.implementsInterface»«ENDIF»«ENDIF» {
            private static final String SAVE_CQL = "UPDATE «e.mkTablename(false)» SET";
            
            «e.tableCategory.trackingColumns?.recurseColumns»
            «e.tenantClass?.recurseColumns»
            «e.pojoType.recurseColumns»
            
            «writeStubs(e)»
            «writeInterfaceMethods(e, pkType, trackingType)»
            «writeStaticFindByMethods(e.pojoType, e)»
            «e.writeCopyOf(pkType, trackingType)»
            
            @Override
            public void save(Session _s) {
                PreparedStatement _stmt = _s.prepare(SAVE_CQL);
                BoundStatement _b = _stmt.bind();
                //...
                _s.execute(_b)
            }
        }
        '''
    }
    
}
