package de.jpaw.bonaparte.noSQL.dsl.generator.java

import de.jpaw.bonaparte.noSQL.dsl.bDsl.EntityDefinition
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator

import static de.jpaw.bonaparte.noSQL.dsl.generator.java.ZUtil.*

class JavaGeneratorMain implements IGenerator {

    override doGenerate(Resource input, IFileSystemAccess fsa) {
        // java
        for (e : input.allContents.toIterable.filter(typeof(EntityDefinition))) {
            switch (e.provider) {
                case AEROSPIKE:
                    fsa.generateFile(getJavaFilename(getPackageName(e), e.name), AesGeneratorMain.javaSetOut(e))
                case OFFHEAPMAP:
                    fsa.generateFile(getJavaFilename(getPackageName(e), e.name), OffHeapMapGeneratorMain.javaSetOut(e))
                default:
                    {} // not yet supported
            }
        }
    }
}
