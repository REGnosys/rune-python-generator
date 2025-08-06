package com.regnosys.rosetta.generator.python;

import com.google.inject.Guice;
import com.google.inject.Injector;
import com.google.inject.Provider;
import com.regnosys.rosetta.RosettaRuntimeModule;
import com.regnosys.rosetta.RosettaStandaloneSetup;
import com.regnosys.rosetta.builtin.RosettaBuiltinsService;
import com.regnosys.rosetta.generator.external.ExternalGenerator;
import com.regnosys.rosetta.generator.external.ExternalGenerators;
import com.regnosys.rosetta.rosetta.RosettaModel;
import org.apache.commons.cli.*;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.resource.ResourceSet;
import org.eclipse.xtext.resource.XtextResourceSet;
import org.eclipse.emf.common.util.URI;
import org.jetbrains.annotations.NotNull;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import jakarta.inject.Inject;
import java.io.IOException;
import java.nio.file.*;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Command-line interface for generating Python code from Rosetta models.
 * <p>
 * This CLI tool loads Rosetta model files (either from a directory or a single file),
 * invokes the {@link PythonCodeGenerator}, and writes the generated Python code to the specified target directory.
 * It is intended for use by developers and build systems to automate the translation of Rosetta DSL models to Python.
 * </p>
 *
 * <h2>Usage</h2>
 * <pre>
 *   java -cp &lt;your-jar-or-classpath&gt; com.regnosys.rosetta.generator.python.PythonCodeGeneratorCLI -s &lt;source-dir&gt; -t &lt;target-dir&gt;
 *   java -cp &lt;your-jar-or-classpath&gt; com.regnosys.rosetta.generator.python.PythonCodeGeneratorCLI -f &lt;source-file&gt; -t &lt;target-dir&gt;
 * </pre>
 * <ul>
 *   <li><b>-s, --dir &lt;source-dir&gt;</b>: Source directory containing Rosetta files (all <code>.rosetta</code> files will be processed)</li>
 *   <li><b>-f, --file &lt;source-file&gt;</b>: Single Rosetta file to process</li>
 *   <li><b>-t, --tgt &lt;target-dir&gt;</b>: Target directory for generated Python code (defaults to <code>./python</code> if not specified)</li>
 *   <li><b>-h</b>: Print usage/help</li>
 * </ul>
 *
 * <h2>Example</h2>
 * <pre>
 *   java -jar target/python-0.0.0.main-SNAPSHOT-shaded.jar -s src/main/rosetta -t build/python
 * </pre>
 *
 * <h2>Notes</h2>
 * <ul>
 *   <li>Either <b>-s</b> or <b>-f</b> must be specified.</li>
 *   <li>The tool will clean the target directory before writing new files.</li>
 *   <li>Requires a Java 11+ runtime and all dependencies on the classpath (or use the shaded/uber jar).</li>
 * </ul>
 *
 * @author Plamen Neykov
 * @author Daniel Schwartz
 * @see PythonCodeGenerator
 */

public class PythonCodeGeneratorCLI {
    private static final Logger LOGGER = LoggerFactory.getLogger(PythonCodeGeneratorCLI.class);

    public static void main(String[] args) {
        Options options = new Options();
        Option help = new Option("h", "Print usage");
        Option srcDirOpt = Option.builder("s").longOpt("dir").argName("srcDir").desc("Source Rosetta directory").hasArg().build();
        Option srcFileOpt = Option.builder("f").longOpt("file").argName("srcFile").desc("Source Rosetta file").hasArg().build();
        Option tgtDirOpt = Option.builder("t").longOpt("tgt").argName("tgtDir").desc("Target Python directory (default: ./python)").hasArg().build();

        options.addOption(help);
        options.addOption(srcDirOpt);
        options.addOption(srcFileOpt);
        options.addOption(tgtDirOpt);

        CommandLineParser parser = new DefaultParser();
        try {
            CommandLine cmd = parser.parse(options, args);
            if (cmd.hasOption("h")) {
                printUsage(options);
                return;
            }
            String tgtDir = cmd.getOptionValue("t", "./python");
            if (cmd.hasOption("s")) {
                String srcDir = cmd.getOptionValue("s");
                translateFromSourceDir(srcDir, tgtDir);
            } else if (cmd.hasOption("f")) {
                String srcFile = cmd.getOptionValue("f");
                translateFromSourceFile(srcFile, tgtDir);
            } else {
                System.err.println("Either a source directory (-s) or source file (-f) must be specified.");
                printUsage(options);
            }
        } catch (ParseException e) {
            System.err.println("Failed to parse command line arguments: " + e.getMessage());
            printUsage(options);
        }
    }

    private static void printUsage(Options options) {
        HelpFormatter formatter = new HelpFormatter();
        formatter.printHelp("PythonCodeGeneratorCLI", options, true);
    }

