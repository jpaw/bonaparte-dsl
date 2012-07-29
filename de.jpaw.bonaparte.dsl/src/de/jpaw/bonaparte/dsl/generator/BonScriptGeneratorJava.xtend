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

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition
import de.jpaw.bonaparte.dsl.bonScript.ElementaryDataType
import de.jpaw.bonaparte.dsl.bonScript.DataType
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition

// using JCL here, because it is already a project dependency, should switch to slf4j
//import org.apache.commons.logging.Log
//import org.apache.commons.logging.LogFactory

// generator for the language Java
class BonScriptGeneratorJava implements IGenerator {
    // we use JCL instead of SLF4J here in order not not introduce another logging framework (JCL is already used in Eclipse)
    //private static final logger logger = LoggerFactory.getLogger(BonScriptGenerator.class); // slf4f
    //private static Log logger = LogFactory::getLog("de.jpaw.bonaparte.dsl.generator.BonScriptGeneratorJava") // jcl
    
    String bonaparteInterfacesPackage = "de.jpaw.bonaparte.core"
    String bonaparteClassDefaultPackagePrefix = "de.jpaw.bonaparte.pojos"
    
    
    // Utility methods
    def getMediumClassName(ClassDefinition d) {
        (d.eContainer as PackageDefinition).name + "." + d.name  
    }
    // create the package name for a class definition object
    def getPackageName(ClassDefinition d) {
        val PackageDefinition pkg = d.eContainer as PackageDefinition
        (if (pkg.prefix == null) bonaparteClassDefaultPackagePrefix else pkg.prefix) + "." + pkg.name  
    }
    
    // create the filename to store a generated java class source in. Assumes subdirectory ./java
    def getJavaFilename(ClassDefinition d) {
        return "java/" + getPackageName(d).replaceAll("\\.", "/") + "/" + d.name + ".java";
    }
    
    // convert an Xtend boolean to Java source token
    def b2A(boolean f) {
        if (f) "true" else "false"
    }
    
    // get the elementary data object after resolving typedefs
    // uses caching to keep overall running time at O(1) per call
    def ElementaryDataType resolveElem(DataType d) {
        DataTypeExtension::get(d).elementaryDataType
    }
    
    // get the class / object reference after resolving typedefs
    // uses caching to keep overall running time at O(1) per call
    def ClassDefinition resolveObj(DataType d) {
        DataTypeExtension::get(d).objectDataType
    }

    // generate a fully qualified or (optically nicer) simple class name, depending on whether target is in same package as the current class 
    def possiblyFQClassName(ClassDefinition current, ClassDefinition target) {
        if (getPackageName(current) == getPackageName(target))
            target.name
        else
            getPackageName(target) + "." +target.name
    }
    
    def String getJavaDataType(DataType d) {
        val ref = DataTypeExtension::get(d)
        if (ref.isPrimitive)
            ref.elementaryDataType.name
        else
            ref.javaType
    }
    
    /*
    def fieldDebug(FieldDefinition i) {
        System::out.println("DEBUG: Field " + i.name + ": d=" + i.datatype)
        System::out.println("                              e=" + i.datatype.elementaryDataType
            + ", o=" + i.datatype.objectDataType + ", t=" + i.datatype.dataTypeReference)
        System::out.println("                              e=" + resolveElem(i.datatype)
            + ", o=" + resolveObj(i.datatype))
    } */
    
    override void doGenerate(Resource resource, IFileSystemAccess fsa) {
        for (d : resource.allContents.toIterable.filter(typeof(ClassDefinition)))
            fsa.generateFile(getJavaFilename(d), d.writeClassDefinition);
    }
    
    def writeClassDefinition(ClassDefinition d) '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git 
        package «getPackageName(d)»;
        
