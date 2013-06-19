package de.jpaw.persistence.dsl.validation;

import java.util.List;

import org.eclipse.xtext.validation.Check;

import de.jpaw.bonaparte.dsl.bonScript.BonScriptPackage;
import de.jpaw.bonaparte.dsl.bonScript.DataType;
import de.jpaw.bonaparte.dsl.bonScript.ElementaryDataType;
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition;
import de.jpaw.bonaparte.dsl.validation.BonScriptJavaValidator;
import de.jpaw.persistence.dsl.bDDL.BDDLPackage;
import de.jpaw.persistence.dsl.bDDL.CollectionDefinition;
import de.jpaw.persistence.dsl.bDDL.EntityDefinition;
import de.jpaw.persistence.dsl.bDDL.ListOfColumns;
import de.jpaw.persistence.dsl.bDDL.ManyToOneRelationship;

public class BDDLJavaValidator extends AbstractBDDLJavaValidator {

    @Check
    public void checkEntity(EntityDefinition e) {
        String s = e.getName();
        if (s != null) {
            if (!Character.isUpperCase(s.charAt(0))) {
                error("Entity names should start with an upper case letter",
                        BDDLPackage.Literals.ENTITY_DEFINITION__NAME);
            }
        }
        if (e.getExtends() != null) {
            // parent must extend as well or define inheritance
            if ((e.getExtends().getExtends() == null) && (e.getExtends().getXinheritance() == null)) {
                error("entities inherited from must define inheritance properties",
                        BDDLPackage.Literals.ENTITY_DEFINITION__EXTENDS);
            }

            // verify that we do not use extends together with extendsClass or extendsJava
            if ((e.getExtendsClass() != null) || (e.getExtendsJava() != null)) {
                error("entities inherited from cannot use extendsJava or extends in additon", BDDLPackage.Literals.ENTITY_DEFINITION__EXTENDS);
            }
        }

        String tablename = de.jpaw.persistence.dsl.generator.YUtil.mkTablename(e, false);
        if (tablename.length() > 27) {
            // leave room for suffixes like _t(n) or _pk or _i(n) / _j(n) for index naming
            warning("The resulting SQL table name " + tablename + " exceeds 27 characters length and will not work for some database brands (Oracle)",
                    BDDLPackage.Literals.ENTITY_DEFINITION__NAME);
        }

        // verify for missing primary key
        if (e.getTableCategory().isRequiresPk()) {
            // we need one by definition of the category
            if (e.getPk() == null)
                error("The table category requires specificaton of a primary key for this entity",
                        BDDLPackage.Literals.ENTITY_DEFINITION__TABLE_CATEGORY);
        }

        if (e.getXinheritance() != null) {
            switch (e.getXinheritance()) {
            case NONE:
                if (e.getDiscname() != null) {
                    error("discriminator without inheritance", BDDLPackage.Literals.ENTITY_DEFINITION__DISCNAME);
                }
                break;
            case TABLE_PER_CLASS:
                if (e.getDiscname() != null) {
                    warning("TABLE_PER_CLASS inheritance does not need a discriminator", BDDLPackage.Literals.ENTITY_DEFINITION__DISCNAME);
                }
                break;
            case SINGLE_TABLE:
            case JOIN:
                if (e.getDiscname() == null) {
                    error("JOIN / SINGLE_TABLE inheritance require a discriminator", BDDLPackage.Literals.ENTITY_DEFINITION__DISCNAME);
                }
                break;
            default:
                break;
            }
        }

        if (e.getCollections() != null && e.getCollections().size() > 0) {
            if (e.getPk() == null || e.getPk().getColumnName().size() != 1) {
                error("Collections components only allowed for entities with a single column primary key", BDDLPackage.Literals.ENTITY_DEFINITION__COLLECTIONS);
                return;
            }
        }
    }

    @Check
    public void checkCollection(CollectionDefinition c) {
        if (c.getMap() != null && c.getMap().getIsMap() != null) {
            error("Collections component only allowed to reference fields which are a Map<>", BDDLPackage.Literals.COLLECTION_DEFINITION__MAP);
            return;
        }
    }

    @Check
    public void checkManyToOneRelationship(ManyToOneRelationship m2o) {
        String s = m2o.getName();
        if (s != null) {
            if (!Character.isLowerCase(s.charAt(0))) {
                error("relationship (field) names should start with a lower case letter",
                        BDDLPackage.Literals.MANY_TO_ONE_RELATIONSHIP__NAME);
            }
        }
        EntityDefinition child = m2o.getChildObject();
        if (child != null) {
            // child must have a PK, and that must have the same number of fields as the referenced field list
            if (child.getPk() == null) {
                error("Referenced entity must have a primary key defined",
                        BDDLPackage.Literals.MANY_TO_ONE_RELATIONSHIP__CHILD_OBJECT);
                return;
            }
            if (m2o.getReferencedFields() != null) {
                // pk is defined and referenced fields as well
                if (m2o.getReferencedFields().isIsUnique()) {
                    error("'unique' keyword does not make sense for ManyToOne relationships",
                            BDDLPackage.Literals.MANY_TO_ONE_RELATIONSHIP__REFERENCED_FIELDS);
                }
                List<FieldDefinition> refc = m2o.getReferencedFields().getColumnName();
                List<FieldDefinition> pk = child.getPk().getColumnName();
                if (refc.size() != pk.size()) {
                    error("List of referenced columns must have same cardinality as primary key of child entity (" + pk.size() + ")",
                            BDDLPackage.Literals.MANY_TO_ONE_RELATIONSHIP__REFERENCED_FIELDS);
                    return;
                }
                // both lists have same size, now check object types
                for (int j = 0; j < pk.size(); ++j) {
                    // perform type checking. Issue warnings only for non-matches, because differences could be due to typedefs used / vs not used
                    if (checkSameType(pk.get(j).getDatatype(), refc.get(j).getDatatype())) {
                        warning("Possible data type mismatch for column " + (j+1), BDDLPackage.Literals.MANY_TO_ONE_RELATIONSHIP__REFERENCED_FIELDS);
                    }
                }
            }
        }
    }

    private static boolean isSame(Object a, Object b) {
        if (a == null && b == null)
            return true;
        if (a == null || b == null)
            return false;
        return a.equals(b);
    }

    private static boolean checkSameType(DataType a, DataType b) {
        if (!isSame(a.getReferenceDataType(), b.getReferenceDataType()))  // typedefs must be exactly the same
            return false;
        ElementaryDataType adt = a.getElementaryDataType();
        ElementaryDataType bdt = b.getElementaryDataType();

        if (adt != null) {
            if (bdt == null)
                return false;
            // a and b both not null, compare!
            if (!isSame(adt.getEnumType(), bdt.getEnumType()))
                return false;
            if (!isSame(adt.getName(), bdt.getName()))
                return false;
            if (adt.getLength() != bdt.getLength())
                return false;
        } else if (bdt != null) {
            // a is null, b not
            return false;
        }
        return true;

    }
}
