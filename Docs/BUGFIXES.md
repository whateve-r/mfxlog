# 🐛 BUGFIXES - Squad of Systems

## ❌ **ERRORES CRÍTICOS IDENTIFICADOS EN BACKTEST**

### Fecha: 26/10/2025
### Contexto: Backtest visual 1 año (EURUSD M15)

---

## 📊 **RESULTADOS ANTES DE CORRECCIONES**

| EA | Trades | Profit | Diagnóstico |
|---|---|---|---|
| **E4_VolArbitrage** | **0** | $0 | ❌ CRÍTICO: No ejecuta ningún trade |
| **E3_VWAP_Breakout** | ~50 | **-$4,000** | ❌ PÉRDIDAS CONSISTENTES |
| **E5_ORB** | ~30 | **-$1,500** | ❌ PÉRDIDAS CONSISTENTES |

**Conclusión:** Errores de implementación MQL5, no mala racha estadística.

---

## 🔍 **CAUSA RAÍZ: SINTAXIS MQL4 EN LUGAR DE MQL5**

### Problema Principal

Los EAs fueron implementados con **sintaxis MQL4** (iATR, iRSI, iADX, iVolume, iHighest, iLowest llamados directamente) en lugar de usar la sintaxis correcta de **MQL5** (handles persistentes + CopyBuffer).

**Consecuencias:**
- Indicadores retornan valores inválidos o basura
- Filtros de entrada nunca se activan correctamente
- E4 con 0 trades = RSI/Volumen siempre inválidos
- E3/E5 con pérdidas = Filtros ATR/ADX/Volumen no funcionan

---

## ✅ **CORRECCIONES IMPLEMENTADAS**

### **ERROR #1: Indicadores sin handles persistentes**

#### ❌ ANTES (INCORRECTO - MQL4):
```cpp
void OnTick() {
    double atr = iATR(_Symbol, PERIOD_M15, 14, 0);  // SINTAXIS MQL4
    double rsi = iRSI(_Symbol, PERIOD_M15, 14, PRICE_CLOSE, 0);
    double adx = iADX(_Symbol, PERIOD_M15, 14, 0);
}
```

**Problema:** Compila sin errores pero retorna valores inválidos/basura.

#### ✅ DESPUÉS (CORRECTO - MQL5):
```cpp
// Variables globales
int g_atrHandle = INVALID_HANDLE;
int g_rsiHandle = INVALID_HANDLE;
int g_adxHandle = INVALID_HANDLE;

int OnInit() {
    // Crear handles UNA VEZ
    g_atrHandle = iATR(_Symbol, PERIOD_M15, 14);
    g_rsiHandle = iRSI(_Symbol, PERIOD_M15, 14, PRICE_CLOSE);
    g_adxHandle = iADX(_Symbol, PERIOD_M15, 14);
    
    if(g_atrHandle == INVALID_HANDLE || g_rsiHandle == INVALID_HANDLE) {
        return(INIT_FAILED);
    }
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
    // Liberar handles
    if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
    if(g_rsiHandle != INVALID_HANDLE) IndicatorRelease(g_rsiHandle);
    if(g_adxHandle != INVALID_HANDLE) IndicatorRelease(g_adxHandle);
}

void OnTick() {
    // Leer valores usando CopyBuffer
    double atrBuffer[], rsiBuffer[], adxBuffer[];
    ArraySetAsSeries(atrBuffer, true);
    ArraySetAsSeries(rsiBuffer, true);
    ArraySetAsSeries(adxBuffer, true);
    
    CopyBuffer(g_atrHandle, 0, 0, 1, atrBuffer);
    CopyBuffer(g_rsiHandle, 0, 0, 1, rsiBuffer);
    CopyBuffer(g_adxHandle, 0, 0, 1, adxBuffer);
    
    double atr = atrBuffer[0];
    double rsi = rsiBuffer[0];
    double adx = adxBuffer[0];
}
```

---

### **ERROR #2: Función iVolume() no existe en MQL5**

