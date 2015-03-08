package de.jpaw.bonaparte.jpa.dsl.ui.help;

import org.eclipse.emf.ecore.EObject;
import org.eclipse.xtext.documentation.IEObjectDocumentationProvider;

import de.jpaw.bonaparte.jpa.dsl.bDDL.EntityDefinition;
import de.jpaw.bonaparte.jpa.dsl.bDDL.OneToMany;
import de.jpaw.bonaparte.jpa.dsl.bDDL.OneToOne;
import de.jpaw.bonaparte.jpa.dsl.bDDL.Relationship;

public class BDDLEObjectDocumentationProvider implements IEObjectDocumentationProvider {
    private static final String RELATIONSHIP_DOC =
            "(<i>entity</i>) - The Java JPA 2.0 entity class containing the referred object<p>"
            + "(<i>field name</i>) - The Java identifier of the field in this entity class<p>"
            + "[LAZY|EAGER] - optional specification of the fetch type. For lazy fetching, the relationship can not be optional<p>"
            + "(<i>referencing fields</i>) - The fields in this entity mapping to the PK fields of the referenced entity<p>";
    private static final String URL_PART = "http://docs.oracle.com/javaee/6/api/javax/bonaparte.jpa/";

    private String docWithUrl(String what, String add) {
        return RELATIONSHIP_DOC + add + (what == null ? "" : "<p>See also: <a href=\"" + URL_PART + what + ".html\"><b>" + what + "</b></a>");
    }

    @Override
    public String getDocumentation(EObject o) {
        if (o instanceof Relationship) {
            String what = null;
            if (o.eContainer() instanceof EntityDefinition)
                what = "ManyToOne";
            else if (o.eContainer() instanceof OneToMany)
                what = "OneToMany";
            else if (o.eContainer() instanceof OneToOne)
                what = "OneToOne";
            return docWithUrl(what, "");
        }
        if (o instanceof OneToOne) {
            return docWithUrl("OneToOne", "[cascade] - If specified, adds <a href=\"" + URL_PART + "CascadeType.html\"><b>CascadeType.ALL</b></a><p>");
        }
        if (o instanceof OneToMany) {
            return docWithUrl("OneToMany", "(<i>mapped Key</i>) - The SQL column name of the referenced entity which selects the Map entry<p>");
        }
        return null;
    }

}
