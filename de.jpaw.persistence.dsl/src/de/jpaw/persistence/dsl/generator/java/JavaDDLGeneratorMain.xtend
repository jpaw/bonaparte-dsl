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
import static extension de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*
import static extension de.jpaw.bonaparte.dsl.generator.java.JavaRtti.*
import static extension de.jpaw.persistence.dsl.generator.YUtil.*
import de.jpaw.persistence.dsl.bDDL.PackageDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.java.ImportCollector
import de.jpaw.bonaparte.dsl.bonScript.PropertyUse
import java.util.List
import de.jpaw.persistence.dsl.bDDL.Inheritance
import de.jpaw.bonaparte.dsl.bonScript.XVisibility
import de.jpaw.bonaparte.dsl.bonScript.Visibility
import de.jpaw.bonaparte.dsl.generator.java.JavaBeanValidation
import de.jpaw.persistence.dsl.bDDL.EmbeddableDefinition
import de.jpaw.persistence.dsl.bDDL.EmbeddableUse
import de.jpaw.persistence.dsl.bDDL.ElementCollectionRelationship
import java.util.ArrayList
import de.jpaw.persistence.dsl.generator.RequiredType
import de.jpaw.persistence.dsl.generator.PrimaryKeyType
import javax.lang.model.type.PrimitiveType

class JavaDDLGeneratorMain implements IGenerator {
    val static final String JAVA_OBJECT_TYPE = "BonaPortable";
    val static final String CALENDAR = "Calendar";
    val static final EMPTY_ELEM_COLL = new ArrayList<ElementCollectionRelationship>(0);
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
    def public static getPackageName(EntityDefinition d) {
        getPackageName(d.eContainer as PackageDefinition)
    }
    // create the package name for an embeddable object
    def public static getPackageName(EmbeddableDefinition d) {
        getPackageName(d.eContainer as PackageDefinition)
    }

