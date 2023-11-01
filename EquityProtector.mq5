//+------------------------------------------------------------------+
//|                                              EquityProtector.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

// Inputs
input double equityLimit = 2;
input double balanceLimit = 2;

// DateTime variables
string currentDataString = TimeToString(TimeCurrent(), TIME_DATE);
string currentMinutesString = TimeToString(TimeCurrent(), TIME_MINUTES);
string timeSeconds = TimeToString(TimeCurrent(), TIME_SECONDS);
datetime yesterdayTime = TimeCurrent() - PeriodSeconds(PERIOD_D1);
string yesterdayDataString = TimeToString(yesterdayTime, TIME_DATE);

// Double variables
double balance, equity, current_pl, prevBalance, limit_orders, open_positions, dailyProfit, todayPL;

// String variables
string balanceString, equityString;

string GetDayOfWeek()
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


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   EventSetTimer(1);
   // Initialize account data
   balance = AccountInfoDouble(ACCOUNT_BALANCE);
   equity = AccountInfoDouble(ACCOUNT_EQUITY);
   limit_orders = AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
   open_positions = AccountInfoDouble(ACCOUNT_ASSETS);



   GetPl(yesterdayDataString,yesterdayDataString);
   Print(currentDataString);

   // Date Text Object
   CreateObject(0, "dateLabel", OBJ_LABEL, 0, 0, 0, 20, 20, "Impact", clrYellow, 
                  GetDayOfWeek() + ", " + currentDataString);
   
   // Separator
   string separatorText = "";
   int separatorLenght = 35;
   for(int i = 0; i < separatorLenght; separatorText += "-", i++);
   CreateObject(0, "separator", OBJ_LABEL, 0, 0, 0, 50, 15, "Impact", clrAqua, separatorText);
 
   // Equity Text Object
   CreateObject(0, "equityLabel", OBJ_LABEL, 0, 0, 0, 80, 15, "Impact", clrWhite, 
                  "Equity Limit: " + equityLimit + "% | " +
                  "Equity: $ " +  DoubleToString(equity, 2));

   // Balance Text Object
   CreateObject(0, "balanceLabel", OBJ_LABEL, 0, 0, 0, 110, 15, "Impact", clrWhite, 
                 "Balance Limit: " + balanceLimit + "% | " + 
                 "Balance: $ " + DoubleToString(balance, 2));
 
   color plColor = clrWhite;
   if(todayPL > 0){
      plColor = clrLimeGreen;
   } 
   if(todayPL < 0){
      plColor = clrRed;
   } else plColor = clrWhite;
   
   // Floating Equity Text Object
   todayPL = GetPl(currentDataString,currentDataString);
   current_pl = (equity - balance); 
   prevBalance = balance - todayPL - current_pl; // get the previous balance by subtracting/adding today's P/L
   
   
   Print(current_pl);
   Print(todayPL);

   CreateObject(0, "floatingeEquityLabel", OBJ_LABEL, 0, 0, 0, 140, 15, "Impact", GetColor(current_pl), 
                  "Floating Equity: " + DoubleToString(((current_pl/equity)*100),2) + "% | " +
                  "Current P/L: $ " +  DoubleToString(current_pl,2));                 

   // Today P/L Text Object  
   CreateObject(0, "todayPL", OBJ_LABEL, 0, 0, 0, 170, 20, "Impact", GetColor(todayPL), 
                  "Today Loss/Gain: $ " + DoubleToString(todayPL,2) + " | " +
                  DoubleToString(((todayPL/equity) * 100),2) + "%"); 
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();
   ObjectDelete(0,"dateLabel");
   ObjectDelete(0,"separator");
   ObjectDelete(0,"equityLabel");
   ObjectDelete(0,"balanceLabel");
   ObjectDelete(0,"floatingeEquityLabel");
   ObjectDelete(0,"todayPL");
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
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


double GetPl(datetime date1,datetime date2){
               HistorySelect(date1, date2);
               uint total = HistoryDealsTotal();
               ulong ticket = 0;
               double profit;
               double total_PL;
               datetime time;
               for(uint i = 0; i < total; i++)
               {
                  // Try to get deal's ticket
                  if ((ticket = HistoryDealGetTicket(i)) > 0)
                  {
                     // Get deal's properties  
                     time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
                     profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                     total_PL += profit;
                     Print(time);
                     if (profit >= 0) Print("Profit: ", profit + " " + time);
                     else Print("Loss: ", profit);
                  }
               }   
               Print("Total P/L: ", total_PL);
               
               return total_PL;   
}



color GetColor(double pl){

   color plColor = clrWhite;
   if(pl > 0){
      plColor = clrLimeGreen;
   } 
   if(pl < 0){
      plColor = clrRed;
   } 
   return plColor;
   }

void UpdatePL(){
               // Initialize account data
               balance = AccountInfoDouble(ACCOUNT_BALANCE);
               equity = AccountInfoDouble(ACCOUNT_EQUITY);
               limit_orders = AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
               open_positions = AccountInfoDouble(ACCOUNT_ASSETS);
     
               // Floating Equity Text Object
               todayPL = GetPl(currentDataString,currentDataString);
               current_pl = (equity - balance); 
               prevBalance = balance - todayPL - current_pl; // get the previous balance by subtracting/adding today's P/L
                           
               Print(current_pl);
               Print(todayPL);

            
               // Aggiorna gli oggetti come il Floating Equity Text Object
               ObjectSetString(0, "dateLabel", OBJPROP_TEXT, GetDayOfWeek() + ", " + currentDataString);
               
               ObjectSetString(0, "equityLabel", OBJPROP_TEXT, "Equity Limit: " + equityLimit + "% | " +
                                "Equity: $ " +  DoubleToString(equity, 2));     
                                
               ObjectSetString(0, "balanceLabel", OBJPROP_TEXT, "Balance Limit: " + balanceLimit + "% | " + 
                                 "Balance: $ " + DoubleToString(balance, 2));
               
               color plColor = GetColor(todayPL);
               color currentPlColor = GetColor(current_pl);
              
               
               ObjectSetString(0,"floatingeEquityLabel", OBJPROP_TEXT, "Floating Equity: " + 
                                  DoubleToString(((current_pl/equity)*100), 2) + "% | Current P/L: $ " + 
                                  DoubleToString(current_pl, 2));
                                  
               ObjectSetInteger(0,"floatingeEquityLabel", OBJPROP_COLOR, currentPlColor);                  
               
               ObjectSetString(0,"todayPL", OBJPROP_TEXT, "Today Loss/Gain: $ " + DoubleToString(todayPL, 2) +
                                  " | " + DoubleToString(((todayPL/equity) * 100), 2) + "%");
                                  
               ObjectSetInteger(0,"todayPL", OBJPROP_COLOR, plColor);  
               }

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {   
   UpdatePL();
  }
//+------------------------------------------------------------------+
