# 🚀 Squad of Systems (SoS) - Trading System

## 📋 Descripción del Proyecto

**Squad of Systems (SoS)** es un sistema de trading algorítmico avanzado diseñado para prop firms (FTMO, FundedNext, etc.) que combina 7 Expert Advisors (EAs) descorrelacionados, orquestados por un EA Maestro llamado **StormGuard**.

### 🎯 Objetivos Principales

- **Rentabilidad:** 15-30% mensual
- **Drawdown Máximo Global:** 7%
- **Drawdown Máximo Diario:** 4.5%
- **Descorrelación:** 7 estrategias independientes con correlación < 0.4

---

## 🏗️ Arquitectura del Sistema

### StormGuard (Master EA)

**Función:** Cerebro del sistema que supervisa y controla todos los EAs esclavos.

**Responsabilidades:**
- ✅ Monitoreo de Drawdown en Tiempo Real
- ✅ Circuit Breaker automático
- ✅ Filtro de Régimen de Mercado (VIX)
- ✅ Comunicación Master-Slave vía GlobalVariables
- ✅ Dashboard visual en tiempo real
- ✅ Alertas por email/push

### EAs Esclavas (7 Estrategias)

1. **E1_RateSpread** - Mean Reversion on Interest Rate Spreads
2. **E2_CarryTrade** - Adaptive Carry Trade
3. **E3_VWAP_Breakout** - Momentum Breakout with VWAP Filter
4. **E4_VolArbitrage** - Volatility Arbitrage Intraday
5. **E5_ORB** - Opening Range Breakout
6. **E6_NewsSentiment** - News Sentiment Trading
7. **E7_Scalper** - Inverse R:R Scalper (Solo para challenges)

---

## 📁 Estructura del Proyecto

```
SoS-TradingSystem/
├── Experts/
│   ├── StormGuard.mq5                    ✅ COMPLETADO
│   └── Slaves/
│       ├── E1_RateSpread.mq5             ⏳ Pendiente
│       ├── E2_CarryTrade.mq5             ⏳ Pendiente
│       ├── E3_VWAP_Breakout.mq5          ⏳ Pendiente
│       ├── E4_VolArbitrage.mq5           ⏳ Pendiente
│       ├── E5_ORB.mq5                    ⏳ Pendiente
│       ├── E6_NewsSentiment.mq5          ⏳ Pendiente
│       └── E7_Scalper.mq5                ⏳ Pendiente
├── Include/
│   ├── SoS_Commons.mqh                   ✅ COMPLETADO
│   ├── SoS_GlobalComms.mqh               ✅ COMPLETADO
│   ├── SoS_RiskManager.mqh               ✅ COMPLETADO
│   └── SoS_APIHandler.mqh                ✅ COMPLETADO
├── Indicators/
│   └── VWAP_Custom.mq5                   ⏳ Pendiente
├── Tests/
│   ├── test_risk_manager.mq5             ⏳ Pendiente
│   ├── test_api_handler.mq5              ⏳ Pendiente
│   └── test_global_comms.mq5             ⏳ Pendiente
└── Docs/
    ├── README.md                         ✅ Este archivo
    ├── API_KEYS.md                       ✅ COMPLETADO
    └── CHANGELOG.md                      ✅ COMPLETADO
```

---

## 🔧 Configuración Inicial

### 1. Habilitar WebRequest en MT5

**CRÍTICO:** Antes de usar cualquier EA con APIs, debes habilitar WebRequest.

**Pasos:**
1. En MT5: `Herramientas → Opciones → Expert Advisors`
2. Marcar: `☑ Permitir WebRequest para las siguientes URLs:`
3. Agregar las siguientes URLs:
   ```
   https://api.stlouisfed.org
   https://www.alphavantage.co
   ```

### 2. Obtener API Keys

Ver archivo `API_KEYS.md` para instrucciones detalladas.

**APIs Requeridas:**
- **FRED API** (Federal Reserve Economic Data) - GRATUITA
  - URL: https://fred.stlouisfed.org/docs/api/api_key.html
  - Límite: 1000 requests/día
  
