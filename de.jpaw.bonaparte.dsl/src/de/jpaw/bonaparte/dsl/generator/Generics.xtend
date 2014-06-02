package de.jpaw.bonaparte.dsl.generator

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import java.util.Map
import java.util.HashMap

// class to support replacement of generics arguments by their actual parameters in subclasses
class Generics {
    private var Map<String,String> current = new HashMap<String,String>(20)
    private var Generics parent = null
    private val WORD_BOUNDARY = "\\b"

    // no-argument constructor for the top level class (no substitution)
    public new() {
    }

    // create a generics substitution for superclass of d, being invoked by d
    // parent generics is there to allow for concatenation of arguments (nested substitution)
    public new(Generics myParent, ClassDefinition d) {
        var ClassDefinition superClass = XUtil::getParent(d)
        parent = myParent
        // System::out.println("new generics created for " + d.name + " START");
        if (superClass !== null) {
            var args = superClass.genericParameters     // the symbolic names of the generics parameters in the superclass
            var argValues = d.extendsClass.classRefGenericParms
            if (argValues !== null && args !== null && !argValues.empty && !args.empty) {  // actual values supplied, hope both are of same cardinality
                // get the names to be substituted
                for (int i : 0 .. args.size-1)
                    current.put(args.get(i).name, XUtil::genericRef2String(argValues.get(i)))
            }
        }
        // System::out.println("new generics created for " + d.name + " END");
    }

    // replace all occurrences of a generics parameter by its value. Only whole words will be replaced, ie. DATA in myDATAxy will be left as is.
    def public String replace(String pattern) {
        var String worker = pattern
        // System::out.println("replacing variable <" + pattern + ">");
        for (e : current.entrySet) {
            worker = worker.replaceAll(WORD_BOUNDARY + e.key + WORD_BOUNDARY, e.value)
        }
        // System::out.println("replaced to <" + worker + ">");
        if (parent !== null)
            return parent.replace(worker)
        return worker
    }
}
