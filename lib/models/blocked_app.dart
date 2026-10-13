class InstalledApp {
  const InstalledApp({required this.packageName, required this.name});

  final String packageName;
  final String name;

  factory InstalledApp.fromMap(Map<Object?, Object?> m) =>
      InstalledApp(packageName: m['package']! as String, name: m['name']! as String);
}

class BlockedApp {
  const BlockedApp({required this.packageName, required this.name});

  final String packageName;
  final String name;

  /// Single-letter avatar, as in the mockup.
  String get letter => name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase();

  Map<String, Object?> toJson() => {'package': packageName, 'name': name};

  factory BlockedApp.fromJson(Map<String, Object?> j) =>
      BlockedApp(packageName: j['package']! as String, name: j['name']! as String);
}
