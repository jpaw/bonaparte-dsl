package de.jpaw.persistence.dsl.validation;

import org.eclipse.xtext.validation.Check;

import de.jpaw.persistence.dsl.bDDL.BDDLPackage;
import de.jpaw.persistence.dsl.bDDL.EntityDefinition;

public class BDDLJavaValidator extends AbstractBDDLJavaValidator {

	@Check
	public void checkEntity(EntityDefinition e) {
		if (e.getExtends() != null) {
			// parent must extend as well or define inheritance
			if (e.getExtends().getExtends() == null && e.getExtends().getInheritance() == null)
				error("entities inherited from must define inheritance properties",
						BDDLPackage.Literals.ENTITY_DEFINITION__EXTENDS);
		}
		
		String tablename = de.jpaw.persistence.dsl.generator.YUtil.mkTablename(e, false);
		if (tablename.length() > 30)
			warning("The resulting SQL table name " + tablename + " exceeds 30 characters length and will not work for some database brands (Oracle)",
					BDDLPackage.Literals.ENTITY_DEFINITION__NAME);
	}
}
