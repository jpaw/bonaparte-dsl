package de.jpaw.bonaparte.dsl.tests

import com.google.common.io.Resources
import com.google.inject.Provider
import de.jpaw.bonaparte.dsl.bonScript.Model
import java.io.File
import java.io.FileOutputStream
import java.nio.charset.Charset
import javax.inject.Inject
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.xtext.generator.IGenerator
import org.eclipse.xtext.generator.InMemoryFileSystemAccess
import org.eclipse.xtext.junit4.util.ParseHelper
import org.eclipse.xtext.mwe.PathTraverser
import org.eclipse.xtext.validation.CheckMode
import org.eclipse.xtext.validation.IResourceValidator

import static org.junit.Assert.*
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.resource.XtextResource
import org.eclipse.xtext.diagnostics.Severity

abstract class AbstractCompilerTest {
	
	@Inject extension ParseHelper<Model>
	@Inject Provider<ResourceSet> resourceSetProvider
	protected def IGenerator getGenerator(Resource resource) {
		switch resource {
			XtextResource : resource.resourceServiceProvider.get(IGenerator)
		}
	}
	protected def IResourceValidator getValidator(Resource resource) {
		switch resource {
			XtextResource : resource.resourceServiceProvider.resourceValidator
		}
	}

	def void assertNoChanges(CharSequence source) {
		val model = source.parse
		val issues = getValidator(model.eResource).validate(model.eResource, CheckMode.ALL, null)
		assertTrue(issues.toString, issues.empty)
		val fsa = new InMemoryFileSystemAccess
		getGenerator(model.eResource).doGenerate(model.eResource, fsa)
		assertOrGenerate(fsa)
	}
	
	private def void assertOrGenerate(InMemoryFileSystemAccess fsa) {
		val stackElement = new Exception().stackTrace.get(2)
		val data = new File("./expectations/"+stackElement.className+"/"+stackElement.methodName+"/result.txt")
		if (!data.exists) {
			println("No expectation data found. Generating it now.")
			ensureFolderExists(data.parentFile)
			new FileOutputStream(data) => [
				write(fsa.allFiles.toString.bytes)
				close
			]
		} else {
			assertEquals(fsa.allFiles.toString, Resources.readLines(data.toURL, Charset.defaultCharset).join("\n"))
		}
	}
	
	def void assertNoChanges(File pathToRoot, int expectedWarnings) {
		val rs = resourceSetProvider.get
		val uris = new PathTraverser().findAllResourceUris(pathToRoot.canonicalPath, [true]) 
		uris.forEach [
			rs.getResource(it, true)
		]
		val allWarnings = uris.map [
			val resource = rs.getResource(it, false)
			val issues = getValidator(resource).validate(resource, CheckMode.ALL, null)
			assertTrue(issues.toString, issues.filter[severity==Severity.ERROR].empty)
			issues.filter[severity==Severity.WARNING]
		].flatten
		assertEquals(allWarnings.toString, expectedWarnings, allWarnings.size)
		
		val fsa = new InMemoryFileSystemAccess
		uris.forEach [
			val resource = rs.getResource(it, false)
			getGenerator(resource).doGenerate(resource, fsa)
		]
		
		assertOrGenerate(fsa)
	}
	
	def void ensureFolderExists(File file) {
		if (!file.exists) {
			ensureFolderExists(file.parentFile)
			file.mkdir
		}
	}
	
}