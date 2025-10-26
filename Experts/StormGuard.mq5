//+------------------------------------------------------------------+
//| StormGuard.mq5 - Master EA del Sistema Squad of Systems          |
//| Squad of Systems - Trading System                                |
//| Copyright 2025, SoS Trading                                       |
//+------------------------------------------------------------------+
#property copyright "SoS Trading System"
#property link      "https://github.com/sos-trading"
#property version   "1.00"
#property description "Master EA que supervisa y controla todos los EAs esclavos"
#property description "Responsabilidades: Monitoreo DD, Circuit Breaker, Filtro VIX, Comunicación Master-Slave"

#include <Trade\Trade.mqh>
#include "..\Include\SoS_Commons.mqh"
#include "..\Include\SoS_GlobalComms.mqh"
#include "..\Include\SoS_RiskManager.mqh"
#include "..\Include\SoS_APIHandler.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== RISK MANAGEMENT ==="
input double InpMaxGlobalDD = 7.0;           // Drawdown Global Máximo (%)
input double InpMaxDailyDD = 4.5;            // Drawdown Diario Máximo (%)
input double InpRiskPerTrade = 0.5;          // Riesgo por Trade (%)

input group "=== VIX MONITORING ==="
input bool InpEnableVIX = true;              // Activar monitoreo VIX
input int InpVIXUpdateInterval = 300;        // Intervalo actualización VIX (segundos)
input double InpVIXPanicLevel = 30.0;        // VIX Nivel de Pánico
input string InpAlphaVantageKey = "";        // Alpha Vantage API Key

input group "=== NOTIFICATIONS ==="
input bool InpEnableEmailAlerts = false;     // Activar alertas por Email
input bool InpEnablePushAlerts = true;       // Activar alertas Push
input bool InpEnableLogging = true;          // Logging detallado

input group "=== DASHBOARD ==="
input bool InpShowDashboard = true;          // Mostrar Dashboard en pantalla
input int InpDashboardX = 20;                // Dashboard posición X
input int InpDashboardY = 20;                // Dashboard posición Y
input color InpDashboardColor = clrWhite;    // Color del Dashboard

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;
RiskManager riskMgr;
APIHandler api;

double g_initialBalance = 0;
double g_dailyStartBalance = 0;
datetime g_lastResetTime = 0;
datetime g_lastVIXUpdate = 0;
bool g_emergencyStopActive = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
    Print("==================================================");
    Print("🚀 StormGuard Master EA v1.0 - INICIANDO");
    Print("==================================================");
    
    // Configurar trade object
    trade.SetExpertMagicNumber(MAGIC_STORMGUARD);
    trade.SetDeviationInPoints(50);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    // Inicializar balance tracking
    g_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    g_dailyStartBalance = g_initialBalance;
    g_lastResetTime = TimeCurrent();
    g_lastVIXUpdate = 0;
    g_emergencyStopActive = false;
    
    // Configurar API Handler
    if(InpEnableVIX && InpAlphaVantageKey != "") {
        api.SetAlphaVantageKey(InpAlphaVantageKey);
        Print("✅ Alpha Vantage API configurada");
    } else {
        Print("⚠️ VIX Monitoring desactivado (API Key no configurada)");
    }
    
    // Inicializar sistema de comunicación
    GlobalComms::InitializeSystem();
    GlobalComms::SetInitialBalance(g_initialBalance);
    GlobalComms::SetDailyStartBalance(g_dailyStartBalance);
    
    // Timer para chequeos periódicos (cada 60 segundos)
    EventSetTimer(60);
    
    // Crear dashboard si está habilitado
    if(InpShowDashboard) {
        CreateDashboard();
    }
    
    Print("==================================================");
    Print("✅ StormGuard LISTO - Protegiendo el portafolio");
    Print("💰 Balance Inicial: $", FormatDouble(g_initialBalance, 2));
    Print("📊 Max Global DD: ", InpMaxGlobalDD, "%");
    Print("📉 Max Daily DD: ", InpMaxDailyDD, "%");
    Print("==================================================");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    EventKillTimer();
    
    // Limpiar dashboard
    if(InpShowDashboard) {
        DeleteDashboard();
    }
    
    Print("==================================================");
    Print("🛑 StormGuard Master EA - DETENIDO");
    Print("Razón: ", GetUninitReasonText(reason));
    Print("==================================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
    // 1. Verificación de Drawdown en TIEMPO REAL (crítico)
    CheckDrawdown();
    
    // 2. Actualizar GlobalVariables para comunicación con esclavos
    UpdateGlobalVariables();
    
    // 3. Actualizar Dashboard
    if(InpShowDashboard) {
        UpdateDashboard();
    }
}

