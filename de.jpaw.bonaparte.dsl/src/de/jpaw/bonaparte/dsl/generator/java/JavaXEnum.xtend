 /*
  * Copyright 2012,2013 Michael Bischoff
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

import de.jpaw.bonaparte.dsl.bonScript.XEnumDefinition

import static de.jpaw.bonaparte.dsl.generator.java.JavaPackages.*
import de.jpaw.bonaparte.dsl.bonScript.EnumDefinition

class JavaXEnum {
    def static public int getOverallMaxLength(XEnumDefinition ed) {
        if (ed.maxlength > 0)
            return ed.maxlength
        else
            return getInternalMaxLength(ed.myEnum, if (ed.extendsXenum != null) getOverallMaxLength(ed.extendsXenum) else ed.maxlength) 
    }
    def static public int getInternalMaxLength(EnumDefinition ed, int priorMax) {
        var max = priorMax
        for (a : ed.avalues) {
            val l = a.token.length
            if (l > max) max = l
        }
        if (max <= 0)
            max = 1
        return max
    }
    
    def private static XEnumDefinition getRootXEnum(XEnumDefinition d) {
        if (d.extendsXenum == null)
            return d
        else
            return d.extendsXenum.getRootXEnum
    }
    
    // TODO: some time de.jpaw.util.EnumException should move to package de.jpaw.enums.EnumException
    def static public writeXEnumDefinition(XEnumDefinition d) {
        val boolean subClass = d.extendsXenum != null
        val rootClass = d.getRootXEnum
        
        return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git
        package «getPackageName(d)»;

        import de.jpaw.enums.XEnumFactory;
        «IF !subClass»
            import de.jpaw.enums.AbstractXEnumBase;
        «ENDIF»
        // import de.jpaw.util.EnumException;
        // import de.jpaw.enums.TokenizableEnum;
        // import de.jpaw.enums.XEnum;
        
        «IF getPackageName(d.myEnum) != getPackageName(d)»
            import «getPackageName(d.myEnum)».«d.myEnum.name»;
        «ENDIF»
        «IF subClass && getPackageName(d.extendsXenum) != getPackageName(d)»
            import «getPackageName(d.extendsXenum)».«d.extendsXenum.name»;
        «ENDIF»
        «IF subClass && rootClass != d.extendsXenum && getPackageName(rootClass) != getPackageName(d)»
            import «getPackageName(rootClass)».«rootClass.name»;
        «ENDIF»

        «IF d.javadoc != null»
            «d.javadoc»
        «ENDIF»
        «IF d.isDeprecated»
        @Deprecated
        «ENDIF»
        public«IF d.isFinal» final«ENDIF»«IF d.isAbstract» abstract«ENDIF» class «d.name» extends «IF !subClass»AbstractXEnumBase<«d.name»>«ELSE»«d.extendsXenum.name»«ENDIF» {
            public static final String PQON = "base.XAccountType1";
            public static final int NUM_VALUES_TOTAL = «IF subClass»«d.extendsXenum.name».NUM_VALUES_TOTAL + «ENDIF»«d.myEnum.name».values().length;
            «IF !subClass»
                public static final int MAX_TOKEN_LENGTH = «d.getOverallMaxLength»;
                // root class builds the factory
                public static final XEnumFactory<«d.name»> myFactory = new XEnumFactory<«d.name»>(MAX_TOKEN_LENGTH, «d.name».class, PQON);
            «ENDIF»

            static {
                // create all the instances
                «d.myEnum.name» [] values = «d.myEnum.name».values();
                for (int i = 0; i < values.length; ++i) {
                    «d.myEnum.name» e = values[i];
                    myFactory.publishInstance(new «d.name»(e, i«IF subClass» + «d.extendsXenum.name».NUM_VALUES_TOTAL«ENDIF», e.name(), e.getToken(), myFactory));
                }
                myFactory.register(PQON);
            }
            @Override
            public String getPqon() {
                return PQON;
            }
            
            // constructor may not be accessible from the outside
            protected «d.name»(Enum<?> enumVal, int ordinal, String name, String token, XEnumFactory<«rootClass.name»> myFactory) {
                super(enumVal, ordinal, name, token, myFactory);
            }
        }
        '''
    }
}