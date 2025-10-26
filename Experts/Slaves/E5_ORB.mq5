//+------------------------------------------------------------------+
//| E5_ORB.mq5 - Opening Range Breakout + Session HL + VROC + Calendar|
//| Squad of Systems - Trading System                                |
//| Copyright 2025, SoS Trading                                       |
//+------------------------------------------------------------------+
#property copyright "SoS Trading System"
#property link      "https://github.com/sos-trading"
#property version   "2.30"
#property description "Opening Range Breakout with Session Levels, VROC, and MT5 Calendar News Filter"

#include <Trade\Trade.mqh>
#include "..\..\Include\SoS_Commons.mqh"
#include "..\..\Include\SoS_GlobalComms.mqh"
#include "..\..\Include\SoS_RiskManager.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== SESSION SETTINGS ==="
input int    InpSessionStartHour = 9;           // Hora inicio sesión (EST)
input int    InpSessionStartMinute = 30;        // Minuto inicio sesión
input int    InpRangePeriodMinutes = 30;        // Duración del rango (reducido)
input int    InpSessionEndHour = 16;            // Hora fin sesión (EST)

input group "=== ENTRY FILTERS ==="
input double InpBufferPips = 3.0;               // Buffer para entrada (reducido)
input double InpMinATRMultiplier = 0.8;         // ATR mínimo vs promedio (relajado)
input double InpVolumeMultiplier = 1.2;         // Volumen mín vs promedio

input group "=== v2.2 SESSION HIGH/LOW FILTER ==="
input bool   InpUseSessionHL = true;            // Usar Session High/Low
input int    InpAsianSessionStart = 0;          // Hora inicio sesión asiática (GMT)
input int    InpAsianSessionEnd = 8;            // Hora fin sesión asiática (GMT)

input group "=== v2.2 VROC VOLUME FILTER ==="
input bool   InpUseVROC = true;                 // Usar VROC (Volume Rate of Change)
input int    InpVROCPeriod = 14;                // VROC Period
input double InpVROCThreshold = 20.0;           // VROC Min % (breakout fuerte)

input group "=== v2.2 NEWS FILTER ==="
input bool   InpUseNewsFilter = true;           // Usar News Filter
input int    InpNewsAvoidMinutes = 60;          // Minutos evitar antes/después noticia
input string InpNewsCountryCodes = "US,EU,GB";  // v2.3: Códigos países
input ENUM_CALENDAR_EVENT_IMPORTANCE InpNewsMinImportance = CALENDAR_IMPORTANCE_HIGH;  // v2.3: Importancia mínima

input group "=== RISK MANAGEMENT ==="
input double InpRiskPercent = 0.5;              // Riesgo por trade (%)
input double InpTPMultiplier = 1.5;             // TP como múltiplo del rango

input group "=== LIMITS ==="
input int    InpMaxTradesPerDay = 1;            // Máximo trades diarios

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;
RiskManager riskMgr(_Symbol, MAGIC_E5_ORB);  // v2.4: Constructor con magic para TradeHistory

double g_rangeHigh = 0;
double g_rangeLow = 0;
bool g_rangeDefined = false;
bool g_tradedToday = false;
datetime g_lastTradeDate = 0;

// v2.2: Session High/Low tracking
double g_asianSessionHigh = 0;
double g_asianSessionLow = 0;
bool g_asianSessionDefined = false;

// v2.3: Calendar news tracking
string g_newsCountryIds[];
int g_newsCountryCount = 0;

