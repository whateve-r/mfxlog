# 🔧 Instrucciones de Compilación y Testing - SoS System

## ✅ **FASE 2 COMPLETADA**

Todos los Expert Advisors han sido implementados:
- ✅ StormGuard.mq5 (Master EA)
- ✅ E1_RateSpread.mq5
- ✅ E2_CarryTrade.mq5
- ✅ E3_VWAP_Breakout.mq5
- ✅ E4_VolArbitrage.mq5
- ✅ E5_ORB.mq5
- ✅ E6_NewsSentiment.mq5
- ✅ E7_Scalper.mq5

**Total:** 1 Master + 7 Slaves = **8 Expert Advisors**

---

## 📝 **PASO 1: Copiar Archivos a MT5**

### Ubicación de los archivos

Los archivos están en:
```
c:\Users\manud\OneDrive\Escritorio\tfg\mfxlog\
```

### Destino en MT5

Copiar a la carpeta de datos de MT5:
```
C:\Users\[TuUsuario]\AppData\Roaming\MetaQuotes\Terminal\[TU_ID_MT5]\MQL5\
```

**Para encontrar la carpeta correcta:**
1. Abrir MT5
2. Menú: `Archivo → Abrir carpeta de datos`
3. Navegar a `MQL5\`

### Estructura a copiar:

```
MQL5/
├── Experts/
│   ├── StormGuard.mq5
│   └── Slaves/
│       ├── E1_RateSpread.mq5
│       ├── E2_CarryTrade.mq5
│       ├── E3_VWAP_Breakout.mq5
│       ├── E4_VolArbitrage.mq5
│       ├── E5_ORB.mq5
│       ├── E6_NewsSentiment.mq5
│       └── E7_Scalper.mq5
└── Include/
    ├── SoS_Commons.mqh
    ├── SoS_GlobalComms.mqh
    ├── SoS_RiskManager.mqh
    └── SoS_APIHandler.mqh
```

---

## 🔨 **PASO 2: Compilar en MetaEditor**

### ✅ **COMPILACIÓN EXITOSA CONFIRMADA**

**Estado:** TODOS los archivos compilados sin errores críticos

**Warnings menores detectados (IGNORABLES):**
- E4_VolArbitrage.mq5 línea 157: `possible loss of data due to type conversion long→double`
- E3_VWAP_Breakout.mq5 línea 290: `possible loss of data due to type conversion long→double`

**Análisis:** Conversiones seguras de volumen (long) a double. MQL5 es conservador pero NO hay pérdida real de datos en rangos normales. **IMPACTO: NINGUNO**.

---

### Orden de Compilación (IMPORTANTE)

**1. Compilar Includes PRIMERO:**
```
✅ 1. SoS_Commons.mqh - OK sin errores
✅ 2. SoS_GlobalComms.mqh - OK sin errores
✅ 3. SoS_RiskManager.mqh - OK sin errores
✅ 4. SoS_APIHandler.mqh - OK sin errores
```

**2. Compilar Master EA:**
```
✅ 5. StormGuard.mq5 - OK sin errores
```

**3. Compilar EAs Esclavas:**
```
✅ 6. E5_ORB.mq5 - OK sin errores
✅ 7. E4_VolArbitrage.mq5 - OK con 1 warning ignorable
✅ 8. E3_VWAP_Breakout.mq5 - OK con 1 warning ignorable
✅ 9. E1_RateSpread.mq5 - OK sin errores
✅ 10. E2_CarryTrade.mq5 - OK sin errores
✅ 11. E6_NewsSentiment.mq5 - OK sin errores
✅ 12. E7_Scalper.mq5 - OK sin errores
```

**RESUMEN:** 12/12 archivos compilados exitosamente. Sistema listo para testing funcional.

---

### Cómo Compilar

1. **Abrir MetaEditor** (F4 en MT5 o Tools → MetaQuotes Language Editor)

2. **Para cada archivo:**
   - Abrir archivo en MetaEditor
   - Presionar `F7` o click en botón "Compile"
   - Verificar en pestaña "Errors" que dice: `0 error(s), 0-2 warning(s)`

3. **Si hay errores:**
   - Leer mensaje de error cuidadosamente
   - Verificar que todos los Include files estén compilados
   - Verificar rutas de `#include` en cada .mq5

---

## ⚙️ **PASO 3: Configurar WebRequest** ⚠️ CRÍTICO

### URLs Requeridas

**ANTES** de usar las EAs, habilitar WebRequest para:

```
https://api.stlouisfed.org
https://www.alphavantage.co
```

### Procedimiento

