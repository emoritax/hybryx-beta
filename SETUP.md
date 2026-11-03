# HYBRYX Beta — cómo correrla

Este zip trae solo `lib/` y `pubspec.yaml`. Las carpetas de Android las genera Flutter.

## 1. Crear el proyecto base

```bash
flutter create --org com.hybryx --platforms android hybryx_beta
cd hybryx_beta
```

## 2. Reemplazar con el código de la beta

- Borra la carpeta `lib/` que creó Flutter y pega la `lib/` de este zip.
- Reemplaza `pubspec.yaml` con el de este zip.
- **Borra `test/widget_test.dart`**: el ejemplo de Flutter busca una clase `MyApp` que ya no existe.

## 3. Instalar dependencias y revisar

```bash
flutter pub get
flutter analyze      # debe salir sin errores (puede haber "info")
```

## 4. Correr en tu celular Android

1. En el celular: Ajustes → Acerca del teléfono → toca 7 veces "Número de compilación" → aparece "Opciones de desarrollador" → activa "Depuración USB".
2. Conecta por USB y acepta el permiso en el celular.
3. `flutter devices` (debe aparecer) y luego `flutter run`.

## 5. APK para testers

```bash
flutter build apk --release
# queda en build/app/outputs/flutter-apk/app-release.apk
```

## Notas

- Los datos viven en `hybryx_beta.db` dentro del celular. Desinstalar la app los borra.
- Si cambias tablas en `db.dart`, sube `version` y agrega `onUpgrade`; o, mientras sea beta, desinstala y reinstala.
- Requiere Flutter 3.35+ (Dart 3.9). Verifica con `flutter --version`.
