//+------------------------------------------------------------------+
//| E3_VWAP_Breakout.mq5 - Momentum Breakout with VWAP + UT Bot      |
//| Squad of Systems - Trading System                                |
//| Copyright 2025, SoS Trading                                       |
//+------------------------------------------------------------------+
#property copyright "SoS Trading System"
#property link      "https://github.com/sos-trading"
#property version   "2.20"
#property description "Momentum Breakout with VWAP, ADX, UT Bot, and LRC Filters"

#include <Trade\Trade.mqh>
#include "..\..\Include\SoS_Commons.mqh"
#include "..\..\Include\SoS_GlobalComms.mqh"
#include "..\..\Include\SoS_RiskManager.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== SIGNAL SETTINGS ==="
input int    InpSwingLookback = 10;             // Lookback para swing high/low (reducido)
input double InpATRMultiplier = 1.5;            // Distancia mínima al VWAP (relajado)
input double InpATR_SL_Multiplier = 1.5;        // SL en términos de ATR
input double InpMinADX = 20.0;                  // ADX mínimo para tendencia (relajado)
input double InpExitADX = 15.0;                 // ADX de salida
input double InpVolumeThreshold = 0.8;          // % Volumen vs promedio (más permisivo)

input group "=== v2.2 UT BOT FILTER ==="
input bool   InpUseUTBot = true;                // Usar UT Bot Alerts
input int    InpUTBotPeriod = 7;                // UT Bot ATR Period
input double InpUTBotSensitivity = 2.0;         // UT Bot Sensitivity (ATR multiplier)

input group "=== v2.2 LINEAR REGRESSION FILTER ==="
input bool   InpUseLRC = true;                  // Usar Linear Regression Candles
input int    InpLRCPeriod = 50;                 // LRC Lookback Period
input double InpLRCMinSlope = 0.0001;           // LRC Min Slope (filtrar rango)

input group "=== v2.2 H1 TREND FILTER ==="
input bool   InpUseH1Trend = true;              // Usar H1 EMA 50 Trend Filter
input int    InpH1EMA = 50;                     // H1 EMA Period

input group "=== RISK MANAGEMENT ==="
input double InpRiskPercent = 0.5;              // Riesgo por trade (%)

input group "=== LIMITS ==="
input int    InpMaxTradesPerDay = 2;            // Máximo trades diarios

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;
RiskManager riskMgr(_Symbol, MAGIC_E3_VWAP);  // v2.4: Constructor con magic para TradeHistory

int g_tradesToday = 0;
datetime g_lastResetDate = 0;
ulong g_currentTicket = 0;

