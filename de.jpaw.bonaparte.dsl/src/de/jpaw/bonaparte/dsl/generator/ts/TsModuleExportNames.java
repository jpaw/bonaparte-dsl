package de.jpaw.bonaparte.dsl.generator.ts;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

import org.eclipse.emf.ecore.EObject;

/** Assigns stable public names to types re-exported by a TypeScript entry-point barrel. */
public final class TsModuleExportNames {
    private final Map<String, String> exportNamesByIdentity = new HashMap<>();

    public TsModuleExportNames(Collection<? extends EObject> types) {
        Map<String, EObject> uniqueTypes = new LinkedHashMap<>();
        Map<String, Integer> countsByName = new HashMap<>();
        for (EObject type : types) {
            String identity = TsImportCollector.bonIdentity(type);
            if (uniqueTypes.putIfAbsent(identity, type) == null)
                countsByName.merge(TsImportCollector.simpleName(type), 1, Integer::sum);
        }

        Set<String> occupiedNames = new HashSet<>(countsByName.keySet());
        ArrayList<EObject> collisions = new ArrayList<>();
        for (EObject type : uniqueTypes.values()) {
            if (countsByName.get(TsImportCollector.simpleName(type)) > 1)
                collisions.add(type);
        }
        collisions.sort(Comparator.comparing(TsImportCollector::bonIdentity));

        for (EObject type : collisions) {
            String baseName = TsModuleResolver.qualifiedExportName(type);
            String exportName = baseName;
            int suffix = 2;
            while (!occupiedNames.add(exportName))
                exportName = baseName + suffix++;
            exportNamesByIdentity.put(TsImportCollector.bonIdentity(type), exportName);
        }
    }

    public String exportName(EObject type) {
        String identity = TsImportCollector.bonIdentity(type);
        return exportNamesByIdentity.getOrDefault(identity, TsImportCollector.simpleName(type));
    }
}