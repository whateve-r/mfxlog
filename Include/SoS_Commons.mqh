//+------------------------------------------------------------------+
//| SoS_Commons.mqh - Constantes y Estructuras Compartidas           |
//| Squad of Systems - Trading System                                |
//| Copyright 2025, SoS Trading                                       |
//+------------------------------------------------------------------+
#property copyright "SoS Trading System"
#property version   "2.40"
#property strict

//+------------------------------------------------------------------+
//| v2.4: Log Levels para sistema de logging multinivel              |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL {
    LOG_LEVEL_DEBUG = 0,   // Todos los mensajes (verbose)
    LOG_LEVEL_INFO = 1,    // Información general
    LOG_LEVEL_WARNING = 2, // Advertencias
    LOG_LEVEL_ERROR = 3,   // Solo errores críticos
    LOG_LEVEL_NONE = 4     // Sin logs (solo para producción extrema)
};

// Variable global para controlar nivel de logging (ajustar según EA)
ENUM_LOG_LEVEL g_LogLevel = LOG_LEVEL_INFO;  // Default: INFO

//+------------------------------------------------------------------+
//| Magic Numbers del Sistema                                        |
//+------------------------------------------------------------------+
#define MAGIC_STORMGUARD  100000
#define MAGIC_E1_RATE     100001  // Mean Reversion on Interest Rate Spreads
#define MAGIC_E2_CARRY    100002  // Adaptive Carry Trade
#define MAGIC_E3_VWAP     100003  // Momentum Breakout with VWAP Filter
#define MAGIC_E4_VOL      100004  // Volatility Arbitrage Intraday
#define MAGIC_E5_ORB      100005  // Opening Range Breakout
#define MAGIC_E6_NEWS     100006  // News Sentiment
#define MAGIC_E7_SCALP    100007  // Inverse R:R Scalper

//+------------------------------------------------------------------+
//| GlobalVariable Keys (Comunicación Master-Slave)                  |
//+------------------------------------------------------------------+
#define GV_VIX_PANIC           "SoS_VIX_Panic"
#define GV_GLOBAL_DD           "SoS_GlobalDD"
#define GV_DAILY_DD            "SoS_DailyDD"
#define GV_EMERGENCY_STOP      "SoS_EmergencyStop"
#define GV_DISABLE_BREAKOUTS   "SoS_DisableBreakouts"
#define GV_INITIAL_BALANCE     "SoS_InitialBalance"
#define GV_DAILY_START_BALANCE "SoS_DailyStartBalance"

//+------------------------------------------------------------------+
//| Límites de Drawdown (en %)                                       |
//+------------------------------------------------------------------+
#define MAX_GLOBAL_DD  7.0   // Drawdown Global Máximo
#define MAX_DAILY_DD   4.5   // Drawdown Diario Máximo

//+------------------------------------------------------------------+
//| VIX Levels                                                        |
//+------------------------------------------------------------------+
#define VIX_PANIC_LEVEL      30.0  // VIX > 30: Desactivar breakouts
#define VIX_CARRY_DISABLE    25.0  // VIX > 25: E2 cierra posiciones

//+------------------------------------------------------------------+
//| Riesgo por Trade (en %)                                          |
//+------------------------------------------------------------------+
#define RISK_PER_TRADE_DEFAULT  0.5
#define RISK_PER_TRADE_MAX      1.0
#define RISK_PER_TRADE_MIN      0.25

//+------------------------------------------------------------------+
//| Estado del Régimen de Mercado                                    |
//+------------------------------------------------------------------+
enum MarketRegime {
    REGIME_UNKNOWN = 0,   // Desconocido
    REGIME_TRENDING = 1,  // Tendencial (ADX > 25)
    REGIME_RANGING = 2,   // Lateral (ADX < 20)
    REGIME_VOLATILE = 3,  // Alta volatilidad (ATR > promedio)
    REGIME_PANIC = 4      // Pánico (VIX > 30)
};

