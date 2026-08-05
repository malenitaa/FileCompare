# FileCompare

[![Descargar última versión](https://img.shields.io/github/v/release/malenitaa/FileCompare?label=descargar&color=6b46c1)](https://github.com/malenitaa/FileCompare/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![macOS](https://img.shields.io/badge/platform-macOS-lightgrey)](#)

**FileCompare** es una app nativa de **macOS** para **comparar archivos de
texto o código lado a lado** (diff visual) — una versión simple de las
herramientas de "compare"/diff de BBEdit o Notepad++. Escrita en
**Swift/SwiftUI**, sin Electron, sin dependencias externas, 100% local.

- Dos paneles lado a lado (editables) o una vista unificada estilo `git diff`.
- Resaltado línea por línea y también a nivel de palabra dentro de cada línea.
- Abrí archivos por drag & drop, botón de carpeta, o pegando texto directo.
- Scroll sincronizado, números de línea, navegación entre cambios (`⌘↓` / `⌘↑`).
- Toggles para ignorar espacios/mayúsculas, y para quitar texto antes de comparar.
- **Modo "Conjuntos"**: compara dos listas sin importar el orden (por ejemplo
  el "following"/"followers" exportado de Instagram), mostrando "sólo en A",
  "en ambos" y "sólo en B".
- Guardar cada panel de vuelta a su archivo, deshacer/rehacer, recuerda los
  últimos archivos abiertos.

## Descargar y usar

1. Andá a [Releases](https://github.com/malenitaa/FileCompare/releases) y
   bajate el `.zip` de la última versión.
2. Descomprimilo y arrastrá `FileCompare.app` a tu carpeta de Applications.
3. La primera vez que la abras, macOS puede avisar que **"no se puede
   verificar el desarrollador"**. Es normal para cualquier app open-source
   sin firma de Apple — no significa que esté rota:
   - Click derecho (o Ctrl+click) sobre la app en Applications.
   - Elegí "Abrir".
   - Confirmá en el diálogo que aparece.
   Con eso alcanza, una sola vez. **No hace falta desactivar Gatekeeper**
   ni ninguna protección del sistema — si algo te pide eso, desconfiá.

Requiere macOS 13 o superior.

## Privacidad y seguridad

- **Cero red.** La app no hace ninguna llamada a internet, nunca — todo el
  diff se calcula en tu máquina.
- **Cero telemetría.** No hay cuentas, login ni tracking.
- Solo lee y escribe los archivos que vos elegís abrir/guardar. No accede
  a nada más de tu disco.
- El código completo es Swift, corto y legible — está pensado para que
  puedas revisarlo antes de correrlo si querés.

## Para desarrolladores

Requisitos: macOS 13+ y Xcode 15+.

```bash
git clone https://github.com/malenitaa/FileCompare.git
cd FileCompare
open FileCompare.xcodeproj
```

Compilá y corré con `⌘R` desde Xcode.

## ¿Te sirvió?

Si te resultó útil y querés bancar el proyecto:

- 🇦🇷 [Cafecito](https://cafecito.app/rezamalena) (pesos argentinos)
- 🌎 [Ko-fi](https://ko-fi.com/malenitaa) (dólares)

## Licencia

MIT — ver [LICENSE](LICENSE).
