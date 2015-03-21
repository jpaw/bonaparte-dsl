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
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*

class JavaRtti {

    def public static int getRttiRecursive(ClassDefinition d) {
        if (d === null)
            return 0
        else if (d.getParent === null)
            return d.rtti
        else if (d.addRtti)
            return d.rtti + d.getParent.rttiRecursive
        else if (d.rtti != 0)
            return d.rtti
        else
            return d.getParent.rttiRecursive
    }

    def public static writeRtti(ClassDefinition d) {
        return '''
            private static final int MY_RTTI = «d.rttiRecursive»;
            public static int class$rtti() {
                return MY_RTTI;
            }
            public int ret$rtti() {
                return MY_RTTI;
            }
        '''
    }
}
