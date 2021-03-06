/*
 * generated by Xtext 2.13.0
 */
package de.jpaw.bonaparte.jpa.dsl.tests

import com.google.inject.Inject
import de.jpaw.bonaparte.jpa.dsl.bDDL.Model
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.Assert
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(XtextRunner)
@InjectWith(BDDLInjectorProvider)
class BDDLParsingTest {
	@Inject
	ParseHelper<Model> parseHelper
	
	@Test
	def void loadModel() {
		val result = parseHelper.parse('''
			package my.test owner scott prefix test {
				
			}
		''')
		Assert.assertNotNull(result)
		val errors = result.eResource.errors
		Assert.assertTrue('''Unexpected errors: «errors.join(", ")»''', errors.isEmpty)
	}
}
