//+------------------------------------------------------------------+
//|                                                   GridMultiInd.mq5  |
//|                        Copyright 2025, MetaQuotes Software Corp.   |
//|                                             https://www.mql5.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict


input group "Grid Parameter"
// Grid Parameters
input int      Grid_Distance = 250;     // Grid distance in points
input double   Volume = 0.01;           // Trade volume
input double   TakeProfit = 0;          // Take profit in points (0 to disable)
input double   StopLoss = 0;            // Stop loss in points (0 to disable)
input int      JumlahGrid = 3;          // Number of grids

input group "CCI Parameters"
// CCI Parameters
input bool     Use_CCI = true;          // Use CCI Indicator
input int      CCI_Period = 14;         // CCI Period
input int      CCI_Oversold = 100;      // CCI Oversold level

input group "RSI Parameters"
// RSI Parameters
input bool     Use_RSI = false;         // Use RSI Indicator
input int      RSI_Period = 14;         // RSI Period
input int      RSI_Oversold = 30;       // RSI Oversold level

input group "Stochastic Parameters"
// Stochastic Parameters
input bool     Use_Stochastic = false;  // Use Stochastic Indicator
input int      Stoch_K_Period = 5;      // Stochastic %K period
input int      Stoch_D_Period = 3;      // Stochastic %D period
input int      Stoch_Slowing = 3;       // Stochastic slowing
input int      Stoch_Oversold = 20;     // Stochastic oversold level

input group "MACD Parameters"
// MACD Parameters
input bool     Use_MACD = false;        // Use MACD Indicator
input int      MACD_Fast = 12;          // MACD Fast EMA
input int      MACD_Slow = 26;          // MACD Slow EMA
input int      MACD_Signal = 9;         // MACD Signal period

input group "MA Cross Parameters"
// Moving Average Cross Parameters
input bool     Use_MA_Cross = false;    // Use Moving Average Cross
input int      Fast_MA_Period = 10;     // Fast MA period
input int      Slow_MA_Period = 20;     // Slow MA period
input ENUM_MA_METHOD MA_Method = MODE_SMA; // MA method

input group "Signal Confirmation"
input bool    AnySignalToOpen = true;   // True: Open on any signal, False: Need all signals
input int     ConfirmationBars = 2;     // Number of bars to confirm signals

input group "Trailing Settings"
//input bool     AllowMultiplePositions = false;  // Allow multiple positions
//input int      MaxPositions = 1;                // Maximum number of positions allowed
input bool     UseTrailingStop = false;         // Enable/Disable trailing stop
input double   StartTrailing = 50;             // Start trailing stop (points)
input double   StepTrailing = 10;              // Trailing stop step (points)

// Global variables
bool     AllowMultiplePositions = false;  // Allow multiple positions
int      MaxPositions = 1;                // Maximum number of positions allowed
int handle_cci, handle_rsi, handle_stoch, handle_macd, handle_fast_ma, handle_slow_ma;
MqlTradeRequest request;
MqlTradeResult result;
int totalPositions = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize indicators based on activation status
    if(Use_CCI)
    {
        handle_cci = iCCI(_Symbol, PERIOD_CURRENT, CCI_Period, PRICE_CLOSE);
        if(handle_cci == INVALID_HANDLE)
        {
            Print("Error creating CCI indicator");
            return(INIT_FAILED);
        }
    }
    
    if(Use_RSI)
    {
        handle_rsi = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
        if(handle_rsi == INVALID_HANDLE)
        {
            Print("Error creating RSI indicator");
            return(INIT_FAILED);
        }
    }
    
    if(Use_Stochastic)
    {
        handle_stoch = iStochastic(_Symbol, PERIOD_CURRENT, Stoch_K_Period, Stoch_D_Period, Stoch_Slowing, MODE_SMA, STO_LOWHIGH);
        if(handle_stoch == INVALID_HANDLE)
        {
            Print("Error creating Stochastic indicator");
            return(INIT_FAILED);
        }
    }
    
    if(Use_MACD)
    {
        handle_macd = iMACD(_Symbol, PERIOD_CURRENT, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
        if(handle_macd == INVALID_HANDLE)
        {
            Print("Error creating MACD indicator");
            return(INIT_FAILED);
        }
    }
    
    if(Use_MA_Cross)
    {
        handle_fast_ma = iMA(_Symbol, PERIOD_CURRENT, Fast_MA_Period, 0, MA_Method, PRICE_CLOSE);
        handle_slow_ma = iMA(_Symbol, PERIOD_CURRENT, Slow_MA_Period, 0, MA_Method, PRICE_CLOSE);
        if(handle_fast_ma == INVALID_HANDLE || handle_slow_ma == INVALID_HANDLE)
        {
            Print("Error creating MA indicators");
            return(INIT_FAILED);
        }
    }
     // Hitung jumlah indikator aktif
    int activeCount = 0;
    if(Use_CCI) activeCount++;
    if(Use_RSI) activeCount++;
    if(Use_Stochastic) activeCount++;
    if(Use_MACD) activeCount++;
    if(Use_MA_Cross) activeCount++;
    
    // Validasi minimal satu indikator aktif
    if(activeCount == 0)
    {
        Print("Error: At least one indicator must be activated!");
        return(INIT_PARAMETERS_INCORRECT);
    }
    
    if(ConfirmationBars <= 0)
    {
        Print("Error: ConfirmationBars must be greater than 0!");
        return(INIT_PARAMETERS_INCORRECT);
    }
     if(MaxPositions <= 0)
    {
        Print("Error: MaxPositions must be greater than 0!");
        return(INIT_PARAMETERS_INCORRECT);
    }
    
    if(StartTrailing < 0)
    {
        Print("Error: StartTrailing cannot be negative!");
        return(INIT_PARAMETERS_INCORRECT);
    }
    
    if(StepTrailing <= 0)
    {
        Print("Error: StepTrailing must be greater than 0!");
        return(INIT_PARAMETERS_INCORRECT);
    }
    
    // Initialize trade request
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
    // Release indicator handles
    if(Use_CCI && handle_cci != INVALID_HANDLE)
        IndicatorRelease(handle_cci);
    if(Use_RSI && handle_rsi != INVALID_HANDLE)
        IndicatorRelease(handle_rsi);
    if(Use_Stochastic && handle_stoch != INVALID_HANDLE)
        IndicatorRelease(handle_stoch);
    if(Use_MACD && handle_macd != INVALID_HANDLE)
        IndicatorRelease(handle_macd);
    if(Use_MA_Cross)
    {
        if(handle_fast_ma != INVALID_HANDLE)
            IndicatorRelease(handle_fast_ma);
        if(handle_slow_ma != INVALID_HANDLE)
            IndicatorRelease(handle_slow_ma);
    }
}

