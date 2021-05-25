//+------------------------------------------------------------------+
//|                                                  LTY_Commons.mqh |
//|                                          Copyright 2020, GSPY FX |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, GSPY FX"
#property strict

#include "Header.mqh"

//+------------------------------------------
// Variable declarations
struct Order_info
  {
   long              order_id;
   datetime          order_date;
   int               order_type;
   double            order_size;
   string            order_symbol;
   double            order_price;
   double            order_tp;
   double            order_sl;
   double            order_swap;
   double            order_currentProfit;
   bool              order_adjusted;
  };
struct Order_parameters
  {
   int               iMaxOrder;
   int               iDist;
   int               iMaxLot;
   int               iTPpips;
   int               iSLpips;
   int               iMagicNum;
   double            dLotMul;
   double            dStartLot;
   string            strSymbols[20];
   int               iRunningSymbols;
   bool              bTrailSL;
   int               iSLMult;
  };
Order_parameters orderParameters;

Order_info orderInfo[100];

int iOrderCount = 0;
int iOrderCountBuy = 0;
int iOrderCountSell = 0;
int iCurrentSymbolCount = 0;

string strCurrentSymbols[100];

double dCurrentLot = 0;
bool gIsHedge = false;

//Params


//+-------------------------------------------
void initParameters(Order_parameters &params)
  {
   orderParameters = params;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ProcessEA()
  {
   bool bObserveFlg = true;
//Print("XXX -- iOrderCount: ",iOrderCount);
//Print("XXX -- orderParameters.iMaxOrder = ",orderParameters.iMaxOrder);
   if(iOrderCount < 0)
     {
      iOrderCount = 0;
     }
   if(iOrderCount < orderParameters.iMaxOrder)
     {
      observeChart(NULL);
     }

   if(iOrderCount >= 1)
     {
      // Manage Order
      ManageOrders();
     }

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void observeChart(string symbol)
  {
   double vbid    = MarketInfo(symbol,MODE_BID);
   double vask    = MarketInfo(symbol,MODE_ASK);
   double dSL;
// --- Get trend using EMA 200
   int iTrend = GetTrend(symbol);
   int iOder = 0;
   double dLot;
   double dTakeProfit;

// --- Verify area and get stop loss
   switch(iTrend)
     {
      case __TREND_LONG :
         //Print("Trend Long ");
         iOder = AreaOfValue(iTrend, symbol, dSL);
         break;
      case __TREND_SHORT:
         //Print("Trend Short ");
         iOder = AreaOfValue(iTrend, symbol, dSL);
         break;
      default:
         iOder = NG;
         break;
     }
   if(iOder == OK)
     {
      dLot = orderParameters.dStartLot;
      dTakeProfit = GetTPPrice(symbol, iTrend, orderParameters.iTPpips);

      RegisterOrder(symbol, iTrend, dLot, dTakeProfit, dSL);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RegisterOrder(string symbol,int iTrend, double dLot, double dTP, double dSL)
  {
   int iTicket;
   /*if(IsSymbolExistOrder(symbol) == true)
     {
      return;
     }*/
//Print("XXX -- RegisterOrder - iOrderCount: ", iOrderCount);

   switch(iTrend)
     {
      case __TREND_LONG:
         iTicket = OrderSend(symbol,
                             OP_BUY,
                             dLot,
                             Ask,
                             3,
                             dSL,
                             dTP,
                             "LightYearEA",
                             orderParameters.iMagicNum,
                             0,
                             Green);
         iOrderCountBuy++;
         iOrderCount++;
         break;
      case __TREND_SHORT:
         iTicket = OrderSend(symbol,
                             OP_SELL,
                             dLot,
                             Bid,
                             3,
                             dSL,
                             dTP,
                             "LightYearEA",
                             orderParameters.iMagicNum,
                             0,
                             Red);
         iOrderCountSell++;
         iOrderCount++;
         break;
      default:
         break;
     }
   if(iTicket < 0)
     {
      Alert("OrderSend Error");
     }
   if(iTicket != 0)
     {
      if(iTrend == __TREND_LONG)
        {
         orderInfo[iOrderCount-1].order_price = Ask;
        }
      else
        {
         orderInfo[iOrderCount-1].order_price = Bid;
        }
      orderInfo[iOrderCount-1].order_id = iTicket;
      orderInfo[iOrderCount-1].order_symbol = symbol;
      orderInfo[iOrderCount-1].order_tp = dTP;
      orderInfo[iOrderCount-1].order_sl = dSL;
      orderInfo[iOrderCount-1].order_type = iTrend;
      orderInfo[iOrderCount-1].order_size = dLot;
      //strCurrentSymbols[iCurrentSymbolCount++] = symbol;
      orderInfo[iOrderCount-1].order_adjusted = false;
      //PrintOrderInfo(orderInfo[iOrderCount-1]);
     }

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsSymbolExistOrder(string strSymbol)
  {
   bool bIsExist = false;
   for(int i=0; i<ArraySize(orderInfo)-1; i++)
     {
      if(strSymbol == orderInfo[i].order_symbol)
        {
         bIsExist = true;
        }
     }
   return bIsExist;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageOrders()
  {
   Order_info ordInfo;
   int iOrderUp = 0;
   double dNewTP = 0;

   for(int i=0; i < ArraySize(orderInfo)-1; i++)
     {

      if(orderInfo[i].order_id == 0)
        {
         return;
        }
      if(OrderSelect(orderInfo[i].order_id, SELECT_BY_TICKET) == false)
        {
         continue;
        }
      if(IsSLThenDeleteOrder(orderInfo[i]))
        {
         return;
        }
      if(IsTPThenDeleteOrder(orderInfo[i]))
        {
         return;
        }
      if(AdjustToTrailingSL(orderInfo[i]))
        {
         return;
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool AdjustToTrailingSL(Order_info &order)
  {
   double lCurrentPrice = 0.0;
   double dTrailSLCurrent = 0.0;
   int intEndCode = False;
   bool res;

   if(!orderParameters.bTrailSL)
     {
      return intEndCode;
     }
   if(order.order_id == 0 || order.order_adjusted == false)
     {
      return intEndCode;
     }
//Print("XXX -- order.order_id : ",order.order_id);
   OrderSelect(order.order_id,SELECT_BY_TICKET);
   switch(order.order_type)
     {
      case  __TREND_LONG:
         lCurrentPrice =  MarketInfo(order.order_symbol,MODE_ASK);
         dTrailSLCurrent = OrderOpenPrice() + GetUnits(order.order_symbol, orderParameters.iSLpips);
         //Print("XXX -- dTrailSLCurrent : ",dTrailSLCurrent);
         //Print("XXX -- lCurrentPrice : ", lCurrentPrice);
         if(dTrailSLCurrent < lCurrentPrice)
           {
            res = OrderModify(OrderTicket(),
                              OrderOpenPrice(),
                              dTrailSLCurrent,
                              OrderTakeProfit(),
                              0,Blue);
            order.order_sl = dTrailSLCurrent;
            order.order_adjusted = true;
           }
         break;
      case __TREND_SHORT:
         lCurrentPrice = MarketInfo(order.order_symbol,MODE_BID);
         dTrailSLCurrent = OrderOpenPrice() - GetUnits(order.order_symbol, orderParameters.iSLpips);
         //Print("XXX -- dTrailSLCurrent : ",dTrailSLCurrent);
         //Print("XXX -- lCurrentPrice : ", lCurrentPrice);
         if(dTrailSLCurrent > lCurrentPrice)
           {
            res = OrderModify(OrderTicket(),
                              OrderOpenPrice(),
                              dTrailSLCurrent,
                              OrderTakeProfit(),
                              0,Blue);
            order.order_sl = dTrailSLCurrent;
            order.order_adjusted = true;
           }
         break;
      default:
         return false;
         break;
     }

   return intEndCode;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsSLThenDeleteOrder(Order_info &order)
  {
   double lCurrentPrice = 0.0;
   int intEndCode = False;

   switch(order.order_type)
     {
      case  __TREND_LONG:
         lCurrentPrice =  MarketInfo(order.order_symbol,MODE_ASK);
         if(order.order_sl >= lCurrentPrice)
           {
            // Delete order
            //Print("XXX -- Delete @ IsSLThenDeleteOrder");
            DeleteOder(order.order_id);
            intEndCode = True;
           }
         break;
      case __TREND_SHORT:
         lCurrentPrice = MarketInfo(order.order_symbol,MODE_BID);
         if(order.order_sl <= lCurrentPrice)
           {
            // Delete order
            //Print("XXX -- Delete @ IsSLThenDeleteOrder");
            DeleteOder(order.order_id);
            intEndCode = True;
           }
         break;
      default:
         return false;
         break;
     }
//Print("XXX -- IsTPThenDeleteOrder: Price - ", lCurrentPrice)
   return intEndCode;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTPThenDeleteOrder(Order_info &order)
  {
   double lCurrentPrice = 0.0;
   int intEndCode = False;
//Print("XXX -- IsTPThenDeleteOrder: OrderType -",order.order_type);
   switch(order.order_type)
     {
      case  __TREND_LONG:
         lCurrentPrice =  MarketInfo(order.order_symbol,MODE_ASK);
         if(order.order_tp < lCurrentPrice)
           {
            // Delete order
            /*
            Print("XXX -- Delete @ IsTPThenDeleteOrder");
            Print("XXX -- Delete order lCurrentPrice : ", lCurrentPrice);
            Print("XXX -- Delete order order.order_tp : ", order.order_tp);
            */
            DeleteOder(order.order_id);
            intEndCode = True;
            //Print("XXX -- Delete order");
           }
         break;
      case __TREND_SHORT:
         lCurrentPrice = MarketInfo(order.order_symbol,MODE_BID);

         if(order.order_tp > lCurrentPrice)
           {
            // Delete order
            /*
            Print("XXX -- Delete @ IsTPThenDeleteOrder");
            Print("XXX -- Delete order lCurrentPrice : ", lCurrentPrice);
            Print("XXX -- Delete order order.order_tp : ", order.order_tp);
            */
            DeleteOder(order.order_id);
            intEndCode = True;
            //Print("XXX -- Delete order");
           }
         break;
      default:
         return false;
         break;
     }
//Print("XXX -- IsTPThenDeleteOrder: Price - ", lCurrentPrice);

   return intEndCode;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetAndUpdateTP(Order_info &ordInfo[])
  {
   int iTPIndex = ArraySize(ordInfo)/2;
   double dUpdateTP = ordInfo[iTPIndex].order_tp;
   for(int i=0; i<ArraySize(ordInfo); i++)
     {
      ordInfo[i].order_tp = dUpdateTP;
      if(OrderModify(ordInfo[i].order_id,
                     ordInfo[i].order_price,
                     ordInfo[i].order_sl,
                     ordInfo[i].order_tp,
                     0,Blue))
        {
         Print("New TP @: ", dUpdateTP);
        }
     }

   return dUpdateTP;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GetLastOrderBySymbol(string strSymbol, Order_info &ordInfo)
  {

   for(int i=ArraySize(orderInfo) - 1; i>0; i--)
     {
      if(orderInfo[i].order_symbol == strSymbol)
        {

         ordInfo = orderInfo[i];
         break;
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteOders(int &iTicket[])
  {
   for(int i=0; i<ArraySize(iTicket); i++)
     {
      DeleteOder(iTicket[i]);

     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteOder(int iTicket)
  {
   int iPos = 0;
   bool bFlag = false;
   for(int i=0; i<ArraySize(orderInfo) -1 ; i++)
     {
      if(orderInfo[i].order_id == iTicket)
        {
         iPos = i;
         bFlag = true;
        }
     }
   for(int i=iPos; i<ArraySize(orderInfo) - 1; i++)
     {
      orderInfo[i] = orderInfo[i + 1];
      bFlag = true;
     }
   if(bFlag == true)
     {
      iOrderCount--;
     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetTrend(string symbol)
  {
   double EMA50 = iMA(NULL,0,50,0,MODE_EMA,PRICE_CLOSE,0);
   double EMA200 = iMA(NULL,0,200,0,MODE_EMA,PRICE_CLOSE,0);

   if(EMA50 > EMA200 && GetDistanceUnits(EMA50,EMA200) >= 20)
     {
      return __TREND_LONG;
     }
   else
      if(EMA50 < EMA200 && GetDistanceUnits(EMA200,EMA50) >= 20)
        {
         return __TREND_SHORT;
        }
   return 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int AreaOfValue(int trend, string symbol, double &dSL)
  {
   double dAtrLevel = 5 * MathRound(iATR(symbol,0,22,0)*(Digits>=5?10000:1000));

   int iHighestPos = iHighest(NULL,0,MODE_HIGH,20,3);
   int iLowestPos = iLowest(NULL,0,MODE_LOW,20,3);

   double dHighestPrice = High[iHighestPos];
   double dLowestPrice = Low[iLowestPos];

   double vask    = MarketInfo(symbol,MODE_ASK);
   double vbid    = MarketInfo(symbol,MODE_BID);
   double dSLComp;
   int iOrder = 0;
   int iOrderEntry;
   double dValidComp = 0.0;
   double dnewSL = 0.0;
// Get Entry
   iOrderEntry = GetEntryStatus(symbol);

   if(iOrderEntry == trend)
     {

      if(trend ==  __TREND_LONG)
        {
         dSLComp = dHighestPrice - GetUnits(symbol, dAtrLevel + orderParameters.iSLMult);
         dSL = dSLComp;
         dValidComp = vask - dSL;
         dnewSL = dSLComp - GetUnits(symbol, 100);
         iOrder = OK;
        }
      else if(trend == __TREND_SHORT)
           {
            dSLComp = dLowestPrice + GetUnits(symbol, dAtrLevel + orderParameters.iSLMult);
            dSL = dSLComp;
            dValidComp = dSL - vbid;
            dnewSL = dSLComp + GetUnits(symbol, 100);
            iOrder = OK;
           }
     }
   if(iOrder == OK)
     {
      if(dValidComp <= GetUnits(symbol, 10))
        {
         dSL = dnewSL;
        }
     }
   return iOrder;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetEntryStatus(string symbol)
  {
   double dK0 = iStochastic(symbol,0,20,3,3,MODE_SMA,0,MODE_MAIN,0);
   double dD0 = iStochastic(symbol,0,20,3,3,MODE_SMA,0,MODE_SIGNAL,0);

   double dK1 = iStochastic(symbol,0,20,3,3,MODE_SMA,0,MODE_MAIN,1);
   double dD1 = iStochastic(symbol,0,20,3,3,MODE_SMA,0,MODE_SIGNAL,1);

   if((dK0 <= 80 && dD0 >= 50) &&
      (dD0 < dK0 && dD1 > dK1))
     {
      //Print("XXX -- Trend: Long1 ");
      return __TREND_LONG;
     }
   if(dD0 > dK0 && dD1 > dK1)
     {
      //Print("XXX -- Trend: Long2 ");
      return __TREND_LONG;
     }
   if((dK0 <= 50 && dD0 >= 20) &&
      (dD0 > dK0 && dD1 < dK1))
     {
      //Sell signal
      //Print("XXX -- Trend: Short1 ");
      return __TREND_SHORT;
     }
   if((dD0 < dK0 && dD1 < dK1))
     {
      //Print("XXX -- Trend: Short2 ");
      return __TREND_SHORT;
     }
   return OK;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetTPPrice(string strSymbol,int iTrend, int iTpPips)
  {
   double dTp = 0;
   int   vspread = (int)MarketInfo(strSymbol,MODE_SPREAD);
   switch(iTrend)
     {
      case  __TREND_LONG:
         dTp = Ask + GetUnits(strSymbol, iTpPips) + (vspread * Point) ;
         break;
      case __TREND_SHORT:
         dTp = Bid - GetUnits(strSymbol, iTpPips) - (vspread * Point);
         break;
      default:
         break;
     }
   return dTp;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetUnits(string strSymbol, int iPips)
  {
   double dUnits;
   if(Digits >= 5)
     {
      dUnits = 0.0001 * iPips;
     }
   else
     {
      dUnits = 0.01 * iPips;
     }
//Print("XXX -- DIGITS: ", Digits, " dUnits: ", dUnits);
   return dUnits;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetDistanceUnits(double dStart, double dEnd)
  {
   double dDist = dStart - dEnd;
   int iExp = 1;
   for(int i=0; i<Digits; i++)
     {
      iExp *= 10;
     }
   return dDist * iExp;
  }
//+------------------------------------------------------------------+
void PrintOrderInfo(Order_info &oInfo)
  {
   Print("Order Ticket: ", oInfo.order_id);
   Print("Order Price: ",  oInfo.order_price);
   Print("Order TP: ",     oInfo.order_tp);
   Print("Order SL: ",     oInfo.order_sl);
   Print("Order Symbol: ", oInfo.order_symbol);
   Print("Order Type: ", oInfo.order_type);
  }
//+------------------------------------------------------------------+