1. En MT5: `Herramientas → Opciones`
2. Pestaña: `Expert Advisors`
3. Marcar: `☑ Permitir WebRequest para las siguientes URLs:`
4. Agregar ambas URLs (una por línea):
   - `https://api.stlouisfed.org`
   - `https://www.alphavantage.co`
5. Click `OK`
6. **REINICIAR MT5 COMPLETAMENTE** (importante para que tome efecto)

**⚠️ Sin esto, E1, E2 y E6 NO funcionarán (error 4014 o "URL not allowed").**

### Verificación

Después de reiniciar MT5:
- Ve a `Herramientas → Opciones → Expert Advisors`
- Verifica que ambas URLs aparecen en la lista
- Si ves error 4014 al adjuntar EAs con APIs, repite este paso

---

## 🧪 **PASO 4: Testing Funcional en Demo**

### ⚡ Preparación del Entorno MT5

**Requisitos de cuenta demo:**
- Balance inicial: **$10,000**
- Broker: IC Markets, Pepperstone, FTMO demo (compatible con MT5)
- Apalancamiento: 1:100 o superior
- Tipo de cuenta: Standard o ECN (evitar cuentas cent)

**Verificar WebRequest habilitado:**
- `Herramientas → Opciones → Expert Advisors`
- URLs habilitadas: ✅ `https://api.stlouisfed.org` ✅ `https://www.alphavantage.co`
- **MT5 reiniciado después de habilitar URLs**

---

### A. Testing de StormGuard (Master EA) 🎯 CRÍTICO

**Cuenta:** Demo  
**Par:** EURUSD  
**Timeframe:** M15  

**Parámetros de inicialización:**
```
Max Global DD: 7.0
Max Daily DD: 4.5
Alpha Vantage Key: N5B3DFCFSWKS5B59
VIX Panic Level: 30.0
Enable VIX: true
VIX Update Interval: 300 (5 min)
Enable Dashboard: true
Enable Push Alerts: true (opcional)
Enable Email Alerts: false (opcional)
```

**⚠️ IMPORTANTE: Marcar "Permitir trading automático" (Allow AutoTrading) al adjuntar**

**Validaciones de inicialización:**
- [ ] Dashboard aparece en esquina superior izquierda del gráfico
- [ ] Logs muestran: `"StormGuard Master EA Iniciado"`
- [ ] Logs muestran: `"Sistema SoS inicializado. Balance inicial: 10000"`
- [ ] GlobalVariables se crean (View → Global Variables en MT5)
- [ ] Verificar GlobalVariables creadas:
  - `SoS_VIX_Panic` = 0
  - `SoS_GlobalDD` = 0.0
  - `SoS_DailyDD` = 0.0
  - `SoS_EmergencyStop` = 0
  - `SoS_DisableBreakouts` = 0
- [ ] VIX se actualiza cada 5 min (ver logs: `"VIX actualizado: [valor]"`)
- [ ] VIX real entre 12-25 en condiciones normales

**Contenido esperado del Dashboard:**
```
=== STORMGUARD DASHBOARD ===
Balance: 10000.00
Equity: 10000.00
Global DD: 0.00%
Daily DD: 0.00%
VIX: 18.5 (actualizado cada 5 min)
Emergency: OFF
Breakouts: ENABLED
```

**Si Dashboard NO aparece:**
- Verificar `EnableDashboard = true` en inputs del EA
- Revisar logs buscando errores de creación de objetos gráficos
- Verificar permisos de objetos en MT5

**Si VIX NO se actualiza:**
- Verificar WebRequest habilitado y MT5 reiniciado
- Revisar logs: errores con Alpha Vantage API
- Verificar API key: `N5B3DFCFSWKS5B59`
- Posible rate limit (5 calls/min) → esperar 1-2 minutos

---

### B. Prueba del Circuit Breaker 🚨 OBLIGATORIO

**Objetivo:** Verificar que StormGuard cierra TODAS las posiciones al alcanzar 7% DD

**Procedimiento de simulación:**

1. **Abrir posiciones manuales:**
   - Par: EURUSD
   - Tamaño: 0.3-0.5 lotes por posición
   - Cantidad: 2-3 posiciones (Buy o Sell)
   - Magic Number: Usar 100003 o 100005 (para simular EAs esclavas)
   - Stop Loss: Poner muy cercano al precio actual (5-10 pips)

2. **Forzar pérdida del 7%:**
   - Objetivo: Pérdida de ~$700 (7% de $10,000)
   - Método: Cerrar manualmente posiciones en pérdida o esperar que toquen SL

3. **Monitorear logs cuando DD ≈ 6.5%:**
   - Abrir pestaña "Experts" en Terminal (Ctrl+T)
   - Observar actualización de `SoS_GlobalDD`

