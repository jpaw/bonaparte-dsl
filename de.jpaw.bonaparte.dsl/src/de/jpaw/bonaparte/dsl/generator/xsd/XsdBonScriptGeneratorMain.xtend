 /*
  * Copyright 2015 Michael Bischoff
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

package de.jpaw.bonaparte.dsl.generator.xsd

import com.google.common.base.Strings
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.DataType
import de.jpaw.bonaparte.dsl.bonScript.ElementaryDataType
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition
import java.util.HashSet
import java.util.Set
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.dsl.generator.java.JavaEnum.*
import static extension de.jpaw.bonaparte.dsl.generator.java.JavaXEnum.*

/** Generator which produces xsds.
 * It is only called if XML has not been suppressed in the preferences.
 */
class XsdBonScriptGeneratorMain implements IGenerator {
    public static final String GENERATED_XSD_SUBFOLDER = "resources/xsd/";      // cannot start with a slash, must end with a slash
    //private static final boolean USE_EXTENSION = false;                         // if false, subsumption is used for inheritance, if true, extension

    val Set<PackageDefinition> requiredImports = new HashSet<PackageDefinition>()

    
    /** Creates the filename to store a generated xsd file in. */
    def private static computeXsdFilename(PackageDefinition pkg) {
        if (pkg.bundle === null)
            return pkg.schemaToken + ".xsd"
        else
            return pkg.bundle.replace('.', '/') + "/" + pkg.schemaToken + ".xsd"
    }


    /**
     * xsd generation entry point. The strategy is to loop over all packages and create one xsd per package,
     * with automatically derived short and long namespace IDs.
     * 
     * Assumption is that no package is contained in two separate bon files.
     */
    override void doGenerate(Resource resource, IFileSystemAccess fsa) {
        for (pkg : resource.allContents.toIterable.filter(typeof(PackageDefinition))) {
            if (pkg.xmlAccess !== null) {
                fsa.generateFile(GENERATED_XSD_SUBFOLDER + pkg.computeXsdFilename, pkg.writeXsdFile)
            }
        }
    }            

    def private void addConditionally(EObject e) {
        val pkg = e?.package
        if (pkg !== null)
            requiredImports.add(pkg)
    }
    
    def private collectXmlImports(PackageDefinition pkg) {
        for (cls : pkg.classes) {
            // import the parent class, if it exists
            cls.extendsClass?.classRef.addConditionally
            for (f: cls.fields) {
                val dt = f.datatype
                if (dt.elementaryDataType !== null) {
                    val e = dt.elementaryDataType
                    e.enumType.addConditionally
                    e.xenumType.addConditionally
                    e.enumsetType.addConditionally
                    e.xenumsetType.addConditionally
                } else {
                    dt.objectDataType?.classRef.addConditionally
                }
            }
        }
    }
    
    // distinction between numeric / alphanumeric enum types. Not used, as JAXB always uses the name, and neither the ordinal nor the token 
    def public createMbEnumTypes(PackageDefinition pkg) {
        return '''
            «FOR en: pkg.enums»
                <xs:simpleType name="«en.name»">
                    «IF en.isAlphaEnum»
                        <xs:restriction base="xs:string">
                            «FOR v: en.avalues»
                                <xs:enumeration value="«v.token»"/>
                            «ENDFOR»
                        </xs:restriction>
                    «ELSE»
                        <xs:restriction base="xs:integer">
                            <xs:minInclusive value="0"/>
                            <xs:maxInclusive value="«en.values.size - 1»"/>
                        </xs:restriction>
                    «ENDIF»
                </xs:simpleType>
            «ENDFOR»
        '''
    }
    
    def public createEnumTypes(PackageDefinition pkg) {
        return '''
            «FOR en: pkg.enums»
                <xs:simpleType name="«en.name»">
                    <xs:restriction base="xs:string">
                        «IF en.isAlphaEnum»
                            «FOR v: en.avalues»
                                <xs:enumeration value="«v.name»"/>
                            «ENDFOR»
                        «ELSE»
                            «FOR v: en.values»
                                <xs:enumeration value="«v»"/>
                            «ENDFOR»
                        «ENDIF»
                    </xs:restriction>
                </xs:simpleType>
            «ENDFOR»
        '''
    }
    
