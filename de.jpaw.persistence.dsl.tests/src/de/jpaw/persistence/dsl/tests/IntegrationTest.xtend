package de.jpaw.persistence.dsl.tests

import de.jpaw.bonaparte.dsl.tests.AbstractCompilerTest
import de.jpaw.persistence.dsl.BDDLInjectorProvider
import java.io.File
import org.eclipse.xtext.junit4.InjectWith
import org.eclipse.xtext.junit4.XtextRunner
import org.junit.Test
import org.junit.runner.RunWith
import de.jpaw.persistence.dsl.BDDLStandaloneSetup
import de.jpaw.bonaparte.dsl.BonScriptStandaloneSetup

@RunWith(XtextRunner)
@InjectWith(CompositeInjectorProvider)
class IntegrationTest extends AbstractCompilerTest {
	
	@Test def void testCompilation() {
		assertNoChanges(new File("./input/bon"), 5)
	}
}

class CompositeInjectorProvider extends BDDLInjectorProvider {
	
	override internalCreateInjector() {
		new BonScriptStandaloneSetup().createInjectorAndDoEMFRegistration();
	    return new BDDLStandaloneSetup().createInjectorAndDoEMFRegistration();
	}
}