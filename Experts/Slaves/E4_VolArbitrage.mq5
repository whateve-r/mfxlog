//+------------------------------------------------------------------+
//| E4_VolArbitrage.mq5 - Volatility Arbitrage Intraday              |
//| Squad of Systems - Trading System v2.2                           |
//| Copyright 2025, SoS Trading                                       |
//+------------------------------------------------------------------+
#property copyright "SoS Trading System"
#property link      "https://github.com/sos-trading"
#property version   "2.20"
#property description "Volatility Arbitrage - VWAP Mean Reversion + BB + WAD + Adaptive ATR"

#include <Trade\Trade.mqh>
#include "..\..\Include\SoS_Commons.mqh"
#include "..\..\Include\SoS_GlobalComms.mqh"
#include "..\..\Include\SoS_RiskManager.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== SIGNAL SETTINGS ==="
input bool   InpUseAdaptiveATR = true;          // Usar ATR adaptativo
input double InpATRMultiplier = 1.5;            // Multiplicador ATR base (1.2-2.0 adaptativo)
input double InpVolumeThreshold = 0.75;         // % Volumen vs promedio (más restrictivo)
input int    InpRSIPeriod = 14;                 // Periodo RSI
input double InpRSIOverbought = 68.0;           // RSI sobrecompra (ajustado con BB)
input double InpRSIOversold = 32.0;             // RSI sobreventa (ajustado con BB)

input group "=== MEJORAS v2.2 ==="
input bool   InpUseBBFilter = true;             // Usar Bollinger Bands como filtro
input int    InpBBPeriod = 20;                  // Periodo Bollinger Bands
input double InpBBDeviation = 2.0;              // Desviación estándar BB
input bool   InpUseWADDivergence = true;        // Usar Williams AD para divergencias
input int    InpATRAdaptivePeriod = 50;         // Periodo para ATR adaptativo

input group "=== RISK MANAGEMENT ==="
input double InpRiskPercent = 0.5;              // Riesgo por trade (%)
input double InpSLMultiplier = 0.5;             // SL en términos de ATR

input group "=== LIMITS ==="
input int    InpMaxTradesPerDay = 3;            // Máximo trades diarios
input int    InpTradingStartHour = 8;           // Inicio trading (GMT)
input int    InpTradingEndHour = 18;            // Fin trading (GMT)
input int    InpServerTimeOffset = 0;           // Offset del servidor (ej: +2 para GMT+2)

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;
RiskManager riskMgr(_Symbol, MAGIC_E4_VOL);  // v2.4: Constructor con magic para TradeHistory

int g_tradesToday = 0;
datetime g_lastResetDate = 0;

