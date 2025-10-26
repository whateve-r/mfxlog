# 🔑 API Keys - Squad of Systems (SoS)

## ⚠️ IMPORTANTE: SEGURIDAD

**NUNCA** commitear este archivo a Git una vez que agregues tus API Keys reales.

Agregar al `.gitignore`:
```
Docs/API_KEYS.md
**/API_KEYS.md
```

---

## 📊 FRED API (Federal Reserve Economic Data)

### Descripción
API gratuita del Federal Reserve de St. Louis para datos económicos (tasas de interés, inflación, etc.)

### Obtener API Key

1. Ir a: https://fred.stlouisfed.org/
2. Crear cuenta gratuita
3. Ir a: https://fred.stlouisfed.org/docs/api/api_key.html
4. Solicitar API Key (aprobación instantánea)

### Límites
- **Requests:** 1000 por día
- **Rate limit:** Sin límite por minuto

### Series Usadas en SoS

| Serie ID | Descripción | Usado en |
|----------|-------------|----------|
| DGS2 | US 2-Year Treasury Rate | E1_RateSpread |
| DGS10 | US 10-Year Treasury Rate | E1_RateSpread |
| DFF | Federal Funds Rate | E2_CarryTrade |
| T10Y2Y | 10-Year/2-Year Spread | E1_RateSpread |

### Tu API Key

```
FRED_API_KEY = YOUR_KEY_HERE
```

**Ejemplo (NO USAR):**
```
FRED_API_KEY = abcd1234efgh5678ijkl9012mnop3456
```

### Test de Conectividad

```mql5
// Copiar en Script de MT5 para testear
#include <SoS_APIHandler.mqh>

void OnStart() {
    APIHandler api;
    api.SetFREDKey("YOUR_KEY_HERE");
    
    double value = api.GetFREDValue("DGS10");
    Print("DGS10 = ", value);
}
```

---

## 🌪️ Alpha Vantage API

### Descripción
API gratuita para datos de mercado en tiempo real (VIX, noticias, sentimiento, etc.)

### Obtener API Key

1. Ir a: https://www.alphavantage.co/support/#api-key
2. Completar formulario (nombre + email)
3. Recibir API Key por email (instantáneo)

### Límites (Plan Gratuito)
- **Requests:** 5 por minuto
- **Requests:** 500 por día
- **Upgrade:** Planes pagos disponibles ($49.99/mes para 75 req/min)

### Endpoints Usados en SoS

| Endpoint | Descripción | Usado en |
|----------|-------------|----------|
| GLOBAL_QUOTE | Cotización actual (VIX) | StormGuard |
| NEWS_SENTIMENT | Noticias y sentiment | E6_NewsSentiment |
| TIME_SERIES_INTRADAY | Datos intraday | (Futuro) |

### Tu API Key

```
ALPHAVANTAGE_API_KEY = YOUR_KEY_HERE
```

**Ejemplo (NO USAR):**
```
ALPHAVANTAGE_API_KEY = DEMO
```

⚠️ **Nota:** La key "DEMO" funciona pero tiene límites más restrictivos (5 req/día).

### Test de Conectividad

```mql5
// Copiar en Script de MT5 para testear
#include <SoS_APIHandler.mqh>

void OnStart() {
    APIHandler api;
    api.SetAlphaVantageKey("YOUR_KEY_HERE");
    
    double vix = api.GetVIX();
    Print("VIX = ", vix);
}
```

---

## 🔧 Configuración en StormGuard

Una vez obtenidas las API Keys:

1. **Abrir StormGuard.mq5 en MetaEditor**
2. **Adjuntar a gráfico en MT5**
3. **Configurar en parámetros:**

```
=== VIX MONITORING ===
Enable VIX: true
VIX Update Interval: 300 (segundos)
Alpha Vantage Key: [PEGAR TU KEY AQUÍ]
```

4. **Verificar en logs:**
```
✅ Alpha Vantage API configurada
📡 Actualizando VIX...
✅ VIX actualizado: 15.34
```

