package de.jpaw.bonaparte.dsl.generator.java

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition

class JavaDeexternalize {
    private static String interfaceDowncast = ""; // don't need it any more: "(Class <? extends BonaPortable>)"  // objects implementing BonaPortableWithMeta

/* unused now. Solved through different parser.
    def private static makeRead(ElementaryDataType i, DataTypeExtension ref) {
        switch i.name.toLowerCase {
        // numeric (non-float) types
        case 'byte':      '''ExternalizableParser.readByte      (_in, «ref.wasUpperCase», «ref.effectiveSigned»)'''
        case 'short':     '''ExternalizableParser.readShort     (_in, «ref.wasUpperCase», «ref.effectiveSigned»)'''
        case 'long':      '''ExternalizableParser.readLong      (_in, «ref.wasUpperCase», «ref.effectiveSigned»)'''
        case 'int':       '''ExternalizableParser.readInteger   (_in, «ref.wasUpperCase», «ref.effectiveSigned»)'''
        case 'integer':   '''ExternalizableParser.readInteger   (_in, «ref.wasUpperCase», «ref.effectiveSigned»)'''
        case 'number':    '''ExternalizableParser.readNumber    (_in, «ref.wasUpperCase», «i.length», «ref.effectiveSigned»)'''
        case 'decimal':   '''ExternalizableParser.readBigDecimal(_in, «ref.wasUpperCase», «i.length», «i.decimals», «ref.effectiveSigned»)'''
        // float/double, char and boolean    
        case 'float':     '''ExternalizableParser.readFloat     (_in, «ref.wasUpperCase», «ref.effectiveSigned»)'''
        case 'double':    '''ExternalizableParser.readDouble    (_in, «ref.wasUpperCase», «ref.effectiveSigned»)'''
        case 'boolean':   '''ExternalizableParser.readBoolean   (_in, «ref.wasUpperCase»)'''
        case 'char':      '''ExternalizableParser.readCharacter (_in, «ref.wasUpperCase»)'''
        case 'character': '''ExternalizableParser.readCharacter (_in, «ref.wasUpperCase»)'''
        // text
        case 'uppercase': '''ExternalizableParser.readString    (_in, «ref.wasUpperCase», «i.length», «ref.effectiveTrim», «ref.effectiveTruncate», false, false)'''
        case 'lowercase': '''ExternalizableParser.readString    (_in, «ref.wasUpperCase», «i.length», «ref.effectiveTrim», «ref.effectiveTruncate», false, false)'''
        case 'ascii':     '''ExternalizableParser.readString    (_in, «ref.wasUpperCase», «i.length», «ref.effectiveTrim», «ref.effectiveTruncate», false, false)'''
        case 'unicode':   '''ExternalizableParser.readString    (_in, «ref.wasUpperCase», «i.length», «ref.effectiveTrim», «ref.effectiveTruncate», «ref.effectiveAllowCtrls», true)'''
        // special          
        case 'uuid':      '''ExternalizableParser.readUUID      (_in, «ref.wasUpperCase»)'''
        case 'binary':    '''ExternalizableParser.readByteArray (_in, «ref.wasUpperCase», «i.doHHMMSS», «i.length»)'''
        case 'raw':       '''ExternalizableParser.readRaw       (_in, «ref.wasUpperCase», «i.doHHMMSS», «i.length»)'''
        case 'calendar':  '''ExternalizableParser.readGregorianCalendar(_in, «ref.wasUpperCase», «i.length»)'''
        case 'timestamp': if (Util::useJoda())
                             '''ExternalizableParser.readDayTime(_in, «ref.wasUpperCase», «i.length»)'''
                          else
                             '''ExternalizableParser.readGregorianCalendar(_in, «ref.wasUpperCase», «i.length»)'''
        case 'day':       if (Util::useJoda())
                             '''ExternalizableParser.readDay(_in, «ref.wasUpperCase»)'''
                          else
                             '''ExternalizableParser.readGregorianCalendar(_in, «ref.wasUpperCase», -1)'''
        // enum
        case 'enum':      '''«getPackageName(i.enumType)».«i.enumType.name».«IF (ref.enumMaxTokenLength >= 0)»factory(ExternalizableParser.readString(_in, «ref.wasUpperCase», «ref.enumMaxTokenLength», true, false, false, true))«ELSE»valueOf(ExternalizableParser.readInteger(_in, «ref.wasUpperCase», false))«ENDIF»'''
        case 'object':    '''ExternalizableParser.readObject(_in, BonaPortable.class, «ref.wasUpperCase», true)'''
        }
    }

    def private static makeRead2(ClassDefinition d, FieldDefinition i, String end) '''
        «IF resolveElem(i.datatype) != null»
            «makeRead(resolveElem(i.datatype), DataTypeExtension::get(i.datatype))»«end»
        «ELSE»
            («DataTypeExtension::get(i.datatype).javaType»)ExternalizableParser.readObject(_in, «interfaceDowncast»«DataTypeExtension::get(i.datatype).javaType».class, «b2A(!i.isRequired)», «b2A(i.datatype.orSuperClass)»)«end»
        «ENDIF»
    '''
   */
     
    def public static writeDeexternalizeOld(ClassDefinition d) '''
        @Override
        public void readExternal(ObjectInput _in) throws IOException,
                ClassNotFoundException {
            «IF d.extendsClass != null»
                // recursive call of superclass first
                super.readExternal(_in);
            «ENDIF»

        }
    '''    
    
    def public static writeDeexternalize(ClassDefinition d) '''
        @Override
        public void readExternal(ObjectInput _in) throws IOException,
                ClassNotFoundException {
            deserialize(new ExternalizableParser(_in));
        }
    '''    
}