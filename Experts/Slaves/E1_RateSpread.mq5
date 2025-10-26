//+------------------------------------------------------------------+
//| E1_RateSpread.mq5 - Mean Reversion + Grid Trading + Trailing     |
//| Squad of Systems - Trading System                                |
//| Copyright 2025, SoS Trading                                       |
//+------------------------------------------------------------------+
#property copyright "SoS Trading System"
#property link      "https://github.com/sos-trading"
#property version   "2.20"
#property description "Mean Reversion on Interest Rate Spreads with Grid Trading and Trailing Stop"

#include <Trade\Trade.mqh>
#include "..\..\Include\SoS_Commons.mqh"
#include "..\..\Include\SoS_GlobalComms.mqh"
#include "..\..\Include\SoS_RiskManager.mqh"
#include "..\..\Include\SoS_APIHandler.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== API SETTINGS ==="
input string InpFREDKey = "8b908fe651eccf866411068423dd5068";  // FRED API Key

input group "=== SIGNAL SETTINGS ==="
input string InpSeries1 = "DGS2";               // Serie 1 (2-Year Treasury)
input string InpSeries2 = "DGS10";              // Serie 2 (10-Year Treasury)
input int    InpZScorePeriod = 20;              // Periodo para Z-Score
input double InpZScoreEntry = 2.0;              // Z-Score para entrada
input double InpZScoreExit = 0.5;               // Z-Score para salida
input int    InpUpdateIntervalHours = 2;        // Actualización de datos (horas)

input group "=== v2.2 GRID TRADING ==="
input bool   InpUseGrid = true;                 // Usar Grid Trading
input int    InpMaxGridLevels = 3;              // Máximo niveles grid
input double InpGridStepZScore = 0.5;           // Step entre niveles (Z-Score)
input double InpGridLotMultiplier = 1.5;        // Multiplicador de lote por nivel

input group "=== v2.2 TRAILING STOP ==="
input bool   InpUseTrailing = true;             // Usar Trailing Stop
input double InpTrailingActivateZScore = 0.3;   // Activar trailing cuando Z-Score < 0.3
input double InpTrailingStepZScore = 0.1;       // Step del trailing (Z-Score)

input group "=== v2.2 EQUITY DD PROTECTION ==="
input bool   InpUseEquityDD = true;             // Usar Equity DD Limit
input double InpEquityDDPercent = 3.0;          // Close all si Equity DD > 3%

input group "=== RISK MANAGEMENT ==="
input double InpRiskPercent = 0.5;              // Riesgo por trade (%)
input double InpMaxDDPercent = 2.0;             // Max DD por trade (%)

input group "=== LIMITS ==="
input int    InpMaxTradesPerWeek = 10;          // Máximo trades semanales

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;
RiskManager riskMgr(_Symbol, MAGIC_E1_RATE);  // v2.4: Constructor con magic para TradeHistory
APIHandler api;

double g_spreadHistory[];
double g_lastSpread = 0;
datetime g_lastUpdate = 0;
int g_tradesThisWeek = 0;
datetime g_weekStart = 0;
ulong g_currentTicket = 0;

// v2.2: Grid Trading tracking
ulong g_gridTickets[];
int g_currentGridLevel = 0;
double g_lastGridZScore = 0;

