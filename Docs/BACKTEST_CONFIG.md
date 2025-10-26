# 🧪 CONFIGURACIÓN DE BACKTESTS - Squad of Systems

Configuración óptima de pares y timeframes para **Strategy Tester (Visualize)** de cada EA.

**Fecha:** 26 de Octubre, 2025  
**Versión del Sistema:** v2.4  
**Modo Recomendado:** Visual Mode (Visualize)  
**Período de Prueba:** Últimos 3 meses (Septiembre - Noviembre 2025)

---

## 📋 CONFIGURACIÓN RÁPIDA

| EA | Par Óptimo | Timeframe | Modelo | Depósito | Motivo |
|----|-----------|-----------|--------|----------|---------|
| **E1_RateSpread** | N/A (usa FRED) | H1 | Every tick | $10,000 | Spread rates requiere datos externos |
| **E2_CarryTrade** | AUDJPY | H4 | Every tick | $10,000 | Alto swap diferencial |
| **E3_VWAP_Breakout** | EURUSD | M15 | Every tick | $10,000 | Alta liquidez + volatilidad |
| **E4_VolArbitrage** | GBPUSD | M15 | Every tick | $10,000 | Reversiones VWAP + volatilidad |
| **E5_ORB** | USDJPY | M15 | Every tick | $10,000 | Breakouts en sesión asiática |
| **E6_NewsSentiment** | EURUSD | M30 | Every tick | $10,000 | Máxima exposición a eventos |
| **E7_Scalper** | EURUSD | M5 | Every tick | $10,000 | Alta liquidez + spreads bajos |

---

## 🔍 CONFIGURACIÓN DETALLADA POR EA

### E1_RateSpread - Interest Rate Spread Trading

**⚠️ REQUIERE CONFIGURACIÓN ESPECIAL**

```plaintext
Par: N/A (Estrategia basada en datos FRED)
Timeframe: H1
Período: Últimos 6 meses mínimo

NOTA CRÍTICA:
- Esta estrategia NO opera pares de forex directamente
- Requiere API Key de FRED válida
- Opera basándose en spreads de tasas de interés (T10Y2Y, etc.)
- Para backtest visual, configurar manualmente:
  * InpSeries1 = "DGS10" (US 10Y Treasury)
  * InpSeries2 = "DGS2"  (US 2Y Treasury)
  * InpFREDKey = [TU_API_KEY]

ALTERNATIVA PARA VISUALIZE:
- Usar E2_CarryTrade que sí opera forex con lógica similar
```

---

### E2_CarryTrade - Multi-Currency Carry Strategy

```plaintext
Par Primario: AUDJPY
Timeframe: H4 (4 horas)
Período: 3-6 meses

CONFIGURACIÓN:
├─ InpHighYieldPair = "AUDJPY"
├─ InpLowYieldPair = "EURJPY" 
├─ InpUseBasket = true
├─ InpBasketPairs = "NZDJPY,CADJPY,AUDUSD"
├─ InpMinSwapDifferential = 0.50
└─ InpUseNewsFilter = true
   └─ InpNewsCountryCodes = "AU,JP,NZ,CA"

PARÁMETROS OPTIMIZADOS:
- InpRiskPercent = 0.5%
- InpUseADXW = true (filtro de tendencia)
- InpADXWTrendThreshold = 25

POR QUÉ AUDJPY:
✅ Alto diferencial de swap (AUD alto yield, JPY bajo yield)
✅ Tendencia sostenida en H4
✅ Correlación estable con commodities
✅ Sesión asiática + europea solapadas

MEJORES MESES: Marzo-Mayo, Septiembre-Noviembre
```

---

### E3_VWAP_Breakout - Volume Weighted Price Breakouts

