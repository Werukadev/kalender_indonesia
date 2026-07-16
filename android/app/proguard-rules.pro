# device_calendar serializes its native Kotlin model classes to JSON via
# Gson reflection to send them across the platform channel. Without these
# keep rules, R8 release-build minification renames those classes' fields,
# so Gson serializes under the renamed names and Dart's Calendar.fromJson/
# Event.fromJson (which look up fixed keys like "id") get null for every one
# of them — confirmed as a real bug in a sibling app using this same plugin.
-keep class com.builttoroam.devicecalendar.models.** { *; }

-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken
-keep class * extends com.google.gson.reflect.TypeToken