#### ❌ ANTES (INCORRECTO):
```cpp
long currentVol = iVolume(_Symbol, PERIOD_M15, 0);  // NO EXISTE EN MQL5
for(int i = 1; i <= 20; i++) {
    avgVol += iVolume(_Symbol, PERIOD_M15, i);
}
```

#### ✅ DESPUÉS (CORRECTO):
```cpp
long volume[];
ArraySetAsSeries(volume, true);

int copied = CopyTickVolume(_Symbol, PERIOD_M15, 0, 21, volume);
if(copied < 21) return false;

long currentVol = volume[0];
long avgVol = 0;

for(int i = 1; i <= 20; i++) {
    avgVol += volume[i];
}
avgVol /= 20;
```

---

### **ERROR #3: Funciones iHighest/iLowest no existen en MQL5**

#### ❌ ANTES (INCORRECTO):
```cpp
// Detectar swing high/low
for(int i = 1; i <= 20; i++) {
    double high = iHigh(_Symbol, PERIOD_M15, i);  // SINTAXIS MQL4
    double low = iLow(_Symbol, PERIOD_M15, i);
    
    if(high > swingHigh) swingHigh = high;
    if(low < swingLow) swingLow = low;
}
```

#### ✅ DESPUÉS (CORRECTO):
```cpp
double high[], low[];
ArraySetAsSeries(high, true);
ArraySetAsSeries(low, true);

int copied_high = CopyHigh(_Symbol, PERIOD_M15, 1, 20, high);
int copied_low = CopyLow(_Symbol, PERIOD_M15, 1, 20, low);

int max_index = ArrayMaximum(high, 0, 20);
int min_index = ArrayMinimum(low, 0, 20);

double swingHigh = high[max_index];
double swingLow = low[min_index];
```

---

### **ERROR #4: Cálculo de VWAP con funciones MQL4**

#### ❌ ANTES (INCORRECTO):
```cpp
double CalculateVWAP() {
    datetime todayStart = iTime(_Symbol, PERIOD_D1, 0);  // MQL4
    int bars = Bars(_Symbol, PERIOD_M5, todayStart, TimeCurrent());
    
    for(int i = 0; i < bars; i++) {
        double high = iHigh(_Symbol, PERIOD_M5, i);  // MQL4
        double low = iLow(_Symbol, PERIOD_M5, i);
        double close = iClose(_Symbol, PERIOD_M5, i);
        long volume = iVolume(_Symbol, PERIOD_M5, i);  // NO EXISTE
        
        sumPV += ((high + low + close) / 3.0) * volume;
        sumV += volume;
    }
    return sumPV / sumV;
}
```

#### ✅ DESPUÉS (CORRECTO):
```cpp
double CalculateVWAP() {
    // Copiar arrays de precios y volumen (MQL5)
    double high[], low[], close[];
    long volume[];
    
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(volume, true);
    
    int bars = CopyHigh(_Symbol, PERIOD_M5, 0, 288, high);
    if(bars <= 0) return 0;
    
    CopyLow(_Symbol, PERIOD_M5, 0, bars, low);
    CopyClose(_Symbol, PERIOD_M5, 0, bars, close);
    CopyTickVolume(_Symbol, PERIOD_M5, 0, bars, volume);
    
    double sumPV = 0, sumV = 0;
    
    for(int i = 0; i < bars; i++) {
        double typical = (high[i] + low[i] + close[i]) / 3.0;
        sumPV += typical * (double)volume[i];
        sumV += (double)volume[i];
    }
    
    return sumV > 0 ? sumPV / sumV : 0;
}
```

---

## 📝 **ARCHIVOS MODIFICADOS**

