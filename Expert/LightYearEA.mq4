//+------------------------------------------------------------------+
//|                                                  LightYearEA.mq4 |
//|                                          Copyright 2020, GSPY FX |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, FX Tyche"
#property link      ""
#property version   "1.00"
#property strict

#include "../Include/Header.mqh"
#include "../Include/LTY_Commons.mqh"

//--- input parameters
//input uint     Max_Order=5;
//input uint     DistancePips=20;
//input double   Max_Lot=0.01;
input int      TakeProfitPips=15;
input int      MagicNumber=1687;
//input double   LotMultiplier = 1.3;
input double   StartLot = 0.01;
input int      TrailingStopLossPips=10;
input bool     TrailingStopLoss = True;
input int      StopLossLevel = 50;

//input string   Symbol1 = "";
//input string   Symbol2 = "";
//input string   Symbol3 = "";
//input string   Symbol4 = "";
//input string   Symbol5 = "";
//input string   Symbol6 = "";
//input string   Symbol7 = "";
//input string   Symbol8 = "";
//input string   Symbol9 = "";
//input string   Symbol10 = "";
//----------------------------

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   Print("Initialize...");
   Order_parameters orParams;
   
   //orParams.iMaxOrder = Max_Order;
   orParams.iMaxOrder = 1;       // default
   //orParams.iDist = DistancePips;
   //orParams.iMaxLot = Max_Lot;
   orParams.iMaxLot= StartLot;
   orParams.iTPpips = TakeProfitPips;
   orParams.iSLpips = TrailingStopLossPips;
   orParams.iMagicNum = MagicNumber;
   orParams.dStartLot = StartLot;
   //orParams.dLotMul = LotMultiplier;
   orParams.bTrailSL = TrailingStopLoss;
   orParams.iSLMult = StopLossLevel;
   
   //orParams.strSymbols[0] = Symbol1;
   //orParams.strSymbols[1] = Symbol2; 
   //orParams.strSymbols[2] = Symbol3; 
   //orParams.strSymbols[3] = Symbol4; 
   //orParams.strSymbols[4] = Symbol5; 
   //orParams.strSymbols[5] = Symbol6; 
   //orParams.strSymbols[6] = Symbol7; 
   //orParams.strSymbols[7] = Symbol8; 
   //orParams.strSymbols[8] = Symbol9; 
   //orParams.strSymbols[9] = Symbol10;
   
   /*for(int i=0;i<ArraySize(orParams.strSymbols);i++)
     {
         if(orParams.strSymbols[i] == "")
           {
               orParams.iRunningSymbols = i - 1;
               break;
           }
     }
   
   
   Print("Light Year EA: Parameters Initialize...");
   */
   initParameters(orParams);
   
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   ProcessEA();
  }
//+------------------------------------------------------------------+