//+------------------------------------------------------------------+
//| Check if all active indicators show buy signals                    |
//+------------------------------------------------------------------+
bool CheckBuySignals()
{
    int totalSignals = 0;
    int activeIndicators = 0;
    
    // Check CCI
    if(Use_CCI)
    {
        activeIndicators++;
        double cci[];
        ArraySetAsSeries(cci, true);
        // Copy more bars for confirmation
        if(CopyBuffer(handle_cci, 0, 0, ConfirmationBars + 1, cci) < ConfirmationBars + 1) 
            return false;
            
        bool cciSignal = true;
        // Check if CCI remains below -CCI_Oversold for ConfirmationBars
        for(int i = 0; i < ConfirmationBars; i++)
        {
            if(cci[i] >= -CCI_Oversold)
            {
                cciSignal = false;
                break;
            }
        }
        if(cciSignal) totalSignals++;
    }
    
    // Check RSI
    if(Use_RSI)
    {
        activeIndicators++;
        double rsi[];
        ArraySetAsSeries(rsi, true);
        if(CopyBuffer(handle_rsi, 0, 0, ConfirmationBars + 1, rsi) < ConfirmationBars + 1) 
            return false;
            
        bool rsiSignal = true;
        // Check if RSI remains below RSI_Oversold for ConfirmationBars
        for(int i = 0; i < ConfirmationBars; i++)
        {
            if(rsi[i] >= RSI_Oversold)
            {
                rsiSignal = false;
                break;
            }
        }
        if(rsiSignal) totalSignals++;
    }
    
    // Check Stochastic
    if(Use_Stochastic)
    {
        activeIndicators++;
        double stochK[], stochD[];
        ArraySetAsSeries(stochK, true);
        ArraySetAsSeries(stochD, true);
        if(CopyBuffer(handle_stoch, 0, 0, ConfirmationBars + 1, stochK) < ConfirmationBars + 1) 
            return false;
        if(CopyBuffer(handle_stoch, 1, 0, ConfirmationBars + 1, stochD) < ConfirmationBars + 1) 
            return false;
            
        bool stochSignal = true;
        // Check if both K and D remain below Stoch_Oversold for ConfirmationBars
        for(int i = 0; i < ConfirmationBars; i++)
        {
            if(stochK[i] >= Stoch_Oversold || stochD[i] >= Stoch_Oversold)
            {
                stochSignal = false;
                break;
            }
        }
        if(stochSignal) totalSignals++;
    }
    
    // Check MACD
    if(Use_MACD)
    {
        activeIndicators++;
        double macd[], signal[];
        ArraySetAsSeries(macd, true);
        ArraySetAsSeries(signal, true);
        if(CopyBuffer(handle_macd, 0, 0, ConfirmationBars + 2, macd) < ConfirmationBars + 2) 
            return false;
        if(CopyBuffer(handle_macd, 1, 0, ConfirmationBars + 2, signal) < ConfirmationBars + 2) 
            return false;
            
        bool macdSignal = true;
        // Check if MACD remains above signal line for ConfirmationBars after crossing
        if(macd[ConfirmationBars + 1] < signal[ConfirmationBars + 1] && 
           macd[ConfirmationBars] > signal[ConfirmationBars])
        {
            for(int i = 0; i < ConfirmationBars; i++)
            {
                if(macd[i] <= signal[i])
                {
                    macdSignal = false;
                    break;
                }
            }
            if(macdSignal) totalSignals++;
        }
    }
    
    // Check MA Cross
    if(Use_MA_Cross)
    {
        activeIndicators++;
        double fastMA[], slowMA[];
        ArraySetAsSeries(fastMA, true);
        ArraySetAsSeries(slowMA, true);
        if(CopyBuffer(handle_fast_ma, 0, 0, ConfirmationBars + 2, fastMA) < ConfirmationBars + 2) 
            return false;
        if(CopyBuffer(handle_slow_ma, 0, 0, ConfirmationBars + 2, slowMA) < ConfirmationBars + 2) 
            return false;
            
        bool maCrossSignal = true;
        // Check if Fast MA remains above Slow MA for ConfirmationBars after crossing
        if(fastMA[ConfirmationBars + 1] < slowMA[ConfirmationBars + 1] && 
           fastMA[ConfirmationBars] > slowMA[ConfirmationBars])
        {
            for(int i = 0; i < ConfirmationBars; i++)
            {
                if(fastMA[i] <= slowMA[i])
                {
                    maCrossSignal = false;
                    break;
                }
            }
            if(maCrossSignal) totalSignals++;
        }
    }
    
    // Validasi jumlah indikator aktif
    if(activeIndicators == 0) 
    {
        Print("Error: No indicators are activated!");
        return false;
    }
    
    // Logic berdasarkan AnySignalToOpen
    if(AnySignalToOpen)
    {
        // Return true jika ada minimal satu sinyal
        return (totalSignals > 0);
    }
    else
    {
        // Return true hanya jika semua indikator aktif memberikan sinyal
        return (totalSignals == activeIndicators);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Update total positions
    totalPositions = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetInteger(POSITION_MAGIC) == request.magic)
                totalPositions++;
        }
    }
    
    // Manage trailing stop untuk posisi yang ada
    ManageTrailingStop();
    
    // Check if we can open new positions
    if(!AllowMultiplePositions && totalPositions > 0)
        return;
        
    if(AllowMultiplePositions && totalPositions >= MaxPositions)
        return;
        
    // Check if all active indicators show buy signals
    if(CheckBuySignals())
    {
        OpenGridPositions();
    }
}

