typedef PreparationMap = Map<String, dynamic>;

List<PreparationMap> preparationRows(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <PreparationMap>[];
