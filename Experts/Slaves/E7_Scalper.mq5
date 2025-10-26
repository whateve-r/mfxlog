//+------------------------------------------------------------------+
//| E7_Scalper.mq5 - Inverse R:R Scalper (Challenge Accelerator)     |
//| Squad of Systems - Trading System                                |
//| Copyright 2025, SoS Trading                                       |
//| ⚠️ WARNING: HIGH RISK - SOLO PARA CHALLENGES, NO FONDEO          |
//+------------------------------------------------------------------+
#property copyright "SoS Trading System"
#property link      "https://github.com/sos-trading"
#property version   "1.00"
#property description "⚠️ SCALPER AGRESIVO - Solo para fase de challenge"

#include <Trade\Trade.mqh>
#include "..\..\Include\SoS_Commons.mqh"
#include "..\..\Include\SoS_GlobalComms.mqh"
#include "..\..\Include\SoS_RiskManager.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== ⚠️ RISK WARNING ==="
input bool   InpConfirmHighRisk = false;        // ⚠️ Confirmo alto riesgo (challenge only)

input group "=== SCALPING SETTINGS ==="
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M1; // Timeframe de scalping
input int    InpEMAPeriod = 20;                 // EMA para trend
input int    InpRSIPeriod = 7;                  // RSI rápido
input double InpRSIOverbought = 70;             // RSI sobrecompra
input double InpRSIOversold = 30;               // RSI sobreventa

input group "=== RISK MANAGEMENT ==="
input int    InpSLPips = 40;                    // Stop Loss (pips)
input int    InpTPPips = 30;                    // Take Profit (pips)
input double InpMaxRiskPercent = 4.0;           // ⚠️ Riesgo máximo por trade (%)
input bool   InpUseAggressiveLots = true;       // Usar lotaje agresivo

input group "=== LIMITS ==="
input int    InpMaxTradesPerDay = 2;            // Máximo trades diarios
input double InpDailyProfitTarget = 3.0;        // Profit target diario (%)
input int    InpTradingStartHour = 0;           // v2.5: 24h para testing (antes 8)
input int    InpTradingEndHour = 23;            // v2.5: 24h para testing (antes 18)

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;
RiskManager riskMgr(_Symbol, MAGIC_E7_SCALP);  // v2.4: Constructor con magic para TradeHistory

int g_tradesToday = 0;
datetime g_lastResetDate = 0;
double g_dailyStartBalance = 0;
bool g_dailyTargetReached = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
    // VERIFICACIÓN DE SEGURIDAD
    if(!InpConfirmHighRisk) {
        Print("==================================================");
        Print("❌ E7_Scalper: DETENIDO");
        Print("⚠️ DEBE CONFIRMAR que entiende el ALTO RIESGO");
        Print("⚠️ Este EA es SOLO para CHALLENGES, NO para fondeo");
        Print("📝 Activar: InpConfirmHighRisk = true");
        Print("==================================================");
        return(INIT_PARAMETERS_INCORRECT);
    }
    
    trade.SetExpertMagicNumber(MAGIC_E7_SCALP);
    trade.SetDeviationInPoints(30); // Slippage más agresivo
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    Print("==================================================");
    Print("⚠️ E7_SCALPER (INVERSE R:R) INICIALIZADO ⚠️");
    Print("==================================================");
    Print("🚨 ADVERTENCIA: ESTRATEGIA DE ALTO RIESGO");
    Print("📊 R:R: 1:", FormatDouble((double)InpTPPips/InpSLPips, 2), " (INVERSO)");
    Print("💰 Riesgo máx: ", InpMaxRiskPercent, "% por trade");
    Print("🎯 Target diario: ", InpDailyProfitTarget, "%");
    Print("⏰ Horario: ", InpTradingStartHour, ":00 - ", InpTradingEndHour, ":00 UTC");
    Print("📈 Timeframe: ", EnumToString(InpTimeframe));
    Print("==================================================");
    Print("⚠️ USAR SOLO EN CHALLENGES - NO EN FONDEO ⚠️");
    Print("==================================================");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("🛑 E7_Scalper Detenido. Razón: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
    // Check 1: ¿Podemos operar?
    if(!GlobalComms::CanTrade(MAGIC_E7_SCALP)) {
        return;
    }
    
    // Check 2: Reset diario
    ResetDaily();
    
    // Check 3: Target diario alcanzado
    if(g_dailyTargetReached) {
        return;
    }
    
    // Check 4: Límite de trades
    if(g_tradesToday >= InpMaxTradesPerDay) {
        return;
    }
    
    // Check 5: Horario de trading
    if(!IsInTradingHours()) {
        return;
    }
    
    // Check 6: Hay posiciones abiertas? (scalping: 1 trade a la vez)
    if(riskMgr.GetOpenPositions(MAGIC_E7_SCALP) > 0) {
        return;
    }
    
    // Buscar señal de scalping
    EvaluateScalpingSignal();
}