// v2.2: Trailing Stop tracking
bool g_trailingActive = false;
double g_trailingBestZScore = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
    trade.SetExpertMagicNumber(MAGIC_E1_RATE);
    trade.SetDeviationInPoints(50);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    // Configurar API
    api.SetFREDKey(InpFREDKey);
    
    // Inicializar array de spreads
    ArrayResize(g_spreadHistory, InpZScorePeriod);
    ArrayInitialize(g_spreadHistory, 0);
    
    // v2.2: Inicializar grid tracking
    if(InpUseGrid) {
        ArrayResize(g_gridTickets, InpMaxGridLevels);
        ArrayInitialize(g_gridTickets, 0);
    }
    
    Print("==================================================");
    Print("✅ E1_RateSpread v2.2 (Grid + Trailing + Equity DD) Inicializado");
    Print("📊 Spread: ", InpSeries1, " - ", InpSeries2);
    Print("📈 Z-Score Entry: ±", InpZScoreEntry);
    Print("📉 Z-Score Exit: ±", InpZScoreExit);
    if(InpUseGrid) Print("🔲 Grid: ", InpMaxGridLevels, " niveles, Step=", InpGridStepZScore);
    if(InpUseTrailing) Print("📍 Trailing: Activar @ Z<", InpTrailingActivateZScore, ", Step=", InpTrailingStepZScore);
    if(InpUseEquityDD) Print("🛡️ Equity DD Limit: ", InpEquityDDPercent, "%");
    Print("⏰ Update Interval: ", InpUpdateIntervalHours, " horas");
    Print("💰 Riesgo: ", InpRiskPercent, "%");
    Print("==================================================");
    
    // Test inicial de API - v2.4: VALIDAR conectividad antes de continuar
    Print("🔍 Testeando conectividad FRED API...");
    double testValue = api.GetFREDValue(InpSeries1);
    if(testValue > 0) {
        Print("✅ FRED API: Conectado (", InpSeries1, " = ", FormatDouble(testValue, 4), ")");
    } else {
        Print("❌ FRED API: Error en test inicial - No se puede iniciar sin datos");
        Print("⚠️ Verificar: 1) InpFREDKey válida, 2) Conexión internet, 3) Series válidas");
        return(INIT_FAILED);
    }
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // v2.4: Liberar recursos de arrays dinámicos
    ArrayFree(g_spreadHistory);
    if(InpUseGrid) {
        ArrayFree(g_gridTickets);
    }
    
    Print("🛑 E1_RateSpread v2.4 Detenido. Razón: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
    // Check 1: ¿Podemos operar?
    if(!GlobalComms::CanTrade(MAGIC_E1_RATE)) {
        return;
    }
    
    // Check 2: Reset semanal
    ResetWeeklyCounter();
    
    // Check 3: Actualizar spread si es necesario
    if(ShouldUpdateSpread()) {
        UpdateSpread();
    }
    
    // v2.2: Check 3.5: Equity DD Protection - Close ALL positions
    if(InpUseEquityDD && CheckEquityDD()) {
        CloseAllPositions();
        return;
    }
    
    // Check 4: Gestionar posición abierta
    if(g_currentTicket > 0) {
        ManageOpenPosition();
        return;
    }
    
    // Check 5: Límite de trades
    if(g_tradesThisWeek >= InpMaxTradesPerWeek) {
        return;
    }
    
    // Check 6: Necesitamos historial suficiente
    if(g_spreadHistory[InpZScorePeriod - 1] == 0) {
        return; // Aún no tenemos suficiente historial
    }
    
    // Calcular Z-Score
    double zScore = CalculateZScore();
    
    if(zScore == 0) return;
    
    // v2.2: Verificar si debemos abrir nivel grid adicional
    if(InpUseGrid && g_currentTicket > 0 && g_currentGridLevel < InpMaxGridLevels) {
        CheckGridEntry(zScore);
    }
    
    // Señal de compra: Spread muy bajo (Z-Score < -2)
    // Interpretación: Esperamos que el spread aumente
    if(zScore < -InpZScoreEntry) {
        ExecuteTrade(ORDER_TYPE_BUY, zScore);
        return;
    }
    
    // Señal de venta: Spread muy alto (Z-Score > 2)
    // Interpretación: Esperamos que el spread disminuya
    if(zScore > InpZScoreEntry) {
        ExecuteTrade(ORDER_TYPE_SELL, zScore);
        return;
    }
}

//+------------------------------------------------------------------+
//| Verifica si debe actualizar el spread                            |
//+------------------------------------------------------------------+
bool ShouldUpdateSpread() {
    if(g_lastUpdate == 0) return true;
    
    int hoursElapsed = (int)((TimeCurrent() - g_lastUpdate) / 3600);
    
    return (hoursElapsed >= InpUpdateIntervalHours);
}