//+------------------------------------------------------------------+
//| Estado de un EA                                                  |
//+------------------------------------------------------------------+
enum EAStatus {
    EA_ACTIVE = 0,     // Activo y operando
    EA_DISABLED = 1,   // Desactivado por StormGuard
    EA_ERROR = 2       // Error crítico
};

//+------------------------------------------------------------------+
//| Estructura de Trade Log                                          |
//+------------------------------------------------------------------+
struct TradeLog {
    datetime   timestamp;      // Hora de la operación
    int        magic;          // Magic Number del EA
    string     ea_name;        // Nombre del EA
    string     symbol;         // Par operado
    int        type;           // ORDER_TYPE_BUY, ORDER_TYPE_SELL
    double     lots;           // Lotes
    double     entry_price;    // Precio de entrada
    double     sl;             // Stop Loss
    double     tp;             // Take Profit
    double     profit;         // Profit/Loss
    string     comment;        // Comentario adicional
};

//+------------------------------------------------------------------+
//| Colores para logs (opcional pero útil)                           |
//+------------------------------------------------------------------+
#define COLOR_SUCCESS  clrGreen
#define COLOR_WARNING  clrOrange
#define COLOR_ERROR    clrRed
#define COLOR_INFO     clrDodgerBlue

//+------------------------------------------------------------------+
//| Timeframes comunes                                               |
//+------------------------------------------------------------------+
#define TF_M1   PERIOD_M1
#define TF_M5   PERIOD_M5
#define TF_M15  PERIOD_M15
#define TF_M30  PERIOD_M30
#define TF_H1   PERIOD_H1
#define TF_H4   PERIOD_H4
#define TF_D1   PERIOD_D1

