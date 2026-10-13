package de.jpaw.bonaparte.dsl.ui;

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
import org.eclipse.jface.preference.StringFieldEditor;
import org.eclipse.jface.util.IPropertyChangeListener;
import org.eclipse.jface.util.PropertyChangeEvent;

import de.jpaw.bonaparte.dsl.BonScriptPreferences;

public class BonScriptConfiguration extends LanguageRootPreferencePage {
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

    private Group createSectionGroup(Composite parent, String title) {
        Group group = new Group(parent, SWT.SHADOW_IN);
        GridData layoutData = new GridData(SWT.FILL, SWT.TOP, true, false);
        layoutData.horizontalSpan = 2;
        group.setLayoutData(layoutData);
        group.setText(title);
        group.setLayout(new GridLayout(1, false));
        return group;
    }

    @Override
    protected void createFieldEditors() {
        super.createFieldEditors();

        Composite myParent = getFieldEditorParent();

        // Validation
        Group validationGroup = createSectionGroup(myParent, "Data types and validation");
        Composite compositeV = new Composite(validationGroup, SWT.NONE);
        addField(new BooleanFieldEditor("DebugOut", "Create debug output (.info) files", compositeV));
        addField(new BooleanFieldEditor("WarnByte", "Warn if mutable raw type (byte []) is used", compositeV));
        addField(new BooleanFieldEditor("WarnFloat", "Warn if floating point types are used", compositeV));

        // output
        Group outputGroup = createSectionGroup(myParent, "Java Code generation");
        Composite compositeO = new Composite(outputGroup, SWT.NONE);
        addField(new BooleanFieldEditor("JavaDefault", "Generate Java source code", compositeO));
        addField(new BooleanFieldEditor("DateTime", "Use JSR310 date / time API instead of joda (requires Java8)", compositeO));
        addField(new BooleanFieldEditor("XMLOut", "Suppress generation of JAXB annotations", compositeO));
        addField(new BooleanFieldEditor("Jakarta", "Generate NEW jakarta package prefixes", compositeO));

        // Serialization support
        Group hazelGroup = createSectionGroup(myParent, "Advanced serialization interfaces");
        Composite compositeH = new Composite(hazelGroup, SWT.NONE);
        addField(new BooleanFieldEditor("Externalize", "Externalizable", compositeH));
        addField(new BooleanFieldEditor("HazelcastDs", "DataSerializable (Hazelcast)", compositeH));
        addField(new BooleanFieldEditor("HazelcastId", "IdentifiedDataSerializable (Hazelcast3)", compositeH));
        addField(new BooleanFieldEditor("HazelcastPo", "Portable (Hazelcast3)", compositeH));
        addField(new IntegerFieldEditor("FactoryId", "Hazelcast3 default factoryId", compositeH, 10));

        // Serialization support
        Group xsdGroup = createSectionGroup(myParent, "XSD creation settings");
        Composite compositeXsd = new Composite(xsdGroup, SWT.NONE);
        addField(new BooleanFieldEditor("xsdDefault",           "Generate XSD files also if no explicit XML directive set", compositeXsd));
        addField(new BooleanFieldEditor("xsdRootSeparateFile",  "Generate separate XSD files for xml root elememts", compositeXsd));
        addField(new BooleanFieldEditor("xsdBundleSubfolders",  "Use separate folders per bundle", compositeXsd));
        addField(new BooleanFieldEditor("xsdExtensions",        "Add anyType element for future extensions to final classes", compositeXsd));

        // TypeScript support
        Group tsGroup = createSectionGroup(myParent, "TypeScript creation settings");
        Composite compositeTs = new Composite(tsGroup, SWT.NONE);
        addField(new BooleanFieldEditor("typeScriptDefault",           "Generate TypeScript files also if no explicit TypeScript directive set", compositeTs));
        addField(new BooleanFieldEditor("typeScriptApiDefault",        "Generate TypeScript API files also if no explicit TypeScriptApi directive set", compositeTs));
        addField(new StringFieldEditor("TypeScript.module", "Module", compositeTs));
        addField(new StringFieldEditor("TypeScript.modulesFile", "Modules file", compositeTs));
        addField(new StringFieldEditor("TypeScript.npmPackage", "NPM package", compositeTs));
    }

