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
import de.jpaw.bonaparte.dsl.generator.Util

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.dsl.generator.JavaPackages.*
import de.jpaw.bonaparte.dsl.bonScript.XExternalizable
import de.jpaw.bonaparte.dsl.bonScript.XXmlAccess
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition
import java.util.List
import java.util.ArrayList
import de.jpaw.bonaparte.dsl.bonScript.XBeanValidation
import de.jpaw.bonaparte.dsl.generator.ImportCollector

// generator for the language Java
class JavaBonScriptGeneratorMain implements IGenerator {
    val boolean codegenJava7 = false    // set to true to generate String switches for enum
    
    private String bonaparteInterfacesPackage = "de.jpaw.bonaparte.core"
    var Map<String, String> requiredImports = new HashMap<String, String>()
    
    // create the filename to store a generated java class source in. Assumes subdirectory ./java
    def private static getJavaFilename(String pkg, String name) {
        return "java/" + pkg.replaceAll("\\.", "/") + "/" + name + ".java"
    }
    // create the filename to store the JAXB index in
    def private static getJaxbResourceFilename(String pkg) {
        return "resources/" + pkg.replaceAll("\\.", "/") + "/jaxb.index"
    }
    
    override void doGenerate(Resource resource, IFileSystemAccess fsa) {
        requiredImports.clear()  // clear hash for this new class output
        for (d : resource.allContents.toIterable.filter(typeof(EnumDefinition)))
            fsa.generateFile(getJavaFilename(getPackageName(d), d.name), d.writeEnumDefinition);
        for (d : resource.allContents.toIterable.filter(typeof(ClassDefinition)))
            fsa.generateFile(getJavaFilename(getPackageName(d), d.name), d.writeClassDefinition);
        for (d : resource.allContents.toIterable.filter(typeof(PackageDefinition))) {
            // get a list of all classes which have an XML tag
            var List<ClassDefinition> classList = new ArrayList<ClassDefinition>()
            for (cl : d.classes)
                if (!cl.isAbstract && getXmlAccess(cl) != null)
                    classList.add(cl)
            if (classList.size() > 0)
                fsa.generateFile(getJaxbResourceFilename(getPackageName(d)), '''
                «FOR cl : classList»
                    «cl.name»
                «ENDFOR»
                ''')
            
            // also, write a package-info.java file, if javadoc on package level exists
            if (d.javadoc != null) {
                fsa.generateFile(getJavaFilename(getPackageName(d), "package-info"), '''
                    // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
                    // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
                    // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git
                    
                    «d.javadoc» 
                    package «getPackageName(d)»;
                ''')
            }
        }
        requiredImports.clear()  // cleanup, we don't know how long this object will live
    }
    
