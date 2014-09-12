package de.jpaw.bonaparte.jpa.dsl.ui.help;

import org.eclipse.emf.ecore.EObject;
import org.eclipse.xtext.ui.editor.hover.html.DefaultEObjectHoverProvider;

import de.jpaw.bonaparte.jpa.dsl.bDDL.EntityDefinition;
import de.jpaw.bonaparte.jpa.dsl.bDDL.OneToMany;
import de.jpaw.bonaparte.jpa.dsl.bDDL.OneToOne;
import de.jpaw.bonaparte.jpa.dsl.bDDL.Relationship;
 
public class BDDLEObjectHoverProvider extends DefaultEObjectHoverProvider {
 
    @Override
    protected String getFirstLine(EObject o) {
        if (o instanceof Relationship) {
            String what = "JPA 2.0 relationship";
            if (o.eContainer() instanceof EntityDefinition)
                what = "@ManyToOne";
            else if (o.eContainer() instanceof OneToMany)
                what = "@OneToMany";
            else if (o.eContainer() instanceof OneToOne)
                what = "@OneToOne";
            return what + ": (referenced entity) (field name in this class) [LAZY|EAGER] for (referencing fields)";
        }
        if (o instanceof OneToOne) {
            return "@OneToOne: (referenced entity) (field name in this class) [LAZY|EAGER] for (referencing fields) [cascade]";
        }
        if (o instanceof OneToMany) {
            return "@OneToMany: {Set,List,Map<{String,Integer,Long}> mapKey (mapped key)} (referenced entity) (field name in this class) [LAZY|EAGER] for (referencing fields)";
        }
        return super.getFirstLine(o);
    }
 
}