// Indicator handle (MQL5)
int g_atrHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
    // Configurar trade object
    trade.SetExpertMagicNumber(MAGIC_E5_ORB);
    trade.SetDeviationInPoints(50);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    // Crear handle de ATR (MQL5)
    g_atrHandle = iATR(_Symbol, PERIOD_H1, 14);
    if(g_atrHandle == INVALID_HANDLE) {
        Print("❌ E5_ORB v2.3: Error creando handle de ATR");
        return(INIT_FAILED);
    }
    
    // v2.3: Parsear country codes para news filter
    if(InpUseNewsFilter) {
        ParseNewsCountryCodes(InpNewsCountryCodes);
        
        if(g_newsCountryCount == 0) {
            Print("⚠️ E5_ORB v2.3: No se pudieron parsear country codes - News filter desactivado");
        } else {
            Print("✅ E5_ORB v2.3: News Filter - ", g_newsCountryCount, " países: ", InpNewsCountryCodes);
        }
    }
    
    Print("==================================================");
    Print("✅ E5_ORB v2.3 (Session HL + VROC + Calendar News) Inicializado");
    Print("📊 Sesión: ", InpSessionStartHour, ":", InpSessionStartMinute, 
          " - ", InpSessionEndHour, ":00 EST");
    Print("📏 Rango: ", InpRangePeriodMinutes, " minutos");
    if(InpUseSessionHL) Print("🌏 Asian Session: ", InpAsianSessionStart, ":00 - ", InpAsianSessionEnd, ":00 GMT");
    if(InpUseVROC) Print("📈 VROC: Period=", InpVROCPeriod, " Threshold=", InpVROCThreshold, "%");
    if(InpUseNewsFilter) Print("📰 News Avoid: ", InpNewsAvoidMinutes, " min | Countries: ", InpNewsCountryCodes);
    Print("💰 Riesgo: ", InpRiskPercent, "%");
    Print("==================================================");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // Liberar handle de indicador (MQL5)
    if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
    
    // v2.3: Limpiar arrays
    ArrayFree(g_newsCountryIds);
    
    Print("🛑 E5_ORB v2.3 Detenido. Razón: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
    // Check 1: ¿Podemos operar?
    if(!GlobalComms::CanTrade(MAGIC_E5_ORB)) {
        return;
    }
    
    // Check 2: Reset diario
    ResetDaily();
    
    // Check 3: ¿Ya operamos hoy?
    if(g_tradedToday) return;
    
    // Check 4: ¿Estamos fuera de sesión?
    if(!IsInTradingSession()) return;
    
    // v2.2: Check 5: News Filter - Evitar trading cerca de noticias
    if(InpUseNewsFilter && IsNearNewsEvent()) {
        Print("📰 E5_ORB v2.2: Trading pausado - Cerca de evento de noticias");
        return;
    }
    
    // v2.2: Definir Asian Session High/Low si aplica
    if(InpUseSessionHL && !g_asianSessionDefined && IsAfterAsianSession()) {
        DefineAsianSessionLevels();
    }
    
    // Fase 1: Definir rango si estamos en periodo
    if(!g_rangeDefined && IsInRangePeriod()) {
        DefineRange();
        return;
    }
    
    // Fase 2: Esperar ruptura después del periodo
    if(g_rangeDefined && !IsInRangePeriod()) {
        CheckBreakout();
    }
}

//+------------------------------------------------------------------+
//| Reset diario de variables                                        |
//+------------------------------------------------------------------+
void ResetDaily() {
    MqlDateTime currentTime;
    TimeToStruct(TimeCurrent(), currentTime);
    
    if(g_lastTradeDate != 0) {
        MqlDateTime lastTime;
        TimeToStruct(g_lastTradeDate, lastTime);
        
        if(lastTime.day != currentTime.day) {
            g_tradedToday = false;
            g_rangeDefined = false;
            g_rangeHigh = 0;
            g_rangeLow = 0;
            g_asianSessionDefined = false;  // v2.2
            g_asianSessionHigh = 0;          // v2.2
            g_asianSessionLow = 0;           // v2.2
            
            Print("🌅 E5_ORB v2.2: Nuevo día - Variables reseteadas");
        }
    }
}

//+------------------------------------------------------------------+
//| Verifica si estamos en el periodo de definición del rango        |
//+------------------------------------------------------------------+
bool IsInRangePeriod() {
    MqlDateTime current;
    TimeToStruct(TimeCurrent(), current);
    
    int startMinutes = InpSessionStartHour * 60 + InpSessionStartMinute;
    int endMinutes = startMinutes + InpRangePeriodMinutes;
    int currentMinutes = current.hour * 60 + current.min;
    
    return (currentMinutes >= startMinutes && currentMinutes < endMinutes);
}

//+------------------------------------------------------------------+
//| Verifica si estamos en sesión de trading                         |
//+------------------------------------------------------------------+
bool IsInTradingSession() {
    MqlDateTime current;
    TimeToStruct(TimeCurrent(), current);
    
    int currentMinutes = current.hour * 60 + current.min;
    int sessionEnd = InpSessionEndHour * 60;
    
    return (currentMinutes < sessionEnd);
}

