//+------------------------------------------------------------------+
//| SoS_RiskManager.mqh - Gestión de Riesgo Centralizada             |
//| Squad of Systems - Trading System                                |
//| Copyright 2025, SoS Trading                                       |
//+------------------------------------------------------------------+
#property copyright "SoS Trading System"
#property version   "2.40"
#property strict

#include "SoS_Commons.mqh"
#include "SoS_TradeHistory.mqh"

//+------------------------------------------------------------------+
//| Clase RiskManager - Gestión de Lotaje, DD y Kelly Criterion      |
//+------------------------------------------------------------------+
class RiskManager {
private:
    string m_symbol;
    CTradeHistory* m_history;  // v2.4: Integración TradeHistory
    int m_magic;
    
public:
    //+------------------------------------------------------------------+
    //| Constructor                                                       |
    //+------------------------------------------------------------------+
    RiskManager() {
        m_symbol = _Symbol;
        m_magic = 0;
        m_history = NULL;
    }
    
    //+------------------------------------------------------------------+
    //| Constructor con símbolo específico                               |
    //+------------------------------------------------------------------+
    RiskManager(string symbol) {
        m_symbol = symbol;
        m_magic = 0;
        m_history = NULL;
    }
    
    //+------------------------------------------------------------------+
    //| Constructor con símbolo y magic (v2.4 - recomendado)             |
    //+------------------------------------------------------------------+
    RiskManager(string symbol, int magic) {
        m_symbol = symbol;
        m_magic = magic;
        m_history = new CTradeHistory(magic);
    }
    
    //+------------------------------------------------------------------+
    //| Destructor - v2.4: Liberar TradeHistory                          |
    //+------------------------------------------------------------------+
    ~RiskManager() {
        if(m_history != NULL) {
            delete m_history;
            m_history = NULL;
        }
    }
    
    //+------------------------------------------------------------------+
    //| Calcula el tamaño de lote basado en riesgo (%)                   |
    //+------------------------------------------------------------------+
    double CalculateLotSize(double riskPercent, double slPips) {
        if(slPips <= 0) {
            Print("❌ Error: SL en pips debe ser > 0");
            return 0;
        }
        
        if(riskPercent <= 0 || riskPercent > RISK_PER_TRADE_MAX) {
            Print("❌ Error: Riesgo debe estar entre 0 y ", RISK_PER_TRADE_MAX, "%");
            return 0;
        }
        
        // Obtener equity actual
        double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        
        // Calcular monto de riesgo
        double riskAmount = accountEquity * (riskPercent / 100.0);
        
        // Obtener información del símbolo
        double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
        double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
        int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
        
        // Calcular valor por pip
        double pipMultiplier = (digits == 5 || digits == 3) ? 10.0 : 1.0;
        double pipValue = (tickValue / tickSize) * point * pipMultiplier;
        
        // Calcular lotes necesarios
        double lots = riskAmount / (slPips * pipValue);
        
        // Normalizar según límites del broker
        lots = NormalizeLots(lots);
        
        return lots;
    }
    
    //+------------------------------------------------------------------+
    //| Calcula lote usando Fractional Kelly Criterion                   |
    //+------------------------------------------------------------------+
    double CalculateKellyLots(double winRate, double avgWin, double avgLoss, double slPips, double kellyFraction = 0.25) {
        if(winRate <= 0 || winRate >= 1 || avgWin <= 0 || avgLoss <= 0 || slPips <= 0) {
            Print("❌ Error en parámetros de Kelly: WinRate=", winRate, " AvgWin=", avgWin, " AvgLoss=", avgLoss);
            return CalculateLotSize(RISK_PER_TRADE_DEFAULT, slPips);
        }
        
        // Kelly Criterion: f = (p*b - q) / b
        // Donde: p = win rate, q = 1-p, b = avg_win/avg_loss
        double b = avgWin / avgLoss;
        double kellyPercent = ((winRate * b) - (1 - winRate)) / b;
        
        // Aplicar fracción de Kelly (default 25% = Kelly fraccionado)
        kellyPercent *= kellyFraction;
        
        // Limitar al rango permitido
        if(kellyPercent < RISK_PER_TRADE_MIN) kellyPercent = RISK_PER_TRADE_MIN;
        if(kellyPercent > RISK_PER_TRADE_MAX) kellyPercent = RISK_PER_TRADE_MAX;
        
        Print("📊 Kelly Fraction (", kellyFraction*100, "%): Riesgo calculado = ", FormatDouble(kellyPercent, 3), "%");
        
        return CalculateLotSize(kellyPercent, slPips);
    }
    
