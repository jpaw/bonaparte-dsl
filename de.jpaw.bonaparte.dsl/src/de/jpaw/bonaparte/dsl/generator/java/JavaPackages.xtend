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
import de.jpaw.bonaparte.dsl.bonScript.EnumDefinition

import static de.jpaw.bonaparte.dsl.generator.XUtil.*
import de.jpaw.bonaparte.dsl.bonScript.XEnumDefinition
import de.jpaw.bonaparte.dsl.bonScript.EnumSetDefinition
import de.jpaw.bonaparte.dsl.bonScript.XEnumSetDefinition
import org.eclipse.emf.ecore.EObject

class JavaPackages {
    // TODO: should we make this configurable per generator run?
    public static final String bonaparteClassDefaultPackagePrefix = "de.jpaw.bonaparte.pojos"

    // create the package name for EObjects
    def public static getBonPackageName(EObject pp) {
        val p = getPackage(pp)
        return (if (p.prefix === null) bonaparteClassDefaultPackagePrefix else p.prefix) + "." + p.name
    }

    // Utility methods
    def public static getPartiallyQualifiedClassName(ClassDefinition d) {
        getPackage(d).name + "." + d.name
    }
    def public static getPartiallyQualifiedClassName(EnumSetDefinition d) {
        getPackage(d).name + "." + d.name
    }
    def public static getPartiallyQualifiedClassName(EnumDefinition d) {
        getPackage(d).name + "." + d.name
    }
    def public static getPartiallyQualifiedClassName(XEnumDefinition d) {
        getPackage(d).name + "." + d.name
    }
    def public static getPartiallyQualifiedClassName(XEnumSetDefinition d) {
        getPackage(d).name + "." + d.name
    }
    // create a serialVersionUID which depends on class name and revision, plus the same for any parent classes only
    def public static long getSerialUID(ClassDefinition d) {
        var long myUID = d.getPartiallyQualifiedClassName.hashCode
        if (d.revision !== null)
            myUID = 97L * myUID + d.revision.hashCode()
        if (d.extendsClass !== null && d.extendsClass.classRef !== null)
            myUID = 131L * myUID + getSerialUID(d.extendsClass.classRef)   // recurse parent classes
        return myUID
    }
    // create a serialVersionUID which depends on class name
    def public static long getSerialUID(EnumDefinition d) {
        var long myUID = d.getPartiallyQualifiedClassName.hashCode
        for (value : d.values)
            myUID = 97L * myUID + value.hashCode
        for (value : d.avalues)
            myUID = 17L * myUID + value.token.hashCode + 11 * value.name.hashCode
        return myUID
    }
    // create a serialVersionUID which depends on class name and revision, plus the same for any parent classes only
    def public static long getSerialUID(XEnumDefinition d) {
        var long myUID = d.getPartiallyQualifiedClassName.hashCode + d.myEnum.getSerialUID
        if (d.extendsXenum !== null)
            myUID = 131L * myUID + getSerialUID(d.extendsXenum)   // recurse parent xenums
        return myUID
    }
}
