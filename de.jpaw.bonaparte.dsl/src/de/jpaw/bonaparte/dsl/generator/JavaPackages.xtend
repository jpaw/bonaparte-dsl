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
  
package de.jpaw.bonaparte.dsl.generator

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.EnumDefinition
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition

class JavaPackages {
    // TODO: should we make this configurable per generator run?
    public static String bonaparteClassDefaultPackagePrefix = "de.jpaw.bonaparte.pojos"
    
    // create the package name for a class definition object
    def public static getPackageName(ClassDefinition d) {
        val PackageDefinition pkg = d.eContainer as PackageDefinition
        (if (pkg.prefix == null) bonaparteClassDefaultPackagePrefix else pkg.prefix) + "." + pkg.name  
    }
    def public static getPackageName(EnumDefinition d) {
        val PackageDefinition pkg = d.eContainer as PackageDefinition
        (if (pkg.prefix == null) bonaparteClassDefaultPackagePrefix else pkg.prefix) + "." + pkg.name  
    }
    
    // generate a fully qualified or (optically nicer) simple class name, depending on whether target is in same package as the current class 
    def public static possiblyFQClassName(ClassDefinition current, ClassDefinition target) {
        if (getPackageName(current) == getPackageName(target))
            target.name
        else
            getPackageName(target) + "." +target.name
    }
    
}