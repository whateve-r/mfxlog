//+------------------------------------------------------------------+
//| E2_CarryTrade.mq5 - Multi-Symbol + ADXW + Calendar News          |
//| Squad of Systems - Trading System                                |
//| Copyright 2025, SoS Trading                                       |
//+------------------------------------------------------------------+
#property copyright "SoS Trading System"
#property link      "https://github.com/sos-trading"
#property version   "2.30"
#property description "Adaptive Carry Trade with Multi-Symbol Basket, ADXW Hedging, and MT5 Calendar News Filter"

#include <Trade\Trade.mqh>
#include "..\..\Include\SoS_Commons.mqh"
#include "..\..\Include\SoS_GlobalComms.mqh"
#include "..\..\Include\SoS_RiskManager.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== CARRY TRADE SETTINGS ==="
input string InpHighYieldPair = "AUDUSD";       // Par de alto rendimiento
input string InpLowYieldPair = "JPYUSD";        // Par de bajo rendimiento
input double InpMinSwapDifferential = 0.5;      // Diferencial mínimo de swap

input group "=== v2.2 MULTI-SYMBOL BASKET ==="
input bool   InpUseBasket = true;               // Usar Multi-Symbol Basket
input string InpBasketPairs = "AUDUSD,NZDUSD,GBPUSD";  // Pares basket (separados por coma)
input int    InpMaxBasketSize = 3;              // Máximo pares en basket

input group "=== v2.2 ADXW DYNAMIC HEDGING ==="
input bool   InpUseADXW = true;                 // Usar ADXW para hedging dinámico
input int    InpADXWPeriod = 14;                // ADXW Period
input double InpADXWTrendThreshold = 25.0;      // ADXW > 25 = Tendencia fuerte
input double InpADXWHedgeMultiplier = 1.5;      // Multiplicador hedge si ADXW alto

input group "=== v2.2 NEWS FILTER ==="
input bool   InpUseNewsFilter = true;           // Usar News Filter
input int    InpNewsAvoidHours = 4;             // Evitar abrir 4h antes noticias
input string InpNewsCountryCodes = "";          // v2.3: Códigos países (vacío=auto-detectar de basket)
input ENUM_CALENDAR_EVENT_IMPORTANCE InpNewsMinImportance = CALENDAR_IMPORTANCE_HIGH;  // v2.3: Importancia mínima

input group "=== RISK MANAGEMENT ==="
input double InpRiskPercent = 0.5;              // Riesgo por trade (%)
input double InpHedgeRatio = 1.0;               // Ratio de hedge inicial
input int    InpVolatilityPeriod = 20;          // Periodo para vol relativa

input group "=== LIMITS ==="
input int    InpMaxPositions = 2;               // Máximo posiciones simultáneas
input int    InpMinHoldingDays = 7;             // Mínimo días de holding

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;
RiskManager riskMgr(_Symbol, MAGIC_E2_CARRY);  // v2.4: Constructor con magic para TradeHistory

ulong g_longTicket = 0;
ulong g_shortTicket = 0;
datetime g_positionOpenTime = 0;

// v2.2: Multi-Symbol Basket
string g_basketSymbols[];
ulong g_basketTickets[];
int g_basketSize = 0;

// v2.2: ADXW handles
int g_adxwHandles[];

