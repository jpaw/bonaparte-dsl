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

package de.jpaw.bonaparte.jpa.dsl.generator.res

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IGenerator
import org.eclipse.xtext.generator.IFileSystemAccess
import de.jpaw.bonaparte.jpa.dsl.bDDL.PackageDefinition

class ResourceGeneratorMain implements IGenerator {

    override void doGenerate(Resource resource, IFileSystemAccess fsa) {
        for (d : resource.allContents.toIterable.filter(typeof(PackageDefinition)))
            fsa.generateFile("resources/bonaparte.jpa/" + d.name + ".txt", d.dumpPackage);
    }

    // create a file which contains the class names of all JPA Entities defined in this package
    def dumpPackage(PackageDefinition p) '''
        «FOR e: p.entities»
            «IF !e.isAbstract && !e.mappedSuperclass»
                «p.name».«e.name»
            «ENDIF»
        «ENDFOR»
    '''

}
