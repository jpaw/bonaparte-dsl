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

package de.jpaw.bonaparte.jpa.dsl.generator

import de.jpaw.bonaparte.dsl.generator.BonScriptGenerator
import de.jpaw.bonaparte.jpa.dsl.generator.java.JavaDDLGeneratorMain
import de.jpaw.bonaparte.jpa.dsl.generator.res.ResourceGeneratorMain
import de.jpaw.bonaparte.jpa.dsl.generator.sql.SqlDDLGeneratorMain
import java.util.concurrent.atomic.AtomicInteger
import jakarta.inject.Inject
import org.apache.log4j.Logger
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.AbstractGenerator
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext

class BDDLGenerator extends AbstractGenerator {
    static Logger LOGGER = Logger.getLogger(BDDLGenerator)
    static final AtomicInteger globalId = new AtomicInteger(0)
    final int localId = globalId.incrementAndGet

    @Inject BonScriptGenerator bonaparteGenerator
    @Inject SqlDDLGeneratorMain generatorSql
    @Inject JavaDDLGeneratorMain generatorJava
    @Inject ResourceGeneratorMain generatorResource

    def private String filterInfo() {
        "#" + localId + ": "
    }

    new() {
        LOGGER.info("BDDLGenerator constructed. " + filterInfo)
    }

    override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext unused) {
        try {
            bonaparteGenerator.doGenerate(resource, fsa, unused)

            LOGGER.info(filterInfo + "start code output: SQL DDL for " + resource.URI.toString);
            generatorSql.doGenerate(resource, fsa, unused)

            LOGGER.info(filterInfo + "start code output: Java output for " + resource.URI.toString);
            generatorJava.doGenerate(resource, fsa, unused)

            LOGGER.info(filterInfo + "start code output: resource output for " + resource.URI.toString);
            generatorResource.doGenerate(resource, fsa)

            LOGGER.info(filterInfo + "start cleanup");

        } catch (Exception e) {
            LOGGER.error("Exception " + e.message)
            e.printStackTrace(System.out)
            throw e
        }
    }
}