// v2.3: Calendar news tracking
string g_newsCountryIds[];
int g_newsCountryCount = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
    trade.SetExpertMagicNumber(MAGIC_E2_CARRY);
    trade.SetDeviationInPoints(50);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    // v2.2: Parsear basket de símbolos
    if(InpUseBasket) {
        ParseBasketSymbols();
        
        // Crear handles ADXW para cada símbolo del basket
        if(InpUseADXW) {
            ArrayResize(g_adxwHandles, g_basketSize);
            for(int i = 0; i < g_basketSize; i++) {
                g_adxwHandles[i] = iADX(g_basketSymbols[i], PERIOD_D1, InpADXWPeriod);
                if(g_adxwHandles[i] == INVALID_HANDLE) {
                    Print("❌ E2_Carry v2.3: Error creando ADXW handle para ", g_basketSymbols[i]);
                    return(INIT_FAILED);
                }
            }
        }
    }
    
    // v2.3: Configurar news filter dinámico
    if(InpUseNewsFilter) {
        if(InpNewsCountryCodes == "") {
            // Auto-detectar países desde el basket
            AutoDetectNewsCountries();
        } else {
            // Usar países especificados manualmente
            ParseNewsCountryCodes(InpNewsCountryCodes);
        }
        
        if(g_newsCountryCount > 0) {
            string countryList = "";
            for(int i = 0; i < g_newsCountryCount; i++) {
                if(i > 0) countryList += ",";
                countryList += g_newsCountryIds[i];
            }
            Print("✅ E2_Carry v2.3: News Filter - ", g_newsCountryCount, " países: ", countryList);
        } else {
            Print("⚠️ E2_Carry v2.3: No se pudieron detectar países - News filter desactivado");
        }
    }
    
    Print("==================================================");
    Print("✅ E2_CarryTrade v2.3 (Multi-Symbol + ADXW + Calendar News) Inicializado");
    Print("📊 Long: ", InpHighYieldPair, " | Short: ", InpLowYieldPair);
    if(InpUseBasket) {
        Print("🗂️ Basket: ", g_basketSize, " pares - ", InpBasketPairs);
    }
    if(InpUseADXW) Print("📈 ADXW: Period=", InpADXWPeriod, " Threshold=", InpADXWTrendThreshold);
    if(InpUseNewsFilter) Print("📰 News Avoid: ", InpNewsAvoidHours, " horas");
    Print("💱 Min Swap Diff: ", InpMinSwapDifferential);
    Print("💰 Riesgo: ", InpRiskPercent, "%");
    Print("==================================================");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // v2.2: Liberar handles ADXW
    if(InpUseADXW && InpUseBasket) {
        for(int i = 0; i < g_basketSize; i++) {
            if(g_adxwHandles[i] != INVALID_HANDLE) {
                IndicatorRelease(g_adxwHandles[i]);
            }
        }
    }
    
    // v2.3: Limpiar arrays
    ArrayFree(g_basketSymbols);
    ArrayFree(g_basketTickets);
    ArrayFree(g_adxwHandles);
    ArrayFree(g_newsCountryIds);
    
    Print("🛑 E2_CarryTrade v2.3 Detenido. Razón: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
    // Check 1: ¿Podemos operar?
    if(!GlobalComms::CanTrade(MAGIC_E2_CARRY)) {
        // Cerrar posiciones si VIX > 25
        if(g_longTicket > 0 || g_shortTicket > 0) {
            CloseAllCarryPositions("VIX Filter/Emergency Stop");
        }
        return;
    }
    
    // Check 2: VIX Level - GlobalComms maneja el cierre automático
    // Si VIX > 25, GlobalComms::CanTrade() retorna false y ya se cerraron posiciones arriba
    
    // Check 3: Gestionar posiciones existentes
    if(g_longTicket > 0 || g_shortTicket > 0) {
        ManageCarryPositions();
        return;
    }
    
    // Check 4: v2.3 News Filter - Evitar abrir cerca de noticias
    if(InpUseNewsFilter && IsNearMajorNews()) {
        Print("📰 E2_Carry v2.3: Trading pausado - Cerca de evento de noticias");
        return;
    }
    
    // Check 5: Verificar swap differential favorable
    if(CheckSwapDifferential()) {
        ExecuteCarryTrade();
    }
}

