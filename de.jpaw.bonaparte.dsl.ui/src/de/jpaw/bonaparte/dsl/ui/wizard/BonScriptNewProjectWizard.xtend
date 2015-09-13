package de.jpaw.bonaparte.dsl.ui.wizard

import javax.inject.Inject
import org.eclipse.xtext.ui.wizard.IProjectCreator
import org.eclipse.xtext.ui.wizard.XtextNewProjectWizard

class BonScriptNewProjectWizard extends XtextNewProjectWizard {
    
    private WizardNewBonScriptProjectCreationPage mainPage;
    
    @Inject
    new(IProjectCreator creator) {
        super(creator)
        windowTitle = "New BonScript Project"
    }
    
    /**
     * Use this method to read the project settings from the wizard pages and feed them into the project info class.
     */
    override protected getProjectInfo() {
        return new BonScriptProjectInfo => [
            projectName = mainPage.projectName
            // specific attributes
            jpawParentVersion   = mainPage.jpawParentVersion
            xtendVersion        = mainPage.xtendVersion
            useBonscript        = mainPage.useBonscript
            useXtend            = mainPage.useXtend
            useJpawParent       = mainPage.useJpawParent
        ]
    }
    
    /**
     * Use this method to add pages to the wizard.
     * The one-time generated version of this class will add a default new project page to the wizard.
     */
    override public void addPages() {
        mainPage = new WizardNewBonScriptProjectCreationPage("basicNewProjectPage") => [
            title       = "BonScript Project"
            description = "Create a new BonScript project."
            // specific 
        ]
        addPage(mainPage);
    }
}