```plaintext
Par Primario: EURUSD
Timeframe: M15 (15 minutos)
Período: 2-3 meses

CONFIGURACIÓN:
├─ InpSwingPeriod = 10
├─ InpUseUTBot = true
├─ InpUseLRC = true (Linear Regression Channel)
├─ InpUseH1Trend = true
└─ InpH1EMA = 50

PARÁMETROS OPTIMIZADOS:
- InpRiskPercent = 0.5%
- InpATRMultiplier = 1.5
- InpADXThreshold = 20
- InpMaxTradesPerDay = 2

POR QUÉ EURUSD M15:
✅ Mayor liquidez del mercado (spreads bajos)
✅ Breakouts claros en M15 durante Londres-NY
✅ Suficiente volatilidad para VWAP reversions
✅ Datos históricos de alta calidad

MEJORES HORAS: 08:00-16:00 GMT (sesión europea)
EVITAR: 22:00-06:00 GMT (baja liquidez asiática)
```

---

### E4_VolArbitrage - Volatility Arbitrage (VWAP Mean Reversion)

```plaintext
Par Primario: GBPUSD
Timeframe: M15 (15 minutos)
Período: 2-3 meses

CONFIGURACIÓN:
├─ InpUseAdaptiveATR = true
├─ InpATRMultiplier = 1.5
├─ InpUseBBFilter = true
├─ InpBBPeriod = 20
├─ InpBBDeviation = 2.0
├─ InpUseWADDivergence = true
└─ InpVolumeThreshold = 0.75

PARÁMETROS OPTIMIZADOS:
- InpRiskPercent = 0.5%
- InpRSIOverbought = 68
- InpRSIOversold = 32
- InpMaxTradesPerDay = 3
- InpTradingStartHour = 10 (EST)
- InpTradingEndHour = 16 (EST)

POR QUÉ GBPUSD M15:
✅ Alta volatilidad intradiaria (ideal para reversiones)
✅ VWAP bien definido en M15
✅ Responde bien a Bollinger Bands
✅ Spreads razonables durante sesión europea

MEJORES HORAS: 08:00-17:00 GMT
EVITAR: Post-NY close (baja volatilidad)
```

---

### E5_ORB - Opening Range Breakout

```plaintext
Par Primario: USDJPY
Timeframe: M15 (15 minutos)
Período: 2-3 meses

CONFIGURACIÓN:
├─ InpSessionStartHour = 9
├─ InpSessionStartMinute = 30 (EST = 14:30 GMT)
├─ InpSessionEndHour = 16 (EST)
├─ InpRangePeriodMinutes = 30
├─ InpUseSessionHL = true
├─ InpAsianSessionStart = 0 (GMT)
├─ InpAsianSessionEnd = 8 (GMT)
├─ InpUseVROC = true
└─ InpUseNewsFilter = true
   └─ InpNewsCountryCodes = "US,JP"

PARÁMETROS OPTIMIZADOS:
- InpRiskPercent = 0.5%
- InpBufferPips = 3
- InpATRMultiplier = 0.8
- InpVROCThreshold = 15%
- InpNewsAvoidMinutes = 30

POR QUÉ USDJPY M15:
✅ Breakouts claros en apertura de NY (9:30 EST)
✅ Rango asiático bien definido (0-8 GMT)
✅ Volatilidad consistente en sesión NY
✅ Spread bajo + alta liquidez

MEJORES DÍAS: Martes-Jueves (evitar Lunes/Viernes)
SESIÓN CLAVE: 9:30-16:00 EST (14:30-21:00 GMT)
```

---

### E6_NewsSentiment - Economic Calendar Trading

```plaintext
Par Primario: EURUSD
Timeframe: M30 (30 minutos)
Período: 3-6 meses (más eventos económicos)

CONFIGURACIÓN:
├─ InpUseCalendar = true
├─ InpCountryCodes = "US,EU,GB,JP"
├─ InpMinImportance = CALENDAR_IMPORTANCE_HIGH
├─ InpSurpriseThreshold = 10.0%
├─ InpMaxEventAgeDays = 7
├─ InpWaitAfterNewsMin = 5
├─ InpUseWeighted = true
├─ InpRelevanceWeight = 0.6
├─ InpTimeDecayWeight = 0.4
├─ InpUseCorrelation = true
└─ InpUseTimeDecay = true
   └─ InpMaxPositionHours = 24

PARÁMETROS OPTIMIZADOS:
- InpRiskPercent = 0.5%
- InpSLPips = 40
- InpTPPips = 80
- InpNewsCheckIntervalMin = 15

POR QUÉ EURUSD M30:
✅ Mayor exposición a eventos económicos (US + EU)
✅ M30 captura movimientos post-noticia
✅ Spread bajo (importante para news trading)
✅ Alta correlación con índices (DXY, etc.)

EVENTOS CLAVE A MONITOREAR:
- NFP (Non-Farm Payrolls) - Primer viernes del mes
- FOMC (Federal Reserve) - ~8 veces/año
- ECB (Banco Central Europeo) - ~8 veces/año
- CPI (Inflación US/EU) - Mensual

MEJOR PERÍODO: Meses con múltiples eventos (Marzo, Junio, Sept, Dic)
```