//+------------------------------------------------------------------+
//| Verifica si el diferencial de swap es favorable                  |
//+------------------------------------------------------------------+
bool CheckSwapDifferential() {
    // Usar función nativa de MQL5 para obtener swap
    double swap1Long = SymbolInfoDouble(InpHighYieldPair, SYMBOL_SWAP_LONG);
    double swap2Short = SymbolInfoDouble(InpLowYieldPair, SYMBOL_SWAP_SHORT);
    
    double swapDiff = swap1Long + MathAbs(swap2Short);
    
    if(swapDiff >= InpMinSwapDifferential) {
        Print("✅ E2_Carry: Swap differential favorable: ", FormatDouble(swapDiff, 2));
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Ejecuta Carry Trade (v2.2 con Multi-Symbol Basket)               |
//+------------------------------------------------------------------+
void ExecuteCarryTrade() {
    Print("==================================================");
    Print("🚀 E2_Carry v2.2: Ejecutando Carry Trade...");
    
    // v2.2: Si usamos basket, abrir múltiples pares
    if(InpUseBasket) {
        ExecuteBasketCarryTrade();
    } else {
        // Estrategia original: Single pair
        ExecuteSingleCarryTrade();
    }
}
//+------------------------------------------------------------------+
//| v2.5: Ejecuta Carry Trade Single Pair con SL/TP                  |
//+------------------------------------------------------------------+
void ExecuteSingleCarryTrade() {
    // Calcular lotaje basado en volatilidad relativa
    double hedgeRatio = CalculateHedgeRatio();
    
    double baseLots = riskMgr.CalculateLotSize(InpRiskPercent, 50); // 50 pips base
    if(baseLots == 0) return;
    
    double longLots = baseLots;
    double shortLots = baseLots * hedgeRatio;
    
    // Normalizar lotes
    longLots = riskMgr.NormalizeLots(longLots);
    shortLots = riskMgr.NormalizeLots(shortLots);
    
    // v2.5 FIX: Calcular SL/TP basados en ATR de cada par
    double atrLong = GetPairATR(InpHighYieldPair, PERIOD_H4, 14);
    double atrShort = GetPairATR(InpLowYieldPair, PERIOD_H4, 14);
    
    if(atrLong == 0) atrLong = 0.001;  // Fallback
    if(atrShort == 0) atrShort = 0.001;
    
    double longEntryPrice = SymbolInfoDouble(InpHighYieldPair, SYMBOL_ASK);
    double shortEntryPrice = SymbolInfoDouble(InpLowYieldPair, SYMBOL_BID);
    
    // SL: 2.0 × ATR (dar espacio a carry trade - holding period largo)
    // TP: 4.0 × ATR (R:R = 1:2 favorable)
    double longSL = longEntryPrice - (2.0 * atrLong);
    double longTP = longEntryPrice + (4.0 * atrLong);
    
    double shortSL = shortEntryPrice + (2.0 * atrShort);
    double shortTP = shortEntryPrice - (4.0 * atrShort);
    
    // Ejecutar Long en par de alto rendimiento
    bool longResult = trade.Buy(longLots, InpHighYieldPair, 0, longSL, longTP, 
                                 "E2_Carry_Long_v2.5");
    
    if(longResult) {
        g_longTicket = trade.ResultOrder();
        Print("✅ Long ", InpHighYieldPair, " @ ", longLots, " lots - Ticket: ", g_longTicket);
        Print("   Entry: ", FormatDouble(longEntryPrice, 5), 
              " | SL: ", FormatDouble(longSL, 5), 
              " | TP: ", FormatDouble(longTP, 5),
              " (", FormatDouble(atrLong * 2.0, 5), " pips SL)");
    } else {
        Print("❌ Error abriendo Long: ", GetLastError());
        return;
    }
    
    // Ejecutar Short en par de bajo rendimiento
    bool shortResult = trade.Sell(shortLots, InpLowYieldPair, 0, shortSL, shortTP, 
                                   "E2_Carry_Short_v2.5");
    
    if(shortResult) {
        g_shortTicket = trade.ResultOrder();
        Print("✅ Short ", InpLowYieldPair, " @ ", shortLots, " lots - Ticket: ", g_shortTicket);
        Print("   Entry: ", FormatDouble(shortEntryPrice, 5), 
              " | SL: ", FormatDouble(shortSL, 5), 
              " | TP: ", FormatDouble(shortTP, 5),
              " (", FormatDouble(atrShort * 2.0, 5), " pips SL)");
    } else {
        Print("❌ Error abriendo Short: ", GetLastError());
        // Cerrar long si short falló
        if(g_longTicket > 0) {
            trade.PositionClose(g_longTicket);
            g_longTicket = 0;
        }
        return;
    }
    
    g_positionOpenTime = TimeCurrent();
    
    Print("==================================================");
    Print("✅ CARRY TRADE COMPLETO (v2.5 - SL/TP Protectors)");
    Print("📈 Long: ", InpHighYieldPair, " x", longLots, " | R:R = 1:2");
    Print("📉 Short: ", InpLowYieldPair, " x", shortLots, " | R:R = 1:2");
    Print("⚖️ Hedge Ratio: ", FormatDouble(hedgeRatio, 3));
    Print("🌪️ VIX: ", FormatDouble(GlobalComms::GetVIX(), 2));
    Print("==================================================");
}

//+------------------------------------------------------------------+
//| Calcula hedge ratio basado en volatilidad relativa               |
//+------------------------------------------------------------------+
double CalculateHedgeRatio() {
    // v2.5 FIX: Calcular ATR de cada par específico (no usar _Symbol genérico)
    double atrHigh = GetPairATR(InpHighYieldPair, PERIOD_H4, InpVolatilityPeriod);
    double atrLow = GetPairATR(InpLowYieldPair, PERIOD_H4, InpVolatilityPeriod);
    
    if(atrLow == 0 || atrHigh == 0) {
        Print("⚠️ E2_Carry: No se pudo calcular ATR - Usando ratio fijo 1.0");
        return 1.0;
    }
    
    // Ratio = Vol(High) / Vol(Low)
    double ratio = atrHigh / atrLow;
    
    Print("📊 E2_Carry: Hedge Ratio = ", FormatDouble(ratio, 3), 
          " (ATR ", InpHighYieldPair, ": ", FormatDouble(atrHigh, 5), 
          " / ATR ", InpLowYieldPair, ": ", FormatDouble(atrLow, 5), ")");
    
    return ratio;
}

//+------------------------------------------------------------------+
//| v2.5: Obtiene ATR de cualquier par (no solo _Symbol)             |
//+------------------------------------------------------------------+
double GetPairATR(string symbol, ENUM_TIMEFRAMES timeframe, int period) {
    int atrHandle = iATR(symbol, timeframe, period);
    if(atrHandle == INVALID_HANDLE) {
        Print("⚠️ E2_Carry: Error creando ATR handle para ", symbol);
        return 0.0;
    }
    
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);
    
    if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0) {
        Print("⚠️ E2_Carry: Error copiando ATR para ", symbol);
        IndicatorRelease(atrHandle);
        return 0.0;
    }
    
    double atr = atrBuffer[0];
    IndicatorRelease(atrHandle);
    
    return atr;
}

