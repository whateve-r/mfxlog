//+------------------------------------------------------------------+
//| SoS_APIHandler.mqh - Gestión de APIs Externas                    |
//| Squad of Systems - Trading System                                |
//| Copyright 2025, SoS Trading                                       |
//+------------------------------------------------------------------+
#property copyright "SoS Trading System"
#property version   "1.00"
#property strict

#include "SoS_Commons.mqh"

//+------------------------------------------------------------------+
//| Clase APIHandler - Manejo de WebRequests a APIs Externas         |
//+------------------------------------------------------------------+
class APIHandler {
private:
    string m_fredApiKey;
    string m_alphaVantageKey;
    int m_timeout;
    
    // v2.4: Sistema de cache para FRED API
    struct FREDCacheEntry {
        string seriesId;
        string data;
        datetime timestamp;
    };
    
    FREDCacheEntry m_fredCache[];
    int m_fredCacheSize;
    int m_cacheExpirySeconds;  // Tiempo de vida del cache (default: 24h)
    
    //+------------------------------------------------------------------+
    //| Parser simple de JSON (extraer valor de una clave)               |
    //+------------------------------------------------------------------+
    string ExtractJSONValue(string json, string key) {
        string searchPattern = "\"" + key + "\":";
        int pos = StringFind(json, searchPattern);
        
        if(pos == -1) {
            searchPattern = "\"" + key + "\": ";
            pos = StringFind(json, searchPattern);
        }
        
        if(pos == -1) return "";
        
        pos += StringLen(searchPattern);
        
        // Saltar espacios
        while(StringGetCharacter(json, pos) == ' ') pos++;
        
        // Determinar si es string (empieza con ")
        bool isString = (StringGetCharacter(json, pos) == '"');
        if(isString) pos++; // Saltar comilla inicial
        
        // Extraer valor hasta la comilla de cierre o coma/corchete
        string value = "";
        char terminator = isString ? '"' : ',';
        
        while(pos < StringLen(json)) {
            char c = (char)StringGetCharacter(json, pos);
            
            if(c == terminator || c == '}' || c == ']') break;
            
            value += CharToString(c);
            pos++;
        }
        
        return value;
    }
    
public:
    //+------------------------------------------------------------------+
    //| Constructor                                                       |
    //+------------------------------------------------------------------+
    APIHandler() {
        m_fredApiKey = "";
        m_alphaVantageKey = "";
        m_timeout = 5000; // 5 segundos
        m_fredCacheSize = 0;
        m_cacheExpirySeconds = 86400;  // 24 horas
        ArrayResize(m_fredCache, 0);
    }
    
    //+------------------------------------------------------------------+
    //| Establece la API Key de FRED                                     |
    //+------------------------------------------------------------------+
    void SetFREDKey(string apiKey) {
        m_fredApiKey = apiKey;
    }
    
    //+------------------------------------------------------------------+
    //| Establece la API Key de Alpha Vantage                            |
    //+------------------------------------------------------------------+
    void SetAlphaVantageKey(string apiKey) {
        m_alphaVantageKey = apiKey;
    }
    
    //+------------------------------------------------------------------+
    //| Establece el timeout de las requests (ms)                        |
    //+------------------------------------------------------------------+
    void SetTimeout(int timeoutMs) {
        m_timeout = timeoutMs;
    }
    
    //+------------------------------------------------------------------+
    //| v2.4: Establece tiempo de expiración del cache (segundos)        |
    //+------------------------------------------------------------------+
    void SetCacheExpiry(int seconds) {
        m_cacheExpirySeconds = seconds;
    }
    
    //+------------------------------------------------------------------+
    //| v2.4: Buscar en cache de FRED                                    |
    //+------------------------------------------------------------------+
    string GetFromCache(string seriesId) {
        datetime now = TimeCurrent();
        
        for(int i = 0; i < m_fredCacheSize; i++) {
            if(m_fredCache[i].seriesId == seriesId) {
                // Verificar si el cache aún es válido
                if((now - m_fredCache[i].timestamp) < m_cacheExpirySeconds) {
                    Print("✅ FRED Cache HIT: ", seriesId, " (edad: ", 
                          (now - m_fredCache[i].timestamp)/3600, "h)");
                    return m_fredCache[i].data;
                } else {
                    Print("⚠️ FRED Cache EXPIRED: ", seriesId);
                    // Eliminar entrada expirada
                    for(int j = i; j < m_fredCacheSize - 1; j++) {
                        m_fredCache[j] = m_fredCache[j + 1];
                    }
                    m_fredCacheSize--;
                    ArrayResize(m_fredCache, m_fredCacheSize);
                    break;
                }
            }
        }
        
        return "";  // Cache miss
    }
    
