//+------------------------------------------------------------------+
//| test_risk_manager.mq5 - Unit Tests para RiskManager              |
//| Squad of Systems - Trading System v2.4                           |
//| Copyright 2025, SoS Trading                                       |
//+------------------------------------------------------------------+
#property copyright "SoS Trading System"
#property version   "2.40"
#property strict
#property script_show_inputs

#include "../Include/SoS_RiskManager.mqh"
#include "../Include/SoS_GlobalComms.mqh"

input group "=== TEST CONFIGURATION ==="
input bool InpRunAllTests = true;              // Ejecutar todos los tests
input bool InpVerboseOutput = true;            // Mostrar detalles en cada test

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
int g_testsPassed = 0;
int g_testsFailed = 0;
int g_totalTests = 0;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart() {
    Print("==================================================");
    Print("🧪 INICIANDO TESTS UNITARIOS - RiskManager v2.4");
    Print("==================================================");
    
    // Inicializar sistema de GlobalVariables
    GlobalComms::InitializeSystem();
    
    // Ejecutar batería de tests
    if(InpRunAllTests) {
        Test_CalculateLotSize();
        Test_CalculateKellyLots();
        Test_NormalizeLots();
        Test_GetCurrentGlobalDD();
        Test_GetCurrentDailyDD();
        Test_CanOpenNewPosition();
        Test_CalculateATRbasedSL();
        Test_GetOpenPositions();
        Test_GetTotalRiskInMarket();
        Test_CalculateScalperLots();
    }
    
    // Resumen final
    Print("==================================================");
    Print("📊 RESUMEN DE TESTS:");
    Print("✅ Tests APROBADOS: ", g_testsPassed, " / ", g_totalTests);
    Print("❌ Tests FALLIDOS: ", g_testsFailed, " / ", g_totalTests);
    Print("📈 Tasa de éxito: ", FormatDouble((double)g_testsPassed/g_totalTests*100, 1), "%");
    Print("==================================================");
    
    if(g_testsFailed == 0) {
        Print("🎉 TODOS LOS TESTS PASARON - SISTEMA VALIDADO");
    } else {
        Print("⚠️ HAY TESTS FALLIDOS - REVISAR IMPLEMENTACIÓN");
    }
}

//+------------------------------------------------------------------+
//| Test 1: CalculateLotSize - Validar cálculo de lotes              |
//+------------------------------------------------------------------+
void Test_CalculateLotSize() {
    StartTest("CalculateLotSize");
    
    RiskManager riskMgr(_Symbol, 100001);
    
    // Test Case 1: Riesgo 1% con SL 50 pips
    double lots1 = riskMgr.CalculateLotSize(1.0, 50);
    AssertTrue(lots1 > 0, "Lote calculado debe ser mayor a 0");
    AssertTrue(lots1 >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), 
               "Lote debe ser >= MinLot");
    
    // Test Case 2: Riesgo 2% debe ser el doble que 1%
    double lots2 = riskMgr.CalculateLotSize(2.0, 50);
    AssertTrue(MathAbs(lots2 - lots1*2) < 0.05, 
               "2% riesgo debe ser ~doble que 1% riesgo");
    
    // Test Case 3: Mayor SL = menor lotaje
    double lots3 = riskMgr.CalculateLotSize(1.0, 100);
    AssertTrue(lots3 < lots1, 
               "100 pips SL debe dar menor lotaje que 50 pips");
    
    // Test Case 4: Parámetros inválidos (SL negativo)
    double lotsInvalid = riskMgr.CalculateLotSize(1.0, -10);
    AssertEqual(lotsInvalid, 0.0, 
                "SL negativo debe retornar 0");
    
    // Test Case 5: Riesgo fuera de rango
    double lotsOutOfRange = riskMgr.CalculateLotSize(15.0, 50);  // > MAX_RISK
    AssertEqual(lotsOutOfRange, 0.0, 
                "Riesgo >5% debe retornar 0");
    
    EndTest();
}