//+------------------------------------------------------------------+
//| Gestiona posiciones del Carry Trade                              |
//+------------------------------------------------------------------+
void ManageCarryPositions() {
    // Verificar que ambas posiciones aún existen
    bool longExists = PositionSelectByTicket(g_longTicket);
    bool shortExists = PositionSelectByTicket(g_shortTicket);
    
    if(!longExists || !shortExists) {
        Print("⚠️ E2_Carry: Una posición fue cerrada. Cerrando la otra...");
        CloseAllCarryPositions("Posición desbalanceada");
        return;
    }
    
    // Verificar holding period mínimo
    int daysHeld = (int)((TimeCurrent() - g_positionOpenTime) / 86400);
    
    if(daysHeld < InpMinHoldingDays) {
        return; // Mantener posiciones
    }
    
    // Calcular P/L combinado
    double longPL = PositionGetDouble(POSITION_PROFIT);
    
    PositionSelectByTicket(g_shortTicket);
    double shortPL = PositionGetDouble(POSITION_PROFIT);
    
    double totalPL = longPL + shortPL;
    
    // Salida por profit target (2% del equity)
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double targetProfit = equity * 0.02;
    
    if(totalPL >= targetProfit) {
        CloseAllCarryPositions("Profit Target alcanzado ($" + DoubleToString(totalPL, 2) + ")");
        return;
    }
    
    // Salida por pérdida excesiva (-1% del equity)
    double maxLoss = -equity * 0.01;
    
    if(totalPL <= maxLoss) {
        CloseAllCarryPositions("Max Loss alcanzado ($" + DoubleToString(totalPL, 2) + ")");
        return;
    }
}