    //+------------------------------------------------------------------+
    //| v2.4: Guardar en cache de FRED                                   |
    //+------------------------------------------------------------------+
    void SaveToCache(string seriesId, string data) {
        // Verificar si ya existe (actualizar)
        for(int i = 0; i < m_fredCacheSize; i++) {
            if(m_fredCache[i].seriesId == seriesId) {
                m_fredCache[i].data = data;
                m_fredCache[i].timestamp = TimeCurrent();
                Print("📝 FRED Cache UPDATED: ", seriesId);
                return;
            }
        }
        
        // Agregar nueva entrada
        ArrayResize(m_fredCache, m_fredCacheSize + 1);
        m_fredCache[m_fredCacheSize].seriesId = seriesId;
        m_fredCache[m_fredCacheSize].data = data;
        m_fredCache[m_fredCacheSize].timestamp = TimeCurrent();
        m_fredCacheSize++;
        
        Print("💾 FRED Cache SAVED: ", seriesId, " (Total cached: ", m_fredCacheSize, ")");
    }
    
    //+------------------------------------------------------------------+
    //| v2.4: Obtiene datos de FRED (CON CACHE)                          |
    //+------------------------------------------------------------------+
    string GetFREDData(string seriesId) {
        // Intentar obtener desde cache primero
        string cachedData = GetFromCache(seriesId);
        if(cachedData != "") {
            return cachedData;  // Cache hit - evitar request
        }
        
        if(m_fredApiKey == "") {
            Print("❌ Error: FRED API Key no configurada");
            return "";
        }
        
        // Construir URL
        string url = "https://api.stlouisfed.org/fred/series/observations?series_id=" + 
                     seriesId + 
                     "&api_key=" + m_fredApiKey + 
                     "&file_type=json&limit=1&sort_order=desc";
        
        Print("📡 FRED Request: ", seriesId, " (Cache MISS)");
        
        char post[], result[];
        string headers;
        
        int res = WebRequest("GET", url, NULL, NULL, m_timeout, post, 0, result, headers);
        
        if(res == -1) {
            int errorCode = GetLastError();
            Print("❌ FRED API Error: ", errorCode);
            
            if(errorCode == 4060) {
                Print("⚠️ WebRequest no habilitado. Ir a: Herramientas → Opciones → Expert Advisors");
                Print("   Agregar URL: https://api.stlouisfed.org");
            }
            
            return "";
        }
        
        string jsonResponse = CharArrayToString(result);
        Print("✅ FRED Response recibida (", StringLen(jsonResponse), " chars)");
        
        // Guardar en cache antes de retornar
        if(jsonResponse != "") {
            SaveToCache(seriesId, jsonResponse);
        }
        
        return jsonResponse;
    }
    
    //+------------------------------------------------------------------+
    //| Obtiene el último valor de una serie de FRED                     |
    //+------------------------------------------------------------------+
    double GetFREDValue(string seriesId) {
        string jsonResponse = GetFREDData(seriesId);
        if(jsonResponse == "") return 0;
        
        // Extraer el valor del JSON
        // Formato esperado: {"observations": [{"value": "4.25", ...}]}
        string valueStr = ExtractJSONValue(jsonResponse, "value");
        
        if(valueStr == "") {
            Print("❌ No se pudo extraer valor de FRED para ", seriesId);
            return 0;
        }
        
        double value = StringToDouble(valueStr);
        Print("📊 FRED ", seriesId, " = ", FormatDouble(value, 4));
        
        return value;
    }
    
    //+------------------------------------------------------------------+
    //| Calcula el spread entre dos series de FRED                       |
    //+------------------------------------------------------------------+
    double GetFREDSpread(string series1, string series2) {
        double value1 = GetFREDValue(series1);
        double value2 = GetFREDValue(series2);
        
        if(value1 == 0 || value2 == 0) {
            Print("❌ Error calculando spread: ", series1, "=", value1, ", ", series2, "=", value2);
            return 0;
        }
        
        double spread = value1 - value2;
        Print("📊 Spread ", series1, "-", series2, " = ", FormatDouble(spread, 4));
        
        return spread;
    }
    
    //+------------------------------------------------------------------+
    //| Obtiene el valor actual del VIX (Alpha Vantage)                  |
    //+------------------------------------------------------------------+
    double GetVIX() {
        if(m_alphaVantageKey == "") {
            Print("❌ Error: Alpha Vantage API Key no configurada");
            return -1;
        }
        
        // Construir URL para VIX
        string url = "https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=VIX&apikey=" + 
                     m_alphaVantageKey;
        
        Print("📡 Alpha Vantage Request: VIX");
        
        char post[], result[];
        string headers;
        
        int res = WebRequest("GET", url, NULL, NULL, m_timeout, post, 0, result, headers);
        
        if(res == -1) {
            int errorCode = GetLastError();
            Print("❌ Alpha Vantage API Error: ", errorCode);
            
            if(errorCode == 4060) {
                Print("⚠️ WebRequest no habilitado. Ir a: Herramientas → Opciones → Expert Advisors");
                Print("   Agregar URL: https://www.alphavantage.co");
            }
            
            return -1;
        }
        
        string jsonResponse = CharArrayToString(result);
        
        // Verificar si hay rate limit
        if(StringFind(jsonResponse, "rate limit") != -1 || 
           StringFind(jsonResponse, "API call frequency") != -1) {
            Print("⚠️ Alpha Vantage: Rate limit alcanzado");
            return -1;
        }
        
        // Extraer valor (campo "05. price")
        string priceStr = ExtractJSONValue(jsonResponse, "05. price");
        
        if(priceStr == "") {
            Print("❌ No se pudo extraer VIX de la respuesta");
            return -1;
        }
        
        double vix = StringToDouble(priceStr);
        Print("🌪️ VIX = ", FormatDouble(vix, 2));
        
        return vix;
    }
    