---

### E7_Scalper - High-Frequency Scalping (⚠️ ALTO RIESGO)

```plaintext
Par Primario: EURUSD
Timeframe: M5 (5 minutos)
Período: 1-2 meses (suficiente para evaluar)

⚠️ ADVERTENCIA:
Este EA usa R:R inverso (TP pequeño, SL grande) - SOLO para challenges

CONFIGURACIÓN:
├─ InpConfirmHighRisk = true (OBLIGATORIO)
├─ InpSLPips = 50
├─ InpTPPips = 10 (R:R = 1:5 inverso)
├─ InpMaxRiskPercent = 2.0%
├─ InpDailyProfitTarget = 3.0%
├─ InpTradingStartHour = 8 (UTC)
├─ InpTradingEndHour = 18 (UTC)
├─ InpEMAPeriod = 20
└─ InpRSIPeriod = 14

PARÁMETROS OPTIMIZADOS:
- InpMaxRiskPercent = 2.0% (agresivo)
- InpRSIOverbought = 70
- InpRSIOversold = 30
- InpMinSpreadPips = 2.0

POR QUÉ EURUSD M5:
✅ Spread ultra bajo (crítico para scalping)
✅ Alta frecuencia de señales en M5
✅ Liquidez 24/5 (evita slippage)
✅ Movimientos predecibles en tendencia

MEJORES HORAS: 08:00-12:00 GMT, 13:00-17:00 GMT
EVITAR: 00:00-06:00 GMT (spread alto)

⚠️ NO USAR EN FONDEO - Solo para pasar challenges rápido
```

---

## 🎯 CONFIGURACIÓN DEL STRATEGY TESTER

### Configuración General (Todos los EAs)

```plaintext
STRATEGY TESTER SETTINGS:
├─ Período: 2024.09.01 - 2024.11.30 (3 meses)
├─ Depósito Inicial: $10,000 USD
├─ Apalancamiento: 1:100
├─ Modelo: Every tick (más preciso)
├─ Optimización: Desactivada (primero visual)
├─ Visual Mode: ACTIVADO
└─ Delay: 10ms (para ver operaciones claramente)

OPTIMIZATION (Después de validar visual):
├─ Forward Period: 30% (últimos 1 mes)
├─ Genetic Algorithm: 256 cromosomas
├─ Criterio: Balance + Drawdown
└─ Parámetros a optimizar:
   ├─ InpRiskPercent (0.3% - 1.0%)
   ├─ InpATRMultiplier (1.0 - 2.5)
   └─ Períodos de indicadores (±20%)
```

---

## 📊 MÉTRICAS OBJETIVO (Por EA)

### Objetivos Mínimos para Validación

| Métrica | E2 | E3 | E4 | E5 | E6 | E7 |
|---------|----|----|----|----|----|----|
| **Win Rate** | >55% | >45% | >50% | >50% | >55% | >60% |
| **Profit Factor** | >1.5 | >1.3 | >1.4 | >1.4 | >1.5 | >1.2 |
| **Max DD** | <8% | <10% | <8% | <8% | <7% | <15% |
| **Trades/mes** | 10-20 | 20-40 | 30-60 | 15-30 | 10-25 | 100+ |
| **Avg Win/Loss** | >1.5 | >1.2 | >1.3 | >1.3 | >1.5 | <0.3 |

