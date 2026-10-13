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

import de.jpaw.bonaparte.dsl.BonScriptPreferences
import de.jpaw.bonaparte.dsl.generator.debug.DebugBonScriptGeneratorMain
import de.jpaw.bonaparte.dsl.generator.java.JavaBonScriptGeneratorMain
import de.jpaw.bonaparte.dsl.generator.tsapi.TsApiClientGenerator
import de.jpaw.bonaparte.dsl.generator.ts.TypeScriptBonScriptGeneratorMain
import de.jpaw.bonaparte.dsl.generator.ts.TsGenerationContext
import de.jpaw.bonaparte.dsl.generator.xsd.XsdBonScriptGeneratorMain
import java.util.concurrent.atomic.AtomicInteger
import jakarta.inject.Inject
import org.apache.log4j.Logger
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.AbstractGenerator
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext

class BonScriptGenerator extends AbstractGenerator {
    static final Logger LOGGER = Logger.getLogger(BonScriptGenerator)
    static final AtomicInteger globalId = new AtomicInteger(0)

    final int localId = globalId.incrementAndGet
    final String jakartaPrefix;

    @Inject DebugBonScriptGeneratorMain generatorDebug
    @Inject JavaBonScriptGeneratorMain generatorJava
    @Inject XsdBonScriptGeneratorMain generatorXsd
    @Inject TypeScriptBonScriptGeneratorMain generatorTs
    @Inject TsApiClientGenerator generatorTsApi
    @com.google.inject.Inject(optional=true) TsGenerationContext ownershipContext

    def private String filterInfo() {
        "@" + localId + ": "
    }

    new() {
        jakartaPrefix = if (BonScriptPreferences.currentPrefs.jakartaOutput) "jakarta" else "javax"
        LOGGER.info("BonScriptGenerator constructed for " + jakartaPrefix + ". " + filterInfo)
    }

    override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext unused) {
        val resAsString = resource.URI.toString
        if (ownershipContext !== null)
            TsGenerationContext.attach(resource.resourceSet, ownershipContext)

        try {
            if (BonScriptPreferences.currentPrefs.doDebugOut) {
                LOGGER.info(filterInfo + "start code output: Debug dump for " + resAsString);
                generatorDebug.doGenerate(resource, fsa)
            }

            if (BonScriptPreferences.getDoJava) {
	            LOGGER.info(filterInfo + "start code output: Java output for " + resAsString);
	            generatorJava.doGenerate(resource, fsa, unused)
            }

            if (BonScriptPreferences.getDoXsd) {
                LOGGER.info(filterInfo + "start XSD creation for " + resAsString);
                generatorXsd.doGenerate(resource, fsa, unused)
            }

            if (BonScriptPreferences.getDoTypeScript) {
                LOGGER.info(filterInfo + "start TypeScript creation for " + resAsString);
                generatorTs.doGenerate(resource, fsa, unused)
            }
            if (BonScriptPreferences.getDoTypeScriptApi) {
                LOGGER.info(filterInfo + "start TypeScript API creation for " + resAsString);
                generatorTsApi.doGenerate(resource, fsa)
            }

            LOGGER.info(filterInfo + "start cleanup");
            DataTypeExtension::clear()

        } catch (Exception e) {
            LOGGER.error("Exception " + e.message)
            e.printStackTrace(System.out)
            throw e
        }
    }
}
