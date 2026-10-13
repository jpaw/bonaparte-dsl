package de.jpaw.bonaparte.dsl;

import org.eclipse.xtext.resource.XtextResourceSet;
import org.eclipse.xtext.util.Modules2;

import com.google.inject.AbstractModule;
import com.google.inject.Guice;
import com.google.inject.Inject;
import com.google.inject.Injector;
import com.google.inject.Provider;

import de.jpaw.bonaparte.dsl.generator.ts.TsGenerationContext;

public final class BonScriptMavenSetup extends BonScriptStandaloneSetup {
    @Override
    public Injector createInjector() {
        TsGenerationContext context = TsGenerationContext.active();
        if (context == null)
            throw new IllegalStateException("BonScriptMavenSetup requires an active Maven ownership context");
        return Guice.createInjector(Modules2.mixin(new BonScriptRuntimeModule(), new AbstractModule() {
            @Override
            protected void configure() {
                bind(TsGenerationContext.class).toInstance(context);
                bind(XtextResourceSet.class).toProvider(new Provider<XtextResourceSet>() {
                    @Inject
                    private Injector injector;

                    @Override
                    public XtextResourceSet get() {
                        XtextResourceSet resources = new XtextResourceSet();
                        injector.injectMembers(resources);
                        TsGenerationContext.attach(resources, context);
                        return resources;
                    }
                });
            }
        }));
    }
}