    def writeEnumDefinition(EnumDefinition d) {
        var int counter = -1
        return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git 
        package «getPackageName(d)»;
        
        import de.jpaw.util.EnumException;
        
        «IF d.javadoc != null»
            «d.javadoc»
        «ENDIF»        

        public enum «d.name» {
            «IF d.avalues == null || d.avalues.size() == 0»
                «FOR v:d.values SEPARATOR ', '»«v»«ENDFOR»;
            «ELSE»
                «FOR v:d.avalues SEPARATOR ', '»«v.name»("«v.token»")«ENDFOR»;
                
                // constructor by token
                private String _token; 
                private «d.name»(String _token) {
                    this._token = _token;
                }

                // token retrieval
                public String getToken() {
                    return _token;
                }
                
                // static factory method.«IF codegenJava7» Requires Java 7«ENDIF»
                public static «d.name» factory(String _token) throws EnumException {
                    if (_token != null) {
                        «IF codegenJava7»
                            switch (_token) {
                            «FOR v:d.avalues»
                                case "«v.token»": return «v.name»;  
                            «ENDFOR»
                            default: throw new EnumException(EnumException.INVALID_NUM, _token);
                            }
                        «ELSE»
                            «FOR v:d.avalues»
                                if (_token.equals("«v.token»")) return «v.name»;  
                            «ENDFOR»
                            throw new EnumException(EnumException.INVALID_NUM, _token);
                        «ENDIF»
                    }
                    return null;
                }
            «ENDIF»
                
            public static «d.name» valueOf(Integer ordinal) throws EnumException {
                if (ordinal != null) { 
                    switch (ordinal.intValue()) {
                    «IF d.avalues == null || d.avalues.size() == 0»
                        «FOR v:d.values»
                            case «Integer::valueOf(counter = counter + 1).toString()»: return «v»;  
                        «ENDFOR»
                    «ELSE»
                        «FOR v:d.avalues»
                            case «Integer::valueOf(counter = counter + 1).toString()»: return «v.name»;  
                        «ENDFOR»
                    «ENDIF»
                    default: throw new EnumException(EnumException.INVALID_NUM, ordinal.toString());
                    }
                }
                return null;
            }
        }
        '''
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
    
    // decision classes for the package level settings
    def private static getXmlAccess(ClassDefinition d) {
        var XXmlAccess t = d.xmlAccess?.x ?: getPackage(d).xmlAccess?.x ?: null     // default to no XMLAccess annotations
        return if (t == XXmlAccess::NOXML) null else t
    }
    def private static getExternalizable(ClassDefinition d) {
        val XExternalizable t = d.isExternalizable?.x ?: getPackage(d).isExternalizable?.x ?: XExternalizable::EXT   // default to creation of externalization methods
        return t != null && t != XExternalizable::NOEXT         
    }
    def private static getBeanValidation(ClassDefinition d) {
        var XBeanValidation t = d.doBeanValidation?.x ?: getPackage(d).doBeanValidation?.x ?: XBeanValidation::NOBEAN_VAL  // default to creation of no bean validation annotations
        return t != null && t != XBeanValidation::NOBEAN_VAL
    }
        
        
    def writeClassDefinition(ClassDefinition d) {
    // map to evaluate if we have conflicting class names and need FQCNs
    // key is the class name, data is the package name
    // using FQONs in case of conflict is not yet implemented
        val String myPackageName = getPackageName(d)
        val ImportCollector imports = new ImportCollector(myPackageName)
        imports.recurseImports(d, true)
        imports.addImport(d)  // add myself as well
        if (d.genericParameters != null)
            for (gp : d.genericParameters)
                if (gp.^extends != null)
                    imports.addImport(gp.^extends)
        // determine XML annotation support
        val XXmlAccess xmlAccess = getXmlAccess(d)
        val doExt = getExternalizable(d)
        val doBeanVal = getBeanValidation(d)
    return
    '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git 
        package «getPackageName(d)»;
        
        import java.util.Arrays;
        import java.util.List;
        import java.util.ArrayList;
        import java.util.regex.Pattern;
        import java.util.regex.Matcher;
        import java.util.Calendar;
        import java.util.UUID;
        import java.util.HashMap;
        import java.util.Map;
        import java.util.concurrent.ConcurrentHashMap;
        import java.util.concurrent.ConcurrentMap;
        import java.math.BigDecimal;
        import de.jpaw.util.ByteArray;
        import de.jpaw.util.CharTestsASCII;
        import de.jpaw.util.EnumException;
        import de.jpaw.util.ToStringHelper;
        «IF Util::useJoda()»
        import org.joda.time.LocalDate;
        import org.joda.time.LocalDateTime;
        «ELSE»
        import de.jpaw.util.DayTime;
        «ENDIF»
        «IF (xmlAccess != null && !d.isAbstract)»
            import javax.xml.bind.annotation.XmlAccessorType;
            import javax.xml.bind.annotation.XmlAccessType;
            import javax.xml.bind.annotation.XmlRootElement;
        «ENDIF»
        «JavaBeanValidation::writeImports(doBeanVal)»
        «IF doExt»
        import java.io.Externalizable;
        import java.io.IOException;
        import java.io.ObjectInput;
        import java.io.ObjectOutput;
        import «bonaparteInterfacesPackage».ExternalizableConstants;
        import «bonaparteInterfacesPackage».ExternalizableComposer;
        import «bonaparteInterfacesPackage».ExternalizableParser;
        «ENDIF»
        import «bonaparteInterfacesPackage».BonaPortable;
        import «bonaparteInterfacesPackage».BonaPortableWithMetaData;
        import «bonaparteInterfacesPackage».MessageParser;
        import «bonaparteInterfacesPackage».MessageComposer;
        import «bonaparteInterfacesPackage».MessageParserException;
        import «bonaparteInterfacesPackage».ObjectValidationException;
        import «bonaparteInterfacesPackage».StringConverter;
        import «bonaparteClassDefaultPackagePrefix».meta.*;
        «imports.createImports»
        
        
        «IF d.javadoc != null»
            «d.javadoc»
        «ENDIF»        

        «IF (xmlAccess != null && !d.isAbstract)»
            @XmlRootElement
            @XmlAccessorType(XmlAccessType.«xmlAccess.toString»)
        «ENDIF»
        «IF d.isDeprecated»
        @Deprecated
        «ENDIF»
        public«IF d.isFinal» final«ENDIF»«IF d.isAbstract» abstract«ENDIF» class «d.name»«genericDef2String(d.genericParameters)»«IF d.extendsClass != null» extends «d.parent.name»«genericArgs2String(d.extendsClass.classRefGenericParms)»«ENDIF»
          implements BonaPortableWithMetaData«IF doExt», Externalizable«ENDIF»«IF d.implementsInterface != null», «d.implementsInterface»«ENDIF» {
            private static final long serialVersionUID = «getSerialUID(d)»L;
        
            «JavaMeta::writeMetaData(d)»
            «JavaRtti::writeRtti(d)»
            «JavaFieldsGettersSetters::writeFields(d, doBeanVal)»
            «JavaFieldsGettersSetters::writeGettersSetters(d)»
            «JavaValidate::writePatterns(d)»
            «JavaSerialize::writeSerialize(d)»
            «JavaDeserialize::writeDeserialize(d)»
            «JavaValidate::writeValidationCode(d)»
            «JavaCompare::writeHash(d)»
            «JavaCompare::writeComparisonCode(d)»
            «IF doExt»
            «JavaExternalize::writeExternalize(d)»
            «JavaDeexternalize::writeDeexternalize(d)»
            «ENDIF»
            «JavaTreeWalker::writeTreeWalkerCode(d)»
            «JavaConstructor::writeConstructorCode(d)»
            
            @Override
            public String toString() {
                return ToStringHelper.toStringSL(this);
            }
        }
    '''   
    }
    def JavaDeexternalize(ClassDefinition definition) { }
 
}