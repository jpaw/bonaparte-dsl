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

import com.google.inject.Inject
import de.jpaw.bonaparte.dsl.BonScriptPreferences
import de.jpaw.bonaparte.dsl.BonScriptTraceExtensions
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.EnumDefinition
import de.jpaw.bonaparte.dsl.bonScript.EnumSetDefinition
import de.jpaw.bonaparte.dsl.bonScript.InterfaceListDefinition
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition
import de.jpaw.bonaparte.dsl.bonScript.XBeanValidation
import de.jpaw.bonaparte.dsl.bonScript.XEnumDefinition
import de.jpaw.bonaparte.dsl.bonScript.XEnumSetDefinition
import de.jpaw.bonaparte.dsl.bonScript.XExternalizable
import de.jpaw.bonaparte.dsl.bonScript.XHazelcast
import de.jpaw.bonaparte.dsl.bonScript.XXmlAccess
import de.jpaw.bonaparte.dsl.bonScript.XXmlFormDefault
import java.util.ArrayList
import java.util.HashMap
import java.util.List
import java.util.Map
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.AbstractGenerator
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import static extension de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*

// generator for the language Java
class JavaBonScriptGeneratorMain extends AbstractGenerator {
    static private boolean AUTO_XML_ADAPTER_FOR_ABSTRACT_EMPTY_CLASSES = false
//    @TracedAccessors(BonScriptFactory)
//    static class BonScriptTraceExtensions {}

    @Inject extension BonScriptTraceExtensions

    var Map<String, String> requiredImports = new HashMap<String, String>()

    // create the filename to store a generated java class source in. Assumes subdirectory ./java
    def private static getJavaFilename(String pkg, String name) {
        return "java/" + pkg.replaceAll("\\.", "/") + "/" + name + ".java"
    }
    // create the filename to store the JAXB index in
    def private static getJaxbResourceFilename(String pkg) {
        return "resources/" + pkg.replaceAll("\\.", "/") + "/jaxb.index"
    }

    def private static writeAttributeFormDefault(XXmlFormDefault xmlAttributeFormDefault) {
        if (xmlAttributeFormDefault !== null)
            return ''', attributeFormDefault = XmlNsForm.«xmlAttributeFormDefault»'''
    }
    def private static writeXmlNs(PackageDefinition d, XXmlFormDefault xmlElementFormDefault) {
        if (!(XXmlFormDefault.UNQUALIFIED == xmlElementFormDefault && "" == d.xmlNsPrefix))
            return ''', xmlns = { @XmlNs(prefix="«d.xmlNsPrefix ?: d.schemaToken»", namespaceURI="«d.effectiveXmlNs»") }'''
    }
    

