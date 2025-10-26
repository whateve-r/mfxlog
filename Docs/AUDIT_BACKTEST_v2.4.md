# 🚨 DIAGNÓSTICO POST-BACKTEST v2.4

**Fecha:** 26 de Octubre, 2025  
**Período testeado:** 3 meses (Sept-Nov 2024)  
**Configuración:** Según BACKTEST_CONFIG.md

---

## 📊 RESULTADOS CATASTRÓFICOS

| EA | P/L | Trades | Diagnóstico |
|----|-----|--------|-------------|
| E2_CarryTrade | **-$7,121.93** | ~50+ | ❌ Sin SL/TP, hedge ratio siempre 1.0 |
| E3_VWAP_Breakout | $0.00 | 0 | ❌ Filtros contradictorios (volumen bajo ≠ breakout) |
| E4_VolArbitrage | $0.00 | 0 | ❌ Horario EST vs GMT, nunca entra en trading hours |
| E5_ORB | +$1.60 | 1-2 | ⚠️ Funciona pero muy restrictivo |
| E6_NewsSentiment | $0.00 | 0 | ❌ Sin eventos en período o threshold muy alto |
| E7_Scalper | $0.00 | 0 | ❌ Horario EST + spread filter |
s
---

## 🔴 E2: PÉRDIDA BRUTAL (-$7K)

### Bugs identificados:

1. **Sin SL/TP**
```cpp
trade.Buy(lots, symbol, 0, 0, 0, comment);  // SL=0, TP=0
```

2. **Hedge Ratio siempre 1.0**
```cpp
double atrHigh = riskMgr.GetATR(PERIOD_D1, ...);  // Usa _Symbol
double atrLow = riskMgr.GetATR(PERIOD_D1, ...);   // Usa _Symbol
return atrHigh / atrLow;  // = 1.0 siempre
```

3. **Cierra solo por equity**
```cpp
if(totalPL >= equity * 0.02) close();  // +2%
if(totalPL <= -equity * 0.01) close(); // -1%  ← ALCANZA ESTO 70 VECES
```

---

## 🔴 E3/E4/E7: 0 TRADES (Horario GMT)

### Bug común:
```cpp
input int InpTradingStartHour = 10;  // EST
bool IsInTradingHours() {
    TimeToStruct(TimeCurrent(), current);  // GMT del servidor
    return (current.hour >= 10 && current.hour < 16);  // Nunca TRUE
}
```

**Servidor:** GMT+0  
**Parámetro:** 10-16 (asume EST = GMT-5)  
**Resultado:** 10:00 EST = 15:00 GMT → Filtro nunca pasa

---

## 🔴 E3: FILTROS IMPOSIBLES

Requiere cumplir **11 condiciones** simultáneamente:

```
✅ VIX OK
✅ Max trades/día
✅ VWAP calculado
✅ ADX >= 20 (tendencia fuerte)
✅ Distance >= 1.5×ATR
✅ IsLowVolume() == TRUE  ← CONTRADICE breakout (volumen ALTO)
✅ H1 EMA alineada
✅ LRC no lateral
✅ UT Bot señal activa
✅ Swing high/low detectado
✅ Bollinger Bands confirmación
```

**Probabilidad:** <1% → 0 trades

---

## FIXES URGENTES

Implementaré en orden de severidad (empiezo ahora):

1. **E2:** SL/TP + FixHedgeRatio() (30 min)
2. **E4:** FixHorario() + Debug (15 min)
3. **E3:** RemoveLowVolumeFilter() + MakeFiltersOptional() (20 min)
4. **E6:** LowerThresholds() + AddDebug() (15 min)
5. **E7:** FixHorario() + LooseSpread() (10 min)

¿Procedo con la implementación?