//+------------------------------------------------------------------+
//| Utility Functions                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Convierte Magic Number a nombre de EA                            |
//+------------------------------------------------------------------+
string MagicToEAName(int magic) {
    switch(magic) {
        case MAGIC_STORMGUARD: return "StormGuard";
        case MAGIC_E1_RATE:    return "E1_RateSpread";
        case MAGIC_E2_CARRY:   return "E2_CarryTrade";
        case MAGIC_E3_VWAP:    return "E3_VWAP_Breakout";
        case MAGIC_E4_VOL:     return "E4_VolArbitrage";
        case MAGIC_E5_ORB:     return "E5_ORB";
        case MAGIC_E6_NEWS:    return "E6_NewsSentiment";
        case MAGIC_E7_SCALP:   return "E7_Scalper";
        default:               return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| Verifica si un Magic Number es de breakout (E3, E5, E7)          |
//+------------------------------------------------------------------+
bool IsBreakoutEA(int magic) {
    return (magic == MAGIC_E3_VWAP || magic == MAGIC_E5_ORB || magic == MAGIC_E7_SCALP);
}

//+------------------------------------------------------------------+
//| Formatea un double para logging                                  |
//+------------------------------------------------------------------+
string FormatDouble(double value, int digits = 2) {
    return DoubleToString(value, digits);
}

//+------------------------------------------------------------------+
//| Calcula pips desde precio                                        |
//+------------------------------------------------------------------+
double CalculatePips(string symbol, double price_diff) {
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    // Para pares de 5 o 3 dígitos, 1 pip = 10 points
    double pip_multiplier = (digits == 5 || digits == 3) ? 10.0 : 1.0;
    
    return (price_diff / point) / pip_multiplier;
}

//+------------------------------------------------------------------+
//| v2.4: Valida y reinicializa un handle de indicador si es inválido|
//| Retorna: true si el handle es válido después de validación       |
//+------------------------------------------------------------------+
template<typename T>
bool ValidateHandle(int &handle, T init_func, string indicator_name) {
    // Si el handle ya es válido, retornar true
    if(handle != INVALID_HANDLE) {
        return true;
    }
    
    // Intentar reinicializar el handle
    Print("⚠️ Handle inválido para ", indicator_name, " - Reinicializando...");
    handle = init_func;
    
    if(handle == INVALID_HANDLE) {
        int error = GetLastError();
        Print("❌ ERROR: No se pudo reinicializar ", indicator_name, " | Error: ", error);
        return false;
    }
    
    Print("✅ Handle reinicializado exitosamente para ", indicator_name);
    return true;
}

//+------------------------------------------------------------------+
//| v2.4: Copia buffer con retry logic (3 intentos)                  |
//| Retorna: Número de datos copiados (-1 si todos los intentos fallan)|
//+------------------------------------------------------------------+
int SafeCopyBuffer(int indicator_handle, int buffer_num, int start_pos, int count, 
                   double &buffer[], int max_retries = 3) {
    int copied = -1;
    int retries = max_retries;
    
    while(retries > 0) {
        copied = CopyBuffer(indicator_handle, buffer_num, start_pos, count, buffer);
        
        if(copied > 0) {
            return copied;  // Éxito
        }
        
        // Error - esperar y reintentar
        int error = GetLastError();
        Print("⚠️ CopyBuffer falló (intento ", (max_retries - retries + 1), "/", max_retries, 
              ") | Error: ", error, " - Reintentando...");
        
        Sleep(100);  // Esperar 100ms antes de reintentar
        retries--;
    }
    
    // Todos los intentos fallaron
    Print("❌ ERROR: CopyBuffer falló después de ", max_retries, " intentos");
    return -1;
}

//+------------------------------------------------------------------+
//| v2.4: Sistema de Logging Multinivel                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Log DEBUG - Solo si g_LogLevel == DEBUG                          |
//+------------------------------------------------------------------+
void LogDebug(string message) {
    if(g_LogLevel <= LOG_LEVEL_DEBUG) {
        Print("🔍 DEBUG: ", message);
    }
}

//+------------------------------------------------------------------+
//| Log INFO - Información general del sistema                       |
//+------------------------------------------------------------------+
void LogInfo(string message) {
    if(g_LogLevel <= LOG_LEVEL_INFO) {
        Print("ℹ️ INFO: ", message);
    }
}

//+------------------------------------------------------------------+
//| Log WARNING - Advertencias (situaciones anómalas pero no críticas)|
//+------------------------------------------------------------------+
void LogWarning(string message) {
    if(g_LogLevel <= LOG_LEVEL_WARNING) {
        Print("⚠️ WARNING: ", message);
    }
}

//+------------------------------------------------------------------+
//| Log ERROR - Errores críticos que requieren atención              |
//+------------------------------------------------------------------+
void LogError(string message) {
    if(g_LogLevel <= LOG_LEVEL_ERROR) {
        Print("❌ ERROR: ", message);
    }
}

//+------------------------------------------------------------------+
//| Log con nivel personalizado                                      |
//+------------------------------------------------------------------+
void Log(ENUM_LOG_LEVEL level, string message) {
    if(g_LogLevel <= level) {
        string prefix = "";
        
        switch(level) {
            case LOG_LEVEL_DEBUG:   prefix = "🔍 DEBUG: ";   break;
            case LOG_LEVEL_INFO:    prefix = "ℹ️ INFO: ";    break;
            case LOG_LEVEL_WARNING: prefix = "⚠️ WARNING: "; break;
            case LOG_LEVEL_ERROR:   prefix = "❌ ERROR: ";   break;
        }
        
        Print(prefix, message);
    }
}

//+------------------------------------------------------------------+
//| Establecer nivel de logging global                               |
//+------------------------------------------------------------------+
void SetLogLevel(ENUM_LOG_LEVEL level) {
    g_LogLevel = level;
    Print("📝 Nivel de logging cambiado a: ", EnumToString(level));
}

//+------------------------------------------------------------------+