//+------------------------------------------------------------------+
//| Cierra todas las posiciones del Carry Trade                      |
//+------------------------------------------------------------------+
void CloseAllCarryPositions(string reason) {
    Print("==================================================");
    Print("🔒 E2_Carry: Cerrando posiciones - ", reason);
    
    double totalPL = 0;
    
    if(g_longTicket > 0) {
        if(PositionSelectByTicket(g_longTicket)) {
            totalPL += PositionGetDouble(POSITION_PROFIT);
        }
        
        if(trade.PositionClose(g_longTicket)) {
            Print("✅ Long cerrado - Ticket: ", g_longTicket);
        }
        g_longTicket = 0;
    }
    
    if(g_shortTicket > 0) {
        if(PositionSelectByTicket(g_shortTicket)) {
            totalPL += PositionGetDouble(POSITION_PROFIT);
        }
        
        if(trade.PositionClose(g_shortTicket)) {
            Print("✅ Short cerrado - Ticket: ", g_shortTicket);
        }
        g_shortTicket = 0;
    }
    
    int daysHeld = (int)((TimeCurrent() - g_positionOpenTime) / 86400);
    
    Print("📊 Total P/L: $", FormatDouble(totalPL, 2));
    Print("📅 Días mantenido: ", daysHeld);
    Print("==================================================");
    
    g_positionOpenTime = 0;
}

//+------------------------------------------------------------------+
//| v2.2: Parsear símbolos del basket desde string                   |
//+------------------------------------------------------------------+
void ParseBasketSymbols() {
    string pairsInput = InpBasketPairs;
    
    // Contar cuántos pares hay (contar comas + 1)
    int commaCount = 0;
    for(int i = 0; i < StringLen(pairsInput); i++) {
        if(StringSubstr(pairsInput, i, 1) == ",") commaCount++;
    }
    
    g_basketSize = MathMin(commaCount + 1, InpMaxBasketSize);
    ArrayResize(g_basketSymbols, g_basketSize);
    ArrayResize(g_basketTickets, g_basketSize);
    ArrayInitialize(g_basketTickets, 0);
    
    // Parsear string
    int start = 0;
    for(int i = 0; i < g_basketSize; i++) {
        int commaPos = StringFind(pairsInput, ",", start);
        
        if(commaPos >= 0) {
            g_basketSymbols[i] = StringSubstr(pairsInput, start, commaPos - start);
            start = commaPos + 1;
        } else {
            g_basketSymbols[i] = StringSubstr(pairsInput, start);
        }
        
        // Limpiar espacios
        StringTrimLeft(g_basketSymbols[i]);
        StringTrimRight(g_basketSymbols[i]);
    }
    
    Print("🗂️ E2_Carry v2.2: Basket parseado - ", g_basketSize, " pares");
}