    override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext unused) {
        val needJoda = !BonScriptPreferences.currentPrefs.doDateTime
        requiredImports.clear()  // clear hash for this new class output
        for (d : resource.allContents.toIterable.filter(typeof(EnumSetDefinition)))
            fsa.generateTracedFile(getJavaFilename(getBonPackageName(d), d.name), d, xRef[JavaEnumSet::writeEnumSetDefinition(d)]);
        for (d : resource.allContents.toIterable.filter(typeof(XEnumSetDefinition)))
            fsa.generateTracedFile(getJavaFilename(getBonPackageName(d), d.name), d, xRef[JavaXEnumSet::writeXEnumSetDefinition(d)]);
        for (d : resource.allContents.toIterable.filter(typeof(EnumDefinition)))
            fsa.generateTracedFile(getJavaFilename(getBonPackageName(d), d.name), d, xRef[JavaEnum::writeEnumDefinition(d)]);
        for (d : resource.allContents.toIterable.filter(typeof(XEnumDefinition))) {
            fsa.generateTracedFile(getJavaFilename(getBonPackageName(d), d.name), d, xRef[JavaXEnum::writeXEnumDefinition(d)]);
            if (d.getRelevantXmlAccess !== null && !d.abstract && d.extendsXenum === null) {
                print('''output of xml adapter for «d.name»''')
                fsa.generateTracedFile(getJavaFilename(getBonPackageName(d), d.name + "XmlAdapter"), d, xRef[JavaXEnum::writeXEnumTypeAdapter(d)]);
            }
        }
        for (d : resource.allContents.toIterable.filter(typeof(ClassDefinition)).filter[!noJava])
            fsa.generateTracedFile(getJavaFilename(getBonPackageName(d), d.name), d, xRef[d.writeClassDefinition]);
        for (d : resource.allContents.toIterable.filter(typeof(PackageDefinition))) {
            // get a list of all classes which have an XML tag
            var List<ClassDefinition> classList = new ArrayList<ClassDefinition>()
            for (cl : d.classes)
                if (!cl.isAbstract && cl.getRelevantXmlAccess !== null)
                    classList.add(cl)
            var List<XEnumDefinition> xenumList = new ArrayList<XEnumDefinition>()
            for (xl : d.xenums)
                if (!xl.isAbstract && xl.getRelevantXmlAccess !== null)
                    xenumList.add(xl)
            if (classList.size > 0 || xenumList.size > 0)
                fsa.generateFile(getJaxbResourceFilename(getBonPackageName(d)), '''
                «FOR cl : classList»
                    «cl.name»
                «ENDFOR»
                «FOR xl : xenumList»
                    «xl.name»
                «ENDFOR»
                ''')

            // also, write a package-info.java file, if javadoc on package level exists or if XML bindings are used
            if (d.javadoc !== null || !(d.xmlAccess?.x == XXmlAccess::NONE || d.xmlAccess?.x == XXmlAccess::NOXML)) {
                val xmlElementFormDefault = d.xmlElementFormDefault?.x ?: XXmlFormDefault.QUALIFIED  // no null possible, due to backwards compatibility unspecified means QUALIFIED
                val xmlAttributeFormDefault = d.xmlAttributeFormDefault?.x
                fsa.generateFile(getJavaFilename(getBonPackageName(d), "package-info"), '''
                    // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
                    // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
                    // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git

                    «IF d.xmlAccess !== null && !BonScriptPreferences.getNoXML»
                    @XmlSchema(namespace = "«d.effectiveXmlNs»", elementFormDefault = XmlNsForm.«xmlElementFormDefault»«writeAttributeFormDefault(xmlAttributeFormDefault)»«d.writeXmlNs(xmlElementFormDefault)»)

                    @XmlJavaTypeAdapters({
                        «IF needJoda»
                            @XmlJavaTypeAdapter(type=LocalDate.class,       value=LocalDateAdapter.class),
                            @XmlJavaTypeAdapter(type=LocalTime.class,       value=LocalTimeAdapter.class),
                            @XmlJavaTypeAdapter(type=LocalDateTime.class,   value=LocalDateTimeAdapter.class),
                            @XmlJavaTypeAdapter(type=Instant.class,         value=InstantAdapter.class),
                        «ENDIF»
                        @XmlJavaTypeAdapter(type=ByteArray.class,       value=ByteArrayAdapter.class)
                    })
                    «ENDIF»
                    «d.javadoc»
                    package «getBonPackageName(d)»;
                    «IF d.xmlAccess !== null && !BonScriptPreferences.getNoXML»

                        import javax.xml.bind.annotation.XmlSchema;
                        import javax.xml.bind.annotation.XmlNs;
                        import javax.xml.bind.annotation.XmlNsForm;
                        import javax.xml.bind.annotation.adapters.XmlJavaTypeAdapter;
                        import javax.xml.bind.annotation.adapters.XmlJavaTypeAdapters;
                        import de.jpaw.util.ByteArray;
                        import de.jpaw.xml.jaxb.ByteArrayAdapter;
                        «IF needJoda»
                            import org.joda.time.LocalDate;
                            import org.joda.time.LocalDateTime;
                            import org.joda.time.LocalTime;
                            import org.joda.time.Instant;
                            import de.jpaw.xml.jaxb.InstantAdapter;
                            import de.jpaw.xml.jaxb.LocalDateAdapter;
                            import de.jpaw.xml.jaxb.LocalTimeAdapter;
                            import de.jpaw.xml.jaxb.LocalDateTimeAdapter;
                        «ENDIF»
                    «ENDIF»
                ''')
            }
        }
        requiredImports.clear()  // cleanup, we don't know how long this object will live
    }

    def private static writeRef(ClassDefinition d) '''
        «IF d.refPFunction !== null && d.refPFunction.trim.length != 0»
            @Override
            public long ret$RefP() {
                return «d.refPFunction»;
            }
            @Override
            public Long ret$RefW() {
                return Long.valueOf(ret$RefP());
            }
        «ELSEIF d.refWFunction !== null && d.refWFunction.trim.length != 0»
            @Override
            public Long ret$RefW() {
                return «d.refWFunction»;
            }
            @Override
            public long ret$RefP() {
                return ret$RefW().longValue();
            }
        «ENDIF»
        «IF d.keyPFunction !== null»
            public static «(d.recursePkClass ?: d).name» ret$Key(long ref) {
                return ref <= 0L ? null : «d.keyPFunction»;
            }
            public static «(d.recursePkClass ?: d).name» ret$Key(Long ref) {
                return ref == null ? null : ret$Key(ref.longValue());
            }
        «ELSEIF d.keyWFunction !== null»
            public static «(d.recursePkClass ?: d).name» ret$Key(Long ref) {
                return ref == null ? null : «d.keyWFunction»;
            }
            public static «(d.recursePkClass ?: d).name» ret$Key(long ref) {
                return ref <= 0L ? null : ret$Key(Long.valueOf(ref));
            }
        «ENDIF»
    '''

    // constract the interface name, which includes the ret$Ref variant
    def private static refExtension(ClassDefinition d)
        '''BonaPortable«IF d.refPFunction !== null || d.refWFunction !== null»Ref«ENDIF»'''

