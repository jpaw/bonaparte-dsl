# 6. Maven Integration

This document shows how to wire the bonaparte generators into a Maven build, using the `t9t`
project as the reference. There are two Maven plugins involved:

1. **`xtext-maven-plugin`** (from Eclipse Xtext) — runs the Xtext grammar and the *Java* generator.
2. **`bonaparte-typescript-maven-plugin`** (from this repo) — runs the *TypeScript* model and API
   generators with full Maven module-ownership awareness.

Both are configured in `t9t/pom.xml` under `<pluginManagement>` and inherited by the API modules.

## The two plugins at a glance

| Plugin | Goal | Phase | What it runs |
|--------|------|-------|--------------|
| `org.eclipse.xtext:xtext-maven-plugin` | `generate` | `process-sources` | Java generator (+ XSD) |
| `de.jpaw.bonaparte-dsl:bonaparte-typescript-maven-plugin` | `generate` | `generate-sources` | TS model + TS API generators |

> The TS plugin *extends* the Xtext plugin (`TypeScriptGenerateMojo extends XtextGenerateMojo`).
> It re-runs the same Xtext generation but with a `TsGenerationContext` active, so the TS
> generators can resolve module ownership.

## 1. `xtext-maven-plugin` (Java generation)

From `t9t/pom.xml`:

```xml
<plugin>
    <groupId>org.eclipse.xtext</groupId>
    <artifactId>xtext-maven-plugin</artifactId>
    <version>${xtext-maven-plugin.version}</version>
    <executions>
        <execution>
            <id>compile</id>
            <phase>process-sources</phase>
            <goals><goal>generate</goal></goals>
            <configuration>
                <compilerSourceLevel>21</compilerSourceLevel>
                <compilerTargetLevel>21</compilerTargetLevel>
                <addOutputDirectoriesToCompileSourceRoots>false</addOutputDirectoriesToCompileSourceRoots>
                <sourceRoots>
                    <sourceRoot>${project.basedir}/src/main/bon</sourceRoot>
                </sourceRoots>
                <languages>
                    <language>
                        <setup>de.jpaw.bonaparte.dsl.BonScriptStandaloneSetup</setup>
                        <outputConfigurations>
                            <outputConfiguration>
                                <outputDirectory>${project.basedir}/src/generated</outputDirectory>
                            </outputConfiguration>
                        </outputConfigurations>
                    </language>
                    <language>
                        <setup>de.jpaw.bonaparte.jpa.dsl.BDDLStandaloneSetup</setup>
                        <outputConfigurations>
                            <outputConfiguration>
                                <outputDirectory>${project.basedir}/src/generated</outputDirectory>
                            </outputConfiguration>
                        </outputConfigurations>
                    </language>
                </languages>
            </configuration>
        </execution>
    </executions>
    <dependencies>
        <dependency><groupId>org.eclipse.jdt</groupId><artifactId>ecj</artifactId><version>${jdt.version}</version></dependency>
        <dependency><groupId>org.eclipse.jdt</groupId><artifactId>org.eclipse.jdt.core</artifactId><version>${jdt.version}</version></dependency>
        <dependency><groupId>de.jpaw.bonaparte-dsl</groupId><artifactId>de.jpaw.bonaparte.dsl</artifactId><version>${bonaparte-plugin.version}</version></dependency>
        <dependency><groupId>de.jpaw.bonaparte-dsl</groupId><artifactId>de.jpaw.bonaparte.jpa.dsl</artifactId><version>${bonaparte-plugin.version}</version></dependency>
    </dependencies>
</plugin>
```

Key configuration points:

- **`sourceRoots`** — where the `.bon` files live (`src/main/bon`).
- **`languages`** — the grammar setups to run. `BonScriptStandaloneSetup` is the bonaparte DSL;
  `BDDLStandaloneSetup` is the companion JPA DSL.
- **`outputDirectory`** — generated sources go to `src/generated`.
- **`addOutputDirectoriesToCompileSourceRoots=false`** — the generated Java is added to the
  compile path separately (see `build-helper-maven-plugin` below).
- **Plugin `<dependencies>`** — the Xtext plugin needs the DSL artifacts on its classpath to load
  the grammar and generators.