    def public createXEnumTypes(PackageDefinition pkg) {
        return '''
            «FOR en: pkg.xenums»
                <xs:simpleType name="«en.name»">
                    <xs:restriction base="xs:string">
                        <xs:maxLength value="«en.root.overallMaxLength»"/>
                    </xs:restriction>
                </xs:simpleType>
            «ENDFOR»
        '''
    }

    def public createEnumsetTypes(PackageDefinition pkg) {
        return '''
            «FOR en: pkg.enumSets»
                <xs:simpleType name="«en.name»">
                    <xs:list itemType="«en.myEnum.name.xsdQualifiedName(en.myEnum.package)»"/>
                </xs:simpleType>
            «ENDFOR»
        '''
    }

    def public createXEnumsetTypes(PackageDefinition pkg) {
        return '''
            «FOR en: pkg.xenumSets»
                <xs:simpleType name="«en.name»">
                    <xs:list itemType="«en.myXEnum.name.xsdQualifiedName(en.myXEnum.package)»"/>
                </xs:simpleType>
            «ENDFOR»
        '''
    }

    def public createTypeDefs(PackageDefinition pkg) {
        return '''
            «FOR td: pkg.types»
                <xs:simpleType name="«td.name»"«describeField(pkg, td.datatype, false)»
            «ENDFOR»
        '''
    }

    // specify the max occurs clause
    def public howManyMax(int limit) {
        if (limit <= 0)
            return ''' maxOccurs="unbounded"'''
        else if (limit != 1)
            return ''' maxOccurs="«limit»"'''
    }

    // specify the min occurs clause
    def public howManyMin(int limit) {
        if (limit != 1)
            return ''' minOccurs="«limit»"'''
    }

    // nillable = true allows to send empty tags for nulls, minOccurs allows omitting the tag
    def public obtainOccurs(FieldDefinition f) {
        if (f.isArray !== null)
            return '''«f.isArray.mincount.howManyMin» «f.isArray.maxcount.howManyMax»'''
        else if (f.isList !== null)
            return '''«f.isList.mincount.howManyMin» «f.isList.maxcount.howManyMax»'''
        else if (f.isSet !== null)
            return '''«f.isSet.mincount.howManyMin» «f.isSet.maxcount.howManyMax»'''
        else if (f.isMap !== null)
            return '''«f.isMap.mincount.howManyMin» «f.isMap.maxcount.howManyMax»'''
        else if (!f.isRequired)
            return ''' minOccurs="0" nillable="true"'''
    }

    def wrap(boolean inElement, CharSequence content) {
        if (inElement) {
            // inside element: must open a new simpleType element
            return '''
                >
                    <xs:simpleType>
                        «content»
                    </xs:simpleType>
                </xs:element>
            '''
        } else {
            return '''
                >
                    «content»
                </xs:simpleType>
            '''
        }
    }

    def typeWrap(boolean inElement, CharSequence content) {
        if (inElement) {
            return ''' type="«content»"/>'''
        } else {
            // not inside element: in simpleType, must use an artifical restiction (with no restrictions)
            return '''
                >
                    <xs:restriction base="«content»"/>
                </xs:simpleType>
            '''
        }
    }
    
    def public defIntegral(ElementaryDataType e, boolean signed, String name, String unsignedLimit, boolean inElement) {
        val finalName = '''xs:«IF signed»«name»«ELSE»unsigned«name.toFirstUpper»«ENDIF»'''
        var String minLimit = null
        var String maxLimit = null
        if (e.length <= 0) {
            // unbounded type: specify min/max if unsigned, as Java has no unsigned numbers
            if (signed)
                return inElement.typeWrap(finalName)
            else
                maxLimit = '''<xs:maxInclusive value="«unsignedLimit»"/>'''
        } else {
            // define upper and lower symmetric limits
            val limit = Strings.repeat("9", e.length)
            minLimit = '''<xs:minInclusive value="-«limit»"/>'''
            maxLimit = '''<xs:maxInclusive value="«limit»"/>'''
        }
        return inElement.wrap('''
            <xs:restriction base="«finalName»">
                «minLimit»
                «maxLimit»
            </xs:restriction>
        ''')
    }
    
