package de.jpaw.bonaparte.dsl.generator.java

import de.jpaw.bonaparte.dsl.bonScript.AbstractTypeDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.DataType
import de.jpaw.bonaparte.dsl.bonScript.EnumDefinition
import java.util.HashMap
import java.util.Map

import static de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*

public class ImportCollector {
    private Map<String, String> requiredImports
    private String myPackageName

    new(String myPackage) {
        requiredImports = new HashMap<String, String>()
        myPackageName = myPackage
    }

    def void clear() {
        requiredImports.clear()
    }

    def void addImports(DataType dataType) {
    	if (dataType == null)
    		return;
    	addImport(dataType.referenceDataType)
    	dataType.classRefGenericParms.forEach[addImports]
    }
    
    def dispatch void addImport(AbstractTypeDefinition cl) {
    	// do nothing
    }
    def dispatch void addImport(Void cl) {
    	// do nothing
    }
    
    def dispatch void addImport(ClassDefinition cl) {
        addImport(getPackageName(cl), cl.name)
    }

    def dispatch void addImport(EnumDefinition cl) {
        addImport(getPackageName(cl), cl.name)
    }

    // same code as in JavaBonScriptGenerator...
    def void recurseImports(ClassDefinition d, boolean recurseFields) {
        if (d == null)
            return;
        // collect all imports for this class (make sure we don't duplicate any)
        for (i : d.fields) {
        	addImports(i.datatype)
        }
        // generic parameters
        if (d.genericParameters != null)
            for (gp : d.genericParameters)
                if (gp.^extends != null)
                    addImports(gp.^extends)
        // finally, possibly the parent object
        addImports(d.extendsClass)
        if (recurseFields && d.extendsClass != null && d.extendsClass.referenceDataType instanceof ClassDefinition)
            recurseImports(d.extendsClass.referenceDataType as ClassDefinition, true)
    }

    def void addImport(String packageName, String objectName) {
        val String currentEntry = requiredImports.get(objectName)
        if (currentEntry == null) // not yet in, fine, add it!
            requiredImports.put(objectName, packageName)
        else
            if (!currentEntry.equals(packageName))  // not good, more than one entry!
                requiredImports.put(objectName, "-")  // this will cause am intentional compile error of the generated code
    }

    def createImports() '''
        «FOR o : requiredImports.keySet»
            «IF !requiredImports.get(o).equals(myPackageName)»
                import «requiredImports.get(o)».«o»;
            «ENDIF»
        «ENDFOR»
    '''
}