### E4_VolArbitrage.mq5
**Cambios:**
1. ✅ Añadido `g_rsiHandle` y `g_atrHandle` como variables globales
2. ✅ Creación de handles en `OnInit()` con validación
3. ✅ Liberación de handles en `OnDeinit()`
4. ✅ Reemplazado `iVolume()` por `CopyTickVolume()`
5. ✅ Reemplazado lectura directa de RSI por `CopyBuffer(g_rsiHandle)`
6. ✅ Reemplazado lectura directa de ATR por `CopyBuffer(g_atrHandle)`
7. ✅ Función `CalculateVWAP()` reescrita con arrays MQL5
8. ✅ Función `IsLowVolume()` reescrita con `CopyTickVolume()`
9. ✅ Añadido debug print cada 100 ticks para monitorear señales
10. ✅ **Parámetros relajados:** ATR 1.5 (antes 2.0), RSI 65/35 (antes 70/30), Volumen 0.8 (antes 0.5)

### E3_VWAP_Breakout.mq5
**Cambios:**
1. ✅ Añadido `g_adxHandle` y `g_atrHandle` como variables globales
2. ✅ Creación de handles en `OnInit()` con validación
3. ✅ Liberación de handles en `OnDeinit()`
4. ✅ Reemplazado detección de swing high/low por `CopyHigh/Low()` + `ArrayMaximum/Minimum()`
5. ✅ Reemplazado `iVolume()` por `CopyTickVolume()`
6. ✅ Reemplazado lectura directa de ADX por `CopyBuffer(g_adxHandle)`
7. ✅ Función `CalculateVWAP()` reescrita con arrays MQL5
8. ✅ Función `ManageOpenPosition()` corregida con handles persistentes
9. ✅ Añadido debug print en rupturas alcistas/bajistas
10. ✅ **Parámetros relajados:** Swing 10 (antes 20), ATR 1.5 (antes 2.0), ADX 20 (antes 25), Volumen 0.8 (antes 0.5)

### E5_ORB.mq5
**Cambios:**
1. ✅ Añadido `g_atrHandle` como variable global
2. ✅ Creación de handle en `OnInit()` con validación
3. ✅ Liberación de handle en `OnDeinit()`
4. ✅ Función `DefineRange()` reescrita con `CopyHigh/Low()` + `ArrayMaximum/Minimum()`
5. ✅ Reemplazado `iVolume()` por `CopyTickVolume()` en `CheckVolumeFilter()`
6. ✅ Función `CheckATRFilter()` reescrita con `CopyBuffer(g_atrHandle)`
7. ✅ Añadido debug print en rupturas alcistas/bajistas
8. ✅ **Parámetros relajados:** Rango 30min (antes 60min), Buffer 3 pips (antes 5), ATR 0.8 (antes 1.0)

---

## 🎯 **EXPECTATIVAS POST-CORRECCIÓN**

### Backtest 1 año EURUSD M15 (esperado):

| EA | Trades Esperados | Profit Factor | Profit Esperado |
|---|---|---|---|
| **E4_VolArbitrage** | 100-300 | 1.2-1.5 | +$500 a +$2,000 |
| **E3_VWAP_Breakout** | 50-100 | 1.1-1.3 | -$200 a +$1,000 |
| **E5_ORB** | 20-50 | 1.0-1.2 | -$100 a +$500 |

**Nota:** Si después de estas correcciones los resultados siguen siendo negativos, el problema es **conceptual en las estrategias**, no de implementación.

---

## 🧪 **PLAN DE RE-TESTING**

### Paso 1: Recompilar
```
1. Abrir MetaEditor
2. Compilar E4_VolArbitrage.mq5 → Verificar 0 errores
3. Compilar E3_VWAP_Breakout.mq5 → Verificar 0 errores
4. Compilar E5_ORB.mq5 → Verificar 0 errores
```

### Paso 2: Backtest Individual (3 meses cada uno)
```
1. E4_VolArbitrage: EURUSD M15, Enero-Marzo 2025
   - Verificar número de trades > 0
   - Leer logs buscando prints de debug
   - Verificar RSI/VWAP/ATR se calculan correctamente

2. E3_VWAP_Breakout: EURUSD M15, Enero-Marzo 2025
   - Verificar detección de swing high/low
   - Verificar ADX filtering funciona
   - Verificar trailing stop se actualiza

3. E5_ORB: EURUSD M5, Enero-Marzo 2025
   - Verificar definición de rango a las 09:30 EST
   - Verificar detección de rupturas
   - Verificar filtros de volumen/ATR
```

