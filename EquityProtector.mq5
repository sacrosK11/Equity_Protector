//+------------------------------------------------------------------+
//|                                              EquityProtector.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Variables                                                        |
//+------------------------------------------------------------------+
// Inputs
input double equityLimit = 2;
//input double balanceLimit = 2;
input int    updateFrequency_seconds = 1;
input bool   protector = true;

// Int Double and Long variables
double balance, equity, current_pl, prevBalance, open_positions, dailyProfit, todayPL, PercentFloatingEquity, totalPL, lossLimitInDollars;
double freeDailyRisk;
double max_equity = AccountInfoDouble(ACCOUNT_EQUITY);
long limit_orders;

// Bool variables
bool Ready, Closing;

// String variables
string GetDayOfWeek() // Get the day of the week by MqlDateTime
{
   MqlDateTime tm;
   TimeCurrent(tm);
   int day = tm.day_of_week;
   string dayName;
   switch (day)
   {
      case 0:  dayName = "SUNDAY"; break;
      case 1:  dayName = "MONDAY"; break;
      case 2:  dayName = "TUESDAY"; break;
      case 3:  dayName = "WEDNESDAY"; break;
      case 4:  dayName = "THURSTDAY"; break;
      case 5:  dayName = "FRIDAY"; break;
      case 6:  dayName = "SATURDAY"; break;
      default: dayName = "INVALID DAY"; break;
   }
   return dayName;
}

// DateTime variables
string currentDataString = TimeToString(TimeCurrent(), TIME_DATE); //today
datetime yesterdayTime = TimeCurrent() - PeriodSeconds(PERIOD_D1); 
datetime tomorrowDayTimev = TimeCurrent() + PeriodSeconds(PERIOD_D1);
string yesterdayDataString = TimeToString(yesterdayTime, TIME_DATE); //yesterday
string currentDay = GetDayOfWeek();

// Convert the ACCOUNT_CURRENCY ticker in the corresponding symbol
string GetAccountCurrency()
{
   string currency = AccountInfoString(ACCOUNT_CURRENCY);
   string account_currency;
   
   if      (currency == "USD")    account_currency = " $ ";
   else if (currency == "EUR")    account_currency = " € ";
   else if (currency == "GBP")    account_currency = " £ ";
   else    account_currency       = " " + currency + " ";
   
   return account_currency;
}

// Externs
#include       <Trade/Trade.mqh>
CTrade         Trade;
CPositionInfo  PositionInfo;

//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Functions                                                        |
//+------------------------------------------------------------------+
// Function to facilitate the creation of objects with similar characteristics 
void CreateObject(
                  long chart_id,
                  string name,
                  ENUM_OBJECT type,
                  int sub_window,
                  datetime time1,
                  double price1,
                  int y_distance,
                  int font_size,
                  string font_type,
                  color font_color,
                  string text      
                  ){
                  ObjectCreate(chart_id, name, type, sub_window, time1, price1);
                  ObjectSetInteger(chart_id, name, OBJPROP_SELECTABLE, true);
                  ObjectSetInteger(chart_id, name, OBJPROP_XDISTANCE, 10);
                  ObjectSetInteger(chart_id, name, OBJPROP_YDISTANCE, y_distance);
                  ObjectSetInteger(chart_id, name, OBJPROP_FONTSIZE, font_size);
                  ObjectSetString(chart_id, name, OBJPROP_FONT, font_type);
                  ObjectSetInteger(chart_id, name, OBJPROP_COLOR, font_color);   
                  ObjectSetString(chart_id, name, OBJPROP_TEXT, text); 
                  }

// Get the closed trades from date 1 to date 2 and return the total sum
double GetPl(datetime date1, datetime date2)
               {
               HistorySelect(date1, date2);
               uint total = HistoryDealsTotal();
               ulong    ticket = 0;
               double   profit;
               double   total_PL = 0;
               int      type;
               datetime time;
               for(uint i = 0; i < total; i++)
               {  
                  // Try to get deal's ticket
                  if ((ticket = HistoryDealGetTicket(i)) > 0)
                  {
                  
                     ENUM_POSITION_TYPE posType = PositionGetInteger(POSITION_TYPE);
                     //Print(EnumToString(posType) + " : " + (string)ticket);
                  
                     // Get deal's properties  
                     time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
                     profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                     ENUM_DEAL_TYPE type = HistoryDealGetInteger(ticket, DEAL_TYPE);
                     // Set balance movements to 0.0 to remove deposits and withdrawals 
                     switch(type){
                     
                        case DEAL_TYPE_BALANCE: profit = 0;
                        default: total_PL += profit;
                     }                     
                  }
               }   
               return total_PL;   
               }

