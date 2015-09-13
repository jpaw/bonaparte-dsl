package de.jpaw.bonaparte.dsl.ui.wizard;

import java.util.List;

import org.eclipse.core.resources.IProject;
import org.eclipse.core.resources.IResource;
import org.eclipse.core.runtime.CoreException;
import org.eclipse.core.runtime.IProgressMonitor;
import org.eclipse.xtend.type.impl.java.JavaBeansMetaModel;
import org.eclipse.xpand2.XpandExecutionContextImpl;
import org.eclipse.xpand2.XpandFacade;
import org.eclipse.xpand2.output.Outlet;
import org.eclipse.xpand2.output.OutputImpl;

import com.google.common.collect.ImmutableList;
import com.google.common.collect.Lists;

public class BonScriptProjectCreator extends org.eclipse.xtext.ui.wizard.AbstractPluginProjectCreator {

    protected static final String DSL_GENERATOR_PROJECT_NAME = "de.jpaw.bonaparte.dsl";

    protected static final String SRC_BON       = "src/main/bon";
    protected static final String SRC_XTEND     = "src/main/xtend";
    protected static final String SRC_JAVA      = "src/main/java";
    protected static final String SRC_GEN_XTEND = "src/main/xtend-gen";
    protected static final String SRC_GEN_BON   = "src/generated/java";
    protected final List<String> SRC_FOLDER_LIST = ImmutableList.of(SRC_BON, SRC_XTEND, SRC_JAVA, SRC_GEN_XTEND, SRC_GEN_BON);

    override protected BonScriptProjectInfo getProjectInfo() {
        return super.getProjectInfo as BonScriptProjectInfo
    }
    
    override protected String getModelFolderName() {
        return SRC_BON;
    }
    
    override protected List<String> getAllFolders() {
        return SRC_FOLDER_LIST;
    }

    override protected List<String> getRequiredBundles() {
        return Lists.newArrayList(super.getRequiredBundles()) => [
            add(DSL_GENERATOR_PROJECT_NAME)
        ]
    }

    override protected void enhanceProject(IProject project, IProgressMonitor monitor) throws CoreException {
        val output = new OutputImpl() => [
            addOutlet(new Outlet(false, getEncoding(), null, true, project.getLocation().makeAbsolute().toOSString()));
        ]

        val execCtx = new XpandExecutionContextImpl(output, null) => [
            resourceManager.fileEncoding = "UTF-8"
            registerMetaModel(new JavaBeansMetaModel)
        ]
        
        XpandFacade.create(execCtx) => [
            evaluate("de::jpaw::bonaparte::dsl::ui::wizard::BonScriptNewProject::main", getProjectInfo());
        ]

        project.refreshLocal(IResource.DEPTH_INFINITE, monitor);
    }

}