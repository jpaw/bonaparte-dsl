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
  
package de.jpaw.bonaparte.dsl.generator

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IGenerator
import org.eclipse.xtext.generator.IFileSystemAccess

// using JCL here, because it is already a project dependency, should switch to slf4j
import org.apache.commons.logging.Log
import org.apache.commons.logging.LogFactory
import de.jpaw.bonaparte.dsl.generator.debug.BonScriptGeneratorDebug
import de.jpaw.bonaparte.dsl.generator.java.BonScriptGeneratorJava

class BonScriptGenerator implements IGenerator {
    // we use JCL instead of SLF4J here in order not not introduce another logging framework (JCL is already used in Eclipse)
    //private static final logger logger = LoggerFactory.getLogger(BonScriptGenerator.class); // slf4f
    private static Log logger = LogFactory::getLog("de.jpaw.bonaparte.dsl.generator.BonScriptGenerator") // jcl
    
    
    override void doGenerate(Resource resource, IFileSystemAccess fsa) {
        
        // code output: one xtend file per language, such that it can be easily extended to additional languages
        logger.info("start code output: Debug dump");
        new BonScriptGeneratorDebug().doGenerate(resource, fsa)
        
        logger.info("start code output: Java");
        new BonScriptGeneratorJava().doGenerate(resource, fsa)
        
        logger.info("start cleanup");
        DataTypeExtension::clear()
    }
    
 
}