**Leyenda:**
- 🟢 **E2, E6:** Mean reversion + fundamentales → Alta precisión
- 🟡 **E3, E4, E5:** Breakout/Mean Reversion → Precisión media
- 🔴 **E7:** Scalping agresivo → Baja precisión, alto volumen

---

## 🚀 PASOS PARA EJECUTAR BACKTEST VISUAL

### 1️⃣ Preparar Datos Históricos

```plaintext
1. Abrir MetaTrader 5
2. Tools → History Center (F2)
3. Para cada par (EURUSD, GBPUSD, USDJPY, AUDJPY):
   ├─ Seleccionar símbolo
   ├─ Seleccionar M1 (1 minuto)
   ├─ Click "Download"
   ├─ Período: Sept 2024 - Nov 2024
   └─ Esperar descarga completa
4. Verificar calidad:
   ├─ Tools → Options → Charts
   └─ Max bars in chart: 100,000+
```

### 2️⃣ Configurar Strategy Tester

```plaintext
1. View → Strategy Tester (Ctrl+R)
2. Configurar:
   ├─ Expert Advisor: [Seleccionar E3_VWAP_Breakout]
   ├─ Symbol: EURUSD
   ├─ Period: M15
   ├─ Date: 2024.09.01 - 2024.11.30
   ├─ Model: Every tick based on real ticks
   ├─ Optimization: OFF
   ├─ Visual mode: ON
   └─ Delay: 10
3. Configurar inputs (ver secciones arriba)
4. Click "Start"
```

### 3️⃣ Monitorear Backtest Visual

```plaintext
OBSERVAR:
✅ Señales de entrada (flechas en gráfico)
✅ Posiciones abiertas (líneas azul/rojo)
✅ SL/TP correctamente colocados
✅ Cierre de posiciones en VWAP (E3, E4)
✅ Respeto a horarios de trading
✅ Log del Journal (mensajes ✅/❌)

VALIDAR:
├─ No hay trades fuera de horario
├─ Max trades/día respetado
├─ SL/TP coherentes con ATR
├─ Lotaje calculado correctamente
└─ Circuit breaker funciona (tras 5 pérdidas)
```

### 4️⃣ Analizar Resultados

```plaintext
PESTAÑA "RESULTS":
├─ Balance final > $10,500 (+5%)
├─ Max Drawdown < 10%
├─ Profit Factor > 1.3
├─ Total trades > 30
└─ Sharpe Ratio > 1.0

PESTAÑA "GRAPH":
├─ Balance curve ascendente
├─ Equity suave (sin spikes)
└─ DD recuperados rápido

PESTAÑA "REPORT":
├─ Export → Save as HTML
└─ Compartir para análisis
```

---

## 🎯 ORDEN RECOMENDADO DE TESTING

Ejecutar backtests en este orden (de menos a más complejo):

### FASE 1 - VALIDACIÓN BÁSICA (1-2 días)
1. **E3_VWAP_Breakout** (EURUSD M15) - Más simple, visual claro
2. **E4_VolArbitrage** (GBPUSD M15) - Similar a E3, pero con BB
3. **E7_Scalper** (EURUSD M5) - Rápido, muchas señales

### FASE 2 - ESTRATEGIAS AVANZADAS (2-3 días)
4. **E5_ORB** (USDJPY M15) - Requiere sesiones específicas
5. **E6_NewsSentiment** (EURUSD M30) - Requiere eventos Calendar
6. **E2_CarryTrade** (AUDJPY H4) - Multi-símbolo, más lento

### FASE 3 - VALIDACIÓN COMPLETA (1 semana)
7. **Portfolio Test** - Todos los EAs simultáneos en demo
8. **StormGuard** - Master EA coordinando todo el sistema

---

## 📝 CHECKLIST DE VALIDACIÓN

Antes de pasar a demo/live, verificar:

- [ ] **E3**: Min 30 trades, Win Rate >45%, VWAP reversions visibles
- [ ] **E4**: Min 30 trades, Bollinger Bands filtran correctamente
- [ ] **E5**: Min 15 trades, Breakouts claros en 9:30 EST
- [ ] **E6**: Min 10 trades, Solo opera tras eventos HIGH importance
- [ ] **E7**: Min 100 trades, Daily target alcanzado 60%+ días
- [ ] **E2**: Min 10 trades, Swap positivo acumulado visible