//+------------------------------------------------------------------+
//| Evalúa señal de scalping                                         |
//+------------------------------------------------------------------+
void EvaluateScalpingSignal() {
    // Obtener EMA
    int emaHandle = iMA(_Symbol, InpTimeframe, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    double emaBuffer[];
    ArraySetAsSeries(emaBuffer, true);
    
    if(SafeCopyBuffer(emaHandle, 0, 0, 1, emaBuffer) <= 0) {
        IndicatorRelease(emaHandle);
        Print("⚠️ E7_Scalp: Error obteniendo EMA - Omitiendo tick");
        return;
    }
    
    double ema = emaBuffer[0];
    IndicatorRelease(emaHandle);
    
    // v2.4: Obtener RSI con retry logic
    int rsiHandle = iRSI(_Symbol, InpTimeframe, InpRSIPeriod, PRICE_CLOSE);
    double rsiBuffer[];
    ArraySetAsSeries(rsiBuffer, true);
    
    if(SafeCopyBuffer(rsiHandle, 0, 0, 1, rsiBuffer) <= 0) {
        IndicatorRelease(rsiHandle);
        Print("⚠️ E7_Scalp: Error obteniendo RSI - Omitiendo tick");
        return;
    }
    
    double rsi = rsiBuffer[0];
    IndicatorRelease(rsiHandle);
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Señal BUY: Precio > EMA && RSI < 30 (oversold bounce)
    if(currentPrice > ema && rsi < InpRSIOversold) {
        ExecuteScalp(ORDER_TYPE_BUY);
        return;
    }
    
    // Señal SELL: Precio < EMA && RSI > 70 (overbought rejection)
    if(currentPrice < ema && rsi > InpRSIOverbought) {
        ExecuteScalp(ORDER_TYPE_SELL);
        return;
    }
}

//+------------------------------------------------------------------+
//| Ejecuta scalp con lotaje agresivo                                |
//+------------------------------------------------------------------+
void ExecuteScalp(ENUM_ORDER_TYPE orderType) {
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
    
    // Calcular lotaje AGRESIVO
    double lots;
    
    if(InpUseAggressiveLots) {
        lots = riskMgr.CalculateScalperLots(InpSLPips);
        Print("⚡ E7: Lotaje AGRESIVO calculado: ", lots);
    } else {
        lots = riskMgr.CalculateLotSize(InpMaxRiskPercent, InpSLPips);
        Print("📊 E7: Lotaje estándar: ", lots);
    }
    
    if(lots == 0) {
        Print("❌ E7: Error calculando lotaje");
        return;
    }
    
    // Ejecutar orden
    bool result = false;
    string comment = "E7_Scalp_" + EnumToString(orderType);
    
    if(orderType == ORDER_TYPE_BUY) {
        result = trade.Buy(lots, _Symbol, 0, slPrice, tpPrice, comment);
    } else {
        result = trade.Sell(lots, _Symbol, 0, slPrice, tpPrice, comment);
    }
    
    if(result) {
        g_tradesToday++;
        
        double rr = (double)InpTPPips / InpSLPips;
        double riskAmount = (lots * InpSLPips * point * 10 * 
                           SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE));
        double riskPercent = (riskAmount / AccountInfoDouble(ACCOUNT_EQUITY)) * 100.0;
        
        Print("==================================================");
        Print("⚡ E7_SCALPER: TRADE #", g_tradesToday, " EJECUTADO");
        Print("🎫 Ticket: ", trade.ResultOrder());
        Print("📍 Tipo: ", EnumToString(orderType));
        Print("💵 Lots: ", lots, " (⚠️ AGRESIVO)");
        Print("💰 Riesgo: ", FormatDouble(riskPercent, 2), "%");
        Print("📉 SL: ", slPrice, " (", InpSLPips, " pips)");
        Print("📈 TP: ", tpPrice, " (", InpTPPips, " pips)");
        Print("🎯 R:R: 1:", FormatDouble(rr, 2), " ⚠️ INVERSO");
        Print("==================================================");
    } else {
        Print("❌ E7: Error ejecutando trade. Code: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Verifica horario de trading                                      |
//+------------------------------------------------------------------+
bool IsInTradingHours() {
    MqlDateTime current;
    TimeToStruct(TimeCurrent(), current);
    
    return (current.hour >= InpTradingStartHour && current.hour < InpTradingEndHour);
}

//+------------------------------------------------------------------+
//| Reset diario                                                      |
//+------------------------------------------------------------------+
void ResetDaily() {
    MqlDateTime current;
    TimeToStruct(TimeCurrent(), current);
    
    if(g_lastResetDate != 0) {
        MqlDateTime lastReset;
        TimeToStruct(g_lastResetDate, lastReset);
        
        if(lastReset.day != current.day) {
            // Calcular profit del día anterior
            double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
            double dailyProfit = currentBalance - g_dailyStartBalance;
            double dailyProfitPercent = (dailyProfit / g_dailyStartBalance) * 100.0;
            
            Print("==================================================");
            Print("🌅 E7: NUEVO DÍA");
            Print("📊 Profit día anterior: $", FormatDouble(dailyProfit, 2), 
                  " (", FormatDouble(dailyProfitPercent, 2), "%)");
            Print("🔢 Trades ejecutados: ", g_tradesToday);
            Print("==================================================");
            
            // Reset variables
            g_tradesToday = 0;
            g_dailyTargetReached = false;
            g_dailyStartBalance = currentBalance;
            g_lastResetDate = TimeCurrent();
        }
    } else {
        g_lastResetDate = TimeCurrent();
    }
    
    // Verificar si alcanzamos target diario
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double dailyProfit = currentBalance - g_dailyStartBalance;
    double dailyProfitPercent = (dailyProfit / g_dailyStartBalance) * 100.0;
    
    if(dailyProfitPercent >= InpDailyProfitTarget && !g_dailyTargetReached) {
        g_dailyTargetReached = true;
        
        Print("==================================================");
        Print("🎯 E7: TARGET DIARIO ALCANZADO!");
        Print("💰 Profit: $", FormatDouble(dailyProfit, 2), 
              " (", FormatDouble(dailyProfitPercent, 2), "%)");
        Print("✅ No más trades hoy - Preservar ganancias");
        Print("==================================================");
        
        SendNotification("🎯 E7_Scalper: Target diario alcanzado! +" + 
                        DoubleToString(dailyProfitPercent, 2) + "%");
    }
}

//+------------------------------------------------------------------+
