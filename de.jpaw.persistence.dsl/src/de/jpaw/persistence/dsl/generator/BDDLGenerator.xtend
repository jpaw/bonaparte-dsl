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

package de.jpaw.persistence.dsl.generator

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IGenerator
import org.eclipse.xtext.generator.IFileSystemAccess
import org.apache.log4j.Logger
import de.jpaw.persistence.dsl.generator.sql.SqlDDLGeneratorMain
import de.jpaw.persistence.dsl.generator.java.JavaDDLGeneratorMain
import de.jpaw.persistence.dsl.generator.res.ResourceGeneratorMain
import java.util.concurrent.atomic.AtomicInteger
import javax.inject.Inject
import de.jpaw.bonaparte.dsl.generator.Util

class BDDLGenerator implements IGenerator {
    // we use JCL instead of SLF4J here in order not not introduce another logging framework (JCL is already used in Eclipse)
    //private static final logger logger = LoggerFactory.getLogger(BonScriptGenerator.class); // slf4f
    private static Logger logger = Logger.getLogger(BDDLGenerator)
    private static boolean doFilter = Util::autodetectMavenRun;
    private static final AtomicInteger globalId = new AtomicInteger(0)
    private final int localId = globalId.incrementAndGet
    
    @Inject SqlDDLGeneratorMain generatorSql
    @Inject JavaDDLGeneratorMain generatorJava
    @Inject ResourceGeneratorMain generatorResource
    
    def public static void activateFilter() {
        //doFilter = true;  // not setting it, we rely on the Eclipse detection now
        logger.info("### BDDL STANDALONE MODE: filter is ON ### for Id " + globalId.addAndGet(100));
    }
    def private String filterInfo() {
        "#" + localId + ": " + if (doFilter) "Filter ON : " else "Filter OFF: "   
    }
    
    public new() {
        logger.info("BDDLGenerator constructed. " + filterInfo)
        /* still causes the build run to break - why? It's just a debug output!  
        try {
            val Exception e = new Exception("BDDLGenerator constructed. " + filterInfo)
            e.printStackTrace
        } catch (Exception e) {
        } */
    }
    
    override void doGenerate(Resource resource, IFileSystemAccess fsa) {
        
        // adaption: in maven builds, too many files are presented, need to filter out the ones for this project, which is done via URL start pattern
        if (!doFilter   // !doFilter = Eclipse mode
            || resource.URI.toString.startsWith("platform:/resource") // building inside Eclipse
            || (resource.URI.toString.startsWith("file:/") && resource.URI.toString.endsWith(".bddl")) // maven fornax plugin
            ) {
            logger.info(filterInfo + "start code output: SQL DDL for " + resource.URI.toString);
            generatorSql.doGenerate(resource, fsa)

            logger.info(filterInfo + "start code output: Java output for " + resource.URI.toString);
            generatorJava.doGenerate(resource, fsa)

            logger.info(filterInfo + "start code output: resource output for " + resource.URI.toString);
            generatorResource.doGenerate(resource, fsa)

            logger.info(filterInfo + "start cleanup");
        } else {
            logger.info(filterInfo + "Skipping code generation for " + resource.URI.toString);
        }
    }
}
