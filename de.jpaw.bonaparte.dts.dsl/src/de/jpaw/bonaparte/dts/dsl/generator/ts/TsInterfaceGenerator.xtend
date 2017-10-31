package de.jpaw.bonaparte.dts.dsl.generator.ts

import de.jpaw.bonaparte.dts.dsl.bDts.TsClassDefinition
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.dts.dsl.generator.ZUtil.*
import de.jpaw.bonaparte.dts.dsl.bDts.TsInterfaceDefinition
import static extension de.jpaw.bonaparte.dts.dsl.generator.ts.TsClassGenerator.*

class TsInterfaceGenerator {

    def static collectFields(ImportCollector imp, TsInterfaceDefinition d) {
        imp.collectFields(d.pojoType)
    }

    def static writeFields(TsInterfaceDefinition d) {
        d.pojoType.writeFields(false)
    }

    def static writeTsInterfaceDefinition(TsInterfaceDefinition d) {
        val imports = new ImportCollector
        imports.addImport(d.extends)
        imports.collectFields(d)

        return '''
            «imports.writeImports(d)»

            export interface «d.name»«IF d.extends !== null» extends «d.extends.name»«ENDIF» {
                "@PQON": string = "«d.pqon»";
                «d.writeFields»

                constructor() {
                }
            }
        '''
    }
}