//+------------------------------------------------------------------+
//| Function to open grid positions                                    |
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
            
        // Set initial Stop Loss if StopLoss parameter is greater than 0
        if(StopLoss > 0)
        {
            double initialSL = NormalizeDouble(price - (StopLoss * point), _Digits);
            if(MathAbs(price - initialSL) >= minStop)
                request.sl = initialSL;
            else
                request.sl = 0;
        }
        else
            request.sl = 0;
            
        // Send order
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


void ManageTrailingStop()
{
    // Check if trailing stop is enabled
    if(!UseTrailingStop || StartTrailing <= 0) 
        return;
    
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double minStop = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            // Skip if not our EA's position
            if(PositionGetInteger(POSITION_MAGIC) != request.magic)
                continue;
                
            double positionSL = PositionGetDouble(POSITION_SL);
            double positionTP = PositionGetDouble(POSITION_TP);
            double positionPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            // Only for BUY positions
            if(posType == POSITION_TYPE_BUY)
            {
                // Calculate profit in points
                double profitPoints = (bid - positionPrice) / point;
                
                // Only modify stop loss if profit exceeds StartTrailing
                if(profitPoints >= StartTrailing)
                {
                    // Calculate new stop loss
                    double newSL = NormalizeDouble(bid - (StepTrailing * point), _Digits);
                    
                    // If no SL exists or new SL is higher than current SL
                    if(positionSL == 0 || newSL > positionSL + (minStop * point))
                    {
                        MqlTradeRequest tradeRequest = {};
                        MqlTradeResult tradeResult = {};
                        
                        tradeRequest.action = TRADE_ACTION_SLTP;
                        tradeRequest.position = PositionGetTicket(i);
                        tradeRequest.symbol = _Symbol;
                        tradeRequest.sl = newSL;
                        tradeRequest.tp = positionTP; // Maintain existing TP
                        
                        if(!OrderSend(tradeRequest, tradeResult))
                        {
                            PrintFormat("Error modifying trailing stop: %d", GetLastError());
                        }
                    }
                }
            }
        }
    }
}