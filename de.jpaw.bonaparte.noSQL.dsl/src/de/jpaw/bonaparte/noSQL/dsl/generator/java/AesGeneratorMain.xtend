package de.jpaw.bonaparte.noSQL.dsl.generator.java

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.generator.java.ImportCollector
import de.jpaw.bonaparte.noSQL.dsl.bDsl.EntityDefinition

import static extension de.jpaw.bonaparte.noSQL.dsl.generator.java.ZUtil.*

class AesGeneratorMain {

    def private static writeObjectRef(ClassDefinition c, String name) '''
        new ObjectReference(Visibility.PUBLIC, false, "«name»", Multiplicity.SCALAR, IndexType.NONE, 0, 0, DataCategory.OBJECT, "ref", "«c.name»", false, false, null, true, "«c.name»", «c.name».class$MetaData(), null, null)'''

    def public static javaSetOut(EntityDefinition e) {
        val String myPackageName = e.packageName
        val ImportCollector imports = new ImportCollector(myPackageName)
        var ClassDefinition stopper = null
        val tracking = e.tableCategory.trackingColumns
        var numBins = 1 + e.indexes.size    // the $data record, plus any field required for a bin
        if (tracking !== null)
            numBins += 1;   // another one for the tracking record
        if (e.bins !== null)
            numBins += e.bins.columnName.size

        imports.recurseImports(tracking, true)
        imports.recurseImports(e.pojoType, true)
        imports.addImport(myPackageName, e.name)  // add myself as well
        imports.addImport(e.pojoType);  // TODO: not needed, see above?
        imports.addImport(e.tableCategory.trackingColumns);
        if (e.^extends !== null) {
            imports.addImport(getPackageName(e.^extends), e.^extends.name)
            stopper = e.^extends.pojoType
        }


        return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git
        package «e.packageName»;

        import java.time.Instant;

        import com.aerospike.client.AerospikeClient;
        import com.aerospike.client.Bin;
        import com.aerospike.client.Key;
        import com.aerospike.client.async.AsyncClient;
        import com.aerospike.client.AerospikeException;
        import com.aerospike.client.policy.WritePolicy;
        import com.aerospike.client.listener.WriteListener;
        import com.aerospike.client.listener.RecordSequenceListener;
        import com.aerospike.client.Record;

        import de.jpaw.bonaparte.noSQL.aerospike.AerospikeBinComposer;

        import de.jpaw.bonaparte.core.BonaPortable;
        import de.jpaw.bonaparte.core.BonaPortableClass;
        import de.jpaw.bonaparte.core.MessageParser;
        import de.jpaw.bonaparte.core.MessageComposer;
        import de.jpaw.bonaparte.core.MessageParserException;
        import de.jpaw.bonaparte.core.ObjectValidationException;
        import de.jpaw.bonaparte.core.FoldingComposer;
        import de.jpaw.bonaparte.core.DataConverter;
        import de.jpaw.bonaparte.core.StaticMeta;
        import de.jpaw.bonaparte.pojos.meta.*;

        «imports.createImports»

        @SuppressWarnings("all")
        public class «e.name»«IF e.extendsClass !== null» extends «e.extendsClass.name»«ENDIF»«IF e.^extends !== null» extends «e.^extends.name»«ENDIF» {
            static public final ObjectReference my$data = «writeObjectRef(e.pojoType, "$data")»;
            «IF tracking !== null»
                static public final ObjectReference my$tracking = «writeObjectRef(tracking, "$tracking")»;
            «ENDIF»
            static public final int NUM_BINS = «numBins»;

            static public Key createKey(«e.pojoType.name» obj) throws AerospikeException {
                «IF e.pk.columnName.size == 1»
                    return obj.get«e.pk.columnName.get(0).name.toFirstUpper»();
                «ELSE»
                    StringBuilder keyComposer = new StringBuilder(80);
                    «FOR c : e.pk.columnName SEPARATOR ' keyComposer.append((char)1);'»
                        keyComposer.append(obj.get«c.name.toFirstUpper»());
                    «ENDFOR»
                    return new Key("«e.tableCategory.tablespaceName»", "«e.name»", keyComposer.toString());
                «ENDIF»
            }

            static public Bin [] createBins(«e.pojoType.name» obj) {
                AerospikeBinComposer abc = new AerospikeBinComposer(«numBins», false);
                // FoldingComposer fbc = new FoldingComposer(abc, FoldingComposer.EMPTY_MAPPING, FoldingStrategy.FORWARD_OBJECTS);
                abc.addField(my$data, obj);
                «IF tracking !== null»
                    abc.addField(my$tracking, null);  // TODO!
                «ENDIF»
                «FOR i : e.indexes»
                    abc.addField(«e.pojoType.name».meta$$«i.columns.columnName.get(0).name», obj.get«i.columns.columnName.get(0).name.toFirstUpper»());
                «ENDFOR»
                «IF e.bins !== null»
                    «FOR i : e.bins.columnName»
                        abc.addField(«e.pojoType.name».meta$$«i.name», obj.get«i.name.toFirstUpper»());»
                    «ENDFOR»
                «ENDIF»
                return abc.toArray();
            }

            static public void put(AerospikeClient client, WritePolicy policy, «e.pojoType.name» obj) throws AerospikeException {
                client.put(policy, createKey(obj), createBins(obj));
            }
        }
        '''
    }

}