// Function to get the text color based on a number (green = positive number, red = negative number)
color GetColor(double pl)
   {
   color plColor = clrWhite;
   if(pl > 0) plColor = clrLime;
   if(pl < 0) plColor = clrRed;
   return plColor;
   }


// Function to return ON If protector id true, OFF if it's false
string isOn(double protector)
   {
   string onOff = "";
   if(protector) onOff = "ON";      
   else onOff = "OFF";
   return(onOff);
   }
   
color colorIsOn(double protector)
   {
   color colorOnOff = clrWhite;
   if(protector) colorOnOff = clrPaleGreen;      
   else colorOnOff = clrLightSalmon;
   return colorOnOff;
   }
// Function called by the timer to update objects 
void UpdatePL(){
           
               // Initialize account data
               balance = AccountInfoDouble(ACCOUNT_BALANCE);
               equity = AccountInfoDouble(ACCOUNT_EQUITY);
               limit_orders = AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
               open_positions = AccountInfoDouble(ACCOUNT_ASSETS);
               
               
               // Update DateTime variables
               string currentDataString = TimeToString(TimeCurrent(), TIME_DATE); //today
               datetime yesterdayTime = TimeCurrent() - PeriodSeconds(PERIOD_D1); 
               datetime tomorrowDayTimev = TimeCurrent() + PeriodSeconds(PERIOD_D1);
               string yesterdayDataString = TimeToString(yesterdayTime, TIME_DATE); //yesterday
               string currentDay = GetDayOfWeek();
                 
               // Calculate data
               todayPL = GetPl(StringToTime(currentDataString), StringToTime(tomorrowDayTimev));
               // Re-download closed trades total amount from date1 to date2
               current_pl = (equity - balance); 
               totalPL = todayPL+current_pl;
               // get the previous balance by subtracting/adding today's P/L
               prevBalance = balance - todayPL - current_pl; 
               // Calculate the total loss by summing the total closed trades and the current floating equity (/equity * 100 for the % value)
               PercentFloatingEquity = (((todayPL+current_pl)/equity) * 100); 
               lossLimitInDollars = prevBalance*(equityLimit/100);
               
               freeDailyRisk = PercentFloatingEquity+equityLimit;
               
 
                 
               
                if(!Ready){
                  Ready = true;
                  CheckClose();
                  }
                           
               CheckClose();      
               
               // Update Date Object  
               ObjectSetString(0, "dateLabel", OBJPROP_TEXT, GetDayOfWeek() + ", " + TimeCurrent());
               color plColor = GetColor(todayPL + current_pl);
               color currentPlColor = GetColor(current_pl);
               
               // Update balance label
               ObjectSetString(0,"equityBalanceLabel", OBJPROP_TEXT, "BALANCE: " +  GetAccountCurrency() + DoubleToString(balance, 2) + 
                   " | " + "EQUITY: " +  GetAccountCurrency() + DoubleToString(equity, 2));
               
               // Update Date Floating Equity
               ObjectSetString(0,"floatingeEquityLabel", OBJPROP_TEXT, "FLOATING P/L: " +  GetAccountCurrency() + DoubleToString(current_pl, 2) + 
                                  " | " + DoubleToString(((current_pl/equity)*100), 2) + "%");
 
               ObjectSetInteger(0,"floatingeEquityLabel", OBJPROP_COLOR, currentPlColor);     
               
               //Update Total PL Object              
               ObjectSetString(0,"todayPLlabel", OBJPROP_TEXT, "TOTAL DAILY P/L " + GetAccountCurrency() + DoubleToString(totalPL,2) +
                                  " | " + DoubleToString(PercentFloatingEquity, 2) + "%");             
               ObjectSetInteger(0,"todayPLlabel", OBJPROP_COLOR, plColor);     
             
               //Update Balance Limit Object
               ObjectSetString(0,"balanceLimitLabel", OBJPROP_TEXT, "DAILY LOSS LIMIT: " + GetAccountCurrency() + DoubleToString(lossLimitInDollars,2) +
                                 " | " + DoubleToString(equityLimit,2) + "%");   
               
               //Upadte Protector On/Off Label
               ObjectSetString(0, "protectorLabel", OBJPROP_TEXT, "*** ACCOUNT PROTECTOR IS: " + isOn(protector) + " ***");
               ObjectSetInteger(0,"protectorLabel", OBJPROP_COLOR, colorIsOn(protector));                          
               
               //Update Free Daily Risk Object 
               ObjectSetString(0,"freeDailyRisk", OBJPROP_TEXT, "FREE DAILY RISK: " + GetAccountCurrency() + DoubleToString((lossLimitInDollars+totalPL),2) +
                                 " | " + DoubleToString(freeDailyRisk,2) + "%");     
                                 
                                               
               ChartRedraw(0);
                                                                                            
               }
