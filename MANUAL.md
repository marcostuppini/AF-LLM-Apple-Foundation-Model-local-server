# MenuBarApp - Manuale d'Uso

## Descrizione

**MenuBarApp** è un'applicazione macOS che permette di controllare il backend **AF-LLM** (Apple Foundation Models Local) direttamente dalla barra dei menu. L'app consente di:

- Avviare e fermare il server AI locale
- Visualizzare l'indirizzo dell'endpoint API
- Visualizzare il nome del modello utilizzato
- Regolare i parametri di inferenza (temperatura, top-p, max tokens)

---

## Caratteristiche Tecniche

### Requisiti di Sistema
- **macOS**: 13.0 (Ventura) o successivo
- **macOS AI**: 26.0 (Tahoe) o successivo per Apple Intelligence
- **Processore**: Apple Silicon (ARM64)
- **Xcode**: Installato con Swift 5.9+

### Dipendenze
- **Vapor**: Framework web per Swift (incluso nel backend AF-LLM)
- **FoundationModels**: Framework Apple per l'inferenza AI locale

### Configurazione di Rete
- **Porta**: 8080
- **Bind**: localhost (127.0.0.1)
- **Protocollo**: HTTP (nessuna crittografia, uso locale)

---

## Struttura del Progetto

```
/Volumes/Memory+/AF-LLM/
├── MenuBarApp/              # Sorgenti dell'app menu bar
│   ├── Sources/
│   │   └── MenuBarApp/
│   │       ├── main.swift      # Entry point
│   │       ├── AppDelegate.swift  # (non più usato)
│   │       └── SettingsView.swift # (non più usato)
│   ├── Resources/
│   │   └── Icon.png           # Icona del menu
│   ├── entitlements.plist     # Permessi app
│   └── Package.swift          # Configurazione Swift package
├── Sources/
│   └── AF-LLM/
│       └── main.swift         # Backend server
├── icon.png                  # Icona sorgente
├── MenuBarApp.app/           # App compilata e firmata
└── README.md                 # Documentazione
```

---

## Installazione

### Opzione 1: Uso Diretto
1. Naviga nella cartella del progetto
2. Fai doppio click su `MenuBarApp.app`

### Opzione 2: Installazione in Applicazioni
```bash
cp -R /Volumes/Memory+/AF-LLM/MenuBarApp.app ~/Applications/
```

### Opzione 3: Avvio da Terminale
```bash
open /Volumes/Memory+/AF-LLM/MenuBarApp.app
# oppure
/Volumes/Memory+/AF-LLM/MenuBarApp.app/Contents/MacOS/MenuBarApp &
```

---

## Interfaccia

### Icona nella Barra dei Menu
L'app appare come un'icona nella barra dei menu (in alto a destra dello schermo). Se l'icona personalizzata non carica, viene utilizzata un'icona di sistema (server rack o CPU).

### Menu a Tendina

#### Start Server / Stop Server
- **Start Server**: Avvia il backend AF-LLM
- **Stop Server**: Ferma il backend

#### Open Settings…
Apre un pannello con le impostazioni del modello:
- **Temperature** (0.0 - 2.0): Controlla la casualità delle risposte
  - Valori bassi (0.0-0.5): Risposte più deterministiche
  - Valori medi (0.5-1.0): Bilanciamento
  - Valori alti (1.0-2.0): Maggiore creatività
- **Top-P** (0.0 - 1.0): Nucleus sampling
  - Valori bassi: Risposte più concentrate
  - Valori alti: Risposte più variabili
- **Max Tokens** (1 - 2048): Lunghezza massima della risposta

#### Quit
Chiude l'app e ferma il server (se in esecuzione).

### Tooltip
Passando il mouse sopra l'icona viene mostrato:
- Nome del modello: `apple-local`
- Endpoint: `http://localhost:8080/v1`
- Valori correnti di Temperature, Top-P, Max Tokens

---

## Esempi Pratici

### Esempio 1: Avvio Base
1. Apri MenuBarApp
2. Clicca sull'icona nella barra dei menu
3. Seleziona "Start Server"
4. L'icona cambia stato (il menu mostra "Stop Server")
5. Il server è ora accessibile all'indirizzo `http://localhost:8080/v1`

### Esempio 2: Configurazione per Coding Assist
Per risposte più deterministiche e precise (codice):
```
Temperature: 0.3
Top-P: 0.8
Max Tokens: 512
```

### Esempio 3: Configurazione per Brainstorming
Per risposte più creative:
```
Temperature: 1.2
Top-P: 0.95
Max Tokens: 1024
```

### Esempio 4: Test da Terminale
```bash
curl -s -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "apple-local",
    "messages": [
      {"role": "system", "content": "You are a senior software engineer"},
      {"role": "user", "content": "Explain what this function does: def foo(x): return x * 2"}
    ]
  }' | jq .
```

### Esempio 5: Script Python per Usare l'API
```python
import requests
import json

def ask_ai(prompt: str, system: str = "You are a helpful assistant.") -> str:
    response = requests.post(
        "http://localhost:8080/v1/chat/completions",
        json={
            "model": "apple-local",
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": prompt}
            ]
        }
    )
    data = response.json()
    return data["choices"][0]["message"]["content"]

# Esempio d'uso
risposta = ask_ai("Scrivi una funzione Python per invertire una stringa")
print(risposta)
```

