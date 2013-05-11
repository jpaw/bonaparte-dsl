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
import de.jpaw.bonaparte.dsl.generator.Util
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*

class YUtil {
    def public static String quoteSQL(String text) {
        return text.replace("'", "''").replace("\\", "\\\\");
    }
    
    def public static java2sql(String javaname) {
        CaseFormat::LOWER_CAMEL.to(CaseFormat::LOWER_UNDERSCORE, javaname);
    }

    def public static String columnName(FieldDefinition c) {
        return java2sql(c.name)  // allow to add column data type prefixes here... (systems Hungarian notation: http://en.wikipedia.org/wiki/Hungarian_notation)
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
    
    def public static CharSequence recurseComments(ClassDefinition cl, ClassDefinition stopAt, String tablename) {
        recurse(cl, stopAt, false,
                [ it.comment != null ],
                [ '''-- comments for columns of java class «it.name»
                  '''],
                [ '''COMMENT ON COLUMN «tablename».«columnName(it)» IS '«quoteSQL(it.comment)»';
                  ''']
        )
    }
    
    def public static CharSequence recurseDataGetter(ClassDefinition cl, ClassDefinition stopAt) {
        recurse(cl, stopAt, true,
                [ !hasProperty(it.properties, "noJava") ],
                [ '''// auto-generated data getter for «it.name»
                  '''],
                [ '''_r.set«Util::capInitial(it.name)»(get«Util::capInitial(it.name)»());
                  ''']
        )
    }
    
    def public static CharSequence recurseDataSetter(ClassDefinition cl, ClassDefinition stopAt, EntityDefinition avoidKeyOf) {
        recurse(cl, stopAt, false,
                [ (avoidKeyOf == null || !isKeyField(avoidKeyOf, it)) && !hasProperty(it.properties, "noJava") ],
                [ '''// auto-generated data setter for «it.name»
                  '''],
                [ '''set«Util::capInitial(it.name)»(_d.get«Util::capInitial(it.name)»());
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
    
}