// Indicator handles (MQL5)
int g_rsiHandle = INVALID_HANDLE;
int g_atrHandle = INVALID_HANDLE;
int g_bbHandle = INVALID_HANDLE;     // v2.2: Bollinger Bands
int g_wadHandle = INVALID_HANDLE;    // v2.2: Williams Accumulation/Distribution

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
    trade.SetExpertMagicNumber(MAGIC_E4_VOL);
    trade.SetDeviationInPoints(50);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    // Crear handles de indicadores (MQL5)
    g_rsiHandle = iRSI(_Symbol, PERIOD_M15, InpRSIPeriod, PRICE_CLOSE);
    g_atrHandle = iATR(_Symbol, PERIOD_M15, 14);
    
    // v2.2: Crear handles adicionales
    if(InpUseBBFilter) {
        g_bbHandle = iBands(_Symbol, PERIOD_M15, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
        if(g_bbHandle == INVALID_HANDLE) {
            Print("❌ E4_VolArb v2.2: Error creando Bollinger Bands handle");
            return(INIT_FAILED);
        }
    }
    
    if(InpUseWADDivergence) {
        g_wadHandle = iAD(_Symbol, PERIOD_M15, VOLUME_TICK);
        if(g_wadHandle == INVALID_HANDLE) {
            Print("❌ E4_VolArb v2.2: Error creando Williams AD handle");
            return(INIT_FAILED);
        }
    }
    
    if(g_rsiHandle == INVALID_HANDLE || g_atrHandle == INVALID_HANDLE) {
        Print("❌ E4_VolArb: Error creando handles de indicadores base");
        return(INIT_FAILED);
    }
    
    Print("==================================================");
    Print("✅ E4_VolArbitrage v2.2 (VWAP + BB + WAD) Inicializado");
    Print("📊 ATR: ", InpUseAdaptiveATR ? "ADAPTATIVO (1.2-2.0)" : DoubleToString(InpATRMultiplier, 1));
    Print("📈 Bollinger Bands: ", InpUseBBFilter ? "ACTIVADO" : "DESACTIVADO");
    Print("📊 Williams AD: ", InpUseWADDivergence ? "ACTIVADO" : "DESACTIVADO");
    Print("📉 Volumen threshold: ", InpVolumeThreshold * 100, "%");
    Print("💰 Riesgo: ", InpRiskPercent, "%");
    Print("🔢 Max trades/día: ", InpMaxTradesPerDay);
    Print("==================================================");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // Liberar handles de indicadores (MQL5)
    if(g_rsiHandle != INVALID_HANDLE) IndicatorRelease(g_rsiHandle);
    if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
    if(g_bbHandle != INVALID_HANDLE) IndicatorRelease(g_bbHandle);      // v2.2
    if(g_wadHandle != INVALID_HANDLE) IndicatorRelease(g_wadHandle);    // v2.2
    
    Print("🛑 E4_VolArbitrage v2.2 Detenido. Razón: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
    // Check 1: ¿Podemos operar?
    if(!GlobalComms::CanTrade(MAGIC_E4_VOL)) {
        return;
    }
    
    // Check 2: Reset diario
    ResetDailyCounter();
    
    // Check 3: Límite de trades
    if(g_tradesToday >= InpMaxTradesPerDay) {
        return;
    }
    
    // Check 4: Horario de trading
    if(!IsInTradingHours()) {
        return;
    }
    
    // Calcular VWAP
    double vwap = CalculateVWAP();
    if(vwap == 0) {
        return; // Sin print para evitar spam
    }
    
    // v2.4: Obtener ATR con retry logic y validación de handle
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);
    if(SafeCopyBuffer(g_atrHandle, 0, 0, 1, atrBuffer) <= 0) {
        Print("⚠️ E4_Vol: No se pudo obtener ATR - Omitiendo tick");
        return;
    }
    double atr = atrBuffer[0];
    
    // v2.2: ATR Adaptativo
    double atrMultiplier = InpATRMultiplier;
    if(InpUseAdaptiveATR) {
        atrMultiplier = CalculateAdaptiveATRMultiplier();
    }
    
    // v2.4: Obtener RSI con retry logic
    double rsiBuffer[];
    ArraySetAsSeries(rsiBuffer, true);
    if(SafeCopyBuffer(g_rsiHandle, 0, 0, 1, rsiBuffer) <= 0) {
        Print("⚠️ E4_Vol: No se pudo obtener RSI - Omitiendo tick");
        return;
    }
    double rsi = rsiBuffer[0];
    
    // v2.2: Obtener Bollinger Bands si está activado
    double bbUpper = 0, bbMiddle = 0, bbLower = 0;
    if(InpUseBBFilter) {
        double bbUpperBuffer[], bbMiddleBuffer[], bbLowerBuffer[];
        ArraySetAsSeries(bbUpperBuffer, true);
        ArraySetAsSeries(bbMiddleBuffer, true);
        ArraySetAsSeries(bbLowerBuffer, true);
        
        if(SafeCopyBuffer(g_bbHandle, 1, 0, 1, bbUpperBuffer) > 0 &&
           SafeCopyBuffer(g_bbHandle, 0, 0, 1, bbMiddleBuffer) > 0 &&
           SafeCopyBuffer(g_bbHandle, 2, 0, 1, bbLowerBuffer) > 0) {
            bbUpper = bbUpperBuffer[0];
            bbMiddle = bbMiddleBuffer[0];
            bbLower = bbLowerBuffer[0];
        }
    }
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Filtro de volumen bajo
    if(!IsLowVolume()) {
        return;
    }
    
    // DEBUG: Print cada 100 ticks para monitorear
    static int tick_count = 0;
    tick_count++;
    if(tick_count % 100 == 0) {
        Print("📊 E4_VolArb v2.2: VWAP=", FormatDouble(vwap, 5), 
              " | Precio=", FormatDouble(currentPrice, 5),
              " | ATR=", FormatDouble(atr, 5), " (Mult=", FormatDouble(atrMultiplier, 2), ")",
              " | RSI=", FormatDouble(rsi, 1),
              " | Dist=", FormatDouble(MathAbs(currentPrice - vwap) / atr, 2), "xATR",
              InpUseBBFilter ? " | BB: [" + DoubleToString(bbLower, 5) + " - " + DoubleToString(bbUpper, 5) + "]" : "");
    }
    
    // v2.2: Detectar reversión bajista con filtros avanzados
    // Condiciones:
    // 1. Price > VWAP + (ATR * multiplier adaptativo) ✅
    // 2. RSI > 68 (sobrecompra) ✅
    // 3. BB Filter: Price > BB Upper (opcional) ✅
    // 4. WAD Divergence: Price up, WAD down (opcional) ✅
    // 5. Volumen bajo (filtro de liquidez) ✅
    
    bool sellCondition1 = currentPrice > vwap + (atrMultiplier * atr);
    bool sellCondition2 = rsi > InpRSIOverbought;
    bool sellCondition3 = !InpUseBBFilter || (currentPrice > bbUpper);
    bool sellCondition4 = !InpUseWADDivergence || CheckBearishDivergence(currentPrice);
    bool sellCondition5 = IsLowVolume();
    
    if(sellCondition1 && sellCondition2 && sellCondition3 && sellCondition4 && sellCondition5) {
        Print("🔴 E4_VolArb v2.2: SEÑAL SELL detectada!");
        Print("   ✅ VWAP Dist: ", FormatDouble((currentPrice - vwap) / atr, 2), "xATR");
        Print("   ✅ RSI: ", FormatDouble(rsi, 1), " > ", InpRSIOverbought);
        if(InpUseBBFilter) Print("   ✅ BB: Precio > Upper (", FormatDouble(bbUpper, 5), ")");
        if(InpUseWADDivergence) Print("   ✅ WAD: Divergencia bajista confirmada");
        
        ExecuteTrade(ORDER_TYPE_SELL, vwap, atr, currentPrice, atrMultiplier);
        return;
    }
    
    // v2.2: Detectar reversión alcista con filtros avanzados
    bool buyCondition1 = currentPrice < vwap - (atrMultiplier * atr);
    bool buyCondition2 = rsi < InpRSIOversold;
    bool buyCondition3 = !InpUseBBFilter || (currentPrice < bbLower);
    bool buyCondition4 = !InpUseWADDivergence || CheckBullishDivergence(currentPrice);
    bool buyCondition5 = IsLowVolume();
    
    if(buyCondition1 && buyCondition2 && buyCondition3 && buyCondition4 && buyCondition5) {
        Print("🟢 E4_VolArb v2.2: SEÑAL BUY detectada!");
        Print("   ✅ VWAP Dist: ", FormatDouble((vwap - currentPrice) / atr, 2), "xATR");
        Print("   ✅ RSI: ", FormatDouble(rsi, 1), " < ", InpRSIOversold);
        if(InpUseBBFilter) Print("   ✅ BB: Precio < Lower (", FormatDouble(bbLower, 5), ")");
        if(InpUseWADDivergence) Print("   ✅ WAD: Divergencia alcista confirmada");
        
        ExecuteTrade(ORDER_TYPE_BUY, vwap, atr, currentPrice, atrMultiplier);
        return;
    }
}

