package de.jpaw.bonaparte.dts.dsl.generator

import de.jpaw.bonaparte.dsl.generator.DataTypeExtension
import de.jpaw.bonaparte.dts.dsl.bDts.DTSPackageDefinition
import de.jpaw.bonaparte.dts.dsl.bDts.TsClassDefinition
import de.jpaw.bonaparte.dts.dsl.bDts.TsInterfaceDefinition

class ZUtil {

    def public static getInheritanceRoot(TsClassDefinition e) {
        var TsClassDefinition ee = e
        while (ee.^extends !== null)
            ee = ee.^extends
        return ee
    }

    def public static getDtsPackage(TsClassDefinition d) {
        return d.eContainer as DTSPackageDefinition
    }
    def public static getDtsPackage(TsInterfaceDefinition i) {
        return i.eContainer as DTSPackageDefinition
    }
    def public static getPqon(TsClassDefinition d) {
        return d.dtsPackage.name + "." + d.name
    }
    def public static getPqon(TsInterfaceDefinition i) {
        return i.dtsPackage.name + "." + i.name
    }

    // reference is the package prefix of the reference element, we know it ends with "."
    def public static String asRelativePathTo(String what, String reference) {
        // a common prefix of both strings can be skipped, if that prefix ends with a dot or equals the full reference
        if (what.startsWith(reference))
            return what.substring(reference.length)  // full match of prefix
        // check if we can reduce it by at least one component
        var int firstDot = reference.indexOf(".")
        if (firstDot >= 0)
            return what.substring(firstDot + 1).asRelativePathTo(reference.substring(firstDot + 1))
        // reduction was not possible, pathnames differ at first component, prepend as many relative steps back as required
        val p = new StringBuilder
        do {
            p.append("../")
            firstDot = reference.indexOf(".", firstDot + 1)
        } while (firstDot >= 0)
        return p.toString + what;
    }

    def public static String jsType(DataTypeExtension ref) {
        if (ref.objectDataType !== null)
            return ref.objectDataType.name
        if (ref.elementaryDataType === null)
            return "null"
        // val e = ref.elementaryDataType
        val javaType = ref.javaType.toLowerCase

        switch (ref.category) {
            case BASICNUMERIC:  return "number"
            case BINARY:        return "string"     // base64 encoded?
            case ENUM:          return "number"     // ordinal
            case ENUMALPHA:     return "string"     // token
            case ENUMSET:       return "number"     // bitmap
            case ENUMSETALPHA:  return "string"     // string of tokens
            case MISC:          {
                                    if (javaType == "boolean")
                                        return "boolean"
                                    if (javaType == "uuid" || javaType == "char" || javaType == "character")
                                        return "string"
                                    return "null"  // unknown...
                                }
            case NUMERIC:       return "number"     // number
            case OBJECT:        {
                                    if (javaType == "element")
                                        return "any"
                                    if (javaType == "array")
                                        return "any[]"
                                    return "object"  // JSON, BonaPortable
                                }
            case STRING:        return "string"
            case TEMPORAL:      {
                                    if (javaType == "instant")
                                        return "number"
                                    else
                                        return "string"
                                }
            case XENUM:         return "string"     // token
            case XENUMSET:      return "string"     // string of tokens
        }
    }
}
