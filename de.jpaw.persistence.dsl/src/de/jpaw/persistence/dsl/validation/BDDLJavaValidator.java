package de.jpaw.persistence.dsl.validation;

import org.eclipse.xtext.validation.Check;

import de.jpaw.persistence.dsl.bDDL.BDDLPackage;
import de.jpaw.persistence.dsl.bDDL.CollectionDefinition;
import de.jpaw.persistence.dsl.bDDL.EntityDefinition;

public class BDDLJavaValidator extends AbstractBDDLJavaValidator {

    @Check
    public void checkEntity(EntityDefinition e) {
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
}
