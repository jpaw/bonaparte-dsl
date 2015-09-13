package de.jpaw.bonaparte.dsl.ui.wizard

import org.eclipse.ui.dialogs.WizardNewProjectCreationPage
import org.eclipse.swt.widgets.Composite
import org.eclipse.swt.widgets.Group
import org.eclipse.swt.SWT
import org.eclipse.swt.layout.GridData
import org.eclipse.swt.layout.GridLayout
import org.eclipse.swt.widgets.Label
import org.eclipse.swt.widgets.Text
import org.eclipse.jface.viewers.IStructuredSelection

class WizardNewBonScriptProjectCreationPage extends WizardNewProjectCreationPage {
    private final IStructuredSelection selection;
    
    public val useMaven = true
    public var String jpawParentVersion
    public var String xtendVersion
    public var boolean useBonscript
    public var boolean useXtend
    public var boolean useJpawParent
    
    new(String pageName, IStructuredSelection sel) {
        super(pageName)
        selection = sel
        setDefaults
        println("WizardNewBonScriptProjectCreationPage constructed")
    }
    
    def private setDefaults() {
        jpawParentVersion   = "1.0.6"
        xtendVersion        = "2.8.4"
        useBonscript        = true
        useXtend            = true
        useJpawParent       = false        
    }
    
    private var Text jpawVersionCtrl
    
    override public void createControl(Composite myParent) {
        println("WizardNewBonScriptProjectCreationPage.createControl executed")
        super.createControl(myParent)
        setDefaults
        // Settings
        new Group(myParent, SWT.SHADOW_IN) => [
            layoutData                  = new GridData(SWT.FILL, SWT.TOP, true, false)
            text                        = "Project settings"
            layout                      = new GridLayout(2, false)
            // jpaw version
            val lbl1                    = new Label(it, SWT.NONE)
            val data1                   = new GridData(GridData.FILL_HORIZONTAL)
            data1.horizontalSpan        = 1
            lbl1.text                   = "jpaw version"
            jpawVersionCtrl             = new Text(it, SWT.BORDER)
            val data2                   = new GridData(GridData.FILL_HORIZONTAL)
            data2.horizontalSpan        = 1;
            jpawVersionCtrl.layoutData  = data2
            jpawVersionCtrl.font        = myParent.font
            jpawVersionCtrl.text        = jpawParentVersion
            jpawVersionCtrl.addListener(SWT.Modify) [ jpawParentVersion = jpawVersionCtrl.text ]
        
            // finish
            pack
        ]
    }
}