4. **Al alcanzar 7.0% DD exactamente:**

**Comportamiento esperado (DEBE ocurrir):**
- [ ] Logs imprimen: `"🚨 CIRCUIT BREAKER ACTIVADO! Global DD: 7.00%"`
- [ ] TODAS las posiciones se cierran automáticamente (incluye Magic 100001-100007)
- [ ] Logs muestran: `"Posición cerrada: Ticket [XXXX]"` para cada posición
- [ ] `SoS_EmergencyStop` cambia a 1 en GlobalVariables
- [ ] StormGuard ejecuta `ExpertRemove()` y se detiene
- [ ] Dashboard muestra: `"Emergency: ON"`
- [ ] Notificación push/email enviada (si configurada)

**Si Circuit Breaker NO se activa:**
- Verificar que StormGuard sigue corriendo (ícono carita feliz en gráfico)
- Revisar logs buscando errores en `CheckDrawdown()`
- Verificar GlobalVariables se actualizan correctamente
- Verificar cálculo de DD: `(Balance - Equity) / Balance * 100`

---

### C. Prueba del VIX Filter 📊

**Verificar actualización automática de VIX:**
- [ ] Esperar 5 minutos después de adjuntar StormGuard
- [ ] Logs muestran cada 5 min: `"VIX actualizado: [valor]"`
- [ ] VIX real típico: 12-25 (mercados normales), >30 (crisis/pánico)
- [ ] GlobalVariable `SoS_VIX_Panic` = 0 si VIX < 30
- [ ] GlobalVariable `SoS_VIX_Panic` = 1 si VIX ≥ 30

**Simular VIX alto (opcional - para testing avanzado):**

Si quieres probar que las EAs de breakout (E3, E5, E7) se desactivan con VIX > 30:

1. Abrir `StormGuard.mq5` en MetaEditor
2. Buscar función `UpdateVIX()`
3. Comentar línea: `double vix = api.GetVIX(AlphaVantageKey);`
4. Añadir línea: `double vix = 35.0;` (simular pánico)
5. Recompilar y volver a adjuntar al gráfico
6. Verificar logs: `"VIX en modo PÁNICO (35.0) - Breakouts desactivados"`
7. GlobalVariable `SoS_DisableBreakouts` debe cambiar a 1
8. **Restaurar código original después del test**

---

### D. Testing Individual de EAs (UNA POR UNA)

**⚠️ IMPORTANTE:** NO adjuntar todas las EAs simultáneamente. Testing incremental día por día.

**Cronograma sugerido:**
- **Día 1:** E5_ORB (sin APIs, más simple)
- **Día 2:** E4_VolArbitrage (sin APIs)
- **Día 3:** E3_VWAP_Breakout (sin APIs, trailing stop)
- **Día 4:** E1_RateSpread (FRED API)
- **Día 5:** E2_CarryTrade (usa VIX de StormGuard)
- **Día 6:** E6_NewsSentiment (Alpha Vantage News)
- **Día 7:** E7_Scalper (⚠️ solo para challenges, muy agresivo)

**Prerequisito para TODAS las EAs:** StormGuard DEBE estar corriendo en un gráfico.

---

#### 1. E5_ORB (Opening Range Breakout) - DÍA 1

**Cuenta:** Demo  
**Par:** EURUSD  
**Timeframe:** M5  

**Prerequisito:** ✅ StormGuard corriendo en gráfico EURUSD M15

**Cómo adjuntar:**
1. Abrir NUEVO gráfico de EURUSD M5 (diferente al de StormGuard)
2. Navigator → Expert Advisors → Slaves → E5_ORB.mq5
3. Arrastrar al gráfico
4. Marcar "Permitir trading automático"

**Parámetros recomendados:**
```
Session Start Hour: 9 (EST)
Session Start Minute: 30
Range Period Minutes: 60
Buffer Pips: 5.0
Risk Percent: 0.5
Max Trades Per Day: 1
```

**Validaciones (observar 24-48 horas):**
- [ ] Define opening range a las 09:30-10:30 EST
- [ ] Logs muestran: `"E5_ORB: Opening Range DEFINIDO. High: [X] | Low: [X]"`
- [ ] Espera ruptura del rango con buffer de 5 pips
- [ ] Verifica filtros: Volumen > 1.2x promedio, ATR > 1.0x promedio
- [ ] Ejecuta máximo 1 trade por día
- [ ] SL colocado en extremo opuesto del rango
- [ ] TP a 1.5x el tamaño del rango
- [ ] Lotaje calculado razonable (0.01-0.1 lotes aprox)
- [ ] Respeta circuit breaker de StormGuard si se activa

