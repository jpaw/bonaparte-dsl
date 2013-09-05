package de.jpaw.bonaparte.dsl.ui.scoping;

import java.util.Collections;
import java.util.Iterator;
import java.util.List;

import org.apache.log4j.Logger;
import org.eclipse.core.runtime.IPath;
import org.eclipse.core.runtime.Path;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.jdt.core.IJavaProject;
import org.eclipse.xtext.common.types.access.jdt.IJavaProjectProvider;
import org.eclipse.xtext.common.types.xtext.TypesAwareDefaultGlobalScopeProvider;
import org.eclipse.xtext.resource.IContainer;

import com.google.inject.Inject;

//TODO Types scope provider is just used, because it is bound in runtime module as well.
public class BonaparteGlobalScopeProvider extends TypesAwareDefaultGlobalScopeProvider {
	
	Logger LOG = Logger.getLogger(BonaparteGlobalScopeProvider.class);
	
	@Inject IJavaProjectProvider javaProjectProvider;

	@Override
	protected List<IContainer> getVisibleContainers(Resource resource) {
//		List<IContainer> result = super.getVisibleContainers(resource);
//		if (!result.isEmpty()) 
//			return result;
		// fall back strategy for https://bugs.eclipse.org/bugs/show_bug.cgi?id=416638
		IJavaProject project = javaProjectProvider.getJavaProject(resource.getResourceSet());
		Iterator<Resource> iterator = resource.getResourceSet().getResources().iterator();
		while (iterator.hasNext()) {
			Resource next = iterator.next();
			URI uri = next.getURI();
			if (uri.isPlatformResource()) {
				String string = uri.toPlatformString(false);
				IPath path = new Path(string).removeFirstSegments(1);
				if (project.getProject().findMember(path) != null) {
					return super.getVisibleContainers(next);
				}
			}
		}
		LOG.error("Couldn't find resource contained in current java project '"+project.getElementName()+"'. Resource was "+resource.getURI());
		return Collections.emptyList();
	}
}