    override void doGenerate(Resource resource, IFileSystemAccess fsa) {
        // java
        for (e : resource.allContents.toIterable.filter(typeof(EntityDefinition))) {
            if (!e.noJava && !(e.eContainer as PackageDefinition).noJava) {
                val primaryKeyType = determinePkType(e)
                if (primaryKeyType == PrimaryKeyType::IMPLICIT_EMBEDDABLE) {
                    // write a separate class for the composite key
                    fsa.generateFile(getJavaFilename(getPackageName(e), e.name + "Key"), e.javaKeyOut)
                }
                fsa.generateFile(getJavaFilename(getPackageName(e), e.name), e.javaEntityOut(primaryKeyType))
            }
        }
        for (e : resource.allContents.toIterable.filter(typeof(EmbeddableDefinition))) {
            fsa.generateFile(getJavaFilename(getPackageName(e), e.name), e.javaEmbeddableOut)
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

    def private writeColumnType(FieldDefinition c, String myName) {
        val DataTypeExtension ref = DataTypeExtension::get(c.datatype)
        if (ref.objectDataType != null) {
            if (c.properties.hasProperty("serialized")) {
                // use byte[] Java type and assume same as Object
                return '''
                    «fieldVisibility»byte [] «myName»;'''
            } else if (c.properties.hasProperty(PROP_REF)) {
                // plain old Long as an artificial key / referencing is done by application
                // can optionally have a ManyToOne object mapping in a Java superclass, with insertable=false, updatable=false
                return '''
                    «fieldVisibility»Long «myName»;'''
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
                    «fieldVisibility»«c.JavaDataTypeNoName(false)» «myName»;'''
            }
        }
        switch (ref.enumMaxTokenLength) {
        case DataTypeExtension::NO_ENUM:
            switch (ref.javaType) {
            case "Calendar":        writeTemporalFieldAndAnnotation(c, "TIMESTAMP", CALENDAR, myName)
            case "DateTime":        writeTemporalFieldAndAnnotation(c, "DATE", CALENDAR, myName)
            case "LocalDateTime":   if (useUserTypes)
                                        writeField(c, ref.javaType, myName)
                                    else
                                        writeTemporalFieldAndAnnotation(c, "TIMESTAMP", CALENDAR, myName)
            case "LocalDate":       if (useUserTypes)
                                        writeField(c, ref.javaType, myName)
                                    else
                                        writeTemporalFieldAndAnnotation(c, "DATE", CALENDAR, myName)
            case "ByteArray":       writeField(c, if (useUserTypes) "ByteArray" else "byte []", myName)
            case JAVA_OBJECT_TYPE:  '''
                                        // @Lob
                                        «writeField(c, "byte []", myName)»
                                    '''
            default:                '''
                                        «fieldVisibility»«JavaDataTypeNoName(c, c.properties.hasProperty(PROP_UNROLL))» «myName»;
                                    '''
            }
        case DataTypeExtension::ENUM_NUMERIC:   writeField(c, "Integer", myName)
        default:                                writeField(c, if (ref.allTokensAscii) "String" else "Integer", myName)
        }
    }


    def private optionalAnnotation(List <PropertyUse> properties, String key, String annotation) {
        '''«IF properties.hasProperty(key)»«annotation»«ENDIF»'''
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
    def private sizeSpec(FieldDefinition c) {
        val ref = DataTypeExtension::get(c.datatype);
        if (ref.category == DataCategory::STRING)
            return ''', length=«ref.elementaryDataType.length»'''
        if (ref.elementaryDataType != null && ref.elementaryDataType.name.toLowerCase.equals("decimal"))
            return ''', precision=«ref.elementaryDataType.length», scale=«ref.elementaryDataType.decimals»'''
        return ''''''
    }
    
    // write the definition of a single column (entities or Embeddables)
    def private singleColumn(FieldDefinition c, List <ElementCollectionRelationship> el, boolean withBeanVal, String myName) '''
        «IF el != null && c.aggregate»
            «ElementCollections::writePossibleCollectionOrRelation(c, el)»
        «ENDIF»
        @Column(name="«myName.java2sql»"«IF XUtil::isRequired(c)», nullable=false«ENDIF»«c.sizeSpec»«IF hasProperty(c.properties, "noinsert")», insertable=false«ENDIF»«IF hasProperty(c.properties, "noupdate")», updatable=false«ENDIF»)
        «c.properties.optionalAnnotation("version", "@Version")»
        «c.properties.optionalAnnotation("lob",     "@Lob")»
        «c.properties.optionalAnnotation("lazy",    "@Basic(fetch=LAZY)")»
        «JavaBeanValidation::writeAnnotations(c, DataTypeExtension::get(c.datatype), withBeanVal)»
        «c.writeColumnType(myName)»
    '''

    def private boolean inList(List<FieldDefinition> pkColumns, FieldDefinition c) {
        for (i : pkColumns)
            if (i == c)
                return true
        return false
    }

    def private hasECin(FieldDefinition c, List <ElementCollectionRelationship> el) {
        el != null && el.map[name].contains(c)
        /*        
        val result = e.elementCollections != null && e.elementCollections.map[name].contains(c)
        System::out.println('''Testing for «c.name» in «e.name» gives «result»''')
        return result  */        
    }
    
    // didn't work:
    def private static CharSequence onlyLoopUnroll(List<FieldDefinition> l, String prefix, String suffix, (String, String) => CharSequence func) {
        l.map[ f |
            val myName = f.name.asEmbeddedName(prefix, suffix)
            if (f.properties.hasProperty(PROP_UNROLL)) {
                val indexPattern = f.indexPattern;
                (1 .. f.isList.maxcount).map[String::format(indexPattern, it)].map[func.apply(f.name + it, myName + it)].join(',\n')
            } else {
                func.apply(f.name, myName)
            }
        ].join('\n')
    }
    // «fields.onlyLoopUnroll(prefix, suffix, [ fldName, myName2 | '''@AttributeOverride(name="«fldName»", column=@Column(name="«myName2.java2sql»"))'''])»
    
    // output a single field (which maybe expands to multiple DB columns due to embeddables and List expansion. The field could be used from an entity or an embeddable
    def private static CharSequence writeFieldWithEmbeddedAndListJ(FieldDefinition f, List<EmbeddableUse> embeddables,
            String prefix, String suffix, String currentIndex,
            boolean noListAtThisPoint, boolean noList2, String separator, (FieldDefinition, String, String) => CharSequence func) {
        // expand Lists first
        val myName = f.name.asEmbeddedName(prefix, suffix)
        if (!noListAtThisPoint && f.isList != null && f.isList.maxcount > 0 && f.properties.hasProperty(PROP_UNROLL)) {
            val indexPattern = f.indexPattern;
            return '''
                «(1 .. f.isList.maxcount).map[f.writeFieldWithEmbeddedAndListJ(embeddables, prefix, '''«suffix»«String::format(indexPattern, it)»''', String::format(indexPattern, it), true, false, separator, func)].join(separator)»
                «IF noList2 == false»
                    public «f.JavaDataTypeNoName(false)» get«myName.toFirstUpper()»() {
                        «f.JavaDataTypeNoName(false)» _a = new Array«f.JavaDataTypeNoName(false)»(«f.isList.maxcount»);
                        «(1 .. f.isList.maxcount).map['''_a.add(get«myName.toFirstUpper»«String::format(indexPattern, it)»());'''].join('\n')»
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
    def private CharSequence recurseColumns(ClassDefinition cl, ClassDefinition stopAt, EntityDefinition e,
        List<FieldDefinition> pkColumns, PrimaryKeyType primaryKeyType) {
        cl.recurseColumns(stopAt, e.elementCollections, e.embeddables, e.tableCategory.doBeanVal, pkColumns, primaryKeyType);
    }
    
    def private CharSequence recurseColumns(ClassDefinition cl, ClassDefinition stopAt,
        List<ElementCollectionRelationship> el, List<EmbeddableUse> embeddables, boolean doBeanVal,
        List<FieldDefinition> pkColumns, PrimaryKeyType primaryKeyType
    ) {
        // include aggregates if there is an @ElementCollection defined for them
        //        «IF embeddables?.filter[isPk != null].head?.field == fld»
        //            @EmbeddedId
        //        «ENDIF»
        recurseJ(cl, stopAt, true, [ !isAggregate || hasECin(el) || properties.hasProperty(PROP_UNROLL) ], embeddables,
            [ '''// table columns of java class «name»
            ''' ], [ fld, myName, ind | '''
                «IF (primaryKeyType == PrimaryKeyType::SINGLE_COLUMN || primaryKeyType == PrimaryKeyType::ID_CLASS) && pkColumns.map[name].contains(fld.name)»
                    @Id
                «ENDIF»
                «IF (primaryKeyType != PrimaryKeyType::IMPLICIT_EMBEDDABLE || !inList(pkColumns, fld)) && !fld.properties.hasProperty(PROP_NOJAVA)»
                    «fld.singleColumn(el, doBeanVal, myName)»
                    «fld.writeGetter(myName)»
                    «fld.writeSetter(myName)»
                    «IF fld.properties.hasProperty(PROP_VERSION)»
                        «IF fld.JavaDataTypeNoName(false).equals("int") || fld.JavaDataTypeNoName(false).equals("Integer")»
                            «fld.setIntVersion»
                        «ENDIF»
                        // specific getter/setters for the version field
                        public void set$Version(«fld.JavaDataTypeNoName(false)» _v) {
                            set«myName.toFirstUpper»(_v);
                        }
                        public «fld.JavaDataTypeNoName(false)» get$Version() {
                            return get«myName.toFirstUpper»();
                        }
                    «ENDIF»
                    «IF fld.properties.hasProperty(PROP_ACTIVE)»
                        «setHaveActive»
                        // specific getter/setters for the active flag
                        public void set$Active(boolean _a) {
                            set«myName.toFirstUpper»(_a);
                        }
                        public boolean get$Active() {
                            return get«myName.toFirstUpper»();
                        }
                    «ENDIF»
                «ENDIF»
        ''']
        )
    }

    
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
                    
    def private writeCopyOf(EntityDefinition e, String pkType, String trackingType) '''
        @Override
        public BonaPersistableBase mergeFrom(final BonaPersistableBase _b) {
            «IF e.extends != null»
                super.mergeFrom(_b);
            «ENDIF»
            if (_b instanceof «e.name») {
                «e.name» _x = («e.name»)_b;
                «IF e.extends == null && e.pk?.columnName != null»
                    «FOR f: e.pk?.columnName»
                        set«f.name.toFirstUpper»(_x.get«f.name.toFirstUpper»());
                    «ENDFOR»
                «ENDIF»
                «e.tenantClass?.recurseForCopyOf(null, e.pk?.columnName, [ fld, myName, req | '''«myName» = _x.«myName»;
                    '''])»
                «e.pojoType.recurseForCopyOf(e.extends?.pojoType, e.pk?.columnName, [ fld, myName, req | '''«myName» = _x.«myName»;
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

    def private writeGetter(FieldDefinition i, String myName) {
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

    def private writeSetter(FieldDefinition i, String myName) {
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

    // provide getter / setter for version and active for all entities. Reason is that we can then use them in generic methods without checking
    def private writeStubs(EntityDefinition e) '''
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

    def private writeInterfaceMethods(EntityDefinition e, String pkType, String trackingType) '''
        «IF e.^extends == null»
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

        «IF !e.noDataKeyMapper»
        @Override
        public «pkType» get$Key() throws ApplicationException {
            «IF pkType.equals("Serializable")»
                return null;  // FIXME! not yet implemented!
            «ELSE»
                «IF e.embeddablePk != null»
                    return get«e.embeddablePk.field.name.toFirstUpper»();
                «ELSEIF e.pkPojo != null»
                    return new «e.pkPojo.name»(«e.pkPojo.fields.map['''get«name.toFirstUpper»()'''].join(', ')»);
                «ELSEIF e.pk.columnName.size > 1»
                    return key.clone(); // as our key fields are all immutable, shallow copy is sufficient
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
                «IF e.embeddablePk != null»
                    set«e.embeddablePk.field.name.toFirstUpper»(_k);
                «ELSEIF e.pkPojo != null»
                    «FOR f: e.pkPojo.fields»
                        set«f.name.toFirstUpper»(_k.get«f.name.toFirstUpper»());
                    «ENDFOR»
                «ELSEIF e.pk.columnName.size > 1»
                    key = _k.clone();   // as our key fields are all immutable, shallow copy is sufficient
                «ELSE»
                    set«e.pk.columnName.get(0).name.toFirstUpper»(_k);  // no direct assigned due to possible enum or temporal type, with implied conversions
                «ENDIF»
            «ENDIF»
        }
        «ENDIF»
        
        @Override
        public «trackingType» get$Tracking() throws ApplicationException {
            «IF e.tableCategory.trackingColumns == null»
                return null;
            «ELSE»
                «e.tableCategory.trackingColumns.name» _r = new «e.tableCategory.trackingColumns.name»();
                «recurseDataGetter(e.tableCategory.trackingColumns, null, e.embeddables)»
                return _r;
            «ENDIF»
        }
        @Override
        public void set$Tracking(«trackingType» _d) {
            «IF e.tableCategory.trackingColumns != null»
                «recurseDataSetter(e.tableCategory.trackingColumns, null, null, e.embeddables)»
            «ENDIF»
        }
        «ENDIF»
    '''

    // TODO: does not work for embeddables!  Would need dot notation for that 
    def private CharSequence writeStaticFindByMethods(ClassDefinition cl, ClassDefinition stopAt, EntityDefinition e) {
        recurse(cl, stopAt, false, [ true ], e.embeddables, [ '''''' ], [ fld, myName, req | '''
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

    def private i2s(Inheritance i) {
        switch (i) {
        case Inheritance::SINGLE_TABLE: return "SINGLE_TABLE"
        case Inheritance::JOIN: return "JOINED"
        case Inheritance::TABLE_PER_CLASS: return "TABLE_PER_CLASS"
        }
    }

    def private static noDataMapper(EntityDefinition e) {
        e.noMapper || (e.eContainer as PackageDefinition).noMapper || e.noDataKeyMapper
    }

    def private static noDataKeyMapper(EntityDefinition e) {
        e.noKeyMapper || (e.eContainer as PackageDefinition).noKeyMapper
    }
    
    def private wrImplements(EntityDefinition e, String pkType, String trackingType) {
        if (e.noDataKeyMapper)
            '''BonaPersistableTracking<«trackingType»>'''
        else if (e.noDataMapper)
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
    
    def private static createUniqueConstraints(EntityDefinition e) '''
        «IF !e.index.filter[isUnique].empty»
            , uniqueConstraints={
            «e.index.filter[isUnique].map['''    @UniqueConstraint(columnNames={«columns.columnName.map['''"«name.java2sql»"'''].join(', ')»})'''].join(',\n')»
            }«ENDIF»'''

    def private javaEntityOut(EntityDefinition e, PrimaryKeyType primaryKeyType) {
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
        imports.addImport(e.pojoType);  // TODO: not needed, see above?
        imports.addImport(e.tableCategory.trackingColumns);
        if (e.^extends != null) {
            imports.addImport(getPackageName(e.^extends), e.^extends.name)
            stopper = e.^extends.pojoType
        }
        // imports for ManyToOne
        for (r : e.manyToOnes)
            imports.addImport(r.childObject.getPackageName, r.childObject.name)
        // for OneToMany
        for (r : e.oneToManys)
            imports.addImport(r.relationship.childObject.getPackageName, r.relationship.childObject.name)
        // for OneToOne
        for (r : e.oneToOnes)
            imports.addImport(r.relationship.childObject.getPackageName, r.relationship.childObject.name)
        // for Embeddables
        for (r : e.embeddables) {
            imports.addImport(r.name.getPackageName, r.name.name)  // the Entity
            //imports.addImport(r.name.pojoType.getPackageName, r.name.pojoType.name)  // the BonaPortable
            imports.recurseImports(e.pojoType, true)
        }
        imports.addImport(e.pkPojo)
        

        var List<FieldDefinition> pkColumns = null
        var String pkType0 = null
        var String trackingType = "BonaPortable"
        if (e.countEmbeddablePks > 0) {
            pkType0 = e.embeddablePk.name.pojoType.name
            pkColumns = e.embeddablePk.name.pojoType.fields
        } else if (e.pk != null) {
            pkColumns = e.pk.columnName
            if (pkColumns.size > 1)
                pkType0 = e.name + "Key"
            else
                pkType0 = pkColumns.get(0).JavaDataTypeNoName(true)
        } else if (e.pkPojo != null) {
            pkColumns = e.pkPojo.fields
            pkType0 = e.pkPojo.name 
        }
        val String pkType = pkType0 ?: "Serializable"
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
        import javax.persistence.CascadeType;
        import javax.persistence.Id;
        import javax.persistence.IdClass;
        import javax.persistence.Temporal;
        import javax.persistence.TemporalType;
        import javax.persistence.NoResultException;
        import javax.persistence.TypedQuery;
        import javax.persistence.EmbeddedId;
        import javax.persistence.Embedded;
        import javax.persistence.ManyToOne;
        import javax.persistence.OneToMany;
        import javax.persistence.OneToOne;
        import javax.persistence.FetchType;
        import javax.persistence.CascadeType;
        import javax.persistence.MapKey;
        import javax.persistence.MapKeyJoinColumn;
        import javax.persistence.JoinColumn;
        import javax.persistence.JoinColumns;
        import javax.persistence.ElementCollection;
        import javax.persistence.MapKeyColumn;
        import javax.persistence.CollectionTable;
        import javax.persistence.EntityListeners;
        import javax.persistence.UniqueConstraint;
        import javax.persistence.AttributeOverride;
        import javax.persistence.AttributeOverrides;
        «JavaBeanValidation::writeImports(e.tableCategory.doBeanVal)»
        «writeDefaultImports»
        import java.io.Serializable;

        import de.jpaw.bonaparte.jpa.BonaPersistableNoData;
        import de.jpaw.bonaparte.jpa.BonaPersistableTracking;
        import de.jpaw.bonaparte.jpa.BonaPersistableBase;
        import de.jpaw.bonaparte.jpa.BonaPersistable;
        import de.jpaw.bonaparte.jpa.KeyClass;
        import de.jpaw.bonaparte.jpa.DataClass;
        import de.jpaw.bonaparte.jpa.TrackingClass;
        import de.jpaw.bonaparte.jpa.BonaPersistable;
        import «bonaparteInterfacesPackage».BonaPortable;
        import «bonaparteInterfacesPackage».ByteArrayComposer;
        import «bonaparteInterfacesPackage».ByteArrayParser;
        import «bonaparteInterfacesPackage».MessageParserException;
        «imports.createImports»

        «IF e.javadoc != null»
            «e.javadoc»
        «ENDIF»
        «IF e.isAbstract || e.mappedSuperclass»
            @MappedSuperclass
        «ELSE»
            @DataClass(«e.pojoType.name».class)
            «IF e.tableCategory.trackingColumns != null»
                @TrackingClass(«e.tableCategory.trackingColumns.name».class)
            «ENDIF»
            «IF pkType0 != null»
                @KeyClass(«pkType0».class)
            «ENDIF»
            @Entity
            «IF e.tableCategory.autoSetter != null»
                @EntityListeners({«e.tableCategory.autoSetter».class})
            «ENDIF»
            «IF e.cacheable»
                @Cacheable(true)
            «ENDIF»
            «IF e.cacheSize != 0»
                @Cache(size=«e.cacheSize», expiry=«scaledExpiry(e.cacheExpiry, e.cacheExpiryScale)»000)
            «ENDIF»
            @Table(name="«mkTablename(e, false)»"«e.createUniqueConstraints»)
            «IF primaryKeyType == PrimaryKeyType::ID_CLASS»
                @IdClass(«e.pkPojo.name».class)
            «ENDIF»
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
            «IF stopper == null && primaryKeyType == PrimaryKeyType::IMPLICIT_EMBEDDABLE»
                @EmbeddedId
                «fieldVisibility»«e.name»Key key;
                // forwarding getters and setters
                «FOR i:e.pk.columnName»
                    public void set«i.name.toFirstUpper»(«i.substitutedJavaTypeScalar» _x) {
                        key.set«i.name.toFirstUpper»(_x);
                    }
                    public «i.substitutedJavaTypeScalar» get«i.name.toFirstUpper»() {
                        return key.get«i.name.toFirstUpper»();
                    }
                «ENDFOR»

            «ENDIF»
            «IF stopper == null»«e.tableCategory.trackingColumns?.recurseColumns(null, e, pkColumns, primaryKeyType)»«ENDIF»
            «e.tenantClass?.recurseColumns(null, e, pkColumns, primaryKeyType)»
            «e.pojoType.recurseColumns(stopper, e, pkColumns, primaryKeyType)»
            «IF stopper == null»«EqualsHash::writeEqualsAndHashCode(e, primaryKeyType)»«ENDIF»
            «writeStubs(e)»
            «writeInterfaceMethods(e, pkType, trackingType)»
            «IF (!e.noDataMapper)»
                «MakeMapper::writeMapperMethods(e, pkType, trackingType)»
            «ENDIF»
            «writeStaticFindByMethods(e.pojoType, stopper, e)»
            «e.writeCopyOf(pkType, trackingType)»
            «MakeRelationships::writeRelationships(e, fieldVisibility)»
        }
        '''
    }
    def private javaKeyOut(EntityDefinition e) {
        val String myPackageName = getPackageName(e)
        val String myName = e.name + "Key"
        val ImportCollector imports = new ImportCollector(myPackageName)
        imports.recurseImports(e.pojoType, true)

        imports.addImport(myPackageName, myName)  // add myself as well

        return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git
        package «getPackageName(e)»;

        import javax.persistence.EntityManager;
        import javax.persistence.Embeddable;
        import javax.persistence.Embedded;
        import javax.persistence.Column;
        import javax.persistence.EmbeddedId;
        import javax.persistence.Temporal;
        import javax.persistence.TemporalType;
        import javax.persistence.ManyToOne;
        import javax.persistence.JoinColumn;
        import javax.persistence.FetchType;
        import javax.persistence.CascadeType;
        «JavaBeanValidation::writeImports(e.tableCategory.doBeanVal)»
        «writeDefaultImports»
        import java.io.Serializable;

        import «bonaparteInterfacesPackage».BonaPortable;
        import «bonaparteInterfacesPackage».ByteArrayComposer;
        import «bonaparteInterfacesPackage».ByteArrayParser;
        import «bonaparteInterfacesPackage».MessageParserException;
        «imports.createImports»

        @Embeddable
        public class «myName» implements Serializable, Cloneable {
            «FOR col : e.pk.columnName»
                «col.writeColStuff(e, e.tableCategory.doBeanVal, col.name)»
            «ENDFOR»
            «EqualsHash::writeHash(null, e.pk.columnName)»
            «EqualsHash::writeKeyEquals(myName, e.pk.columnName)»
            «writeCloneable(myName)»
        }
        '''
    }
    
    def private javaEmbeddableOut(EmbeddableDefinition e) {
        val String myPackageName = getPackageName(e)
        val String myName = e.name
        val ImportCollector imports = new ImportCollector(myPackageName)
        imports.recurseImports(e.pojoType, true)

        imports.addImport(myPackageName, e.name)  // add myself as well

        return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git
        package «getPackageName(e)»;

        import javax.persistence.EntityManager;
        import javax.persistence.Embeddable;
        import javax.persistence.Embedded;
        import javax.persistence.Column;
        import javax.persistence.EmbeddedId;
        import javax.persistence.Temporal;
        import javax.persistence.TemporalType;
        import javax.persistence.ManyToOne;
        import javax.persistence.JoinColumn;
        import javax.persistence.FetchType;
        import javax.persistence.CascadeType;
        «JavaBeanValidation::writeImports(e.doBeanVal)»
        «writeDefaultImports»
        import java.io.Serializable;

        import «bonaparteInterfacesPackage».BonaPortable;
        import «bonaparteInterfacesPackage».ByteArrayComposer;
        import «bonaparteInterfacesPackage».ByteArrayParser;
        import «bonaparteInterfacesPackage».MessageParserException;
        «imports.createImports»

        @Embeddable
        public class «e.name» implements Serializable, Cloneable {
            «e.pojoType.recurseColumns(null, EMPTY_ELEM_COLL, e.embeddables, e.doBeanVal, null, PrimaryKeyType::NONE)»
            «EqualsHash::writeHash(e.pojoType, null)»
            «EqualsHash::writeKeyEquals(e.name, e.pojoType.fields)»
            «writeCloneable(myName)»
        }
        '''
    }
    
    def private static writeCloneable(String name) '''
        @Override
        public «name» clone() {
            try {
                return («name»)super.clone();
            } catch (CloneNotSupportedException e) {
                return this;  // fallback
            }
        }
    '''
    
   
    def private writeColStuff(FieldDefinition f, EntityDefinition optionalEntity, boolean doBeanVal, String myName) '''
        «f.singleColumn(optionalEntity.elementCollections, doBeanVal, myName)»
        «f.writeGetter(myName)»
        «f.writeSetter(myName)»
    '''
}
