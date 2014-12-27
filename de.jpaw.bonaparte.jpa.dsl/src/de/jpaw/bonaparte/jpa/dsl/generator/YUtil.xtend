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

package de.jpaw.bonaparte.jpa.dsl.generator

import com.google.common.base.CaseFormat
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.jpa.dsl.bDDL.BDDLPackageDefinition
import de.jpaw.bonaparte.jpa.dsl.bDDL.EmbeddableUse
import de.jpaw.bonaparte.jpa.dsl.bDDL.EntityDefinition
import de.jpaw.bonaparte.jpa.dsl.bDDL.Inheritance
import de.jpaw.bonaparte.jpa.dsl.bDDL.Model
import de.jpaw.bonaparte.jpa.dsl.bDDL.TableCategoryDefinition
import java.util.ArrayList
import java.util.Arrays
import java.util.List
import org.eclipse.emf.ecore.EObject

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*

class YUtil {
    // bonaparte properties which are used for bddl code generators
    public static final String PROP_UNROLL = "unroll";     // List<> => 01...0n
    public static final String PROP_NOJAVA = "noJava";
    public static final String PROP_NODDL  = "noDDL";
    public static final String PROP_FINDBY = "findBy";
    public static final String PROP_LISTBY = "listBy";
    public static final String PROP_LIACBY = "listActiveBy";
    public static final String PROP_ACTIVE = "active";
    public static final String PROP_VERSION = "version";
    public static final String PROP_SERIALIZED = "serialized";
    public static final String PROP_COMPACT = "compact";                // compact serialized form (addon attribute to serialized)  
    public static final String PROP_REF = "ref";
    public static final String PROP_SIMPLEREF = "simpleref";
    public static final String PROP_NOTNULL = "notNull";                // make a field optional in Java, but required on the DB
    public static final String PROP_NULL_WHEN_ZERO = "nullWhenZero";    // null for number 0 or for 0-length strings
    public static final String PROP_CURRENT_USER = "currentUser";
    public static final String PROP_CURRENT_TIMESTAMP = "currentTimestamp";
    public static final String PROP_SQL_DEFAULT = "SQLdefault";
    public static final String PROP_NOUPDATE = "noupdate";              // do not update existing fields (create user / timestamp)
    
    
    // create the package name for an entity or embeddable
    def public static String getBddlPackageName(EObject p) {
        if (p instanceof BDDLPackageDefinition)
            return (if (p.prefix === null) bonaparteClassDefaultPackagePrefix else p.prefix) + "." + p.name
        else
            return p.eContainer.bddlPackageName
    }

    // return true, if this is a list with lower number of elements strictly less than the upper bound.
    // In such a case, the list could be shorter, and elements therefore cannot be assumed to be not null
    def private static isPartOfVariableLengthList(FieldDefinition c) {
        c.isList !== null && c.isList.mincount < c.isList.maxcount
    }

    def public static isNotNullField(FieldDefinition f) {
        return (f.isRequired  || f.properties.hasProperty(PROP_NOTNULL))
            && !f.isPartOfVariableLengthList && !f.isASpecialEnumWithEmptyStringAsNull && !f.properties.hasProperty(PROP_NULL_WHEN_ZERO)
    }
    
    /** Escapes the parament for use in a quoted SQL string, i.e. single quotes and backslashes are doubled. */
    def public static String quoteSQL(String text) {
        return text.replace("'", "''").replace("\\", "\\\\");
    }

    def public static java2sql(String javaname) {
        CaseFormat::LOWER_CAMEL.to(CaseFormat::LOWER_UNDERSCORE, javaname);
    }


    def public static getInheritanceRoot(EntityDefinition e) {
        var EntityDefinition ee = e
        while (ee.^extends !== null)
            ee = ee.^extends
        return ee
    }

    def public static Model getModel(EObject someReference) {
        var EObject ref = someReference
        while (!(ref instanceof Model))
            ref = ref.eContainer
        // have the model, with references to Defaults and categoryList
        return ref as Model
    }