//+------------------------------------------------------------------+
//| Actualiza el spread desde FRED                                   |
//+------------------------------------------------------------------+
void UpdateSpread() {
    Print("📡 E1_RateSpread: Actualizando spread desde FRED...");
    
    double spread = api.GetFREDSpread(InpSeries1, InpSeries2);
    
    if(spread != 0) {
        g_lastSpread = spread;
        g_lastUpdate = TimeCurrent();
        
        // Actualizar historial (shift array)
        for(int i = InpZScorePeriod - 1; i > 0; i--) {
            g_spreadHistory[i] = g_spreadHistory[i - 1];
        }
        g_spreadHistory[0] = spread;
        
        Print("✅ Spread actualizado: ", FormatDouble(spread, 4), " | Z-Score: ", 
              FormatDouble(CalculateZScore(), 2));
    } else {
        Print("❌ Error actualizando spread");
    }
}

//+------------------------------------------------------------------+
//| Calcula Z-Score del spread actual                                |
//+------------------------------------------------------------------+
double CalculateZScore() {
    // Calcular media
    double sum = 0;
    for(int i = 0; i < InpZScorePeriod; i++) {
        sum += g_spreadHistory[i];
    }
    double mean = sum / InpZScorePeriod;
    
    // Calcular desviación estándar
    double sumSquaredDiff = 0;
    for(int i = 0; i < InpZScorePeriod; i++) {
        double diff = g_spreadHistory[i] - mean;
        sumSquaredDiff += diff * diff;
    }
    double stdDev = MathSqrt(sumSquaredDiff / InpZScorePeriod);
    
    if(stdDev == 0) return 0;
    
    // Z-Score = (valor actual - media) / std dev
    double zScore = (g_lastSpread - mean) / stdDev;
    
    return zScore;
}

//+------------------------------------------------------------------+
//| Gestiona posición abierta (salida por Z-Score + Trailing)        |
//+------------------------------------------------------------------+
void ManageOpenPosition() {
    if(!PositionSelectByTicket(g_currentTicket)) {
        g_currentTicket = 0;
        g_currentGridLevel = 0;      // v2.2
        g_trailingActive = false;     // v2.2
        ArrayInitialize(g_gridTickets, 0);  // v2.2
        return;
    }
    
    double zScore = CalculateZScore();
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    bool shouldExit = false;
    
    // v2.2: Trailing Stop Logic
    if(InpUseTrailing) {
        // Activar trailing cuando Z-Score se acerca a 0 (reversión exitosa)
        if(!g_trailingActive && MathAbs(zScore) < InpTrailingActivateZScore) {
            g_trailingActive = true;
            g_trailingBestZScore = zScore;
            Print("📍 E1_RateSpread v2.2: Trailing Stop ACTIVADO @ Z=", FormatDouble(zScore, 2));
        }
        
        // Si trailing activo, actualizar best Z-Score y verificar salida
        if(g_trailingActive) {
            // Para BUY: mejor Z-Score es el más alto (más positivo)
            if(posType == POSITION_TYPE_BUY && zScore > g_trailingBestZScore) {
                g_trailingBestZScore = zScore;
            }
            // Para SELL: mejor Z-Score es el más bajo (más negativo)
            if(posType == POSITION_TYPE_SELL && zScore < g_trailingBestZScore) {
                g_trailingBestZScore = zScore;
            }
            
            // Salida por trailing: Z-Score retrocede más de Step desde best
            bool trailingExit = false;
            if(posType == POSITION_TYPE_BUY && (g_trailingBestZScore - zScore) > InpTrailingStepZScore) {
                trailingExit = true;
            }
            if(posType == POSITION_TYPE_SELL && (zScore - g_trailingBestZScore) > InpTrailingStepZScore) {
                trailingExit = true;
            }
            
            if(trailingExit) {
                shouldExit = true;
                Print("📍 E1_RateSpread v2.2: Trailing Stop hit! Best=", 
                      FormatDouble(g_trailingBestZScore, 2), " Current=", FormatDouble(zScore, 2));
            }
        }
    }
    
    // Salida original por Z-Score
    if(!shouldExit) {
        // Salida para posición larga: Z-Score vuelve a ±0.5
        if(posType == POSITION_TYPE_BUY && zScore > -InpZScoreExit) {
            shouldExit = true;
        }
        
        // Salida para posición corta: Z-Score vuelve a ±0.5
        if(posType == POSITION_TYPE_SELL && zScore < InpZScoreExit) {
            shouldExit = true;
        }
    }
    
    // SL por DD excesivo (por posición individual)
    double currentPL = PositionGetDouble(POSITION_PROFIT);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double ddPercent = (currentPL / equity) * 100.0;
    
    if(ddPercent < -InpMaxDDPercent) {
        shouldExit = true;
        Print("⚠️ E1_RateSpread: Cerrando por DD > ", InpMaxDDPercent, "% (", 
              FormatDouble(ddPercent, 2), "%)");
    }
    
    if(shouldExit) {
        // v2.2: Cerrar todas las posiciones grid también
        CloseAllPositions();
    }
}