---

## 📝 Script de Test Completo

Crear archivo: `Tests/test_api_handler.mq5`

```mql5
//+------------------------------------------------------------------+
//| test_api_handler.mq5 - Test de APIs                              |
//+------------------------------------------------------------------+
#property script_show_inputs

#include "..\Include\SoS_APIHandler.mqh"

input string InpFREDKey = "";           // FRED API Key
input string InpAlphaVantageKey = "";   // Alpha Vantage API Key

void OnStart() {
    Print("==================================================");
    Print("🔍 Testing API Handler...");
    Print("==================================================");
    
    APIHandler api;
    
    // Configurar keys
    if(InpFREDKey != "") api.SetFREDKey(InpFREDKey);
    if(InpAlphaVantageKey != "") api.SetAlphaVantageKey(InpAlphaVantageKey);
    
    // Ejecutar tests
    bool result = api.TestAPIs();
    
    if(result) {
        Print("✅ TODOS LOS TESTS PASARON");
    } else {
        Print("❌ ALGUNOS TESTS FALLARON");
    }
}
```

**Uso:**
1. Compilar `test_api_handler.mq5`
2. Adjuntar a cualquier gráfico
3. Ingresar API Keys en parámetros
4. Ejecutar
5. Verificar logs en "Experts" tab

---

## ⚠️ Rate Limit Management

### Alpha Vantage (5 req/min)

**Estrategia en StormGuard:**
- VIX se actualiza cada **5 minutos** (300 segundos)
- Máximo **12 requests/hora** = 288 requests/día
- Bien dentro del límite de 500/día

**Si alcanzas el límite:**
```
⚠️ Alpha Vantage: Rate limit alcanzado
```

**Soluciones:**
1. Aumentar `InpVIXUpdateInterval` (ej. 600 segundos = 10 min)
2. Upgrade a plan premium ($49.99/mes)
3. Usar múltiples API Keys (rotación)

### FRED (1000 req/día)

**Estrategia en E1_RateSpread:**
- Consultar solo 1-2 veces por hora
- Cachear valores en GlobalVariables
- Máximo **48 requests/día** (cada 30 min)

---

## 🛡️ Seguridad de API Keys

### ✅ Buenas Prácticas

1. **NUNCA** hardcodear keys en el código:
   ```cpp
   // ❌ MAL
   string apiKey = "abcd1234efgh5678";
   
   // ✅ BIEN
   input string InpAPIKey = "";  // Usuario ingresa en parámetros
   ```

2. **Agregar a .gitignore:**
   ```
   Docs/API_KEYS.md
   **/API_KEYS.md
   *.ini
   ```

3. **NO compartir screenshots** con keys visibles

4. **Regenerar keys** si se filtran

### 🔄 Cómo Regenerar Keys

**FRED:**
1. Ir a: https://fred.stlouisfed.org/docs/api/api_key.html
2. Solicitar nueva key (instantáneo)

**Alpha Vantage:**
1. No hay opción de regeneración
2. Solicitar nueva key con otro email
3. Desactivar key antigua

---

## 📞 Soporte de APIs

### FRED
- **Documentación:** https://fred.stlouisfed.org/docs/api/
- **Email:** api@stlouisfed.org
- **FAQ:** https://fred.stlouisfed.org/docs/api/api_faq.html

### Alpha Vantage
- **Documentación:** https://www.alphavantage.co/documentation/
- **Email:** support@alphavantage.co
- **Slack:** https://www.alphavantage.co/slack/

---

## ✅ Checklist de Configuración

- [ ] Obtener FRED API Key
- [ ] Obtener Alpha Vantage API Key
- [ ] Habilitar URLs en MT5 WebRequest
- [ ] Testear FRED API con script
- [ ] Testear Alpha Vantage API con script
- [ ] Configurar StormGuard con keys
- [ ] Verificar VIX se actualiza correctamente
- [ ] Agregar API_KEYS.md a .gitignore

---

**Última actualización:** 2025-10-26
