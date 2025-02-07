//+------------------------------------------------------------------+
//|                                                   GridStochEA.mq5  |
//|                        Copyright 2025, MetaQuotes Software Corp.   |
//|                                             https://www.mql5.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, alfatihmm"
#property link      ""
#property version   "1.01"

// Input Parameters
input double GridDistance = 100;     // Distance between grid levels
input double SLMultiplier = 0;       // Stop Loss multiplier (0 = disable, 0.5 = half distance, 1 = full distance)
input double TPMultiplier = 1;       // Take Profit multiplier (1 = full distance, 1.5 = 1.5x distance)
input double LotSize = 0.1;          // Trading lot size
input string EAComment = "GridStochEA";  // EA identifier
input int KPeriod = 14;              // Stochastic %K period
input int DPeriod = 3;               // Stochastic %D period
input int Slowing = 3;               // Stochastic slowing
input double OversoldLevel = 20;      // Stochastic oversold level

// Global Variables
int buyStop1Ticket = 0;
int buyStop2Ticket = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   // Validate input parameters
   if(OversoldLevel <= 0 || OversoldLevel >= 100)
   {
      Print("Invalid Oversold Level. Must be between 0 and 100");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   CreateInitialGrid();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteAllOrders();
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   ManagePositions();
   CheckAndRestoreGrid();
}

//+------------------------------------------------------------------+
//| Create initial grid orders                                         |
//+------------------------------------------------------------------+
void CreateInitialGrid()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   double kValue, dValue;
   GetStochasticValues(kValue, dValue);
   
   if (kValue < OversoldLevel) {  // Using configurable oversold level
      buyStop1Ticket = OrderCreate(currentPrice + GridDistance, ORDER_TYPE_BUY_STOP);
      buyStop2Ticket = OrderCreate(currentPrice + (2 * GridDistance), ORDER_TYPE_BUY_STOP);
   }
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss price                                          |
//+------------------------------------------------------------------+
double CalculateStopLoss(double entryPrice)
{
   if(SLMultiplier <= 0) return 0.0;
   double slDistance = GridDistance * SLMultiplier;
   return NormalizeDouble(entryPrice - slDistance, _Digits);
}

//+------------------------------------------------------------------+
//| Calculate Take Profit price                                        |
//+------------------------------------------------------------------+
double CalculateTakeProfit(double entryPrice)
{
   if(TPMultiplier <= 0) return 0.0;
   double tpDistance = GridDistance * TPMultiplier;
   return NormalizeDouble(entryPrice + tpDistance, _Digits);
}

//+------------------------------------------------------------------+
//| Create new order                                                   |
//+------------------------------------------------------------------+
int OrderCreate(double price, ENUM_ORDER_TYPE orderType)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_PENDING;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = orderType;
   request.price = NormalizeDouble(price, _Digits);
   
   // Set Stop Loss
   double sl = CalculateStopLoss(price);
   if(sl > 0) {
      request.sl = sl;
   }
   
   // Set Take Profit
   double tp = CalculateTakeProfit(price);
   if(tp > 0) {
      request.tp = tp;
   }
   
   request.deviation = 10;
   request.comment = EAComment;
   
   if(!OrderSend(request, result))
   {
      Print("OrderSend error: ", GetLastError());
      return -1;
   }
   
   return result.order;
}

//+------------------------------------------------------------------+
//| Manage open positions                                              |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            double positionPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            
            // Check if price reached Take Profit level
            if(currentPrice >= CalculateTakeProfit(positionPrice))
            {
               ClosePosition(PositionGetTicket(i));
               UpdateGridLevels(currentPrice);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update grid levels after position close                            |
//+------------------------------------------------------------------+
void UpdateGridLevels(double currentPrice)
{
   double kValue, dValue;
   GetStochasticValues(kValue, dValue);
   
   if (kValue < OversoldLevel) {  // Using configurable oversold level
      DeleteAllOrders();
      
      // Create new grid levels based on the current price
      double newBuyStop1 = currentPrice + GridDistance;
      double newBuyStop2 = currentPrice + (2 * GridDistance);
      
      buyStop1Ticket = OrderCreate(newBuyStop1, ORDER_TYPE_BUY_STOP);
      buyStop2Ticket = OrderCreate(newBuyStop2, ORDER_TYPE_BUY_STOP);
   }
}

//+------------------------------------------------------------------+
//| Close specific position                                            |
//+------------------------------------------------------------------+
void ClosePosition(ulong ticket)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = _Symbol;
   request.volume = PositionGetDouble(POSITION_VOLUME);
   request.type = ORDER_TYPE_SELL;
   request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   request.deviation = 10;
   
   if(!OrderSend(request, result))
   {
      Print("OrderSend error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Delete all pending orders                                          |
//+------------------------------------------------------------------+
void DeleteAllOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(OrderGetTicket(i)))
      {
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         
         request.action = TRADE_ACTION_REMOVE;
         request.order = OrderGetTicket(i);
         
         if(!OrderSend(request, result))
         {
            Print("OrderSend error: ", GetLastError());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check and restore missing grid orders                              |
//+------------------------------------------------------------------+
void CheckAndRestoreGrid()
{
   double kValue, dValue;
   GetStochasticValues(kValue, dValue);
   
   if (kValue > OversoldLevel) {  // Using configurable oversold level
      DeleteAllOrders();
   } else {
      if (OrdersTotal() < 2) {
         CreateInitialGrid();
      }
   }
}

//+------------------------------------------------------------------+
//| Get Stochastic values                                             |
//+------------------------------------------------------------------+
void GetStochasticValues(double &kValue, double &dValue)
{
   int handle = iStochastic(_Symbol, PERIOD_CURRENT, KPeriod, DPeriod, Slowing, MODE_SMA, STO_LOWHIGH);
   if (handle == INVALID_HANDLE) {
      Print("Error creating Stochastic handle: ", GetLastError());
      return;
   }
   
   double kBuffer[], dBuffer[];
   
   if (CopyBuffer(handle, 0, 0, 1, kBuffer) <= 0 || CopyBuffer(handle, 1, 0, 1, dBuffer) <= 0) {
      Print("Error copying Stochastic buffer: ", GetLastError());
      return;
   }
   
   kValue = kBuffer[0];
   dValue = dBuffer[0];
}