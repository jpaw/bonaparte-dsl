package de.jpaw.bonaparte.dsl.generator.java

import java.util.Map
import java.util.HashMap
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.EnumDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassReference
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.DataCategory
import static de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*
import de.jpaw.bonaparte.dsl.bonScript.XEnumDefinition
import de.jpaw.bonaparte.dsl.generator.XUtil

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
        if (cl !== null) {
            addImport(getPackageName(cl), cl.name)
            addImport(cl.externalType?.qualifiedName)
        }
    }

    def void addImport(EnumDefinition cl) {
        if (cl !== null)
            addImport(getPackageName(cl), cl.name)
    }

    def void addImport(XEnumDefinition cl) {
        if (cl !== null)
            addImport(getPackageName(cl), cl.name)
    }
    
    // same code as in JavaBonScriptGenerator...
    def void recurseImports(ClassDefinition d, boolean recurseFields) {
        if (d === null)
            return;
        // collect all imports for this class (make sure we don't duplicate any)
        for (i : d.fields) {
            val ref = DataTypeExtension::get(i.datatype)
            if (ref === null) {
                System::out.println('''recurseImports: NPE catch for «d.name».«i.name»''')
            } else {
                // referenced objects
                if (ref.objectDataType !== null)
                    addImport(ref.objectDataType)
                if (ref.secondaryObjectDataType !== null)
                    addImport(ref.secondaryObjectDataType)
                if (ref.genericsRef !== null)
                    addImport(ref.genericsRef) // referenced enums
                // if (ref.elementaryDataType !== null && ref.elementaryDataType.name.toLowerCase().equals("enum"))
                if (ref.category == DataCategory::ENUM)
                    addImport(ref.elementaryDataType.enumType)
                if (ref.category == DataCategory::XENUM) {
                    addImport(XUtil.getRoot(ref.elementaryDataType.xenumType))
                    addImport(ref.elementaryDataType.xenumType.myEnum)
                }
            }
        }
        // generic parameters
        if (d.genericParameters !== null)
            for (gp : d.genericParameters)
                if (gp.^extends !== null)
                    addImport(gp.^extends)
                    
        // external types
        addImport(d.externalType?.qualifiedName)
        
        // finally, possibly the parent object
        addImport(d.extendsClass)
        if (recurseFields && d.extendsClass !== null && d.extendsClass.classRef !== null)
            recurseImports(d.extendsClass.classRef, true)
    }


    def void addImport(ClassReference r) {
        if (r !== null && r.classRef !== null) {
            addImport(r.classRef)
            if (r.classRefGenericParms !== null)     // recursively add any args
                for (args : r.classRefGenericParms)
                    addImport(args)
        }
    }

    def void addImport(String fqon) {
        if (fqon !== null) {
            val ind = fqon.lastIndexOf('.')
            if (ind > 0)
                addImport(fqon.substring(0, ind), fqon.substring(ind+1))
        }        
    }
    
    def void addImport(String packageName, String objectName) {
        val String currentEntry = requiredImports.get(objectName)
        if (currentEntry === null) // not yet in, fine, add it!
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
