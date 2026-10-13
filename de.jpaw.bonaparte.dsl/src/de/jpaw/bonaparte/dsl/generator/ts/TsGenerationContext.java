package de.jpaw.bonaparte.dsl.generator.ts;

import java.util.List;
import java.util.Objects;

import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.common.notify.impl.AdapterImpl;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.resource.ResourceSet;

public final class TsGenerationContext {
    private static final ThreadLocal<TsGenerationContext> ACTIVE = new ThreadLocal<>();

    public static final class Scope implements AutoCloseable {
        private final TsGenerationContext previous;

        private Scope(TsGenerationContext context) {
            previous = ACTIVE.get();
            ACTIVE.set(Objects.requireNonNull(context, "context"));
        }

        @Override
        public void close() {
            if (previous == null)
                ACTIVE.remove();
            else
                ACTIVE.set(previous);
        }
    }

    public static Scope activate(TsGenerationContext context) {
        return new Scope(context);
    }

    public static TsGenerationContext active() {
        return ACTIVE.get();
    }

    public record Owner(String groupId, String artifactId, String version, String npmPackage) {
        public Owner {
            if (groupId == null || groupId.isBlank() || artifactId == null || artifactId.isBlank()
                    || version == null || version.isBlank() || npmPackage == null || npmPackage.isBlank())
                throw new IllegalArgumentException("TypeScript ownership requires full Maven coordinates and npm.package");
        }

        public String importSpecifier() {
            return npmPackage + "/" + artifactId;
        }
    }

    public record Location(URI root, Owner owner) {
        public Location {
            Objects.requireNonNull(root, "root");
            Objects.requireNonNull(owner, "owner");
            if (!root.toString().endsWith("/"))
                throw new IllegalArgumentException("TypeScript ownership root must end with /: " + root);
        }
    }

    private static final class ContextAdapter extends AdapterImpl {
        private final TsGenerationContext context;

        private ContextAdapter(TsGenerationContext context) {
            this.context = context;
        }
    }

    private final Owner currentOwner;
    private final List<Location> locations;

    public TsGenerationContext(Owner currentOwner, List<Location> locations) {
        this.currentOwner = Objects.requireNonNull(currentOwner, "currentOwner");
        this.locations = List.copyOf(locations);
    }

    public Owner currentOwner() {
        return currentOwner;
    }

    public Owner dependencyOwner(String groupId, String artifactId) {
        Owner found = null;
        for (Location location : locations) {
            Owner candidate = location.owner();
            if (groupId.equals(candidate.groupId()) && artifactId.equals(candidate.artifactId())) {
                if (found != null && !found.equals(candidate))
                    throw new IllegalStateException("Ambiguous TypeScript dependency owner for " + groupId + ":" + artifactId);
                found = candidate;
            }
        }
        if (found == null)
            throw new IllegalStateException("TypeScript dependency closure has no owner for " + groupId + ":" + artifactId);
        return found;
    }

    public Owner owner(URI resourceUri) {
        String resource = normalized(resourceUri);
        Owner found = null;
        int matchedLength = -1;
        for (Location location : locations) {
            String root = normalized(location.root());
            if (resource.startsWith(root) && root.length() >= matchedLength) {
                if (root.length() == matchedLength && found != null && !found.equals(location.owner()))
                    throw new IllegalStateException("Ambiguous TypeScript owner for " + resourceUri);
                found = location.owner();
                matchedLength = root.length();
            }
        }
        if (found == null)
            throw new IllegalStateException("TypeScript dependency closure has no owner for " + resourceUri);
        return found;
    }

    public static void attach(ResourceSet resources, TsGenerationContext context) {
        resources.eAdapters().removeIf(adapter -> adapter instanceof ContextAdapter);
        resources.eAdapters().add(new ContextAdapter(Objects.requireNonNull(context, "context")));
    }

    public static TsGenerationContext from(Resource resource) {
        if (resource == null || resource.getResourceSet() == null)
            return null;
        for (var adapter : resource.getResourceSet().eAdapters()) {
            if (adapter instanceof ContextAdapter attached)
                return attached.context;
        }
        return null;
    }

    private static String normalized(URI uri) {
        String value = uri.toString();
        if (value.startsWith("jar:") || value.startsWith("archive:"))
            return value.substring(value.indexOf(':') + 1);
        return value;
    }
}