    /** Returns the Entity in which an object is defined in. Expectation is that there is a class of type PackageDefinition containing it at some level.
     * If this cannot be found, throw an Exception, because callers assume the result is not null and would throw a NPE anyway.
     */
    def public static EntityDefinition getBaseEntity(EObject ee) {
        var e = ee
        while (e !== null) {
            if (e instanceof EntityDefinition)
                return e
            e = e.eContainer
        }
        if (ee === null)
            throw new Exception("getBaseEntity() called for NULL")
        else
            throw new Exception("getBaseEntity() called for " + ee.toString())
    }

/*
    def public static TableCategoryDefinition getCategory(Model myModel, EntityDefinition t) {
        t.tableCategory

        val String category = t.tableCategory.name
        for (c : myModel.tableCategories)
            if (c.name.equals(category))
                return c
        throw new RuntimeException("could not find category <" + category + "> for Entity " + t.name)

    } */

    def public static String mkTablename(EntityDefinition t, boolean forHistory) {
        if (!forHistory && t.tablename !== null)
            t.tablename
        else if (forHistory && t.historytablename !== null)
            t.historytablename
        else {
            // build the table name according to the template in the table category or the default
            // 1. get a suitable pattern
            var String myPattern
            var String dropSuffix
            var String tablename
            var myPackage = t.eContainer as BDDLPackageDefinition
            var myModel = getModel(myPackage.eContainer)
            var TableCategoryDefinition myCategory = t.tableCategory
            if (forHistory)
                 myCategory = myCategory.historyCategory
            var theOtherModel = getModel(myCategory)

            // precedence rules for table name
            // 1. pattern of referenced category
            // 2. pattern of defaults of my model
            // 3. pattern of defaults of model which owns the category
            if (myCategory.namePattern !== null) {
                myPattern = myCategory.namePattern
                dropSuffix = myCategory.dropSuffix
            } else if (myModel.defaults !== null && myModel.defaults.namePattern !== null) {
                myPattern = myModel.defaults.namePattern
                dropSuffix = myModel.defaults.dropSuffix
            } else if (theOtherModel.defaults !== null && theOtherModel.defaults.namePattern !== null) {
                myPattern = theOtherModel.defaults.namePattern
                dropSuffix = theOtherModel.defaults.dropSuffix
            } else {
                myPattern = "(category)_(entity)"  // last fallback
                dropSuffix = null
            }
            // 2. have the pattern, apply substitution rules
            tablename = myPattern.replace("(category)", myCategory.name)
                                 .replace("(entity)",   java2sql(t.name))
                                 .replace("(prefix)",   myPackage.getDbPrefix)
                                 .replace("(owner)",    myPackage.getSchemaOwner)
                                 .replace("(package)",  myPackage.name.replace('.', '_'))
            // if the name ends in the suffix to drop, remove the suffix
            if (dropSuffix !== null) {
                var suffixLength = dropSuffix.length
                if (tablename.length > suffixLength && tablename.endsWith(dropSuffix))
                    tablename = tablename.substring(0, tablename.length - suffixLength)
            }
            return tablename
        }
    }

