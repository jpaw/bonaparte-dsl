package de.jpaw.bonaparte.jpa.dsl.validation;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EStructuralFeature;
import org.eclipse.xtext.validation.Check;

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition;
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition;
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension;
import de.jpaw.bonaparte.jpa.dsl.BDDLPreferences;
import de.jpaw.bonaparte.jpa.dsl.bDDL.BDDLPackage;
import de.jpaw.bonaparte.jpa.dsl.bDDL.CollectionDefinition;
import de.jpaw.bonaparte.jpa.dsl.bDDL.ConverterDefinition;
import de.jpaw.bonaparte.jpa.dsl.bDDL.ElementCollectionRelationship;
import de.jpaw.bonaparte.jpa.dsl.bDDL.EmbeddableDefinition;
import de.jpaw.bonaparte.jpa.dsl.bDDL.EmbeddableUse;
import de.jpaw.bonaparte.jpa.dsl.bDDL.EntityDefinition;
import de.jpaw.bonaparte.jpa.dsl.bDDL.OneToMany;
import de.jpaw.bonaparte.jpa.dsl.bDDL.Relationship;
import de.jpaw.bonaparte.jpa.dsl.bDDL.TableCategoryDefinition;
import static extension de.jpaw.bonaparte.jpa.dsl.generator.YUtil.*;
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*;

class BDDLValidator extends AbstractBDDLValidator {

    def private void checkTablenameLength(String s, EStructuralFeature where) {
        // leave room for suffixes like _t(n) or _pk or _i(n) / _j(n) for index naming
        // DEBUG, as this does not seem to work!
//        System.out.println("Checking table name " + s + " of length " + s.length() + " against configured limit of " + BDDLPreferences.currentPrefs.maxTablenameLength);
        if (s.length() > BDDLPreferences.currentPrefs.maxTablenameLength)
            error("The resulting SQL table or related index name " + s + " exceeds the maximum configured length of " + BDDLPreferences.currentPrefs.maxTablenameLength + " characters and will not work for some database brands",
                where);
    }
    def private void checkFieldnameLength(String s, EStructuralFeature where) {
        // leave room for suffixes like _t(n) or _pk or _i(n) / _j(n) for index naming
        if (s.length() > BDDLPreferences.currentPrefs.maxFieldnameLength)
            error("The field name " + s + " exceeds the maximum configured length of " + BDDLPreferences.currentPrefs.maxFieldnameLength + " characters and will not work for some database brands",
                where);
    }
    
    // check the length of all fields in the referenced class as well as classes inherited from
    def private void checkClassForColumnLengths(ClassDefinition c, EStructuralFeature where) {
        for (f : c.allFields)
            checkFieldnameLength(f.name, where)
    }
    
