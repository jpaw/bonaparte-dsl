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

package de.jpaw.bonaparte.dsl.validation;

import java.util.List;

import org.eclipse.emf.common.util.EList;
import org.eclipse.xtext.validation.Check;
import org.eclipse.xtext.xbase.lib.StringExtensions;

import de.jpaw.bonaparte.dsl.bonScript.BonScriptPackage;
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition;
import de.jpaw.bonaparte.dsl.bonScript.ClassReference;
import de.jpaw.bonaparte.dsl.bonScript.ElementaryDataType;
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition;
import de.jpaw.bonaparte.dsl.bonScript.GenericsDef;
import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition;
import de.jpaw.bonaparte.dsl.bonScript.PropertyUse;
import de.jpaw.bonaparte.dsl.bonScript.XRequired;
import de.jpaw.bonaparte.dsl.generator.XUtil;

public class BonScriptJavaValidator extends AbstractBonScriptJavaValidator {
    static private final int GIGABYTE = 1024 * 1024 * 1024;

    /* Must change MANIFEST.MF to contain
     * Bundle-RequiredExecutionEnvironment: JavaSE-1.7
     * Otherwise, Eclipse will complain:
     * An internal error occurred during: "Building workspace".
     * Unresolved compilation problem:
     * Cannot switch on a value of type String for source level below 1.7.
     * Only convertible int values or enum variables are permitted
     *
     */

    @Check
    public void checkElementaryDataTypeLength(ElementaryDataType dt) {
        if (dt.getName() != null) {
            switch (dt.getName().toLowerCase()) {
            case "calendar":
                if ((dt.getLength() < 0) || (dt.getLength() > 3)) {
                    error("Fractional seconds must be at least 0 and at most 3 digits",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__LENGTH);
                } else {
                    // not good anyway
                    warning("The type \"Calendar\" is mapped to the mutable Java class (Gregorian)Calendar. Use of \"Day\" or \"Timestamp\" is preferred.",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__NAME);
                }
                return;
            case "timestamp": // similar to default, but allow 0 decimals and max. 3 digits precision
                if ((dt.getLength() < 0) || (dt.getLength() > 3)) {
                    error("Fractional seconds must be at least 0 and at most 3 digits",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__LENGTH);
                }
                return;
            case "number":
                if ((dt.getLength() <= 0) || (dt.getLength() > 9)) {
                    error("Mantissa must be at least 1 and at max 9",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__LENGTH);
                }
                return;
            case "decimal":
                if ((dt.getLength() <= 0) || (dt.getLength() > 18)) {
                    error("Mantissa must be at least 1 and at max 18",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__LENGTH);
                }
                if ((dt.getDecimals() < 0) || (dt.getDecimals() > dt.getLength())) {
                    error("Decimals may not be negative and must be at max length of mantissa",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__DECIMALS);
                }
                return;
                // String types and binary data types
            case "ascii":
            case "unicode":
            case "uppercase":
            case "lowercase":
            case "binary":
                if (dt.getMinLength() < 0) {
                    error("Field min length cannot be negative",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__MIN_LENGTH);
                    return;
                }
                if (dt.getMinLength() > dt.getLength()) {
                    error("Field min length cannot exceed field length",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__MIN_LENGTH);
                    return;
                }
                if ((dt.getLength() <= 0) || (dt.getLength() > GIGABYTE)) {
                    error("Field size must be at least 1 and at most 1 GB",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__LENGTH);
                }
                return;
            case "raw":
                if ((dt.getLength() <= 0) || (dt.getLength() > GIGABYTE)) {
                    error("Field size must be at least 1 and at most 1 GB",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__LENGTH);
                } else {
                    // not good anyway
                    warning("The type \"Raw\" is mapped to the mutable Java class byte []. Use of \"Binary\" is preferred.",
                            BonScriptPackage.Literals.ELEMENTARY_DATA_TYPE__NAME);
                }
                return;
            }
        }
    }

    private boolean isSubBundle(String myBundle, String extendedBundle) {
        if (extendedBundle == null)
        {
            return true;  // everything is a sub-bundle of the static data
        }
        if (myBundle == null)
        {
            return false; // something not in a bundle cannot extend a bundle
        }
        if (!myBundle.startsWith(extendedBundle))
        {
            return false; // should be the bundle extended
        }
        // finally check if the bundle names are either equal or the extension is of form '.' QualifiedID
        return (myBundle.length() == extendedBundle.length())
                || ((myBundle.length() > extendedBundle.length()) && (myBundle.charAt(extendedBundle.length()) == '.'));
    }