//+------------------------------------------------------------------+
//| Ejecuta trade basado en Z-Score (v2.2 con grid inicial)          |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType, double zScore) {
    // Calcular lotaje conservador
    double lots = riskMgr.CalculateLotSize(InpRiskPercent, 50); // 50 pips SL aproximado
    
    if(lots == 0) {
        Print("❌ E1_RateSpread: Error calculando lotaje");
        return;
    }
    
    // Ejecutar orden (sin SL/TP fijos, gestión manual)
    bool result = false;
    string comment = "E1_RateSpread_v2.2_Z" + DoubleToString(zScore, 2);
    
    double entryPrice = SymbolInfoDouble(_Symbol, 
                        orderType == ORDER_TYPE_BUY ? SYMBOL_ASK : SYMBOL_BID);
    
    if(orderType == ORDER_TYPE_BUY) {
        result = trade.Buy(lots, _Symbol, 0, 0, 0, comment);
    } else {
        result = trade.Sell(lots, _Symbol, 0, 0, 0, comment);
    }
    
    if(result) {
        g_currentTicket = trade.ResultOrder();
        g_tradesThisWeek++;
        
        // v2.2: Inicializar grid
        if(InpUseGrid) {
            g_currentGridLevel = 1;
            g_gridTickets[0] = g_currentTicket;
            g_lastGridZScore = zScore;
        }
        
        Print("==================================================");
        Print("✅ E1_RateSpread v2.2: TRADE EJECUTADO");
        Print("🎫 Ticket: ", g_currentTicket);
        Print("📍 Tipo: ", EnumToString(orderType));
        Print("💵 Lots: ", lots);
        Print("📊 Spread: ", FormatDouble(g_lastSpread, 4));
        Print("📈 Z-Score: ", FormatDouble(zScore, 2));
        Print("🎯 Exit Z-Score: ±", InpZScoreExit);
        if(InpUseGrid) Print("🔲 Grid Level: 1/", InpMaxGridLevels);
        if(InpUseTrailing) Print("📍 Trailing: Activará @ Z<", InpTrailingActivateZScore);
        Print("==================================================");
    } else {
        Print("❌ E1_RateSpread: Error ejecutando trade. Code: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Reset contador semanal                                           |
//+------------------------------------------------------------------+
void ResetWeeklyCounter() {
    MqlDateTime current;
    TimeToStruct(TimeCurrent(), current);
    
    if(g_weekStart == 0) {
        g_weekStart = TimeCurrent();
        return;
    }
    
    MqlDateTime weekStartTime;
    TimeToStruct(g_weekStart, weekStartTime);
    
    // Reset cada lunes
    if(current.day_of_week == 1 && weekStartTime.day_of_week != 1) {
        g_tradesThisWeek = 0;
        g_weekStart = TimeCurrent();
        Print("📅 E1_RateSpread: Nueva semana - Contador reseteado");
    }
}

//+------------------------------------------------------------------+
//| v2.2: Verificar si debemos abrir nivel grid adicional            |
//+------------------------------------------------------------------+
void CheckGridEntry(double zScore) {
    if(!PositionSelectByTicket(g_currentTicket)) return;
    
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    // Calcular distancia desde último grid
    double zScoreDiff = MathAbs(zScore - g_lastGridZScore);
    
    // Si Z-Score se mueve InpGridStepZScore más en la misma dirección, abrir nuevo nivel
    bool openNewLevel = false;
    
    if(posType == POSITION_TYPE_BUY && zScore < g_lastGridZScore - InpGridStepZScore) {
        openNewLevel = true;  // Spread sigue bajando, agregar más BUY
    }
    if(posType == POSITION_TYPE_SELL && zScore > g_lastGridZScore + InpGridStepZScore) {
        openNewLevel = true;  // Spread sigue subiendo, agregar más SELL
    }
    
    if(openNewLevel) {
        // Calcular lote incrementado
        double baseLots = riskMgr.CalculateLotSize(InpRiskPercent, 50);
        double gridLots = baseLots * MathPow(InpGridLotMultiplier, g_currentGridLevel);
        
        // Ejecutar orden grid
        bool result = false;
        string comment = "E1_Grid_L" + IntegerToString(g_currentGridLevel + 1) + "_Z" + DoubleToString(zScore, 2);
        
        if(posType == POSITION_TYPE_BUY) {
            result = trade.Buy(gridLots, _Symbol, 0, 0, 0, comment);
        } else {
            result = trade.Sell(gridLots, _Symbol, 0, 0, 0, comment);
        }
        
        if(result) {
            g_gridTickets[g_currentGridLevel] = trade.ResultOrder();
            g_currentGridLevel++;
            g_lastGridZScore = zScore;
            
            Print("🔲 E1_RateSpread v2.2: GRID NIVEL ", g_currentGridLevel, " abierto!");
            Print("   Ticket: ", g_gridTickets[g_currentGridLevel - 1]);
            Print("   Lots: ", gridLots, " (x", FormatDouble(InpGridLotMultiplier, 1), ")");
            Print("   Z-Score: ", FormatDouble(zScore, 2));
        }
    }
}

//+------------------------------------------------------------------+
//| v2.2: Verificar Equity DD global                                 |
//+------------------------------------------------------------------+
bool CheckEquityDD() {
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    double ddPercent = ((equity - balance) / balance) * 100.0;
    
    if(ddPercent < -InpEquityDDPercent) {
        Print("🚨 E1_RateSpread v2.2: EQUITY DD LIMIT HIT!");
        Print("   Balance: $", FormatDouble(balance, 2));
        Print("   Equity: $", FormatDouble(equity, 2));
        Print("   DD: ", FormatDouble(ddPercent, 2), "% > ", InpEquityDDPercent, "%");
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| v2.2: Cerrar todas las posiciones (grid completo)                |
//+------------------------------------------------------------------+
void CloseAllPositions() {
    double totalPL = 0;
    int closedCount = 0;
    
    // Cerrar posición principal
    if(g_currentTicket > 0) {
        if(PositionSelectByTicket(g_currentTicket)) {
            totalPL += PositionGetDouble(POSITION_PROFIT);
            if(trade.PositionClose(g_currentTicket)) {
                closedCount++;
            }
        }
        g_currentTicket = 0;
    }
    
    // Cerrar posiciones grid
    if(InpUseGrid) {
        for(int i = 0; i < g_currentGridLevel; i++) {
            if(g_gridTickets[i] > 0) {
                if(PositionSelectByTicket(g_gridTickets[i])) {
                    totalPL += PositionGetDouble(POSITION_PROFIT);
                    if(trade.PositionClose(g_gridTickets[i])) {
                        closedCount++;
                    }
                }
            }
        }
        
        // Reset grid
        ArrayInitialize(g_gridTickets, 0);
        g_currentGridLevel = 0;
        g_lastGridZScore = 0;
    }
    
    // Reset trailing
    g_trailingActive = false;
    g_trailingBestZScore = 0;
    
    if(closedCount > 0) {
        Print("==================================================");
        Print("✅ E1_RateSpread v2.2: TODAS LAS POSICIONES CERRADAS");
        Print("   Posiciones: ", closedCount);
        Print("   P/L Total: $", FormatDouble(totalPL, 2));
        Print("   Z-Score: ", FormatDouble(CalculateZScore(), 2));
        Print("==================================================");
    }
}

//+------------------------------------------------------------------+