//+------------------------------------------------------------------+
//| Test 2: CalculateKellyLots - Validar Kelly Criterion             |
//+------------------------------------------------------------------+
void Test_CalculateKellyLots() {
    StartTest("CalculateKellyLots");
    
    RiskManager riskMgr(_Symbol, 100001);
    
    // Test Case 1: Sistema ganador (60% WR, b=1.5)
    double kellyGood = riskMgr.CalculateKellyLots(0.60, 150, 100, 50, 0.25);
    AssertTrue(kellyGood > 0, "Sistema ganador debe dar lotaje > 0");
    
    // Test Case 2: Sistema perdedor (40% WR, b=1.0)
    double kellyBad = riskMgr.CalculateKellyLots(0.40, 100, 100, 50, 0.25);
    AssertTrue(kellyBad >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), 
               "Kelly negativo debe usar RISK_MIN como fallback");
    
    // Test Case 3: Parámetros inválidos
    double kellyInvalid = riskMgr.CalculateKellyLots(1.5, 150, 100, 50, 0.25);  // WR > 1
    AssertTrue(kellyInvalid > 0, "Parámetros inválidos deben usar default risk");
    
    EndTest();
}

//+------------------------------------------------------------------+
//| Test 3: NormalizeLots - Validar normalización de lotes           |
//+------------------------------------------------------------------+
void Test_NormalizeLots() {
    StartTest("NormalizeLots");
    
    RiskManager riskMgr(_Symbol, 100001);
    
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    // Test Case 1: Lotaje menor al mínimo
    double normalized1 = riskMgr.NormalizeLots(0.001);
    AssertEqual(normalized1, minLot, "Lotaje < MinLot debe normalizarse a MinLot");
    
    // Test Case 2: Lotaje mayor al máximo
    double normalized2 = riskMgr.NormalizeLots(1000.0);
    AssertEqual(normalized2, maxLot, "Lotaje > MaxLot debe normalizarse a MaxLot");
    
    // Test Case 3: Lotaje válido debe mantenerse en steps
    double validLot = minLot + (lotStep * 3);
    double normalized3 = riskMgr.NormalizeLots(validLot);
    AssertEqual(normalized3, validLot, "Lotaje válido debe mantenerse");
    
    EndTest();
}

//+------------------------------------------------------------------+
//| Test 4: GetCurrentGlobalDD - Validar cálculo de DD Global        |
//+------------------------------------------------------------------+
void Test_GetCurrentGlobalDD() {
    StartTest("GetCurrentGlobalDD");
    
    RiskManager riskMgr(_Symbol, 100001);
    
    // Simular balance inicial mayor a equity actual
    double initialBalance = 10000.0;
    double currentEquity = 9500.0;  // -5% DD
    
    GlobalComms::SetInitialBalance(initialBalance);
    
    // Mock: No podemos cambiar AccountEquity en test, así que solo validamos que funcione
    double dd = riskMgr.GetCurrentGlobalDD();
    AssertTrue(dd >= 0, "DD Global debe ser >= 0");
    
    EndTest();
}

//+------------------------------------------------------------------+
//| Test 5: GetCurrentDailyDD - Validar cálculo de DD Diario         |
//+------------------------------------------------------------------+
void Test_GetCurrentDailyDD() {
    StartTest("GetCurrentDailyDD");
    
    RiskManager riskMgr(_Symbol, 100001);
    
    double dailyStart = 10000.0;
    GlobalComms::SetDailyStartBalance(dailyStart);
    
    double dd = riskMgr.GetCurrentDailyDD();
    AssertTrue(dd >= 0, "DD Diario debe ser >= 0");
    
    EndTest();
}

//+------------------------------------------------------------------+
//| Test 6: CanOpenNewPosition - Validar límites de DD               |
//+------------------------------------------------------------------+
void Test_CanOpenNewPosition() {
    StartTest("CanOpenNewPosition");
    
    RiskManager riskMgr(_Symbol, 100001);
    
    // Test Case 1: Sin DD adicional, siempre debería poder abrir
    bool canOpen1 = riskMgr.CanOpenNewPosition(0);
    AssertTrue(canOpen1, "Sin DD adicional debe permitir trading");
    
    // Test Case 2: Con DD adicional razonable (1%)
    bool canOpen2 = riskMgr.CanOpenNewPosition(1.0);
    AssertTrue(canOpen2, "1% DD adicional debe permitir trading");
    
    // Test Case 3: Simular DD cercano al límite
    GlobalComms::SetGlobalDD(4.8);  // Cerca del límite de 5%
    bool canOpen3 = riskMgr.CanOpenNewPosition(0.5);
    AssertFalse(canOpen3, "DD 4.8% + 0.5% >= 5% debe bloquear trading");
    
    // Limpiar
    GlobalComms::SetGlobalDD(0);
    
    EndTest();
}

