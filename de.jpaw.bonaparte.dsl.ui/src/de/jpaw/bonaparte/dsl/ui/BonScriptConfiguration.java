package de.jpaw.bonaparte.dsl.ui;

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

    @Override
    protected void createFieldEditors() {
        super.createFieldEditors();

        Composite myParent = getFieldEditorParent();

        // Validation
        Group validationGroup = new Group(myParent, SWT.SHADOW_IN);
        validationGroup.setLayoutData(new GridData(SWT.FILL, SWT.TOP, true, false));
        validationGroup.setText("Data types and validation");
        validationGroup.setLayout(new GridLayout(1, false));
        Composite compositeV = new Composite(validationGroup, SWT.NONE);
        addField(new BooleanFieldEditor("WarnByte", "Warn if mutable raw type (byte []) is used", compositeV));
        addField(new BooleanFieldEditor("WarnFloat", "Warn if floating point types are used", compositeV));
        validationGroup.pack();

        // blank, to fill the second column
        new Label(myParent, SWT.NONE).setText(" ");

        // empty line to have some spacing (there may be a better way to do that!)
        new Label(myParent, SWT.NONE).setText(" ");
        new Label(myParent, SWT.NONE).setText(" ");

        // output
        Group outputGroup = new Group(myParent, SWT.SHADOW_IN);
        outputGroup.setLayoutData(new GridData(SWT.FILL, SWT.TOP, true, false));
        outputGroup.setText("Code generation");
        outputGroup.setLayout(new GridLayout(1, false));
        Composite compositeO = new Composite(outputGroup, SWT.NONE);
        addField(new BooleanFieldEditor("DebugOut", "Create debug output (.info) files", compositeO));
        addField(new BooleanFieldEditor("DateTime", "Use JSR310 date / time API instead of joda (requires Java8)", compositeO));
        addField(new BooleanFieldEditor("XMLOut", "Suppress generation of JAXB annotations", compositeO));
        addField(new BooleanFieldEditor("Jakarta", "Generate NEW jakarta package prefixes", compositeO));
        outputGroup.pack();

        // blank, to fill the second column
        new Label(myParent, SWT.NONE).setText(" ");

        // empty line to have some spacing (there may be a better way to do that!)
        new Label(myParent, SWT.NONE).setText(" ");
        new Label(myParent, SWT.NONE).setText(" ");

        // Serialization support
        Group hazelGroup = new Group(myParent, SWT.SHADOW_IN);
        hazelGroup.setLayoutData(new GridData(SWT.FILL, SWT.TOP, true, false));
        hazelGroup.setText("Advanced serialization interfaces");
        hazelGroup.setLayout(new GridLayout(1, false));
        Composite compositeH = new Composite(hazelGroup, SWT.NONE);
        addField(new BooleanFieldEditor("Externalize", "Externalizable", compositeH));
        addField(new BooleanFieldEditor("HazelcastDs", "DataSerializable (Hazelcast)", compositeH));
        addField(new BooleanFieldEditor("HazelcastId", "IdentifiedDataSerializable (Hazelcast3)", compositeH));
        addField(new BooleanFieldEditor("HazelcastPo", "Portable (Hazelcast3)", compositeH));
        addField(new IntegerFieldEditor("FactoryId", "Hazelcast3 default factoryId", compositeH, 10));
        hazelGroup.pack();

        // blank, to fill the second column
        new Label(myParent, SWT.NONE).setText(" ");

        // empty line to have some spacing (there may be a better way to do that!)
        new Label(myParent, SWT.NONE).setText(" ");
        new Label(myParent, SWT.NONE).setText(" ");

        // Serialization support
        Group xsdGroup = new Group(myParent, SWT.SHADOW_IN);
        xsdGroup.setLayoutData(new GridData(SWT.FILL, SWT.TOP, true, false));
        xsdGroup.setText("XSD creation settings");
        xsdGroup.setLayout(new GridLayout(1, false));
        Composite compositeXsd = new Composite(xsdGroup, SWT.NONE);
        addField(new BooleanFieldEditor("xsdDefault",           "Generate XSD files also if no explicit XML directive set", compositeXsd));
        addField(new BooleanFieldEditor("xsdRootSeparateFile",  "Generate separate XSD files for xml root elememts", compositeXsd));
        addField(new BooleanFieldEditor("xsdBundleSubfolders",  "Use separate folders per bundle", compositeXsd));
        addField(new BooleanFieldEditor("xsdExtensions",        "Add anyType element for future extensions to final classes", compositeXsd));
        xsdGroup.pack();

        // blank, to fill the second column
        new Label(myParent, SWT.NONE).setText(" ");
    }

    @Override
    public void init(IWorkbench workbench) {
        // setPreferenceStore(BDDLActivator.getInstance().getPreferenceStore());
        BonScriptPreferences defaults = new BonScriptPreferences();
        IPreferenceStore store = getPreferenceStore();
        store.setDefault("WarnByte",            defaults.warnByte);
        store.setDefault("WarnFloat",           defaults.warnFloat);
        store.setDefault("DebugOut",            defaults.doDebugOut);
        store.setDefault("DateTime",            defaults.doDateTime);
        store.setDefault("XMLOut",              defaults.noXML);
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
        currentSettings.doDebugOut                  = store.getBoolean("DebugOut");
        currentSettings.doDateTime                  = store.getBoolean("DateTime");
        currentSettings.noXML                       = store.getBoolean("XMLOut");
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
                  case "DebugOut":
                      BonScriptPreferences.currentPrefs.doDebugOut          = toBool(event.getNewValue());
                      break;
                  case "XMLOut":
                      BonScriptPreferences.currentPrefs.noXML               = toBool(event.getNewValue());
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
