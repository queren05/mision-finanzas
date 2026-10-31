-keep class es.david.findemes.model.** { *; }
# WorkManager (viene con los anuncios): sin esto, el optimizador borra su base de datos y el juego se cierra al abrir
-keep class * extends androidx.room.RoomDatabase { <init>(); }