// Indicator handles (MQL5)
int g_adxHandle = INVALID_HANDLE;
int g_atrHandle = INVALID_HANDLE;
int g_utbotAtrHandle = INVALID_HANDLE;  // v2.2: UT Bot usa ATR separado
int g_lrcHandle = INVALID_HANDLE;       // v2.2: Linear Regression
int g_h1EmaHandle = INVALID_HANDLE;     // v2.2: H1 EMA 50

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
    trade.SetExpertMagicNumber(MAGIC_E3_VWAP);
    trade.SetDeviationInPoints(50);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    // Crear handles de indicadores (MQL5)
    g_adxHandle = iADX(_Symbol, PERIOD_M15, 14);
    g_atrHandle = iATR(_Symbol, PERIOD_M15, 14);
    
    if(g_adxHandle == INVALID_HANDLE || g_atrHandle == INVALID_HANDLE) {
        Print("❌ E3_VWAP v2.2: Error creando handles de indicadores base");
        return(INIT_FAILED);
    }
    
    // v2.2: UT Bot - ATR separado para trailing
    if(InpUseUTBot) {
        g_utbotAtrHandle = iATR(_Symbol, PERIOD_M15, InpUTBotPeriod);
        if(g_utbotAtrHandle == INVALID_HANDLE) {
            Print("❌ E3_VWAP v2.2: Error creando handle UT Bot ATR");
            return(INIT_FAILED);
        }
    }
    
    // v2.2: Linear Regression Channel
    if(InpUseLRC) {
        g_lrcHandle = iMA(_Symbol, PERIOD_M15, InpLRCPeriod, 0, MODE_LWMA, PRICE_CLOSE);
        if(g_lrcHandle == INVALID_HANDLE) {
            Print("❌ E3_VWAP v2.2: Error creando handle Linear Regression");
            return(INIT_FAILED);
        }
    }
    
    // v2.2: H1 EMA 50 Trend Filter
    if(InpUseH1Trend) {
        g_h1EmaHandle = iMA(_Symbol, PERIOD_H1, InpH1EMA, 0, MODE_EMA, PRICE_CLOSE);
        if(g_h1EmaHandle == INVALID_HANDLE) {
            Print("❌ E3_VWAP v2.2: Error creando handle H1 EMA");
            return(INIT_FAILED);
        }
    }
    
    Print("==================================================");
    Print("✅ E3_VWAP_Breakout v2.2 (UT Bot + LRC + H1) Inicializado");
    Print("📊 Swing Lookback: ", InpSwingLookback);
    Print("📏 VWAP Distance: ", InpATRMultiplier, " ATRs");
    Print("📈 Min ADX: ", InpMinADX);
    if(InpUseUTBot) Print("🤖 UT Bot: Period=", InpUTBotPeriod, " Sens=", InpUTBotSensitivity);
    if(InpUseLRC) Print("📐 LRC: Period=", InpLRCPeriod, " MinSlope=", InpLRCMinSlope);
    if(InpUseH1Trend) Print("⏰ H1 EMA: ", InpH1EMA);
    Print("💰 Riesgo: ", InpRiskPercent, "%");
    Print("==================================================");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // Liberar handles de indicadores (MQL5)
    if(g_adxHandle != INVALID_HANDLE) IndicatorRelease(g_adxHandle);
    if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
    if(g_utbotAtrHandle != INVALID_HANDLE) IndicatorRelease(g_utbotAtrHandle);  // v2.2
    if(g_lrcHandle != INVALID_HANDLE) IndicatorRelease(g_lrcHandle);            // v2.2
    if(g_h1EmaHandle != INVALID_HANDLE) IndicatorRelease(g_h1EmaHandle);        // v2.2
    
    Print("🛑 E3_VWAP_Breakout v2.2 Detenido. Razón: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
    // Check 1: ¿Podemos operar?
    if(!GlobalComms::CanTrade(MAGIC_E3_VWAP)) {
        // Si breakouts están desactivados, cerrar posición actual
        if(g_currentTicket > 0) {
            if(trade.PositionClose(g_currentTicket)) {
                Print("⚠️ E3_VWAP: Posición cerrada por filtro VIX/Breakout disabled");
                g_currentTicket = 0;
            }
        }
        return;
    }
    
    // Check 2: Reset diario
    ResetDailyCounter();
    
    // Check 3: Gestionar posición abierta
    if(g_currentTicket > 0) {
        ManageOpenPosition();
        return; // No abrir nueva posición si hay una activa
    }
    
    // Check 4: Límite de trades
    if(g_tradesToday >= InpMaxTradesPerDay) {
        return;
    }
    
    // Calcular VWAP
    double vwap = CalculateVWAP();
    if(vwap == 0) return;
    
    // v2.4: Obtener ATR con retry logic
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);
    if(SafeCopyBuffer(g_atrHandle, 0, 0, 1, atrBuffer) <= 0) {
        Print("⚠️ E3_VWAP: Error obteniendo ATR - Omitiendo tick");
        return;
    }
    double atr = atrBuffer[0];
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // v2.4: Obtener ADX con retry logic
    double adxBuffer[];
    ArraySetAsSeries(adxBuffer, true);
    if(SafeCopyBuffer(g_adxHandle, 0, 0, 1, adxBuffer) <= 0) {
        Print("⚠️ E3_VWAP: Error obteniendo ADX - Omitiendo tick");
        return;
    }
    double adx = adxBuffer[0];
    
    // Filtro ADX: necesitamos tendencia fuerte
    if(adx < InpMinADX) {
        return;
    }
    
    // Filtro VWAP: necesitamos distancia mínima
    if(MathAbs(currentPrice - vwap) < InpATRMultiplier * atr) {
        return;
    }
    
    // Filtro volumen bajo
    if(!IsLowVolume()) {
        return;
    }
    
    // v2.2: Filtro H1 EMA 50 - Solo operar a favor de tendencia H1
    if(InpUseH1Trend && !CheckH1Trend()) {
        return;
    }
    
    // v2.2: Filtro Linear Regression - Evitar rangos laterales
    if(InpUseLRC && !CheckLRCTrend()) {
        return;
    }
    
    // v2.2: UT Bot - Confirmar dirección con trailing
    int utbotSignal = 0;  // 1=BUY, -1=SELL, 0=neutral
    if(InpUseUTBot) {
        utbotSignal = GetUTBotSignal();
        if(utbotSignal == 0) return;  // No hay señal clara
    }
    
    // Detectar swing high/low usando arrays MQL5
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    int copied_high = CopyHigh(_Symbol, PERIOD_M15, 1, InpSwingLookback, high);
    int copied_low = CopyLow(_Symbol, PERIOD_M15, 1, InpSwingLookback, low);
    
    if(copied_high < InpSwingLookback || copied_low < InpSwingLookback) {
        return;
    }
    
    int max_index = ArrayMaximum(high, 0, InpSwingLookback);
    int min_index = ArrayMinimum(low, 0, InpSwingLookback);
    
    double swingHigh = high[max_index];
    double swingLow = low[min_index];
    
    // v2.2: Ruptura alcista con confirmación UT Bot
    if(currentPrice > swingHigh) {
        if(InpUseUTBot && utbotSignal != 1) return;  // UT Bot debe confirmar BUY
        
        Print("🟢 E3_VWAP v2.2: Ruptura alcista detectada! ADX=", FormatDouble(adx, 1),
              InpUseUTBot ? " | UT Bot: BUY✅" : "",
              InpUseLRC ? " | LRC: Trend✅" : "",
              InpUseH1Trend ? " | H1: Bullish✅" : "");
        ExecuteTrade(ORDER_TYPE_BUY, atr);
        return;
    }
    
    // v2.2: Ruptura bajista con confirmación UT Bot
    if(currentPrice < swingLow) {
        if(InpUseUTBot && utbotSignal != -1) return;  // UT Bot debe confirmar SELL
        
        Print("🔴 E3_VWAP v2.2: Ruptura bajista detectada! ADX=", FormatDouble(adx, 1),
              InpUseUTBot ? " | UT Bot: SELL✅" : "",
              InpUseLRC ? " | LRC: Trend✅" : "",
              InpUseH1Trend ? " | H1: Bearish✅" : "");
        ExecuteTrade(ORDER_TYPE_SELL, atr);
        return;
    }
}

