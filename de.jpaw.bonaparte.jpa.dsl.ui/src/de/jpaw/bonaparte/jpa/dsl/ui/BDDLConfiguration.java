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
        if (x == null)
            return 0;
        if (x instanceof String)
            return Integer.valueOf((String)x);
        if (x instanceof Integer)
            return (Integer)x;
        System.out.println("Problem: cannot convert object of type " + x.getClass().getCanonicalName() + " to int. Value is " + x.toString());
        return 30;
    }

    private boolean toBool(Object x) {
        if (x == null)
            return false;
        if (x instanceof Boolean)
            return ((Boolean) x);
        if (x instanceof String)
            return Boolean.valueOf((String)x);
        if (x instanceof Integer)
            return ((Integer) x).intValue() != 0;
        System.out.println("Problem: cannot convert object of type " + x.getClass().getCanonicalName() + " to boolean. Value is " + x.toString());
        return false;
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
        addField(new BooleanFieldEditor("DebugOut",                     "Create debug output (.info) files",    compositeH));
        addField(new BooleanFieldEditor("Postgres",                     "Create DDL for Postgres 9 databases",  compositeH));
        addField(new BooleanFieldEditor("Oracle",                       "Create DDL for Oracle 11g databases",  compositeH));
        addField(new BooleanFieldEditor("OracleExtendedVarchar",        "   use Oracle MAX_STRING_SIZE = EXTENDED (12c and up)",  compositeH));
        addField(new BooleanFieldEditor("MSSQL",                        "Create DDL for MS SQL server 2012",    compositeH));
        addField(new BooleanFieldEditor("MySQL",                        "Create DDL for MySQL 5.6.5 up",        compositeH));
        addField(new BooleanFieldEditor("SapHana",                      "Create DDL for SAP HANA",              compositeH));
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
        addField(new BooleanFieldEditor("UserTypeEnum",                 "numeric enums",        jpa21group));
        addField(new BooleanFieldEditor("UserTypeEnumAlpha",            "tokenizable enums",    jpa21group));
        addField(new BooleanFieldEditor("UserTypeXEnum",                "xenums",               jpa21group));
        addField(new BooleanFieldEditor("UserTypeEnumset",              "enumsets (all kinds)", jpa21group));
// temporarily the next 3 are configured together
//        addField(new BooleanFieldEditor("UserTypeEnumset",              "numeric enumsets", jpa21group));
//        addField(new BooleanFieldEditor("UserTypeEnumsetAlpha",         "String type enumsets", jpa21group));
//        addField(new BooleanFieldEditor("UserTypeXEnumset",             "xenumsets", jpa21group));
        addField(new BooleanFieldEditor("UserTypeSingleFieldExternals", "singleField external types", jpa21group));
        addField(new BooleanFieldEditor("UserTypeBonaPortable",         "BonaPortables",        jpa21group));
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
        store.setDefault("OracleExtendedVarchar",       defaults.oracleExtendedVarchar);
        store.setDefault("DebugOut",                    defaults.doDebugOut);
        store.setDefault("Postgres",                    defaults.doPostgresOut);
        store.setDefault("Oracle",                      defaults.doOracleOut);
        store.setDefault("MSSQL",                       defaults.doMsSQLServerOut);
        store.setDefault("MySQL",                       defaults.doMySQLOut);
        store.setDefault("SapHana",                     defaults.doSapHanaOut);

        store.setDefault("UserTypeEnum",                defaults.doUserTypeForEnum);
        store.setDefault("UserTypeEnumAlpha",           defaults.doUserTypeForEnumAlpha);
        store.setDefault("UserTypeXEnum",               defaults.doUserTypeForXEnum);
        store.setDefault("UserTypeEnumset",             defaults.doUserTypeForEnumset);
//        store.setDefault("UserTypeEnumsetAlpha",        defaults.doUserTypeForEnumsetAlpha);
//        store.setDefault("UserTypeXEnumset",            defaults.doUserTypeForXEnumset);
        store.setDefault("UserTypeSingleFieldExternals",defaults.doUserTypeForSFExternals);
        store.setDefault("UserTypeBonaPortable",        defaults.doUserTypeForBonaPortable);

        BDDLPreferences currentSettings = new BDDLPreferences();
        currentSettings.maxFieldnameLength          = store.getInt("MaxFieldLen");
        currentSettings.maxTablenameLength          = store.getInt("MaxTableLen");
        currentSettings.oracleExtendedVarchar       = store.getBoolean("OracleExtendedVarchar");
        currentSettings.doDebugOut                  = store.getBoolean("DebugOut");
        currentSettings.doPostgresOut               = store.getBoolean("Postgres");
        currentSettings.doOracleOut                 = store.getBoolean("Oracle");
        currentSettings.doMsSQLServerOut            = store.getBoolean("MSSQL");
        currentSettings.doMySQLOut                  = store.getBoolean("MySQL");
        currentSettings.doSapHanaOut                = store.getBoolean("SapHana");

        currentSettings.doUserTypeForEnum           = store.getBoolean("UserTypeEnum");
        currentSettings.doUserTypeForEnumAlpha      = store.getBoolean("UserTypeEnumAlpha");
        currentSettings.doUserTypeForXEnum          = store.getBoolean("UserTypeXEnum");
        currentSettings.doUserTypeForEnumset        = store.getBoolean("UserTypeEnumset");
//        currentSettings.doUserTypeForEnumsetAlpha   = store.getBoolean("UserTypeEnumsetAlpha");
//        currentSettings.doUserTypeForXEnumset       = store.getBoolean("UserTypeXEnumset");
        currentSettings.doUserTypeForSFExternals    = store.getBoolean("UserTypeSingleFieldExternals");
        currentSettings.doUserTypeForBonaPortable   = store.getBoolean("UserTypeBonaPortable");

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
                  case "OracleExtendedVarchar":
                      BDDLPreferences.currentPrefs.oracleExtendedVarchar    = toBool(event.getNewValue());
                      break;
                  case "DebugOut":
                      BDDLPreferences.currentPrefs.doDebugOut               = toBool(event.getNewValue());
                      break;
                  case "Postgres":
                      BDDLPreferences.currentPrefs.doPostgresOut            = toBool(event.getNewValue());
                      break;
                  case "Oracle":
                      BDDLPreferences.currentPrefs.doOracleOut              = toBool(event.getNewValue());
                      break;
                  case "MSSQL":
                      BDDLPreferences.currentPrefs.doMsSQLServerOut         = toBool(event.getNewValue());
                      break;
                  case "MySQL":
                      BDDLPreferences.currentPrefs.doMySQLOut               = toBool(event.getNewValue());
                      break;
                  case "SapHana":
                      BDDLPreferences.currentPrefs.doSapHanaOut             = toBool(event.getNewValue());
                      break;

                  case "UserTypeEnum":
                      BDDLPreferences.currentPrefs.doUserTypeForEnum        = toBool(event.getNewValue());
                      break;
                  case "UserTypeEnumAlpha":
                      BDDLPreferences.currentPrefs.doUserTypeForEnumAlpha   = toBool(event.getNewValue());
                      break;
                  case "UserTypeXEnum":
                      BDDLPreferences.currentPrefs.doUserTypeForXEnum       = toBool(event.getNewValue());
                      break;
                  case "UserTypeEnumset":
                      BDDLPreferences.currentPrefs.doUserTypeForEnumset     = toBool(event.getNewValue());
                      break;
//                  case "UserTypeEnumsetAlpha":
//                      BDDLPreferences.currentPrefs.doUserTypeForEnumsetAlpha= toBool(event.getNewValue());
//                      break;
//                  case "UserTypeXEnumset":
//                      BDDLPreferences.currentPrefs.doUserTypeForXEnumset    = toBool(event.getNewValue());
//                      break;
                  case "UserTypeSingleFieldExternals":
                      BDDLPreferences.currentPrefs.doUserTypeForSFExternals = toBool(event.getNewValue());
                      break;
                  case "UserTypeBonaPortable":
                      BDDLPreferences.currentPrefs.doUserTypeForBonaPortable = toBool(event.getNewValue());
                      break;
                  }
                }
              });
    }
}
