//+------------------------------------------------------------------+
//| SoS_TradeHistory.mqh - Análisis de Histórico de Trades           |
//| Squad of Systems - Trading System v2.4                           |
//| Copyright 2025, SoS Trading                                       |
//+------------------------------------------------------------------+
#property copyright "SoS Trading System"
#property version   "2.40"
#property strict

//+------------------------------------------------------------------+
//| Estructura para almacenar métricas de trading                    |
//+------------------------------------------------------------------+
struct TradeMetrics {
    int    totalTrades;      // Total de operaciones
    int    winningTrades;    // Trades ganadores
    int    losingTrades;     // Trades perdedores
    double totalProfit;      // Profit total
    double totalLoss;        // Loss total
    double winRate;          // % de aciertos
    double avgWin;           // Promedio de ganancias
    double avgLoss;          // Promedio de pérdidas (positivo)
    double profitFactor;     // Profit Factor (total profit / total loss)
    double kellyFraction;    // Kelly Criterion calculado
    double maxDD;            // Máximo Drawdown observado
    datetime lastUpdate;     // Última actualización
};

//+------------------------------------------------------------------+
//| Clase TradeHistory - Análisis de histórico de trades             |
//+------------------------------------------------------------------+
class CTradeHistory {
private:
    int            m_magicNumber;      // Magic Number del EA
    TradeMetrics   m_metrics;          // Métricas calculadas
    int            m_minTrades;        // Mínimo de trades para cálculo confiable
    
    //+------------------------------------------------------------------+
    //| Calcula métricas desde el historial de deals                     |
    //+------------------------------------------------------------------+
    void CalculateMetricsFromHistory() {
        // Reset
        m_metrics.totalTrades = 0;
        m_metrics.winningTrades = 0;
        m_metrics.losingTrades = 0;
        m_metrics.totalProfit = 0;
        m_metrics.totalLoss = 0;
        m_metrics.maxDD = 0;
        
        // Obtener historial de deals
        datetime from = TimeCurrent() - (365 * 86400);  // Último año
        datetime to = TimeCurrent();
        
        HistorySelect(from, to);
        
        int totalDeals = HistoryDealsTotal();
        double runningProfit = 0;
        double peak = 0;
        
        for(int i = 0; i < totalDeals; i++) {
            ulong ticket = HistoryDealGetTicket(i);
            if(ticket == 0) continue;
            
            // Filtrar por magic number
            if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != m_magicNumber) continue;
            
            // Solo contar operaciones ENTRY_OUT (cierre de posición)
            if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
            
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
            double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            
            double netProfit = profit + swap + commission;
            
            if(netProfit > 0) {
                m_metrics.winningTrades++;
                m_metrics.totalProfit += netProfit;
            } else if(netProfit < 0) {
                m_metrics.losingTrades++;
                m_metrics.totalLoss += MathAbs(netProfit);
            }
            
            m_metrics.totalTrades++;
            
            // Calcular Drawdown
            runningProfit += netProfit;
            if(runningProfit > peak) {
                peak = runningProfit;
            }
            double currentDD = peak - runningProfit;
            if(currentDD > m_metrics.maxDD) {
                m_metrics.maxDD = currentDD;
            }
        }
        
        // Calcular ratios
        if(m_metrics.totalTrades > 0) {
            m_metrics.winRate = (double)m_metrics.winningTrades / m_metrics.totalTrades;
            
            if(m_metrics.winningTrades > 0) {
                m_metrics.avgWin = m_metrics.totalProfit / m_metrics.winningTrades;
            }
            
            if(m_metrics.losingTrades > 0) {
                m_metrics.avgLoss = m_metrics.totalLoss / m_metrics.losingTrades;
            }
            
            if(m_metrics.totalLoss > 0) {
                m_metrics.profitFactor = m_metrics.totalProfit / m_metrics.totalLoss;
            }
            
            // Kelly Criterion: f* = (p * b - q) / b
            // Donde: p = winRate, q = (1-p), b = avgWin/avgLoss
            if(m_metrics.avgLoss > 0 && m_metrics.totalTrades >= m_minTrades) {
                double b = m_metrics.avgWin / m_metrics.avgLoss;
                double p = m_metrics.winRate;
                double q = 1.0 - p;
                
                m_metrics.kellyFraction = (p * b - q) / b;
                
                // Limitar Kelly a valores razonables (máx 25%)
                if(m_metrics.kellyFraction > 0.25) m_metrics.kellyFraction = 0.25;
                if(m_metrics.kellyFraction < 0) m_metrics.kellyFraction = 0;  // No operar si Kelly negativo
            }
        }
        