    def static private createAndPopulateReservedSQL() {
        val RESERVED_SQL = new HashMap<String,String>(200);
        RESERVED_SQL.put("ACCESS", "-O");
        RESERVED_SQL.put("ADD", "-O");
        RESERVED_SQL.put("ALL", "AO");
        RESERVED_SQL.put("ALTER", "AO");
        RESERVED_SQL.put("AND", "AO");
        RESERVED_SQL.put("ANY", "AO");
        RESERVED_SQL.put("AS", "AO");
        RESERVED_SQL.put("ASC", "-O");
        RESERVED_SQL.put("AUDIT", "-O");
        RESERVED_SQL.put("BETWEEN", "AO");
        RESERVED_SQL.put("BY", "AO");
        RESERVED_SQL.put("CHAR", "AO");
        RESERVED_SQL.put("CHECK", "AO");
        RESERVED_SQL.put("CLUSTER", "-O");
        RESERVED_SQL.put("COLUMN", "AO");
        RESERVED_SQL.put("COLUMN_VALUE", "-O");
        RESERVED_SQL.put("COMMENT", "-O");
        RESERVED_SQL.put("COMPRESS", "-O");
        RESERVED_SQL.put("CONNECT", "AO");
        RESERVED_SQL.put("CREATE", "AO");
        RESERVED_SQL.put("CURRENT", "AO");
        RESERVED_SQL.put("DATE", "AO");
        RESERVED_SQL.put("DECIMAL", "AO");
        RESERVED_SQL.put("DEFAULT", "AO");
        RESERVED_SQL.put("DELETE", "AO");
        RESERVED_SQL.put("DESC", "-O");
        RESERVED_SQL.put("DISTINCT", "AO");
        RESERVED_SQL.put("DROP", "AO");
        RESERVED_SQL.put("ELSE", "AO");
        RESERVED_SQL.put("EXCLUSIVE", "-O");
        RESERVED_SQL.put("EXISTS", "AO");
        RESERVED_SQL.put("FILE", "-O");
        RESERVED_SQL.put("FLOAT", "AO");
        RESERVED_SQL.put("FOR", "AO");
        RESERVED_SQL.put("FROM", "AO");
        RESERVED_SQL.put("GRANT", "AO");
        RESERVED_SQL.put("GROUP", "AO");
        RESERVED_SQL.put("HAVING", "AO");
        RESERVED_SQL.put("IDENTIFIED", "-O");
        RESERVED_SQL.put("IMMEDIATE", "-O");
        RESERVED_SQL.put("IN", "AO");
        RESERVED_SQL.put("INCREMENT", "-O");
        RESERVED_SQL.put("INDEX", "-O");
        RESERVED_SQL.put("INITIAL", "-O");
        RESERVED_SQL.put("INSERT", "AO");
        RESERVED_SQL.put("INTEGER", "AO");
        RESERVED_SQL.put("INTERSECT", "AO");
        RESERVED_SQL.put("INTO", "AO");
        RESERVED_SQL.put("IS", "AO");
        RESERVED_SQL.put("LEVEL", "-O");
        RESERVED_SQL.put("LIKE", "AO");
        RESERVED_SQL.put("LOCK", "-O");
        RESERVED_SQL.put("LONG", "-O");
        RESERVED_SQL.put("MAXEXTENTS", "-O");
        RESERVED_SQL.put("MINUS", "-O");
        RESERVED_SQL.put("MLSLABEL", "-O");
        RESERVED_SQL.put("MODE", "-O");
        RESERVED_SQL.put("MODIFY", "-O");
        RESERVED_SQL.put("NESTED_TABLE_ID", "-O");
        RESERVED_SQL.put("NOAUDIT", "-O");
        RESERVED_SQL.put("NOCOMPRESS", "-O");
        RESERVED_SQL.put("NOT", "AO");
        RESERVED_SQL.put("NOWAIT", "-O");
        RESERVED_SQL.put("NULL", "AO");
        RESERVED_SQL.put("NUMBER", "-O");
        RESERVED_SQL.put("OF", "AO");
        RESERVED_SQL.put("OFFLINE", "-O");
        RESERVED_SQL.put("ON", "AO");
        RESERVED_SQL.put("ONLINE", "-O");
        RESERVED_SQL.put("OPTION", "-O");
        RESERVED_SQL.put("OR", "AO");
        RESERVED_SQL.put("ORDER", "AO");
        RESERVED_SQL.put("PCTFREE", "-O");
        RESERVED_SQL.put("PRIOR", "-O");
        RESERVED_SQL.put("PRIVILEGES", "-O");
        RESERVED_SQL.put("PUBLIC", "-O");
        RESERVED_SQL.put("RAW", "-O");
        RESERVED_SQL.put("RENAME", "-O");
        RESERVED_SQL.put("RESOURCE", "-O");
        RESERVED_SQL.put("REVOKE", "AO");
        RESERVED_SQL.put("ROW", "AO");
        RESERVED_SQL.put("ROWID", "-O");
        RESERVED_SQL.put("ROWNUM", "-O");
        RESERVED_SQL.put("ROWS", "AO");
        RESERVED_SQL.put("SELECT", "AO");
        RESERVED_SQL.put("SESSION", "-O");
        RESERVED_SQL.put("SET", "AO");
        RESERVED_SQL.put("SHARE", "-O");
        RESERVED_SQL.put("SIZE", "-O");
        RESERVED_SQL.put("SMALLINT", "AO");
        RESERVED_SQL.put("START", "AO");
        RESERVED_SQL.put("SUCCESSFUL", "-O");
        RESERVED_SQL.put("SYNONYM", "-O");
        RESERVED_SQL.put("SYSDATE", "-O");
        RESERVED_SQL.put("TABLE", "AO");
        RESERVED_SQL.put("THEN", "AO");
        RESERVED_SQL.put("TO", "AO");
        RESERVED_SQL.put("TRIGGER", "AO");
        RESERVED_SQL.put("UID", "-O");
        RESERVED_SQL.put("UNION", "AO");
        RESERVED_SQL.put("UNIQUE", "AO");
        RESERVED_SQL.put("UPDATE", "AO");
        RESERVED_SQL.put("USER", "AO");
        RESERVED_SQL.put("VALIDATE", "-O");
        RESERVED_SQL.put("VALUES", "AO");
        RESERVED_SQL.put("VARCHAR", "AO");
        RESERVED_SQL.put("VARCHAR2", "-O");
        RESERVED_SQL.put("VIEW", "-O");
        RESERVED_SQL.put("WHENEVER", "AO");
        RESERVED_SQL.put("WHERE", "AO");
        RESERVED_SQL.put("WITH", "AO");
        
        return RESERVED_SQL
    }
    // SQL reserved words - column names are checked against these
    static private final Map<String,String> RESERVED_SQL = createAndPopulateReservedSQL;