    def public static String mkTablespaceName(EntityDefinition t, boolean forIndex, TableCategoryDefinition myCategory) {
        if (t.tablespaceName !== null) {
            return if (forIndex && t.indexTablespacename !== null) t.indexTablespacename else t.tablespaceName
        } else {
            // no explicit advice, look in category or defaults definition
            // 1. get a suitable pattern
            var myPackage = t.eContainer as BDDLPackageDefinition
            var myModel = getModel(myPackage.eContainer)
            var theOtherModel = getModel(myCategory)
            var String myPattern

            // precedence rules for tablespace names (same as above)
            // 1. pattern of referenced category
            // 2. pattern of defaults of my model
            // 3. pattern of defaults of model which owns the category
            if (myCategory.tablespacePattern !== null) {
                myPattern = myCategory.tablespacePattern
                // fall through
            } else if (myCategory.tablespaceName !== null) {
                return if (forIndex && myCategory.indexTablespacename !== null) myCategory.indexTablespacename else myCategory.tablespaceName
            } else if (myModel.defaults !== null) {
                if (myModel.defaults.tablespacePattern !== null) {
                    myPattern = myModel.defaults.tablespacePattern
                    // fall through
                } else if (myModel.defaults.tablespaceName !== null) {
                    return if (forIndex && myModel.defaults.indexTablespacename !== null) myModel.defaults.indexTablespacename else myModel.defaults.tablespaceName
                } else {
                    return null
                }
            } else if (theOtherModel.defaults !== null) {
                if (theOtherModel.defaults.tablespacePattern !== null) {
                    myPattern = theOtherModel.defaults.tablespacePattern
                    // fall through
                } else if (theOtherModel.defaults.tablespaceName !== null) {
                    return if (forIndex && theOtherModel.defaults.indexTablespacename !== null) theOtherModel.defaults.indexTablespacename else theOtherModel.defaults.tablespaceName
                } else {
                    return null
                }
            } else {
                return null  // no default name, skip tablespace reference completely if not specified
            }
            // 2. have the pattern, apply substitution rules
            return myPattern.replace("(category)", myCategory.name)
                            .replace("(entity)",   java2sql(t.name))
                            .replace("(prefix)",   myPackage.getDbPrefix)
                            .replace("(owner)",    myPackage.getSchemaOwner)
                            .replace("(package)",  myPackage.name.replace('.', '_'))
                            .replace("(DI)",       (if (forIndex) "I" else "D"))
                            .replace("(di)",       (if (forIndex) "i" else "d"))
        }
    }
    
    // a generic iterator over the fields of a specific class, plus certain super classes.
    // Using the new Xtend lambda expressions, which allows to separate looping logic from specific output formatting.
    // All inherited classes are recursed, until a "stop" class is encountered (which is used in case of JOIN inheritance).
    // The method takes two lambdas, one for the code generation of a field, a second optional one for output of group separators.
    def public static CharSequence recurse(ClassDefinition cl, ClassDefinition stopAt, boolean includeAggregates, (FieldDefinition) => boolean filterCondition,
        List<EmbeddableUse> embeddables,
        (ClassDefinition)=> CharSequence groupSeparator,
        (FieldDefinition, String, RequiredType) => CharSequence fieldOutput) '''
        «IF cl != stopAt»
            «cl.extendsClass?.classRef?.recurse(stopAt, includeAggregates, filterCondition, embeddables, groupSeparator, fieldOutput)»
            «groupSeparator?.apply(cl)»
            «FOR c : cl.fields»
                «IF (includeAggregates || !c.isAggregate || c.properties.hasProperty(PROP_UNROLL)) && filterCondition.apply(c)»
                    «c.writeFieldWithEmbeddedAndList(embeddables, null, null, RequiredType::DEFAULT, false, "", fieldOutput)»
                «ENDIF»
            «ENDFOR»
        «ENDIF»
    '''
    
    def public static void recurseAdd(List<FieldDefinition> bucket, ClassDefinition cl, ClassDefinition stopAt, boolean includeAggregates, (FieldDefinition) => boolean filterCondition) {
        if (cl !== null && cl != stopAt) {
            // add fields of subclasses
            bucket.recurseAdd(cl.extendsClass?.classRef, stopAt, includeAggregates, filterCondition)
            for (c : cl.fields) {
                if ((includeAggregates || !c.isAggregate || c.properties.hasProperty(PROP_UNROLL)) && filterCondition.apply(c))
                    bucket.add(c)
            }
        }
    }
    def public static void recurseAddDDL(List<FieldDefinition> bucket, ClassDefinition cl, ClassDefinition stopAt, List<FieldDefinition> excludeColumns) {
        recurseAdd(bucket, cl, stopAt, false, [ !(properties.hasProperty(PROP_NODDL) || (excludeColumns !== null && excludeColumns.contains(it)))])
    }

    def public static CharSequence recurseComments(ClassDefinition cl, ClassDefinition stopAt, String tablename, List<EmbeddableUse> embeddables) {
        recurse(cl, stopAt, false,
                [ comment !== null && !properties.hasProperty(PROP_NODDL) ],
                embeddables,
                [ '''-- comments for columns of java class «name»
                  '''],
                [ fld, myName, req | '''
                    «IF fld.comment !== null»
                        COMMENT ON COLUMN «tablename».«myName.java2sql» IS '«fld.comment.quoteSQL»';
                    «ENDIF»
                  ''']
        )
    }