**Logs esperados:**
```
"E5_ORB: Inicializado en EURUSD M5"
"E5_ORB: Esperando apertura de sesión..."
"E5_ORB: Opening Range DEFINIDO. High: 1.0850 | Low: 1.0820"
"E5_ORB: Ruptura alcista detectada. Verificando filtros..."
"E5_ORB: Volumen suficiente (120% promedio)"
"E5_ORB: ATR válido (1.2x promedio)"
"E5_ORB: TRADE ejecutado. Ticket [XXXXX] SL: 1.0820 TP: 1.0895"
```

**Formato de reporte:**
```
✅ [TESTING E5_ORB]
Fecha inicio: [DD/MM/YYYY]
Duración: 48 horas
Rango definido correctamente: SÍ / NO
Trades ejecutados: X
Win Rate: X%
Profit total: +$XXX / -$XXX
Lotaje promedio: X.XX lotes
Issues: [lista de problemas]
Status: APROBADO / REQUIERE AJUSTES
```

---

#### 2. E4_VolArbitrage (Volatility Arbitrage) - DÍA 2

**Par:** EURUSD  
**Timeframe:** M15  

**Parámetros:**
```
ATR Multiplier: 2.0
Volume Threshold: 0.5
RSI Period: 14
Max Trades Per Day: 3
Risk Percent: 0.5
```

**Validaciones:**
- [ ] Calcula VWAP desde apertura del día
- [ ] Detecta precio > VWAP + 2×ATR
- [ ] Verifica volumen < 50% promedio
- [ ] Confirma con RSI (>70 o <30)
- [ ] TP en VWAP (reversión completa)
- [ ] Máximo 3 trades/día

**Logs esperados:**
```
"E4_VolArb: VWAP calculado: 1.0835"
"E4_VolArb: Precio alejado de VWAP (2.5x ATR) - Reversión probable"
"E4_VolArb: Volumen bajo (40% promedio) ✓"
"E4_VolArb: RSI overbought (75) ✓"
"E4_VolArb: SELL ejecutado. Target: VWAP reversion"
```

---

#### 3. E3_VWAP_Breakout (Momentum Breakout) - DÍA 3

**Par:** EURUSD  
**Timeframe:** M15  

**Parámetros:**
```
Swing Lookback: 20
ATR Multiplier: 2.0
Min ADX: 25.0
Exit ADX: 15.0
Max Trades Per Day: 2
```

**Validaciones:**
- [ ] Detecta swing high/low (20 velas)
- [ ] Verifica distancia VWAP > 2×ATR
- [ ] Confirma ADX > 25
- [ ] Trailing stop se actualiza dinámicamente
- [ ] Cierra si ADX < 15
- [ ] Cierra automáticamente si VIX > 30 (StormGuard)

**Logs esperados:**
```
"E3_VWAP: Swing high detectado: 1.0875 (20 velas)"
"E3_VWAP: Distancia a VWAP válida (2.3x ATR)"
"E3_VWAP: ADX fuerte (28) ✓"
"E3_VWAP: BUY ejecutado. Trailing stop activo."
"E3_VWAP: Trailing stop actualizado: 1.0860 → 1.0865"
"E3_VWAP: ADX cayendo (12) → Cerrando posición"
```

**Validación especial:**
- [ ] Trailing stop se actualiza dinámicamente cada tick
- [ ] Cierra automáticamente si VIX > 30 (StormGuard desactiva breakouts)
- [ ] GlobalVariable `SoS_DisableBreakouts` = 1 detiene nuevas entradas

---

#### 4. E1_RateSpread (Interest Rate Spreads) - DÍA 4 🌐 API

**Par:** EURUSD (par es referencia, trade basado en spreads)  
**Timeframe:** H1  

**⚠️ Requiere:** FRED API habilitada en WebRequest

**Parámetros:**
```
FRED Key: 8b908fe651eccf866411068423dd5068
Series 1: DGS2
Series 2: DGS10
Z-Score Period: 20
Z-Score Entry: 2.0
Z-Score Exit: 0.5
Update Interval Hours: 2
Max Trades Per Week: 10
```

**Validaciones:**
- [ ] Test inicial de API muestra DGS2 value
- [ ] Spread se actualiza cada 2 horas
- [ ] Historial de spreads se acumula (20 valores)
- [ ] Calcula Z-Score correctamente
- [ ] Entra cuando Z-Score > ±2.0
- [ ] Sale cuando Z-Score vuelve a ±0.5
- [ ] Máximo 10 trades/semana