    //+------------------------------------------------------------------+
    //| Obtiene noticias recientes (Alpha Vantage News Sentiment)        |
    //+------------------------------------------------------------------+
    string GetNewsSentiment(string ticker) {
        if(m_alphaVantageKey == "") {
            Print("❌ Error: Alpha Vantage API Key no configurada");
            return "";
        }
        
        // Construir URL
        string url = "https://www.alphavantage.co/query?function=NEWS_SENTIMENT&tickers=" + 
                     ticker + 
                     "&apikey=" + m_alphaVantageKey +
                     "&limit=10";
        
        Print("📡 Alpha Vantage News Request: ", ticker);
        
        char post[], result[];
        string headers;
        
        int res = WebRequest("GET", url, NULL, NULL, m_timeout, post, 0, result, headers);
        
        if(res == -1) {
            Print("❌ News Sentiment API Error: ", GetLastError());
            return "";
        }
        
        string jsonResponse = CharArrayToString(result);
        
        // Verificar rate limit
        if(StringFind(jsonResponse, "rate limit") != -1) {
            Print("⚠️ Alpha Vantage: Rate limit alcanzado");
            return "";
        }
        
        Print("✅ News Sentiment recibido (", StringLen(jsonResponse), " chars)");
        
        return jsonResponse;
    }
    
    //+------------------------------------------------------------------+
    //| Extrae el sentiment score promedio de las noticias               |
    //+------------------------------------------------------------------+
    double ParseNewsSentimentScore(string jsonResponse) {
        if(jsonResponse == "") return 0;
        
        // Buscar "overall_sentiment_score"
        string scoreStr = ExtractJSONValue(jsonResponse, "overall_sentiment_score");
        
        if(scoreStr == "") {
            Print("❌ No se encontró overall_sentiment_score");
            return 0;
        }
        
        double score = StringToDouble(scoreStr);
        Print("📰 News Sentiment Score = ", FormatDouble(score, 3));
        
        return score;
    }
    
    //+------------------------------------------------------------------+
    //| Obtiene swap rates del símbolo                                   |
    //+------------------------------------------------------------------+
    double GetSwapLong(string symbol) {
        return SymbolInfoDouble(symbol, SYMBOL_SWAP_LONG);
    }
    
    double GetSwapShort(string symbol) {
        return SymbolInfoDouble(symbol, SYMBOL_SWAP_SHORT);
    }
    
    //+------------------------------------------------------------------+
    //| Calcula el diferencial de swap entre dos pares                   |
    //+------------------------------------------------------------------+
    double CalculateSwapDifferential(string symbol1, string symbol2) {
        double swap1_long = GetSwapLong(symbol1);
        double swap2_short = GetSwapShort(symbol2);
        
        double differential = swap1_long + MathAbs(swap2_short);
        
        Print("💱 Swap Differential: ", symbol1, "(long)=", FormatDouble(swap1_long, 2), 
              " + ", symbol2, "(short)=", FormatDouble(swap2_short, 2), 
              " = ", FormatDouble(differential, 2));
        
        return differential;
    }
    
    //+------------------------------------------------------------------+
    //| Test de conectividad a APIs                                      |
    //+------------------------------------------------------------------+
    bool TestAPIs() {
        Print("==================================================");
        Print("🔍 Testing API Connectivity...");
        Print("==================================================");
        
        bool allOk = true;
        
        // Test FRED
        if(m_fredApiKey != "") {
            Print("📡 Testing FRED API...");
            double testValue = GetFREDValue("DGS10");
            if(testValue > 0) {
                Print("✅ FRED API: OK (DGS10 = ", FormatDouble(testValue, 4), ")");
            } else {
                Print("❌ FRED API: FAIL");
                allOk = false;
            }
        } else {
            Print("⚠️ FRED API Key no configurada - SKIP");
        }
        
        // Test Alpha Vantage
        if(m_alphaVantageKey != "") {
            Print("📡 Testing Alpha Vantage API...");
            double vix = GetVIX();
            if(vix > 0) {
                Print("✅ Alpha Vantage API: OK (VIX = ", FormatDouble(vix, 2), ")");
            } else {
                Print("❌ Alpha Vantage API: FAIL");
                allOk = false;
            }
        } else {
            Print("⚠️ Alpha Vantage API Key no configurada - SKIP");
        }
        
        Print("==================================================");
        Print(allOk ? "✅ Todos los tests PASARON" : "❌ Algunos tests FALLARON");
        Print("==================================================");
        
        return allOk;
    }
};

//+------------------------------------------------------------------+
