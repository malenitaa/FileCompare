# FileCompare

Una app de macOS nativa (Swift + SwiftUI + AppKit, sin Electron) para comparar dos archivos de texto o código lado a lado — una versión simple de las herramientas de "compare" de BBEdit o Notepad++. Pensada como herramienta de uso real: prioriza velocidad con archivos grandes y precisión del diff por sobre la estética.

## Funcionalidad

- Dos paneles lado a lado, editables, o una vista unificada estilo `git diff`.
- Abrir archivos por drag & drop, botón de carpeta (`NSOpenPanel`), o pegando texto directo en cualquier panel.
- Resaltado línea por línea: agregado (verde), eliminado (rojo), modificado (naranja), sin cambios — colores del sistema con opacidad baja.
- Resaltado a nivel de palabra/carácter dentro de las líneas modificadas.
- Scroll sincronizado entre ambos paneles (proporcional, no pixel a pixel, porque los dos archivos rara vez tienen la misma cantidad de líneas).
- Números de línea en ambos paneles.
- Navegación entre cambios: botones en la toolbar o `⌘↓` / `⌘↑`.
- Contador de líneas agregadas/eliminadas/modificadas en la toolbar.
- Toggles para ignorar espacios en blanco y mayúsculas/minúsculas al comparar.
- Copiar el contenido de un panel al otro, y guardar cada panel de vuelta a su archivo original (o "Guardar como" si no tiene uno).
- Recuerda los últimos dos archivos abiertos entre sesiones.
- Aviso no bloqueante en archivos grandes (ver más abajo).

## El algoritmo de diff

En vez de sumar una dependencia externa, uso `CollectionDifference` / `.difference(from:)` de la **standard library de Swift** (disponible desde Swift 5.1). Es una implementación de Myers con refinamiento estilo Heckel para detectar movimientos, con complejidad O(n·d) donde *d* es la cantidad de elementos que difieren. Evalué agregar `DifferenceKit` o `Differ`, pero como Swift ya trae una implementación mantenida por el propio lenguaje, sin riesgo de quedar abandonada y sin agregar una dependencia externa a un proyecto chico, usar la stdlib es la opción más simple y confiable.

Se corre en dos pasadas:

1. **Diff de líneas**: se comparan los archivos línea por línea. Las líneas que Myers marca como "remove" e "insert" en la misma posición relativa dentro de un mismo bloque de cambios se emparejan como **modificada** (en vez de mostrarlas como una eliminación + un agregado sueltos), para poder resaltar la diferencia de palabras dentro de esa línea.
2. **Diff de palabras**: sólo sobre las líneas ya marcadas como "modificada" del paso anterior —nunca sobre el archivo completo— se tokeniza cada línea (en corridas de espacios, palabras y caracteres de puntuación) y se vuelve a correr `difference(from:)` sobre esos tokens. Así el costo extra es proporcional al tamaño del cambio, no al tamaño del documento.

Los toggles de "ignorar espacios" e "ignorar mayúsculas" comparan una versión normalizada de cada línea/token, pero siempre muestran el texto original.

## Límites de tamaño de archivo

Por default, si alguno de los dos archivos supera **5 MB** o **50.000 líneas**, la app sigue haciendo el diff línea por línea normalmente, pero **desactiva el resaltado a nivel de palabra** (que es el paso más costoso) para mantener la interfaz responsiva, y lo indica con un aviso en la barra superior. El cómputo del diff siempre corre en un hilo de background (nunca en el hilo principal), con un debounce de 300ms mientras se escribe, así que tipear en un archivo grande no bloquea la UI. Este umbral es una constante (`DiffOptions.largeFileByteThreshold` / `largeFileLineThreshold`) fácil de ajustar en el código si hace falta.

Por encima de 50 MB se muestra además un aviso de que la app puede volverse lenta (no hay un límite duro que impida abrir el archivo).

## Arquitectura

- **SwiftUI** para la estructura general (toolbar, toggles, layout).
- **AppKit** (`NSTextView` + un `NSRulerView` propio para los números de línea) para cada panel de texto, envuelto en un `NSViewRepresentable`. Esto es necesario para tener performance real con archivos largos y poder pintar los colores del diff como atributos de texto sin pelear con las limitaciones de `TextEditor`/`Text` de SwiftUI.
- Sin sandbox de macOS ni telemetría: la app es 100% local, no hace ninguna llamada de red.
- Deployment target: macOS 13.0. Swift language mode 5.

Estructura del código:

```
FileCompare/
├── Models/DiffModels.swift        # DiffLineKind, DiffLine, DiffSegment, DiffResult, DiffSummary
├── Diff/
│   ├── DiffEngine.swift           # orquesta línea + palabra
│   ├── LineDiffEngine.swift       # diff de líneas + emparejado modificado
│   ├── WordDiffEngine.swift       # tokenizer + diff de palabras
│   └── DiffOptions.swift          # ignoreWhitespace, ignoreCase, umbrales
├── ViewModels/CompareViewModel.swift
├── Views/                         # SwiftUI + AppKit (NSViewRepresentable)
└── Support/                       # FileLoader, RecentFilesStore, DiffColors
```

## Clonar y compilar

Requisitos: macOS 13+ y Xcode 15+.

```bash
git clone https://github.com/malenitaa/FileCompare.git
cd FileCompare
open FileCompare.xcodeproj
```

Compilá y corré con `⌘R` desde Xcode. El proyecto está generado con [XcodeGen](https://github.com/yonaskolb/XcodeGen) a partir de `project.yml`, pero el `.xcodeproj` ya está commiteado — no hace falta instalar XcodeGen para compilar. Si modificás `project.yml`, regenerá con:

```bash
xcodegen generate
```

Para correr los tests unitarios (diff de líneas y de palabras):

```bash
xcodebuild -project FileCompare.xcodeproj -scheme FileCompare -destination 'platform=macOS' test
```

## Licencia

MIT — ver [LICENSE](LICENSE).
