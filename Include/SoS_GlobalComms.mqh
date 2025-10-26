//+------------------------------------------------------------------+
//| SoS_GlobalComms.mqh - Capa de comunicación Master-Slave          |
//| Squad of Systems - Trading System v2.4                           |
//| Copyright 2025, SoS Trading                                       |
//+------------------------------------------------------------------+
#property copyright "SoS Trading System"
#property version   "2.40"
#property strict

#include "SoS_Commons.mqh"

//+------------------------------------------------------------------+
//| Clase GlobalComms - Comunicación entre StormGuard y EAs Esclavas |
//+------------------------------------------------------------------+
class GlobalComms {
public:
    
    //+------------------------------------------------------------------+
    //| MÉTODOS PARA STORMGUARD (MASTER)                                 |
    //+------------------------------------------------------------------+
    
    //+------------------------------------------------------------------+
    //| v2.4: Establece el valor actual del VIX (ATOMIC)                 |
    //+------------------------------------------------------------------+
    static void SetVIX(double vix_value) {
        // Usar GlobalVariableSetOnCondition para writes atómicos
        double currentValue = GlobalVariableGet(GV_VIX_PANIC);
        
        // Intentar hasta 3 veces si hay race condition
        int attempts = 0;
        while(attempts < 3) {
            if(GlobalVariableSetOnCondition(GV_VIX_PANIC, vix_value, currentValue)) {
                LogDebug("VIX actualizado atómicamente: " + FormatDouble(vix_value, 2));
                return;  // Éxito
            }
            
            // Falló - otro proceso modificó la variable
            currentValue = GlobalVariableGet(GV_VIX_PANIC);
            attempts++;
            Sleep(10);  // Esperar 10ms antes de reintentar
        }
        
        // Fallback: usar Set normal si falló atomicidad
        GlobalVariableSet(GV_VIX_PANIC, vix_value);
        LogWarning("VIX actualizado sin atomicidad (race condition detectada)");
    }
    
    //+------------------------------------------------------------------+
    //| v2.4: Establece el Drawdown Global (%) - ATOMIC                  |
    //+------------------------------------------------------------------+
    static void SetGlobalDD(double dd_percent) {
        double currentValue = GlobalVariableGet(GV_GLOBAL_DD);
        
        if(!GlobalVariableSetOnCondition(GV_GLOBAL_DD, dd_percent, currentValue)) {
            // Race condition - usar set directo
            GlobalVariableSet(GV_GLOBAL_DD, dd_percent);
        }
    }
    
    //+------------------------------------------------------------------+
    //| v2.4: Establece el Drawdown Diario (%) - ATOMIC                  |
    //+------------------------------------------------------------------+
    static void SetDailyDD(double dd_percent) {
        double currentValue = GlobalVariableGet(GV_DAILY_DD);
        
        if(!GlobalVariableSetOnCondition(GV_DAILY_DD, dd_percent, currentValue)) {
            GlobalVariableSet(GV_DAILY_DD, dd_percent);
        }
    }
    
    //+------------------------------------------------------------------+
    //| Activa el Emergency Stop (cierra todas las posiciones)           |
    //+------------------------------------------------------------------+
    static void TriggerEmergencyStop() {
        GlobalVariableSet(GV_EMERGENCY_STOP, 1);
        Print("🚨 EMERGENCY STOP TRIGGERED BY STORMGUARD");
        SendNotification("🚨 SoS: EMERGENCY STOP ACTIVADO - Circuit Breaker");
    }
    
    //+------------------------------------------------------------------+
    //| Desactiva el Emergency Stop                                      |
    //+------------------------------------------------------------------+
    static void ClearEmergencyStop() {
        GlobalVariableSet(GV_EMERGENCY_STOP, 0);
        Print("✅ Emergency Stop CLEARED");
    }
    