    def private static boolean exists(FieldDefinition f, List<FieldDefinition> l) {
        return l.exists[it.name == f.name];
    }
    
    def private void checkClassForReservedColumnNames(ClassDefinition cc, EStructuralFeature feature) {
        var c = cc
        while (c !== null) {
            for (f : c.getFields()) {
                val usedWhere = RESERVED_SQL.get(java2sql(f.name).toUpperCase());
                if (usedWhere !== null) {
                    if (usedWhere.indexOf('A') >= 0) {
                        error("The field name " + c.name + "." + f.name + " results in a reserved word for ANSI SQL", feature);
                    } else {
                        warning("The field name " + c.name + "." + f.name + " results in a reserved word for "
                            + (if (usedWhere.indexOf('O') >= 0) "Oracle SQL" else "Postgresql"), feature);
                    }
                }
            }
            c = c.extendsClass?.classRef;
        }
    }

    @Check
    def public void checkTableCategoryDefinition(TableCategoryDefinition c) {
        checkClassForReservedColumnNames(c.getTrackingColumns(), BDDLPackage.Literals.TABLE_CATEGORY_DEFINITION__TRACKING_COLUMNS);
        if (c.getHistoryCategory() !== null) {
            // validate that the category requires a primary key, and that the history category defines history columns
            if (!c.isRequiresPk())
                error("table categories with a history must require a primary key", BDDLPackage.Literals.TABLE_CATEGORY_DEFINITION__HISTORY_CATEGORY);
            val hisCategory = c.getHistoryCategory();
            if (hisCategory.getHistorySequenceColumn() === null)
                error("references categories for history does not define a history sequence column", BDDLPackage.Literals.TABLE_CATEGORY_DEFINITION__HISTORY_CATEGORY);
            // the prior check also implies that the history category does not request another history category (by grammar rule)
        }
    }
    
