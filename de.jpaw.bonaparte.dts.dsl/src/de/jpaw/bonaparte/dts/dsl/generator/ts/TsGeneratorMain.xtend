package de.jpaw.bonaparte.dts.dsl.generator.ts

import de.jpaw.bonaparte.dts.dsl.bDts.TsClassDefinition
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator

import static extension de.jpaw.bonaparte.dts.dsl.generator.ZUtil.*
import static extension de.jpaw.bonaparte.dts.dsl.generator.ts.TsClassGenerator.*
import static extension de.jpaw.bonaparte.dts.dsl.generator.ts.TsInterfaceGenerator.*
import de.jpaw.bonaparte.dts.dsl.bDts.TsInterfaceDefinition

class TsGeneratorMain implements IGenerator {

    def getFilename(String pkg, String name) {
        return "ts/" + pkg.replaceAll("\\.", "/") + "/" + name + ".ts"
    }
    def getFilename(TsClassDefinition d) {
        return getFilename(d.dtsPackage.name, d.name)
    }
    def getFilename(TsInterfaceDefinition i) {
        return getFilename(i.dtsPackage.name, i.name)
    }

    override doGenerate(Resource input, IFileSystemAccess fsa) {
        for (d : input.allContents.toIterable.filter(typeof(TsClassDefinition))) {
            fsa.generateFile(d.filename, d.writeTsClassDefinition);
        }
        for (i : input.allContents.toIterable.filter(typeof(TsInterfaceDefinition))) {
            fsa.generateFile(i.filename, i.writeTsInterfaceDefinition);
        }
    }
}
