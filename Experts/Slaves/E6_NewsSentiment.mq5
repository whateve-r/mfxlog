//+------------------------------------------------------------------+
//| E6_NewsSentiment.mq5 - MT5 Calendar + Surprise Index + Correlation|
//| Squad of Systems - Trading System                                |
//| Copyright 2025, SoS Trading                                       |
//+------------------------------------------------------------------+
#property copyright "SoS Trading System"
#property link      "https://github.com/sos-trading"
#property version   "2.30"
#property description "News Trading with MT5 Economic Calendar, Surprise Index, Correlation, and Time Decay"

#include <Trade\Trade.mqh>
#include "..\..\Include\SoS_Commons.mqh"
#include "..\..\Include\SoS_GlobalComms.mqh"
#include "..\..\Include\SoS_RiskManager.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== v2.3 CALENDAR NEWS FILTER ==="
input bool   InpUseCalendar = true;             // Usar MT5 Economic Calendar
input string InpCountryCodes = "US,EU,GB";      // Códigos países (US,EU,GB,AU,etc)
input ENUM_CALENDAR_EVENT_IMPORTANCE InpMinImportance = CALENDAR_IMPORTANCE_MEDIUM;  // v2.5: Bajado de HIGH a MEDIUM
input double InpSurpriseThreshold = 5.0;        // Surprise Index mínimo (%)
input int    InpNewsCheckIntervalMin = 15;      // Check cada X minutos
input int    InpWaitAfterNewsMin = 5;           // Esperar X min después de noticia
input int    InpMaxEventAgeDays = 2;            // Edad máxima eventos (días)

input group "=== v2.2 WEIGHTED SENTIMENT ==="
input bool   InpUseWeighted = true;             // Usar Weighted Sentiment
input double InpRelevanceWeight = 0.6;          // Peso relevancia (0-1)
input double InpTimeDecayWeight = 0.4;          // Peso time decay (0-1)

input group "=== v2.2 CORRELATION CHECKS ==="
input bool   InpUseCorrelation = true;          // Usar Correlation Checks
input string InpDXYSymbol = "USDX";             // Símbolo DXY (para EUR/GBP/etc)
input string InpGOLDSymbol = "XAUUSD";          // Símbolo GOLD (para AUD/etc)
input int    InpCorrelationPeriod = 50;         // Periodo correlación

input group "=== v2.2 TIME DECAY TRAILING ==="
input bool   InpUseTimeDecay = true;            // Usar Time Decay Trailing
input int    InpMaxPositionHours = 8;           // Auto-close después de 8h
input int    InpDecayCheckMinutes = 30;         // Check decay cada 30 min

input group "=== RISK MANAGEMENT ==="
input double InpRiskPercent = 0.5;              // Riesgo por trade (%)
input int    InpSLPips = 20;                    // Stop Loss (pips)
input int    InpTPPips = 30;                    // Take Profit (pips)

input group "=== LIMITS ==="
input int    InpMaxTradesPerDay = 2;            // Máximo trades diarios

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;
RiskManager riskMgr(_Symbol, MAGIC_E6_NEWS);  // v2.4: Constructor con magic para TradeHistory

datetime g_lastNewsCheck = 0;
datetime g_lastEventTime = 0;
double g_lastSurpriseIndex = 0;
string g_lastEventName = "";
int g_tradesToday = 0;
datetime g_lastResetDate = 0;

// v2.2: Tracking de posiciones con time decay
ulong g_currentTicket = 0;
datetime g_positionOpenTime = 0;
datetime g_lastDecayCheck = 0;

// v2.2: Correlation handles
int g_dxyHandle = INVALID_HANDLE;
int g_goldHandle = INVALID_HANDLE;

// v2.3: Calendar country IDs
string g_countryIds[];
int g_countryCount = 0;