        import java.util.GregorianCalendar;
        import java.util.List;
        import java.util.regex.Pattern;
        import java.util.regex.Matcher;
        import java.math.BigDecimal;
        import de.jpaw.util.CharTestsASCII;
        import «bonaparteInterfacesPackage».BonaPortable;
        import «bonaparteInterfacesPackage».MessageParser;
        import «bonaparteInterfacesPackage».MessageComposer;
        import «bonaparteInterfacesPackage».MessageParserException;
        import «bonaparteInterfacesPackage».ObjectValidationException;
        «FOR i:d.fields»
            «IF resolveObj(i.datatype) != null && getPackageName(d) != getPackageName(resolveObj(i.datatype))»
                import «getPackageName(resolveObj(i.datatype))».«resolveObj(i.datatype).name»;
            «ENDIF»
        «ENDFOR»
        «IF d.extendsClass != null && getPackageName(d.extendsClass) != getPackageName(d)»import «getPackageName(d.extendsClass)».«d.extendsClass.name»;«ENDIF»
        
        public«IF d.isFinal» final«ENDIF»«IF d.isAbstract» abstract«ENDIF» class «d.name»«IF d.extendsClass != null» extends «possiblyFQClassName(d, d.extendsClass)»«ENDIF» implements BonaPortable {
            // my name and revision
            private static final String MEDIUM_CLASS_NAME = "«getMediumClassName(d)»";
            private static final String REVISION = «IF d.revision != null && d.revision.length > 0»"«d.revision»"«ELSE»null«ENDIF»;

            // regexp patterns. TODO: add check for uniqueness
            «FOR i: d.fields»
                «IF resolveElem(i.datatype) != null && resolveElem(i.datatype).regexp != null»
                    private static final Pattern _regexp_«i.name» = Pattern.compile("\\A«resolveElem(i.datatype).regexp»\\z");
                «ENDIF»
            «ENDFOR»
            // fields
            «FOR i:d.fields»
                public «JavaDataTypeNoName(i)» «i.name»;
                public «JavaDataTypeNoName(i)» get«Util::capInitial(i.name)»() {
                    return «i.name»;
                }
                public void set«Util::capInitial(i.name)»(«JavaDataTypeNoName(i)» «i.name») {
                    this.«i.name» = «i.name»;
                }
            «ENDFOR»
            

            @Override
            public String getMediumClassName() {  // something between class.getSimpleName() and get fully qualified name
                return MEDIUM_CLASS_NAME;
            }
            @Override
            public String getRevision() {
                return REVISION;
            }

            /* serialize the object into a String. uses implicit toString() member functions of elementary data types */
            @Override
            public void serialiseSub(MessageComposer w) {
                «IF d.extendsClass != null»
                    // recursive call of superclass first
                    super.serialiseSub(w);
                    w.writeSuperclassSeparator();
                «ENDIF»
                «FOR i:d.fields»
                    «IF i.isArray != null»
                        if («i.name» == null) {
                            w.writeNull();
                        } else {
                            w.startArray(«i.name».length, «i.isArray.maxcount»);
                            for (int i = 0; i < «i.name».length; ++i)
                                «makeWrite2(d, i, "[i]")»
                            w.terminateArray();
                        }
                    «ELSE»
                        «makeWrite2(d, i, "")»
                    «ENDIF»
                «ENDFOR»
            }


            /* serialize the object into a String. uses implicit toString() member functions of elementary data types */
            // this method is not needed any more because it is performed in the MessageComposer object
            @Override
            public void serialise(MessageComposer w) {
                // start a new object
                w.startObject(getMediumClassName(), getRevision());
                // do all fields
                serialiseSub(w);
                // terminate the object
                w.terminateObject();
            }
            
            @Override
            public void deserialise(MessageParser p) throws MessageParserException {
                int arrayLength;
                // String embeddingObject = p.setCurrentClass(getMediumClassName); // backup for the class name currently parsed
                «IF d.extendsClass != null»
                    super.deserialise(p);
                    p.eatParentSeparator();
                «ENDIF»
                «FOR i:d.fields»
                    «IF i.isArray != null»
                        arrayLength = p.parseArrayStart(«i.isArray.maxcount», null, 0);
                        if (arrayLength < 0) {
                            «i.name» = null;
                        } else {
                            «IF resolveElem(i.datatype) != null && getJavaDataType(i.datatype).equals("byte []")»
                                «i.name» = new byte [«if (i.isArray.maxcount > 0) i.isArray.maxcount else "arrayLength"»][];  // Java weirdness: dimension swapped to first pair of brackets!
                            «ELSE»
                                «i.name» = new «if (resolveElem(i.datatype) != null) getJavaDataType(i.datatype) else getPackageName(resolveObj(i.datatype)) + "." + resolveObj(i.datatype).name»[«if (i.isArray.maxcount > 0) i.isArray.maxcount else "arrayLength"»];
                            «ENDIF»
                            for (int i = 0; i < arrayLength; ++i)
                                «makeRead2(d, i, "[i]")»
                            p.parseArrayEnd();
                        }
                    «ELSE»
                        «makeRead2(d, i, "")»
                    «ENDIF»
                «ENDFOR»
                // p.setCurrentClass(embeddingObject); // ignore result
            }
            
            // TODO: validation is still work in progress and must be extensively redesigned
            @Override
            public void validate() throws ObjectValidationException {
                // perform checks for required fields
                «IF d.extendsClass != null»
                    super.validate();
                «ENDIF»
                «FOR i:d.fields»
                    «IF i.isRequired»
                        if («i.name» == null)
                            throw new ObjectValidationException(ObjectValidationException.MAY_NOT_BE_BLANK,
                                                                "«i.name»", getMediumClassName());
                        «IF i.isArray != null»
                            for (int i = 0; i < «i.name».length; ++i)
                                if («i.name»[i] == null)
                                    throw new ObjectValidationException(ObjectValidationException.MAY_NOT_BE_BLANK,
                                                                "«i.name»["+i+"]", getMediumClassName());
                        «ENDIF»
                    «ENDIF»
                    «IF resolveObj(i.datatype) != null»
                        «IF i.isArray != null»
                            if («i.name» != null)
                                for (int i = 0; i < «i.name».length; ++i)
                                    «makeValidate(i, "[i]")»
                        «ELSE»
                            «makeValidate(i, "")»
                        «ENDIF»
                    «ENDIF»
                «ENDFOR»
                «FOR i:d.fields»
                    «IF resolveElem(i.datatype) != null && (resolveElem(i.datatype).regexp != null || DataTypeExtension::get(i.datatype).isUpperCaseOrLowerCaseSpecialType)»
                        «IF i.isArray != null»
                            if («i.name» != null)
                                for (int i = 0; i < «i.name».length; ++i)
                                    «makePatternCheck(i, "[i]", DataTypeExtension::get(i.datatype))»
                        «ELSE»
                            «makePatternCheck(i, "", DataTypeExtension::get(i.datatype))»
                        «ENDIF»
                    «ENDIF»
                «ENDFOR»
            }
            
        }
    '''                 

    def makePatternCheck(FieldDefinition i, String index, DataTypeExtension ref) '''
        if («i.name»«index» != null) {
            «IF ref.elementaryDataType.regexp != null» 
                Matcher _m =  _regexp_«i.name».matcher(«i.name»«index»);
                if (!_m.find())
                    throw new ObjectValidationException(ObjectValidationException.NO_PATTERN_MATCH,
                                                        "«i.name»«index»", getMediumClassName());
            «ENDIF»
            «IF ref.isUpperCaseOrLowerCaseSpecialType» 
                if (!CharTestsASCII.is«IF ref.elementaryDataType.name.toLowerCase.equals("uppercase")»UpperCase«ELSE»LowerCase«ENDIF»(«i.name»«index»))
                    throw new ObjectValidationException(ObjectValidationException.NO_PATTERN_MATCH,
                                                        "«i.name»«index»", getMediumClassName());
            «ENDIF»
        }
    '''

    def makeValidate(FieldDefinition i, String index) '''
        «IF i.isRequired»
            «i.name»«index».validate();      // check object (!= null checked before)
        «ELSE»
            if («i.name»«index» != null)
                «i.name»«index».validate();  // check object
        «ENDIF»
    '''
   
    def makeWrite2(ClassDefinition d, FieldDefinition i, String index) '''
        «IF resolveElem(i.datatype) != null»
            «makeWrite(i.name + index, resolveElem(i.datatype), DataTypeExtension::get(i.datatype))»
        «ELSE»
            w.addField(«i.name»«index»);
        «ENDIF»
    '''
   
    def makeWrite(String indexedName, ElementaryDataType e, DataTypeExtension ref) {
        val String grammarName = e.name.toLowerCase;
        if (grammarName.equals("unicode") && ref.effectiveAllowCtrls)  // special treatment if escaped characters must be checked for
            '''w.addEscapedString(«indexedName», «e.length»);'''
        else if (ref.javaType.equals("String") || grammarName.equals("raw") || grammarName.equals("timestamp"))
            '''w.addField(«indexedName», «e.length»);'''
        else if (grammarName.equals("decimal"))
            '''w.addField(«indexedName», «e.length», «e.decimals», «ref.effectiveSigned»);'''
        else if (grammarName.equals("number"))
            '''w.addField(«indexedName», «e.length», «ref.effectiveSigned»);'''
        else if (grammarName.equals("day"))
            '''w.addField(«indexedName», -1);'''
        else // primitive or boxed type
            '''w.addField(«indexedName»);'''
    }

    def makeRead2(ClassDefinition d, FieldDefinition i, String index) '''
        «IF resolveElem(i.datatype) != null»
            «i.name»«index» = «makeRead(resolveElem(i.datatype), DataTypeExtension::get(i.datatype))»;
        «ELSE»
            «i.name»«index» = («possiblyFQClassName(d, resolveObj(i.datatype))»)p.readObject(«possiblyFQClassName(d, resolveObj(i.datatype))».class, «b2A(i.isRequired)», «b2A(i.datatype.orSuperClass)»);
        «ENDIF»
    '''

    def makeRead(ElementaryDataType i, DataTypeExtension ref) {
        switch i.name.toLowerCase {
        // numeric (non-float) types
        case 'long':      '''p.readLong      («ref.wasUpperCase», «ref.effectiveSigned»)'''
        case 'int':       '''p.readInteger   («ref.wasUpperCase», «ref.effectiveSigned»)'''
        case 'integer':   '''p.readInteger   («ref.wasUpperCase», «ref.effectiveSigned»)'''
        case 'number':    '''p.readInt       («ref.wasUpperCase», «i.length», «ref.effectiveSigned»)'''
        case 'decimal':   '''p.readBigDecimal(«ref.wasUpperCase», «i.length», «i.decimals», «ref.effectiveSigned»)'''
        // float and boolean    
        case 'float':     '''p.readFloat («ref.wasUpperCase»)'''
        case 'double':    '''p.readDouble(«ref.wasUpperCase»)'''
        case 'boolean':   '''p.readBoolean(«ref.wasUpperCase»)'''
        // text
        case 'uppercase': '''p.readString(«ref.wasUpperCase», «i.length», «ref.effectiveTrim», «ref.effectiveAllowCtrls», false)'''
        case 'lowercase': '''p.readString(«ref.wasUpperCase», «i.length», «ref.effectiveTrim», «ref.effectiveAllowCtrls», false)'''
        case 'ascii':     '''p.readString(«ref.wasUpperCase», «i.length», «ref.effectiveTrim», «ref.effectiveAllowCtrls», false)'''
        case 'unicode':   '''p.readString(«ref.wasUpperCase», «i.length», «ref.effectiveTrim», «ref.effectiveAllowCtrls», true)'''
        // special          
        case 'raw':       '''p.readBytes («ref.wasUpperCase», «i.length»)'''
        case 'timestamp': '''p.readGregorianCalendar(«ref.wasUpperCase», «i.length»)'''
        case 'day':       '''p.readGregorianCalendar(«ref.wasUpperCase», -1)'''
        }
    }
    
    def JavaDataTypeNoName(FieldDefinition i) {
        var String dataClass
        //fieldDebug(i)
        if (resolveElem(i.datatype) != null)
            dataClass = getJavaDataType(i.datatype)
        else {
            if (resolveObj(i.datatype) == null)
                throw new RuntimeException("INTERNAL ERROR object type not set for field of type object for " + i.name);
            dataClass = resolveObj(i.datatype).name
        }
        if (i.isArray != null)
            // dataClass + "[" + (if (i.isArray.maxcount > 0) i.isArray.maxcount) + "]" 
            dataClass + "[]" 
        else
            dataClass
    }
 
}