/* currently unused
            «JavaMethods::writeMethods(d)»
    def private recurseMethods(ClassDefinition d, boolean isRoot) {
        for (m : d.methods)
            if (m.returnObj !== null)
                addImport(getBonPackageName(m.returnObj), m.returnObj.name)
        if (!isRoot || (isRoot && !d.isAbstract)) // if we are not root, descend all way through. Otherwise, descend if not abstract
            if (d.extendsClass !== null)
                recurseMethods(d.extendsClass, false)
    }  */

    // decision classes for the package level settings
    def private static getExternalizable(ClassDefinition d) {
        val XExternalizable t = d.isExternalizable?.x ?: getPackage(d).isExternalizable?.x ?: BonScriptPreferences.getExternalizable
        return t !== null && t != XExternalizable::NOEXT
    }
    // decision classes for the package level settings
    def private static getHazelSupport(ClassDefinition d) {
        return d.doHazelcast?.x ?: getPackage(d).doHazelcast?.x ?: BonScriptPreferences.getHazelSupport
    }
    def private static getBeanValidation(ClassDefinition d) {
        var XBeanValidation t = d.doBeanValidation?.x ?: getPackage(d).doBeanValidation?.x ?: XBeanValidation::NOBEAN_VAL  // default to creation of no bean validation annotations
        return t !== null && t != XBeanValidation::NOBEAN_VAL
    }

    def private static interfaceOut(InterfaceListDefinition l) {
        '''«IF l !== null»«FOR i : l.ilist», «i.qualifiedName»«ENDFOR»«ENDIF»'''
    }

    def private void checkOrderedByList(ClassDefinition d) {

    }

    def private static intComparable(ClassDefinition d) {
        if (d.orderedByList !== null)
            ''', Comparable<«d.name»>'''
    }
    def private static intHazel(XHazelcast doHazel) {
        switch (doHazel) {
            case NOHAZEL:
                null
            case DATA_SERIALIZABLE:
                ", DataSerializable"
            case IDENTIFIED_DATA_SERIALIZABLE:
                ", BonaparteIdentifiedDataSerializable"
            case PORTABLE:
                ", BonapartePortable"
            case BOTH:                  // does not make sense?
                ", BonapartePortable, BonaparteIdentifiedDataSerializable"
        }
    }

    def writeClassDefinition(ClassDefinition d) {
    // map to evaluate if we have conflicting class names and need FQCNs
    // key is the class name, data is the package name
    // using FQONs in case of conflict is not yet implemented
        val String myPackageName = getBonPackageName(d)
        val ImportCollector imports = new ImportCollector(myPackageName)
        imports.recurseImports(d, true)
        imports.addImport(d)  // add myself as well
        if (d.returnsClassRef !== null)
            imports.addImport(d.returnsClassRef)
        if (d.genericParameters !== null)
            for (gp : d.genericParameters)
                if (gp.^extends !== null)
                    imports.addImport(gp.^extends)
        // determine XML annotation support
        val XXmlAccess xmlAccess = getRelevantXmlAccess(d)
        val withXml = xmlAccess !== null && !BonScriptPreferences.getNoXML
        val autoXmlAdapter = AUTO_XML_ADAPTER_FOR_ABSTRACT_EMPTY_CLASSES && (d.fields.size == 0 && d.isAbstract && d.extendsClass === null)
        val writeXmlAdapter = withXml && (d.isXmlAdapter || autoXmlAdapter)
        val xmlNonAttributeFields = if (withXml) d.fields.filter[!properties.hasProperty(PROP_ATTRIBUTE)].toList

        // val xmlTransient = if (xmlAccess !== null && !BonScriptPreferences.getNoXML) "@XmlTransient"
        val doExt       = d.externalizable
        val doHazel     = d.hazelSupport
        val doBeanVal   = d.beanValidation
        val myKey       = d.recursePkClass
        imports.addImport(myKey)
        imports.addImport(d.pkClass)
        imports.addImport(d.trackingClass)
        val activeColumn = d.fields.filter[properties.hasProperty(PROP_ACTIVE)].head

        if (d.orderedByList !== null)
            d.checkOrderedByList()
    return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git
        package «getBonPackageName(d)»;

        «writeDefaultImports»
        «IF withXml»
            import javax.xml.bind.annotation.XmlAccessorType;
            import javax.xml.bind.annotation.XmlAccessType;
            import javax.xml.bind.annotation.XmlAttribute;
            import javax.xml.bind.annotation.XmlRootElement;
            import javax.xml.bind.annotation.XmlElement;
            import javax.xml.bind.annotation.XmlTransient;
            import javax.xml.bind.annotation.XmlAnyElement;
            import javax.xml.bind.annotation.XmlSchemaType;
            import javax.xml.bind.annotation.adapters.XmlJavaTypeAdapter;
            import javax.xml.bind.annotation.adapters.XmlAdapter;
            import javax.xml.bind.annotation.XmlType;
        «ENDIF»
        «JavaBeanValidation::writeImports(doBeanVal)»
        «IF doExt»
            «JavaExternalize::writeExternalizeImports»
        «ENDIF»
        «IF doHazel != XHazelcast.NOHAZEL»
            «JavaHazelSupport::writeHazelImports(doHazel)»
        «ENDIF»
        import com.google.common.collect.ImmutableList;
        import com.google.common.collect.ImmutableSet;
        import com.google.common.collect.ImmutableMap;
        «IF myKey !== null»
            import de.jpaw.bonaparte.annotation.RelatedKey;
        «ENDIF»
        «IF d.refPFunction !== null || d.refWFunction !== null»
            import «bonaparteInterfacesPackage».BonaPortableRef;
        «ENDIF»
        import «bonaparteInterfacesPackage».BonaPortable;
        import «bonaparteInterfacesPackage».BonaPortableClass;
        import «bonaparteInterfacesPackage».MessageParser;
        import «bonaparteInterfacesPackage».MessageComposer;
        import «bonaparteInterfacesPackage».MessageParserException;
        import «bonaparteInterfacesPackage».ObjectValidationException;
        import «bonaparteInterfacesPackage».DataConverter;
        import «bonaparteInterfacesPackage».StaticMeta;
        import de.jpaw.bonaparte.annotation.*;
        import de.jpaw.bonaparte.util.DeprecationWarner;
        import «bonaparteClassDefaultPackagePrefix».meta.*;
        «imports.createImports»


        «IF d.javadoc !== null»
           «d.javadoc»
        «ENDIF»

        «IF withXml»
            «IF d.effectiveXmlRoot»
                @XmlRootElement(name="«d.name»")
            «ENDIF»
            @XmlAccessorType(XmlAccessType.«xmlAccess.toString»)
            «IF xmlNonAttributeFields.size > 1»
                @XmlType(name="«d.name»", propOrder={«xmlNonAttributeFields.map['''"«name»"'''].join(', ')»})
            «ELSE»
                @XmlType(name="«d.name»")
            «ENDIF»
            «IF writeXmlAdapter»
                @XmlJavaTypeAdapter(«d.name».DefaultXmlAdapter.class)
            «ENDIF»
        «ENDIF»
        «IF myKey !== null»
            @RelatedKey(«JavaPackages::getBonPackageName(myKey)».«myKey.name».class)
        «ENDIF»
        @SuppressWarnings("all")
        «IF d.isDeprecated || (d.eContainer as PackageDefinition).isDeprecated»
            @Deprecated
        «ENDIF»
        «IF d.isIsRefClass»
            @IsRefClass
        «ENDIF»
        «IF d.pkClass !== null»
            @KeyClass(«d.pkClass.name».class)
        «ENDIF»
        «IF d.trackingClass !== null»
            @TrackingClass(«d.trackingClass.name».class)
        «ENDIF»
        «d.properties.generateAllAnnotations»
        public«IF d.isFinal» final«ENDIF»«IF d.isAbstract» abstract«ENDIF» class «d.name»«genericDef2String(d.genericParameters)»«IF d.parent !== null» extends «d.parent.bonPackageName».«d.parent.name»«genericArgs2String(d.extendsClass.classRefGenericParms)»«ENDIF»
          implements «d.refExtension»«d.intComparable»«IF doExt», Externalizable«ENDIF»«intHazel(doHazel)»«interfaceOut(d.implementsInterfaceList)» {
            private static final long serialVersionUID = «getSerialUID(d)»L;

            «JavaRtti::writeRtti(d)»
            «JavaMeta::writeMetaData(d)»
            «JavaFrozen::writeFreezingCode(d)»
            «JavaFieldsGettersSetters::writeFields(d, doBeanVal)»
            «JavaFieldsGettersSetters::writeGettersSetters(d)»
            «JavaValidate::writePatterns(d)»
            «JavaSerialize::writeSerialize(d)»
            «JavaSerialize::writeFoldedSerialize(d)»
            «JavaDeserialize::writeDeserialize(d)»
            «JavaValidate::writeValidationCode(d)»
            «JavaCompare::writeHash(d)»
            «JavaCompare::writeComparisonCode(d)»
            «IF d.orderedByList !== null»
                «JavaCompare::writeComparable(d)»
            «ENDIF»
            «IF doExt»
                «JavaExternalize::writeExternalize(d)»
            «ENDIF»
            «JavaHazelSupport::writeHazelIO(d, doHazel)»
            «JavaTreeWalker::writeTreeWalkerCode(d)»
            «JavaConstructor::writeConstructorCode(d)»
            «IF writeXmlAdapter»
                «Jaxb::writeDefaultAdapter(d)»
            «ENDIF»

            «d.writeRef»

            @Override
            public String toString() {
                return ToStringHelper.toStringSL(this);
            }

            «IF activeColumn !== null»
                @Override
                public void put$Active(boolean _a) {
                    «activeColumn.name» = _a;
                }
                @Override
                public boolean ret$Active() {
                    return «activeColumn.name»;
                }
            «ELSEIF d.parent === null»
                @Override
                public void put$Active(boolean _a) throws ObjectValidationException {
                    // throw new ObjectValidationException(ObjectValidationException.NO_ACTIVE_FIELD, null, _PARTIALLY_QUALIFIED_CLASS_NAME);  // no exception, ignore this because it may be called in generic code
                }
                @Override
                public boolean ret$Active() {
                    return true;  // no active field in this class, returning default
                }
            «ENDIF»
        }
    '''
    }
    def JavaDeexternalize(ClassDefinition definition) { }

}
