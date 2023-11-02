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
input double balanceLimit = 2;
input int    updateFrequency_ms = 1;

// DateTime variables
string currentDataString = TimeToString(TimeCurrent(), TIME_DATE); //today
datetime yesterdayTime = TimeCurrent() - PeriodSeconds(PERIOD_D1); 
string yesterdayDataString = TimeToString(yesterdayTime, TIME_DATE); //yesterday

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
double GetPl(datetime date1, datetime date2){
               
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
                  }
               }   
               return total_PL;   
}


// Function to get the text color based on a number (green = positive number, red = negative number)
color GetColor(double pl)
   {
   color plColor = clrWhite;
   if(pl > 0) plColor = clrLimeGreen;
   if(pl < 0) plColor = clrRed;
   return plColor;
   }

// Function called by the timer to update objects 
void UpdatePL(){
               // Initialize account data
               balance = AccountInfoDouble(ACCOUNT_BALANCE);
               equity = AccountInfoDouble(ACCOUNT_EQUITY);
               limit_orders = AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
               open_positions = AccountInfoDouble(ACCOUNT_ASSETS);
               
     
               // Calculate data
               todayPL = GetPl(currentDataString,TimeCurrent()); // Re-download closed trades total amount from date1 to date2
               current_pl = (equity - balance); 
               prevBalance = balance - todayPL - current_pl; // get the previous balance by subtracting/adding today's P/L
  
               // Update Date Object
               ObjectSetString(0, "dateLabel", OBJPROP_TEXT, GetDayOfWeek() + ", " + currentDataString);
               // Update Equity Object
               ObjectSetString(0, "equityLabel", OBJPROP_TEXT, "Equity Limit: " + equityLimit + "% | " +
                                "Equity:" + GetAccountCurrency() +  DoubleToString(equity, 2));     
               // Update Balance Object                 
               ObjectSetString(0, "balanceLabel", OBJPROP_TEXT, "Balance Limit: " + balanceLimit + "% | " + 
                                 "Balance:" + GetAccountCurrency() + DoubleToString(balance, 2));
               // Update colors
               color plColor = GetColor(todayPL);
               color currentPlColor = GetColor(current_pl);
               // Update Date Floating Equity
               ObjectSetString(0,"floatingeEquityLabel", OBJPROP_TEXT, "Floating Equity: " + 
                                  DoubleToString(((current_pl/equity)*100), 2) + "% | Current P/L:" + 
                                  GetAccountCurrency() + DoubleToString(current_pl, 2));  
               ObjectSetInteger(0,"floatingeEquityLabel", OBJPROP_COLOR, currentPlColor);     
               
               //Update Total PL Object              
               // Calculate the total loss by summing the total closed trades and the current floating equity (/equity * 100 for the % value)
               ObjectSetString(0,"todayPL", OBJPROP_TEXT, "Today Loss/Gain: $ " + DoubleToString((todayPL + current_pl),2) +
                                  " | " + DoubleToString((((todayPL+current_pl)/equity) * 100), 2) + "%");             
               ObjectSetInteger(0,"todayPL", OBJPROP_COLOR, plColor);     
               }
//+------------------------------------------------------------------+


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
   // Create timer and set it in milliseconds
   EventSetTimer(updateFrequency_ms);
   balance = AccountInfoDouble(ACCOUNT_BALANCE);
   equity = AccountInfoDouble(ACCOUNT_EQUITY);
   limit_orders = AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
   open_positions = AccountInfoDouble(ACCOUNT_ASSETS);
   todayPL = GetPl(currentDataString,TimeCurrent());

   // Create Date Text Object
   CreateObject(0, "dateLabel", OBJ_LABEL, 0, 0, 0, 20, 20, "Impact", clrYellow, 
                  GetDayOfWeek() + ", " + currentDataString);
   
   // Create Separator
   string separatorText = "";
   int separatorLenght = 35;
   for(int i = 0; i < separatorLenght; separatorText += "-", i++);
   CreateObject(0, "separator", OBJ_LABEL, 0, 0, 0, 50, 15, "Impact", clrAqua, separatorText);
 
   // Create Equity Text Object
   CreateObject(0, "equityLabel", OBJ_LABEL, 0, 0, 0, 80, 15, "Impact", clrWhite, 
                  "Equity Limit: " + equityLimit + "% | " +
                  "Equity:" + GetAccountCurrency() +  DoubleToString(equity, 2));

   // Create Balance Text Object
   CreateObject(0, "balanceLabel", OBJ_LABEL, 0, 0, 0, 110, 15, "Impact", clrWhite, 
                 "Balance Limit: " + balanceLimit + "% | " + 
                 "Balance:"+ GetAccountCurrency() + DoubleToString(balance, 2));
                 
   // Call the GetColor() function to get the text color by the current P/L
   color plColor = GetColor(todayPL);
   color currentPlColor = GetColor(current_pl);
   
   // Create Floating Equity Text Object
   current_pl = (equity - balance); 
   prevBalance = balance - todayPL - current_pl; // get the previous balance by subtracting/adding today's P/L 
   CreateObject(0, "floatingeEquityLabel", OBJ_LABEL, 0, 0, 0, 140, 15, "Impact", GetColor(current_pl), 
                  "Floating Equity: " + DoubleToString(((current_pl/equity)*100),2) + "% | " +
                  "Current P/L:"+ GetAccountCurrency() +  DoubleToString(current_pl,2));                 

   // Create Today Total P/L Text Object  
   // Calculate the total loss by summing the total closed trades and the current floating equity (/equity * 100 for the % value)
   CreateObject(0, "todayPL", OBJ_LABEL, 0, 0, 0, 170, 20, "Impact", GetColor(todayPL), 
                  "Today Loss/Gain:"+ GetAccountCurrency() + DoubleToString((todayPL + current_pl),2) + " | " +
                  DoubleToString(((todayPL+current_pl/equity) * 100),2) + "%"); 
                  
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
   ObjectDelete(0,"equityLabel");
   ObjectDelete(0,"balanceLabel");
   ObjectDelete(0,"floatingeEquityLabel");
   ObjectDelete(0,"todayPL");
  }
  

