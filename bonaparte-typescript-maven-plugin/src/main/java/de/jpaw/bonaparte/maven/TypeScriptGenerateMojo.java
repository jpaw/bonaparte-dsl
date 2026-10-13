package de.jpaw.bonaparte.maven;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.jar.JarFile;

import org.apache.maven.artifact.Artifact;
import org.apache.maven.execution.MavenSession;
import org.apache.maven.plugin.MojoExecutionException;
import org.apache.maven.plugins.annotations.Component;
import org.apache.maven.plugins.annotations.LifecyclePhase;
import org.apache.maven.plugins.annotations.Mojo;
import org.apache.maven.plugins.annotations.Parameter;
import org.apache.maven.plugins.annotations.ResolutionScope;
import org.apache.maven.project.DefaultProjectBuildingRequest;
import org.apache.maven.project.MavenProject;
import org.apache.maven.project.ProjectBuilder;
import org.eclipse.aether.RepositorySystem;
import org.eclipse.aether.artifact.DefaultArtifact;
import org.eclipse.aether.resolution.ArtifactRequest;
import org.eclipse.emf.common.util.URI;
import org.eclipse.xtext.maven.XtextGenerateMojo;

import de.jpaw.bonaparte.dsl.BonScriptMavenSetup;
import de.jpaw.bonaparte.dsl.BonScriptStandaloneSetup;
import de.jpaw.bonaparte.dsl.generator.ts.TsGenerationContext;

@Mojo(name = "generate", defaultPhase = LifecyclePhase.PROCESS_SOURCES,
    requiresDependencyResolution = ResolutionScope.COMPILE, threadSafe = true)
public final class TypeScriptGenerateMojo extends XtextGenerateMojo {
    @Parameter(defaultValue = "${session}", readonly = true, required = true)
    private MavenSession session;
    @Component
    private ProjectBuilder projectBuilder;
    @Component
    private RepositorySystem repositorySystem;

    @Override
    protected void internalExecute() throws MojoExecutionException {
        try {
            MavenProject current = getProject();
            TsGenerationContext.Owner currentOwner = owner(current);
            List<TsGenerationContext.Location> locations = new ArrayList<>();
            addProjectLocations(locations, current, currentOwner);
            for (Artifact artifact : current.getArtifacts()) {
                File file = artifact.getFile();
                if (file == null)
                    continue;
                MavenProject reactorProject = reactorProject(artifact);
                if (reactorProject != null) {
                    TsGenerationContext.Owner dependencyOwner = owner(reactorProject);
                    addProjectLocations(locations, reactorProject, dependencyOwner);
                    if (file.isFile() && file.getName().endsWith(".jar"))
                        addArchiveLocation(locations, file, dependencyOwner);
                } else if (file.isFile() && file.getName().endsWith(".jar") && containsBon(file)) {
                    MavenProject dependency = effectiveModel(artifact);
                    addArchiveLocation(locations, file, owner(dependency));
                }
            }
            TsGenerationContext context = new TsGenerationContext(currentOwner, locations);
            for (var language : getLanguages()) {
                if (BonScriptStandaloneSetup.class.getName().equals(language.getSetup()))
                    language.setSetup(BonScriptMavenSetup.class.getName());
            }
            try (var scope = TsGenerationContext.activate(context)) {
                super.internalExecute();
            }
        } catch (MojoExecutionException exception) {
            throw exception;
        } catch (Exception exception) {
            throw new MojoExecutionException("Cannot generate with Maven TypeScript ownership for " + getProject().getId(), exception);
        }
    }

    private MavenProject reactorProject(Artifact artifact) {
        for (MavenProject candidate : session.getProjects()) {
            if (artifact.getGroupId().equals(candidate.getGroupId())
                && artifact.getArtifactId().equals(candidate.getArtifactId())
                && artifact.getBaseVersion().equals(candidate.getVersion()))
                return candidate;
        }
        return null;
    }

    private MavenProject effectiveModel(Artifact artifact) throws Exception {
        var pomRequest = new ArtifactRequest(new DefaultArtifact(artifact.getGroupId(), artifact.getArtifactId(),
            "", "pom", artifact.getVersion()), getProject().getRemoteProjectRepositories(), null);
        File pom = repositorySystem.resolveArtifact(session.getRepositorySession(), pomRequest).getArtifact().getFile();
        var request = new DefaultProjectBuildingRequest(session.getProjectBuildingRequest());
        request.setProcessPlugins(false);
        request.setResolveDependencies(false);
        return projectBuilder.build(pom, request).getProject();
    }

    private static TsGenerationContext.Owner owner(MavenProject project) {
        String npmPackage = project.getProperties().getProperty("npm.package");
        if (npmPackage == null || npmPackage.isBlank())
            throw new IllegalStateException("Missing inherited npm.package for " + project.getId());
        return new TsGenerationContext.Owner(project.getGroupId(), project.getArtifactId(), project.getVersion(), npmPackage);
    }

    private static void addProjectLocations(List<TsGenerationContext.Location> locations,
            MavenProject project, TsGenerationContext.Owner owner) {
        locations.add(new TsGenerationContext.Location(URI.createFileURI(project.getBasedir().getAbsolutePath() + "/"), owner));
        locations.add(new TsGenerationContext.Location(URI.createPlatformResourceURI(project.getArtifactId() + "/", true), owner));
        locations.add(new TsGenerationContext.Location(URI.createFileURI(project.getBuild().getOutputDirectory() + "/"), owner));
    }

    private static void addArchiveLocation(List<TsGenerationContext.Location> locations,
            File jar, TsGenerationContext.Owner owner) {
        locations.add(new TsGenerationContext.Location(URI.createURI("jar:" + jar.toURI() + "!/"), owner));
    }

    private static boolean containsBon(File file) throws Exception {
        try (JarFile jar = new JarFile(file)) {
            return jar.stream().anyMatch(entry -> entry.getName().endsWith(".bon"));
        }
    }
}