    @Check
    def public void checkEntity(EntityDefinition e) {
        val s = e.name
        if (s !== null) {
            if (!Character.isUpperCase(s.charAt(0))) {
                error("Entity names should start with an upper case letter",
                        BDDLPackage.Literals.ENTITY_DEFINITION__NAME);
            }
        }
        if (e.extends !== null) {
            // parent must extend as well or define inheritance
            if ((e.extends.extends === null) && (e.extends.getXinheritance() === null)) {
                error("entities inherited from must define inheritance properties",
                        BDDLPackage.Literals.ENTITY_DEFINITION__EXTENDS);
            }

            // verify that we do not use extends together with extendsClass or extendsJava
            if ((e.getExtendsClass() !== null) || (e.getExtendsJava() !== null)) {
                error("entities inherited from cannot use extendsJava or extends in additon", BDDLPackage.Literals.ENTITY_DEFINITION__EXTENDS);
            }
        }

        val tablename = e.mkTablename(false);
        checkTablenameLength(tablename, if (e.getTablename() !== null) BDDLPackage.Literals.ENTITY_DEFINITION__TABLENAME else BDDLPackage.Literals.ENTITY_DEFINITION__NAME);
        
        if (e.getTableCategory().getHistoryCategory() !== null) {
            val historytablename = e.mkTablename(true);
            checkTablenameLength(historytablename, if (e.getHistorytablename() !== null) BDDLPackage.Literals.ENTITY_DEFINITION__HISTORYTABLENAME else BDDLPackage.Literals.ENTITY_DEFINITION__NAME);
        } else if (e.getHistorytablename() !== null) {
            error("History tablename provided, but table category does not specify use of history",
                  BDDLPackage.Literals.ENTITY_DEFINITION__HISTORYTABLENAME);
        }

        // verify for primary key
        // check for embeddable PK
        var numPks = e.countEmbeddablePks
        if (numPks > 1) {
            error("At most one embeddable may be defined as PK", BDDLPackage.Literals.ENTITY_DEFINITION__EMBEDDABLES);
        }
        // we need one by definition of the category
        if (e.getPk() !== null) {
            numPks += 1;
            if (numPks > 1) {
                error("Pimary key already specified by embeddables, no separate PK definition allowed", BDDLPackage.Literals.ENTITY_DEFINITION__PK);

            }
        }
        if (e.getPkPojo() !== null) {
            numPks += 1;
            if (numPks > 1) {
                error("Pimary key already specified by embeddables, no separate PK definition allowed", BDDLPackage.Literals.ENTITY_DEFINITION__PK_POJO);

            }
        }
        if (numPks == 0 && e.getTableCategory().isRequiresPk()) {
            error("The table category requires specificaton of a primary key for this entity",
                   BDDLPackage.Literals.ENTITY_DEFINITION__TABLE_CATEGORY);
        }

        if (e.getXinheritance() !== null) {
            switch (e.getXinheritance()) {
            case NONE:
                if (e.getDiscname() !== null) {
                    error("discriminator without inheritance", BDDLPackage.Literals.ENTITY_DEFINITION__DISCNAME);
                }
            case TABLE_PER_CLASS:
                if (e.getDiscname() !== null) {
                    warning("TABLE_PER_CLASS inheritance does not need a discriminator", BDDLPackage.Literals.ENTITY_DEFINITION__DISCNAME);
                }
            case SINGLE_TABLE:
                if (e.getDiscname() === null) {
                    error("JOIN / SINGLE_TABLE inheritance require a discriminator", BDDLPackage.Literals.ENTITY_DEFINITION__DISCNAME);
                }
            case JOIN:
                if (e.getDiscname() === null) {
                    error("JOIN / SINGLE_TABLE inheritance require a discriminator", BDDLPackage.Literals.ENTITY_DEFINITION__DISCNAME);
                }
            default:
                {}
            }
        }

        if (e.getCollections() !== null && e.getCollections().size() > 0) {
            if (e.getPk() === null || e.getPk().getColumnName().size() != 1) {
                error("Collections components only allowed for entities with a single column primary key", BDDLPackage.Literals.ENTITY_DEFINITION__COLLECTIONS);
                return;
            }
        }
        
        if (e.getTenantClass() !== null) {
            checkClassForReservedColumnNames(e.getTenantClass(), BDDLPackage.Literals.ENTITY_DEFINITION__TENANT_CLASS);
            checkClassForColumnLengths      (e.getTenantClass(), BDDLPackage.Literals.ENTITY_DEFINITION__TENANT_CLASS);
        }
        checkClassForReservedColumnNames(e.getPojoType(), BDDLPackage.Literals.ENTITY_DEFINITION__POJO_TYPE);
        checkClassForColumnLengths      (e.getPojoType(), BDDLPackage.Literals.ENTITY_DEFINITION__TENANT_CLASS);
        
        // for PK pojo, all columns must exist
        if (e.getPkPojo() !== null) {
            // this must be either a final class, or a superclass
            if (e.getPkPojo().isFinal()) {
                for (FieldDefinition f : e.getPkPojo().getFields()) {
                    if (exists(f, e.getPojoType().getFields())) {
                        // nothing
                    } else if (e.getTenantClass() !== null && exists(f, e.getTenantClass().getFields())) {
                        // nothing
                    } else {
                        error("Field " + f.getName() + " of final PK not found in entity", BDDLPackage.Literals.ENTITY_DEFINITION__PK_POJO);
                    }
                }
            } else {
                // must be a superclass
                var dd = e.getPojoType();
                while (dd !== null && dd != e.getPkPojo()) {
                    dd = dd.extendsClass?.classRef;
                }
                if (dd === null)
                    error("A PK class which is not final must be a superclass of the definining DTO", BDDLPackage.Literals.ENTITY_DEFINITION__PK_POJO);
            }
        }
    }
    
