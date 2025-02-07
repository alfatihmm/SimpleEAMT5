//+------------------------------------------------------------------+
//|                                                    GridCCI_MACD.mq5 |
//|                        Copyright 2025, MetaQuotes Software Corp.   |
//|                                             https://www.mql5.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// Input parameters
input int      CCI_Period = 14;        // Period untuk indikator CCI
input int      MACD_Fast = 12;         // MACD Fast EMA Period
input int      MACD_Slow = 26;         // MACD Slow EMA Period
input int      MACD_Signal = 9;        // MACD Signal Period
input int      Grid_Distance = 250;     // Jarak antar posisi dalam poin
input double   Volume = 0.01;           // Volume trade
input double   TakeProfit = 0;          // Take profit dalam poin (0 untuk abaikan)
input double   StopLoss = 0;            // Stop loss dalam poin (0 untuk abaikan)
input int      JumlahGrid = 3;          // Jumlah Grid yang dibuat

// Global variables
int handle_cci;
int handle_macd;
MqlTradeRequest request;
MqlTradeResult result;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    // Inisialisasi handle indikator CCI
    handle_cci = iCCI(_Symbol, PERIOD_CURRENT, CCI_Period, PRICE_CLOSE);
    
    // Inisialisasi handle indikator MACD
    handle_macd = iMACD(_Symbol, PERIOD_CURRENT, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
    
    if(handle_cci == INVALID_HANDLE || handle_macd == INVALID_HANDLE)
    {
        Print("Error creating indicators");
        return(INIT_FAILED);
    }
    
    // Inisialisasi trade request
    ZeroMemory(request);
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = Volume;
    request.deviation = 2;
    request.magic = 123456;
    request.type_filling = ORDER_FILLING_FOK;
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(handle_cci != INVALID_HANDLE)
        IndicatorRelease(handle_cci);
    if(handle_macd != INVALID_HANDLE)
        IndicatorRelease(handle_macd);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    double cci[];
    double macd_main[];
    double macd_signal[];
    
    ArraySetAsSeries(cci, true);
    ArraySetAsSeries(macd_main, true);
    ArraySetAsSeries(macd_signal, true);
    
    // Ambil nilai CCI dan MACD
    if(CopyBuffer(handle_cci, 0, 0, 2, cci) < 2)
        return;
    if(CopyBuffer(handle_macd, 0, 0, 2, macd_main) < 2)
        return;
    if(CopyBuffer(handle_macd, 1, 0, 2, macd_signal) < 2)
        return;
        
    // Cek total posisi terbuka
    if(PositionsTotal() > 0)
        return;
        
    bool macdCrossUp = (macd_main[1] <= macd_signal[1] && macd_main[0] > macd_signal[0]);
    
    // Kondisi untuk membuka posisi long
    if(cci[0] < -100 && macdCrossUp) // Sinyal beli
    {
        OpenGridPositions();
    }
}

//+------------------------------------------------------------------+
//| Fungsi untuk membuka posisi grid                                  |
//+------------------------------------------------------------------+
void OpenGridPositions()
{
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double minStop = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
    
    for(int i = 0; i < JumlahGrid; i++)
    {
        request.type = ORDER_TYPE_BUY;
        request.price = NormalizeDouble(price, _Digits);
        
        // Set Take Profit
        if(TakeProfit > 0)
        {
            request.tp = NormalizeDouble(price + (TakeProfit * point), _Digits);
            
            if(MathAbs(request.tp - price) < minStop)
                request.tp = 0;
        }
        else
            request.tp = 0;
            
        // Set Stop Loss
        if(StopLoss > 0)
        {
            request.sl = NormalizeDouble(price - (StopLoss * point), _Digits);
                        
            if(MathAbs(request.sl - price) < minStop)
                request.sl = 0;
        }
        else
            request.sl = 0;
            
        if(!OrderSend(request, result))
        {
            PrintFormat("OrderSend error %d", GetLastError());
            continue;
        }
        
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            PrintFormat("Order #%d executed: Buy %g %s at %g", 
                       result.order,
                       request.volume, 
                       _Symbol, 
                       result.price);
        }
        else
        {
            PrintFormat("Order failed, retcode=%u", result.retcode);
        }
        
        price += Grid_Distance * point; // Hanya menambah harga untuk grid buy
        Sleep(100);
    }
}