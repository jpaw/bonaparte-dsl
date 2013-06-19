package de.jpaw.bonaparte.dsl.generator.java

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition

class JavaDeexternalize {

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
