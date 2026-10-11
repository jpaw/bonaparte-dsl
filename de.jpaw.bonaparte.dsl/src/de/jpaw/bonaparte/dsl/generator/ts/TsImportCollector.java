package de.jpaw.bonaparte.dsl.generator.ts;

import java.util.Collection;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

import org.eclipse.emf.ecore.EObject;

public final class TsImportCollector {
    private final Map<String, EObject> typesByIdentity = new LinkedHashMap<>();
    private final Map<String, String> identitiesBySimpleName = new LinkedHashMap<>();

    public boolean add(EObject type) {
        if (type == null)
            throw new IllegalArgumentException("Cannot collect a null BON type for TypeScript generation");
        String identity = bonIdentity(type);
        String simpleName = simpleName(type);
        String existingIdentity = identitiesBySimpleName.get(simpleName);
        if (existingIdentity != null && !existingIdentity.equals(identity))
            throw new IllegalStateException("TypeScript name collision for '" + simpleName + "': "
                    + existingIdentity + " and " + identity
                    + ". Rename one BON type or add deterministic import aliases.");
        if (typesByIdentity.containsKey(identity))
            return false;
        typesByIdentity.put(identity, type);
        identitiesBySimpleName.put(simpleName, identity);
        return true;
    }

    public Collection<EObject> getTypes() {
        return Collections.unmodifiableCollection(typesByIdentity.values());
    }

    public static String simpleName(EObject type) {
        Object name = type.eGet(type.eClass().getEStructuralFeature("name"));
        return String.valueOf(name);
    }

    public static String bonIdentity(EObject type) {
        return TsModuleResolver.pqon(type);
    }
}