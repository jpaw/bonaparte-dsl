package de.jpaw.bonaparte.noSQL.dsl.generator.java

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.generator.java.ImportCollector
import de.jpaw.bonaparte.noSQL.dsl.bDsl.EntityDefinition

import static extension de.jpaw.bonaparte.noSQL.dsl.generator.java.ZUtil.*
import de.jpaw.bonaparte.dsl.bonScript.FieldDefinition
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension

class OffHeapMapGeneratorMain {
    def private static isTenant(FieldDefinition f, EntityDefinition e) {
        return e.tenantClass !== null && e.tenantClass.fields.filter[it == f].head !== null
    }
    
    def public static javaSetOut(EntityDefinition e) {
        val String myPackageName = e.packageName
        val ImportCollector imports = new ImportCollector(myPackageName)
        var ClassDefinition stopper = null
        val tracking = e.tableCategory.trackingColumns
        val updater = e.tableCategory.trackingUpdater
         
        if (tracking !== null) {
            imports.recurseImports(tracking, true)
        }
        imports.recurseImports(e.pojoType, true)
        imports.addImport(myPackageName, e.name)  // add myself as well
        imports.addImport(e.pojoType);
        imports.addImport(e.tenantClass);
        imports.addImport(e.tableCategory.trackingColumns);
        if (e.^extends !== null) {
            imports.addImport(getPackageName(e.^extends), e.^extends.name)
            stopper = e.^extends.pojoType
        }
        val tr = if (tracking !== null) tracking.name else "TrackingBase"
        val dt = '''«e.pojoType.name», «tr»'''
        
        val pkField = e.pk.columnName.head
        val pkRef = DataTypeExtension.get(pkField.datatype)
        val packageSuffix = if (pkRef.isPrimitive) "p" else "w"
        val pkJavaType = if (pkRef.isPrimitive) "long" else "Long"
                
        val refPojo = e.pojoType.extendsClass?.classRef
        imports.addImport(refPojo)
        for (i: e.indexes)
            imports.addImport(i.name)
        
        
        return '''
        // This source has been automatically created by the bonaparte DSL. Do not modify, changes will be lost.
        // The bonaparte DSL is open source, licensed under Apache License, Version 2.0. It is based on Eclipse Xtext2.
        // The sources for bonaparte-DSL can be obtained at www.github.com/jpaw/bonaparte-dsl.git
        package «e.packageName»;

        import java.util.Map;
        import org.slf4j.Logger;
        import org.slf4j.LoggerFactory;

        import de.jpaw.bonaparte.core.BonaPortable;
        import de.jpaw.bonaparte.noSQL.ohm«packageSuffix».OffHeapEntity;
        import de.jpaw.bonaparte.noSQL.ohm«packageSuffix».impl.AbstractRefResolver;
        import de.jpaw.bonaparte.noSQL.ohm«packageSuffix».impl.BonaPortableOffHeapConverter;
        import de.jpaw.bonaparte.noSQL.ohm.impl.OffHeapBonaPortableMap;
        import de.jpaw.bonaparte.noSQL.ohm.impl.PersistenceProviderOHM;
        import de.jpaw.bonaparte.pojos.api.DataWithTracking;
        import de.jpaw.bonaparte.pojos.api«packageSuffix».Ref;
        import de.jpaw.bonaparte.pojos.api.TrackingBase;
        import de.jpaw.bonaparte.pojos.meta.ClassDefinition;
        import de.jpaw.bonaparte.refs.PersistenceException;
        import de.jpaw.bonaparte.refs«packageSuffix».RefResolver;
        import de.jpaw.bonaparte.refs«packageSuffix».ReferencingComposer;
        import de.jpaw.bonaparte.refs«packageSuffix».RequestContext;
        import de.jpaw.collections.DuplicateIndexException;
        import de.jpaw.dp.Jdp;
        import de.jpaw.dp.Provider;
        import de.jpaw.dp.Singleton;
        import de.jpaw.offHeap.OffHeapTransaction;
        import de.jpaw.offHeap.PrimitiveLongKeyOffHeapIndex;
        import de.jpaw.offHeap.PrimitiveLongKeyOffHeapMap;
        import de.jpaw.offHeap.Shard;

        «imports.createImports»

        // @SuppressWarnings("all")
        @Singleton
        public class «e.name» extends AbstractRefResolver<«refPojo.name», «dt»>
          implements OffHeapEntity, RefResolver<«refPojo.name», «dt»>«IF e.implementsJavaInterface !== null», «e.implementsJavaInterface.qualifiedName»«ENDIF» {
            private static final Logger LOGGER = LoggerFactory.getLogger(«e.name».class);
            static final public String ENTITY_NAME = "«refPojo.name»";
            static protected final int HASH_MAP_SIZE = 100_000;
            static protected PrimitiveLongKeyOffHeapMap<BonaPortable> db;
            «FOR i: e.indexes»
                static protected PrimitiveLongKeyOffHeapIndex<BonaPortable> index«i.name.name»;
            «ENDFOR»
            «IF tracking !== null»
                private final «updater.qualifiedName» updater = new «updater.qualifiedName»();
            «ENDIF»
            private final Provider<PersistenceProviderOHM> ohmProvider = Jdp.getProvider(PersistenceProviderOHM.class);
            protected OffHeapTransaction transaction;
            protected final Provider<RequestContext> contextProvider = Jdp.getProvider(RequestContext.class);
            protected ReferencingComposer myComposer;

            @Override
            public void open(Shard shard,                       // transaction management
                    BonaPortableOffHeapConverter converter,     // data object converter
                    ReferencingComposer composer,               // index composer
                    Map<ClassDefinition, RefResolver<Ref, ?, ?>> resolvers
                ) {
                entityName = ENTITY_NAME;
                myComposer = composer;
                builder = composer.getBuilder();
                this.transaction = shard.getOwningTransaction();
                resolvers.put(«refPojo.name».class$MetaData(), (RefResolver)this);
                «FOR i: e.indexes»
                    index«i.name.name» = new PrimitiveLongKeyOffHeapIndex<BonaPortable>(null, HASH_MAP_SIZE, 0x«IF i.isIsUnique»b«ELSE»a«ENDIF»1, "«i.name.name»");
                «ENDFOR»

                OffHeapBonaPortableMap.Builder builder = new OffHeapBonaPortableMap.Builder(converter);
                builder.setName(ENTITY_NAME).setShard(shard).setHashSize(HASH_MAP_SIZE);
                db = builder.build();
            }

            @Override
            public void close() {
                db.close();
                «FOR i: e.indexes»
                    index«i.name.name».close();
                «ENDFOR»
            }

            «FOR i: e.indexes»
                private int indexHash«i.name.name»(RequestContext ctx, int pos, «e.pojoType.name» data) {
                    «FOR f: i.columns.columnName»
                        «IF f.isTenant(e)»
                            myComposer.addField(«e.tenantClass.name».meta$$«f.name», ctx.getTenantRef());
                        «ELSE»
                            myComposer.addField(«e.pojoType.name».meta$$«f.name», data.get«f.name.toFirstUpper»());
                        «ENDIF»
                    «ENDFOR»
                    return indexHash(pos);
                }
            «ENDFOR»

            @Override
            public void uncachedRemove(DataWithTracking<«dt»> previous) {
                RequestContext ctx = contextProvider.get();
                ohmProvider.get();      // register transaction
                long key = previous.getData().getObjectRef();
                db.delete(key);

                «IF e.indexes.size > 0»
                    int currentWriterPos = builder.length();
                    int thisIndexHash;
                    «FOR i: e.indexes»
                        thisIndexHash = indexHash«i.name.name»(ctx, currentWriterPos, previous.getData());
                        // LOGGER.info("DELETE: Index hash for «i.name.name» is " + thisIndexHash);
                        index«i.name.name».deleteDirect(key, thisIndexHash);
                        // index.delete(key, indexHash, builder.getCurrentBuffer(), currentWriterPos, builder.length() - currentWriterPos);
                        builder.setLength(currentWriterPos);
                    «ENDFOR»
                «ENDIF»
            }

            private boolean setDTO(long key, BonaPortable obj) {
                int currentWriterPos = builder.length();
                // myComposer.excludeObject(obj);  // obj is Data with tracking!
                myComposer.addField(DataWithTracking.meta$$this, obj);
                boolean existed = db.setFromBuffer(key, builder.getCurrentBuffer(), currentWriterPos, builder.length() - currentWriterPos);
                builder.setLength(currentWriterPos);
                return existed;
            }

            @Override
            protected DataWithTracking<«dt»> uncachedCreate(«e.pojoType.name» obj) throws PersistenceException {
                RequestContext ctx = contextProvider.get();
                ohmProvider.get();
                long key = obj.getObjectRef();
                DataWithTracking<«dt»> dwt = new DataWithTracking<>();
                dwt.setData(obj);
                «IF tracking !== null»
                    dwt.setTracking(new «tr»());
                «ENDIF»
                updater.preCreate(ctx, dwt.getTracking());

                // LOGGER.info("records in DB = " + db.size() + ", records in index = " + index.size());

                // set a safepoint
                int mySafepoint = transaction.defineSafepoint();
                
                «IF e.indexes.size > 0»
                    // add the index first (highest probability that it fails)
                    int currentWriterPos = builder.length();
                    int thisIndexHash;
                    «FOR i: e.indexes»
                        thisIndexHash = indexHash«i.name.name»(ctx, currentWriterPos, obj);
                        // LOGGER.info("CREATE: Index hash for «i.name.name» is " + thisIndexHash);
                        «IF i.isIsUnique»
                            try {
                                index«i.name.name».createDirect(key, thisIndexHash, builder.getCurrentBuffer(), currentWriterPos, builder.length() - currentWriterPos);
                            } catch (DuplicateIndexException e) {
                                transaction.rollbackToDefinedSafepoint(mySafepoint);
                                throw new PersistenceException(PersistenceException.DUPLICATE_UNIQUE_INDEX, key, ENTITY_NAME, "«i.name.name»", null);
                            } finally {
                                builder.setLength(currentWriterPos);
                            }
                        «ELSE»
                            index«i.name.name».createDirect(key, thisIndexHash, builder.getCurrentBuffer(), currentWriterPos, builder.length() - currentWriterPos);
                            builder.setLength(currentWriterPos);
                        «ENDIF»
                    «ENDFOR»
                «ENDIF»

                if (setDTO(key, dwt)) {
                    transaction.rollbackToDefinedSafepoint(mySafepoint);
                    throw new PersistenceException(PersistenceException.RECORD_ALREADY_EXISTS, key, ENTITY_NAME);
                }
                return dwt;
            }

            @Override
            protected void uncachedUpdate(DataWithTracking<«dt»> dwt, «e.pojoType.name» obj) throws PersistenceException {
                ohmProvider.get();
                // milestone 1: assumed no change of any index
                // therefore only the obj must be updated. Here we assume no malfunction can happen.
                dwt.setData(obj);
                updater.preUpdate(contextProvider.get(), dwt.getTracking());        // just overwrite, no need to keep the old one in this case
                long key = obj.getObjectRef();
                
                if (!setDTO(key, dwt))
                    throw new PersistenceException(PersistenceException.RECORD_DOES_NOT_EXIST_ILE, key, ENTITY_NAME);
            }
        
            @Override
            public void flush() {
            }
        
            // cases null and filled objectRef have been covered by the abstract superclass already
            // read only, no tx required 
            @Override
            protected «pkJavaType» getUncachedKey(«refPojo.name» refObject) throws PersistenceException {
                RequestContext ctx = contextProvider.get();
                «FOR i: e.indexes»
                    if (refObject instanceof «i.name.name») {
                        // return myLookup.getKeyForIndex((«i.name.name»)refObject, index«i.name.name», «i.name.name».meta$$this);
                        «i.name.name» data = («i.name.name»)refObject;
                        int currentWriterPos = builder.length();
                        «FOR f: i.columns.columnName»
                            «IF f.isTenant(e)»
                                myComposer.addField(«e.tenantClass.name».meta$$«f.name», ctx.getTenantRef());
                            «ELSE»
                                myComposer.addField(«e.pojoType.name».meta$$«f.name», data.get«f.name.toFirstUpper»());
                            «ENDIF»
                        «ENDFOR»
                        int indexHash = indexHash(currentWriterPos);
                        // LOGGER.info("LOOKUP: Index hash for «i.name.name» is " + indexHash);
                        long key = index«i.name.name».getUniqueKeyByIndex(builder.getCurrentBuffer(), currentWriterPos, builder.length() - currentWriterPos, indexHash);
                        builder.setLength(currentWriterPos);
                        if (key <= 0)
                            throw new PersistenceException(PersistenceException.NO_RECORD_FOR_INDEX, key, null, "«i.name.name»", data.toString());
                        // restore position to previous state
                        return key;
                    }
                «ENDFOR»
                throw new PersistenceException(PersistenceException.UNKNOWN_INDEX_TYPE, 0L, ENTITY_NAME, refObject.get$PQON(), null);
            }

            @Override
            protected DataWithTracking<«dt»> getUncached(«pkJavaType» ref) {
                return (DataWithTracking<«dt»>) db.get(ref);
            }
        }
        '''
    }
    
    
}