// v2.4: Calendar cache - Evitar llamadas cada tick
struct CalendarCache {
    MqlCalendarValue values[];
    datetime lastUpdate;
    int cacheExpiry;  // 900 segundos = 15 minutos
} g_calendarCache;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
    trade.SetExpertMagicNumber(MAGIC_E6_NEWS);
    trade.SetDeviationInPoints(50);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    // v2.4: Inicializar caché
    g_calendarCache.lastUpdate = 0;
    g_calendarCache.cacheExpiry = 900;  // 15 minutos
    ArrayResize(g_calendarCache.values, 0);
    
    // v2.3: Parsear y validar country codes
    if(InpUseCalendar) {
        ParseCountryCodes(InpCountryCodes);
        
        if(g_countryCount == 0) {
            Print("❌ E6_News v2.3: No se pudieron parsear country codes");
            return(INIT_PARAMETERS_INCORRECT);
        }
        
        Print("✅ E6_News v2.3: ", g_countryCount, " países configurados: ", InpCountryCodes);
    }
    
    // v2.2: Crear handles de correlación
    if(InpUseCorrelation) {
        // DXY para EUR, GBP (correlación inversa)
        g_dxyHandle = iClose(InpDXYSymbol, PERIOD_H1, 0);
        
        // GOLD para AUD (correlación positiva)
        g_goldHandle = iClose(InpGOLDSymbol, PERIOD_H1, 0);
        
        // Nota: Si los símbolos no existen, handles serán INVALID pero no bloqueamos init
        if(g_dxyHandle == INVALID_HANDLE) {
            Print("⚠️ E6_News v2.2: DXY handle inválido - Correlación DXY desactivada");
        }
        if(g_goldHandle == INVALID_HANDLE) {
            Print("⚠️ E6_News v2.2: GOLD handle inválido - Correlación GOLD desactivada");
        }
    }
    
    Print("==================================================");
    Print("✅ E6_NewsSentiment v2.3 (MT5 Calendar + Surprise Index) Inicializado");
    Print("� Calendar: ", InpUseCalendar ? "ENABLED" : "DISABLED");
    if(InpUseCalendar) Print("🌍 Countries: ", InpCountryCodes, " | Min Importance: ", EnumToString(InpMinImportance));
    Print("📊 Surprise Index Threshold: ±", InpSurpriseThreshold, "%");
    if(InpUseWeighted) Print("⚖️ Weighted: Relevance=", InpRelevanceWeight, " TimeDecay=", InpTimeDecayWeight);
    if(InpUseCorrelation) Print("📈 Correlation: DXY + GOLD | Period=", InpCorrelationPeriod);
    if(InpUseTimeDecay) Print("⏰ Time Decay: Auto-close @ ", InpMaxPositionHours, "h");
    Print("⏰ Check Interval: ", InpNewsCheckIntervalMin, " min");
    Print("💰 Riesgo: ", InpRiskPercent, "% | SL: ", InpSLPips, " | TP: ", InpTPPips);
    Print("==================================================");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // v2.2: Liberar handles de correlación
    if(g_dxyHandle != INVALID_HANDLE) IndicatorRelease(g_dxyHandle);
    if(g_goldHandle != INVALID_HANDLE) IndicatorRelease(g_goldHandle);
    
    // v2.3: Limpiar arrays
    ArrayFree(g_countryIds);
    
    Print("🛑 E6_NewsSentiment v2.3 Detenido. Razón: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
    // Check 1: ¿Podemos operar?
    if(!GlobalComms::CanTrade(MAGIC_E6_NEWS)) {
        return;
    }
    
    // Check 2: Reset diario
    ResetDailyCounter();
    
    // Check 3: Límite de trades
    if(g_tradesToday >= InpMaxTradesPerDay) {
        return;
    }
    
    // v2.2: Check 3.5: Time Decay - Cerrar posición si lleva >8h abierta
    if(InpUseTimeDecay && g_currentTicket > 0) {
        CheckTimeDecay();
    }
    
    // Check 4: ¿Es momento de revisar noticias?
    if(!ShouldCheckNews()) {
        return;
    }
    
    // Check 5: Obtener y analizar eventos económicos
    CheckCalendarAndTrade();
}

