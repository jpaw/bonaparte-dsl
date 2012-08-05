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

import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension

class JavaCompare {
    
    // TODO: do float and double need special handling as well? (Double.compare(a, b) ?)
    def private static writeCompareStuff(FieldDefinition i, String index, String end) ''' 
        «IF resolveObj(i.datatype) != null»
            ((«index» == null && that.«index» == null) || «index».hasSameContentsAs(that.«index»))«end»
        «ELSE»
            «IF DataTypeExtension::get(i.datatype).isPrimitive»
                «index» == that.«index»«end»
            «ELSE»
                ((«index» == null && that.«index» == null) || «IF getJavaDataType(i.datatype).equals("byte []")»Arrays.equals(«index», that.«index»)«ELSE»«index».equals(that.«index»)«ENDIF»)«end»
            «ENDIF»
        «ENDIF»
    '''
    
    def public static writeComparisonCode(ClassDefinition d) '''
            // don't overwrite equals() due to the myriad of pitfalls as shown here: http://www.artima.com/lejava/articles/equality.html
            // we want a method to check for same contents
            @Override
            public boolean hasSameContentsAs(BonaPortable xthat) {
                if (xthat == null)
                    return false;
                if (!(xthat instanceof «d.name»))
                    return false;
                «d.name» that = («d.name»)xthat;
                «IF d.extendsClass != null»
                    return super.hasSameContentsAs(that)
                «ELSE»
                    return true
                «ENDIF»
                «FOR i:d.fields»
                    «IF i.isArray != null»
                        && ((«i.name» == null && that.«i.name» == null) || («i.name» != null && that.«i.name» != null && arrayCompareSub$«i.name»(that)))
                    «ELSE»
                        && «writeCompareStuff(i, i.name, "")»
                    «ENDIF»
                «ENDFOR»
                ;
            }            
            «FOR i:d.fields»
                «IF i.isArray != null»
                    private boolean arrayCompareSub$«i.name»(«d.name» that) {
                        // both «i.name» and that «i.name» are known to be not null
                        if («i.name».length != that.«i.name».length)
                            return false;
                        for (int i = 0; i < «i.name».length; ++i)
                            if (!(«writeCompareStuff(i, i.name + "[i]", "))")»
                                return false;
                        return true;
                    }
                «ENDIF»
            «ENDFOR»
    '''
}