**Debugging (logs esperados):**
```
"E1_RateSpread: Testeando FRED API..."
"✅ FRED API: Conectado (DGS2 = 4.2345)"
"✅ FRED API: DGS10 obtenido = 4.5678"
"✅ Spread actualizado: 0.3333 | Z-Score: 1.25"
"E1: Spread History [0.32, 0.33, 0.35, ...]"
"E1: Z-Score extremo detectado: 2.15 → SELL signal"
"E1: Trade ejecutado basado en mean reversion"
```

**Errores comunes:**
- Error 4014: WebRequest no habilitado → Verificar URLs
- `"FRED API Error: Invalid series"`: Serie incorrecta (debe ser DGS2 y DGS10)
- Rate limit alcanzado: Esperar (límite: 1000/día, actualización cada 2h = 12/día OK)

**Validación de rate limit:**
- Updates cada 2 horas = 12 calls/día
- FRED permite 1000/día → Margen seguro de 98.8%

---

#### 5. E2_CarryTrade (Adaptive Carry) - DÍA 5 🌐 API

**Pares:** AUDUSD (long) y JPYUSD (short)  
**Timeframe:** D1  

**⚠️ Requiere:** Alpha Vantage API + StormGuard corriendo (para VIX)

**Parámetros:**
```
Alpha Vantage Key: N5B3DFCFSWKS5B59
High Yield Pair: AUDUSD
Low Yield Pair: JPYUSD
Min Swap Differential: 0.5
VIX Close Level: 25.0
Hedge Ratio: 1.0
Min Holding Days: 7
```

**Validaciones:**
- [ ] Verifica swap differential favorable
- [ ] Abre Long AUDUSD + Short JPYUSD simultáneamente
- [ ] Calcula hedge ratio por volatilidad relativa
- [ ] Cierra ambas si VIX > 25
- [ ] No abre nuevas si VIX > 30
- [ ] Mantiene mínimo 7 días
- [ ] Cierra por profit target (2% equity) o loss (-1% equity)

**Debugging (logs esperados):**
```
"E2_Carry: Verificando swap differential..."
"✅ Swap differential favorable: 0.75 puntos"
"E2_Carry: Calculando hedge ratio..."
"E2_Carry: Hedge ratio por volatilidad: 1.15"
"E2_Carry: VIX actual: 18.5 (OK para carry trade)"
"✅ CARRY TRADE COMPLETO"
"📈 Long: AUDUSD x0.10 lotes"
"📉 Short: JPYUSD x0.115 lotes (hedged)"
```

**Validaciones especiales:**
- [ ] Abre SIMULTÁNEAMENTE long AUDUSD + short JPYUSD
- [ ] Hedge ratio calculado por ATR relativo (no fijo en 1.0)
- [ ] Cierra AMBAS posiciones si VIX > 25
- [ ] No abre nuevas si VIX > 30 (obtiene VIX de StormGuard GlobalVariable)
- [ ] Mantiene posiciones mínimo 7 días
- [ ] Cierra por profit target (2% equity) o loss (-1% equity)

**Dependencia crítica:**
E2 lee `SoS_VIX_Value` de GlobalVariables (actualizado por StormGuard cada 5 min)

---

#### 6. E6_NewsSentiment (News Trading) - DÍA 6 🌐 API

**Par:** EURUSD  
**Timeframe:** M15  

**⚠️ Requiere:** Alpha Vantage API

**Parámetros:**
```
Alpha Vantage Key: N5B3DFCFSWKS5B59
Ticker: FOREX:EURUSD
Sentiment Threshold: 0.5
News Check Interval Min: 60
Wait After News Min: 5
SL Pips: 20
TP Pips: 30
Max Trades Per Day: 2
```

**Validaciones:**
- [ ] Revisa noticias cada 60 minutos
- [ ] Parsea sentiment score correctamente
- [ ] Espera 5 min post-noticia
- [ ] Entra BUY si sentiment > 0.5
- [ ] Entra SELL si sentiment < -0.5
- [ ] SL 20 pips, TP 30 pips (R:R 1:1.5)
- [ ] Máximo 2 trades/día

**⚠️ Rate Limit:** 5 calls/min, 500/día → 1 check/hora = 24 calls/día (OK)

**Debugging (logs esperados):**
```
"E6_News: Consultando Alpha Vantage News API..."
"📰 Noticias obtenidas para FOREX:EURUSD"
"📰 Sentiment Score: 0.68 (POSITIVO)"
"📈 Sentiment > 0.5 detectado → Preparando BUY"
"E6_News: Esperando 5 minutos post-noticia..."
"E6_News: BUY ejecutado. SL: 20 pips | TP: 30 pips (R:R 1:1.5)"
```

**Validación de rate limit:**
- Checks cada 60 minutos = 24 calls/día
- Alpha Vantage permite 500/día → Margen seguro de 95.2%
- Rate limit: 5 calls/min (nuestra frecuencia es 1/hora = OK)

