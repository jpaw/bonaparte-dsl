package de.jpaw.bonaparte.dsl.generator.java

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassReference
import de.jpaw.bonaparte.dsl.bonScript.EnumDefinition
import de.jpaw.bonaparte.dsl.bonScript.EnumSetDefinition
import de.jpaw.bonaparte.dsl.bonScript.XEnumDefinition
import de.jpaw.bonaparte.dsl.bonScript.XEnumSetDefinition
import de.jpaw.bonaparte.dsl.generator.DataCategory
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.XUtil
import java.util.HashMap
import java.util.Map
import org.apache.log4j.Logger

import static de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*

class ImportCollector {
    static final Logger LOGGER = Logger.getLogger(ImportCollector);
    Map<String, String> requiredImports
    String myPackageName

    new(String myPackage) {
        requiredImports = new HashMap<String, String>()
        myPackageName = myPackage
    }

    def void clear() {
        requiredImports.clear()
    }

    def void addImport(ClassDefinition cl) {
        if (cl !== null) {
            addImport(getBonPackageName(cl), cl.name)
            if (!cl.useFqn)
                addImport(cl.externalType?.qualifiedName)
        }
    }

    def void addImport(EnumDefinition cl) {
        if (cl !== null)
            addImport(getBonPackageName(cl), cl.name)
    }

    def void addImport(XEnumDefinition cl) {
        if (cl !== null) {
            addImport(getBonPackageName(cl), cl.name)
            addImport(cl.myEnum)
            val root = XUtil.getRoot(cl)
            if (root != cl)
                addImport(root) // avoid endless loop
        }
    }

    def void addImport(EnumSetDefinition cl) {
        if (cl !== null) {
            addImport(getBonPackageName(cl), cl.name)
            addImport(cl.myEnum)
        }
    }

    def void addImport(XEnumSetDefinition cl) {
        if (cl !== null) {
            addImport(getBonPackageName(cl), cl.name)
            addImport(cl.myXEnum)
        }
    }

    // same code as in JavaBonScriptGenerator...
    def void recurseImports(ClassDefinition d, boolean recurseFields) {
        if (d === null)
            return;
        // collect all imports for this class (make sure we don't duplicate any)
        for (i : d.fields) {
            val ref = DataTypeExtension::get(i.datatype)
            if (ref === null) {
                LOGGER.error('''recurseImports: NPE catch for «d.name».«i.name»''')
            } else {
                // referenced objects
                if (ref.objectDataType !== null)
                    addImport(ref.objectDataType)
                if (ref.secondaryObjectDataType !== null)
                    addImport(ref.secondaryObjectDataType)
                if (ref.genericsRef !== null)
                    addImport(ref.genericsRef) // referenced enums
                // if (ref.elementaryDataType !== null && ref.elementaryDataType.name.toLowerCase().equals("enum"))
                switch (ref.category) {
                case DataCategory::ENUM:
                    addImport(ref.elementaryDataType.enumType)
                case DataCategory::ENUMALPHA:
                    addImport(ref.elementaryDataType.enumType)
                case DataCategory::XENUM:
                    addImport(ref.elementaryDataType.xenumType)
                case DataCategory::ENUMSET:
                    addImport(ref.elementaryDataType.enumsetType)
                case DataCategory::ENUMSETALPHA:
                    addImport(ref.elementaryDataType.enumsetType)
                case DataCategory::XENUMSET:
                    addImport(ref.elementaryDataType.xenumsetType)
                default: {}
                }
            }
        }
        // generic parameters
        if (d.genericParameters !== null)
            for (gp : d.genericParameters)
                if (gp.^extends !== null)
                    addImport(gp.^extends)

        // external types, unless advised not to do so
        if (!d.useFqn)
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

    def private writeSingleImportLine(String simpleName) {
        val packageName = requiredImports.get(simpleName)
        if (myPackageName != packageName) {
            if (packageName != "-")
                '''import «packageName».«simpleName»;'''
            else
                '''// FIXME: multiple classes of same simple name «simpleName» used, this may cause problems!'''
        } // else skip (same package as me)
    }

    def createImports() '''
        «FOR o : requiredImports.keySet»
            «writeSingleImportLine(o)»
        «ENDFOR»
    '''
}
