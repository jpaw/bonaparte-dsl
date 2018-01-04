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
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition
import de.jpaw.bonaparte.dsl.generator.Util
import de.jpaw.bonaparte.dsl.generator.java.ImportCollector
import de.jpaw.bonaparte.dsl.generator.java.JavaBeanValidation
import de.jpaw.bonaparte.jpa.dsl.BDDLPreferences
import de.jpaw.bonaparte.jpa.dsl.bDDL.BDDLPackageDefinition
import de.jpaw.bonaparte.jpa.dsl.bDDL.ColumnNameMappingDefinition
import de.jpaw.bonaparte.jpa.dsl.bDDL.ConverterDefinition
import de.jpaw.bonaparte.jpa.dsl.bDDL.ElementCollectionRelationship
import de.jpaw.bonaparte.jpa.dsl.bDDL.EmbeddableDefinition
import de.jpaw.bonaparte.jpa.dsl.bDDL.EmbeddableUse
import de.jpaw.bonaparte.jpa.dsl.bDDL.EntityDefinition
import de.jpaw.bonaparte.jpa.dsl.bDDL.GraphRelationship
import de.jpaw.bonaparte.jpa.dsl.bDDL.IndexDefinition
import de.jpaw.bonaparte.jpa.dsl.bDDL.Inheritance
import de.jpaw.bonaparte.jpa.dsl.bDDL.NamedEntityGraph
import de.jpaw.bonaparte.jpa.dsl.generator.PrimaryKeyType
import de.jpaw.bonaparte.jpa.dsl.generator.RequiredType
import java.util.ArrayList
import java.util.List
import java.util.concurrent.atomic.AtomicInteger
import org.apache.log4j.Logger
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.common.types.JvmGenericType
import org.eclipse.xtext.generator.AbstractGenerator
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext

import static de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*
import static de.jpaw.bonaparte.dsl.generator.java.JavaRtti.*

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.jpa.dsl.generator.YUtil.*

class JavaDDLGeneratorMain extends AbstractGenerator {
    private static final Logger LOGGER = Logger.getLogger(JavaDDLGeneratorMain);
    val static final EMPTY_ELEM_COLL = new ArrayList<ElementCollectionRelationship>(0);

    var JavaFieldWriter fieldWriter = null

    var FieldDefinition haveIntVersion = null
    var haveActive = false

    // create the filename to store a generated java class source in. Assumes subdirectory ./java
    def private static getJavaFilename(String pkg, String name) {
        return "java/" + pkg.replaceAll("\\.", "/") + "/" + name + ".java"
    }

