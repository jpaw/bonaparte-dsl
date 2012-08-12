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
  
package de.jpaw.bonaparte.dsl.generator.java

import java.util.Map
import java.util.HashMap

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IGenerator
import org.eclipse.xtext.generator.IFileSystemAccess

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.EnumDefinition
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dsl.generator.Util

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.dsl.generator.JavaPackages.*

// generator for the language Java
class JavaBonScriptGeneratorMain implements IGenerator {
    
    private String bonaparteInterfacesPackage = "de.jpaw.bonaparte.core"
    var Map<String, String> requiredImports = new HashMap<String, String>()
    
    // create the filename to store a generated java class source in. Assumes subdirectory ./java
    def private static getJavaFilename(String pkg, String name) {
        return "java/" + pkg.replaceAll("\\.", "/") + "/" + name + ".java";
    }
    
    override void doGenerate(Resource resource, IFileSystemAccess fsa) {
        requiredImports.clear()  // clear hash for this new class output
        for (d : resource.allContents.toIterable.filter(typeof(EnumDefinition)))
            fsa.generateFile(getJavaFilename(getPackageName(d), d.name), d.writeEnumDefinition);
        for (d : resource.allContents.toIterable.filter(typeof(ClassDefinition)))
            fsa.generateFile(getJavaFilename(getPackageName(d), d.name), d.writeClassDefinition);
        requiredImports.clear()  // cleanup, we don't know how long this object will live
    }
    
    def writeEnumDefinition(EnumDefinition d) {
        var int counter = -1
        return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git 
        package «getPackageName(d)»;

        public enum «d.name» {
            «FOR v:d.values SEPARATOR ', '»«v»«ENDFOR»;
            
            public static «d.name» valueOf(Integer ordinal) {
                if (ordinal != null) { 
                    switch (ordinal.intValue()) {
                    «FOR v:d.values»
                        case «Integer::valueOf(counter = counter + 1).toString()»: return «v»;  
                    «ENDFOR»
                    }
                }
                return null;
            }
        }
        '''
    }

    def void addImport(String packageName, String objectName) {
        val String currentEntry = requiredImports.get(objectName)
        if (currentEntry == null) // not yet in, fine, add it!
            requiredImports.put(objectName, packageName)
        else
            if (!currentEntry.equals(packageName))  // not good, more than one entry!
                requiredImports.put(objectName, "-")  // this will cause am intentional compile error of the generated code
    }

/* currently unused
            «JavaMethods::writeMethods(d)» 
    def private recurseMethods(ClassDefinition d, boolean isRoot) {
        for (m : d.methods)
            if (m.returnObj != null)
                addImport(getPackageName(m.returnObj), m.returnObj.name)
        if (!isRoot || (isRoot && !d.isAbstract)) // if we are not root, descend all way through. Otherwise, descend if not abstract
            if (d.extendsClass != null)
                recurseMethods(d.extendsClass, false)
    }  */
    def collectRequiredImports(ClassDefinition d) {
        // collect all imports for this class (make sure we don't duplicate any)
        for (i : d.fields) {
            var ref = DataTypeExtension::get(i.datatype)
            // referenced objects
            if (ref.objectDataType != null)
                addImport(getPackageName(ref.objectDataType), ref.objectDataType.name)
            // referenced enums
            if (ref.elementaryDataType != null && ref.elementaryDataType.name.toLowerCase().equals("enum"))
                addImport(getPackageName(ref.elementaryDataType.enumType), ref.elementaryDataType.enumType.name)
        }
        // return parameters of specific methods 
        //recurseMethods(d, true)
        // finally, possibly the parent object
        if (d.extendsClass != null)
            addImport(getPackageName(d.extendsClass), d.extendsClass.name)

        // we should have all used classes in the map now. Need to import all of them with a package name differing from ours
    }
    
    def writeClassDefinition(ClassDefinition d) {
    // map to evaluate if we have conflicting class names and need FQCNs
    // key is the class name, data is the package name
    // using FQONs in case of conflict is not yet implemented
        val String myPackageName = getPackageName(d)
        collectRequiredImports(d)
        addImport(myPackageName, d.name)  // add myself as well
        
    return
    '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git 
        package «getPackageName(d)»;
        
        import java.util.Arrays;
        import java.util.List;
        import java.util.regex.Pattern;
        import java.util.regex.Matcher;
        import java.util.GregorianCalendar;
        import java.util.UUID;
        import java.math.BigDecimal;
        import de.jpaw.util.ByteArray;
        import de.jpaw.util.CharTestsASCII;
        «IF Util::useJoda()»
        import org.joda.time.LocalDate;
        import org.joda.time.LocalDateTime;
        «ELSE»
        import de.jpaw.util.DayTime;
        «ENDIF»
        import «bonaparteInterfacesPackage».BonaPortable;
        import «bonaparteInterfacesPackage».BonaPortableWithMetaData;
        import «bonaparteInterfacesPackage».MessageParser;
        import «bonaparteInterfacesPackage».MessageComposer;
        import «bonaparteInterfacesPackage».MessageParserException;
        import «bonaparteInterfacesPackage».ObjectValidationException;
        import «bonaparteClassDefaultPackagePrefix».meta.*;
        «FOR o : requiredImports.keySet»
            «IF !requiredImports.get(o).equals(myPackageName)»
                import «requiredImports.get(o)».«o»;
            «ENDIF»
        «ENDFOR»
        
        public«IF d.isFinal» final«ENDIF»«IF d.isAbstract» abstract«ENDIF» class «d.name»«IF d.extendsClass != null» extends «possiblyFQClassName(d, d.extendsClass)»«ENDIF» implements BonaPortableWithMetaData {
            
            «JavaMeta::writeMetaData(d)» 
            «JavaFieldsGettersSetters::writeFields(d)» 
            «JavaValidate::writePatterns(d)» 
            «JavaSerialize::writeSerialize(d)» 
            «JavaDeserialize::writeDeserialize(d)» 
            «JavaValidate::writeValidationCode(d)»            
            «JavaCompare::writeComparisonCode(d)»            
        }
    '''   
    }

      
 
}