package de.jpaw.bonaparte.jpa.dsl.ui;

import org.eclipse.swt.SWT;
import org.eclipse.swt.layout.GridData;
import org.eclipse.swt.layout.GridLayout;
import org.eclipse.swt.widgets.Composite;
import org.eclipse.swt.widgets.Group;
import org.eclipse.swt.widgets.Label;
import org.eclipse.ui.IWorkbench;
import org.eclipse.xtext.ui.editor.preferences.LanguageRootPreferencePage;
import org.eclipse.jface.preference.BooleanFieldEditor;
import org.eclipse.jface.preference.IPreferenceStore;
import org.eclipse.jface.preference.IntegerFieldEditor;
import org.eclipse.jface.util.IPropertyChangeListener;
import org.eclipse.jface.util.PropertyChangeEvent;

import de.jpaw.bonaparte.jpa.dsl.BDDLPreferences;

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
        
//        Composite myParent = new Composite(outer, SWT.FILL);
//        FillLayout myLayout = new FillLayout(SWT.VERTICAL);
//        myLayout.marginHeight = 4;
//        myLayout.marginWidth = 4;
//        myParent.setLayout(myLayout);
        
        // Validation
        Group validationGroup = new Group(myParent, SWT.SHADOW_IN);
        validationGroup.setLayoutData(new GridData(SWT.FILL, SWT.TOP, true, false));
        validationGroup.setText("Validation");
        validationGroup.setLayout(new GridLayout(1, false));
        Composite compositeV = new Composite(validationGroup, SWT.NONE);
        addField( new IntegerFieldEditor("MaxFieldLen",                 "Maximum field name length for generated SQL", compositeV, 3));
        addField( new IntegerFieldEditor("MaxTableLen",                 "Maximum table / index name length", compositeV, 3));
        validationGroup.pack();

        // blank, to fill the second column
        new Label(myParent, SWT.NONE).setText(" ");

        // empty line to have some spacing (there may be a better way to do that!)
        new Label(myParent, SWT.NONE).setSize(10, 16);
        new Label(myParent, SWT.NONE).setText(" ");
        
        // output
        Group outputGroup = new Group(myParent, SWT.SHADOW_IN);
        outputGroup.setLayoutData(new GridData(SWT.FILL, SWT.TOP, true, false));
        outputGroup.setText("Generated Code Output");
        outputGroup.setLayout(new GridLayout(1, false));
        Composite compositeH = new Composite(outputGroup, SWT.NONE);
        addField(new BooleanFieldEditor("DebugOut",                     "Create debug output (.info) files", compositeH));
        addField(new BooleanFieldEditor("Postgres",                     "Create DDL for Postgres 9 databases", compositeH));
        addField(new BooleanFieldEditor("Oracle",                       "Create DDL for Oracle 11g databases", compositeH));
        addField(new BooleanFieldEditor("MSSQL",                        "Create DDL for MS SQL server 2012", compositeH));
        addField(new BooleanFieldEditor("MySQL",                        "Create DDL for MySQL 5.6.5 up", compositeH));
        outputGroup.pack();

        // blank, to fill the second column
        new Label(myParent, SWT.NONE).setText(" ");

        
        // empty line to have some spacing (there may be a better way to do that!)
        new Label(myParent, SWT.NONE).setSize(10, 16);
        new Label(myParent, SWT.NONE).setText(" ");
        
        // JPA 2.1 code generation options
        Group jpa21Group = new Group(myParent, SWT.SHADOW_IN);
        jpa21Group.setLayoutData(new GridData(SWT.FILL, SWT.TOP, true, false));
        jpa21Group.setText("Do JPA 2.1 User Types for...");
        jpa21Group.setLayout(new GridLayout(1, false));
        Composite jpa21group = new Composite(jpa21Group, SWT.NONE);
        addField(new BooleanFieldEditor("UserTypeEnum",                 "numeric enums", jpa21group));
        addField(new BooleanFieldEditor("UserTypeEnumAlpha",            "tokenizable enums", jpa21group));
        addField(new BooleanFieldEditor("UserTypeXEnum",                "xenums", jpa21group));
        addField(new BooleanFieldEditor("UserTypeEnumset",              "numeric enumsets", jpa21group));
        addField(new BooleanFieldEditor("UserTypeEnumsetAlpha",         "String type enumsets", jpa21group));
        addField(new BooleanFieldEditor("UserTypeXEnumset",             "xenumsets", jpa21group));
        addField(new BooleanFieldEditor("UserTypeSingleFieldExternals", "singleField external types", jpa21group));
        jpa21Group.pack();
        
        // blank, to fill the second column
        new Label(myParent, SWT.NONE).setText(" ");
    }

    @Override public void init(IWorkbench workbench) {
        //setPreferenceStore(BDDLActivator.getInstance().getPreferenceStore());
        BDDLPreferences defaults = new BDDLPreferences();
        IPreferenceStore store = getPreferenceStore();
        store.setDefault("MaxFieldLen",                 defaults.maxFieldnameLength);
        store.setDefault("MaxTableLen",                 defaults.maxTablenameLength);
        store.setDefault("DebugOut",                    defaults.doDebugOut);
        store.setDefault("Postgres",                    defaults.doPostgresOut);
        store.setDefault("Oracle",                      defaults.doOracleOut);
        store.setDefault("MSSQL",                       defaults.doMsSQLServerOut);
        store.setDefault("MySQL",                       defaults.doMySQLOut);

        store.setDefault("UserTypeEnum",                defaults.doUserTypeForEnum);
        store.setDefault("UserTypeEnumAlpha",           defaults.doUserTypeForEnumAlpha);
        store.setDefault("UserTypeXEnum",               defaults.doUserTypeForXEnum);
        store.setDefault("UserTypeEnumset",             defaults.doUserTypeForEnumset);
        store.setDefault("UserTypeEnumsetAlpha",        defaults.doUserTypeForEnumsetAlpha);
        store.setDefault("UserTypeXEnumset",            defaults.doUserTypeForXEnumset);
        store.setDefault("UserTypeSingleFieldExternals",defaults.doUserTypeForSFExternals);
        
        BDDLPreferences currentSettings = new BDDLPreferences();
        currentSettings.maxFieldnameLength          = store.getInt("MaxFieldLen");
        currentSettings.maxTablenameLength          = store.getInt("MaxTableLen");
        currentSettings.doDebugOut                  = store.getBoolean("DebugOut");
        currentSettings.doPostgresOut               = store.getBoolean("Postgres");
        currentSettings.doOracleOut                 = store.getBoolean("Oracle");
        currentSettings.doMsSQLServerOut            = store.getBoolean("MSSQL");
        currentSettings.doMySQLOut                  = store.getBoolean("MySQL");
        
        currentSettings.doUserTypeForEnum           = store.getBoolean("UserTypeEnum");
        currentSettings.doUserTypeForEnumAlpha      = store.getBoolean("UserTypeEnumAlpha");
        currentSettings.doUserTypeForXEnum          = store.getBoolean("UserTypeXEnum");
        currentSettings.doUserTypeForEnumset        = store.getBoolean("UserTypeEnumset");
        currentSettings.doUserTypeForEnumsetAlpha   = store.getBoolean("UserTypeEnumsetAlpha");
        currentSettings.doUserTypeForXEnumset       = store.getBoolean("UserTypeXEnumset");
        currentSettings.doUserTypeForSFExternals    = store.getBoolean("UserTypeSingleFieldExternals");
        
        BDDLPreferences.currentPrefs = currentSettings;
        
        store.addPropertyChangeListener(new IPropertyChangeListener() {
                @Override
                public void propertyChange(PropertyChangeEvent event) {
                  switch (event.getProperty()) {
                  case "MaxFieldLen":
                      BDDLPreferences.currentPrefs.maxFieldnameLength       = toInt(event.getNewValue());
                      break;
                  case "MaxTableLen":
                      BDDLPreferences.currentPrefs.maxTablenameLength       = toInt(event.getNewValue());
                      break;
                  case "DebugOut":
                      BDDLPreferences.currentPrefs.doDebugOut               = (boolean) event.getNewValue();
                      break;
                  case "Postgres":
                      BDDLPreferences.currentPrefs.doPostgresOut            = (boolean) event.getNewValue();
                      break;
                  case "Oracle":
                      BDDLPreferences.currentPrefs.doOracleOut              = (boolean) event.getNewValue();
                      break;
                  case "MSSQL":
                      BDDLPreferences.currentPrefs.doMsSQLServerOut         = (boolean) event.getNewValue();
                      break;
                  case "MySQL":
                      BDDLPreferences.currentPrefs.doMySQLOut               = (boolean) event.getNewValue();
                      break;
                      
                  case "UserTypeEnum":
                      BDDLPreferences.currentPrefs.doUserTypeForEnum        = (boolean) event.getNewValue();
                      break;
                  case "UserTypeEnumAlpha":
                      BDDLPreferences.currentPrefs.doUserTypeForEnumAlpha   = (boolean) event.getNewValue();
                      break;
                  case "UserTypeXEnum":
                      BDDLPreferences.currentPrefs.doUserTypeForXEnum       = (boolean) event.getNewValue();
                      break;
                  case "UserTypeEnumset":
                      BDDLPreferences.currentPrefs.doUserTypeForEnumset     = (boolean) event.getNewValue();
                      break;
                  case "UserTypeEnumsetAlpha":
                      BDDLPreferences.currentPrefs.doUserTypeForEnumsetAlpha= (boolean) event.getNewValue();
                      break;
                  case "UserTypeXEnumset":
                      BDDLPreferences.currentPrefs.doUserTypeForXEnumset    = (boolean) event.getNewValue();
                      break;
                  case "UserTypeSingleFieldExternals":
                      BDDLPreferences.currentPrefs.doUserTypeForSFExternals = (boolean) event.getNewValue();
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
