# .ci/debug.keystore

Clave de firma FIJA para los APK de la beta (alias `androiddebugkey`, contraseña `android`).

**Por qué existe:** cada build de GitHub Actions corre en una máquina nueva. Sin esta clave,
cada APK quedaría firmado distinto y Android no dejaría instalar una versión encima de la otra.

**Solo para la beta privada.** Antes de publicar en Play Store: crear un keystore de release
propio, guardarlo como secreto del repo (Settings → Secrets → Actions) y NO en el código.
