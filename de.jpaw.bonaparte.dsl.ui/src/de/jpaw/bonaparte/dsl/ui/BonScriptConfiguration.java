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
		addField(new BooleanFieldEditor("WarnDate",
				"Warn if mutable Calendar class is used?", compositeV));
		addField(new BooleanFieldEditor("WarnByte",
				"Warn is mutable Raw type is used?", compositeV));
		addField(new BooleanFieldEditor("WarnFloat",
				"Warn if floating point types are used?", compositeV));
		validationGroup.pack();

		// output
		Group outputGroup = new Group(myParent, SWT.SHADOW_IN);
		outputGroup.setLayoutData(new GridData(SWT.FILL, SWT.TOP, true, false));
		outputGroup.setText("Code generation");
		outputGroup.setLayout(new GridLayout(1, false));
		Composite compositeH = new Composite(outputGroup, SWT.NONE);
		addField(new BooleanFieldEditor("DebugOut",
				"Create debug output (.info) files", compositeH));
		addField(new BooleanFieldEditor("Externalize",
				"Classes implemenent externalizable by default?", compositeH));
		outputGroup.pack();
	}

	@Override
	public void init(IWorkbench workbench) {
		// setPreferenceStore(BDDLActivator.getInstance().getPreferenceStore());
		BonScriptPreferences defaults = new BonScriptPreferences();
		IPreferenceStore store = getPreferenceStore();
		store.setDefault("WarnDate", defaults.warnDate);
		store.setDefault("WarnByte", defaults.warnByte);
		store.setDefault("WarnFloat", defaults.warnFloat);
		store.setDefault("DebugOut", defaults.doDebugOut);
		store.setDefault("Externalize", defaults.defaultExternalize);
		BonScriptPreferences currentSettings = new BonScriptPreferences();
		currentSettings.warnDate           = store.getBoolean("WarnDate");
		currentSettings.warnByte           = store.getBoolean("WarnByte");
		currentSettings.warnFloat          = store.getBoolean("WarnFloat");
		currentSettings.doDebugOut         = store.getBoolean("DebugOut");
		currentSettings.defaultExternalize = store.getBoolean("Externalize");
		BonScriptPreferences.currentPrefs  = currentSettings;
		
		store.addPropertyChangeListener(new IPropertyChangeListener() {
			    @Override
			    public void propertyChange(PropertyChangeEvent event) {
			      switch (event.getProperty()) {
			      case "WarnDate":
			    	  BonScriptPreferences.currentPrefs.warnDate = (boolean) event.getNewValue();
			    	  break;
			      case "WarnByte":
			    	  BonScriptPreferences.currentPrefs.warnByte = (boolean) event.getNewValue();
			    	  break;
			      case "WarnFloat":
			    	  BonScriptPreferences.currentPrefs.warnFloat = (boolean) event.getNewValue();
			    	  break;
			      case "DebugOut":
			    	  BonScriptPreferences.currentPrefs.doDebugOut = (boolean) event.getNewValue();
			    	  break;
			      case "Externalize":
			    	  BonScriptPreferences.currentPrefs.defaultExternalize = (boolean) event.getNewValue();
			    	  break;
			      }
			    }
			  });
	}

}
