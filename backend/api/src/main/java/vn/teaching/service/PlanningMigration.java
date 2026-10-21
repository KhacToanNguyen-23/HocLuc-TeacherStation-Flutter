package vn.teaching.service;

import com.google.gson.*;
import java.util.*;

/** One-time stable locators; original bytes are backed up by PlanningService. */
final class PlanningMigration {
    static boolean upgrade(JsonObject lesson) {
        boolean changed = false;
        if (!lesson.has("boardRevision")) { lesson.addProperty("boardRevision", 0); changed = true; }
        int count = lesson.has("pages") ? lesson.getAsJsonArray("pages").size() : 0;
        JsonArray old = lesson.has("pageIds") ? lesson.getAsJsonArray("pageIds") : new JsonArray();
        JsonArray ids = new JsonArray(); Set<String> used = new HashSet<>();
        for (int i = 0; i < count; i++) {
            String id = i < old.size() && old.get(i).isJsonPrimitive() ? old.get(i).getAsString() : "";
            if (id.isBlank() || !used.add(id)) { id = UUID.randomUUID().toString(); used.add(id); changed = true; }
            ids.add(id);
        }
        if (!ids.equals(old)) { lesson.add("pageIds", ids); changed = true; }
        if (!lesson.has("planningSchemaVersion") || lesson.get("planningSchemaVersion").getAsInt() < 2) {
            lesson.addProperty("planningSchemaVersion", 2); changed = true;
        }
        return changed;
    }
}