//+------------------------------------------------------------------+
//| Gestiona posición abierta (Trailing Stop y salida por ADX)       |
//+------------------------------------------------------------------+
void ManageOpenPosition() {
    if(!PositionSelectByTicket(g_currentTicket)) {
        g_currentTicket = 0;
        return;
    }
    
    // v2.4: Check ADX para salida anticipada con retry logic
    double adxBuffer[];
    ArraySetAsSeries(adxBuffer, true);
    
    if(SafeCopyBuffer(g_adxHandle, 0, 0, 1, adxBuffer) > 0) {
        double adx = adxBuffer[0];
        
        if(adx < InpExitADX) {
            if(trade.PositionClose(g_currentTicket)) {
                Print("📉 E3_VWAP: Posición cerrada por ADX débil (", FormatDouble(adx, 1), ")");
                g_currentTicket = 0;
            }
            return;
        }
    }
    
    // v2.4: Trailing Stop basado en ATR con retry logic
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);
    if(SafeCopyBuffer(g_atrHandle, 0, 0, 1, atrBuffer) <= 0) {
        return;
    }
    double atr = atrBuffer[0];
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    
    double newSL = 0;
    
    if(posType == POSITION_TYPE_BUY) {
        newSL = currentPrice - (InpATR_SL_Multiplier * atr);
        
        // Solo mover SL hacia arriba
        if(newSL > currentSL) {
            if(trade.PositionModify(g_currentTicket, newSL, currentTP)) {
                Print("📊 E3_VWAP: Trailing SL actualizado → ", newSL, 
                      " (+", FormatDouble(CalculatePips(_Symbol, newSL - currentSL), 1), " pips)");
            }
        }
    } else {
        newSL = currentPrice + (InpATR_SL_Multiplier * atr);
        
        // Solo mover SL hacia abajo
        if(newSL < currentSL || currentSL == 0) {
            if(trade.PositionModify(g_currentTicket, newSL, currentTP)) {
                Print("📊 E3_VWAP: Trailing SL actualizado → ", newSL,
                      " (-", FormatDouble(CalculatePips(_Symbol, currentSL - newSL), 1), " pips)");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Ejecuta trade de breakout                                        |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType, double atr) {
    double entryPrice = SymbolInfoDouble(_Symbol, 
                        orderType == ORDER_TYPE_BUY ? SYMBOL_ASK : SYMBOL_BID);
    
    double slPrice;
    if(orderType == ORDER_TYPE_BUY) {
        slPrice = entryPrice - (InpATR_SL_Multiplier * atr);
    } else {
        slPrice = entryPrice + (InpATR_SL_Multiplier * atr);
    }
    
    // Calcular lotaje
    double slPips = CalculatePips(_Symbol, MathAbs(entryPrice - slPrice));
    double lots = riskMgr.CalculateLotSize(InpRiskPercent, slPips);
    
    if(lots == 0) {
        Print("❌ E3_VWAP: Error calculando lotaje");
        return;
    }
    
    // Ejecutar orden (sin TP fijo, usaremos trailing stop)
    bool result = false;
    string comment = "E3_VWAP_" + EnumToString(orderType);
    
    if(orderType == ORDER_TYPE_BUY) {
        result = trade.Buy(lots, _Symbol, 0, slPrice, 0, comment);
    } else {
        result = trade.Sell(lots, _Symbol, 0, slPrice, 0, comment);
    }
    
    if(result) {
        g_currentTicket = trade.ResultOrder();
        g_tradesToday++;
        
        Print("==================================================");
        Print("✅ E3_VWAP: BREAKOUT TRADE #", g_tradesToday);
        Print("🎫 Ticket: ", g_currentTicket);
        Print("📍 Tipo: ", EnumToString(orderType));
        Print("💵 Lots: ", lots);
        Print("📉 SL: ", slPrice, " (", FormatDouble(slPips, 1), " pips)");
        Print("🔄 TP: Trailing Stop (ATR-based)");
        Print("==================================================");
    } else {
        Print("❌ E3_VWAP: Error ejecutando trade. Code: ", GetLastError());
    }
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
            Print("🌅 E3_VWAP: Nuevo día - Contador reseteado");
        }
    } else {
        g_lastResetDate = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| v2.2: Obtener señal UT Bot (basado en trailing ATR)              |
//+------------------------------------------------------------------+
int GetUTBotSignal() {
    double atrBuffer[];
    double closeBuffer[];
    ArraySetAsSeries(atrBuffer, true);
    ArraySetAsSeries(closeBuffer, true);
    
    // v2.4: Copiar ATR y precios de cierre con retry logic
    if(SafeCopyBuffer(g_utbotAtrHandle, 0, 0, 3, atrBuffer) <= 0) return 0;
    if(CopyClose(_Symbol, PERIOD_M15, 0, 3, closeBuffer) <= 0) return 0;
    
    // Calcular trailing stop UT Bot
    double atr = atrBuffer[0];
    double trailStop = closeBuffer[1] - (InpUTBotSensitivity * atr);
    
    // Señal BUY: Precio rompe por encima del trailing stop
    if(closeBuffer[0] > trailStop && closeBuffer[1] <= (closeBuffer[2] - InpUTBotSensitivity * atrBuffer[1])) {
        return 1;  // BUY
    }
    
    // Señal SELL: Precio rompe por debajo del trailing stop
    trailStop = closeBuffer[1] + (InpUTBotSensitivity * atr);
    if(closeBuffer[0] < trailStop && closeBuffer[1] >= (closeBuffer[2] + InpUTBotSensitivity * atrBuffer[1])) {
        return -1;  // SELL
    }
    
    return 0;  // No hay señal
}

//+------------------------------------------------------------------+
//| v2.2: Verificar tendencia con Linear Regression                  |
//+------------------------------------------------------------------+
bool CheckLRCTrend() {
    double lrcBuffer[];
    ArraySetAsSeries(lrcBuffer, true);
    
    // v2.4: Copiar valores de regresión lineal con retry logic
    if(SafeCopyBuffer(g_lrcHandle, 0, 0, 3, lrcBuffer) <= 0) return false;
    
    // Calcular pendiente de la regresión
    double slope = (lrcBuffer[0] - lrcBuffer[2]) / 2.0;
    
    // Si la pendiente es muy pequeña, estamos en rango (evitar)
    if(MathAbs(slope) < InpLRCMinSlope) {
        return false;  // Mercado lateral, no operar
    }
    
    return true;  // Tendencia clara
}

//+------------------------------------------------------------------+
//| v2.2: Verificar tendencia H1 con EMA 50                          |
//+------------------------------------------------------------------+
bool CheckH1Trend() {
    double emaBuffer[];
    double closeBuffer[];
    ArraySetAsSeries(emaBuffer, true);
    ArraySetAsSeries(closeBuffer, true);
    
    // v2.4: Copiar EMA H1 y precio actual con retry logic
    if(SafeCopyBuffer(g_h1EmaHandle, 0, 0, 1, emaBuffer) <= 0) return false;
    if(CopyClose(_Symbol, PERIOD_H1, 0, 1, closeBuffer) <= 0) return false;
    
    double ema = emaBuffer[0];
    double price = closeBuffer[0];
    
    // Solo operar si hay distancia suficiente del EMA (evitar chop)
    double minDistance = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50;
    
    if(MathAbs(price - ema) < minDistance) {
        return false;  // Demasiado cerca del EMA
    }
    
    return true;  // Tendencia H1 clara
}

//+------------------------------------------------------------------+
