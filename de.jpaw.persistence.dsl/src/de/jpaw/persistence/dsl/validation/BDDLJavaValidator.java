package de.jpaw.persistence.dsl.validation;

import org.eclipse.xtext.validation.Check;

import de.jpaw.persistence.dsl.bDDL.BDDLPackage;
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
            warning("The resulting SQL table name " + tablename + " exceeds 27 characters length and will not work for some database brands (Oracle)",
                    BDDLPackage.Literals.ENTITY_DEFINITION__NAME);
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
    }
}
