package de.jpaw.bonaparte.dts.dsl.generator.ts

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dts.dsl.bDts.TsClassDefinition
import de.jpaw.bonaparte.dts.dsl.bDts.TsInterfaceDefinition
import java.util.HashMap

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.dts.dsl.generator.ZUtil.*

class ImportCollector {
    val m = new HashMap<String, String>()
    
    def void addImport(ClassDefinition c) {
        if (c !== null)
            m.put(c.name, c.package.name)
    }
    def void addImport(TsInterfaceDefinition i) {
        if (i !== null)
            m.put(i.name, i.pqon)
    }
    def void addImport(TsClassDefinition d) {
        if (d !== null)
            m.put(d.name, d.pqon)
    }
    
    def writeImports(String ownPackage, String ownName) {
        val reference = ownPackage + "."
        val StringBuilder b = new StringBuilder(400)
        for (imp : m.entrySet) {
            if (imp.key != ownName) {
                b.append('''import {«imp.key»} from '«imp.value.asRelativePathTo(reference)»';\n''')
            }
        }
        return b.toString
    }
    def writeImports(TsInterfaceDefinition i) {
        return writeImports(i.dtsPackage.name, i.name)
    }
    def writeImports(TsClassDefinition d) {
        return writeImports(d.dtsPackage.name, d.name)
    }
}