//+------------------------------------------------------------------+
//| v2.2: Función para calcular multiplicador ATR adaptativo          |
//+------------------------------------------------------------------+
double CalculateAdaptiveATRMultiplier() {
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);
    
    // v2.4: Copiar últimos 50 valores de ATR con retry logic
    if(SafeCopyBuffer(g_atrHandle, 0, 0, InpATRAdaptivePeriod, atrBuffer) <= 0) {
        Print("⚠️ E4_Vol: Error en ATR adaptativo - Usando multiplicador fijo");
        return InpATRMultiplier; // Fallback a multiplicador fijo
    }
    
    // Calcular promedio de ATR
    double atrSum = 0;
    for(int i = 0; i < InpATRAdaptivePeriod; i++) {
        atrSum += atrBuffer[i];
    }
    double atrAvg = atrSum / InpATRAdaptivePeriod;
    double currentATR = atrBuffer[0];
    
    // Volatilidad alta: multiplicador bajo (1.2) - entrar más cerca de VWAP
    if(currentATR > atrAvg * 1.5) {
        return 1.2;
    }
    // Volatilidad baja: multiplicador alto (2.0) - esperar desviaciones mayores
    else if(currentATR < atrAvg * 0.7) {
        return 2.0;
    }
    // Volatilidad normal: usar multiplicador estándar
    else {
        return InpATRMultiplier;
    }
}