**Errores comunes:**
- `"Rate limit alcanzado"`: Esperar 1 minuto
- `"Invalid ticker"`: Verificar formato `FOREX:EURUSD`
- Sentiment score = 0: Sin noticias recientes (normal)

---

#### 7. E7_Scalper ⚠️ (Challenge Only) - DÍA 7

**⚠️ ADVERTENCIA:** ALTO RIESGO - Solo para challenges

**Par:** EURUSD  
**Timeframe:** M1  

**Parámetros CRÍTICOS:**
```
Confirm High Risk: TRUE ← DEBE activarse manualmente
Timeframe: M1
EMA Period: 20
RSI Period: 7
SL Pips: 40
TP Pips: 30 (R:R 1:0.75 INVERSO)
Max Risk Percent: 4.0%
Use Aggressive Lots: true
Max Trades Per Day: 2
Daily Profit Target: 3.0%
```

**Validaciones:**
- [ ] Solo se activa si `InpConfirmHighRisk = true`
- [ ] Señal: Precio > EMA(20) + RSI < 30 (BUY)
- [ ] Señal: Precio < EMA(20) + RSI > 70 (SELL)
- [ ] Lotaje AGRESIVO (hasta 80% DD restante)
- [ ] Target diario 3% → Detiene trading
- [ ] Máximo 2 trades/día
- [ ] Horario: 08:00-18:00 UTC

**⚠️ NO USAR EN CUENTA FONDEADA**

**⚠️ ADVERTENCIAS MÚLTIPLES EN CÓDIGO:**
- Solo se activa si `InpConfirmHighRisk = true` (protección)
- Muestra advertencias en OnInit(), OnTick(), y antes de cada trade
- **NO USAR EN CUENTA FONDEADA - SOLO PARA CHALLENGES**

**Debugging (logs esperados):**
```
"⚠️⚠️⚠️ E7_SCALPER (INVERSE R:R) - ALTO RIESGO ⚠️⚠️⚠️"
"⚠️ SOLO PARA CHALLENGES - NO USAR EN CUENTA FONDEADA"
"E7: Señal BUY detectada (Precio > EMA20, RSI < 30)"
"⚡ E7: Lotaje AGRESIVO calculado: 0.50 lotes (80% DD restante)"
"⚠️ E7: Trade ejecutado con R:R INVERSO (SL 40 pips > TP 30 pips)"
"🎯 E7: TARGET DIARIO ALCANZADO (3.0%) - Deteniendo trading por hoy"
```

**Comportamiento ultra-agresivo:**
- Usa hasta 80% del DD restante por trade (vs 0.5% normal)
- R:R inverso: SL 40 pips > TP 30 pips (1:0.75)
- Target diario 3% → detiene trading cuando se alcanza
- Máximo 2 trades/día (protección mínima)

**Validación crítica:**
- [ ] Solo se activa con `InpConfirmHighRisk = true`
- [ ] Sin confirmación, muestra: `"E7_Scalper: DETENIDO - Debe confirmar alto riesgo"`
- [ ] Detiene trading al alcanzar 3% profit diario
- [ ] Respeta circuit breaker de StormGuard (DD global 7%)

**Recomendación:**
Testear E7 SOLO después de validar que StormGuard y circuit breaker funcionan perfectamente. Es el EA más peligroso del sistema.

---

## 📊 **PASO 5: Testing del Sistema Completo**

### Escenario: 3 EAs Simultáneas

**Configuración:**
1. **Gráfico 1:** EURUSD M15 → StormGuard
2. **Gráfico 2:** EURUSD M15 → E3_VWAP_Breakout
3. **Gráfico 3:** EURUSD M5 → E5_ORB
4. **Gráfico 4:** EURUSD M15 → E4_VolArbitrage

**Validaciones del Sistema:**
- [ ] StormGuard monitorea DD global (suma de todas las EAs)
- [ ] GlobalVariables actualizadas cada tick
- [ ] VIX se actualiza cada 5 min
- [ ] Si VIX > 30: E3 y E5 dejan de operar
- [ ] Circuit Breaker cierra TODAS las posiciones al 7% DD
- [ ] Cada EA respeta su límite de trades/día independientemente
- [ ] Dashboard muestra equity, DD, VIX en tiempo real

### Prueba del Circuit Breaker

**Objetivo:** Forzar DD del 7% y verificar respuesta automática