## 2. `bonaparte-typescript-maven-plugin` (TS generation)

From `t9t/pom.xml`:

```xml
<plugin>
    <groupId>de.jpaw.bonaparte-dsl</groupId>
    <artifactId>bonaparte-typescript-maven-plugin</artifactId>
    <version>${bonaparte-plugin.version}</version>
    <executions>
        <execution>
            <id>generate-with-maven-ownership</id>
            <phase>generate-sources</phase>
            <goals><goal>generate</goal></goals>
        </execution>
    </executions>
    <configuration>
        <!-- identical sourceRoots / languages / outputDirectory as the xtext plugin -->
        <compilerSourceLevel>21</compilerSourceLevel>
        <compilerTargetLevel>21</compilerTargetLevel>
        <addOutputDirectoriesToCompileSourceRoots>false</addOutputDirectoriesToCompileSourceRoots>
        <sourceRoots>
            <sourceRoot>${project.basedir}/src/main/bon</sourceRoot>
        </sourceRoots>
        <languages>
            <language>
                <setup>de.jpaw.bonaparte.dsl.BonScriptStandaloneSetup</setup>
                <outputConfigurations>
                    <outputConfiguration>
                        <outputDirectory>${project.basedir}/src/generated</outputDirectory>
                    </outputConfiguration>
                </outputConfigurations>
            </language>
            <language>
                <setup>de.jpaw.bonaparte.jpa.dsl.BDDLStandaloneSetup</setup>
                <outputConfigurations>
                    <outputConfiguration>
                        <outputDirectory>${project.basedir}/src/generated</outputDirectory>
                    </outputConfiguration>
                </outputConfigurations>
            </language>
        </languages>
    </configuration>
    <dependencies>
        <dependency><groupId>org.eclipse.jdt</groupId><artifactId>ecj</artifactId><version>${jdt.version}</version></dependency>
        <dependency><groupId>org.eclipse.jdt</groupId><artifactId>org.eclipse.jdt.core</artifactId><version>${jdt.version}</version></dependency>
        <dependency><groupId>de.jpaw.bonaparte-dsl</groupId><artifactId>de.jpaw.bonaparte.jpa.dsl</artifactId><version>${bonaparte-plugin.version}</version></dependency>
    </dependencies>
</plugin>
```

The configuration mirrors the Xtext plugin. The difference is *what the mojo does internally*
(see below).

### The `npm.package` requirement

`TypeScriptGenerateMojo` builds a `TsGenerationContext` from the current project and its reactor
dependencies. **Every project in the build must define the `npm.package` property**, otherwise the
mojo throws `Missing inherited npm.package`. In `t9t` this is set once in the root `pom.xml`:

```xml
<properties>
    <npm.package>@arvato-systems-jacs/t9t</npm.package>
    <ts.models>false</ts.models>
    <ts.api>false</ts.api>
</properties>
```

### What the mojo does

`TypeScriptGenerateMojo.internalExecute`:

1. Builds a `TsGenerationContext.Owner` from the current project (`groupId`, `artifactId`,
   `version`, `npm.package`).
2. Adds **locations** for the current project: its `basedir/`, its platform resource
   `<artifactId>/`, and its `outputDirectory/`.
3. For each dependency artifact:
   - if it is a **reactor project**, adds its locations and a jar-archive location;
   - if it is a **non-reactor jar** that contains `.bon` files, resolves its POM via Aether and
     adds an archive location.
4. Swaps the grammar setup from `BonScriptStandaloneSetup` to `BonScriptMavenSetup` (which binds
   the `TsGenerationContext`).
5. Runs `super.internalExecute()` (the normal Xtext generation) inside a
   `TsGenerationContext.activate(context)` scope, so the TS generators see the ownership context.

