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

package de.jpaw.bonaparte.dsl.generator;

// A class to extend the grammar's DataType EObject,
// in order to provide space for internal extra fields used by the code generator, but also
// in order to support O(1) lookup of recursive typedefs

import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import org.eclipse.emf.ecore.EObject;

import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition;
import de.jpaw.bonaparte.dsl.bonScript.TypeDefinition;
import de.jpaw.bonaparte.dsl.bonScript.DataType;
import de.jpaw.bonaparte.dsl.bonScript.ElementaryDataType;
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition;

public class DataTypeExtension {
	// a lookup to determine if a data type can (should) be implemented as a Java primitive.
	// (LANGUAGE SPECIFIC: JAVA)
	private static final Set<String> JAVA_PRIMITIVES = new HashSet<String>(Arrays.asList(new String[] {
		"boolean", "int", "long", "float", "double"
	}));

	// a lookup to resolve typedefs. Also collects preprocessed information about a data type
	static private Map<DataType,DataTypeExtension> map = new HashMap<DataType,DataTypeExtension>(200);

	// a lookup to determine the Java data type to use for a given grammar type.
	// (LANGUAGE SPECIFIC: JAVA)
	static protected Map<String,String> dataTypeJava = new HashMap<String, String>(32);
	static {
		dataTypeJava.put("boolean",   "Boolean");
		dataTypeJava.put("int",       "Integer");
		dataTypeJava.put("integer",   "Integer");
		dataTypeJava.put("long",      "Long");
		dataTypeJava.put("float",     "Float");
		dataTypeJava.put("double",    "Double");
		dataTypeJava.put("number",    "Integer");
		dataTypeJava.put("decimal",   "BigDecimal");
		
		dataTypeJava.put("raw",       "byte []");
		dataTypeJava.put("timestamp", "GregorianCalendar");  // temporary solution until JSR 310 has been implemented
		dataTypeJava.put("day",       "GregorianCalendar");  // temporary solution until JSR 310 has been implemented
		
		dataTypeJava.put("uppercase", "String");
		dataTypeJava.put("lowercase", "String");
		dataTypeJava.put("ascii",     "String");
		dataTypeJava.put("unicode",   "String");
		dataTypeJava.put("string",    "String");
	}
	
	
	// member variables
	private boolean currentlyVisited = false;
	public ElementaryDataType elementaryDataType;
	public ClassDefinition objectDataType;
	public TypeDefinition typedef;
	public boolean effectiveSigned = true;
	public boolean effectiveTrim = false;
	public boolean effectiveAllowCtrls = false;
	public boolean isPrimitive = false;
	public boolean isUpperCaseOrLowerCaseSpecialType = false;
	public boolean wasUpperCase = false;
	public String javaType;
	
	static public void clear() {
		map.clear();
	}
	
	static public DataTypeExtension get(DataType key) throws Exception {
		// retrieve the DataTypeExtension class for the given key (auto-create it if not yet existing)
		DataTypeExtension r = map.get(key);
		if (r != null) {
			if (r.currentlyVisited)
				// can only occur for typedefs
				throw new Exception("recursive typedefs around " + r.typedef.getName());
			return r;
		}
		// does not exist, create a new one!
		r = new DataTypeExtension();
		r.elementaryDataType = key.getElementaryDataType();
		r.objectDataType = key.getObjectDataType();
		r.typedef = key.getDataTypeReference();
		if (r.elementaryDataType != null) {
			// immediate data: perform postprocessing. transfer defaults of embedding package to this instance
			ElementaryDataType e = r.elementaryDataType;
			// find the parent which is the relevant package definition. These are 2 or 3 steps
			// (Package => Typedef => DataType key) or
			// (Package => ClassDefinition => FieldDefinition => DataType key)
			// Still, we keep this generic in order to support possible changes of the grammar
			PackageDefinition p;
			for (EObject i = key.eContainer(); ; i = i.eContainer()) {
				if (i instanceof PackageDefinition) {
					p = (PackageDefinition)i;
					break;
				}
			}
			
			// use the first character to determine that a field is optional
	        if (Character.isUpperCase(e.getName().charAt(0))) {
	            r.wasUpperCase = true;
	            if (e.getName().equals("Int"))
	            	e.setName("Integer");   // fix java naming inconsistency
	        } else {
	            if (e.getName().equals("integer"))
	            	e.setName("int");   // fix java naming inconsistency
	            if (p.isUsePrimitives() && JAVA_PRIMITIVES.contains(e.getName()))
	            	r.isPrimitive = true;
	        }
	        r.javaType = dataTypeJava.get(e.getName().toLowerCase());
	        if (r.javaType == null)
	        	throw new Exception("unmapped Java data type for " + e.getName());
	        
	        // special treatment for uppercase / lowercase shorthands
	        if (r.javaType.equals("String"))
	            if (e.getName().equals("uppercase") || e.getName().equals("lowercase"))
	            	r.isUpperCaseOrLowerCaseSpecialType = true;
	        
	        // set the effective trimming. If settings in e are both undefined (false), the retrieve from the package, else leave at false
	        if (e.isTrim() || e.isNotrim()) {
	        	r.effectiveTrim = e.isTrim();
	        } else if (p.isDefaultTrim()) {
	        	r.effectiveTrim = true;
	        }
	        // set the effective setting to define if control characters are allowed in Unicode strings
	        if (e.isAllowCtrls() || e.isNoCtrls()) {
	        	r.effectiveAllowCtrls = e.isAllowCtrls();
	        } else if (p.isDefaultCtrls()) {
	        	r.effectiveAllowCtrls = true;
	        }
	        // set the effective setting to define if integral and fixed point numbers are signed are unsigned 
	        if (e.isSigned() || e.isUnsigned()) {
	        	r.effectiveSigned = e.isSigned();
	        } else if (p.isDefaultUnsigned()) {
	        	r.effectiveSigned = false;
	        }
	        //System.out.println("setting elem data type: " + e.getName() + String.format(": wasUpper=%b, primitive=%b, length=%d, key=",
	        //		r.wasUpperCase, r.isPrimitive, e.getLength()) + key);
		}
		// now resolve the typedef, if exists
		if (r.typedef != null) {
			r.currentlyVisited = true;
			// add to map
			map.put(key, r);
			DataTypeExtension resolvedReference = get(r.typedef.getDatatype());  // descend via DFS
			r.elementaryDataType = resolvedReference.elementaryDataType;
			r.objectDataType = resolvedReference.objectDataType;
			r.wasUpperCase = resolvedReference.wasUpperCase;
			r.isPrimitive = resolvedReference.isPrimitive;
        	r.effectiveSigned = resolvedReference.effectiveSigned;
        	r.effectiveTrim = resolvedReference.effectiveTrim;
        	r.effectiveAllowCtrls = resolvedReference.effectiveAllowCtrls;
        	r.javaType = resolvedReference.javaType;
        	r.isUpperCaseOrLowerCaseSpecialType = resolvedReference.isUpperCaseOrLowerCaseSpecialType;
			r.currentlyVisited = false;
		} else {
			// just simply store it (elementary data type or object reference)
			map.put(key, r);
		}
		// set "required" etc. parameters
		return r;
	}
}
