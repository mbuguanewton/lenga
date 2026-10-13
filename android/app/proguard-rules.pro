# WorkManager's Room database is created reflectively (getDeclaredConstructor()),
# and R8 otherwise strips the constructor, crashing the app at startup in release.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { <init>(); }

# ML Kit / Google component registrars are instantiated reflectively at startup.
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }
-keep class com.google.mlkit.common.internal.** { <init>(); }