//+------------------------------------------------------------------+
//| Timer function (cada 60 segundos)                                 |
//+------------------------------------------------------------------+
void OnTimer() {
    // 1. Actualizar VIX (cada X segundos según configuración)
    if(InpEnableVIX) {
        UpdateVIX();
    }
    
    // 2. Reset diario del DD (a las 00:00 UTC)
    ResetDailyDD();
    
    // 3. Log de estado del portafolio
    if(InpEnableLogging) {
        LogPortfolioStatus();
    }
}

//+------------------------------------------------------------------+
//| Verificación de Drawdown Crítico (CIRCUIT BREAKER)               |
//+------------------------------------------------------------------+
void CheckDrawdown() {
    // Calcular drawdowns actuales
    double globalDD = riskMgr.GetCurrentGlobalDD();
    double dailyDD = riskMgr.GetCurrentDailyDD();
    
    // Actualizar GlobalVariables
    GlobalComms::SetGlobalDD(globalDD);
    GlobalComms::SetDailyDD(dailyDD);
    
    // CIRCUIT BREAKER: Verificar si se exceden los límites
    if(globalDD >= InpMaxGlobalDD || dailyDD >= InpMaxDailyDD) {
        
        if(!g_emergencyStopActive) {
            g_emergencyStopActive = true;
            
            Print("==================================================");
            Print("🚨 CIRCUIT BREAKER ACTIVADO!");
            Print("📊 Global DD: ", FormatDouble(globalDD, 2), "% (Límite: ", InpMaxGlobalDD, "%)");
            Print("📉 Daily DD: ", FormatDouble(dailyDD, 2), "% (Límite: ", InpMaxDailyDD, "%)");
            Print("==================================================");
            
            // Activar Emergency Stop
            GlobalComms::TriggerEmergencyStop();
            
            // Cerrar TODAS las posiciones del SoS
            CloseAllPositions();
            
            // Enviar alertas
            SendAlert("🚨 CIRCUIT BREAKER ACTIVADO - DD Crítico alcanzado");
            
            Print("⚠️ TODAS LAS POSICIONES CERRADAS - Sistema en STOP");
        }
    }
}

//+------------------------------------------------------------------+
//| Cerrar todas las posiciones del portafolio SoS                   |
//+------------------------------------------------------------------+
void CloseAllPositions() {
    int closedCount = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0) {
            long magic = PositionGetInteger(POSITION_MAGIC);
            
            // Verificar si es de algún EA del SoS (magic 100001-100007)
            if(magic >= MAGIC_E1_RATE && magic <= MAGIC_E7_SCALP) {
                string symbol = PositionGetString(POSITION_SYMBOL);
                
                if(trade.PositionClose(ticket)) {
                    closedCount++;
                    Print("✅ Posición cerrada: Ticket=", ticket, 
                          " | EA=", MagicToEAName((int)magic), 
                          " | Symbol=", symbol);
                } else {
                    Print("❌ Error cerrando posición: Ticket=", ticket, 
                          " | Error=", GetLastError());
                }
            }
        }
    }
    
    Print("==================================================");
    Print("🔒 Total posiciones cerradas: ", closedCount);
    Print("==================================================");
}