//+------------------------------------------------------------------+
//| Define el Opening Range (MQL5 correcto)                          |
//+------------------------------------------------------------------+
void DefineRange() {
    int barsInRange = InpRangePeriodMinutes / 5; // M5 timeframe
    
    // Copiar datos de precios usando arrays MQL5
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    int copied_high = CopyHigh(_Symbol, PERIOD_M5, 0, barsInRange, high);
    int copied_low = CopyLow(_Symbol, PERIOD_M5, 0, barsInRange, low);
    
    if(copied_high < barsInRange || copied_low < barsInRange) {
        return; // No hay suficientes datos
    }
    
    // Encontrar high/low del periodo
    int max_index = ArrayMaximum(high, 0, barsInRange);
    int min_index = ArrayMinimum(low, 0, barsInRange);
    
    g_rangeHigh = high[max_index];
    g_rangeLow = low[min_index];
    g_rangeDefined = true;
    
    double rangeSize = g_rangeHigh - g_rangeLow;
    double rangePips = CalculatePips(_Symbol, rangeSize);
    
    Print("==================================================");
    Print("📊 E5_ORB: Opening Range DEFINIDO");
    Print("📈 High: ", g_rangeHigh);
    Print("📉 Low: ", g_rangeLow);
    Print("📏 Tamaño: ", FormatDouble(rangePips, 1), " pips");
    Print("==================================================");
}

//+------------------------------------------------------------------+
//| Verifica ruptura del rango                                       |
//+------------------------------------------------------------------+
void CheckBreakout() {
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double buffer = InpBufferPips * point * 10;
    
    // Filtro de volumen
    if(!CheckVolumeFilter()) {
        return;
    }
    
    // Filtro ATR
    if(!CheckATRFilter()) {
        return;
    }
    
    // v2.2: Filtro VROC - Confirmar momentum de volumen
    if(InpUseVROC && !CheckVROCFilter()) {
        Print("⚠️ E5_ORB v2.2: VROC insuficiente - Breakout sin momentum");
        return;
    }
    
    // v2.2: Filtro Session High/Low - Confirmar dirección
    bool sessionHLConfirmed = true;
    if(InpUseSessionHL && g_asianSessionDefined) {
        sessionHLConfirmed = CheckSessionHLConfirmation(currentPrice);
        if(!sessionHLConfirmed) {
            Print("⚠️ E5_ORB v2.2: Session HL no confirma dirección");
            return;
        }
    }
    
    // Ruptura alcista
    if(currentPrice > g_rangeHigh + buffer) {
        Print("🟢 E5_ORB v2.2: Ruptura alcista detectada! Precio=", currentPrice, " RangeHigh=", g_rangeHigh,
              InpUseVROC ? " | VROC: Strong✅" : "",
              InpUseSessionHL && g_asianSessionDefined ? " | Asian HL: Bullish✅" : "");
        ExecuteTrade(ORDER_TYPE_BUY);
        return;
    }
    
    // Ruptura bajista
    if(currentPrice < g_rangeLow - buffer) {
        Print("🔴 E5_ORB v2.2: Ruptura bajista detectada! Precio=", currentPrice, " RangeLow=", g_rangeLow,
              InpUseVROC ? " | VROC: Strong✅" : "",
              InpUseSessionHL && g_asianSessionDefined ? " | Asian HL: Bearish✅" : "");
        ExecuteTrade(ORDER_TYPE_SELL);
        return;
    }
}