- **Alpha Vantage API** - GRATUITA
  - URL: https://www.alphavantage.co/support/#api-key
  - Límite: 5 calls/minuto, 500 calls/día

### 3. Compilar los archivos

1. Copiar todos los archivos a la carpeta de MT5
2. Abrir MetaEditor
3. Compilar en este orden:
   - ✅ `Include/SoS_Commons.mqh`
   - ✅ `Include/SoS_GlobalComms.mqh`
   - ✅ `Include/SoS_RiskManager.mqh`
   - ✅ `Include/SoS_APIHandler.mqh`
   - ✅ `Experts/StormGuard.mq5`

---

## 🚀 Uso del Sistema

### Fase 1: Testing de StormGuard

**ANTES** de activar cualquier EA esclava, debes testear StormGuard:

1. **Adjuntar StormGuard a un gráfico** (cualquier par, ej. EURUSD M15)
2. **Configurar parámetros:**
   ```
   Max Global DD: 7.0%
   Max Daily DD: 4.5%
   Alpha Vantage Key: [TU_API_KEY]
   Enable Dashboard: true
   Enable Push Alerts: true
   ```

3. **Abrir posiciones manuales de prueba** con Magic Numbers:
   - Magic: 100003 (simula E3_VWAP)
   - Magic: 100005 (simula E5_ORB)

4. **Verificar funcionalidad:**
   - ✅ Dashboard se muestra correctamente
   - ✅ DD Global se actualiza en cada tick
   - ✅ DD Diario se actualiza en cada tick
   - ✅ VIX se actualiza cada 5 minutos
   - ✅ Circuit Breaker cierra posiciones al alcanzar límite
   - ✅ Reset diario funciona a las 00:00 UTC

### Fase 2: Despliegue de EAs Esclavas

Una vez StormGuard esté validado, agregar EAs progresivamente:

**Orden recomendado:**
1. E5_ORB (más simple, sin APIs)
2. E4_VolArbitrage
3. E3_VWAP_Breakout
4. E1_RateSpread (primera con API)
5. E2_CarryTrade
6. E6_NewsSentiment
7. E7_Scalper (SOLO para challenges)

---

## 📊 Magic Numbers del Sistema

| EA | Magic Number | Descripción |
|----|--------------|-------------|
| StormGuard | 100000 | Master EA |
| E1_RateSpread | 100001 | Interest Rate Spreads |
| E2_CarryTrade | 100002 | Carry Trade |
| E3_VWAP_Breakout | 100003 | VWAP Breakout |
| E4_VolArbitrage | 100004 | Volatility Arbitrage |
| E5_ORB | 100005 | Opening Range Breakout |
| E6_NewsSentiment | 100006 | News Sentiment |
| E7_Scalper | 100007 | Scalper (Challenge only) |

---

## 🔒 Sistema de Comunicación Master-Slave

StormGuard se comunica con las EAs esclavas mediante **GlobalVariables**:

### Variables Publicadas por StormGuard:

| Variable | Descripción | Uso |
|----------|-------------|-----|
| `SoS_VIX_Panic` | Valor actual del VIX | E2, E3, E5, E7 consultan |
| `SoS_GlobalDD` | DD Global (%) | Todas las EAs monitorean |
| `SoS_DailyDD` | DD Diario (%) | Todas las EAs monitorean |
| `SoS_EmergencyStop` | 1 = STOP inmediato | Todas las EAs verifican |
| `SoS_DisableBreakouts` | 1 = Desactivar E3,E5,E7 | EAs de breakout consultan |

### Ejemplo de uso en EAs esclavas:

```cpp
#include <SoS_GlobalComms.mqh>

void OnTick() {
    // Verificar si se puede operar
    if(!GlobalComms::CanTrade(MAGIC_E3_VWAP)) {
        return; // No operar
    }
    
    // Lógica de trading...
}
```

---

## 📈 Métricas de Éxito Esperadas

### Por EA Individual (Backtests 12 meses):