    @Override
    public void init(IWorkbench workbench) {
        // setPreferenceStore(BDDLActivator.getInstance().getPreferenceStore());
        BonScriptPreferences defaults = new BonScriptPreferences();
        IPreferenceStore store = getPreferenceStore();
        store.setDefault("WarnByte",            defaults.warnByte);
        store.setDefault("WarnFloat",           defaults.warnFloat);
        store.setDefault("typeScriptDefault",   defaults.doTypeScript);
        store.setDefault("typeScriptApiDefault",   defaults.doTypeScriptApi);
        store.setDefault("TypeScript.module",   defaults.tsModule == null ? "" : defaults.tsModule);
        store.setDefault("TypeScript.modulesFile", defaults.tsModulesFile == null ? "" : defaults.tsModulesFile);
        store.setDefault("TypeScript.npmPackage", defaults.tsNpmPackage == null ? "" : defaults.tsNpmPackage);
        store.setDefault("DebugOut",            defaults.doDebugOut);
        store.setDefault("DateTime",            defaults.doDateTime);
        store.setDefault("JavaOut",             defaults.doJava);
        store.setDefault("XsdOut",              defaults.doXsd);
        store.setDefault("Jakarta",             defaults.jakartaOutput);
        store.setDefault("Externalize",         defaults.defaultExternalize);
        store.setDefault("HazelcastDs",         defaults.defaultHazelcastDs);
        store.setDefault("HazelcastId",         defaults.defaultHazelcastId);
        store.setDefault("HazelcastPo",         defaults.defaultHazelcastPo);
        store.setDefault("FactoryId",           defaults.defaulthazelcastFactoryId);
        store.setDefault("xsdDefault",          defaults.xsdDefault);
        store.setDefault("xsdRootSeparateFile", defaults.xsdRootSeparateFile);
        store.setDefault("xsdBundleSubfolders", defaults.xsdBundleSubfolders);
        store.setDefault("xsdExtensions",       defaults.xsdExtensions);

        BonScriptPreferences currentSettings = new BonScriptPreferences();
        currentSettings.warnByte                    = store.getBoolean("WarnByte");
        currentSettings.warnFloat                   = store.getBoolean("WarnFloat");
        currentSettings.doTypeScript                = store.getBoolean("typeScriptDefault");
        currentSettings.doTypeScriptApi             = store.getBoolean("typeScriptApiDefault");
        currentSettings.tsModule                    = store.getString("TypeScript.module");
        currentSettings.tsModulesFile               = store.getString("TypeScript.modulesFile");
        currentSettings.tsNpmPackage                = store.getString("TypeScript.npmPackage");
        currentSettings.doDebugOut                  = store.getBoolean("DebugOut");
        currentSettings.doDateTime                  = store.getBoolean("DateTime");
        currentSettings.doJava                      = store.getBoolean("JavaOut");
        currentSettings.doXsd                       = store.getBoolean("XsdOut");
        currentSettings.jakartaOutput               = store.getBoolean("Jakarta");
        currentSettings.defaultExternalize          = store.getBoolean("Externalize");
        currentSettings.defaultHazelcastDs          = store.getBoolean("HazelcastDs");
        currentSettings.defaultHazelcastId          = store.getBoolean("HazelcastId");
        currentSettings.defaultHazelcastPo          = store.getBoolean("HazelcastPo");
        currentSettings.defaulthazelcastFactoryId   = store.getInt("FactoryId");
        currentSettings.xsdDefault                  = store.getBoolean("xsdDefault");
        currentSettings.xsdRootSeparateFile         = store.getBoolean("xsdRootSeparateFile");
        currentSettings.xsdBundleSubfolders         = store.getBoolean("xsdBundleSubfolders");
        currentSettings.xsdExtensions               = store.getBoolean("xsdExtensions");
        BonScriptPreferences.currentPrefs  = currentSettings;

        store.addPropertyChangeListener(new IPropertyChangeListener() {
                @Override
                public void propertyChange(PropertyChangeEvent event) {
                  switch (event.getProperty()) {
                  case "WarnByte":
                      BonScriptPreferences.currentPrefs.warnByte            = toBool(event.getNewValue());
                      break;
                  case "WarnFloat":
                      BonScriptPreferences.currentPrefs.warnFloat           = toBool(event.getNewValue());
                      break;
                  case "typeScriptDefault":
                      BonScriptPreferences.currentPrefs.doTypeScript        = toBool(event.getNewValue());
                      break;
                  case "typeScriptDefaultApi":
                      BonScriptPreferences.currentPrefs.doTypeScriptApi     = toBool(event.getNewValue());
                      break;
                  case "TypeScript.module":
                      BonScriptPreferences.currentPrefs.tsModule            = (String) event.getNewValue();
                      break;
                  case "TypeScript.modulesFile":
                      BonScriptPreferences.currentPrefs.tsModulesFile       = (String) event.getNewValue();
                      break;
                  case "TypeScript.npmPackage":
                      BonScriptPreferences.currentPrefs.tsNpmPackage        = (String) event.getNewValue();
                      break;
                  case "DebugOut":
                      BonScriptPreferences.currentPrefs.doDebugOut          = toBool(event.getNewValue());
                      break;
                  case "JavaOut":
                      BonScriptPreferences.currentPrefs.doJava              = toBool(event.getNewValue());
                      break;
                  case "XsdOut":
                      BonScriptPreferences.currentPrefs.doXsd               = toBool(event.getNewValue());
                      break;
                  case "Jakarta":
                      BonScriptPreferences.currentPrefs.jakartaOutput       = toBool(event.getNewValue());
                      break;
                  case "DateTime":
                      BonScriptPreferences.currentPrefs.doDateTime          = toBool(event.getNewValue());
                      break;
                  case "Externalize":
                      BonScriptPreferences.currentPrefs.defaultExternalize  = toBool(event.getNewValue());
                      break;
                  case "HazelcastDs":
                      BonScriptPreferences.currentPrefs.defaultHazelcastDs  = toBool(event.getNewValue());
                      break;
                  case "HazelcastId":
                      BonScriptPreferences.currentPrefs.defaultHazelcastId  = toBool(event.getNewValue());
                      break;
                  case "HazelcastPo":
                      BonScriptPreferences.currentPrefs.defaultHazelcastPo  = toBool(event.getNewValue());
                      break;
                  case "FactoryId":
                      BonScriptPreferences.currentPrefs.defaulthazelcastFactoryId = toInt(event.getNewValue());
                      break;
                  case "xsdDefault":
                      BonScriptPreferences.currentPrefs.xsdDefault          = toBool(event.getNewValue());
                      break;
                  case "xsdRootSeparateFile":
                      BonScriptPreferences.currentPrefs.xsdRootSeparateFile = toBool(event.getNewValue());
                      break;
                  case "xsdBundleSubfolders":
                      BonScriptPreferences.currentPrefs.xsdBundleSubfolders = toBool(event.getNewValue());
                      break;
                  case "xsdExtensions":
                      BonScriptPreferences.currentPrefs.xsdExtensions       = toBool(event.getNewValue());
                      break;
                  }
                }
              });
    }
}
