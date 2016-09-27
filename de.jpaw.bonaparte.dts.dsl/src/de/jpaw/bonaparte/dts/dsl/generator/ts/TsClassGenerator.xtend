package de.jpaw.bonaparte.dts.dsl.generator.ts

import de.jpaw.bonaparte.dts.dsl.bDts.TsClassDefinition
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.dts.dsl.generator.ZUtil.*
import de.jpaw.bonaparte.dts.dsl.bDts.TsInterfaceDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension

class TsClassGenerator {
    def static collectFields(ImportCollector imp, ClassDefinition d) {
        if (d.extendsClass?.classRef !== null)
            imp.collectFields(d.extendsClass?.classRef)
        for (f : d.fields) {
            val ref = DataTypeExtension.get(f.datatype)
            if (ref.objectDataType !== null) {
                // hack! assume same name and package!
                imp.addImport(ref.objectDataType)
            }
        }
    }

    def static collectFields(ImportCollector imp, TsClassDefinition d) {
        imp.collectFields(d.pojoType)
    }

    def static String writeFields(ClassDefinition d, boolean withSuperclasses) {
        val b = new StringBuilder(1000) 
        if (withSuperclasses && d.extendsClass?.classRef !== null)
            b.append(d.extendsClass?.classRef.writeFields(true))
        for (f : d.fields) {
            val ref = DataTypeExtension.get(f.datatype)
            if (f.aggregate) {
                // TODO
                b.append('''// TODO aggregate «f.name»\n''')
            } else {
                b.append(f.name)
                if (f.isRequired)
                    b.append('?')
                b.append(': ')
                b.append(ref.jsType)
                b.append(';\n')
            }
        }
        return b.toString
    }

    def static writeFields(TsClassDefinition d) {
        d.pojoType.writeFields(true)
    }

    def static writeTsClassDefinition(TsClassDefinition d) {
        val imports = new ImportCollector
        imports.addImport(d.extends)
        imports.addImport(d.implementsInterface)
        imports.collectFields(d)
        
        return '''
            «imports.writeImports(d)»
            
            export class «d.name»«IF d.implementsInterface !== null» implements «d.implementsInterface.name»«ENDIF» {
                "@PQON": string = "«d.pqon»";
                «d.writeFields»
            
                constructor() {
                }
            }
        '''
    }
}