//+------------------------------------------------------------------+


// Check if loss has reached the maximum loss limit and keep trying closing  
void CheckClose(){

if(protector){
   if(Closing){
         CloseBasket();  
         return;
      }   
            
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(freeDailyRisk <= 0){
         CloseBasket();
         return;
      }
   }
}  

// Function to close all open trades and positions
void CloseBasket()
   {            
    // iterate over positions
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if (ticket <= 0){
            Closing = false;
            continue;
        }
        
      // Prova a chiudere la posizione
        if (!Trade.PositionClose(ticket)){
            int result = Trade.ResultRetcode();
            if (result != TRADE_RETCODE_DONE){
                Print("Failed to close position ", ticket, ". Error code: ", result);
                Closing = true;
            } else {
                Print("Position closed successfully: ", ticket);
                Closing = false;
            }
        }
    }                    

    // iterate over orders                   
    for (int i = OrdersTotal() - 1; i >= 0; i--){
        ulong ticket = OrderGetTicket(i);
        string type = OrderGetString(ORDER_COMMENT);
        Print(type);
        if (ticket <= 0){
            Closing = true;
            continue;
        }                    

        // Prova a cancellare l'ordine
        Sleep(100);  // Aggiungi un ritardo di 100 millisecondi
        if(!Trade.OrderDelete(ticket)){
            int result = Trade.ResultRetcode();
            if (result != TRADE_RETCODE_DONE){
                Print("Failed to delete order ", ticket, ". Error code: ", result);
                Closing = true;
            } else {
                Print("Order deleted successfully: ", ticket);
                Closing = false;
            }
        }   
    }   
    if (!Closing){
        freeDailyRisk = PercentFloatingEquity+equityLimit;
    }
}


//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{     
   UpdatePL();
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Closing = false;
   Ready = false;
   
   
   
   // Create timer and set it in milliseconds
   EventSetTimer(updateFrequency_seconds);
   
   // Create Date Text Object
   CreateObject(0, "dateLabel", OBJ_LABEL, 0, 0, 0, 20, 20, "Bahnschrift SemiBold SemiConden", clrDarkViolet, "Loading data...");
   
   // Create Separator
   string separatorText = "";
   int separatorLenght = 48;
   for(int i = 0; i < separatorLenght; separatorText += "*", i++);
   CreateObject(0, "separator", OBJ_LABEL, 0, 0, 0, 50, 15, "Bahnschrift SemiBold SemiConden", clrYellow, separatorText);
 
   // Create Equity Text Object
   CreateObject(0, "equityBalanceLabel", OBJ_LABEL, 0, 0, 0, 70, 20, "Bahnschrift SemiBold SemiConden", clrWhite, " ");
   
   // Create Equity/Balance Object           
   CreateObject(0, "floatingeEquityLabel", OBJ_LABEL, 0, 0, 0, 110, 15, "Bahnschrift SemiBold SemiConden", clrWhite, " ");         

   // Create Today Total P/L Text Object  
   CreateObject(0, "todayPLlabel", OBJ_LABEL, 0, 0, 0, 140, 20, "Bahnschrift SemiBold SemiConden", clrWhite, " "); 
   
   // Create BalanceLimit Object
   CreateObject(0, "balanceLimitLabel", OBJ_LABEL, 0, 0, 0, 180, 15, "Bahnschrift SemiBold SemiConden", clrWhite, " "); 
   
   // Create Protector On/Off Lable
   CreateObject(0, "protectorLabel", OBJ_LABEL, 0, 0, 0, 210, 15, "Bahnschrift SemiBold SemiConden", clrWhite, " ");
  
   // Create Free Daily Risk Object
   CreateObject(0, "freeDailyRisk", OBJ_LABEL, 0, 0, 0, 240, 15, "Bahnschrift SemiBold SemiConden", clrWhite, " "); 
                  
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
 
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer and delete objects
   EventKillTimer();
   ObjectDelete(0,"dateLabel");
   ObjectDelete(0,"separator");
   ObjectDelete(0,"equityBalanceLabel");
   ObjectDelete(0,"floatingeEquityLabel");
   ObjectDelete(0,"todayPLlabel");
   ObjectDelete(0,"balanceLimitLabel");
   ObjectDelete(0,"freeDailyRisk");  
   ObjectDelete(0,"protectorLabel");
  }
 