        m_metrics.lastUpdate = TimeCurrent();
    }
    
public:
    //+------------------------------------------------------------------+
    //| Constructor                                                       |
    //+------------------------------------------------------------------+
    CTradeHistory(int magicNumber, int minTrades = 30) {
        m_magicNumber = magicNumber;
        m_minTrades = minTrades;
        ZeroMemory(m_metrics);
    }
    
    //+------------------------------------------------------------------+
    //| Actualizar métricas (llamar cada X horas)                        |
    //+------------------------------------------------------------------+
    void Update() {
        CalculateMetricsFromHistory();
        
        Print("📊 TradeHistory actualizado para Magic ", m_magicNumber, ":");
        Print("   Trades totales: ", m_metrics.totalTrades, " (W:", m_metrics.winningTrades, " L:", m_metrics.losingTrades, ")");
        Print("   Win Rate: ", FormatDouble(m_metrics.winRate * 100, 2), "%");
        Print("   Avg Win: $", FormatDouble(m_metrics.avgWin, 2), " | Avg Loss: $", FormatDouble(m_metrics.avgLoss, 2));
        Print("   Profit Factor: ", FormatDouble(m_metrics.profitFactor, 2));
        Print("   Kelly Fraction: ", FormatDouble(m_metrics.kellyFraction * 100, 2), "%");
        Print("   Max DD: $", FormatDouble(m_metrics.maxDD, 2));
    }
    
    //+------------------------------------------------------------------+
    //| Obtener Kelly Fraction calculado                                 |
    //+------------------------------------------------------------------+
    double GetKellyFraction() {
        // Solo retornar Kelly si hay suficientes trades
        if(m_metrics.totalTrades < m_minTrades) {
            return 0.01;  // Usar 1% conservador si no hay datos
        }
        
        // Aplicar Half-Kelly (50% del Kelly óptimo) para seguridad
        return m_metrics.kellyFraction * 0.5;
    }
    
    //+------------------------------------------------------------------+
    //| Obtener Win Rate                                                 |
    //+------------------------------------------------------------------+
    double GetWinRate() {
        return m_metrics.winRate;
    }
    
    //+------------------------------------------------------------------+
    //| Obtener Profit Factor                                            |
    //+------------------------------------------------------------------+
    double GetProfitFactor() {
        return m_metrics.profitFactor;
    }
    
    //+------------------------------------------------------------------+
    //| Obtener Total de Trades                                          |
    //+------------------------------------------------------------------+
    int GetTotalTrades() {
        return m_metrics.totalTrades;
    }
    
    //+------------------------------------------------------------------+
    //| Verificar si hay suficientes datos para Kelly                    |
    //+------------------------------------------------------------------+
    bool HasSufficientData() {
        return m_metrics.totalTrades >= m_minTrades;
    }
    
    //+------------------------------------------------------------------+
    //| Obtener métricas completas                                       |
    //+------------------------------------------------------------------+
    TradeMetrics GetMetrics() {
        return m_metrics;
    }
    
    //+------------------------------------------------------------------+
    //| Verificar si el sistema está en buen estado                      |
    //+------------------------------------------------------------------+
    bool IsHealthy() {
        if(m_metrics.totalTrades < m_minTrades) return true;  // Muy pocos datos para juzgar
        
        // Sistema saludable si: Win Rate > 40% Y Profit Factor > 1.2
        return (m_metrics.winRate > 0.40 && m_metrics.profitFactor > 1.2);
    }
};
//+------------------------------------------------------------------+
