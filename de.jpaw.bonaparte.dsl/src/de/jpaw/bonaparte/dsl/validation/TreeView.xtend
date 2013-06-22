
package de.jpaw.bonaparte.dsl.validation
import org.eclipse.emf.ecore.EObject

;
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition

class TreeView {
    def public static CharSequence classInfo(EObject e, int moreLevels) '''
        «e.class.canonicalName»: proxy=«e.eIsProxy», eClass=«e.eClass.name»
        «IF e.eContainer != null && moreLevels > 0»
            «e.eContainer.classInfo(moreLevels-1)»
        «ENDIF»
    '''
    
    def public static CharSequence getClassInfo(ClassDefinition cd) '''
        Object tree of «cd.name» is «cd.classInfo(4)»
    '''
}