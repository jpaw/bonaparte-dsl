package de.jpaw.bonaparte.dsl.generator

import de.jpaw.bonaparte.dsl.bonScript.DataType
import de.jpaw.bonaparte.dsl.bonScript.EnumDefinition

import static de.jpaw.bonaparte.dsl.generator.DataTypeExtension.*
import de.jpaw.bonaparte.dsl.bonScript.TypeDefinition
import de.jpaw.bonaparte.dsl.bonScript.ElementaryDataType
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition

class DataTypeExtensions2 {
	
	static def isEnum(DataType it) {
		referenceDataType instanceof EnumDefinition
	}
	
	static def getEnumDefinition(DataType it) {
		if (isEnum)
			referenceDataType as EnumDefinition
	}
	
	static def getEnumMaxTokenLength(DataType it) {
		if (isEnum) {
			// also count the max length if alphanumeric
            val ead = enumDefinition.avalues
                if (!ead.empty) {
                    return ead.filter[token != null].map[token.length].sort.last 
                }
                return ENUM_NUMERIC;
		} else {
			return NO_ENUM
		}
	}
	
	static def isAllTokensAscii(DataType it) {
		if (isEnum)
			!enumDefinition.avalues.exists[token != null && !Util.isAsciiString(token)]
		else 
			false
	}
	
	static def boolean pointsToElementaryDataType(DataType it) {
		return findElementaryDataType != null 
	}
	
	static def ElementaryDataType findElementaryDataType(DataType it) {
		if (elementaryDataType != null)
			return elementaryDataType;
		switch refType : referenceDataType {
			TypeDefinition : {
				return refType.datatype.findElementaryDataType()
			}
		}	
		return null 
	}
	
	static def getExtendedClassDefinition(ClassDefinition cl) {
		if (cl?.extendsClass?.referenceDataType instanceof ClassDefinition) {
			return cl.extendsClass.referenceDataType as ClassDefinition
		}
		return null
	}
}