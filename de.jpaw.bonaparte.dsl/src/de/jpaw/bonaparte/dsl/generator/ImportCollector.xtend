package de.jpaw.bonaparte.dsl.generator

import java.util.Map
import java.util.HashMap
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.EnumDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassReference

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
    
    def void addImport(ClassDefinition cl) {
        if (cl != null)
            addImport(JavaPackages::getPackageName(cl), cl.name)
    }
    
    def void addImport(EnumDefinition cl) {
        if (cl != null)
            addImport(JavaPackages::getPackageName(cl), cl.name)
    }
    
    // same code as in JavaBonScriptGenerator...
    def void recurseImports(ClassDefinition d, boolean recurseFields) {
        if (d == null)
            return;
        // collect all imports for this class (make sure we don't duplicate any)
        for (i : d.fields) {
            var ref = DataTypeExtension::get(i.datatype)
            // referenced objects
            if (ref.objectDataType != null)
                addImport(ref.objectDataType)
            if (ref.genericsRef != null)
                addImport(ref.genericsRef)
            // referenced enums
            // if (ref.elementaryDataType != null && ref.elementaryDataType.name.toLowerCase().equals("enum"))
            if (ref.category == DataCategory::ENUM)
                addImport(ref.elementaryDataType.enumType)
        }
        // finally, possibly the parent object
        addImport(d.extendsClass)
        if (recurseFields && d.extendsClass != null && d.extendsClass.classRef != null)
            recurseImports(d.extendsClass.classRef, true)
    }
    
        
    def void addImport(ClassReference r) {
        if (r != null && r.classRef != null) {
            addImport(r.classRef)
            if (r.classRefGenericParms != null)     // recursively add any args
                for (args : r.classRefGenericParms)
                    addImport(args)
        }
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