1. Configurar lotajes altos temporalmente en 2-3 EAs
2. Dejar que ejecuten trades
3. Cerrar manualmente algunas posiciones en pérdida para simular DD
4. **Cuando DD Global ≈ 6.5%:** Observar logs
5. **Al alcanzar 7.0%:** Verificar que:
   - [ ] StormGuard imprime "🚨 CIRCUIT BREAKER ACTIVADO!"
   - [ ] TODAS las posiciones se cierran
   - [ ] `SoS_EmergencyStop` = 1 en GlobalVariables
   - [ ] Ninguna EA puede abrir nuevas posiciones
   - [ ] Push notification enviada (si configurada)

---

## 🐛 **PASO 6: Checklist de Errores Comunes**

### Errores de Compilación

**Error:** `'SoS_Commons.mqh' file not found`  
**Solución:** Copiar Include files a `MQL5/Include/`

**Error:** `Undeclared identifier 'MAGIC_E1_RATE'`  
**Solución:** Compilar `SoS_Commons.mqh` PRIMERO

**Error:** `'GlobalComms' undeclared identifier`  
**Solución:** Compilar `SoS_GlobalComms.mqh` antes del EA

---

### Errores de Runtime

**Error:** `WebRequest error 4060`  
**Solución:** Habilitar URLs en Options → Expert Advisors

**Error:** `FRED API Error: 4060`  
**Solución:** Agregar `https://api.stlouisfed.org` a WebRequest

**Error:** `Alpha Vantage: Rate limit alcanzado`  
**Solución:** Esperar 1 minuto o reducir frecuencia de updates

**Error:** `E7_Scalper: DETENIDO - Debe confirmar alto riesgo`  
**Solución:** Cambiar `InpConfirmHighRisk = true` en inputs

---

## 📝 **PASO 7: Reporte de Resultados**

### Formato de Reporte por EA

Usar este template para reportar testing de cada EA:

```markdown
## 🧪 TESTING REPORT: [NOMBRE EA]

**Fecha:** [DD/MM/YYYY]
**Duración:** [X horas/días]
**Par:** EURUSD
**Timeframe:** [MX]
**Balance inicial:** $10,000

### Comportamiento Observado

✅ **Inicialización:**
- Logs de startup: OK / ERROR
- Parámetros cargados: OK / ERROR
- Comunicación con StormGuard: OK / ERROR

✅ **Filtros y Lógica:**
- [Filtro específico 1]: FUNCIONANDO / FALLANDO
- [Filtro específico 2]: FUNCIONANDO / FALLANDO
- Respeta VIX filter: SÍ / NO / NO APLICA
- Respeta circuit breaker: SÍ / NO (si se activó)

📊 **Resultados de Trading:**
- Trades ejecutados: X
- Trades ganadores: X (X%)
- Trades perdedores: X (X%)
- Win Rate: X%
- Profit total: +$XXX / -$XXX
- Max drawdown observado: X.X%
- Lotaje promedio: X.XX lotes
- Respeta límite trades/día: SÍ / NO

🐛 **Issues Encontrados:**
1. [Descripción del problema]
   - Severidad: CRÍTICO / ALTO / MEDIO / BAJO
   - Reproducción: [pasos para reproducir]
   - Error code: [si aplica]
   - Logs relevantes: [copiar logs]

📸 **Screenshots:**
- [Adjuntar capturas del dashboard, gráfico con trades, etc]

🎯 **Status Final:**
- [ ] APROBADO - Listo para producción
- [ ] REQUIERE AJUSTES - Funciona pero necesita optimización
- [ ] BLOQUEADO - Errores críticos que impiden uso

### Próximos Pasos
- [Lista de acciones a tomar]
```

---

### Reporte de Compilación (COMPLETADO)

```
✅ [COMPILACIÓN] - Status: ✅ COMPLETADO
   - Include files: ✅ OK (4/4)
   - StormGuard: ✅ OK
   - E1_RateSpread: ✅ OK
   - E2_CarryTrade: ✅ OK
   - E3_VWAP_Breakout: ✅ OK (1 warning ignorable)
   - E4_VolArbitrage: ✅ OK (1 warning ignorable)
   - E5_ORB: ✅ OK
   - E6_NewsSentiment: ✅ OK
   - E7_Scalper: ✅ OK
   
📊 Resumen: 12/12 archivos compilados exitosamente
⚠️ Warnings: 2 (conversiones long→double, IGNORABLES)
   
✅ [TESTING FUNCIONAL] - Status: EN PROGRESO
   - WebRequest configurado: SÍ / NO
   - StormGuard funcionando: SÍ / NO
   - Circuit Breaker testeado: SÍ / NO
   - VIX actualizándose: SÍ / NO
   - FRED API respondiendo: SÍ / NO
   - Alpha Vantage respondiendo: SÍ / NO
   - E5_ORB ejecutó trade: SÍ / NO
   - (repetir para cada EA testeada)
   
📊 [RESULTADOS PRELIMINARES]
   - Trades ejecutados: X
   - Win Rate: X%
   - DD Máximo alcanzado: X%
   - Bugs encontrados: [lista]
   
🐛 [ISSUES ENCONTRADOS]
   1. [Descripción del bug]
      - EA afectada: EX
      - Reproducción: [pasos]
      - Error code: [si aplica]
   
🎯 [PRÓXIMOS PASOS]
   - [Lista de acciones a tomar]
```