    //+------------------------------------------------------------------+
    //| v2.4: Calcula Kelly automático desde historial (TradeHistory)    |
    //+------------------------------------------------------------------+
    double CalculateAutoKellyLots(double slPips, double kellyFraction = 0.5) {
        // Si no hay historial configurado, usar Kelly default
        if(m_history == NULL) {
            Print("⚠️ TradeHistory no configurado - Usando Kelly default");
            return CalculateKellyLots(0.55, 150, 100, slPips, kellyFraction);
        }
        
        // Actualizar estadísticas
        m_history.Update();
        
        // Verificar si hay suficientes datos
        if(!m_history.HasSufficientData()) {
            Print("⚠️ Datos insuficientes (", m_history.GetTotalTrades(), " trades) - Usando riesgo conservador");
            return CalculateLotSize(RISK_PER_TRADE_MIN, slPips);
        }
        
        // Verificar salud del sistema
        if(!m_history.IsHealthy()) {
            Print("⚠️ Sistema no saludable - WinRate=", FormatDouble(m_history.GetWinRate()*100, 1), 
                  "% PF=", FormatDouble(m_history.GetProfitFactor(), 2), " - Usando riesgo mínimo");
            return CalculateLotSize(RISK_PER_TRADE_MIN, slPips);
        }
        
        // Obtener Kelly automático (Half-Kelly ya aplicado internamente)
        double kellyRisk = m_history.GetKellyFraction();
        
        Print("📊 Auto Kelly (EA=", m_magic, "): ", 
              "WinRate=", FormatDouble(m_history.GetWinRate()*100, 1), "% ",
              "PF=", FormatDouble(m_history.GetProfitFactor(), 2), " ",
              "Riesgo=", FormatDouble(kellyRisk, 3), "%");
        
        return CalculateLotSize(kellyRisk, slPips);
    }
    
    //+------------------------------------------------------------------+
    //| Normaliza lotes según límites del broker                         |
    //+------------------------------------------------------------------+
    double NormalizeLots(double lots) {
        double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
        double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
        
        // Ajustar a límites
        if(lots < minLot) lots = minLot;
        if(lots > maxLot) lots = maxLot;
        
        // Redondear al step más cercano
        lots = MathFloor(lots / lotStep) * lotStep;
        
        return NormalizeDouble(lots, 2);
    }
    
    //+------------------------------------------------------------------+
    //| Calcula el Drawdown Global actual (%)                            |
    //+------------------------------------------------------------------+
    double GetCurrentGlobalDD() {
        double initialBalance = GlobalVariableGet(GV_INITIAL_BALANCE);
        if(initialBalance == 0) initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        
        double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        
        if(currentEquity >= initialBalance) return 0;
        
        return ((initialBalance - currentEquity) / initialBalance) * 100.0;
    }
    
    //+------------------------------------------------------------------+
    //| Calcula el Drawdown Diario actual (%)                            |
    //+------------------------------------------------------------------+
    double GetCurrentDailyDD() {
        double dailyStartBalance = GlobalVariableGet(GV_DAILY_START_BALANCE);
        if(dailyStartBalance == 0) dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        
        double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        
        if(currentEquity >= dailyStartBalance) return 0;
        
        return ((dailyStartBalance - currentEquity) / dailyStartBalance) * 100.0;
    }
    