    //+------------------------------------------------------------------+
    //| Desactiva/Activa los EAs de Breakout (E3, E5, E7)                |
    //+------------------------------------------------------------------+
    static void DisableBreakouts(bool disable) {
        GlobalVariableSet(GV_DISABLE_BREAKOUTS, disable ? 1 : 0);
        if(disable) {
            Print("⚠️ Breakouts DISABLED (VIX > ", VIX_PANIC_LEVEL, ")");
        } else {
            Print("✅ Breakouts ENABLED (VIX normal)");
        }
    }
    
    //+------------------------------------------------------------------+
    //| Establece el Balance Inicial del sistema                         |
    //+------------------------------------------------------------------+
    static void SetInitialBalance(double balance) {
        GlobalVariableSet(GV_INITIAL_BALANCE, balance);
        Print("💰 Balance inicial establecido: ", FormatDouble(balance, 2));
    }
    
    //+------------------------------------------------------------------+
    //| Establece el Balance Inicial del día                             |
    //+------------------------------------------------------------------+
    static void SetDailyStartBalance(double balance) {
        GlobalVariableSet(GV_DAILY_START_BALANCE, balance);
        Print("🌅 Balance inicio del día: ", FormatDouble(balance, 2));
    }
    
    //+------------------------------------------------------------------+
    //| MÉTODOS PARA EAs ESCLAVAS (SLAVES)                               |
    //+------------------------------------------------------------------+
    
    //+------------------------------------------------------------------+
    //| Obtiene el valor actual del VIX                                  |
    //+------------------------------------------------------------------+
    static double GetVIX() {
        if(!GlobalVariableCheck(GV_VIX_PANIC)) return 0;
        return GlobalVariableGet(GV_VIX_PANIC);
    }
    
    //+------------------------------------------------------------------+
    //| Obtiene el Drawdown Global actual (%)                            |
    //+------------------------------------------------------------------+
    static double GetGlobalDD() {
        if(!GlobalVariableCheck(GV_GLOBAL_DD)) return 0;
        return GlobalVariableGet(GV_GLOBAL_DD);
    }
    
    //+------------------------------------------------------------------+
    //| Obtiene el Drawdown Diario actual (%)                            |
    //+------------------------------------------------------------------+
    static double GetDailyDD() {
        if(!GlobalVariableCheck(GV_DAILY_DD)) return 0;
        return GlobalVariableGet(GV_DAILY_DD);
    }
    
    //+------------------------------------------------------------------+
    //| Verifica si el Emergency Stop está activo                        |
    //+------------------------------------------------------------------+
    static bool IsEmergencyStop() {
        if(!GlobalVariableCheck(GV_EMERGENCY_STOP)) return false;
        return (GlobalVariableGet(GV_EMERGENCY_STOP) == 1);
    }
    
    //+------------------------------------------------------------------+
    //| Verifica si los Breakouts están deshabilitados                   |
    //+------------------------------------------------------------------+
    static bool AreBreakoutsDisabled() {
        if(!GlobalVariableCheck(GV_DISABLE_BREAKOUTS)) return false;
        return (GlobalVariableGet(GV_DISABLE_BREAKOUTS) == 1);
    }
    
    //+------------------------------------------------------------------+
    //| Obtiene el Balance Inicial del sistema                           |
    //+------------------------------------------------------------------+
    static double GetInitialBalance() {
        if(!GlobalVariableCheck(GV_INITIAL_BALANCE)) 
            return AccountInfoDouble(ACCOUNT_BALANCE);
        return GlobalVariableGet(GV_INITIAL_BALANCE);
    }
    
    //+------------------------------------------------------------------+
    //| Obtiene el Balance Inicial del día                               |
    //+------------------------------------------------------------------+
    static double GetDailyStartBalance() {
        if(!GlobalVariableCheck(GV_DAILY_START_BALANCE)) 
            return AccountInfoDouble(ACCOUNT_BALANCE);
        return GlobalVariableGet(GV_DAILY_START_BALANCE);
    }
    
    //+------------------------------------------------------------------+
    //| MÉTODO DE SEGURIDAD PARA TODAS LAS EAs                           |
    //+------------------------------------------------------------------+
    