//+------------------------------------------------------------------+
//| Verifica si es momento de revisar noticias                       |
//+------------------------------------------------------------------+
bool ShouldCheckNews() {
    if(g_lastNewsCheck == 0) return true;
    
    int minutesElapsed = (int)((TimeCurrent() - g_lastNewsCheck) / 60);
    
    return (minutesElapsed >= InpNewsCheckIntervalMin);
}

//+------------------------------------------------------------------+
//| v2.3: Revisa calendario económico y ejecuta trade si hay señal   |
//+------------------------------------------------------------------+
void CheckCalendarAndTrade() {
    Print("� E6_News v2.3: Revisando Calendar Events...");
    
    g_lastNewsCheck = TimeCurrent();
    
    if(!InpUseCalendar || g_countryCount == 0) {
        Print("⚠️ E6_News: Calendar desactivado o sin países configurados");
        return;
    }
    // v2.4: Verificar caché primero (evita 100+ llamadas/segundo a Calendar)
    datetime now = TimeCurrent();
    bool cacheExpired = (now - g_calendarCache.lastUpdate) > g_calendarCache.cacheExpiry;
    
    MqlCalendarValue values[];
    
    if(cacheExpired) {
        // Buscar eventos en las últimas InpMaxEventAgeDays días
        datetime dateFrom = now - (InpMaxEventAgeDays * 86400);
        datetime dateTo = now;
        
        // Actualizar caché
        if(CalendarValueHistory(values, dateFrom, dateTo) > 0) {
            ArrayResize(g_calendarCache.values, ArraySize(values));
            ArrayCopy(g_calendarCache.values, values);
            g_calendarCache.lastUpdate = now;
            
            Print("📊 E6_News v2.4: Caché actualizado - ", ArraySize(values), " eventos (TTL=15min)");
        } else {
            Print("⚠️ E6_News v2.4: No se pudieron obtener eventos de Calendar");
            return;
        }
    } else {
        // Usar caché existente
        ArrayResize(values, ArraySize(g_calendarCache.values));
        ArrayCopy(values, g_calendarCache.values);
    }
    
    if(ArraySize(values) > 0) {
        // v2.5: DEBUG - Contar eventos por importancia
        static datetime lastDebugLog = 0;
        if(TimeCurrent() - lastDebugLog > 3600) {  // Log cada 1h
            int countHigh = 0, countMed = 0, countLow = 0, countQualified = 0;
            for(int i = 0; i < ArraySize(values); i++) {
                MqlCalendarEvent evt;
                if(!CalendarEventById(values[i].event_id, evt)) continue;
                if(evt.importance == CALENDAR_IMPORTANCE_HIGH) countHigh++;
                else if(evt.importance == CALENDAR_IMPORTANCE_MEDIUM) countMed++;
                else countLow++;
                
                if(evt.importance >= InpMinImportance) countQualified++;
            }
            Print("📊 E6_DEBUG: Total=", ArraySize(values), " | HIGH=", countHigh, 
                  " MED=", countMed, " LOW=", countLow, " | Qualified>=", 
                  EnumToString(InpMinImportance), "=", countQualified);
            lastDebugLog = TimeCurrent();
        }
        
        Print("📊 E6_News v2.5: Procesando ", ArraySize(values), " eventos (caché ", cacheExpired ? "actualizado" : "válido", ")");
        
        // Iterar sobre cada valor de evento
        for(int i = 0; i < ArraySize(values); i++) {
            MqlCalendarEvent event;
            if(!CalendarEventById(values[i].event_id, event)) continue;
            
            // Verificar importancia PRIMERO (filtro más rápido)
            if(event.importance < InpMinImportance) continue;
            
            // Verificar país
            MqlCalendarCountry country;
            if(!CalendarCountryById(event.country_id, country)) continue;
            
            // Comprobar si el país está en nuestra lista configurada
            bool countryMatch = false;
            for(int c = 0; c < g_countryCount; c++) {
                if(country.code == g_countryIds[c]) {
                    countryMatch = true;
                    break;
                }
            }
            if(!countryMatch) continue;
            if(!countryMatch) continue;
            
            // Calcular Surprise Index
            double surpriseIndex = CalculateSurpriseIndex(values[i], event);
            
            if(MathAbs(surpriseIndex) >= InpSurpriseThreshold) {
                Print("🎯 EVENT FOUND: ", event.name, " | Country: ", country.code, 
                      " | Surprise: ", FormatDouble(surpriseIndex, 2), "%");
                
                g_lastEventName = event.name;
                g_lastEventTime = (datetime)values[i].time;
                g_lastSurpriseIndex = surpriseIndex;
                
                // Esperar X minutos después del evento
                int minutesSinceEvent = (int)((TimeCurrent() - g_lastEventTime) / 60);
                if(minutesSinceEvent < InpWaitAfterNewsMin) {
                    Print("⏰ Esperando ", InpWaitAfterNewsMin - minutesSinceEvent, " min más...");
                    continue;
                }
                
                // Aplicar weighted scoring si está activo
                double finalScore = surpriseIndex;
                
                if(InpUseWeighted) {
                    double relevance = (double)event.importance / 3.0;  // High=1.0, Medium=0.66, Low=0.33
                    double eventAge = (double)minutesSinceEvent / (InpMaxEventAgeDays * 1440.0);
                    double timeDecay = 1.0 - MathMin(eventAge, 1.0);
                    
                    finalScore = (surpriseIndex * InpRelevanceWeight * relevance) + 
                                (surpriseIndex * InpTimeDecayWeight * timeDecay);
                    
                    Print("⚖️ Weighted Surprise: ", FormatDouble(surpriseIndex, 2), "% → ", 
                          FormatDouble(finalScore, 2), "% (Rel=", FormatDouble(relevance, 2), 
                          " Decay=", FormatDouble(timeDecay, 2), ")");
                }
                
                // Evaluar señal
                if(finalScore > 0) {
                    Print("📈 E6_News v2.3: Surprise POSITIVO → Preparando BUY");
                    ExecuteTrade(ORDER_TYPE_BUY, finalScore);
                } else {
                    Print("📉 E6_News v2.3: Surprise NEGATIVO → Preparando SELL");
                    ExecuteTrade(ORDER_TYPE_SELL, finalScore);
                }
                
                return;  // Solo operar con el primer evento que califique
            }
        }
    } else {
        Print("⚠️ E6_News v2.3: No se pudieron recuperar eventos del calendario");
    }
    
    Print("➡️ E6_News v2.3: No hay eventos con Surprise Index >= ", InpSurpriseThreshold, "%");
}