---

---

## 🎯 **ROADMAP DE TESTING COMPLETO**

### Semana 1: Testing Básico (7 días)

**Día 1:** StormGuard + Circuit Breaker
- Inicializar StormGuard en demo
- Verificar dashboard y GlobalVariables
- Simular DD del 7% y validar circuit breaker
- Verificar VIX updates cada 5 min

**Día 2:** E5_ORB (primer EA esclava)
- Adjuntar E5_ORB a gráfico EURUSD M5
- Verificar definición de opening range
- Observar trades durante 24-48 horas
- Validar respeto a StormGuard

**Día 3:** E4_VolArbitrage
- Añadir E4 a sistema (2 EAs corriendo)
- Validar cálculo de VWAP inline
- Verificar mean reversion logic

**Día 4:** E3_VWAP_Breakout
- Añadir E3 a sistema (3 EAs corriendo)
- Validar trailing stop dinámico
- Verificar desactivación con VIX > 30

**Día 5:** E1_RateSpread (primera EA con API)
- Configurar WebRequest URLs (si no está hecho)
- Verificar conexión a FRED API
- Validar actualización de spreads cada 2h
- Confirmar cálculo de Z-Score

**Día 6:** E2_CarryTrade
- Añadir E2 con pares AUDUSD/JPYUSD
- Verificar apertura simultánea de long+short
- Validar hedge ratio dinámico
- Confirmar lectura de VIX desde GlobalVariables

**Día 7:** E6_NewsSentiment
- Verificar Alpha Vantage News API
- Confirmar parsing de sentiment score
- Validar wait period de 5 min post-news

### Semana 2: Testing Avanzado (opcional)

**Día 8:** E7_Scalper (solo si vas a hacer challenge)
- Activar `InpConfirmHighRisk = true`
- Testear en cuenta demo SEPARADA
- Monitorear lotaje agresivo
- Validar stop al alcanzar 3% diario

**Día 9-10:** Testing de Sistema Completo
- Todas las EAs corriendo simultáneamente
- Verificar descorrelación de estrategias
- Monitorear DD global en tiempo real
- Validar que circuit breaker protege TODO

**Día 11-14:** Optimización y Backtesting
- Backtest de cada EA (12 meses mínimo)
- Optimización de parámetros
- Análisis de correlación entre EAs
- Forward testing adicional

### Fase 3: Producción (después de 2 semanas)

**Pre-requisitos antes de pasar a cuenta real:**
- [ ] Circuit breaker validado 100%
- [ ] Todas las EAs testeadas individualmente (min 48h cada una)
- [ ] Sistema completo corriendo estable 5+ días
- [ ] Win rate agregado > 50%
- [ ] Max DD observado < 5% en demo
- [ ] Backtest de 12 meses con profit factor > 1.5
- [ ] Correlación entre EAs < 0.4
- [ ] APIs respondiendo consistentemente sin rate limits

**Configuración para cuenta real:**
- Empezar con E5, E4, E3 (sin APIs, más estables)
- Añadir E1, E2, E6 después de 1 semana
- E7 SOLO para challenges, NUNCA en cuenta fondeada
- Lotaje inicial: 50% del calculado por RiskManager
- Monitoreo diario obligatorio primeras 2 semanas

---

## 🚀 **¡Sistema Listo para Testing Funcional!**

**Total de archivos implementados:** 12  
- 4 Include files (.mqh) ✅
- 1 Master EA (StormGuard) ✅
- 7 Slave EAs (E1-E7) ✅
- Documentación completa ✅

**Estado actual:** ✅ Compilación exitosa (2 warnings ignorables)

**Próxima acción inmediata:**
1. Configurar WebRequest URLs en MT5
2. Reiniciar MT5 completamente
3. Abrir cuenta demo ($10,000)
4. Adjuntar StormGuard a EURUSD M15
5. Verificar dashboard y VIX updates
6. Simular circuit breaker
7. Reportar resultados

**Tiempo estimado total:** 2-3 semanas de testing exhaustivo

---

**Última actualización:** 2025-10-26  
**Versión del sistema:** 2.0.0  
**Estado compilación:** ✅ EXITOSA (12/12 archivos)  
**Próximo milestone:** Testing funcional StormGuard en demo