    private static void translateFromSourceDir (String srcDir, String tgtDir) {
        // Find all .rosetta files in a directory
        Path srcDirPath = Paths.get(srcDir);
        if (!Files.exists(srcDirPath)) {
            LOGGER.error("Source directory does not exist: {}", srcDir);
            System.exit(1);
        }
        if (!Files.isDirectory(srcDirPath)) {
            LOGGER.error("Source directory is not a directory: {}", srcDir);
            System.exit(1);
        }
        try {
            List<Path> rosettaFiles = Files.walk(srcDirPath)
                    .filter(Files::isRegularFile)
                    .filter(f -> f.getFileName().toString().endsWith(".rosetta"))
                    .collect(Collectors.toList());
            processRosettaFiles(rosettaFiles, tgtDir);
        } catch (IOException e) {
            LOGGER.error("Failed to process source directory: {}", srcDir, e);
        }
    }
    private static void translateFromSourceFile (String srcFile, String tgtDir) {
        Path srcFilePath = Paths.get(srcFile);
        if (!Files.exists(srcFilePath)) {
            LOGGER.error("Source file does not exist: {}", srcFile);
            System.exit(1);
        }
        if (Files.isDirectory(srcFilePath)) {
            LOGGER.error("Source file is a directory: {}", srcFile);
            System.exit(1);
        }
        if (!srcFilePath.toString().endsWith(".rosetta")) {
            LOGGER.error("Source file does not end with .rosetta: {}", srcFile);
            System.exit(1);
        }
        List<Path> rosettaFiles = List.of(srcFilePath);
        processRosettaFiles(rosettaFiles, tgtDir);
    }
    // Common processing function
    private static void processRosettaFiles(List<Path> rosettaFiles, String tgtDir) {
        LOGGER.info("Processing {} .rosetta files, writing to: {}", rosettaFiles.size(), tgtDir);

        if (rosettaFiles.isEmpty()) {
            System.err.println("No .rosetta files found to process.");
            System.exit(1);
        }

        Injector injector = new PythonRosettaStandaloneSetup().createInjectorAndDoEMFRegistration();
        ResourceSet resourceSet = injector.getInstance(ResourceSet.class);
        List<Resource> resources = new LinkedList<>();
        RosettaBuiltinsService builtins = injector.getInstance(RosettaBuiltinsService.class);
        resources.add (resourceSet.getResource(builtins.basicTypesURI, true));
        resources.add (resourceSet.getResource(builtins.annotationsURI, true));
        rosettaFiles.stream()
                .map(path -> resourceSet.getResource(URI.createFileURI(path.toString()), true))
                .forEach(resources::add);

        PythonCodeGenerator pythonCodeGenerator = injector.getInstance(PythonCodeGenerator.class);
        PythonModelLoader modelLoader = injector.getInstance(PythonModelLoader.class);

        List<RosettaModel> models = modelLoader.getRosettaModels(resources);
        if (models.isEmpty()) {
            LOGGER.error("No valid Rosetta models found.");
            System.exit(1);
        }
        String version = models.getFirst().getVersion();

        LOGGER.info("Processing {} models, version: {}", models.size(), version);

        Map<String, CharSequence> generatedPython = new HashMap<>();
        pythonCodeGenerator.beforeAllGenerate(resourceSet, models, version);
        for (RosettaModel model : models) {
            System.out.println("Processing: " + model.getName());
            generatedPython.putAll(pythonCodeGenerator.beforeGenerate(model.eResource(), model, version));
            generatedPython.putAll(pythonCodeGenerator.generate(model.eResource(), model, version));
            generatedPython.putAll(pythonCodeGenerator.afterGenerate(model.eResource(), model, version));
        }
        generatedPython.putAll(pythonCodeGenerator.afterAllGenerate(resourceSet, models, version));

        writePythonFiles(generatedPython, tgtDir);
    }

    private static void writePythonFiles(Map<String, CharSequence> generatedPython, String tgtDir) {
        for (Map.Entry<String, CharSequence> entry : generatedPython.entrySet()) {
            String filePath = entry.getKey();
            CharSequence content = entry.getValue();
            Path outputPath = Paths.get(tgtDir, filePath);
            try {
                Files.createDirectories(outputPath.getParent());
                Files.writeString(outputPath, content.toString());
                LOGGER.info("Wrote file: {}", outputPath);
            } catch (IOException e) {
                System.err.println("Failed to write file: " + outputPath + " - " + e.getMessage());
            }
        }
        LOGGER.info("Wrote {} files to {}", generatedPython.size(), tgtDir);
    }
    // --- Helper classes for model loading and Guice setup ---

    static class PythonModelLoader {
        @Inject Provider<XtextResourceSet> resourceSetProvider;
        
        public List<RosettaModel> getRosettaModels(List<Resource> resources) {
            return resources.stream()
                    .filter(Objects::nonNull)
                    .map(Resource::getContents)
                    .flatMap(Collection::stream)
                    .filter(r -> r instanceof RosettaModel)
                    .map(r -> (RosettaModel) r)
                    .collect(Collectors.toList());
        }
        public XtextResourceSet getResourceSet() {
            return resourceSetProvider.get();
        }

        private static String url(@NotNull java.net.URL c) {
            try {
                return c.toURI().toURL().toURI().toASCIIString();
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        }

        private static Resource getResource(ResourceSet resourceSet, String f) {
            try {
                return resourceSet.getResource(org.eclipse.emf.common.util.URI.createURI(f, true), true);
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        }
    }

    static class PythonRosettaRuntimeModule extends RosettaRuntimeModule {
        @Override
        public void configure(com.google.inject.Binder binder) {
            super.configure(binder);
            binder.bind(PythonModelLoader.class);
        }

        @Override
        public Class<? extends Provider<ExternalGenerators>> provideExternalGenerators() {
            return PythonCodeGeneratorInstance.class;
        }
    }

    public static class PythonCodeGeneratorInstance implements Provider<ExternalGenerators> {
        @Override
        public ExternalGenerators get() {
            return new ExternalGenerators() {
                @NotNull
                @Override
                public Iterator<ExternalGenerator> iterator() {
                    return List.of((ExternalGenerator) new PythonCodeGenerator()).iterator();
                }
            };
        }
    }

    static class PythonRosettaStandaloneSetup extends RosettaStandaloneSetup {
        @Override
        public Injector createInjector() {
            return Guice.createInjector(new PythonRosettaRuntimeModule());
        }
    }
}