    def public defString(ElementaryDataType e, boolean trim, String pattern, boolean inElement) {
        return inElement.wrap('''
            <xs:restriction base="xs:«IF trim»normalizedString«ELSE»string«ENDIF»">
                «IF e.minLength > 0»<xs:minLength value="«e.minLength»"/>«ENDIF»
                <xs:maxLength value="«e.length»"/>
                «IF pattern !== null»<xs:pattern value="«pattern»"/>«ENDIF»
            </xs:restriction>
        ''')
    }

    def private defBinary(ElementaryDataType e, boolean inElement) {
        if (e.length <= 0 || e.length == Integer.MAX_VALUE)
            return inElement.typeWrap("xs:base64Binary")   // unbounded
        else
            return inElement.wrap('''
                <xs:restriction base="xs:base64Binary»">
                    <xs:maxLength value="«e.length»"/>
                </xs:restriction>
            ''')
    }

    // method is called with inElement = false for type defs and with inElement = true for fields of complex types
    def public CharSequence describeField(PackageDefinition pkg, DataType dt, boolean inElement) {
        if (dt.referenceDataType !== null) {
            val typeDef = dt.referenceDataType
            return inElement.typeWrap(typeDef.name.xsdQualifiedName(typeDef.package))
        }
        // no type definition, embedded tpe is used
        val ref = dt.rootDataType
        if (ref.elementaryDataType !== null) {
            val e = ref.elementaryDataType
            switch (e.name.toLowerCase) {
                case 'float':       return inElement.typeWrap("xs:float")
                case 'double':      return inElement.typeWrap("xs:double")
                case 'decimal':
                    return inElement.wrap('''
                        <xs:restriction base="xs:decimal">
                            <xs:totalDigits value="«e.length»"/>
                            <xs:fractionDigits value="«e.decimals»"/>
                            «IF !ref.effectiveSigned» <xs:minInclusive value="0"/>«ENDIF»
                        </xs:restriction>
                    ''')
                case 'number':
                    return inElement.wrap('''
                        <xs:restriction base="xs:decimal">
                            <xs:totalDigits value="«e.length»"/>
                            «IF !ref.effectiveSigned» <xs:minInclusive value="0"/>«ENDIF»
                        </xs:restriction>
                    ''')
                case 'integer':     return e.defIntegral(ref.effectiveSigned, "int",   Integer.MAX_VALUE.toString, inElement)
                case 'int':         return e.defIntegral(ref.effectiveSigned, "int",   Integer.MAX_VALUE.toString, inElement)
                case 'long':        return e.defIntegral(ref.effectiveSigned, "long",  Long.MAX_VALUE.toString, inElement)
                case 'byte':        return e.defIntegral(ref.effectiveSigned, "byte",  "127", inElement)
                case 'short':       return e.defIntegral(ref.effectiveSigned, "short", "32767", inElement)
                case 'unicode':     return e.defString(ref.effectiveTrim, null, inElement)
                case 'uppercase':   return e.defString(ref.effectiveTrim, "([A-Z])*", inElement)
                case 'lowercase':   return e.defString(ref.effectiveTrim, "([a-z])*", inElement)
                case 'ascii':       return e.defString(ref.effectiveTrim, "\\p{IsBasicLatin}*", inElement)
                case 'object':      return inElement.typeWrap("xs:anyType")
                // temporal types
                case 'day':         return inElement.typeWrap("xs:date")
                case 'time':        return inElement.typeWrap("xs:time")
                case 'timestamp':   return inElement.typeWrap("xs:dateTime")
                case 'instant':     return inElement.typeWrap("xs:unsignedLong")
                // misc
                case 'boolean':     return inElement.typeWrap("xs:boolean")
                case 'character':   return inElement.typeWrap("bon:CHAR")
                case 'char':        return inElement.typeWrap("bon:CHAR")
                case 'uuid':        return inElement.typeWrap("bon:UUID")
                case 'raw':         return e.defBinary(inElement)
                case 'binary':      return e.defBinary(inElement)
                // enum stuff
                case 'enum':        return inElement.typeWrap(e.enumType.name.xsdQualifiedName(e.enumType.package))
                case 'xenum':       return inElement.typeWrap(e.xenumType.name.xsdQualifiedName(e.xenumType.package))
                case 'enumset':     return inElement.typeWrap(e.enumsetType.name.xsdQualifiedName(e.enumsetType.package))
                case 'xenumset':    return inElement.typeWrap(e.xenumsetType.name.xsdQualifiedName(e.xenumsetType.package))
            }
        } else if (ref.objectDataType !== null) {
            // check for explicit reference (no subtypes)
            return inElement.typeWrap(ref.objectDataType.xsdQualifiedName(pkg))
        } else {
            // plain object (i.e. any bonaportable)
            return inElement.typeWrap("xs:anyType")
        }
    }