//+------------------------------------------------------------------+
//| v2.2: Ejecuta Carry Trade con Multi-Symbol Basket                |
//+------------------------------------------------------------------+
void ExecuteBasketCarryTrade() {
    double baseLots = riskMgr.CalculateLotSize(InpRiskPercent, 50);
    if(baseLots == 0) return;
    
    // Dividir lote entre símbolos del basket
    double lotsPerPair = baseLots / g_basketSize;
    
    int successCount = 0;
    
    for(int i = 0; i < g_basketSize; i++) {
        string symbol = g_basketSymbols[i];
        
        // v2.2: Calcular hedge ratio con ADXW
        double hedgeMultiplier = 1.0;
        if(InpUseADXW) {
            hedgeMultiplier = CalculateADXWHedgeMultiplier(i);
        }
        
        double adjustedLots = riskMgr.NormalizeLots(lotsPerPair * hedgeMultiplier);
        
        // Abrir Long en cada par del basket
        bool result = trade.Buy(adjustedLots, symbol, 0, 0, 0, 
                               "E2_Carry_v2.2_Basket_" + IntegerToString(i + 1));
        
        if(result) {
            g_basketTickets[i] = trade.ResultOrder();
            successCount++;
            Print("✅ Basket[", i + 1, "]: Long ", symbol, " @ ", adjustedLots, 
                  " lots (ADXW Mult: ", FormatDouble(hedgeMultiplier, 2), ")");
        } else {
            Print("❌ Error abriendo ", symbol, ": ", GetLastError());
        }
    }
    
    if(successCount > 0) {
        g_positionOpenTime = TimeCurrent();
        
        Print("==================================================");
        Print("✅ CARRY BASKET COMPLETO");
        Print("📊 Pares abiertos: ", successCount, "/", g_basketSize);
        Print("💵 Lote base: ", baseLots, " / Par: ", FormatDouble(baseLots / g_basketSize, 3));
        Print("🌪️ VIX: ", FormatDouble(GlobalComms::GetVIX(), 2));
        Print("==================================================");
    }
}

//+------------------------------------------------------------------+
//| v2.2: Calcular multiplicador hedge basado en ADXW                |
//+------------------------------------------------------------------+
double CalculateADXWHedgeMultiplier(int symbolIndex) {
    double adxwBuffer[];
    ArraySetAsSeries(adxwBuffer, true);
    
    // v2.4: Leer ADXW del símbolo con retry logic
    if(SafeCopyBuffer(g_adxwHandles[symbolIndex], 0, 0, 1, adxwBuffer) <= 0) {
        Print("⚠️ E2_Carry: Error obteniendo ADXW - Usando hedge default");
        return 1.0;  // Default si falla
    }
    
    double adxw = adxwBuffer[0];
    
    // Si ADXW > threshold, hay tendencia fuerte → aumentar hedge
    if(adxw > InpADXWTrendThreshold) {
        double multiplier = InpADXWHedgeMultiplier;
        Print("📈 ", g_basketSymbols[symbolIndex], " ADXW=", FormatDouble(adxw, 1), 
              " > ", InpADXWTrendThreshold, " → Hedge x", FormatDouble(multiplier, 2));
        return multiplier;
    }
    
    return 1.0;  // Sin ajuste
}