//+------------------------------------------------------------------+
//| Actualizar VIX desde Alpha Vantage (con fallback a MarketWatch)  |
//+------------------------------------------------------------------+
void UpdateVIX() {
    // Verificar si ha pasado suficiente tiempo desde la última actualización
    if(TimeCurrent() - g_lastVIXUpdate < InpVIXUpdateInterval) {
        return; // Aún no es momento de actualizar
    }
    
    Print("📡 Actualizando VIX...");
    
    double vix = 0;
    
    // MÉTODO 1: Intentar obtener VIX desde Market Watch (símbolo directo)
    // Ventaja: Sin latencia, sin rate limits, datos en tiempo real
    if(SymbolSelect("VIX", true)) {  // Asegurar que el símbolo esté en Market Watch
        vix = SymbolInfoDouble("VIX", SYMBOL_BID);
        if(vix > 0 && vix < 100) {  // Validar rango razonable (VIX típico: 10-80)
            Print("✅ VIX desde Market Watch: ", FormatDouble(vix, 2));
        } else {
            vix = 0;  // Valor inválido
        }
    }
    
    // MÉTODO 2: Fallback a Alpha Vantage API si Market Watch falló
    if(vix <= 0 && InpAlphaVantageKey != "") {
        Print("⚠️ VIX no disponible en Market Watch - Intentando API...");
        vix = api.GetVIX();
        
        if(vix > 0) {
            Print("✅ VIX desde Alpha Vantage API: ", FormatDouble(vix, 2));
        }
    }
    
    // MÉTODO 3: Si ambos fallan, usar último valor conocido (no actualizar)
    if(vix <= 0) {
        vix = GlobalComms::GetVIX();  // Recuperar último valor válido
        Print("⚠️ Error obteniendo VIX - Usando valor anterior: ", FormatDouble(vix, 2));
        
        // Si no hay valor anterior, usar VIX neutro (20)
        if(vix <= 0) {
            vix = 20.0;
            Print("⚠️ No hay VIX previo - Usando VIX neutro: 20.0");
        }
        
        return;  // No actualizar timestamp si usamos valor antiguo
    }
    
    // Actualizar solo si obtuvimos valor válido
    g_lastVIXUpdate = TimeCurrent();
    // Actualizar solo si obtuvimos valor válido
    g_lastVIXUpdate = TimeCurrent();
    
    // Publicar VIX en GlobalVariables
    GlobalComms::SetVIX(vix);
    
    // Evaluar si hay que desactivar breakouts
    if(vix >= InpVIXPanicLevel) {
        GlobalComms::DisableBreakouts(true);
        
        // Alertar si es la primera vez que entra en pánico
        static bool wasInPanic = false;
        if(!wasInPanic) {
            SendAlert("⚠️ VIX en PÁNICO: " + DoubleToString(vix, 2) + " - Breakouts desactivados");
            wasInPanic = true;
        }
    } else {
        GlobalComms::DisableBreakouts(false);
        
        // Reset del flag de pánico
        static bool wasInPanic = false;
        wasInPanic = false;
    }
}

//+------------------------------------------------------------------+
//| Reset del Drawdown Diario (a las 00:00 UTC)                      |
//+------------------------------------------------------------------+
void ResetDailyDD() {
    MqlDateTime currentTime, lastResetDateTime;
    TimeToStruct(TimeCurrent(), currentTime);
    TimeToStruct(g_lastResetTime, lastResetDateTime);
    
    // Verificar si es un nuevo día
    if(currentTime.day != lastResetDateTime.day) {
        double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        
        g_dailyStartBalance = currentEquity;
        g_lastResetTime = TimeCurrent();
        
        GlobalComms::SetDailyStartBalance(g_dailyStartBalance);
        GlobalComms::SetDailyDD(0);
        
        // Desactivar Emergency Stop si estaba activo (nuevo día = nueva oportunidad)
        if(g_emergencyStopActive) {
            g_emergencyStopActive = false;
            GlobalComms::ClearEmergencyStop();
            Print("✅ Emergency Stop CLEARED - Nuevo día de trading");
        }
        
        Print("==================================================");
        Print("🌅 NUEVO DÍA DE TRADING");
        Print("🔄 Drawdown Diario reseteado");
        Print("💰 Balance inicio del día: $", FormatDouble(g_dailyStartBalance, 2));
        Print("==================================================");
    }
}

