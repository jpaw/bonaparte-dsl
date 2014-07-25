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
import org.eclipse.jface.util.IPropertyChangeListener;
import org.eclipse.jface.util.PropertyChangeEvent;

import de.jpaw.bonaparte.dsl.BonScriptPreferences;

public class BonScriptConfiguration extends LanguageRootPreferencePage {

    @Override
    protected void createFieldEditors() {
        super.createFieldEditors();

        Composite myParent = getFieldEditorParent();

        // Validation
        Group validationGroup = new Group(myParent, SWT.SHADOW_IN);
        validationGroup.setLayoutData(new GridData(SWT.FILL, SWT.TOP, true,
                false));
        validationGroup.setText("Data types and Validation");
        validationGroup.setLayout(new GridLayout(1, false));
        Composite compositeV = new Composite(validationGroup, SWT.NONE);
        addField(new BooleanFieldEditor("WarnByte", "Warn is mutable Raw type (byte []) is used?", compositeV));
        addField(new BooleanFieldEditor("WarnFloat", "Warn if floating point types are used?", compositeV));
        validationGroup.pack();

        // output
        Group outputGroup = new Group(myParent, SWT.SHADOW_IN);
        outputGroup.setLayoutData(new GridData(SWT.FILL, SWT.TOP, true, false));
        outputGroup.setText("Code generation");
        outputGroup.setLayout(new GridLayout(1, false));
        Composite compositeO = new Composite(outputGroup, SWT.NONE);
        addField(new BooleanFieldEditor("DebugOut", "Create debug output (.info) files", compositeO));
        addField(new BooleanFieldEditor("DateTime", "Use JSR310 date / time API instead of joda (requires Java8)?", compositeO));
        addField(new BooleanFieldEditor("XMLOut", "Suppress generation of JAXB annotations", compositeO));
        outputGroup.pack();

        // Serialization support
        Group hazelGroup = new Group(myParent, SWT.SHADOW_IN);
        hazelGroup.setLayoutData(new GridData(SWT.FILL, SWT.TOP, true, false));
        hazelGroup.setText("Advanced Serialization interfaces");
        hazelGroup.setLayout(new GridLayout(1, false));
        Composite compositeH = new Composite(hazelGroup, SWT.NONE);
        addField(new BooleanFieldEditor("Externalize", "Externalizable", compositeH));
        addField(new BooleanFieldEditor("HazelcastDs", "DataSerializable (Hazelcast)", compositeH));
        addField(new BooleanFieldEditor("HazelcastId", "IdentifiedDataSerializable (Hazelcast3)", compositeH));
        addField(new BooleanFieldEditor("HazelcastPo", "Portable (Hazelcast3)", compositeH));
        addField(new IntegerFieldEditor("FactoryId", "Hazelcast3 default factoryId", compositeH, 10));
        hazelGroup.pack();

    }

    @Override
    public void init(IWorkbench workbench) {
        // setPreferenceStore(BDDLActivator.getInstance().getPreferenceStore());
        BonScriptPreferences defaults = new BonScriptPreferences();
        IPreferenceStore store = getPreferenceStore();
        store.setDefault("WarnByte", defaults.warnByte);
        store.setDefault("WarnFloat", defaults.warnFloat);
        store.setDefault("DebugOut", defaults.doDebugOut);
        store.setDefault("DateTime", defaults.doDateTime);
        store.setDefault("XMLOut",   defaults.noXML);
        store.setDefault("Externalize", defaults.defaultExternalize);
        store.setDefault("HazelcastDs", defaults.defaultHazelcastDs);
        store.setDefault("HazelcastId", defaults.defaultHazelcastId);
        store.setDefault("HazelcastPo", defaults.defaultHazelcastPo);
        store.setDefault("FactoryId", defaults.defaulthazelcastFactoryId);
        BonScriptPreferences currentSettings = new BonScriptPreferences();
        currentSettings.warnByte           = store.getBoolean("WarnByte");
        currentSettings.warnFloat          = store.getBoolean("WarnFloat");
        currentSettings.doDebugOut         = store.getBoolean("DebugOut");
        currentSettings.doDateTime         = store.getBoolean("DateTime");
        currentSettings.noXML              = store.getBoolean("XMLOut");
        currentSettings.defaultExternalize = store.getBoolean("Externalize");
        currentSettings.defaultHazelcastDs = store.getBoolean("HazelcastDs");
        currentSettings.defaultHazelcastId = store.getBoolean("HazelcastId");
        currentSettings.defaultHazelcastPo = store.getBoolean("HazelcastPo");
        currentSettings.defaulthazelcastFactoryId = store.getInt("FactoryId");
        BonScriptPreferences.currentPrefs  = currentSettings;
        
        store.addPropertyChangeListener(new IPropertyChangeListener() {
                @Override
                public void propertyChange(PropertyChangeEvent event) {
                  switch (event.getProperty()) {
                  case "WarnByte":
                      BonScriptPreferences.currentPrefs.warnByte = (boolean) event.getNewValue();
                      break;
                  case "WarnFloat":
                      BonScriptPreferences.currentPrefs.warnFloat = (boolean) event.getNewValue();
                      break;
                  case "DebugOut":
                      BonScriptPreferences.currentPrefs.doDebugOut = (boolean) event.getNewValue();
                      break;
                  case "XMLOut":
                      BonScriptPreferences.currentPrefs.noXML = (boolean) event.getNewValue();
                      break;
                  case "DateTime":
                      BonScriptPreferences.currentPrefs.doDateTime = (boolean) event.getNewValue();
                      break;
                  case "Externalize":
                      BonScriptPreferences.currentPrefs.defaultExternalize = (boolean) event.getNewValue();
                      break;
                  case "HazelcastDs":
                      BonScriptPreferences.currentPrefs.defaultHazelcastDs = (boolean) event.getNewValue();
                      break;
                  case "HazelcastId":
                      BonScriptPreferences.currentPrefs.defaultHazelcastId = (boolean) event.getNewValue();
                      break;
                  case "HazelcastPo":
                      BonScriptPreferences.currentPrefs.defaultHazelcastPo = (boolean) event.getNewValue();
                      break;
                  case "FactoryId":
                      BonScriptPreferences.currentPrefs.defaulthazelcastFactoryId = (int) event.getNewValue();
                      break;
                  }
                }
              });
    }

}
