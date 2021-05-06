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
import de.jpaw.bonaparte.dsl.generator.xsd.XsdBonScriptGeneratorMain
import java.util.concurrent.atomic.AtomicInteger
import javax.inject.Inject
import org.apache.log4j.Logger
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.AbstractGenerator
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext

class BonScriptGenerator extends AbstractGenerator {
    private static final Logger LOGGER = Logger.getLogger(BonScriptGenerator)
    private static final AtomicInteger globalId = new AtomicInteger(0)
    private final int localId = globalId.incrementAndGet

    @Inject DebugBonScriptGeneratorMain generatorDebug
    @Inject JavaBonScriptGeneratorMain generatorJava
    @Inject XsdBonScriptGeneratorMain generatorXsd

    def private String filterInfo() {
        "@" + localId + ": "
    }

    public new() {
        LOGGER.info("BonScriptGenerator constructed. " + filterInfo)
    }

    override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext unused) {

        try {
            if (BonScriptPreferences.currentPrefs.doDebugOut) {
                LOGGER.info(filterInfo + "start code output: Debug dump for " + resource.URI.toString);
                generatorDebug.doGenerate(resource, fsa)
            }

            LOGGER.info(filterInfo + "start code output: Java output for " + resource.URI.toString);
            generatorJava.doGenerate(resource, fsa, unused)

            if (!BonScriptPreferences.getNoXML) {
                LOGGER.info(filterInfo + "start XSD creation for " + resource.URI.toString);
                generatorXsd.doGenerate(resource, fsa, unused)
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