- [ ] **Circuit Breaker**: Pausa tras 5 pérdidas consecutivas
- [ ] **VIX Panic**: Breakouts (E3,E5,E7) pausados con VIX >30
- [ ] **DD Limits**: Ningún EA excede 10% DD individual
- [ ] **Global DD**: Sistema completo <5% DD global

- [ ] **Kelly Criterion**: Activo tras 30+ trades
- [ ] **TradeHistory**: Logs muestran WinRate/PF/Kelly actualizados
- [ ] **Calendar Cache**: E6 no spamea logs cada tick
- [ ] **Unit Tests**: `test_risk_manager.mq5` pasa 10/10 tests

---

## 🛠️ TROUBLESHOOTING COMÚN

### "No hay trades en backtest"

**Causas posibles:**
1. Horario de trading no coincide con período
   - **Fix:** E5 requiere sesión NY (9:30-16:00 EST)
2. Filtros demasiado restrictivos
   - **Fix:** Desactivar temporalmente `InpUseBBFilter`, `InpUseWADDivergence`
3. Datos históricos incompletos
   - **Fix:** Descargar M1 completo desde History Center

### "Drawdown excesivo (>15%)"

**Causas posibles:**
1. Riesgo muy alto
   - **Fix:** Reducir `InpRiskPercent` a 0.3%
2. SL muy ajustado
   - **Fix:** Aumentar `InpATRMultiplier` a 2.0
3. Mercado lateral (no tendencial)
   - **Fix:** Probar otro período (ej: Oct-Nov en lugar Sept-Oct)

### "E6 no opera (Calendar)"

**Causas posibles:**
1. Sin eventos HIGH importance en período
   - **Fix:** Cambiar a `CALENDAR_IMPORTANCE_MEDIUM`
2. Country codes incorrectos
   - **Fix:** Verificar códigos ISO: "US,EU,GB,JP"
3. Surprise threshold muy alto
   - **Fix:** Bajar a `InpSurpriseThreshold = 5.0%`

### "E7 pierde dinero constantemente"

**Esperado:**
- E7 usa R:R inverso (1:5) - Necesita >80% Win Rate
- Si Win Rate <70%, es normal que pierda
- **No es un bug** - Diseñado así para challenges

---

## 📞 SOPORTE

Si encuentras problemas:

1. **Revisar Journal del Strategy Tester:**
   - Buscar mensajes `❌` o `⚠️`
   - Copiar últimas 50 líneas

2. **Verificar versión:**
   - Todos los EAs deben mostrar `v2.4` en OnInit

3. **Exportar Report:**
   - Strategy Tester → Report → Save as HTML
   - Compartir para análisis

4. **Logs de errores comunes:**
   ```
   ❌ E4_VolArb: Error creando Bollinger Bands handle
   → Instalar MT5 actualizado (build 3661+)
   
   ⚠️ E6_News v2.4: No se pudieron parsear country codes
   → Verificar formato: "US,EU,GB" (sin espacios)
   
   ❌ FRED API: Error en test inicial
   → E1 requiere API Key válida (obtener en fred.stlouisfed.org)
   ```

---

## 🎓 GLOSARIO

- **VWAP:** Volume Weighted Average Price - Precio promedio ponderado por volumen
- **ORB:** Opening Range Breakout - Ruptura del rango de apertura
- **ATR:** Average True Range - Rango verdadero promedio (volatilidad)
- **BB:** Bollinger Bands - Bandas de Bollinger
- **WAD:** Williams Accumulation/Distribution - Indicador de acumulación/distribución
- **VROC:** Volume Rate of Change - Tasa de cambio de volumen
- **Kelly Criterion:** Fórmula matemática para optimizar tamaño de posición
- **DD:** Drawdown - Pérdida máxima desde pico anterior

---

**Última actualización:** 26 de Octubre, 2025  
**Autor:** Squad of Systems (SoS) Trading  
**Versión del sistema:** v2.4 Post-Audit

