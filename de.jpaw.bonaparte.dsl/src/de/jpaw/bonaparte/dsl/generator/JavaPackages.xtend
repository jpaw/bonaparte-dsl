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
import org.eclipse.emf.ecore.EObject

class JavaPackages {
    // TODO: should we make this configurable per generator run?
    public static final String bonaparteClassDefaultPackagePrefix = "de.jpaw.bonaparte.pojos"

    def public static getPackageName(PackageDefinition p) {
        (if (p.prefix == null) bonaparteClassDefaultPackagePrefix else p.prefix) + "." + p.name  
    }
    
    def public static getPackage(EObject ee) {
        var e = ee
        while (e != null) {
            if (e instanceof PackageDefinition)
                return e as PackageDefinition
            e = e.eContainer
        }
        return null
    }
    
    // create the package name for a class definition object
    def public static getPackageName(ClassDefinition d) {
        getPackageName(getPackage(d))
    }
    def public static getPackageName(EnumDefinition d) {
        getPackageName(getPackage(d))
    }
    
    // generate a fully qualified or (optically nicer) simple class name, depending on whether target is in same package as the current class
    // TODO: do this in dependence of the import list 
    def public static xxxxxpossiblyFQClassName(ClassDefinition current, ClassDefinition target) {
        if (getPackageName(current) == getPackageName(target))
            target.name
        else
            getPackageName(target) + "." +target.name
    }
    
}