//+------------------------------------------------------------------+
//| Test 7: CalculateATRbasedSL - Validar SL basado en ATR           |
//+------------------------------------------------------------------+
void Test_CalculateATRbasedSL() {
    StartTest("CalculateATRbasedSL");
    
    RiskManager riskMgr(_Symbol, 100001);
    
    double slPips = riskMgr.CalculateATRbasedSL(PERIOD_M15, 2.0);
    
    // ATR-based SL debe ser razonable (entre 10 y 200 pips)
    AssertTrue(slPips >= 10, "ATR SL debe ser >= 10 pips");
    AssertTrue(slPips <= 200, "ATR SL debe ser <= 200 pips");
    
    EndTest();
}

//+------------------------------------------------------------------+
//| Test 8: GetOpenPositions - Validar conteo de posiciones          |
//+------------------------------------------------------------------+
void Test_GetOpenPositions() {
    StartTest("GetOpenPositions");
    
    RiskManager riskMgr(_Symbol, 100001);
    
    int count = riskMgr.GetOpenPositions(100001);
    AssertTrue(count >= 0, "Conteo de posiciones debe ser >= 0");
    
    EndTest();
}

//+------------------------------------------------------------------+
//| Test 9: GetTotalRiskInMarket - Validar riesgo total              |
//+------------------------------------------------------------------+
void Test_GetTotalRiskInMarket() {
    StartTest("GetTotalRiskInMarket");
    
    RiskManager riskMgr(_Symbol, 100001);
    
    double totalRisk = riskMgr.GetTotalRiskInMarket();
    AssertTrue(totalRisk >= 0, "Riesgo total debe ser >= 0");
    AssertTrue(totalRisk <= 25.0, "Riesgo total debe ser <= 25% (límite razonable)");
    
    EndTest();
}

//+------------------------------------------------------------------+
//| Test 10: CalculateScalperLots - Validar lotaje agresivo E7       |
//+------------------------------------------------------------------+
void Test_CalculateScalperLots() {
    StartTest("CalculateScalperLots");
    
    RiskManager riskMgr(_Symbol, 100007);  // E7_Scalper
    
    double scalperLots = riskMgr.CalculateScalperLots(15);  // 15 pips SL
    
    AssertTrue(scalperLots > 0, "Scalper lots debe ser > 0");
    AssertTrue(scalperLots >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), 
               "Scalper lots debe ser >= MinLot");
    
    EndTest();
}

//+------------------------------------------------------------------+
//| UTILIDADES DE TEST                                                |
//+------------------------------------------------------------------+

void StartTest(string testName) {
    g_totalTests++;
    if(InpVerboseOutput) {
        Print("");
        Print("▶️ TEST #", g_totalTests, ": ", testName);
    }
}

void EndTest() {
    if(InpVerboseOutput) {
        Print("✅ Test completado");
    }
}

void AssertTrue(bool condition, string message) {
    if(condition) {
        g_testsPassed++;
        if(InpVerboseOutput) Print("  ✅ PASS: ", message);
    } else {
        g_testsFailed++;
        Print("  ❌ FAIL: ", message);
    }
}

void AssertFalse(bool condition, string message) {
    AssertTrue(!condition, message);
}

void AssertEqual(double value1, double value2, string message) {
    bool equal = MathAbs(value1 - value2) < 0.0001;
    if(equal) {
        g_testsPassed++;
        if(InpVerboseOutput) Print("  ✅ PASS: ", message, " (", value1, " == ", value2, ")");
    } else {
        g_testsFailed++;
        Print("  ❌ FAIL: ", message, " (Expected: ", value2, ", Got: ", value1, ")");
    }
}

//+------------------------------------------------------------------+