    @Check
    def public void checkCollection(CollectionDefinition c) {
        if (c.getMap() !== null && c.getMap().getIsMap() !== null) {
            error("Collections component only allowed to reference fields which are a Map<>", BDDLPackage.Literals.COLLECTION_DEFINITION__MAP);
            return;
        }

        if (c.getTablename() !== null)
            checkTablenameLength(c.getTablename(), BDDLPackage.Literals.COLLECTION_DEFINITION__TABLENAME);
    }

    @Check
    def public void checkRelationship(Relationship m2o) {
        val s = m2o.getName();
        if (s !== null) {
            if (!Character.isLowerCase(s.charAt(0))) {
                error("relationship (field) names should start with a lower case letter",
                        BDDLPackage.Literals.RELATIONSHIP__NAME);
            }
        }
        /* deactivate plausis for now...
        EntityDefinition child = m2o.getChildObject();
        if (child != null) {
            // child must have a PK, and that must have the same number of fields as the referenced field list
            if (child.getPk() == null) {
                error("Referenced entity must have a primary key defined",
                        BDDLPackage.Literals.RELATIONSHIP__CHILD_OBJECT);
                return;
            }
            if (m2o.getReferencedFields() != null) {
                // pk is defined and referenced fields as well
                List<FieldDefinition> refc = m2o.getReferencedFields().getColumnName();
                List<FieldDefinition> pk = child.getPk().getColumnName();
                if (m2o.eContainer() instanceof OneToMany) {
                    // we are a ManyToOne relationship here....
                    if (refc.size() > pk.size()) {
                        error("List of referenced columns cannot exceed the cardinality of the primary key of child entity (" + pk.size() + ")",
                                BDDLPackage.Literals.RELATIONSHIP__REFERENCED_FIELDS);
                        return;
                    }
                } else {
                    // we are a ManyToOne relationship here.... or possibly OneToOne...
                    if (refc.size() != pk.size()) {
                        error("List of referenced columns must have same cardinality as primary key of child entity (" + pk.size() + ")",
                                BDDLPackage.Literals.RELATIONSHIP__REFERENCED_FIELDS);
                        return;
                    }
                }
                // both lists have same size or refc is smaller, now check object types
                for (int j = 0; j < refc.size(); ++j) {
                    // perform type checking. Issue warnings only for non-matches, because differences could be due to typedefs used / vs not used
                    if (checkSameType(pk.get(j).getDatatype(), refc.get(j).getDatatype())) {
                        warning("Possible data type mismatch for column " + (j+1), BDDLPackage.Literals.RELATIONSHIP__REFERENCED_FIELDS);
                    }
                }
            }
        } */
    }

//    private static boolean isSame(Object a, Object b) {
//        if (a == null && b == null)
//            return true;
//        if (a == null || b == null)
//            return false;
//        return a.equals(b);
//    }
//
//    private static boolean checkSameType(DataType a, DataType b) {
//        if (!isSame(a.getReferenceDataType(), b.getReferenceDataType()))  // typedefs must be exactly the same
//            return false;
//        ElementaryDataType adt = a.getElementaryDataType();
//        ElementaryDataType bdt = b.getElementaryDataType();
//
//        if (adt != null) {
//            if (bdt == null)
//                return false;
//            // a and b both not null, compare!
//            if (!isSame(adt.getEnumType(), bdt.getEnumType()))
//                return false;
//            if (!isSame(adt.getName(), bdt.getName()))
//                return false;
//            if (adt.getLength() != bdt.getLength())
//                return false;
//        } else if (bdt != null) {
//            // a is null, b not
//            return false;
//        }
//        return true;
//
//    }
    