    def public static boolean inList(List<FieldDefinition> pkColumns, FieldDefinition c) {
        if (pkColumns === null)
            return false
        for (i : pkColumns)
            if (i == c)
                return true
        return false
    }


    def public static String asEmbeddedName(String myName, String prefix, String suffix) {
        if (prefix === null)
            '''«myName»«suffix»'''
        else
            '''«prefix»«myName.toFirstUpper»«suffix»'''
    }
    
    def private static listForPattern(String pattern, int max) {
        return (1..max).map[String.format(pattern, it)]
    }
    
    def public static indexList(FieldDefinition f) {
        if (f.isList === null || !f.properties.hasProperty(PROP_UNROLL))
            return null
        val userPattern = f.properties.getProperty(PROP_UNROLL)
        if (userPattern === null || userPattern.length == 0)
            return listForPattern("%02d", f.isList.maxcount)           // default 2 digit counter
        if (userPattern.indexOf('%') >= 0)
            return listForPattern(userPattern, f.isList.maxcount)      // user specific counter
        return Arrays.asList(userPattern.split(','))                    // fallback: explicit list of field names, length of it also determines the maximum number of entries
    }
    
    // output a single field (which maybe expands to multiple DB columns due to embeddables and List expansion. The field could be used from an entity or an embeddable
    def public static CharSequence writeFieldWithEmbeddedAndList(FieldDefinition f, List<EmbeddableUse> embeddables, String prefix, String suffix,
        RequiredType reqType,
        boolean noListAtThisPoint, String separator, (FieldDefinition, String, RequiredType) => CharSequence func) {
        // expand Lists first
        val myName = f.name.asEmbeddedName(prefix, suffix)
        val myIndexList = f.indexList
        if (!noListAtThisPoint && myIndexList !== null) {
            // lists almost always correspond to nullable fields because we don't know the number of elements
            val newRequired = if (reqType == RequiredType::FORCE_NOT_NULL /* || f.isAggregateRequired */) reqType else RequiredType::FORCE_NULL;
            // val newRequiredInitial = if (reqType == RequiredType::FORCE_NOT_NULL || f.isAggregateRequired) reqType else RequiredType::FORCE_NULL;
            // actually, if the List is required AND we have a mincount > 0, then the first fields will actually be required:  if (it > f.isList.mincount) newRequired else newRequiredInitial
            myIndexList.map[f.writeFieldWithEmbeddedAndList(embeddables, prefix, '''«suffix»«it»''' , newRequired, true, separator, func)].join(separator)
        } else {
            // see if we need embeddables expansion
            val emb = embeddables?.findFirst[field == f]
            // System.out.println('''****** Field «f.name»: found emb = «emb !== null»''')
            if (emb !== null) {
                // expand embeddable, output it instead of the original column
                val objectName = emb.name.pojoType.name
                val nameLengthDiff = f.name.length - objectName.length
                val tryDefaults = emb.prefix === null && emb.suffix === null && nameLengthDiff > 0
                val finalPrefix = if (tryDefaults && f.name.endsWith(objectName)) f.name.substring(0, nameLengthDiff) else emb.prefix             // Address homeAddress => prefix home
                val finalSuffix = if (tryDefaults && f.name.startsWith(objectName.toFirstLower)) f.name.substring(objectName.length) else emb.suffix // Amount amountBc => suffix Bc
                val newPrefix = '''«prefix»«finalPrefix»'''
                val newSuffix = '''«finalSuffix»«suffix»'''
                val newRequired = if (reqType == RequiredType::FORCE_NOT_NULL || f.isRequired) reqType else RequiredType::FORCE_NULL;
                //System::out.println('''SQL: «myName» defts=«tryDefaults»: nldiff=«nameLengthDiff», emb.pre=«emb.prefix», emb.suff=«emb.suffix»!''')
                //System::out.println('''SQL: «myName» defts=«tryDefaults»: has in=(«prefix»,«suffix»), final=(«finalPrefix»,«finalSuffix»), new=(«newPrefix»,«newSuffix»)''')
                emb.name.pojoType.allFields.map[writeFieldWithEmbeddedAndList(emb.name.embeddables, newPrefix, newSuffix, newRequired, false, separator, func)].join(separator)
            } else {
                // regular field
                func.apply(f, myName, reqType)
            }
        }
    }
    
