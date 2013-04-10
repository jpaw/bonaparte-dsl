 /*
  * Copyright 2012 Michael Bischoff
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
  * You may obtain a copy of the License at
  *
  *   http://www.apache.org/licenses/LICENSE-2.0
  *
  * Unless required by applicable law or agreed to in writing, software
  * distributed under the License is distributed on an "AS IS" BASIS,
  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  * See the License for the specific language governing permissions and
  * limitations under the License.
  */
  
package de.jpaw.bonaparte.dsl.generator.debug

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IGenerator
import org.eclipse.xtext.generator.IFileSystemAccess

import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*

class DebugBonScriptGeneratorMain implements IGenerator {
    override void doGenerate(Resource resource, IFileSystemAccess fsa) {
        for (d : resource.allContents.toIterable.filter(typeof(PackageDefinition)))
            fsa.generateFile("debug/" + d.name + ".dump", d.dumpPackage);
    }
    
    def writeDefaults(FieldDefinition i) {
        if (i.datatype == null)
           return "***** ERROR ***** datatype is NULL for " + i.name
        var ref = DataTypeExtension::get(i.datatype)
        if (ref == null)
           return "***** ERROR ***** ref is NULL for " + i.name
        return "defaults: (v=" +
            (if (ref.visibility != null) ref.visibility else "null") + ", req=" +
            (if (ref.defaultRequired != null) ref.defaultRequired else "null") + ")"
    }
    
    def dumpPackage(PackageDefinition p) '''
       === PACKAGE «p.name» («IF p.bundle != null»BUNDLE «p.bundle»«ELSE»ROOT«ENDIF») === 
       «FOR c:p.classes»
           CLASS «c.name»: «IF c.getParent != null»EXTENDS «c.getParent.name»«ENDIF» abstract=«c.isAbstract» final=«c.isFinal»
               //
               «FOR i:c.fields»
                   FIELD «i.name»: «IF i.required != null»local required = «i.required.x», «ENDIF»«IF i.visibility != null»local visibility = «i.visibility.x», «ENDIF»«writeDefaults(i)»
               «ENDFOR»
           
       «ENDFOR»
    '''
}