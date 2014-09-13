package de.jpaw.bonaparte.noSQL.dsl.generator

import de.jpaw.bonaparte.noSQL.dsl.bDsl.EntityDefinition
import org.eclipse.emf.ecore.EObject

class ZUtil {
    
    def public static getInheritanceRoot(EntityDefinition e) {
        var EntityDefinition ee = e
        while (ee.^extends !== null)
            ee = ee.^extends
        return ee
    }
    
    
    /** Returns the Entity in which an object is defined in. Expectation is that there is a class of type PackageDefinition containing it at some level.
     * If this cannot be found, throw an Exception, because callers assume the result is not null and would throw a NPE anyway.
     */
    def public static EntityDefinition getBaseEntity(EObject ee) {
        var e = ee
        while (e !== null) {
            if (e instanceof EntityDefinition)
                return e
            e = e.eContainer
        }
        if (ee === null)
            throw new Exception("getBaseEntity() called for NULL")
        else
            throw new Exception("getBaseEntity() called for " + ee.toString())
    }
    
}