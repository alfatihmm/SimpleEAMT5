//+------------------------------------------------------------------+
//|                                                    GridMA.mq5      |
//|                        Copyright 2025, MetaQuotes Software Corp.   |
//|                                             https://www.mql5.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// Input parameters
input int      MA_Period = 20;         // MA Period
input ENUM_MA_METHOD MA_Method = MODE_SMA; // MA Method
input int      Grid_Distance = 250;     // Jarak antar posisi dalam poin
input double   Volume = 0.01;           // Volume trade
input double   TakeProfit = 0;          // Take profit dalam poin (0 untuk abaikan)
input double   StopLoss = 0;            // Stop loss dalam poin (0 untuk abaikan)
input int      JumlahGrid = 3;          // Jumlah Grid yang dibuka
input int      ConfirmationBars = 2;    // Jumlah bar konfirmasi
input int      IDmagic = 123456;         // Magic Number ID

// Global variables
int handle_ma;
MqlTradeRequest request;
MqlTradeResult result;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{    
    // Inisialisasi handle indikator MA
    handle_ma = iMA(_Symbol, PERIOD_CURRENT, MA_Period, 0, MA_Method, PRICE_CLOSE);
    
    if(handle_ma == INVALID_HANDLE)
    {
        Print("Error creating MA indicator");
        return(INIT_FAILED);
    }
    
    // Validasi parameter konfirmasi
    if(ConfirmationBars < 1)
    {
        Print("Confirmation bars harus lebih besar dari 0");
        return(INIT_PARAMETERS_INCORRECT);
    }
    
    // Inisialisasi trade request
    ZeroMemory(request);
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = Volume;
    request.deviation = 2;
    request.magic = IDmagic;
    request.type_filling = ORDER_FILLING_FOK;
    
    Print("Expert Advisor GridMA diinisialisasi");
    Print("MA Period: ", MA_Period);
    Print("Grid Distance: ", Grid_Distance);
    Print("Confirmation Bars: ", ConfirmationBars);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(handle_ma != INVALID_HANDLE)
        IndicatorRelease(handle_ma);
    Print("Expert Advisor GridMA dihentikan");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    double ma[];
    double close[];
    
    ArraySetAsSeries(ma, true);
    ArraySetAsSeries(close, true);
    
    // Ambil nilai MA dan harga untuk konfirmasi
    int bars_needed = ConfirmationBars + 2; // +2 untuk bar saat ini dan sebelumnya
    
    if(CopyBuffer(handle_ma, 0, 0, bars_needed, ma) < bars_needed)
        return;
    if(CopyClose(_Symbol, PERIOD_CURRENT, 0, bars_needed, close) < bars_needed)
        return;
        
    // Cek total posisi terbuka
    if(PositionsTotal() > 0)
    {
        ManageOpenPositions();
        return;
    }
    
    // Variabel untuk menghitung berapa bar yang sudah di atas MA
    int barsAboveMA = 0;
    bool foundCrossing = false;
    
    // Hitung berapa bar berturut-turut yang berada di atas MA
    for(int i = 0; i < bars_needed; i++)
    {
        if(close[i] > ma[i])
        {
            barsAboveMA++;
            
            // Cek apakah bar sebelumnya di bawah MA (crossing point)
            if(i < bars_needed-1 && close[i+1] <= ma[i+1])
            {
                foundCrossing = true;
                break;
            }
        }
        else
        {
            break; // Keluar dari loop jika menemukan bar di bawah MA
        }
    }
    
    // Buka posisi hanya jika:
    // 1. Ditemukan crossing point
    // 2. Jumlah bar di atas MA sama dengan jumlah konfirmasi yang diinginkan
    // 3. Bar saat ini masih di atas MA
    if(foundCrossing && barsAboveMA >= ConfirmationBars && close[0] > ma[0])
    {
        Print("Crossing terdeteksi dan terkonfirmasi setelah ", ConfirmationBars, " bar");
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
        
        price += Grid_Distance * point;
        Sleep(100);
    }
}

//+------------------------------------------------------------------+
//| Fungsi untuk mengelola posisi terbuka                            |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
    // Fungsi ini bisa digunakan untuk mengelola posisi yang sudah terbuka
    // Misalnya untuk trailing stop atau menutup posisi berdasarkan kondisi tertentu
    
    double ma[];
    ArraySetAsSeries(ma, true);
    
    if(CopyBuffer(handle_ma, 0, 0, 1, ma) < 1)
        return;
        
    // Anda bisa menambahkan logika manajemen posisi di sini
}