    override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext unused) {
        // java
        for (e : resource.allContents.toIterable.filter(typeof(EntityDefinition))) {
            if (!e.noJava && !(e.eContainer as BDDLPackageDefinition).isNoJava) {
                val primaryKeyType = determinePkType(e)
                if (primaryKeyType == PrimaryKeyType::IMPLICIT_EMBEDDABLE) {
                    // write a separate class for the composite key
                    fsa.generateFile(getJavaFilename(e.bddlPackageName, e.name + "Key"), e.javaKeyOut)
                }
                fsa.generateFile(getJavaFilename(e.bddlPackageName, e.name), e.javaEntityOut(primaryKeyType))
            }
        }
        for (e : resource.allContents.toIterable.filter(typeof(EmbeddableDefinition))) {
            fsa.generateFile(getJavaFilename(e.bddlPackageName, e.name), e.javaEmbeddableOut)
        }
        for (e : resource.allContents.toIterable.filter(typeof(ConverterDefinition))) {
            fsa.generateFile(getJavaFilename(e.bddlPackageName, e.name), Converters.writeTypeConverter(e))
        }
        for (d : resource.allContents.toIterable.filter(typeof(BDDLPackageDefinition))) {
            // write a package-info.java file, if javadoc on package level exists
            if (d.javadoc !== null) {
                fsa.generateFile(getJavaFilename(getBddlPackageName(d), "package-info"), '''
                    // This source has been automatically created by the bonaparte bonaparte.jpa DSL. Do not modify, changes will be lost.
                    // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
                    // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git

                    «d.javadoc»
                    package «getBddlPackageName(d)»;
                ''')
            }
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

    def private hasECin(FieldDefinition c, List <ElementCollectionRelationship> el) {
        el !== null && el.map[name].contains(c)
        /*
        val result = e.elementCollections !== null && e.elementCollections.map[name].contains(c)
        LOGGER.debug('''Testing for «c.name» in «e.name» gives «result»''')
        return result  */
    }

    // output a single field (which maybe expands to multiple DB columns due to embeddables and List expansion. The field could be used from an entity or an embeddable
    def private static CharSequence writeFieldWithEmbeddedAndListJ(FieldDefinition f, List<EmbeddableUse> embeddables, ColumnNameMappingDefinition nmd,
            String prefix, String suffix, String currentIndex,
            boolean noListAtThisPoint, boolean noList2, String separator, (FieldDefinition, String, String) => CharSequence func) {
        // expand Lists first
        // if the elements are nullable (!f.isRequired), then any element is transferred. Otherwise, only not null elements are transferred
        val myName = f.name.asEmbeddedName(prefix, suffix)
        val myIndexList = f.indexList
        if (!noListAtThisPoint && myIndexList !== null) {
            val notNullElements = f.isRequired
            // val ref = DataTypeExtension::get(f.datatype);
            return '''
                «myIndexList.map[f.writeFieldWithEmbeddedAndListJ(embeddables, nmd, prefix, '''«suffix»«it»''', it, true, false, separator, func)].join(separator)»
                «IF noList2 == false»
                    public «f.JavaDataTypeNoName(false)» get«myName.toFirstUpper()»() {
                        «f.JavaDataTypeNoName(false)» _a = new Array«f.JavaDataTypeNoName(false)»(«myIndexList.size»);
                        «myIndexList.map['''«IF notNullElements»if (get«myName.toFirstUpper»«it»() != null) «ENDIF»_a.add(get«myName.toFirstUpper»«it»());'''].join('\n')»
                        return _a;
                    }
                    public void set«myName.toFirstUpper()»(«f.JavaDataTypeNoName(false)» _a) {
                        «myIndexList.map['''set«myName.toFirstUpper»«it»(null);'''].join('\n')»
                        if (_a == null)
                            return;
                        «(1..myIndexList.size).map['''if (_a.size() >= «it») set«myName.toFirstUpper»«myIndexList.get(it-1)»(_a.get(«it-1»));'''].join('\n')»
                    }
                «ENDIF»
                '''
        } else {
            // see if we need embeddables expansion, but only if it is either not an aggregate or it has "unroll loops" set. (Otherwise, it will be an ElementCollection!!!)
            val emb = embeddables.findFirst[field == f]
            if (emb !== null && (!f.aggregate || f.properties.hasProperty(PROP_UNROLL))) {
                // expand embeddable, output it instead of the original column
                val pojo = emb.name.pojoType
                val isExternalType = pojo.externalType !== null // adapter required?
                val lvar = if (isExternalType) "_y" else "_x"
                val objectName = if (isExternalType) pojo.externalName else pojo.name
                val nameLengthDiff = f.name.length - objectName.length
                val tryDefaults = emb.prefix === null && emb.suffix === null && nameLengthDiff > 0
                val finalPrefix = if (tryDefaults && f.name.endsWith(objectName)) f.name.substring(0, nameLengthDiff) else emb.prefix             // Address homeAddress => prefix home
                val finalSuffix = if (tryDefaults && f.name.startsWith(objectName.toFirstLower)) f.name.substring(objectName.length) else emb.suffix // Amount amountBc => suffix Bc
                val newPrefix = '''«prefix»«finalPrefix»'''
                val newSuffix = '''«finalSuffix»«suffix»'''
                val efields = pojo.allFields  // shorthand...: the fields of the embeddable
                LOGGER.debug('''DDL gen: Expanding embeddable «myName» from «objectName», field is «f.name», aggregate is «f.aggregate», has unroll = «f.properties.hasProperty(PROP_UNROLL)», noList=«noListAtThisPoint», «noList2»''')
                //System::out.println('''Java: «myName» defts=«tryDefaults»: nldiff=«nameLengthDiff», emb.pre=«emb.prefix», emb.suff=«emb.suffix»!''')
                //System::out.println('''Java: «myName» defts=«tryDefaults»: has in=(«prefix»,«suffix»), final=(«finalPrefix»,«finalSuffix»), new=(«newPrefix»,«newSuffix»)''')

                val newPojo =
                    if (pojo.singleField)       // adapter, and special type of it?
                        '''«myName».get«pojo.firstField.name.toFirstUpper»()'''      // do not construct a temporary BonaPortable adapter proxy of the Embeddable
                    else
                        '''new «pojo.name»(«efields.map['''«myName».get«name.toFirstUpper»()'''].join(', ')»)'''
                val extraExternalArgs = if (isExternalType && emb.field?.datatype !== null) {
                    if (emb.field.datatype.extraParameterString !== null)
                        '''«emb.field.datatype.extraParameterString», '''
                    else if (emb.field.datatype.extraParameter !== null)
                        '''get«emb.field.datatype.extraParameter.name.toFirstUpper»(), '''
                }
                val marshaller = if (pojo.bonaparteAdapterClass !== null) '''«pojo.adapterClassName».marshal(_x)''' else '''_x.marshal()'''

                return '''
                    «IF newPrefix != "" || newSuffix != ""»
                        @AttributeOverrides({
                        «pojo.allFields.map[writeFieldWithEmbeddedAndListJ(emb.name.embeddables, nmd, newPrefix, newSuffix, null, false, true, ',\n',
                            [ fld, myName2, ind | '''    @AttributeOverride(name="«fld.name»«ind»", column=@Column(name="«myName2.java2sql(nmd)»"))'''])].join(',\n')»
                        })
                    «ENDIF»
                    «IF emb.isPk !== null»
                        @EmbeddedId
                    «ELSE»
                        @Embedded
                    «ENDIF»
                    private «emb.name.name» «myName»;
                    public «objectName» get«myName.toFirstUpper()»() {
                        if («myName» == null)
                            return null;
                        «IF isExternalType»
                            return «pojo.adapterClassName».unmarshal(«extraExternalArgs»«newPojo»«IF pojo.exceptionConverter», RuntimeExceptionConverter.INSTANCE«ENDIF»);
                        «ELSE»
                            return «newPojo»;
                        «ENDIF»
                    }
                    public void set«myName.toFirstUpper()»(«objectName» _x) {
                        if (_x == null) {
                            «myName» = null;
                        } else {
                            «myName» = new «emb.name.name»();
                            «IF pojo.singleField»
                                «myName».set«pojo.firstField.name.toFirstUpper»(«marshaller»);
                            «ELSE»
                                «IF isExternalType»
                                    «pojo.name» _y = «marshaller»;
                                «ENDIF»
                                «efields.map['''«myName».set«name.toFirstUpper»(«lvar».get«name.toFirstUpper»());'''].join('\n')»
                            «ENDIF»
                        }
                    }
                '''
            } else if (emb !== null) {
                // embeddable in a list, not unrolled: this must be an ElementCollection!
                // TODO: use special data types
                func.apply(f, myName, currentIndex)
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
        List<EmbeddableUse> embeddables, ColumnNameMappingDefinition nmd,
        (ClassDefinition)=> CharSequence groupSeparator,
        (FieldDefinition, String, String) => CharSequence fieldOutput) '''
        «IF cl != stopAt»
            «cl.extendsClass?.classRef?.recurseJ(stopAt, includeAggregates, filterCondition, embeddables, nmd, groupSeparator, fieldOutput)»
            «groupSeparator?.apply(cl)»
            «FOR c : cl.fields»
                «IF (includeAggregates || !c.isAggregate || c.properties.hasProperty(PROP_UNROLL)) && filterCondition.apply(c)»
                    «c.writeFieldWithEmbeddedAndListJ(embeddables, nmd, null, null, null, false, false, "", fieldOutput)»
                «ENDIF»
            «ENDFOR»
        «ENDIF»
    '''

    // shorthand call for entities
    def private CharSequence recurseColumns(ClassDefinition cl, ClassDefinition stopAt, EntityDefinition e,
        List<FieldDefinition> pkColumns, PrimaryKeyType primaryKeyType, boolean isIdGenerated, String generatedIdDetails) {
        cl.recurseColumns(stopAt, e.elementCollections, e.embeddables, e.nameMapping, e.tableCategory.doBeanVal, pkColumns, primaryKeyType, isIdGenerated, generatedIdDetails);
    }

    def private CharSequence recurseColumns(ClassDefinition cl, ClassDefinition stopAt,
        List<ElementCollectionRelationship> el, List<EmbeddableUse> embeddables, ColumnNameMappingDefinition nmd, boolean doBeanVal,
        List<FieldDefinition> pkColumns, PrimaryKeyType primaryKeyType, boolean isIdGenerated, String generatedIdDetails
    ) {
        // include aggregates if there is an @ElementCollection defined for them
        //        «IF embeddables?.filter[isPk !== null].head?.field == fld»
        //            @EmbeddedId
        //        «ENDIF»
        recurseJ(cl, stopAt, true, [ !isAggregate || hasECin(el) || properties.hasProperty(PROP_UNROLL) ], embeddables, nmd,
            [ '''// table columns of java class «name»
            ''' ], [ fld, myName, ind | '''
                «IF (primaryKeyType == PrimaryKeyType::SINGLE_COLUMN || primaryKeyType == PrimaryKeyType::ID_CLASS) && pkColumns.map[name].contains(fld.name)»
                    @Id
                    «IF isIdGenerated»
                        @GeneratedValue«IF generatedIdDetails !== null»(«generatedIdDetails»)«ENDIF»
                    «ENDIF»
                «ENDIF»
                «IF (primaryKeyType != PrimaryKeyType::IMPLICIT_EMBEDDABLE || !inList(pkColumns, fld)) && !fld.properties.hasProperty(PROP_NOJAVA)»
                    «fieldWriter.writeColStuff(fld, el, doBeanVal, myName, embeddables, cl, nmd)»
                    «IF fld.properties.hasProperty(PROP_VERSION)»
                        «IF fld.JavaDataTypeNoName(false).equals("int") || fld.JavaDataTypeNoName(false).equals("Integer")»
                            «fld.setIntVersion»
                        «ENDIF»
                    «ENDIF»
                    «IF fld.properties.hasProperty(PROP_ACTIVE)»
                        «setHaveActive»
                        // specific getter/setters for the active flag
                        @Override
                        public void put$Active(boolean _a) {
                            set«myName.toFirstUpper»(_a);
                        }
                        @Override
                        public boolean ret$Active() {
                            return get«myName.toFirstUpper»();
                        }
                    «ENDIF»
                «ENDIF»
        ''']
        )
    }


    def private static CharSequence recurseForCopyOf(ClassDefinition cl, ClassDefinition stopAt, List<FieldDefinition> excludes,
        (FieldDefinition, String, RequiredType) => CharSequence fieldOutput, EntityDefinition e) '''
        «IF cl != stopAt»
            «cl.extendsClass?.classRef?.recurseForCopyOf(stopAt, excludes, fieldOutput, e)»
            «FOR c : cl.fields»
                «IF ((!c.isAggregate || c.properties.hasProperty(PROP_UNROLL) || c.isInElementCollection(e)) && (excludes === null || !excludes.contains(c))
                    && !c.properties.hasProperty(PROP_NOJAVA) && (JavaFieldWriter.shouldWriteColumn(c) || MakeMapper.isAnEmbeddable(c, e.embeddables))
                )»
                    «c.writeFieldWithEmbeddedAndList(null, null, null, RequiredType::DEFAULT, false, "", fieldOutput)»
                «ENDIF»
            «ENDFOR»
        «ENDIF»
    '''

    def private writeCopyOf(EntityDefinition e, String pkType, String trackingType) {
        // FT-1588 may have an issue with lazy loaded proxies here...
//        val myPrinter = [ FieldDefinition fld, String myName, RequiredType req | '''«myName» = _x.«myName»;
//        ''']
        val myPrinter = [ FieldDefinition fld, String myName, RequiredType req | '''set«myName.toFirstUpper»(_x.get«myName.toFirstUpper»());
        ''']
        return '''
        @Override
        public BonaPersistableBase mergeFrom(final BonaPersistableBase _b) {
            «IF e.extends !== null»
                super.mergeFrom(_b);
            «ENDIF»
            if (_b instanceof «e.name») {
                «e.name» _x = («e.name»)_b;
                «IF e.extends === null && e.pk?.columnName !== null»
                    «FOR f: e.pk.columnName»
                        set«f.name.toFirstUpper»(_x.get«f.name.toFirstUpper»());
                    «ENDFOR»
                «ENDIF»
                «e.tenantClass?.recurseForCopyOf(null, e.pk?.columnName, myPrinter, e)»
                «e.pojoType.recurseForCopyOf(e.extends?.pojoType, e.pk?.columnName, myPrinter, e)»
            }
            return this;
        }
    '''
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
        «IF e.^extends === null»
            «writeRtti(e.pojoType)»
            «IF !haveActive»
                // no isActive column in this entity, create stubs to satisfy interface
                @Override
                public void put$Active(boolean _a) {
                    // throw new RuntimeException("Entity «e.name» does not have an isActive field");
                }
                @Override
                public boolean ret$Active() {
                    return true;  // no isActive column => all rows are active by default
                }
            «ENDIF»
            «IF haveIntVersion === null»
                // no version column of type int or Integer, write stub
                @Override
                public void put$IntVersion(int _v) {
                    // throw new RuntimeException("Entity «e.name» does not have an integer type version field");
                }
                @Override
                public int ret$IntVersion() {
                    return -1;
                }
            «ELSE»
                // version column of type int or Integer exists, write proxy
                @Override
                public void put$IntVersion(int _v) {
                    set«haveIntVersion.name.toFirstUpper»(_v);
                }
                @Override
                public int ret$IntVersion() {
                    return get«haveIntVersion.name.toFirstUpper»();
                }
            «ENDIF»
        «ENDIF»
    '''

    def private writeKeyInterfaceMethods(EntityDefinition e, String pkType) '''
        public static Class<«if (pkType == "long") "?" else pkType»> class$KeyClass() {
            return «pkType».class;
        }
        @Override
        public Class<«if (pkType == "long") "?" else pkType»> ret$KeyClass() {
            return «pkType».class;
        }
        @Override
        public «pkType» ret$Key() {
            «IF pkType.equals("Serializable")»
                return null;  // FIXME! not yet implemented!
            «ELSE»
                «IF e.embeddablePk !== null»
                    return get«e.embeddablePk.field.name.toFirstUpper»();
                «ELSEIF e.pkPojo !== null»
                    return new «e.pkPojo.name»(«e.pkPojo.fields.map[if (hasProperty(properties, PROP_SIMPLEREF)) '''new «JavaDataTypeNoName(true)»(get«name.toFirstUpper»())''' else '''get«name.toFirstUpper»()'''].join(', ')»);
                «ELSEIF e.pk.columnName.size > 1»
                    return key.clone(); // as our key fields are all immutable, shallow copy is sufficient
                «ELSE»
                    return «e.pk.columnName.get(0).name»;
                «ENDIF»
            «ENDIF»
        }
        @Override
        public void put$Key(«pkType» _k) {
            «IF pkType == "Serializable"»
                // FIXME! not yet implemented!!!
            «ELSE»
                «IF e.embeddablePk !== null»
                    set«e.embeddablePk.field.name.toFirstUpper»(_k);
                «ELSEIF e.pkPojo !== null»
                    «FOR f: e.pkPojo.fields»
                        set«f.name.toFirstUpper»(_k.get«f.name.toFirstUpper»()«IF hasProperty(f.properties, PROP_SIMPLEREF)».«f.properties.getProperty(PROP_SIMPLEREF)»«ENDIF»);
                    «ENDFOR»
                «ELSEIF e.pk.columnName.size > 1»
                    key = _k.clone();   // as our key fields are all immutable, shallow copy is sufficient
                «ELSE»
                    set«e.pk.columnName.get(0).name.toFirstUpper»(_k);  // no direct assigned due to possible enum or temporal type, with implied conversions
                «ENDIF»
            «ENDIF»
        }
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

    def private static writeGetSelf(EntityDefinition e) '''
        /** Method that allows generic proxy resolution by returning {@code this}. */
        @Override
        public «e.name» ret$Self() {
            return this;
        }
    '''

    def private i2s(Inheritance i) {
        switch (i) {
        case Inheritance::SINGLE_TABLE: return "SINGLE_TABLE"
        case Inheritance::JOIN: return "JOINED"
        case Inheritance::TABLE_PER_CLASS: return "TABLE_PER_CLASS"
        default: null
        }
    }

    def private static doNoDataMapper(EntityDefinition e) {
        e.isIsAbstract || (!e.doMapper && (e.noMapper || (e.eContainer as BDDLPackageDefinition).isNoMapper))
    }

    def private static doNoKeyMapper(EntityDefinition e) {
        !e.doMapper && (e.noKeyMapper || (e.eContainer as BDDLPackageDefinition).noKeyMapper)
    }

        // the class which defines the data mapper type is the one which is
        // - not abstract
        // - has not "noDataMapper specified
        // has no parent class of these properties
    def private static boolean isFirstNonAbstractClass(EntityDefinition e) {
        if (e.isIsAbstract || e.doNoDataMapper)
            return false
        if (e.extends === null)
            return true
        return e.extends.firstNonAbstractBaseClass === null  // true if no superclass defines it
    }

    def private static EntityDefinition firstNonAbstractBaseClass(EntityDefinition e) {
        // careful not to implement exponential recursion: try bottom up!
        val parent = e.extends?.firstNonAbstractBaseClass       // head recursion
        if (parent === null) {
            // try e
            if (e.isIsAbstract || e.doNoDataMapper)
                return null
            return e
        }
        return null
    }

    // define the "implements" for an Entity or MappedSuperclass.
    // The following rules hold:
    // Tracking is always defined in the root entity (extends == null), no matter if abstract or not
    // BonaData is written if the class is not abstract and not noDataMappper specified
    // BonaKey is written once the key has been defined, independent of root class or not, independent of abstract class or not
    // deprecated interfaces BonaPersistableNoData* are written together with the key.
    def private wrImplements(EntityDefinition e, String pkType, String trackingType, boolean pkDefinedInThisEntity, boolean shouldBeSerializable) {
        //println('''write Implements for entity «e.name»: abstract=«e.isIsAbstract», root=«e.extends === null», PK defined here=«pkDefinedInThisEntity», PK class = «pkType», first non abstract base entity=«e.firstNonAbstractBaseClass»''')
        // val doNone = !(e.extends === null) && !(pkDefinedInThisEntity && !e.doNoKeyMapper) && !e.isFirstNonAbstractClass
        val interfaces = new ArrayList<String>(4)
        if (pkDefinedInThisEntity && !e.doNoKeyMapper) {
            // first for compatibility of some existing active annotations... add a deprecated interface. trackingType is always populated, not only for the root entity
                                                        interfaces.add(if (pkType == "long") '''BonaPersistableNoDataLong<«trackingType»>''' else '''BonaPersistableNoData<«pkType», «trackingType»>''')
                                                        interfaces.add(if (pkType == "long") '''BonaPersistableKeyLong'''                    else '''BonaPersistableKey<«pkType»>''')
        }
        if (e.isFirstNonAbstractClass)                  interfaces.add('''BonaPersistableData<«e.pojoType.name»>''')
        if (e.extends === null)                         interfaces.add('''BonaPersistableTracking<«trackingType»>''')
        if (shouldBeSerializable)                       interfaces.add("Serializable")

        if (interfaces.empty)
            return "BonaPersistableBase"
        else
            return interfaces.join(", ")
    }

    // output 0 to 4 elements */
    def private writeEntityListeners(String a, String b, JvmGenericType c, JvmGenericType d) {
        val mylist = new ArrayList<String>(4)
        if (a !== null)
            mylist.add(a)
        if (b !== null)
            mylist.add(b)
        if (c !== null)
            mylist.add(c.qualifiedName)
        if (d !== null)
            mylist.add(d.qualifiedName)
        if (mylist.size == 0)
            return null
        return '''
            @EntityListeners({«mylist.map[it + ".class"].join(', ')»})
        '''
    }

    def private static createUniqueConstraints(EntityDefinition e) '''
        «IF !e.index.filter[isUnique].empty»
            , uniqueConstraints={
            «e.index.filter[isUnique].map['''    @UniqueConstraint(columnNames={«columns.columnName.map['''"«name.java2sql(e.nameMapping)»"'''].join(', ')»})'''].join(',\n')»
            }«ENDIF»'''

    def private declareIndex(IndexDefinition i, EntityDefinition e, String tablename, AtomicInteger indexCounter, ColumnNameMappingDefinition nmd) {
        val no = indexCounter.incrementAndGet
        return '''@Index(name="«tablename.indexname(i, no)»", columnList="«i.columns.columnName.map[name.java2sql(nmd)].join(", ")»"«IF i.isIsUnique», unique=true«ENDIF»)'''
    }

    def private addIndexes(EntityDefinition e, BDDLPreferences prefs) {
        if (!prefs.doIndexes)
            return null
        val tablename = e.mkTablename(false)
        val nmd = e.nameMapping
        val indexCounter = new AtomicInteger
        return ''', indexes = { «e.index.map[declareIndex(e, tablename, indexCounter, nmd)].join(", ")»}'''
    }

    def private String joinNodes(List<String> names) {
        return names.map['''@NamedAttributeNode(«it»)'''].join(", ")
    }
    def private String quoted(String name) {
        return '''"«name»"'''
    }
    def private String subgraph(GraphRelationship sub, NamedEntityGraph neg) {
        return '''@NamedSubgraph(name="«neg.name».«sub.name.name»", attributeNodes={«sub.fields.fields.map[name.quoted].joinNodes»})'''
    }
    def private String entityGraph(NamedEntityGraph neg) {
        val haveSubgraphs = neg.rname.exists[fields !== null]
        return '''
            @NamedEntityGraph(name="«neg.name»"«IF neg.isAll»,
                includeAllAttributes = true«ENDIF»«IF !neg.rname.empty»,
                attributeNodes = {
                    «neg.rname.map[if (fields === null) '''"«name.name»"''' else '''value="«name.name»", subgraph="«neg.name».«name.name»"'''].joinNodes»
                }«ENDIF»«IF haveSubgraphs»,
                subgraphs = {
                    «FOR sg: neg.rname.filter[fields !== null]»
                        «sg.subgraph(neg)»
                    «ENDFOR»
                }«ENDIF»
            )
        '''
    }

    def private javaEntityOut(EntityDefinition e, PrimaryKeyType primaryKeyType) {
        val prefs = BDDLPreferences.currentPrefs
        val String myPackageName = e.bddlPackageName
        val ImportCollector imports = new ImportCollector(myPackageName)
        var ClassDefinition stopper = null
        val shouldBeSerializable = e.serializable || (e.eContainer as BDDLPackageDefinition).allSerializable
//        val nmd = e.nameMapping

        imports.recurseImports(e.tableCategory.trackingColumns, true)
        imports.recurseImports(e.pojoType, true)

        // reset tracking flags
        haveIntVersion = null
        haveActive = false
        fieldWriter = new JavaFieldWriter(e)

        imports.addImport(myPackageName, e.name)  // add myself as well
        imports.addImport(e.pojoType);  // TODO: not needed, see above?
        imports.addImport(e.tableCategory.trackingColumns);
        if (e.^extends !== null) {
            imports.addImport(getBddlPackageName(e.^extends), e.^extends.name)
            stopper = e.^extends.pojoType
        }
        // imports for ManyToOne
        for (r : e.manyToOnes)
            imports.addImport(r.relationship.childObject.getBddlPackageName, r.relationship.childObject.name)
        // for OneToMany
        for (r : e.oneToManys)
            imports.addImport(r.relationship.childObject.getBddlPackageName, r.relationship.childObject.name)
        // for OneToOne
        for (r : e.oneToOnes)
            imports.addImport(r.relationship.childObject.getBddlPackageName, r.relationship.childObject.name)
        // for Embeddables
        for (r : e.embeddables) {
            imports.addImport(r.name.getBddlPackageName, r.name.name)  // the Entity
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
        } else if (e.pk !== null) {
            pkColumns = e.pk.columnName
            if (pkColumns.size > 1)
                pkType0 = e.name + "Key"
            else
                pkType0 = pkColumns.get(0).JavaDataTypeNoName(true)
        } else if (e.pkPojo !== null) {
            pkColumns = e.pkPojo.fields
            pkType0 = e.pkPojo.name
        }
        val pkDefinedInThisEntity = pkType0 !== null
        val String pkType = pkType0 ?: "Serializable"
        if (e.tableCategory.trackingColumns !== null) {
            trackingType = e.tableCategory.trackingColumns.name
        }
        val dataMapperEntity = e.firstNonAbstractBaseClass

        return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git
        package «myPackageName»;

        «IF e.tenantId !== null»
            //import javax.persistence.Multitenant;  // not (yet?) there. Should be in JPA 2.1
            import org.eclipse.bonaparte.jpa.annotations.Multitenant;  // BAD! O-R mapper specific TODO: FIXME
        «ENDIF»
        «IF e.cacheSize != 0»
            import org.eclipse.bonaparte.jpa.annotations.Cache;  // BAD! O-R mapper specific TODO: FIXME
        «ENDIF»
        «IF e.cacheable»
            import javax.persistence.Cacheable;
        «ENDIF»
        «IF e.xinheritance !== null && e.xinheritance != Inheritance::NONE»
            import javax.persistence.Inheritance;
            import javax.persistence.InheritanceType;
        «ENDIF»
        «IF e.discname !== null»
            import javax.persistence.DiscriminatorType;
            import javax.persistence.DiscriminatorColumn;
            import javax.persistence.DiscriminatorValue;
        «ENDIF»
        «IF e.^extends !== null»
            import javax.persistence.DiscriminatorValue;
        «ENDIF»
        «IF e.isAbstract»
            import javax.persistence.MappedSuperclass;
        «ENDIF»
        «IF e.isIdGenerated»
            import javax.persistence.GeneratedValue;
            import javax.persistence.GenerationType;
        «ENDIF»
        «IF e.generator !== null»
            import javax.persistence.«e.generator.substring(1)»;
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
        «IF prefs.doIndexes»
            import javax.persistence.Index;
        «ENDIF»
        «IF !e.neg.nullOrEmpty»
            import javax.persistence.NamedEntityGraph;
            import javax.persistence.NamedEntityGraphs;
            import javax.persistence.NamedAttributeNode;
            import javax.persistence.NamedSubgraph;
        «ENDIF»

        «JavaBeanValidation::writeImports(e.tableCategory.doBeanVal)»
        «writeDefaultImports»
        «writeJpaImports»

        import de.jpaw.bonaparte.jpa.*;
        «IF prefs.doUserTypeForJson»
            import de.jpaw.bonaparte.jpa.json.*;
        «ENDIF»

        «imports.createImports»

        «IF e.javadoc !== null»
            «e.javadoc»
        «ENDIF»
        «IF e.isAbstract»
            @MappedSuperclass
        «ELSE»
            @DataClass(«e.pojoType.name».class)
            «IF e.tableCategory.trackingColumns !== null»
                @TrackingClass(«e.tableCategory.trackingColumns.name».class)
            «ENDIF»
            «IF pkDefinedInThisEntity»
                @KeyClass(«pkType0».class)
            «ENDIF»
            @Entity
            «writeEntityListeners(e.tableCategory.autoSetter, e.autoSetter, e.tableCategory.entityListener, e.entityListener)»
            «IF e.cacheable»
                @Cacheable(true)
            «ENDIF»
            «IF e.cacheSize != 0»
                @Cache(size=«e.cacheSize», expiry=«scaledExpiry(e.cacheExpiry, e.cacheExpiryScale)»000)
            «ENDIF»
            @Table(name="«mkTablename(e, false)»"«e.createUniqueConstraints»«e.addIndexes(prefs)»)
            «IF primaryKeyType == PrimaryKeyType::ID_CLASS»
                @IdClass(«e.pkPojo.name».class)
            «ENDIF»
            «IF e.tenantId !== null»
                @Multitenant(/* SINGLE_TABLE */)
            «ENDIF»
            «IF e.xinheritance !== null && e.xinheritance != Inheritance::NONE»
                @Inheritance(strategy=InheritanceType.«i2s(e.xinheritance)»)
            «ENDIF»
            «IF e.discname !== null»
                @DiscriminatorColumn(name="«e.discname»", discriminatorType=DiscriminatorType.«IF e.discriminatorTypeInt»INTEGER«ELSE»STRING«ENDIF»)
                @DiscriminatorValue(«IF e.discriminatorTypeInt»"0"«ELSE»"«Util::escapeString2Java(e.discriminatorValue)»"«ENDIF»)
            «ELSEIF e.discriminatorValue !== null»
                @DiscriminatorValue("«Util::escapeString2Java(e.discriminatorValue)»")
            «ENDIF»
            «IF e.generator !== null»
                «e.generator»(name="«e.generatorName»"«IF e.generatorValue !== null», «e.generatorValue»«ENDIF»)
            «ENDIF»
        «ENDIF»
        «IF e.neg.size > 0»
            «IF e.neg.size == 1»
                «e.neg.get(0).entityGraph»
            «ELSE»
                @NamedEntityGraphs({
                    «e.neg.map[entityGraph].join(",\n")»
                })
            «ENDIF»
        «ENDIF»
        @SuppressWarnings("all")
        «IF e.isDeprecated || e.pojoType.isDeprecated || (e.pojoType.eContainer as PackageDefinition).isDeprecated || (e.eContainer as BDDLPackageDefinition).isIsDeprecated»
            @Deprecated
        «ENDIF»
        public«IF e.isAbstract» abstract«ENDIF» class «e.name»«IF e.extendsClass !== null» extends «e.extendsClass.name»«ENDIF»«IF e.extendsJava !== null» extends «e.extendsJava»«ENDIF»«IF e.^extends !== null» extends «e.^extends.name»«ENDIF» implements «wrImplements(e, pkType, trackingType, pkDefinedInThisEntity, shouldBeSerializable)»«IF e.implementsJavaInterface !== null», «e.implementsJavaInterface.qualifiedName»«ENDIF» {
            «IF shouldBeSerializable»
                private static final long serialVersionUID = «getSerialUID(e.pojoType) + 1L»L;
            «ENDIF»
            «IF primaryKeyType == PrimaryKeyType::IMPLICIT_EMBEDDABLE»
                «fieldWriter.buildEmbeddedId(e)»
            «ENDIF»
            «IF e.extends === null»«e.tableCategory.trackingColumns?.recurseColumns(null, e, pkColumns, primaryKeyType, e.isIsIdGenerated, e.generatedIdDetails)»«ENDIF»
            «e.tenantClass?.recurseColumns(null, e, pkColumns, primaryKeyType, e.isIsIdGenerated, e.generatedIdDetails)»
            «e.pojoType.recurseColumns(stopper, e, pkColumns, primaryKeyType, e.isIsIdGenerated, e.generatedIdDetails)»
            «IF pkDefinedInThisEntity || (e.^extends === null && !e.isIsAbstract)»
                «EqualsHash::writeEqualsAndHashCode(e, primaryKeyType)»
            «ENDIF»
            «writeStubs(e)»
            «IF pkDefinedInThisEntity»
                «writeKeyInterfaceMethods(e, pkType)»
            «ENDIF»
            «IF e.^extends === null»
                «MakeMapper::writeTrackingMapperMethods(e.tableCategory.trackingColumns, trackingType)»
            «ENDIF»
            «IF dataMapperEntity !== null»
                «MakeMapper::writeDataMapperMethods(e.pojoType, e == dataMapperEntity, dataMapperEntity.pojoType, e.embeddables, e.pk?.columnName)»
            «ENDIF»
            «writeStaticFindByMethods(e.pojoType, stopper, e)»
            «e.writeCopyOf(pkType, trackingType)»
            «e.writeGetSelf»
            «MakeRelationships::writeRelationships(e, JavaFieldWriter.defineVisibility(e))»
        }
        '''
    }
    def private javaKeyOut(EntityDefinition e) {
        val String myPackageName = e.bddlPackageName
        val String myName = e.name + "Key"
        val ImportCollector imports = new ImportCollector(myPackageName)
        imports.recurseImports(e.pojoType, true)

        imports.addImport(myPackageName, myName)  // add myself as well
        fieldWriter = new JavaFieldWriter(e)

        return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git
        package «myPackageName»;

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
        «writeJpaImports»

        «imports.createImports»

        @SuppressWarnings("all")
        @Embeddable
        public class «myName» implements Serializable, Cloneable {
            private static final long serialVersionUID = «getSerialUID(e.pojoType) + 1L»L;
            «FOR col : e.pk.columnName»
                «fieldWriter.writeColStuff(col, e.elementCollections, e.tableCategory.doBeanVal, col.name, null, null, e.nameMapping)»
            «ENDFOR»
            «EqualsHash::writeHashMethodForClassPlusExtraFields(null, e.pk.columnName)»
            «EqualsHash::writeKeyEquals(myName, e.pk.columnName)»
            «writeCloneable(myName)»
        }
        '''
    }

    def private javaEmbeddableOut(EmbeddableDefinition e) {
        val prefs = BDDLPreferences.currentPrefs
        val String myPackageName = e.bddlPackageName
        val String myName = e.name
        val ImportCollector imports = new ImportCollector(myPackageName)
        imports.addImport(e.pojoType)               // add underlying POJO as well (this is not done by the recursive one next line!)
        imports.recurseImports(e.pojoType, true)
        imports.addImport(myPackageName, e.name)  // add myself as well
        fieldWriter = new JavaFieldWriter(e)

        return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git
        package «myPackageName»;

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
        «writeJpaImports»

        import de.jpaw.bonaparte.jpa.BonaData;
        import de.jpaw.bonaparte.jpa.DeserializeExceptionHandler;
        «IF prefs.doUserTypeForJson»
            import de.jpaw.bonaparte.jpa.json.*;
        «ENDIF»
        «imports.createImports»

        «IF e.javadoc !== null»
            «e.javadoc»
        «ENDIF»
        @SuppressWarnings("all")
        @Embeddable
        «IF e.isDeprecated || e.pojoType.isDeprecated»
            @Deprecated
        «ENDIF»
        public class «e.name» implements Serializable, Cloneable, BonaData<«e.pojoType.name»> {
            private static final long serialVersionUID = «getSerialUID(e.pojoType) + 1L»L;
            «e.pojoType.recurseColumns(null, EMPTY_ELEM_COLL, e.embeddables, e.nameMappingGroup, e.doBeanVal, null, PrimaryKeyType::NONE, false, null)»
            «EqualsHash::writeHashMethodForClassPlusExtraFields(e.pojoType, null)»
            «EqualsHash::writeKeyEquals(e.name, e.pojoType.fields)»
            «writeCloneable(myName)»
            «MakeMapper::writeDataMapperMethods(e.pojoType, true, e.pojoType, e.embeddables, null)»

            private Object ret$Key() {  // only required in case of a deserialized exception Handler
                return null;
            }
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

    def public static writeJpaImports() '''
        import java.io.Serializable;

        import «bonaparteInterfacesPackage».BonaPortable;
        import «bonaparteInterfacesPackage».ByteArrayComposer;
        import «bonaparteInterfacesPackage».ByteArrayParser;
        import «bonaparteInterfacesPackage».CompactByteArrayParser;
        import «bonaparteInterfacesPackage».CompactByteArrayComposer;
        import «bonaparteInterfacesPackage».StaticMeta;
        import «bonaparteInterfacesPackage».MessageParserException;
        import «bonaparteInterfacesPackage».RuntimeExceptionConverter;
        import «bonaparteInterfacesPackage».BonaparteJsonEscaper;
        import de.jpaw.util.ByteBuilder;
        import de.jpaw.json.JsonException;
        import de.jpaw.json.JsonParser;
    '''
}