This is what lets the TS generators know *which module owns which `.bon` file* and how to import
across modules (see [Module system](04-typescript-generator.md#module-system)).

## 3. Enabling the TS generators: `t9t-settings-api`

The TS generators are off by default. `t9t` uses a `pom`-packaging "settings" module,
`t9t-settings-api`, to flip them on for all API modules via the
**`properties-maven-plugin`**:

```xml
<plugin>
    <groupId>org.codehaus.mojo</groupId>
    <artifactId>properties-maven-plugin</artifactId>
    <version>1.2.1</version>
    <executions>
        <execution>
            <id>configure-bonaparte-typescript</id>
            <phase>initialize</phase>
            <goals><goal>set-system-properties</goal></goals>
            <configuration>
                <properties>
                    <property><name>bonaparte.TypeScript</name><value>${ts.models}</value></property>
                    <property><name>bonaparte.TypeScriptApi</name><value>${ts.api}</value></property>
                </properties>
            </configuration>
        </execution>
    </executions>
</plugin>
```

This sets the `bonaparte.TypeScript` / `bonaparte.TypeScriptApi` **system properties** from the
`ts.models` / `ts.api` Maven properties, which the generators read at call time (see
[Configuration Reference](07-configuration-reference.md)).

`t9t-settings-api` also:

- Adds `src/generated/java` to the compile sources via `build-helper-maven-plugin`.
- Sets `xtext-maven-plugin` `skip=true` in `pluginManagement` (the API modules only need the TS
  plugin, not a second Java generation pass).

## 4. Build profiles: `ts-models` and `ts-api`

`t9t/pom.xml` defines two profiles that activate the TS generation and pull in the API modules:

```xml
<profile>
    <id>ts-models</id>
    <activation><property><name>ts</name><value>true</value></property></activation>
    <properties><ts.models>true</ts.models></properties>
    <modules>
        <module>t9t-base-api</module>
        <module>t9t-ssm-api</module>
        <!-- ... all *-api modules ... -->
    </modules>
</profile>

<profile>
    <id>ts-api</id>
    <activation><property><name>ts-api</name><value>true</value></property></activation>
    <properties>
        <ts.models>true</ts.models>
        <ts.api>true</ts.api>
    </properties>
    <modules>
        <!-- ... same module list ... -->
    </modules>
</profile>
```

So:

- `mvn ... -Dts=true` → builds the API modules with **TS models** only.
- `mvn ... -Dts-api=true` → builds the API modules with **TS models + TS API clients**.

## 5. Packaging the TS as an npm package: `t9t-api-ts`

The generated TypeScript is packaged and published as an npm package by the `t9t-api-ts` module
(`pom` packaging, "Angular Package Format sources"). It uses the **`frontend-maven-plugin`**:

| Goal | Phase | Command |
|------|-------|---------|
| `install-node-and-npm` | — | installs Node/npm |
| `npm ci` | `generate-resources` | install JS deps |
| `npm run build` | `compile` | build the library |
| `npm test` + `npm run typecheck` | `test` | test + typecheck |
| `npm run package:artifact` | `package` | produce the npm tarball (env `MAVEN_PROJECT_VERSION`, `MAVEN_BUILD_TIMESTAMP`, `MAVEN_TARGET_DIRECTORY`) |
| `npm run publish:package` | `deploy` | publish (env `NODE_AUTH_TOKEN`, `NPM_REGISTRY_URL`) |

A `build-helper-maven-plugin` execution then attaches `target/t9t-api-npm.tgz` to the build with
classifier `npm`, so the tarball is a first-class Maven artifact.

## Putting it together

```
t9t (root pom)
├── npm.package, ts.models, ts.api properties
├── pluginManagement: xtext-maven-plugin + bonaparte-typescript-maven-plugin
├── profile ts-models  (-Dts=true)      → ts.models=true  + API modules
└── profile ts-api     (-Dts-api=true)  → ts.models=true, ts.api=true + API modules

t9t-settings-api (pom, parent of all *-api modules)
├── properties-maven-plugin: bonaparte.TypeScript=${ts.models}, bonaparte.TypeScriptApi=${ts.api}
├── build-helper: add src/generated/java
└── xtext-maven-plugin skip=true

t9t-ssm-api (example API module)
├── src/main/bon/*.bon
└── src/generated/{java,ts}/...   (generated)

t9t-api-ts (pom, npm packaging)
└── frontend-maven-plugin: build + package + publish the TS as an npm tarball
```

## See also

- [Configuration Reference](07-configuration-reference.md) — every `bonaparte.*` property.
- [Examples](08-examples.md) — the end-to-end result of this pipeline.