//+------------------------------------------------------------------+
//| v2.2: Función para detectar divergencia bajista WAD              |
//+------------------------------------------------------------------+
bool CheckBearishDivergence(double currentPrice) {
    double wadBuffer[];
    double priceBuffer[];
    ArraySetAsSeries(wadBuffer, true);
    ArraySetAsSeries(priceBuffer, true);
    
    // v2.4: Copiar con retry logic
    if(SafeCopyBuffer(g_wadHandle, 0, 0, 3, wadBuffer) <= 0) return false;
    if(CopyClose(_Symbol, _Period, 0, 3, priceBuffer) <= 0) return false;
    
    // Divergencia bajista: Precio sube, WAD baja
    bool priceRising = (priceBuffer[0] > priceBuffer[2]);
    bool wadFalling = (wadBuffer[0] < wadBuffer[2]);
    
    return (priceRising && wadFalling);
}

//+------------------------------------------------------------------+
//| v2.2: Función para detectar divergencia alcista WAD              |
//+------------------------------------------------------------------+
bool CheckBullishDivergence(double currentPrice) {
    double wadBuffer[];
    double priceBuffer[];
    ArraySetAsSeries(wadBuffer, true);
    ArraySetAsSeries(priceBuffer, true);
    
    // v2.4: Copiar con retry logic
    if(SafeCopyBuffer(g_wadHandle, 0, 0, 3, wadBuffer) <= 0) return false;
    if(CopyClose(_Symbol, _Period, 0, 3, priceBuffer) <= 0) return false;
    
    // Divergencia alcista: Precio baja, WAD sube
    bool priceFalling = (priceBuffer[0] < priceBuffer[2]);
    bool wadRising = (wadBuffer[0] > wadBuffer[2]);
    
    return (priceFalling && wadRising);
}

//+------------------------------------------------------------------+
//| Calcula VWAP desde apertura del día (MQL5 correcto)              |
//+------------------------------------------------------------------+
double CalculateVWAP() {
    // Obtener inicio del día actual
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    dt.hour = 0;
    dt.min = 0;
    dt.sec = 0;
    datetime todayStart = StructToTime(dt);
    
    // Copiar datos de precios y volumen (MQL5)
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
    
    double sumPV = 0;
    double sumV = 0;
    
    for(int i = 0; i < bars; i++) {
        double typical = (high[i] + low[i] + close[i]) / 3.0;
        sumPV += typical * (double)volume[i];
        sumV += (double)volume[i];
    }
    
    return sumV > 0 ? sumPV / sumV : 0;
}

//+------------------------------------------------------------------+
//| Verifica si el volumen es bajo (MQL5 correcto)                   |
//+------------------------------------------------------------------+
bool IsLowVolume() {
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
    
    return (currentVol < avgVol * InpVolumeThreshold);
}