//+------------------------------------------------------------------+
//| Filtro de volumen (MQL5 correcto)                                |
//+------------------------------------------------------------------+
bool CheckVolumeFilter() {
    long volume[];
    ArraySetAsSeries(volume, true);
    
    int copied = CopyTickVolume(_Symbol, PERIOD_M5, 0, 21, volume);
    if(copied < 21) return false;
    
    long currentVol = volume[0];
    long avgVol = 0;
    
    for(int i = 1; i <= 20; i++) {
        avgVol += volume[i];
    }
    avgVol /= 20;
    
    if(currentVol < avgVol * InpVolumeMultiplier) {
        Print("⚠️ E5_ORB: Volumen insuficiente (", currentVol, " vs ", avgVol, ")");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Filtro ATR (MQL5 correcto con handle persistente)                |
//+------------------------------------------------------------------+
bool CheckATRFilter() {
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);
    
    // v2.4: Obtener ATR actual y últimos 20 valores con retry logic
    int copied = SafeCopyBuffer(g_atrHandle, 0, 0, 21, atrBuffer);
    if(copied < 21) return false;
    
    double atr = atrBuffer[0];
    double avgATR = 0;
    
    for(int i = 1; i <= 20; i++) {
        avgATR += atrBuffer[i];
    }
    avgATR /= 20;
    
    if(atr < avgATR * InpMinATRMultiplier) {
        Print("⚠️ E5_ORB: ATR bajo (", FormatDouble(atr, 5), 
              " vs ", FormatDouble(avgATR, 5), ") - Mercado en rango");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Ejecuta trade                                                     |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType) {
    double rangeSize = g_rangeHigh - g_rangeLow;
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    double slPrice, tpPrice;
    double entryPrice = SymbolInfoDouble(_Symbol, 
                        orderType == ORDER_TYPE_BUY ? SYMBOL_ASK : SYMBOL_BID);
    
    // Calcular SL y TP
    if(orderType == ORDER_TYPE_BUY) {
        slPrice = g_rangeLow;
        tpPrice = g_rangeHigh + (rangeSize * InpTPMultiplier);
    } else {
        slPrice = g_rangeHigh;
        tpPrice = g_rangeLow - (rangeSize * InpTPMultiplier);
    }
    
    // Calcular lotaje
    double slPips = CalculatePips(_Symbol, MathAbs(entryPrice - slPrice));
    double lots = riskMgr.CalculateLotSize(InpRiskPercent, slPips);
    
    if(lots == 0) {
        Print("❌ E5_ORB: Error calculando lotaje");
        return;
    }
    
    // Ejecutar orden
    bool result = false;
    string comment = "E5_ORB_" + EnumToString(orderType);
    
    if(orderType == ORDER_TYPE_BUY) {
        result = trade.Buy(lots, _Symbol, 0, slPrice, tpPrice, comment);
    } else {
        result = trade.Sell(lots, _Symbol, 0, slPrice, tpPrice, comment);
    }
    
    if(result) {
        g_tradedToday = true;
        g_lastTradeDate = TimeCurrent();
        
        Print("==================================================");
        Print("✅ E5_ORB: TRADE EJECUTADO");
        Print("📍 Tipo: ", EnumToString(orderType));
        Print("💵 Lots: ", lots);
        Print("📉 SL: ", slPrice, " (", FormatDouble(slPips, 1), " pips)");
        Print("📈 TP: ", tpPrice);
        Print("🎯 R:R: 1:", FormatDouble(InpTPMultiplier, 2));
        Print("==================================================");
    } else {
        Print("❌ E5_ORB: Error ejecutando trade. Code: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Obtiene timestamp de inicio de sesión                            |
//+------------------------------------------------------------------+
datetime GetSessionStartTime() {
    MqlDateTime current;
    TimeToStruct(TimeCurrent(), current);
    
    current.hour = InpSessionStartHour;
    current.min = InpSessionStartMinute;
    current.sec = 0;
    
    return StructToTime(current);
}

//+------------------------------------------------------------------+
//| v2.2: Define Asian Session High/Low levels                       |
//+------------------------------------------------------------------+
void DefineAsianSessionLevels() {
    // Calcular barras desde inicio sesión asiática hasta ahora
    MqlDateTime current;
    TimeToStruct(TimeCurrent(), current);
    
    // Asumimos que ya pasó la sesión asiática (0:00-8:00 GMT)
    int barsInSession = (InpAsianSessionEnd - InpAsianSessionStart) * 12;  // H1 = 12 bars per hour on M5
    
    double high[];
    double low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    // Copiar datos de la sesión asiática previa
    int copied_high = CopyHigh(_Symbol, PERIOD_M5, 0, barsInSession, high);
    int copied_low = CopyLow(_Symbol, PERIOD_M5, 0, barsInSession, low);
    
    if(copied_high < barsInSession || copied_low < barsInSession) {
        return;
    }
    
    int max_index = ArrayMaximum(high, 0, barsInSession);
    int min_index = ArrayMinimum(low, 0, barsInSession);
    
    g_asianSessionHigh = high[max_index];
    g_asianSessionLow = low[min_index];
    g_asianSessionDefined = true;
    
    Print("🌏 E5_ORB v2.2: Asian Session Levels Definidos");
    Print("   High: ", g_asianSessionHigh, " | Low: ", g_asianSessionLow);
}

//+------------------------------------------------------------------+
//| v2.2: Verificar si estamos después de la sesión asiática         |
//+------------------------------------------------------------------+
bool IsAfterAsianSession() {
    MqlDateTime current;
    TimeToStruct(TimeCurrent(), current);
    
    return (current.hour >= InpAsianSessionEnd);
}

//+------------------------------------------------------------------+
//| v2.2: Verificar confirmación con Session High/Low                |
//+------------------------------------------------------------------+
bool CheckSessionHLConfirmation(double currentPrice) {
    // BUY: Precio debe estar por encima de Asian Session High
    if(currentPrice > g_rangeHigh && currentPrice > g_asianSessionHigh) {
        return true;
    }
    
    // SELL: Precio debe estar por debajo de Asian Session Low
    if(currentPrice < g_rangeLow && currentPrice < g_asianSessionLow) {
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| v2.2: Filtro VROC - Volume Rate of Change                        |
//+------------------------------------------------------------------+
bool CheckVROCFilter() {
    long volumeBuffer[];
    ArraySetAsSeries(volumeBuffer, true);
    
    // Copiar volúmenes usando CopyTickVolume (no CopyBuffer)
    if(CopyTickVolume(_Symbol, PERIOD_M5, 0, InpVROCPeriod + 1, volumeBuffer) <= 0) {
        return false;
    }
    
    // Calcular VROC = ((Vol[0] - Vol[n]) / Vol[n]) * 100
    long currentVol = volumeBuffer[0];
    long pastVol = volumeBuffer[InpVROCPeriod];
    
    if(pastVol == 0) return false;
    
    double vroc = ((double)(currentVol - pastVol) / (double)pastVol) * 100.0;
    
    if(vroc < InpVROCThreshold) {
        Print("⚠️ E5_ORB v2.2: VROC=", FormatDouble(vroc, 1), "% < ", InpVROCThreshold, "% (débil)");
        return false;
    }
    
    Print("✅ E5_ORB v2.2: VROC=", FormatDouble(vroc, 1), "% - Momentum fuerte!");
    return true;
}

//+------------------------------------------------------------------+
//| v2.3: News Filter - MT5 Calendar dinámico                        |
//+------------------------------------------------------------------+
bool IsNearNewsEvent() {
    if(g_newsCountryCount == 0) return false;  // No hay países configurados
    
    datetime currentTime = TimeCurrent();
    datetime searchFrom = currentTime - (InpNewsAvoidMinutes * 60);
    datetime searchTo = currentTime + (InpNewsAvoidMinutes * 60);
    
    // Buscar eventos próximos en el calendario
    MqlCalendarValue values[];
    
    if(CalendarValueHistory(values, searchFrom, searchTo) > 0) {
        for(int i = 0; i < ArraySize(values); i++) {
            MqlCalendarEvent event;
            
            if(CalendarEventById(values[i].event_id, event)) {
                // Verificar importancia mínima
                if(event.importance < InpNewsMinImportance) continue;
                
                // Verificar país
                MqlCalendarCountry country;
                if(CalendarCountryById(event.country_id, country)) {
                    for(int c = 0; c < g_newsCountryCount; c++) {
                        if(country.code == g_newsCountryIds[c]) {
                            datetime eventTime = (datetime)values[i].time;
                            int minutesAway = (int)(MathAbs(currentTime - eventTime) / 60);
                            
                            if(minutesAway <= InpNewsAvoidMinutes) {
                                Print("📰 E5_ORB v2.3: Evento próximo detectado: ", event.name, 
                                      " (", country.code, ") en ", minutesAway, " min");
                                return true;
                            }
                        }
                    }
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| v2.3: Parsear country codes separados por coma                   |
//+------------------------------------------------------------------+
void ParseNewsCountryCodes(string codes) {
    ArrayFree(g_newsCountryIds);
    g_newsCountryCount = 0;
    
    string parts[];
    int count = StringSplit(codes, StringGetCharacter(",", 0), parts);
    
    if(count <= 0) return;
    
    ArrayResize(g_newsCountryIds, count);
    
    for(int i = 0; i < count; i++) {
        string code = parts[i];
        StringTrimLeft(code);
        StringTrimRight(code);
        
        if(StringLen(code) == 2) {
            g_newsCountryIds[g_newsCountryCount] = code;
            g_newsCountryCount++;
        }
    }
    
    ArrayResize(g_newsCountryIds, g_newsCountryCount);
}

//+------------------------------------------------------------------+