//+------------------------------------------------------------------+
//| v2.4: Log de estado del portafolio CON DESGLOSE POR EA           |
//+------------------------------------------------------------------+
void LogPortfolioStatus() {
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double floatingPL = equity - balance;
    int totalPositions = PositionsTotal();
    
    // Contar posiciones por EA
    int countE1 = 0, countE2 = 0, countE3 = 0, countE4 = 0, countE5 = 0, countE6 = 0, countE7 = 0;
    double plE1 = 0, plE2 = 0, plE3 = 0, plE4 = 0, plE5 = 0, plE6 = 0, plE7 = 0;
    
    for(int i = 0; i < totalPositions; i++) {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        
        long magic = PositionGetInteger(POSITION_MAGIC);
        double profit = PositionGetDouble(POSITION_PROFIT) + 
                       PositionGetDouble(POSITION_SWAP);
        
        switch(magic) {
            case MAGIC_E1_RATE:  countE1++; plE1 += profit; break;
            case MAGIC_E2_CARRY: countE2++; plE2 += profit; break;
            case MAGIC_E3_VWAP:  countE3++; plE3 += profit; break;
            case MAGIC_E4_VOL:   countE4++; plE4 += profit; break;
            case MAGIC_E5_ORB:   countE5++; plE5 += profit; break;
            case MAGIC_E6_NEWS:  countE6++; plE6 += profit; break;
            case MAGIC_E7_SCALP: countE7++; plE7 += profit; break;
        }
    }
    
    int sosPositions = countE1 + countE2 + countE3 + countE4 + countE5 + countE6 + countE7;
    
    Print("==================== PORTFOLIO STATUS v2.4 ====================");
    Print("💰 Balance: $", FormatDouble(balance, 2), " | 📈 Equity: $", FormatDouble(equity, 2));
    Print("💵 Floating P/L: $", FormatDouble(floatingPL, 2));
    Print("📊 Global DD: ", FormatDouble(GlobalComms::GetGlobalDD(), 2), "% (Max: ", InpMaxGlobalDD, "%)");
    Print("📉 Daily DD: ", FormatDouble(GlobalComms::GetDailyDD(), 2), "% (Max: ", InpMaxDailyDD, "%)");
    Print("🌪️ VIX: ", FormatDouble(GlobalComms::GetVIX(), 2), 
          " | 🔒 Breakouts: ", GlobalComms::AreBreakoutsDisabled() ? "DISABLED" : "ENABLED");
    Print("🚨 Emergency Stop: ", g_emergencyStopActive ? "ACTIVE ❌" : "INACTIVE ✅");
    Print("----------------------------------------------------------");
    Print("📍 POSICIONES POR EA (Total: ", sosPositions, "):");
    if(countE1 > 0) Print("   E1_Rate:     ", countE1, " pos | P/L: $", FormatDouble(plE1, 2));
    if(countE2 > 0) Print("   E2_Carry:    ", countE2, " pos | P/L: $", FormatDouble(plE2, 2));
    if(countE3 > 0) Print("   E3_VWAP:     ", countE3, " pos | P/L: $", FormatDouble(plE3, 2));
    if(countE4 > 0) Print("   E4_Vol:      ", countE4, " pos | P/L: $", FormatDouble(plE4, 2));
    if(countE5 > 0) Print("   E5_ORB:      ", countE5, " pos | P/L: $", FormatDouble(plE5, 2));
    if(countE6 > 0) Print("   E6_News:     ", countE6, " pos | P/L: $", FormatDouble(plE6, 2));
    if(countE7 > 0) Print("   E7_Scalp:    ", countE7, " pos | P/L: $", FormatDouble(plE7, 2));
    if(sosPositions == 0) Print("   (Sin posiciones activas)");
    Print("===========================================================");
}

//+------------------------------------------------------------------+
//| Actualizar GlobalVariables                                        |
//+------------------------------------------------------------------+
void UpdateGlobalVariables() {
    // Las GlobalVariables ya se actualizan en CheckDrawdown() y UpdateVIX()
    // Esta función es un placeholder para lógica adicional futura
}

//+------------------------------------------------------------------+
//| Enviar alertas (Email/Push)                                       |
//+------------------------------------------------------------------+
void SendAlert(string message) {
    if(InpEnablePushAlerts) {
        SendNotification("StormGuard: " + message);
    }
    
    if(InpEnableEmailAlerts) {
        // SendMail requiere configuración SMTP en MT5
        // Tools → Options → Email
        SendMail("StormGuard Alert", message);
    }
}

