 /*
  * Copyright 2016 Michael Bischoff
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

class Jaxb {
    // called only if XML is enabled
    def static writeDefaultAdapter(ClassDefinition d) {
        return '''
            public static class DefaultXmlAdapter extends XmlAdapter<«d.name», «d.name»> {
                public static XmlAdapter<? extends «d.name», «d.name»> effectiveAdapter = null;  // allow to overwrite by own implementation
                
                @Override
                public «d.name» marshal(«d.name» param) throws Exception {
                    return effectiveAdapter == null ? param : effectiveAdapter.marshal(param);
                }
                @Override
                public «d.name» unmarshal(«d.name» param) throws Exception {
                    return effectiveAdapter == null ? param : ((XmlAdapter<«d.name», «d.name»>)effectiveAdapter).unmarshal(param);
                }
            }
        '''
    }
}
