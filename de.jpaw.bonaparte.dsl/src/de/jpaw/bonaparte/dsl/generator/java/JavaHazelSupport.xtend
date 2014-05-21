 /*
  * Copyright 2014 Michael Bischoff
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
import de.jpaw.bonaparte.dsl.bonScript.XHazelcast
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*

class JavaHazelSupport {
    static public final String BONAPARTE_HAZEL_PACKAGE = "de.jpaw.bonaparte.hazelcast"
    static public final String HAZELCAST_NIO_PACKAGE = "com.hazelcast.nio"
    static public final String HAZELCAST_INT_PACKAGE = "com.hazelcast.nio.serialization"

    // if called, we know that doHazel is not NOHAZEL. For imports, just distinguish between classes / interfaces available in hazelcast 2 and 3
    def public static writeHazelImports(XHazelcast doHazel) '''
        import java.io.IOException;
        import «HAZELCAST_NIO_PACKAGE».ObjectDataInput;
        import «HAZELCAST_NIO_PACKAGE».ObjectDataOutput;
        import «HAZELCAST_INT_PACKAGE».DataSerializable;
        import «BONAPARTE_HAZEL_PACKAGE».HazelcastParser;
        import «BONAPARTE_HAZEL_PACKAGE».HazelcastComposer;
        «IF doHazel != XHazelcast.DATA_SERIALIZABLE»
            import «HAZELCAST_INT_PACKAGE».IdentifiedDataSerializable;
            import «HAZELCAST_INT_PACKAGE».Portable;
            import «HAZELCAST_INT_PACKAGE».PortableReader;
            import «HAZELCAST_INT_PACKAGE».PortableWriter;
        «ENDIF»
    '''
    
    def private static writeHazelIds(ClassDefinition d) '''
        @Override
        public int getFactoryId() { 
            return «d.effectiveFactoryId»;
        }
        @Override
        public int getId() {
            «IF d.hazelcastId == 0»
                return MY_RTTI;        // reuse of the rtti
            «ELSE»
                return «d.hazelcastId»
            «ENDIF»
        }
    '''
    
    def private static writeDataSerializable(ClassDefinition d, boolean recommendIdentifiable) '''
        @Override
        public void writeData(ObjectDataOutput _out) throws IOException { 
            HazelcastComposer.serialize(this, _out, «recommendIdentifiable»);
        }
        @Override
        public void readData(ObjectDataInput _in) throws IOException {
            HazelcastParser.deserialize(this, _in);
        }
    '''
    
    def private static writePortable(ClassDefinition d) '''
        @Override
        public void writePortable(PortableWriter _out) throws IOException { 
            HazelcastPortableComposer.serialize(this, _out);
        }
        @Override
        public void readPortable(PortableReader _in) throws IOException {
            HazelcastPortableParser.deserialize(this, _in);
        }
    '''
    
    def public static writeHazelIO(ClassDefinition d, XHazelcast doHazel) {
        switch (doHazel) {
            case NOHAZEL:
            	null
            case DATA_SERIALIZABLE:
                d.writeDataSerializable(false)
            case IDENTIFIED_DATA_SERIALIZABLE: {
                d.writeDataSerializable(true)
                d.writeHazelIds
            }
            case PORTABLE: {
				d.writePortable           	
                d.writeHazelIds
            }
            case BOTH: {					// does not make sense? 
                d.writeDataSerializable(true)
				d.writePortable           	
                d.writeHazelIds
            }
        }
    }
}