    def public static countEmbeddablePks(EntityDefinition e) {
        if (e.embeddables === null)
            return 0
        return e.embeddables.filter[isPk !== null].size
    }
    def public static getEmbeddablePk(EntityDefinition e) {
        return e?.embeddables.filter[isPk !== null].head
    }
    
    def public static determinePkType(EntityDefinition e) {
        if (e.pk !== null) {
            if (e.pk.columnName.size > 1)
                PrimaryKeyType::IMPLICIT_EMBEDDABLE
            else
                PrimaryKeyType::SINGLE_COLUMN
        } else if (e.pkPojo !== null) {
            PrimaryKeyType::ID_CLASS
        } else if (e.embeddablePk !== null)
            PrimaryKeyType::EXPLICIT_EMBEDDABLE
        else
            PrimaryKeyType::NONE
    }
    
    // checks if the field f is an elementcollection for entity e
    // this methods checks the definitions of the entity itself, as well as in any parent entity
    def public static boolean isInElementCollection(FieldDefinition f, EntityDefinition e) {
        var ee = e;
        while (ee !== null) {
            if (ee.elementCollections !== null && ee.elementCollections.exists[name == f])
                return true
            ee = e.^extends
        }
        return false
    }
    
    /** Returns a list of the main columns in the primary key of an entity, or null if no PK exists.
     * The fields not included are:
     * element collection map key,
     * history sequence number
     * 
     */
    def public static primaryKeyColumns(EntityDefinition e) {
        val baseEntity = e.inheritanceRoot // for derived tables, the original (root) table
        return if (baseEntity.embeddablePk !== null)
                baseEntity.embeddablePk.name.pojoType.fields
            else if (baseEntity.pk !== null)
                baseEntity.pk.columnName
            else if (baseEntity.pkPojo !== null)
                baseEntity.pkPojo.fields
            else null
    }
        
    /** Returns a list of the main non-primary key columns of an entity. This list may be empty, but the response is never null.
     * The non-included columns are:
     * discriminators for inheritance, history change type
     * 
     */
    def public static nonPrimaryKeyColumns(EntityDefinition t, boolean descendForTablePerClass) {
        val resultList = new ArrayList<FieldDefinition>(50)
        val baseEntity = t.inheritanceRoot // for derived tables, the original (root) table
        val myPrimaryKeyColumns = t.primaryKeyColumns
        val ClassDefinition stopAt = if (t.inheritanceRoot.xinheritance == Inheritance::JOIN) t.^extends?.pojoType else null // stop column recursion for JOINed tables
        val tenantClass = if (t.tenantInJoinedTables || t.inheritanceRoot.xinheritance == Inheritance::TABLE_PER_CLASS)
            baseEntity.tenantClass
        else
            t.tenantClass  // for joined tables, only repeat the tenant if the DSL says so
            
        if (stopAt === null)
            recurseAddDDL(resultList, t.tableCategory.trackingColumns, null, myPrimaryKeyColumns)
        recurseAddDDL(resultList, tenantClass, null, myPrimaryKeyColumns)
        recurseAddDDL(resultList, t.pojoType, stopAt, myPrimaryKeyColumns)
        return resultList
    }

    def static private List<EmbeddableUse> combinedEmbeddables(EntityDefinition t, List<EmbeddableUse> work) {
        work.addAll(t.embeddables)
        if (t.^extends !== null)
            t.^extends.combinedEmbeddables(work)
        work
    }
    def static public theEmbeddables(EntityDefinition t) {
        return if (t.inheritanceRoot.xinheritance == Inheritance::TABLE_PER_CLASS) t.combinedEmbeddables(new ArrayList<EmbeddableUse>()) else t.embeddables
    }
}