    def public listDeclaredFields(ClassDefinition cls, PackageDefinition pkg) {
        return '''
            <xs:sequence>
                «FOR f: cls.fields»
                    <xs:element name="«f.name»"«f.obtainOccurs»«describeField(pkg, f.datatype, true)»
                «ENDFOR»
                <!-- <xs:any minOccurs="0" processContents="skip"/> declare that future releases may add new (optional) fields -->
            </xs:sequence>
        '''
    }   
     
    /** Creates all complexType definitions for the package. */
    def public createObjects(PackageDefinition pkg) {
        return '''
            «FOR cls: pkg.classes»
                <xs:complexType name="«cls.name»"«IF cls.abstract» abstract="true"«ENDIF»«if (cls.final) ' block="#all" final="#all"'»«cls.printSubstGroup»>
                    «IF cls.extendsClass?.classRef !== null»
                        <xs:complexContent>
                            <xs:extension base="«cls.extendsClass?.classRef.xsdQualifiedName(pkg)»">
                                «cls.listDeclaredFields(pkg)»
                            </xs:extension>
                        </xs:complexContent>
                    «ELSE»
                        «cls.listDeclaredFields(pkg)»
                    «ENDIF»
                </xs:complexType>
            «ENDFOR»
        '''
    }
    
    def public xsdQualifiedName(String name, PackageDefinition referencedPkg) {
//        if (myPkg === referencedPkg)
//            return name
//        else
            return '''«referencedPkg.schemaToken»:«name»''' 
    }
    
    /** Prints a qualified name with an optional namespace prefix. */
    def public xsdQualifiedName(ClassDefinition cls, PackageDefinition ref) {
        return '''«cls.package.schemaToken»:«cls.name»''' 
    }
    
    /** Inserts code to refer to a substitution group. */
    def public printSubstGroup(ClassDefinition cls) {
        if (cls.extendsClass?.classRef !== null) {
            return ''' substitutionGroup="«cls.extendsClass?.classRef.xsdQualifiedName(cls.package)»"'''
        }
    }
    
    /** Creates all the top level element definitions. Each element corresponds to a class.
     * TODO: clarify if only required for the xmlRoot elements.
     */
    def public createTopLevelElements(PackageDefinition pkg) {
        return '''
            «FOR cls: pkg.classes»
                <xs:element name="«cls.name»" type="«pkg.schemaToken»:«cls.name»"«IF cls.abstract» abstract="true"«ENDIF»«cls.printSubstGroup»/>
            «ENDFOR»
        '''
    }
    
    /** Top level entry point to create the XSD file for a whole package. */
    def private writeXsdFile(PackageDefinition pkg) {
        requiredImports.clear()     // clear hash for this new package output
        pkg.collectXmlImports
        requiredImports.remove(pkg) // no include for myself
//                «pkg.createTopLevelElements»
        
        return '''
            <?xml version="1.0" encoding="UTF-8"?>
            <xs:schema targetNamespace="«pkg.effectiveXmlNs»"
              xmlns:xs="http://www.w3.org/2001/XMLSchema"
              xmlns:bon="http://www.jpaw.de/schema/bonaparte.xsd"
              xmlns:«pkg.schemaToken»="«pkg.effectiveXmlNs»"
              «FOR imp: requiredImports»
                xmlns:«imp.schemaToken»="«imp.effectiveXmlNs»"
              «ENDFOR»
              elementFormDefault="qualified">

                <xs:import namespace="http://www.jpaw.de/schema/bonaparte.xsd" schemaLocation="bonaparte/bonaparte.xsd"/>
                «FOR imp: requiredImports»
                    <xs:import namespace="«imp.effectiveXmlNs»" schemaLocation="«imp.computeXsdFilename»"/>
                «ENDFOR»
                «pkg.createEnumTypes»
                «pkg.createXEnumTypes»
                «pkg.createEnumsetTypes»
                «pkg.createXEnumsetTypes»
                «pkg.createTypeDefs»
                «pkg.createObjects»
            </xs:schema>
        '''           
    }
}
