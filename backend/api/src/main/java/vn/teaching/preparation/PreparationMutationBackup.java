package vn.teaching.preparation;

import com.google.gson.*;
import java.nio.file.*;
import java.util.*;

    /** Only this plan is mutated under the shared store lock; preserve every preexisting byte. */
final class PreparationMutationBackup {
        final PreparationStore store;
        final String plan;final Map<Path,byte[]> original=new LinkedHashMap<>();final Set<Path> assetFiles,indexFiles;final boolean hadAssets,hadRevisions,hadIndices;
        PreparationMutationBackup(PreparationStore store,String plan,int revision)throws Exception{
            this.store=store;this.plan=plan;Path dir=store.root.resolve(plan);
            for(Path path:List.of(dir.resolve("state.json"),dir.resolve("revisions").resolve(revision+".json"),store.root.getParent().resolve("plannings").resolve(plan+".json")))original.put(path,Files.isRegularFile(path)?Files.readAllBytes(path):null);
            assetFiles=files(dir.resolve("assets"));indexFiles=files(store.root.resolve("assets"));hadAssets=Files.isDirectory(dir.resolve("assets"));hadRevisions=Files.isDirectory(dir.resolve("revisions"));hadIndices=Files.isDirectory(store.root.resolve("assets"));
        }
        Set<Path> files(Path dir)throws Exception{if(!Files.isDirectory(dir))return new HashSet<>();try(var stream=Files.list(dir)){return new HashSet<>(stream.filter(Files::isRegularFile).toList());}}
        void restore()throws Exception{
            Path dir=store.root.resolve(plan),indices=store.root.resolve("assets");Exception failure=null;
            Set<Path> extra=files(dir.resolve("assets"));extra.removeAll(assetFiles);
            // register can fail after copying bytes, or after writing an index but before state.
            for(Path file:extra)try{Files.deleteIfExists(file);Files.deleteIfExists(indices.resolve(file.getFileName()+".json"));}catch(Exception e){if(failure==null)failure=e;else failure.addSuppressed(e);}
            if(Files.isDirectory(indices))try(var stream=Files.list(indices)){for(Path index:stream.filter(Files::isRegularFile).toList()){if(indexFiles.contains(index))continue;JsonObject asset=store.read(index);if(PreparationStore.str(asset,"planId").equals(plan))try{Files.deleteIfExists(index);}catch(Exception e){if(failure==null)failure=e;else failure.addSuppressed(e);}}}
            for(var entry:original.entrySet())try{if(entry.getValue()==null)Files.deleteIfExists(entry.getKey());else Files.write(entry.getKey(),entry.getValue());}catch(Exception e){if(failure==null)failure=e;else failure.addSuppressed(e);}
            for(Path created:List.of(dir.resolve("assets"),dir.resolve("revisions"),indices)){boolean existed=created.equals(indices)?hadIndices:created.endsWith("assets")?hadAssets:hadRevisions;if(!existed&&Files.isDirectory(created)){boolean empty;try(var list=Files.list(created)){empty=list.findAny().isEmpty();}if(empty)Files.deleteIfExists(created);}}
            if(failure!=null)throw failure;
        }
    }