    @Check
    public void checkClassDefinition(ClassDefinition cd) {
        String s = cd.getName();
        if (s != null) {
            if (!Character.isUpperCase(s.charAt(0))) {
                error("Class names should start with an upper case letter",
                        BonScriptPackage.Literals.CLASS_DEFINITION__NAME);
            }
        }
        if (cd.getExtendsClass() != null) {
            // the extension must reference a specific class (plus optional generics parameters), but not a generic type itself
            if (cd.getExtendsClass().getClassRef() == null) {
                error("Parent class must be an explicit class, not a generic type",
                        BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS);
                return;
            } else {
                // check the number of generic parameters
                ClassDefinition parent = cd.getExtendsClass().getClassRef();
                EList<GenericsDef> args = parent.getGenericParameters();
                EList<ClassReference> argValues = cd.getExtendsClass().getClassRefGenericParms();
                if ((args == null) && (argValues == null)) {
                    ; // fine
                } else if ((args != null) && (argValues != null)) {
                    if (args.size() != argValues.size()) {
                        error("Parameter number mismatch for generics arguments: " + argValues.size() + " parameters found, but " + args.size() + " expected",
                                BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS);
                    }
                } else if (argValues != null) {
                    error("Generics arguments found, but extending non-generic class", BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS);
                } else if (args != null) {
                    error("Extending generics class, but no generics arguments found", BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS);
                }
            }
            // the extended class may not be final
            if (cd.getExtendsClass().getClassRef().isFinal()) {
                error("Classes max not extend a final class",
                        BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS);
            }
            // the extended class must be in the same bundle or a superbundle
            PackageDefinition myPackage = XUtil.getPackageOrNull(cd);
            PackageDefinition extendedFromPackage = XUtil.getPackageOrNull(cd.getExtendsClass().getClassRef());
            if (myPackage != null && extendedFromPackage != null) {
                if (!isSubBundle(myPackage.getBundle(), extendedFromPackage.getBundle())) {
                    error("Parent classes must be in the same or a superbundle of the current package",
                            BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS);
                }
            } else {
                warning("Cannot determine package of " + (myPackage == null ? cd.getName() : cd.getExtendsClass().getClassRef().getName())
                        + " +++ " + TreeView.getClassInfo(cd) + " *** " + TreeView.getClassInfo(cd.getExtendsClass().getClassRef()),
                        BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS);
            }
            // check for cyclic dependencies
            int depth = 0;
            boolean haveAnchestorWithAbsoluteRtti = false;
            ClassDefinition anchestor = cd.getExtendsClass().getClassRef();
            while (++depth < 100) {  // after 100 iterations we assume cyclicity
                if (cd.getReturnsClass() != null && anchestor.getReturnsClass() != null) {
                    if (!inheritsClass(cd.getReturnsClass(), anchestor.getReturnsClass())) {
                        error("return object of a subclass must inherit the return class of any superclass, which is not the case for return type "
                                + anchestor.getReturnsClass().getName() + " of " + anchestor.getName(),
                                BonScriptPackage.Literals.CLASS_DEFINITION__RETURNS_CLASS);
                    }
                }
                if ((anchestor.getRtti() > 0) && !anchestor.isAddRtti()) {
                    haveAnchestorWithAbsoluteRtti = true;
                }
                anchestor = XUtil.getParent(anchestor);
                if (anchestor == null) {
                    break;
                }
            }
            if (depth >= 100) {
                error("Parent hierarchy is cyclical", BonScriptPackage.Literals.CLASS_DEFINITION__EXTENDS_CLASS);
            }
            // check that relative rtti may only be given if there is a parent class with a fixed rtti
            if (!haveAnchestorWithAbsoluteRtti && cd.isAddRtti()) {
                error("For relative RTTI definition, at least one anchestor must have an absolute RTTI", BonScriptPackage.Literals.CLASS_DEFINITION__ADD_RTTI);
            }
        }
    }
    
    private boolean inheritsClass(ClassDefinition myReturnType, ClassDefinition superclassReturnType) {
        while (myReturnType != null) {
            if (myReturnType.equals(superclassReturnType))
                return true;
            myReturnType = XUtil.getParent(myReturnType);
        }
        return false;
    }

    // helper function for checkFieldDefinition
    public static int countSameName(ClassDefinition cl,  String name) {
        int count = 0;
        for (FieldDefinition field: cl.getFields()) {
            if (name.equals(field.getName())) {
                ++count;
            }
        }
        return count;
    }

