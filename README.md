# AF-LLM - Apple Foundation Models Local Backend

Backend locale per Apple Intelligence, accessibile tramite API OpenAI-compatible.

## Struttura

```
AF-LLM/
├── MenuBarApp/           # App per controllare il server dalla barra dei menu
│   ├── Sources/          # Codice sorgente
│   ├── Resources/        # Icona
│   └── Package.swift      # Configurazione Swift
├── Sources/
│   └── AF-LLM/          # Backend server
│       └── main.swift
├── MenuBarApp.app/       # App compilata e firmata (doppia-click per avviare)
├── icon.png              # Icona sorgente
├── MANUAL.md             # Manuale d'uso completo
└── README.md            # Questo file
```

## Quick Start

### Avviare l'App
```bash
open /Volumes/Memory+/AF-LLM/MenuBarApp.app
```

### Avviare il Server
1. Clicca sull'icona nella barra dei menu
2. Seleziona "Start Server"

### Testare il Server
```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"apple-local","messages":[{"role":"user","content":"Ciao"}]}'
```

### Integrazione OpenCode
- Provider: OpenAI-compatible
- Base URL: http://localhost:8080/v1
- Model: apple-local
- API Key: (vuota)

## Documentazione

Vedi [MANUAL.md](MANUAL.md) per il manuale completo con:
- Caratteristiche tecniche
- Guida all'uso dettagliata
- Esempi pratici
- Guida alla manutenzione
- Risoluzione problemi

## Ricompilazione

```bash
# Backend
cd /Volumes/Memory+/AF-LLM
swift build -c release

# MenuBarApp
cd /Volumes/Memory+/AF-LLM/MenuBarApp
swift build -c release
```

## Requisiti
- macOS 26.0+ (Apple Intelligence)
- Apple Silicon
- Xcode