### Paso 3: Análisis de Logs
En cada backtest, buscar en pestaña "Experts":
- ✅ "VWAP calculado: X.XXXX"
- ✅ "RSI: XX.X"
- ✅ "ATR: X.XXXX"
- ✅ "Distancia de VWAP: X.XX xATR"
- ✅ "SEÑAL BUY/SELL detectada!"

Si estos logs NO aparecen, hay un problema persistente.

### Paso 4: Backtest 1 Año Completo
Después de validar 3 meses con trades exitosos:
- Ejecutar backtest completo 2024 (12 meses)
- Analizar profit factor, drawdown, win rate
- Comparar con expectativas de la tabla

---

## 📋 **CHECKLIST DE VALIDACIÓN**

### E4_VolArbitrage
- [ ] Handle RSI creado correctamente en OnInit
- [ ] Handle ATR creado correctamente en OnInit
- [ ] CopyBuffer(RSI) retorna valores 0-100
- [ ] CopyBuffer(ATR) retorna valores > 0
- [ ] VWAP calculado correctamente (no retorna 0)
- [ ] IsLowVolume() detecta periodos de bajo volumen
- [ ] Genera al menos 1 trade en backtest 3 meses
- [ ] Debug prints muestran VWAP, RSI, ATR cada 100 ticks

### E3_VWAP_Breakout
- [ ] Handle ADX creado correctamente en OnInit
- [ ] Handle ATR creado correctamente en OnInit
- [ ] Detección de swing high/low funciona (ArrayMaximum/Minimum)
- [ ] VWAP calculado correctamente
- [ ] ADX filter funciona (bloquea en ADX < 20)
- [ ] Trailing stop se actualiza dinámicamente
- [ ] Genera al menos 1 trade en backtest 3 meses
- [ ] Debug prints en rupturas alcistas/bajistas

### E5_ORB
- [ ] Handle ATR creado correctamente en OnInit
- [ ] DefineRange() usa CopyHigh/Low correctamente
- [ ] Rango se define a las 09:30 EST
- [ ] CheckVolumeFilter() usa CopyTickVolume
- [ ] CheckATRFilter() usa CopyBuffer(g_atrHandle)
- [ ] Detecta rupturas del rango con buffer
- [ ] Genera al menos 1 trade en backtest 3 meses
- [ ] Debug prints en definición de rango y rupturas

---

## 🚨 **SI LOS PROBLEMAS PERSISTEN**

### Escenario 1: E4 sigue con 0 trades después de correcciones
**Causas posibles:**
- Parámetros aún demasiado restrictivos → Relajar más (ATR 1.0, RSI 60/40)
- VWAP siempre retorna 0 → Verificar array de volumen no está vacío
- Horario de trading demasiado restrictivo → Ampliar a 08:00-18:00

### Escenario 2: E3/E5 siguen con pérdidas masivas
**Causas posibles:**
- Estrategia conceptualmente deficiente → Simplificar lógica
- SL demasiado ajustado → Aumentar ATR multiplier a 2.0-2.5
- Filtros demasiado agresivos → Eliminar filtro de volumen temporalmente

### Escenario 3: Compilación falla con errores
**Causas posibles:**
- Rutas de Include incorrectas → Verificar `#include "..\..\Include\SoS_Commons.mqh"`
- Funciones no declaradas → Verificar todos los Include files compilados primero

---

## 📊 **PRÓXIMOS PASOS**

1. **Inmediato:** Recompilar las 3 EAs corregidas
2. **Testing:** Backtest 3 meses cada una con análisis de logs
3. **Validación:** Verificar número de trades > 0 y lógica funciona
4. **Optimización:** Ajustar parámetros según resultados
5. **Producción:** Backtest 12 meses antes de demo/live

---

**Última actualización:** 26/10/2025  
**Versión:** 2.1.0 (Corrección crítica MQL5)  
**Status:** ✅ BUGS CORREGIDOS - PENDING RE-TESTING