    //+------------------------------------------------------------------+
    //| Verifica si se pueden abrir nuevas posiciones (límite de DD)     |
    //+------------------------------------------------------------------+
    bool CanOpenNewPosition(double additionalRiskPercent = 0) {
        double globalDD = GetCurrentGlobalDD();
        double dailyDD = GetCurrentDailyDD();
        
        // Verificar si ya estamos cerca del límite
        if(globalDD + additionalRiskPercent >= MAX_GLOBAL_DD) {
            Print("⚠️ No se puede abrir posición: Global DD (", FormatDouble(globalDD, 2), 
                  "%) + Riesgo adicional (", FormatDouble(additionalRiskPercent, 2), 
                  "%) >= Límite (", MAX_GLOBAL_DD, "%)");
            return false;
        }
        
        if(dailyDD + additionalRiskPercent >= MAX_DAILY_DD) {
            Print("⚠️ No se puede abrir posición: Daily DD (", FormatDouble(dailyDD, 2), 
                  "%) + Riesgo adicional (", FormatDouble(additionalRiskPercent, 2), 
                  "%) >= Límite (", MAX_DAILY_DD, "%)");
            return false;
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Calcula DD restante disponible (%)                               |
    //+------------------------------------------------------------------+
    double GetRemainingDDCapacity() {
        double globalDD = GetCurrentGlobalDD();
        double dailyDD = GetCurrentDailyDD();
        
        double remainingGlobal = MAX_GLOBAL_DD - globalDD;
        double remainingDaily = MAX_DAILY_DD - dailyDD;
        
        // Retornar el menor de los dos (el más restrictivo)
        return MathMin(remainingGlobal, remainingDaily);
    }
    
    //+------------------------------------------------------------------+
    //| Calcula ATR actual                                               |
    //+------------------------------------------------------------------+
    double GetATR(ENUM_TIMEFRAMES timeframe, int period = 14, int shift = 0) {
        int atrHandle = iATR(m_symbol, timeframe, period);
        if(atrHandle == INVALID_HANDLE) {
            Print("❌ Error al obtener handle de ATR");
            return 0;
        }
        
        double atrBuffer[];
        ArraySetAsSeries(atrBuffer, true);
        
        if(CopyBuffer(atrHandle, 0, shift, 1, atrBuffer) <= 0) {
            Print("❌ Error al copiar buffer de ATR");
            return 0;
        }
        
        IndicatorRelease(atrHandle);
        return atrBuffer[0];
    }
    
    //+------------------------------------------------------------------+
    //| Calcula SL en pips basado en ATR                                 |
    //+------------------------------------------------------------------+
    double CalculateATRbasedSL(ENUM_TIMEFRAMES timeframe, double atrMultiplier = 2.0) {
        double atr = GetATR(timeframe, 14, 0);
        if(atr == 0) {
            Print("⚠️ ATR = 0, usando SL por defecto de 20 pips");
            return 20;
        }
        
        double slPips = CalculatePips(m_symbol, atr * atrMultiplier);
        
        Print("📊 ATR SL calculado: ", FormatDouble(slPips, 1), " pips (ATR=", 
              FormatDouble(atr, 5), ", Multiplicador=", atrMultiplier, ")");
        
        return slPips;
    }
    
    //+------------------------------------------------------------------+
    //| Calcula el tamaño de lote para E7 Scalper (riesgo agresivo)      |
    //+------------------------------------------------------------------+
    double CalculateScalperLots(double slPips) {
        double remainingDD = GetRemainingDDCapacity();
        
        // E7 usa hasta el 80% del DD restante (SOLO para challenges)
        double aggressiveRisk = remainingDD * 0.8;
        
        // Limitar al máximo permitido
        if(aggressiveRisk > 4.0) aggressiveRisk = 4.0;
        if(aggressiveRisk < RISK_PER_TRADE_MIN) aggressiveRisk = RISK_PER_TRADE_MIN;
        
        Print("⚡ E7 Scalper: Riesgo agresivo = ", FormatDouble(aggressiveRisk, 2), 
              "% (", FormatDouble(remainingDD*0.8, 2), "% del DD restante)");
        
        return CalculateLotSize(aggressiveRisk, slPips);
    }
    
    //+------------------------------------------------------------------+
    //| Obtiene el número de posiciones abiertas de un EA específico     |
    //+------------------------------------------------------------------+
    int GetOpenPositions(int magic) {
        int count = 0;
        for(int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0) {
                if(PositionGetInteger(POSITION_MAGIC) == magic) {
                    count++;
                }
            }
        }
        return count;
    }
    
    //+------------------------------------------------------------------+
    //| Calcula el riesgo total actual en el mercado (%)                 |
    //+------------------------------------------------------------------+
    double GetTotalRiskInMarket() {
        double totalRisk = 0;
        
        for(int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0) {
                long magic = PositionGetInteger(POSITION_MAGIC);
                
                // Solo contar posiciones del SoS (magic >= 100001 && <= 100007)
                if(magic >= MAGIC_E1_RATE && magic <= MAGIC_E7_SCALP) {
                    double positionLots = PositionGetDouble(POSITION_VOLUME);
                    double sl = PositionGetDouble(POSITION_SL);
                    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                    
                    if(sl > 0) {
                        double slDistance = MathAbs(openPrice - sl);
                        double slPips = CalculatePips(m_symbol, slDistance);
                        
                        // Calcular riesgo aproximado
                        double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
                        double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
                        double positionRisk = (slPips * point * positionLots * tickValue) / 
                                             AccountInfoDouble(ACCOUNT_EQUITY) * 100.0;
                        
                        totalRisk += positionRisk;
                    }
                }
            }
        }
        
        return totalRisk;
    }
};

//+------------------------------------------------------------------+