    @Check
    public void checkFieldDefinition(FieldDefinition fd) {
        String s = fd.getName();
        if (s != null) {
            if (!Character.isLowerCase(s.charAt(0))) {
                error("field names should start with a lower case letter",
                        BonScriptPackage.Literals.FIELD_DEFINITION__NAME);
            }
        }
        /*
        if (s.length() > 1 && Character.isUpperCase(s.charAt(1)) && fd.getGetter() == null && fd.getSetter() == null) {
            warning("Java beans specification for getter / setter name differs from standard get/setCapsFirst approach. Consider specifying alt names",
                    BonScriptPackage.Literals.FIELD_DEFINITION__NAME);
        }
        if (fd.getGetter() != null && s.equals("get" + StringExtensions.toFirstUpper(fd.getGetter()))) {
            error("alternate name matches the default name", BonScriptPackage.Literals.FIELD_DEFINITION__GETTER);
        }
        if (fd.getSetter() != null && s.equals("set" + StringExtensions.toFirstUpper(fd.getSetter()))) {
            error("alternate name matches the default name", BonScriptPackage.Literals.FIELD_DEFINITION__SETTER);
        } */

        // check for unique name within this class and possible superclasses
        ClassDefinition cl = (ClassDefinition)fd.eContainer();  // Grammar dependency! FieldDefinition is only called from ClassDefinition right now
        if (countSameName(cl, s) != 1) {
            error("field name is not unique within this class",
                    BonScriptPackage.Literals.FIELD_DEFINITION__NAME);
        }
        // check parent classes as well
        for (ClassDefinition parentClass = XUtil.getParent(cl); parentClass != null; parentClass = XUtil.getParent(parentClass)) {
            if (countSameName(parentClass, s) != 0) {
                error("field occurs in inherited class "
                        + ((PackageDefinition)parentClass.eContainer()).getName() + "."
                        + parentClass.getName() + " already (shadowing not allowed in bonaparte)",
                        BonScriptPackage.Literals.FIELD_DEFINITION__NAME);
            }
        }

        if (fd.getRequired() != null) {
            /*
            // System.out.println("Checking " + s + ": getRequired() = <" + fd.getRequired().toString() + ">");
            // not allowed for typedefs right now
            if (fd.getDatatype() != null && fd.getDatatype().getReferenceDataType() != null) {
                error("required / optional attributes not allowed for type definitions: found <" + fd.getRequired().getX().toString() + "> for " + s,
                        BonScriptPackage.Literals.FIELD_DEFINITION__REQUIRED);
            } */
            if ((fd.getRequired().getX() == XRequired.OPTIONAL) && (fd.getDatatype() != null)) {
                ElementaryDataType dt = fd.getDatatype().getElementaryDataType();
                if ((dt != null) && (dt.getName() != null) && Character.isLowerCase(dt.getName().charAt(0))) {
                    error("optional attribute conflicts implicit 'required' meaning of lower case data type",
                            BonScriptPackage.Literals.FIELD_DEFINITION__REQUIRED);
                }
            }
        }
    }

    @Check
    public void checkGenericsParameterList(ClassReference ref) {
        if (ref.getClassRef() != null) {
            // verify that the parameters given match the definition of the class referenced
            List <GenericsDef> requiredParameters = ref.getClassRef().getGenericParameters();
            List <ClassReference> providedParameters = ref.getClassRefGenericParms();
            if ((requiredParameters == null) && (providedParameters == null))
            {
                return;  // OK, both have no parameters
            }
            if (requiredParameters == null) {
                // not ok, one is empty, the other not!
                error("list of generic type attributes does not match definition of referenced class, which is a non-generic type",
                        BonScriptPackage.Literals.CLASS_REFERENCE__CLASS_REF_GENERIC_PARMS);
                return;
            }
            if (providedParameters == null) {
                // not ok, one is empty, the other not!
                error("must provide a list of generic type attributes",
                        BonScriptPackage.Literals.CLASS_REFERENCE__CLASS_REF);
                return;
            }
            if (requiredParameters.size() != providedParameters.size()) {
                // not ok, one is empty, the other not!
                error("list of generic type attributes differs in length from definition in referenced class",
                        BonScriptPackage.Literals.CLASS_REFERENCE__CLASS_REF_GENERIC_PARMS);
                return;
            }
            for (int i = 0; i < requiredParameters.size(); ++i) {
                if (requiredParameters.get(i).getExtends() != null) {
                    // provided parameter must be a subclass of the requested one
                    ; //if (!isSuperClass(requiredParameters.get(i).getExtends(), providedParameters.get(i)))
                }
            }
        }
    }
    

    @Check
    public void checkPropertyUse(PropertyUse pu) {
        if (pu.getKey().getAnnotationName() == null)
            return; // no check for standard properties
        if (pu.getKey().isWithArg()) {
            if (pu.getValue() == null)
                error("the property " + pu.getKey().getName() + " has been defined to require a value",
                        BonScriptPackage.Literals.PROPERTY_USE__KEY);
        } else {
            if (pu.getValue() != null)
                error("the property " + pu.getKey().getName() + " has been defined to not accept a value",
                        BonScriptPackage.Literals.PROPERTY_USE__VALUE);
        }
    }

}