//+------------------------------------------------------------------+
//| v2.3: News Filter - MT5 Calendar dinámico                        |
//+------------------------------------------------------------------+
bool IsNearMajorNews() {
    if(g_newsCountryCount == 0) return false;
    
    datetime currentTime = TimeCurrent();
    datetime searchFrom = currentTime - (InpNewsAvoidHours * 3600);
    datetime searchTo = currentTime + (InpNewsAvoidHours * 3600);
    
    MqlCalendarValue values[];
    
    if(CalendarValueHistory(values, searchFrom, searchTo) > 0) {
        for(int i = 0; i < ArraySize(values); i++) {
            MqlCalendarEvent event;
            
            if(CalendarEventById(values[i].event_id, event)) {
                if(event.importance < InpNewsMinImportance) continue;
                
                MqlCalendarCountry country;
                if(CalendarCountryById(event.country_id, country)) {
                    for(int c = 0; c < g_newsCountryCount; c++) {
                        if(country.code == g_newsCountryIds[c]) {
                            datetime eventTime = (datetime)values[i].time;
                            int hoursAway = (int)(MathAbs(currentTime - eventTime) / 3600);
                            
                            if(hoursAway <= InpNewsAvoidHours) {
                                Print("📰 E2_Carry v2.3: Evento próximo detectado: ", event.name, 
                                      " (", country.code, ") en ", hoursAway, " horas");
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
//| v2.3: Auto-detectar países desde basket symbols                  |
//+------------------------------------------------------------------+
void AutoDetectNewsCountries() {
    ArrayFree(g_newsCountryIds);
    g_newsCountryCount = 0;
    
    string detectedCountries[];
    int detectedCount = 0;
    ArrayResize(detectedCountries, 10);  // Max 10 países
    
    // Extraer países de todos los símbolos del basket
    for(int i = 0; i < g_basketSize; i++) {
        string symbol = g_basketSymbols[i];
        if(StringLen(symbol) < 6) continue;
        
        string base = StringSubstr(symbol, 0, 3);
        string quote = StringSubstr(symbol, 3, 3);
        
        // Convertir base currency a country code
        string baseCountry = CurrencyToCountry(base);
        if(baseCountry != "" && !IsInArray(detectedCountries, detectedCount, baseCountry)) {
            detectedCountries[detectedCount] = baseCountry;
            detectedCount++;
        }
        
        // Convertir quote currency a country code
        string quoteCountry = CurrencyToCountry(quote);
        if(quoteCountry != "" && !IsInArray(detectedCountries, detectedCount, quoteCountry)) {
            detectedCountries[detectedCount] = quoteCountry;
            detectedCount++;
        }
    }
    
    // Copiar a array global
    ArrayResize(g_newsCountryIds, detectedCount);
    for(int i = 0; i < detectedCount; i++) {
        g_newsCountryIds[i] = detectedCountries[i];
    }
    g_newsCountryCount = detectedCount;
}

//+------------------------------------------------------------------+
//| v2.4: Convertir currency code a country code (expandido)         |
//+------------------------------------------------------------------+
string CurrencyToCountry(string currency) {
    // Monedas mayores (G10)
    if(currency == "USD") return "US";
    if(currency == "EUR") return "EU";
    if(currency == "GBP") return "GB";
    if(currency == "JPY") return "JP";
    if(currency == "CHF") return "CH";
    if(currency == "CAD") return "CA";
    if(currency == "AUD") return "AU";
    if(currency == "NZD") return "NZ";
    
    // Escandinavia
    if(currency == "SEK") return "SE";  // Corona sueca
    if(currency == "NOK") return "NO";  // Corona noruega
    if(currency == "DKK") return "DK";  // Corona danesa
    
    // Asia-Pacífico
    if(currency == "CNY" || currency == "CNH") return "CN";  // Yuan chino
    if(currency == "HKD") return "HK";  // Dólar de Hong Kong
    if(currency == "SGD") return "SG";  // Dólar de Singapur
    if(currency == "KRW") return "KR";  // Won surcoreano
    if(currency == "TWD") return "TW";  // Dólar taiwanés
    if(currency == "THB") return "TH";  // Baht tailandés
    if(currency == "INR") return "IN";  // Rupia india
    
    // Latinoamérica
    if(currency == "MXN") return "MX";  // Peso mexicano
    if(currency == "BRL") return "BR";  // Real brasileño
    if(currency == "ARS") return "AR";  // Peso argentino
    if(currency == "CLP") return "CL";  // Peso chileno
    if(currency == "COP") return "CO";  // Peso colombiano
    
    // EMEA (Europa, Medio Oriente, África)
    if(currency == "TRY") return "TR";  // Lira turca
    if(currency == "ZAR") return "ZA";  // Rand sudafricano
    if(currency == "RUB") return "RU";  // Rublo ruso
    if(currency == "PLN") return "PL";  // Zloty polaco
    if(currency == "CZK") return "CZ";  // Corona checa
    if(currency == "HUF") return "HU";  // Florín húngaro
    if(currency == "ILS") return "IL";  // Shekel israelí
    if(currency == "SAR") return "SA";  // Riyal saudí
    if(currency == "AED") return "AE";  // Dirham de EAU
    
    return "";  // Moneda no soportada
}

//+------------------------------------------------------------------+
//| Helper: Verificar si string está en array                        |
//+------------------------------------------------------------------+
bool IsInArray(const string &arr[], int size, string value) {
    for(int i = 0; i < size; i++) {
        if(arr[i] == value) return true;
    }
    return false;
}

//+------------------------------------------------------------------+