//+------------------------------------------------------------------+
//| v2.3: Calcular Surprise Index de un evento                       |
//+------------------------------------------------------------------+
double CalculateSurpriseIndex(const MqlCalendarValue &value, const MqlCalendarEvent &event) {
    // Surprise Index = ((Actual - Forecast) / Forecast) * 100
    
    if(value.forecast_value == 0 || value.forecast_value == LONG_MAX) {
        return 0;  // No hay forecast disponible
    }
    
    if(value.actual_value == LONG_MAX) {
        return 0;  // No hay actual disponible aún
    }
    
    double forecast = (double)value.forecast_value;
    double actual = (double)value.actual_value;
    
    // Aplicar multiplicador del evento (ej: si es en miles, millions, etc)
    if(event.digits > 0) {
        double multiplier = MathPow(10, -event.digits);
        forecast *= multiplier;
        actual *= multiplier;
    }
    
    double surprise = ((actual - forecast) / forecast) * 100.0;
    
    return surprise;
}

//+------------------------------------------------------------------+
//| Timer event (ejecuta trade después de esperar)                   |
//+------------------------------------------------------------------+
void OnTimer() {
    // Timer ya cumplió su función, desactivar
    EventKillTimer();
}

//+------------------------------------------------------------------+
//| Ejecuta trade basado en sentiment (v2.2 con correlation checks)  |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType, double sentimentScore) {
    // v2.2: Correlation Check - Confirmar dirección con DXY/GOLD
    if(InpUseCorrelation && !CheckCorrelationConfirmation(orderType)) {
        Print("⚠️ E6_News v2.2: Correlación NO confirma señal - Trade cancelado");
        return;
    }
    
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double entryPrice = SymbolInfoDouble(_Symbol, 
                        orderType == ORDER_TYPE_BUY ? SYMBOL_ASK : SYMBOL_BID);
    
    // Calcular SL y TP
    double slPrice, tpPrice;
    
    if(orderType == ORDER_TYPE_BUY) {
        slPrice = entryPrice - (InpSLPips * point * 10);
        tpPrice = entryPrice + (InpTPPips * point * 10);
    } else {
        slPrice = entryPrice + (InpSLPips * point * 10);
        tpPrice = entryPrice - (InpTPPips * point * 10);
    }
    
    // Calcular lotaje
    double lots = riskMgr.CalculateLotSize(InpRiskPercent, InpSLPips);
    
    if(lots == 0) {
        Print("❌ E6_News: Error calculando lotaje");
        return;
    }
    
    // Ejecutar orden
    bool result = false;
    string comment = "E6_News_" + EnumToString(orderType) + "_S" + DoubleToString(sentimentScore, 2);
    
    if(orderType == ORDER_TYPE_BUY) {
        result = trade.Buy(lots, _Symbol, 0, slPrice, tpPrice, comment);
    } else {
        result = trade.Sell(lots, _Symbol, 0, slPrice, tpPrice, comment);
    }
    
    if(result) {
        g_tradesToday++;
        g_currentTicket = trade.ResultOrder();          // v2.2
        g_positionOpenTime = TimeCurrent();             // v2.2
        g_lastDecayCheck = TimeCurrent();               // v2.2
        
        double rr = (double)InpTPPips / InpSLPips;
        
        Print("==================================================");
        Print("✅ E6_News: TRADE #", g_tradesToday, " EJECUTADO");
        Print("🎫 Ticket: ", trade.ResultOrder());
        Print("📍 Tipo: ", EnumToString(orderType));
        Print("💵 Lots: ", lots);
        Print("📰 Sentiment: ", FormatDouble(sentimentScore, 3));
        Print("📉 SL: ", slPrice, " (", InpSLPips, " pips)");
        Print("📈 TP: ", tpPrice, " (", InpTPPips, " pips)");
        Print("🎯 R:R: 1:", FormatDouble(rr, 2));
        Print("==================================================");
    } else {
        Print("❌ E6_News: Error ejecutando trade. Code: ", GetLastError());
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
            Print("🌅 E6_News: Nuevo día - Contador reseteado");
        }
    } else {
        g_lastResetDate = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| v2.2: Check Time Decay - Cerrar posición después de X horas      |
//+------------------------------------------------------------------+
void CheckTimeDecay() {
    if(!PositionSelectByTicket(g_currentTicket)) {
        g_currentTicket = 0;
        g_positionOpenTime = 0;
        return;
    }
    
    // Check cada InpDecayCheckMinutes
    int minutesSinceCheck = (int)((TimeCurrent() - g_lastDecayCheck) / 60);
    if(minutesSinceCheck < InpDecayCheckMinutes) {
        return;
    }
    
    g_lastDecayCheck = TimeCurrent();
    
    // Calcular horas desde apertura
    int hoursOpen = (int)((TimeCurrent() - g_positionOpenTime) / 3600);
    
    if(hoursOpen >= InpMaxPositionHours) {
        double pl = PositionGetDouble(POSITION_PROFIT);
        
        if(trade.PositionClose(g_currentTicket)) {
            Print("==================================================");
            Print("⏰ E6_News v2.2: TIME DECAY - Posición cerrada");
            Print("   Horas abiertas: ", hoursOpen, " >= ", InpMaxPositionHours);
            Print("   P/L: $", FormatDouble(pl, 2));
            Print("==================================================");
            
            g_currentTicket = 0;
            g_positionOpenTime = 0;
        }
    }
}

//+------------------------------------------------------------------+
//| v2.2: Verificar confirmación de correlación                      |
//+------------------------------------------------------------------+
bool CheckCorrelationConfirmation(ENUM_ORDER_TYPE orderType) {
    // Determinar qué correlación usar según el par
    string baseCurrency = StringSubstr(_Symbol, 0, 3);
    
    bool useDXY = false;
    bool useGOLD = false;
    
    // EUR, GBP → correlación INVERSA con DXY
    if(baseCurrency == "EUR" || baseCurrency == "GBP") {
        useDXY = true;
    }
    
    // AUD, NZD → correlación POSITIVA con GOLD
    if(baseCurrency == "AUD" || baseCurrency == "NZD") {
        useGOLD = true;
    }
    
    // DXY Correlation Check
    if(useDXY && g_dxyHandle != INVALID_HANDLE) {
        double dxyBuffer[];
        ArraySetAsSeries(dxyBuffer, true);
        
        if(CopyClose(InpDXYSymbol, PERIOD_H1, 0, InpCorrelationPeriod, dxyBuffer) > 0) {
            // Calcular tendencia DXY (Simple: último > promedio = alcista)
            double dxyAvg = 0;
            for(int i = 0; i < InpCorrelationPeriod; i++) {
                dxyAvg += dxyBuffer[i];
            }
            dxyAvg /= InpCorrelationPeriod;
            
            bool dxyBullish = dxyBuffer[0] > dxyAvg;
            
            // Correlación INVERSA: DXY up → EUR down
            if(orderType == ORDER_TYPE_BUY && dxyBullish) {
                Print("⚠️ E6_News v2.2: DXY alcista → EUR bajista (inverso) - Señal BUY no confirmada");
                return false;
            }
            if(orderType == ORDER_TYPE_SELL && !dxyBullish) {
                Print("⚠️ E6_News v2.2: DXY bajista → EUR alcista (inverso) - Señal SELL no confirmada");
                return false;
            }
            
            Print("✅ E6_News v2.2: Correlación DXY confirmada");
        }
    }
    
    // GOLD Correlation Check
    if(useGOLD && g_goldHandle != INVALID_HANDLE) {
        double goldBuffer[];
        ArraySetAsSeries(goldBuffer, true);
        
        if(CopyClose(InpGOLDSymbol, PERIOD_H1, 0, InpCorrelationPeriod, goldBuffer) > 0) {
            double goldAvg = 0;
            for(int i = 0; i < InpCorrelationPeriod; i++) {
                goldAvg += goldBuffer[i];
            }
            goldAvg /= InpCorrelationPeriod;
            
            bool goldBullish = goldBuffer[0] > goldAvg;
            
            // Correlación POSITIVA: GOLD up → AUD up
            if(orderType == ORDER_TYPE_BUY && !goldBullish) {
                Print("⚠️ E6_News v2.2: GOLD bajista → AUD bajista (positivo) - Señal BUY no confirmada");
                return false;
            }
            if(orderType == ORDER_TYPE_SELL && goldBullish) {
                Print("⚠️ E6_News v2.2: GOLD alcista → AUD alcista (positivo) - Señal SELL no confirmada");
                return false;
            }
            
            Print("✅ E6_News v2.2: Correlación GOLD confirmada");
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| v2.3: Parsear country codes separados por coma                   |
//+------------------------------------------------------------------+
void ParseCountryCodes(string codes) {
    ArrayFree(g_countryIds);
    g_countryCount = 0;
    
    string parts[];
    int count = StringSplit(codes, StringGetCharacter(",", 0), parts);
    
    if(count <= 0) return;
    
    ArrayResize(g_countryIds, count);
    
    for(int i = 0; i < count; i++) {
        string code = parts[i];
        StringTrimLeft(code);
        StringTrimRight(code);
        
        if(StringLen(code) == 2) {
            g_countryIds[g_countryCount] = code;
            g_countryCount++;
        }
    }
    
    ArrayResize(g_countryIds, g_countryCount);
}

//+------------------------------------------------------------------+
