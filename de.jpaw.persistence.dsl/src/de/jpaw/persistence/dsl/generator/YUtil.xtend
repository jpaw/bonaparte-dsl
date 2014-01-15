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

package de.jpaw.persistence.dsl.generator

import com.google.common.base.CaseFormat
import de.jpaw.persistence.dsl.bDDL.EntityDefinition
import de.jpaw.persistence.dsl.bDDL.Model
import org.eclipse.emf.ecore.EObject
import de.jpaw.persistence.dsl.bDDL.TableCategoryDefinition
import de.jpaw.persistence.dsl.bDDL.PackageDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import de.jpaw.persistence.dsl.bDDL.EmbeddableUse
import java.util.List

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
    public static final String PROP_REF = "ref";
    public static final String PROP_NOTNULL = "notNull";    // make a field optional in Java, but required on the DB
    public static final String PROP_CURRENT_USER = "currentUser";
    public static final String PROP_CURRENT_TIMESTAMP = "currentTimestamp";
    public static final String PROP_SQL_DEFAULT = "SQLdefault";
    
    
    /** Escapes the parament for use in a quoted SQL string, i.e. single quotes and backslashes are doubled. */
    def public static String quoteSQL(String text) {
        return text.replace("'", "''").replace("\\", "\\\\");
    }

    def public static java2sql(String javaname) {
        CaseFormat::LOWER_CAMEL.to(CaseFormat::LOWER_UNDERSCORE, javaname);
    }


    def public static getInheritanceRoot(EntityDefinition e) {
        var EntityDefinition ee = e
        while (ee.^extends != null)
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
    def public static getBaseEntity(EObject ee) {
        var e = ee
        while (e != null) {
            if (e instanceof EntityDefinition)
                return e as EntityDefinition
            e = e.eContainer
        }
        if (ee == null)
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
        if (!forHistory && t.tablename != null)
            t.tablename
        else if (forHistory && t.historytablename != null)
            t.historytablename
        else {
            // build the table name according to the template in the table category or the default
            // 1. get a suitable pattern
            var String myPattern
            var String dropSuffix
            var String tablename
            var myPackage = t.eContainer as PackageDefinition
            var myModel = getModel(myPackage.eContainer)
            var TableCategoryDefinition myCategory = t.tableCategory
            if (forHistory)
                 myCategory = myCategory.historyCategory
            var theOtherModel = getModel(myCategory)

            // precedence rules for table name
            // 1. pattern of referenced category
            // 2. pattern of defaults of my model
            // 3. pattern of defaults of model which owns the category
            if (myCategory.namePattern != null) {
                myPattern = myCategory.namePattern
                dropSuffix = myCategory.dropSuffix
            } else if (myModel.defaults != null && myModel.defaults.namePattern != null) {
                myPattern = myModel.defaults.namePattern
                dropSuffix = myModel.defaults.dropSuffix
            } else if (theOtherModel.defaults != null && theOtherModel.defaults.namePattern != null) {
                myPattern = theOtherModel.defaults.namePattern
                dropSuffix = theOtherModel.defaults.dropSuffix
            } else {
                myPattern = "(category)_(entity)"  // last fallback
                dropSuffix = null
            }
            // 2. have the pattern, apply substitution rules
            tablename = myPattern.replace("(category)", myCategory.name)
                                 .replace("(entity)",   java2sql(t.name))
                                 .replace("(prefix)",   myPackage.dbPrefix)
                                 .replace("(owner)",    myPackage.schemaOwner)
                                 .replace("(package)",  myPackage.name.replace('.', '_'))
            // if the name ends in the suffix to drop, remove the suffix
            if (dropSuffix != null) {
                var suffixLength = dropSuffix.length
                if (tablename.length > suffixLength && tablename.endsWith(dropSuffix))
                    tablename = tablename.substring(0, tablename.length - suffixLength)
            }
            return tablename
        }
    }

    def public static String mkTablespaceName(EntityDefinition t, boolean forIndex, TableCategoryDefinition myCategory) {
        if (t.tablespaceName != null) {
            return if (forIndex && t.indexTablespacename != null) t.indexTablespacename else t.tablespaceName
        } else {
            // no explicit advice, look in category or defaults definition
            // 1. get a suitable pattern
            var myPackage = t.eContainer as PackageDefinition
            var myModel = getModel(myPackage.eContainer)
            var theOtherModel = getModel(myCategory)
            var String myPattern

            // precedence rules for tablespace names (same as above)
            // 1. pattern of referenced category
            // 2. pattern of defaults of my model
            // 3. pattern of defaults of model which owns the category
            if (myCategory.tablespacePattern != null) {
                myPattern = myCategory.tablespacePattern
                // fall through
            } else if (myCategory.tablespaceName != null) {
                return if (forIndex && myCategory.indexTablespacename != null) myCategory.indexTablespacename else myCategory.tablespaceName
            } else if (myModel.defaults != null) {
                if (myModel.defaults.tablespacePattern != null) {
                    myPattern = myModel.defaults.tablespacePattern
                    // fall through
                } else if (myModel.defaults.tablespaceName != null) {
                    return if (forIndex && myModel.defaults.indexTablespacename != null) myModel.defaults.indexTablespacename else myModel.defaults.tablespaceName
                } else {
                    return null
                }
            } else if (theOtherModel.defaults != null) {
                if (theOtherModel.defaults.tablespacePattern != null) {
                    myPattern = theOtherModel.defaults.tablespacePattern
                    // fall through
                } else if (theOtherModel.defaults.tablespaceName != null) {
                    return if (forIndex && theOtherModel.defaults.indexTablespacename != null) theOtherModel.defaults.indexTablespacename else theOtherModel.defaults.tablespaceName
                } else {
                    return null
                }
            } else {
                return null  // no default name, skip tablespace reference completely if not specified
            }
            // 2. have the pattern, apply substitution rules
            return myPattern.replace("(category)", t.tableCategory.name)
                            .replace("(entity)",   java2sql(t.name))
                            .replace("(prefix)",   myPackage.dbPrefix)
                            .replace("(owner)",    myPackage.schemaOwner)
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

    def public static CharSequence recurseComments(ClassDefinition cl, ClassDefinition stopAt, String tablename, List<EmbeddableUse> embeddables) {
        recurse(cl, stopAt, false,
                [ comment != null && !properties.hasProperty(PROP_NODDL) ],
                embeddables,
                [ '''-- comments for columns of java class «name»
                  '''],
                [ fld, myName, req | '''
                    «IF fld.comment != null»
                        COMMENT ON COLUMN «tablename».«myName.java2sql» IS '«fld.comment.quoteSQL»';
                    «ENDIF»
                  ''']
        )
    }

    def public static CharSequence recurseDataGetter(ClassDefinition cl, ClassDefinition stopAt, List<EmbeddableUse> embeddables) {
        recurse(cl, stopAt, true,
                [ !properties.hasProperty(PROP_NODDL) ],
                embeddables,
                [ '''// auto-generated data getter for «name»
                  '''],
                [ fld, myName, req | '''_r.set«myName.toFirstUpper»(get«myName.toFirstUpper»());
                  ''']
        )
    }

    def public static CharSequence recurseDataSetter(ClassDefinition cl, ClassDefinition stopAt, EntityDefinition avoidKeyOf, List<EmbeddableUse> embeddables) {
        recurse(cl, stopAt, true,
                [ (avoidKeyOf == null || !isKeyField(avoidKeyOf, it)) && !properties.hasProperty(PROP_NOJAVA) ],
                embeddables,
                [ '''// auto-generated data setter for «name»
                  '''],
                [ fld, myName, req | '''set«myName.toFirstUpper»(_d.get«myName.toFirstUpper»());
                  ''']
        )
    }

    def public static isKeyField(EntityDefinition e, FieldDefinition f) {
        if (e.pk != null) {
            for (FieldDefinition i: e.pk.columnName) {
                if (i == f)
                    return true
            }
        }
        return false
    }

    def public static String asEmbeddedName(String myName, String prefix, String suffix) {
        if (prefix == null)
            '''«myName»«suffix»'''
        else
            '''«prefix»«myName.toFirstUpper»«suffix»'''
    }
    
    def public static indexPattern(FieldDefinition f) {
        val userPattern = f.properties.getProperty(PROP_UNROLL)
        val p = if (userPattern != null && userPattern.length > 0) userPattern.indexOf('%') else -1
        if (p >= 0) userPattern else "%02d"        
    }
    
    // output a single field (which maybe expands to multiple DB columns due to embeddables and List expansion. The field could be used from an entity or an embeddable
    def public static CharSequence writeFieldWithEmbeddedAndList(FieldDefinition f, List<EmbeddableUse> embeddables, String prefix, String suffix,
        RequiredType reqType,
        boolean noListAtThisPoint, String separator, (FieldDefinition, String, RequiredType) => CharSequence func) {
        // expand Lists first
        val myName = f.name.asEmbeddedName(prefix, suffix)
        if (!noListAtThisPoint && f.isList != null && f.isList.maxcount > 0 && f.properties.hasProperty(PROP_UNROLL)) {
            val indexPattern = f.indexPattern;
            // lists almost always correspond to nullable fields because we don't know the number of elements
            val newRequired = if (reqType == RequiredType::FORCE_NOT_NULL /* || f.isAggregateRequired */) reqType else RequiredType::FORCE_NULL;
            val newRequiredInitial = if (reqType == RequiredType::FORCE_NOT_NULL || f.isAggregateRequired) reqType else RequiredType::FORCE_NULL;
            // actually, if the List is required AND we have a mincount > 0, then the first fields will actually be required
            (1 .. f.isList.maxcount).map[f.writeFieldWithEmbeddedAndList(embeddables, prefix, '''«suffix»«String::format(indexPattern, it)»''' , if (it > f.isList.mincount) newRequired else newRequiredInitial, true, separator, func)].join(separator)
        } else {
            // see if we need embeddables expansion
            val emb = embeddables?.findFirst[field == f]
            // System.out.println('''****** Field «f.name»: found emb = «emb != null»''')
            if (emb != null) {
                // expand embeddable, output it instead of the original column
                val objectName = emb.name.pojoType.name
                val nameLengthDiff = f.name.length - objectName.length
                val tryDefaults = emb.prefix == null && emb.suffix == null && nameLengthDiff > 0
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
        if (e.embeddables == null)
            return 0
        return e.embeddables.filter[isPk != null].size
    }
    def public static getEmbeddablePk(EntityDefinition e) {
        return e?.embeddables.filter[isPk != null].head
    }
    
    def public static determinePkType(EntityDefinition e) {
        if (e.pk != null) {
            if (e.pk.columnName.size > 1)
                PrimaryKeyType::IMPLICIT_EMBEDDABLE
            else
                PrimaryKeyType::SINGLE_COLUMN
        } else if (e.pkPojo != null) {
            PrimaryKeyType::ID_CLASS
        } else if (e.embeddablePk != null)
            PrimaryKeyType::EXPLICIT_EMBEDDABLE
        else
            PrimaryKeyType::NONE
    }
        
}
