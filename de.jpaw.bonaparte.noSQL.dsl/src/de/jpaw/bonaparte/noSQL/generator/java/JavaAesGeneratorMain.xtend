package de.jpaw.bonaparte.noSQL.generator.java

import de.jpaw.bonaparte.noSQL.bDsl.EntityDefinition
import de.jpaw.bonaparte.noSQL.bDsl.PackageDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.generator.java.ImportCollector
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator

import static de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*

class JavaAesGeneratorMain implements IGenerator {
    // create the filename to store a generated java class source in. Assumes subdirectory ./java
    def private static getJavaFilename(String pkg, String name) {
        return "java/" + pkg.replaceAll("\\.", "/") + "/" + name + ".java"
    }
    def public static getPackageName(PackageDefinition p) {
        (if (p.prefix === null) bonaparteClassDefaultPackagePrefix else p.prefix) + "." + p.name
    }

    // create the package name for an entity
    def public static getPackageName(EntityDefinition d) {
        getPackageName(d.eContainer as PackageDefinition)
    }
    
    override doGenerate(Resource input, IFileSystemAccess fsa) {
        // java
        for (e : input.allContents.toIterable.filter(typeof(EntityDefinition))) {
            fsa.generateFile(getJavaFilename(getPackageName(e), e.name + "Key"), e.javaSetOut)
        }
    }
    
    
    def private static javaSetOut(EntityDefinition e) {
        val String myPackageName = getPackageName(e)
        val ImportCollector imports = new ImportCollector(myPackageName)
        var ClassDefinition stopper = null

        imports.recurseImports(e.tableCategory.trackingColumns, true)
        imports.recurseImports(e.pojoType, true)
        imports.addImport(myPackageName, e.name)  // add myself as well
        imports.addImport(e.pojoType);  // TODO: not needed, see above?
        imports.addImport(e.tableCategory.trackingColumns);
        if (e.^extends !== null) {
            imports.addImport(getPackageName(e.^extends), e.^extends.name)
            stopper = e.^extends.pojoType
        }
        
        
        return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git
        package «getPackageName(e)»;
        
        import org.joda.time.Instant
        
        import com.aerospike.client.AerospikeClient
        import com.aerospike.client.Bin
        import com.aerospike.client.Key
        import com.aerospike.client.async.AsyncClient
        import com.aerospike.client.AerospikeException
        import com.aerospike.client.policy.WritePolicy
        import com.aerospike.client.listener.WriteListener
        import com.aerospike.client.listener.RecordSequenceListener
        import com.aerospike.client.Record
        
        @SuppressWarnings("all")
        public class «e.name»«IF e.extendsClass !== null» extends «e.extendsClass.name»«ENDIF»«IF e.extendsJava !== null» extends «e.extendsJava»«ENDIF»«IF e.^extends !== null» extends «e.^extends.name»«ENDIF» {
            
            static public void write(BonaPortable obj) {
                
            } 
        }
        '''
    }
    
}