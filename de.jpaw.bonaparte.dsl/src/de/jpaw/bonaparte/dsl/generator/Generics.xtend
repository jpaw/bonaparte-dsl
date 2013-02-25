package de.jpaw.bonaparte.dsl.generator

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import java.util.Map
import java.util.HashMap

// class to support replacement of generics arguments by their actual parameters in subclasses 
class Generics {
    private var Map<String,String> current = new HashMap<String,String>(20)
    private var Generics parent = null
    
    // no-argument constructor for the top level class (no substitution)
    public new() {
    }
    
    // create a generics substitution for superclass of d, being invoked by d
    // parent generics is there to allow for concatenation of arguments (nested substitution) 
    public new(Generics myParent, ClassDefinition d) {
        var ClassDefinition superClass = XUtil::getParent(d)
        parent = myParent
        if (superClass != null) {
            var args = superClass.genericParameters     // the symbolic names of the generics parameters in the superclass
            var argValues = d.extendsClass.classRefGenericParms
            if (argValues != null && args != null) {  // actual values supplied, hope both are of same cardinality
                // get the names to be substituted
                for (int i : 0 .. args.size-1)
                    current.put(args.get(i).name, argValues.get(i).classRef.name)
            }            
        }
    }
    
    // replace all occurrences of a generics parameter by its value.
    // TODO: perform a more stringent pattern separation (using regexp). A token is a sequence of letters only, no substrings allowed
    def public String replace(String pattern) {
        var String worker = pattern
        for (e : current.entrySet) {
            worker = worker.replaceAll(e.key, e.value)
        }
        if (parent != null)
            return parent.replace(worker)
        return worker
    }
}