    //+------------------------------------------------------------------+
    //| Verifica si un EA puede operar (según magic number)              |
    //+------------------------------------------------------------------+
    static bool CanTrade(int magic) {
        // Check 1: Emergency Stop
        if(IsEmergencyStop()) {
            Print("❌ [", MagicToEAName(magic), "] Trading bloqueado: EMERGENCY STOP activo");
            return false;
        }
        
        // Check 2: v2.4 - Circuit Breaker por EA (pausa temporal)
        if(IsEAPaused(magic)) {
            // No imprimir cada tick - solo cuando se consulta por primera vez
            return false;
        }
        
        // Check 3: Breakouts deshabilitados (solo para E3, E5, E7)
        if(AreBreakoutsDisabled() && IsBreakoutEA(magic)) {
            Print("⚠️ [", MagicToEAName(magic), "] Trading bloqueado: Breakouts deshabilitados (VIX alto)");
            return false;
        }
        
        // Check 4: VIX > 25 y es Carry Trade (E2)
        double vix = GetVIX();
        if(magic == MAGIC_E2_CARRY && vix > VIX_CARRY_DISABLE) {
            Print("⚠️ [E2_CarryTrade] Trading bloqueado: VIX > ", VIX_CARRY_DISABLE, " (VIX=", vix, ")");
            return false;
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Verifica si un EA debe cerrar posiciones (lógica específica)     |
    //+------------------------------------------------------------------+
    static bool ShouldClosePositions(int magic) {
        // E2 (Carry Trade): Cerrar si VIX > 25
        if(magic == MAGIC_E2_CARRY) {
            double vix = GetVIX();
            if(vix > VIX_CARRY_DISABLE) {
                Print("⚠️ [E2_CarryTrade] Cerrando posiciones: VIX = ", vix);
                return true;
            }
        }
        
        // E3, E5, E7 (Breakouts): Cerrar si breakouts están deshabilitados
        if(IsBreakoutEA(magic) && AreBreakoutsDisabled()) {
            Print("⚠️ [", MagicToEAName(magic), "] Cerrando posiciones: Breakouts deshabilitados");
            return true;
        }
        
        return false;
    }
    
    //+------------------------------------------------------------------+
    //| INICIALIZACIÓN DEL SISTEMA                                       |
    //+------------------------------------------------------------------+
    
    //+------------------------------------------------------------------+
    //| Inicializa todas las GlobalVariables del sistema                 |
    //+------------------------------------------------------------------+
    static void InitializeSystem() {
        double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
        
        GlobalVariableSet(GV_VIX_PANIC, 0);
        GlobalVariableSet(GV_GLOBAL_DD, 0);
        GlobalVariableSet(GV_DAILY_DD, 0);
        GlobalVariableSet(GV_EMERGENCY_STOP, 0);
        GlobalVariableSet(GV_DISABLE_BREAKOUTS, 0);
        GlobalVariableSet(GV_INITIAL_BALANCE, current_balance);
        GlobalVariableSet(GV_DAILY_START_BALANCE, current_balance);
        
        Print("==================================================");
        Print("✅ Sistema SoS inicializado correctamente");
        Print("💰 Balance inicial: ", FormatDouble(current_balance, 2));
        Print("📊 Max Global DD: ", MAX_GLOBAL_DD, "%");
        Print("📉 Max Daily DD: ", MAX_DAILY_DD, "%");
        Print("==================================================");
    }
    
    //+------------------------------------------------------------------+
    //| Log del estado actual del sistema                                |
    //+------------------------------------------------------------------+
    static void LogSystemStatus() {
        Print("================== SoS SYSTEM STATUS ==================");
        Print("💰 Balance: ", FormatDouble(AccountInfoDouble(ACCOUNT_BALANCE), 2));
        Print("📈 Equity: ", FormatDouble(AccountInfoDouble(ACCOUNT_EQUITY), 2));
        Print("📊 Global DD: ", FormatDouble(GetGlobalDD(), 2), "%");
        Print("📉 Daily DD: ", FormatDouble(GetDailyDD(), 2), "%");
        Print("🌪️ VIX: ", FormatDouble(GetVIX(), 2));
        Print("🔒 Breakouts: ", AreBreakoutsDisabled() ? "DISABLED" : "ENABLED");
        Print("🚨 Emergency Stop: ", IsEmergencyStop() ? "ACTIVE" : "INACTIVE");
        Print("======================================================");
    }
    
    //+------------------------------------------------------------------+
    //| v2.4: CIRCUIT BREAKER POR EA (Loss Streak Protection)            |
    //+------------------------------------------------------------------+
    
    //+------------------------------------------------------------------+
    //| Incrementa contador de pérdidas consecutivas para un EA          |
    //+------------------------------------------------------------------+
    static void IncrementLossStreak(int magic) {
        string varName = "SoS_LossStreak_" + IntegerToString(magic);
        
        double currentStreak = 0;
        if(GlobalVariableCheck(varName)) {
            currentStreak = GlobalVariableGet(varName);
        }
        
        currentStreak++;
        GlobalVariableSet(varName, currentStreak);
        
        Print("📉 [", MagicToEAName(magic), "] Loss Streak: ", (int)currentStreak);
        
        // Si alcanza 5 pérdidas consecutivas, pausar EA por 1 hora
        if(currentStreak >= 5) {
            PauseEA(magic, 3600);  // 3600 segundos = 1 hora
        }
    }
    
    //+------------------------------------------------------------------+
    //| Resetea contador de pérdidas consecutivas (después de un win)    |
    //+------------------------------------------------------------------+
    static void ResetLossStreak(int magic) {
        string varName = "SoS_LossStreak_" + IntegerToString(magic);
        GlobalVariableSet(varName, 0);
        Print("✅ [", MagicToEAName(magic), "] Loss Streak reseteado");
    }
    
    //+------------------------------------------------------------------+
    //| Obtiene el número de pérdidas consecutivas de un EA              |
    //+------------------------------------------------------------------+
    static int GetLossStreak(int magic) {
        string varName = "SoS_LossStreak_" + IntegerToString(magic);
        if(!GlobalVariableCheck(varName)) return 0;
        return (int)GlobalVariableGet(varName);
    }
    
    //+------------------------------------------------------------------+
    //| Pausa un EA por X segundos (circuit breaker temporal)            |
    //+------------------------------------------------------------------+
    static void PauseEA(int magic, int durationSeconds) {
        string varName = "SoS_PauseUntil_" + IntegerToString(magic);
        datetime pauseUntil = TimeCurrent() + durationSeconds;
        
        GlobalVariableSet(varName, (double)pauseUntil);
        
        int hours = durationSeconds / 3600;
        int minutes = (durationSeconds % 3600) / 60;
        
        Print("⏸️ [", MagicToEAName(magic), "] PAUSADO por ", hours, "h ", minutes, "min");
        Print("⏰ Se reanudará a las: ", TimeToString(pauseUntil, TIME_DATE|TIME_MINUTES));
        
        // Notificar a usuario si configurado
        string msg = "⏸️ SoS: " + MagicToEAName(magic) + " pausado por " + 
                     IntegerToString(hours) + "h " + IntegerToString(minutes) + "min (Loss Streak >= 5)";
        SendNotification(msg);
    }
    
    //+------------------------------------------------------------------+
    //| Verifica si un EA está pausado (circuit breaker activo)          |
    //+------------------------------------------------------------------+
    static bool IsEAPaused(int magic) {
        string varName = "SoS_PauseUntil_" + IntegerToString(magic);
        
        if(!GlobalVariableCheck(varName)) return false;
        
        datetime pauseUntil = (datetime)GlobalVariableGet(varName);
        datetime now = TimeCurrent();
        
        if(now < pauseUntil) {
            int minutesLeft = (int)((pauseUntil - now) / 60);
            Print("⏸️ [", MagicToEAName(magic), "] PAUSADO - Quedan ", minutesLeft, " minutos");
            return true;
        } else {
            // Pausa expirada - limpiar variable
            GlobalVariableDel(varName);
            Print("▶️ [", MagicToEAName(magic), "] Pausa expirada - EA reanudado");
            return false;
        }
    }
};

//+------------------------------------------------------------------+
