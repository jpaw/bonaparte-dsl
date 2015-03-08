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

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import static de.jpaw.bonaparte.dsl.generator.XUtil.*

class JavaExternalize {
    def public static writeExternalizeImports() '''
        import java.io.Externalizable;
        import java.io.IOException;
        import java.io.ObjectInput;
        import java.io.ObjectOutput;
        import «bonaparteInterfacesPackage».ExternalizableConstants;
        import «bonaparteInterfacesPackage».ExternalizableComposer;
        import «bonaparteInterfacesPackage».ExternalizableParser;
    '''

    def public static writeExternalize(ClassDefinition d) '''
        @Override
        public void writeExternal(ObjectOutput _out) throws IOException {
            ExternalizableComposer.serialize(this, _out);
        }
        @Override
        public void readExternal(ObjectInput _in) throws IOException, ClassNotFoundException {
            ExternalizableParser.deserialize(this, _in);
        }

    '''
}