    @Check
    def public void checkElementCollectionRelationship(ElementCollectionRelationship ec) {
        val f = ec.getName();
        
        if (f === null)  // not yet complete
            return;
        
        if (ec.getMapKey() !== null) {
            // the referenced field must be of type map
            if (f.getIsMap() === null) {
                error("The referenced field must be a map if mapKey is used",
                        BDDLPackage.Literals.ELEMENT_COLLECTION_RELATIONSHIP__MAP_KEY);
            }

            checkFieldnameLength(ec.getMapKey(), BDDLPackage.Literals.ELEMENT_COLLECTION_RELATIONSHIP__MAP_KEY);
        } else {
            // the referenced field must be of type list of set
            if (f.getIsSet() === null && f.getIsList() === null) {
                if (f.getIsMap() !== null) {
                    error("Specify a mapKey for Map type collections",
                        BDDLPackage.Literals.ELEMENT_COLLECTION_RELATIONSHIP__NAME);
                } else {
                    error("The referenced field must be a List or Set",
                        BDDLPackage.Literals.ELEMENT_COLLECTION_RELATIONSHIP__NAME);
                }
            }
        }

        if (ec.getTablename() !== null)
            checkTablenameLength(ec.getTablename(), BDDLPackage.Literals.ELEMENT_COLLECTION_RELATIONSHIP__TABLENAME);
        if (ec.getHistorytablename() !== null)
            checkTablenameLength(ec.getHistorytablename(), BDDLPackage.Literals.ELEMENT_COLLECTION_RELATIONSHIP__HISTORYTABLENAME);
        
        val e = getEntity(ec);
        if (e === null) {
            error("Cannot determine containing Entity", BDDLPackage.Literals.ELEMENT_COLLECTION_RELATIONSHIP__NAME);
            return;
        }
        if (e.getPk() === null || e.getPk().getColumnName() === null) {
            error("EntityCollections only possible for entities with a primary key",
                    BDDLPackage.Literals.ELEMENT_COLLECTION_RELATIONSHIP__NAME);
        } else {
            // compare number of fields and field length
            if (ec.getKeyColumns() !== null) {
                if (ec.getKeyColumns().size() != e.getPk().getColumnName().size()) {
                    error("EntityCollections join columns (found " + ec.getKeyColumns().size()
                            + ") must be the same number as the primary key size of the entity (" + e.getPk().getColumnName().size() + ")",
                            BDDLPackage.Literals.ELEMENT_COLLECTION_RELATIONSHIP__KEY_COLUMNS);
                }
                for (String kc : ec.getKeyColumns()) {
                    checkFieldnameLength(kc, BDDLPackage.Literals.ELEMENT_COLLECTION_RELATIONSHIP__KEY_COLUMNS);
                }
            }
        }
    }
    
    def private static EntityDefinition getEntity(EObject ee) {
        var e = ee
        while (e !== null) {
            if (e instanceof EntityDefinition)
                return e;
            e = e.eContainer();
        }
        return null;
    }
    
    @Check
    def public void checkOneToMany(OneToMany ec) {
        if (ec.getMapKey() !== null) {
            checkFieldnameLength(ec.getMapKey(), BDDLPackage.Literals.ONE_TO_MANY__MAP_KEY);
        }
    }
    
    @Check
    def public void checkEmbeddableDefinition(EmbeddableDefinition e) {
        if (e.getPojoType() !== null) {
            if (!e.getPojoType().isFinal())
                error("Embeddables must be final", BDDLPackage.Literals.EMBEDDABLE_DEFINITION__POJO_TYPE);
            if (e.getPojoType().isAbstract())
                error("Embeddables may not be abstract", BDDLPackage.Literals.EMBEDDABLE_DEFINITION__POJO_TYPE);
        }
    }
    
    @Check
    def public void checkEmbeddableUse(EmbeddableUse u) {
        var DataTypeExtension ref;
        try {
            ref = DataTypeExtension.get(u.getField().getDatatype());
        } catch (Exception e) {
            warning("Could not retrieve datatype", BDDLPackage.Literals.EMBEDDABLE_USE__FIELD);
            return;
        }
        if (ref.objectDataType === null) {
            error("Referenced field must be of object type", BDDLPackage.Literals.EMBEDDABLE_USE__FIELD);
            return;
        }
        if (ref.objectDataType != u.getName().getPojoType()) {
            error("class mismatch: embeddable references " + u.getName().getPojoType().getName() + ", field is " + ref.objectDataType.getName(),
                    BDDLPackage.Literals.EMBEDDABLE_USE__NAME);
            return;
        }
    }
    
    @Check
    def public void checkConverterDefinition(ConverterDefinition c) {
        val a = c.getMyAdapter();
        if (a !== null) {
            if (!a.isSingleField()) {
                error("Converters can only be registered for single field external types currently", BDDLPackage.Literals.CONVERTER_DEFINITION__MY_ADAPTER);
                return;
            }
            if (a.isNeedExtraParam()) {
                error("Converters cannot receive extra parameters", BDDLPackage.Literals.CONVERTER_DEFINITION__MY_ADAPTER);
                return;
            }
        }
    }
    
}