//+------------------------------------------------------------------+
//| Crear Dashboard en pantalla                                       |
//+------------------------------------------------------------------+
void CreateDashboard() {
    int x = InpDashboardX;
    int y = InpDashboardY;
    int lineHeight = 18;
    
    CreateLabel("SoS_Title", x, y, "=== STORMGUARD v1.0 ===", clrYellow, 10, "Arial Bold");
    CreateLabel("SoS_Balance", x, y + lineHeight * 1, "Balance: $0.00", InpDashboardColor);
    CreateLabel("SoS_Equity", x, y + lineHeight * 2, "Equity: $0.00", InpDashboardColor);
    CreateLabel("SoS_GlobalDD", x, y + lineHeight * 3, "Global DD: 0.00%", InpDashboardColor);
    CreateLabel("SoS_DailyDD", x, y + lineHeight * 4, "Daily DD: 0.00%", InpDashboardColor);
    CreateLabel("SoS_VIX", x, y + lineHeight * 5, "VIX: 0.00", InpDashboardColor);
    CreateLabel("SoS_Status", x, y + lineHeight * 6, "Status: ACTIVE", clrLime);
}

//+------------------------------------------------------------------+
//| Actualizar Dashboard                                              |
//+------------------------------------------------------------------+
void UpdateDashboard() {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double globalDD = GlobalComms::GetGlobalDD();
    double dailyDD = GlobalComms::GetDailyDD();
    double vix = GlobalComms::GetVIX();
    
    ObjectSetString(0, "SoS_Balance", OBJPROP_TEXT, "Balance: $" + FormatDouble(balance, 2));
    ObjectSetString(0, "SoS_Equity", OBJPROP_TEXT, "Equity: $" + FormatDouble(equity, 2));
    
    // Colorear DD según nivel de riesgo
    color ddColor = (globalDD < 3) ? clrLime : (globalDD < 5) ? clrYellow : clrRed;
    ObjectSetString(0, "SoS_GlobalDD", OBJPROP_TEXT, "Global DD: " + FormatDouble(globalDD, 2) + "%");
    ObjectSetInteger(0, "SoS_GlobalDD", OBJPROP_COLOR, ddColor);
    
    color dailyColor = (dailyDD < 2) ? clrLime : (dailyDD < 3.5) ? clrYellow : clrRed;
    ObjectSetString(0, "SoS_DailyDD", OBJPROP_TEXT, "Daily DD: " + FormatDouble(dailyDD, 2) + "%");
    ObjectSetInteger(0, "SoS_DailyDD", OBJPROP_COLOR, dailyColor);
    
    ObjectSetString(0, "SoS_VIX", OBJPROP_TEXT, "VIX: " + FormatDouble(vix, 2));
    
    string status = g_emergencyStopActive ? "EMERGENCY STOP" : "ACTIVE";
    color statusColor = g_emergencyStopActive ? clrRed : clrLime;
    ObjectSetString(0, "SoS_Status", OBJPROP_TEXT, "Status: " + status);
    ObjectSetInteger(0, "SoS_Status", OBJPROP_COLOR, statusColor);
    
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Eliminar Dashboard                                                |
//+------------------------------------------------------------------+
void DeleteDashboard() {
    ObjectDelete(0, "SoS_Title");
    ObjectDelete(0, "SoS_Balance");
    ObjectDelete(0, "SoS_Equity");
    ObjectDelete(0, "SoS_GlobalDD");
    ObjectDelete(0, "SoS_DailyDD");
    ObjectDelete(0, "SoS_VIX");
    ObjectDelete(0, "SoS_Status");
}

//+------------------------------------------------------------------+
//| Helper: Crear Label en pantalla                                  |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int fontSize = 9, string font = "Arial") {
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
    ObjectSetString(0, name, OBJPROP_FONT, font);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| Helper: Obtener texto de razón de deinicialización               |
//+------------------------------------------------------------------+
string GetUninitReasonText(int reason) {
    switch(reason) {
        case REASON_PROGRAM: return "Cambio de programa";
        case REASON_REMOVE: return "EA removido del gráfico";
        case REASON_RECOMPILE: return "EA recompilado";
        case REASON_CHARTCHANGE: return "Cambio de símbolo/período";
        case REASON_CHARTCLOSE: return "Gráfico cerrado";
        case REASON_PARAMETERS: return "Cambio de parámetros";
        case REASON_ACCOUNT: return "Cambio de cuenta";
        case REASON_TEMPLATE: return "Nueva plantilla aplicada";
        case REASON_INITFAILED: return "Inicialización fallida";
        case REASON_CLOSE: return "Terminal cerrado";
        default: return "Razón desconocida (" + IntegerToString(reason) + ")";
    }
}

//+------------------------------------------------------------------+