### Esempio 6: Integrazione con OpenCode
1. Apri OpenCode
2. Vai nelle impostazioni provider
3. Aggiungi un nuovo provider:
   - **Provider**: OpenAI-compatible
   - **Base URL**: `http://localhost:8080/v1`
   - **Model**: `apple-local`
   - **API Key**: (lasciare vuoto)

### Esempio 7: Refactoring di Codice
Richiesta al modello:
```
Refactor this Python code to be more Pythonic:
def process_data(data):
    result = []
    for item in data:
        if item > 0:
            result.append(item * 2)
    return result
```

### Esempio 8: Generazione Test
Richiesta al modello:
```
Generate unit tests for this function:
def add(a, b):
    return a + b
```

---

## Ricompilazione

### Ricompilare il Backend AF-LLM
```bash
cd /Volumes/Memory+/AF-LLM
swift build -c release
# L'eseguibile sarà in: .build/arm64-apple-macosx/release/AF-LLM
```

### Ricompilare MenuBarApp
```bash
cd /Volumes/Memory+/AF-LLM/MenuBarApp
swift build -c release
```

### Ricreare il Bundle .app
```bash
cd /Volumes/Memory+/AF-LLM

# Copia l'eseguibile
cp MenuBarApp/.build/arm64-apple-macosx/release/MenuBarApp MenuBarApp.app/Contents/MacOS/

# Firma con il certificato
codesign --force --sign "Developer ID Application: Marco Stuppini (WY6CRB2JW8)" \
         --options runtime \
         --entitlements MenuBarApp/entitlements.plist \
         MenuBarApp.app
```

### Aggiornare l'Icona
1. Sostituisci `icon.png` con una nuova immagine 512x512 PNG
2. Ricompila l'app o copia manualmente l'icona:
   ```bash
   cp nuovaimmagine.png MenuBarApp/Resources/Icon.png
   cp MenuBarApp/Resources/Icon.png MenuBarApp.app/Contents/Resources/
   ```

---

## Manutenzione

### Verifica Firma App
```bash
spctl -a -t exec -vv /Volumes/Memory+/AF-LLM/MenuBarApp.app
```
Dovrebbe mostrare: `accepted`

### Verifica che il Server Sia in Esecuzione
```bash
lsof -i :8080 | grep AF-LLM
```

### Log del Server
Il server stampa output su stdout. Per catturarlo:
```bash
/Volumes/Memory+/AF-LLM/.build/arm64-apple-macosx/release/AF-LLM > server.log 2>&1 &
```

### Pulizia Build Artifacts
```bash
rm -rf /Volumes/Memory+/AF-LLM/.build
rm -rf /Volumes/Memory+/AF-LLM/MenuBarApp/.build
```

### Verifica Connessione al Server
```bash
curl http://localhost:8080/
# Dovrebbe rispondere: "Apple Intelligence Local Coding Backend is running"
```

---

## Risoluzione Problemi

### L'icona non appare nella barra dei menu
1. Verifica che l'app sia in esecuzione: `ps aux | grep MenuBarApp`
2. Controlla se l'icona è nell'area overflow del Centro di Controllo
3. Vai in Impostazioni di Sistema → Barra dei Menu → verifica le app

### Il server non si avvia
1. Controlla se la porta 8080 è già in uso:
   ```bash
   lsof -i :8080
   ```
2. Ferma eventuali processi esistenti:
   ```bash
   killall AF-LLM 2>/dev/null
   ```
3. Verifica che il backend esista:
   ```bash
   ls -la /Volumes/Memory+/AF-LLM/.build/arm64-apple-macosx/release/AF-LLM
   ```

### Errore di firma
Se Gatekeeper blocca l'app:
1. Vai in Impostazioni di Sistema → Privacy e Sicurezza
2. Cerca il messaggio relativo a MenuBarApp
3. Clicca "Apri comunque"

### L'app si chiude improvvisamente
1. Controlla i log di sistema:
   ```bash
   log show --predicate 'eventMessage CONTAINS "MenuBarApp"' --last 1h
   ```
2. Verifica che non ci siano crash reports:
   ```bash
   ls -la ~/Library/Logs/DiagnosticReports/ | grep MenuBar
   ```

---

## Specifiche API

### Endpoint Chat Completions
```
POST http://localhost:8080/v1/chat/completions
Content-Type: application/json

{
  "model": "apple-local",
  "messages": [
    {"role": "system", "content": "Istruzioni di sistema"},
    {"role": "user", "content": "Domanda o task"}
  ]
}
```

### Risposta
```json
{
  "id": "chatcmpl-local",
  "object": "chat.completion",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Risposta del modello"
      },
      "finish_reason": "stop"
    }
  ]
}
```

### Codici di Errore
- `chatcmpl-local-fallback`: Modello non disponibile
- `chatcmpl-local-error`: Formato richiesta non valido

---

## Sicurezza

### Limitazioni
- Il server si lega solo a `localhost`
- Nessuna autenticazione richiesta
- Dati non crittografati

### Raccomandazioni
- Non esporre la porta 8080 su reti pubbliche
- Usare solo in ambienti fidati
- Considerare l'uso di un reverse proxy con HTTPS per uso remoto

---

## Cronologia Versioni

### v1.0.0
- Prima release
- Avvio/fermo server backend
- Impostazioni temperatura, top-p, max tokens
- Icona personalizzata nella barra dei menu
- Firma digitale Developer ID

---

## Contatti e Supporto

Per problemi o domande:
- Verifica la sezione Risoluzione Problemi
- Controlla i log del server
- Assicurati che Apple Intelligence sia abilitato

---

## Licenza

Questo progetto è fornito così com'è per uso personale e di sviluppo.
