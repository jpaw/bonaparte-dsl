package de.jpaw.bonaparte.noSQL.dsl.generator.java

import de.jpaw.bonaparte.noSQL.dsl.bDsl.EntityDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.generator.java.ImportCollector
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator

import static de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*
import de.jpaw.bonaparte.noSQL.dsl.bDsl.BDSLPackageDefinition

class ZUtil {

    // create the filename to store a generated java class source in. Assumes subdirectory ./java
    def public static getJavaFilename(String pkg, String name) {
        return "java/" + pkg.replaceAll("\\.", "/") + "/" + name + ".java"
    }
    def public static getPackageName(BDSLPackageDefinition p) {
        (if (p.prefix === null) bonaparteClassDefaultPackagePrefix else p.prefix) + "." + p.name
    }

    // create the package name for an entity
    def public static getPackageName(EntityDefinition d) {
        getPackageName(d.eContainer as BDSLPackageDefinition)
    }

}