| EA | Win Rate | Avg R:R | Max DD | Sharpe | Trades/Mes |
|----|----------|---------|--------|--------|------------|
| E1 | 55-65% | 1:1.5 | 1-4% | 1.2-1.8 | 10-20 |
| E2 | 60-70% | 1:2 | 3-5% | 1.5-2.0 | 5-15 |
| E3 | 45-55% | 1:2.5 | 3-6% | 1.0-1.5 | 15-30 |
| E4 | 65-75% | 1:1.2 | 2-5% | 1.8-2.2 | 20-40 |
| E5 | 50-60% | 1:2 | 4-6% | 1.3-1.7 | 15-25 |
| E6 | 60-70% | 1:1.5 | 2-4% | 1.4-1.9 | 5-10 |
| E7 | 70-85% | 1:0.75 | Variable | 0.8-1.2 | 20-50 |

### Portafolio Completo (Objetivo):

- **Win Rate Global:** 60-70%
- **Rentabilidad Mensual:** 15-30%
- **Max Drawdown:** < 8%
- **Sharpe Ratio:** > 2.0
- **Trades/Mes:** 100-200 (agregado)

---

## ⚠️ ADVERTENCIAS IMPORTANTES

### 🚨 E7_Scalper - USO RESTRINGIDO

**SOLO** usar E7_Scalper durante la **fase de challenge** de prop firms.

**NUNCA** usar en cuenta fondeada por:
- Riesgo agresivo (hasta 4% por trade)
- R:R inverso (1:0.75)
- Baja calidad de trades
- Objetivo: Velocidad, no sostenibilidad

### 🌪️ VIX Monitoring

- **VIX > 30:** Breakouts (E3, E5, E7) desactivados automáticamente
- **VIX > 25:** E2 (Carry Trade) cierra posiciones automáticamente

### 📊 Drawdown Limits

- **Global DD > 7%:** Circuit Breaker → CIERRA TODO
- **Daily DD > 4.5%:** Circuit Breaker → CIERRA TODO

**No hay override manual.** El sistema se protege automáticamente.

---

## 🛠️ Troubleshooting

### Problema: WebRequest devuelve error -1

**Solución:**
1. Verificar que las URLs estén habilitadas en MT5
2. Verificar conexión a internet
3. Verificar API Keys correctas
4. Ver logs en "Experts" tab para detalles

### Problema: Circuit Breaker se activa prematuramente

**Posibles causas:**
1. Balance inicial mal configurado → Verificar GlobalVariables
2. DD limits muy bajos → Ajustar `InpMaxGlobalDD` / `InpMaxDailyDD`
3. Slippage alto → Ajustar en broker o filtrar trades

### Problema: VIX no se actualiza

**Solución:**
1. Verificar Alpha Vantage API Key
2. Verificar rate limits (5 calls/min máx)
3. Verificar conectividad WebRequest
4. Usar script de test: `Tests/test_api_handler.mq5`

---

## 📞 Soporte y Contacto

- **Documentación:** Ver carpeta `Docs/`
- **Issues:** Reportar bugs en GitHub Issues
- **Email:** support@sos-trading.com (placeholder)

---

## 📜 Licencia

Copyright © 2025 SoS Trading System  
All rights reserved.

**Uso Privado Únicamente.** No redistribuir sin autorización.

---

## 🎓 Próximos Pasos

1. ✅ **FASE 1 COMPLETADA:** StormGuard + Includes implementados
2. ⏳ **FASE 2:** Testing de StormGuard en demo
3. ⏳ **FASE 3:** Implementar E5_ORB, E4_VolArbitrage
4. ⏳ **FASE 4:** Implementar E3_VWAP_Breakout + VWAP indicator
5. ⏳ **FASE 5:** Implementar EAs con APIs (E1, E2, E6)
6. ⏳ **FASE 6:** Implementar E7_Scalper
7. ⏳ **FASE 7:** Backtest completo del portafolio
8. ⏳ **FASE 8:** Forward test en demo (2 semanas mínimo)
9. ⏳ **FASE 9:** Challenge de prop firm
10. ⏳ **FASE 10:** Deployment en cuenta fondeada

---

**¡Buena suerte con tu trading! 🚀📈**