//+------------------------------------------------------------------+
//| Verifica horario de trading (v2.5 - GMT con offset)              |
//+------------------------------------------------------------------+
bool IsInTradingHours() {
    MqlDateTime current;
    TimeToStruct(TimeCurrent(), current);
    
    // v2.5: Ajustar hora del servidor por offset
    int adjustedHour = current.hour - InpServerTimeOffset;
    if(adjustedHour < 0) adjustedHour += 24;
    if(adjustedHour >= 24) adjustedHour -= 24;
    
    bool inHours = (adjustedHour >= InpTradingStartHour && adjustedHour < InpTradingEndHour);
    
    // v2.5: DEBUG cada 100 ticks para diagnosticar problemas de horario
    static int debugCount = 0;
    debugCount++;
    if(debugCount % 100 == 0) {
        Print("⏰ E4_Vol DEBUG: ServerTime=", current.hour, ":00 GMT | ",
              "AdjustedTime=", adjustedHour, ":00 GMT | ",
              "TradingRange=", InpTradingStartHour, "-", InpTradingEndHour, " | ",
              "InHours=", inHours ? "✅ YES" : "❌ NO");
    }
    
    return inHours;
}

//+------------------------------------------------------------------+
//| Ejecuta trade de reversión (v2.2 con ATR adaptativo)             |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType, double vwap, double atr, double currentPrice, double atrMultiplier) {
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    double slPrice, tpPrice;
    double entryPrice = SymbolInfoDouble(_Symbol, 
                        orderType == ORDER_TYPE_BUY ? SYMBOL_ASK : SYMBOL_BID);
    
    // SL: VWAP ± 0.5*ATR
    // TP: VWAP (reversión completa)
    if(orderType == ORDER_TYPE_BUY) {
        slPrice = vwap - (InpSLMultiplier * atr);
        tpPrice = vwap;
    } else {
        slPrice = vwap + (InpSLMultiplier * atr);
        tpPrice = vwap;
    }
    
    // Calcular lotaje
    double slPips = CalculatePips(_Symbol, MathAbs(entryPrice - slPrice));
    double lots = riskMgr.CalculateLotSize(InpRiskPercent, slPips);
    
    if(lots == 0) {
        Print("❌ E4_VolArb: Error calculando lotaje");
        return;
    }
    
    // Ejecutar orden
    bool result = false;
    string comment = "E4_VolArb_v2.2_ATR" + DoubleToString(atrMultiplier, 1);
    
    if(orderType == ORDER_TYPE_BUY) {
        result = trade.Buy(lots, _Symbol, 0, slPrice, tpPrice, comment);
    } else {
        result = trade.Sell(lots, _Symbol, 0, slPrice, tpPrice, comment);
    }
    
    if(result) {
        g_tradesToday++;
        
        double distanceToVWAP = MathAbs(currentPrice - vwap);
        double distanceInATR = distanceToVWAP / atr;
        
        Print("==================================================");
        Print("✅ E4_VolArb: TRADE #", g_tradesToday, " EJECUTADO");
        Print("📍 Tipo: ", EnumToString(orderType));
        Print("💵 Lots: ", lots);
        Print("📊 VWAP: ", vwap);
        Print("📏 Distancia: ", FormatDouble(distanceInATR, 2), " ATRs");
        Print("📉 SL: ", slPrice);
        Print("📈 TP: ", tpPrice, " (VWAP)");
        Print("==================================================");
    } else {
        Print("❌ E4_VolArb: Error ejecutando trade. Code: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Reset contador diario                                            |
//+------------------------------------------------------------------+
void ResetDailyCounter() {
    MqlDateTime current;
    TimeToStruct(TimeCurrent(), current);
    
    if(g_lastResetDate != 0) {
        MqlDateTime lastReset;
        TimeToStruct(g_lastResetDate, lastReset);
        
        if(lastReset.day != current.day) {
            g_tradesToday = 0;
            g_lastResetDate = TimeCurrent();
            Print("🌅 E4_VolArb: Nuevo día - Contador de trades reseteado");
        }
    } else {
        g_lastResetDate = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
