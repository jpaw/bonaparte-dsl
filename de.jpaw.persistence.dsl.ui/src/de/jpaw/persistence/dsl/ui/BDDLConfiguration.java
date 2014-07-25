package de.jpaw.persistence.dsl.ui;

import org.eclipse.swt.SWT;
import org.eclipse.swt.layout.GridData;
import org.eclipse.swt.layout.GridLayout;
import org.eclipse.swt.widgets.Composite;
import org.eclipse.swt.widgets.Group;
import org.eclipse.ui.IWorkbench;
import org.eclipse.xtext.ui.editor.preferences.LanguageRootPreferencePage;
import org.eclipse.jface.preference.BooleanFieldEditor;
import org.eclipse.jface.preference.IPreferenceStore;
import org.eclipse.jface.preference.IntegerFieldEditor;
import org.eclipse.jface.util.IPropertyChangeListener;
import org.eclipse.jface.util.PropertyChangeEvent;

import de.jpaw.persistence.dsl.BDDLPreferences;

public class BDDLConfiguration extends LanguageRootPreferencePage {
    private int toInt(Object x) {
        if (x instanceof String)
            return Integer.valueOf((String)x);
        if (x instanceof Integer)
            return (Integer)x;
        System.out.println("Problem: cannot convert object of type " + x.getClass().getCanonicalName() + " to int. Value is " + x.toString());
        return 30;
    }
    
    @Override protected void createFieldEditors() {
        super.createFieldEditors();
        
        Composite myParent = getFieldEditorParent();
        
        // Validation
        Group validationGroup = new Group(myParent, SWT.SHADOW_IN);
        validationGroup.setLayoutData(new GridData(SWT.FILL, SWT.TOP, true, false));
        validationGroup.setText("Validation");
        validationGroup.setLayout(new GridLayout(1, false));
        Composite compositeV = new Composite(validationGroup, SWT.NONE);
        addField( new IntegerFieldEditor("MaxFieldLen", "Maximum field name length for generated SQL", compositeV, 3));
        addField( new IntegerFieldEditor("MaxTableLen", "Maximum table / index name length", compositeV, 3));
        validationGroup.pack();

        // output
        Group outputGroup = new Group(myParent, SWT.SHADOW_IN);
        outputGroup.setLayoutData(new GridData(SWT.FILL, SWT.TOP, true, false));
        outputGroup.setText("Generated Code Output");
        outputGroup.setLayout(new GridLayout(1, false));
        Composite compositeH = new Composite(outputGroup, SWT.NONE);
        addField(new BooleanFieldEditor("DebugOut", "Create debug output (.info) files", compositeH));
        addField(new BooleanFieldEditor("Postgres", "Create DDL for Postgres 9 databases", compositeH));
        addField(new BooleanFieldEditor("Oracle",   "Create DDL for Oracle 11g databases", compositeH));
        addField(new BooleanFieldEditor("MSSQL",    "Create DDL for MS SQL server 2012", compositeH));
        outputGroup.pack();
    }

    @Override public void init(IWorkbench workbench) {
        //setPreferenceStore(BDDLActivator.getInstance().getPreferenceStore());
        BDDLPreferences defaults = new BDDLPreferences();
        IPreferenceStore store = getPreferenceStore();
        store.setDefault("MaxFieldLen", defaults.maxFieldnameLength);
        store.setDefault("MaxTableLen", defaults.maxTablenameLength);
        store.setDefault("DebugOut", defaults.doDebugOut);
        store.setDefault("Postgres", defaults.doPostgresOut);
        store.setDefault("Oracle", defaults.doOracleOut);
        store.setDefault("MSSQL", defaults.doMsSQLServerOut);
        
        BDDLPreferences currentSettings = new BDDLPreferences();
        currentSettings.maxFieldnameLength = store.getInt("MaxFieldLen");
        currentSettings.maxTablenameLength = store.getInt("MaxTableLen");
        currentSettings.doDebugOut         = store.getBoolean("DebugOut");
        currentSettings.doPostgresOut      = store.getBoolean("Postgres");
        currentSettings.doOracleOut        = store.getBoolean("Oracle");
        currentSettings.doMsSQLServerOut   = store.getBoolean("MSSQL");
        BDDLPreferences.currentPrefs = currentSettings;
        
        store.addPropertyChangeListener(new IPropertyChangeListener() {
                @Override
                public void propertyChange(PropertyChangeEvent event) {
                  switch (event.getProperty()) {
                  case "MaxFieldLen":
                      BDDLPreferences.currentPrefs.maxFieldnameLength = toInt(event.getNewValue());
                      break;
                  case "MaxTableLen":
                      BDDLPreferences.currentPrefs.maxTablenameLength = toInt(event.getNewValue());
                      break;
                  case "DebugOut":
                      BDDLPreferences.currentPrefs.doDebugOut = (boolean) event.getNewValue();
                      break;
                  case "Postgres":
                      BDDLPreferences.currentPrefs.doPostgresOut = (boolean) event.getNewValue();
                      break;
                  case "Oracle":
                      BDDLPreferences.currentPrefs.doOracleOut = (boolean) event.getNewValue();
                      break;
                  case "MSSQL":
                      BDDLPreferences.currentPrefs.doMsSQLServerOut = (boolean) event.getNewValue();
                      break;
                  }
                }
              });
    }
    
// no xtend in the UI module...
//  // Validation
//  new Group(myParent, SWT.SHADOW_IN) => [
//      layout = new GridLayout(1, false)
//      layoutData = new GridData(SWT.FILL, SWT.TOP, true, false)
//      text = "Validation"
//      val compositeV = new Composite(it, SWT.NONE);
//      addField( new IntegerFieldEditor("MaxFieldLen", "Maximum field name length", compositeV, 3) => [ setValidRange(18,60)] );
//      addField( new IntegerFieldEditor("MaxTableLen", "Maximum table name length", compositeV, 3) => [ setValidRange(18,60)] );
//      pack
//  ]
//  
//  
//  // output
//  new Group(myParent, SWT.SHADOW_IN) => [
//      layout = new GridLayout(1, false)
//      layoutData = new GridData(SWT.FILL, SWT.TOP, true, false)
//      text = "Code output"
//      val compositeOut = new Composite(it, SWT.NONE);
//      addField(new BooleanFieldEditor("DebugOut", "Create debug output (.info) files", compositeOut));
//      addField(new BooleanFieldEditor("Postgres", "Create DDL for Postgres 9 databases", compositeOut));
//      addField(new BooleanFieldEditor("Oracle",   "Create DDL for Oracle 11g databases", compositeOut));
//      addField(new BooleanFieldEditor("MSSQL",    "Create DDL for MS-SQL server 2012 databases", compositeOut));
//      pack
//  ]
//}
//
//// not sure if needed, as the superclass defines getPreferenceStore()
//override public void init(IWorkbench workbench) {
////  setPreferenceStore(BDDLActivator.getInstance().getPreferenceStore());
//  val store = getPreferenceStore => [
//      setDefault("MaxFieldLen", 30)
//      setDefault("MaxTableLen", 30)
//      setDefault("DebugOut", false)
//      setDefault("Postgres", true)
//      setDefault("Oracle", true)
//      setDefault("MSSQL", false)
//  ]

}
