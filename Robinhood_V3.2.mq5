
#property strict

string ExpireTime="2023.11.28 00:00";


#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

input string GENERAL_SETTINGS ="General Settings" ; // General Settings


input double LOTS =0.5; // Lot Size
input bool ENABLE_AUTO_LOT=false; // Enable risk calculation
input double RISK_PCT =0.2;// Risk Percent of Free Margin
input int  MAGIC_NUMBER =  20131111; // Magic Number
input int STOPLOSS =250; // Stoploss in pips
input int TAKEPROFIT =25; // TakeProfit in pips
input int BUFFER_PIPS=5; // Buffer Pips
input string TRADE_COMMNET= "Price Action EA"; // Price Action EA
input double MARTINGALE_FACTOR_LOOSE= 10; // Martingale Factor on losing trades
input double MARTINGALE_FACTOR_WIN= 1; //Martingale Factor on winning trades
enum TRADE_MODE
  {
   ONLY_BUY=1,// Buy Only Trades Allowed
   ONLY_SELL=2,// Sell Only Trades Allowed
   BUY_SELL=3 // Buy & Sell Trades Allowed
  };
input TRADE_MODE trade_mode=BUY_SELL; // Trade Mode

input bool CloseLosingTrades = true; //Close Losing Trades
//input double MartingaleMult = 2;     //Martingale Lot Multiplier
input double ProfitAmount = 100;     //USD Amount in total profit

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input bool TRADE_MOVING_AVG=true; //Trade Moving Average (True/Falls)
input bool ENABLE_MA=true; // Enable Moving Average Auto Pilot
input int    InpMovingAveragePeriod =80;   //  Moving Average Period
input ENUM_MA_METHOD MOVING_AVERAGE_MODE =   MODE_EMA; // Moving Average Mode
input int MA_SHIFT = 0; // Moving Average Shift
input ENUM_APPLIED_PRICE APPLIED_PRICE= PRICE_CLOSE; // Applied Price Type
input bool STOP_TRADING_AFTER_WIN=true; // Stop trading after win
input string TRADING_TIME_SETTINGS= "-----------TRADING TIME SETTINGS---------------"; // -----------TRADING TIME SETTINGS---------------
input bool bUseTimeTrading = false; // Use Trading Times? (24/7 if false)

input bool ENABLE_AISAN_SESSION =true; // Asian Session
input bool ENABLE_EUROPIAN_SESSION =true; // EUROPIAN Session
input bool ENABLE_AMERIACAN_SESSION =true; // AMERIACAN Session
input bool ENABLE_OTHER_SESSION =true; // OTHER Session

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input string StartTime    = "01:00";    // Start Time (Broker time)
input string EndTime    = "23:00";   // End Time (Broker time)

input string DAYS_SETTINGS    = "_________________Days Settings_____________";   //_______________ Days Settings_________________
input bool MondayTrade = true; // Monday Trade
input bool TuesdayTrade = true; // Tuesday Trade
input bool WednesdayTrade = true; // Wednesday Trade
input bool ThursdayTrade = true; // Thursday Trade
input bool FridayTrade = true; // Friday Trade
input bool SaturdayTrade = false; // Saturday Trade
input bool SundayTrade = false; // Sunday Trade

int iPipMult[]= {1,10,1,10,1,10,100};
double            m_adjusted_point;             // point value adjusted for 3 or 5 points
CTrade            m_trade;                      // trading object
CSymbolInfo       m_symbol;                     // symbol info object
CPositionInfo     m_position;                   // trade position object
CAccountInfo      m_account;                    // account info wrapper
string globalComment ="";
int wins,losses;
int lastWins,lastLosses;
double lot;
int m_handle_ma1=INVALID_HANDLE;
double m_buff_MA1[2];
double initLot;
double lastLotValue;
input string           InpName="Button";            // Button name
input ENUM_BASE_CORNER InpCorner=CORNER_LEFT_UPPER; // Chart corner for anchoring
input string           InpFont="Arial";             // Font
input int              InpFontSize=14;              // Font size
input color            InpColor=clrBlack;           // Text color
input color            InpBackColor=C'236,233,216'; // Background color
input color            InpBorderColor=clrNONE;      // Border color
input bool             InpState=false;              // Pressed/Released
input bool             InpBack=false;               // Background object
input bool             InpSelection=false;          // Highlight to move
input bool             InpHidden=true;              // Hidden in the object list
input long             InpZOrder=0;                 // Priority for mouse click

input string FILTERS    = "_________________Filters_____________";   //_______________ Filters_________________
input bool Filter1=true;		// Trade Last Candle Sticks
input int Filter1n=75;		// Amount of Candle Sticks

input bool           FilterHigh  = false; // Filter High Events :
input bool           FilterMed  = false; // Filter Med Events :
input bool           FilterLow  = false; // Filter Low Events :
input int            MinBeforeHighEvent = 15; // Minutes before High news :
input int            MinAfterHighEvent = 15; // Minutes after High news :
input int            MinBeforeMedEvent = 15; // Minutes before Med news :
input int            MinAfterMedEvent = 15; // Minutes after Med news :
input int            MinBeforeLowEvent = 15; // Minutes before Low news :
input int            MinAfterLowEvent = 15; // Minutes after Low news :


bool ClosedProfit = false;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int getRandomMagicNumber()
  {
   int rnd = 1000 + MathRand()%1000000;
   if(CheckIfMagicExists(rnd))
      getRandomMagicNumber();
   return rnd;
  }
//+------------------------------------------------------------------+
//|               Calculate optimal lot size                         |
//+------------------------------------------------------------------+
double LotsOptimized()
  {
   int    orders=HistoryDealsTotal();     // history orders total

   losses=0;
   wins=0;
   lot=LOTS;

//--- select lot size
//lot=NormalizeDouble(AccountFreeMargin()*MaximumRisk/1000.0,1);
//--- calcuulate number of losses orders without a break
   if(MARTINGALE_FACTOR_LOOSE>0 && MARTINGALE_FACTOR_WIN>0)
     {
      for(int i=orders-1; i>=0; i--)
        {
         ulong temp_Ticket = HistoryDealGetTicket(i);
         // here check some validity factors of the position-closing deal
         // (symbol, position ID, even MagicNumber if you care...)
         double deal_profit = HistoryDealGetDouble(temp_Ticket, DEAL_PROFIT);
         ulong magic = HistoryDealGetInteger(temp_Ticket, DEAL_MAGIC);
         string  symbol = HistoryDealGetString(temp_Ticket, DEAL_SYMBOL);
         long deal_entry=HistoryDealGetInteger(temp_Ticket,DEAL_ENTRY);

         if(symbol==Symbol() && deal_entry==DEAL_ENTRY_OUT && magic== MAGIC_NUMBER)
           {
            //Print("deal_profit ",deal_profit);
            //---
            if(deal_profit>0)
               break;
            if(deal_profit<=0)
               losses++;
           }
        }

      for(int i=orders-1; i>=0; i--)
        {
         ulong temp_Ticket = HistoryDealGetTicket(i);
         // here check some validity factors of the position-closing deal
         // (symbol, position ID, even MagicNumber if you care...)
         double deal_profit = HistoryDealGetDouble(temp_Ticket, DEAL_PROFIT);
         ulong magic = HistoryDealGetInteger(temp_Ticket, DEAL_MAGIC);
         string  symbol = HistoryDealGetString(temp_Ticket, DEAL_SYMBOL);
         long deal_entry=HistoryDealGetInteger(temp_Ticket,DEAL_ENTRY);

         if(symbol==Symbol() && deal_entry==DEAL_ENTRY_OUT && magic== MAGIC_NUMBER)
           {
            //Print("deal_profit ",deal_profit);
            //---
            if(deal_profit>0)
               wins++;
            if(deal_profit<0)
               break;
           }
        }

      if(CloseLosingTrades)
        {
         if((TotalHistoryOrders()>1 && wins==1 && losses==0) || (wins==0 && losses==0))
           {
            if(ENABLE_AUTO_LOT)
              {
               double risk = AccountInfoDouble(ACCOUNT_MARGIN_FREE)*RISK_PCT/100;
               initLot = NormalizeDouble(RiskToLot(risk),2);
               //Print("initLot",initLot);
              }
            else
              {
               initLot=LOTS;
              }

            lot=initLot;
           }
         //Print("lastOrderLots ",lastOrderLots());
         else
            if(losses>=1)
              {
               lot=NormalizeDouble(lastOrderLots()*MARTINGALE_FACTOR_LOOSE,2);
               //Print("calculated lots ",lot);
              }
            else
               if(wins>=1)
                 {
                  lot=NormalizeDouble(lastOrderLots()*MARTINGALE_FACTOR_WIN,2);
                 }
        }
      else
        {
         if(ENABLE_AUTO_LOT)
           {
            double risk = AccountInfoDouble(ACCOUNT_MARGIN_FREE)*RISK_PCT/100;
            initLot = NormalizeDouble(RiskToLot(risk),2);
            //Print("initLot",initLot);
           }
         else
           {
            initLot=LOTS;
           }

         lot=initLot;
        }
     }

//--- return lot size
   if(lot<SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN))
      lot=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);

   if(lot>SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX))
      lot=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);

//if(lot<LOTS)
//   lot=LOTS;

   return(lot);
  }
//+------------------------------------------------------------------+
//|           Check the time start and end                           |
//+------------------------------------------------------------------+
bool CheckTimeStartEnd()
  {
   MqlDateTime dt;
   datetime dCurrentTime =TimeCurrent();
   datetime nextDay,previousDay;
   bool bCanTradeLocal=false;
   if(dt.day_of_week==5)
      nextDay = iTime(Symbol(),PERIOD_CURRENT,0) + 60 * 60 * 72;
   else
      nextDay = iTime(Symbol(),PERIOD_CURRENT,0) + 60 * 60 * 24;
   if(dt.day_of_week==1)
      previousDay = iTime(Symbol(),PERIOD_CURRENT,0) - 60 * 60 * 24;
   else
      previousDay = iTime(Symbol(),PERIOD_CURRENT,0) - 60 * 60 * 72;
   datetime time_tradestart,time_tradeend;
   string startHourArr[2],endHourArr[2];
   StringSplit(StartTime,':',startHourArr);
   StringSplit(EndTime,':',endHourArr);
   datetime firstDate =iTime(Symbol(),PERIOD_CURRENT,0);
   datetime secondDate = iTime(Symbol(),PERIOD_CURRENT,0);
   if(StringToInteger(startHourArr[0])>StringToInteger(endHourArr[0]))
     {
      if(dt.hour>StringToInteger(startHourArr[0]))
        {
         firstDate =iTime(Symbol(),PERIOD_CURRENT,0);
         secondDate=nextDay;
        }
      else
        {
         firstDate =previousDay;
         secondDate=iTime(Symbol(),PERIOD_CURRENT,0);
        }
     }
   time_tradestart = StringToTime(TimeToString(firstDate,TIME_DATE) + " "  + StartTime);
   time_tradeend = StringToTime(TimeToString(secondDate,TIME_DATE) + " "  + EndTime);
   if(ENABLE_AISAN_SESSION)
     {
      time_tradestart = StringToTime(TimeToString(iTime(Symbol(),PERIOD_CURRENT,0),TIME_DATE) + " "  + "23:00");
      time_tradeend = StringToTime(TimeToString(nextDay,TIME_DATE) + " "  + "8:00");
     }
   globalComment+="startTime "+TimeToString(time_tradestart)+"\n";
   globalComment+="endTime "+TimeToString(time_tradeend)+"\n";
   if(bUseTimeTrading && !bCanTradeLocal)
     {
      if(dCurrentTime > time_tradestart && dCurrentTime < time_tradeend)
        {
         bCanTradeLocal = true;
        }
     }
   else
     {
      bCanTradeLocal = true;
     }
   if(ENABLE_EUROPIAN_SESSION)
     {
      time_tradestart = StringToTime(TimeToString(iTime(Symbol(),PERIOD_CURRENT,0),TIME_DATE) + " "  + "07:00");
      time_tradeend = StringToTime(TimeToString(iTime(Symbol(),PERIOD_CURRENT,0),TIME_DATE) + " "  + "16:00");
     }
   if(bUseTimeTrading && !bCanTradeLocal)
     {
      if(dCurrentTime > time_tradestart && dCurrentTime < time_tradeend)
        {
         bCanTradeLocal = true;
        }
     }
   else
     {
      bCanTradeLocal = true;
     }
   if(ENABLE_AMERIACAN_SESSION)
     {
      time_tradestart = StringToTime(TimeToString(iTime(Symbol(),PERIOD_CURRENT,0),TIME_DATE) + " "  + "12:00");
      time_tradeend = StringToTime(TimeToString(iTime(Symbol(),PERIOD_CURRENT,0),TIME_DATE) + " "  + "20:00");
     }
   if(bUseTimeTrading && !bCanTradeLocal)
     {
      if(dCurrentTime > time_tradestart && dCurrentTime < time_tradeend)
        {
         bCanTradeLocal = true;
        }
     }
   else
     {
      bCanTradeLocal = true;
     }
   if(ENABLE_OTHER_SESSION)
     {
      time_tradestart = StringToTime(TimeToString(firstDate,TIME_DATE) + " "  + StartTime);
      time_tradeend = StringToTime(TimeToString(secondDate,TIME_DATE) + " "  + EndTime);
     }
   if(bUseTimeTrading && !bCanTradeLocal)
     {
      if(dCurrentTime > time_tradestart && dCurrentTime < time_tradeend)
        {
         bCanTradeLocal = true;
        }
     }
   else
     {
      bCanTradeLocal = true;
     }

   return bCanTradeLocal;
  }
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
	/*if( TimeCurrent()>=(datetime)ExpireTime )
	{
		Alert("The EA expired");
		return INIT_FAILED;
	}*/
  
//---
   m_trade.SetAsyncMode(true);
//---

   RequestTradeHistory();
//MAGIC_NUMBER= getRandomMagicNumber();
//--- chart window size
   long x_distance;
   long y_distance;
   m_symbol.Name(Symbol());

   long digits_adjust=1;
   if(m_symbol.Digits()==3 || m_symbol.Digits()==5)
      digits_adjust=10;
   m_adjusted_point=m_symbol.Point()*digits_adjust;


//--- set window size
   if(!ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0,x_distance))
     {
      Print("Failed to get the chart width! Error code = ",GetLastError());
      return(INIT_FAILED);
     }
   if(!ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0,y_distance))
     {
      Print("Failed to get the chart height! Error code = ",GetLastError());
      return(INIT_FAILED);
     }
//--- create EMA indicator and add it to collection
   if(m_handle_ma1==INVALID_HANDLE)
      if((m_handle_ma1=iMA(NULL,0,InpMovingAveragePeriod,MA_SHIFT,MOVING_AVERAGE_MODE,APPLIED_PRICE))==INVALID_HANDLE)
        {
         printf("Error creating EMA indicator");
         return(INIT_FAILED);
        }

   int x_step=(int)x_distance/32;
   int y_step=(int)y_distance/32;
//--- set the button coordinates and its size
   int x=(int)x_distance/32;
   int y=(int)y_distance/3;
   int x_size=(int)x_distance*2/16;
   int y_size=(int)y_distance*2/16;
//--- create the button
   if(!ButtonCreate(ChartID(),"EA-BUY",0,x,y,x_size,y_size,InpCorner,"Buy",InpFont,InpFontSize,
                    InpColor,clrGreen,InpBorderColor,InpState,InpBack,InpSelection,InpHidden,InpZOrder))
     {
      return(INIT_FAILED);
     }
   if(!ButtonCreate(ChartID(),"EA-SELL",0,x + x_size+10,y,x_size,y_size,InpCorner,"Sell",InpFont,InpFontSize,
                    InpColor,clrRed,InpBorderColor,InpState,InpBack,InpSelection,InpHidden,InpZOrder))
     {
      return(INIT_FAILED);
     }//---

//---

   ClosedProfit = false;

//--- redraw the chart
   ChartRedraw();
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RequestTradeHistory()
  {
   datetime time_local=TimeCurrent();
   HistorySelect(0,TimeCurrent());
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   if(!CloseLosingTrades)
      MonitorMartingale();
//---

   RequestTradeHistory();
   globalComment="";
   m_symbol.Name(Symbol());
   m_trade.SetExpertMagicNumber(MAGIC_NUMBER);  // magic
   globalComment+="Magic Number "+(string)MAGIC_NUMBER+"\n";

   if(!m_symbol.RefreshRates())
      return;

   if(BarsCalculated(m_handle_ma1)<2)
      return;
   if(CopyBuffer(m_handle_ma1,0,0,2,m_buff_MA1)!=2)
      return;

   bool bCanTrade = true;

   bCanTrade =CheckTimeStartEnd();
   if(!bCanTrade)
     {
      globalComment+="Out of trading time!!";
      Comment(globalComment);
      return ;
     }
   bCanTrade =TradeAllowedforThisDay();

   if(!bCanTrade)
     {
      globalComment+="Trading is not allowed today!!";
      Comment(globalComment);
      return;
     }

   double close = iClose(Symbol(),PERIOD_CURRENT,0);
   double lots = LotsOptimized();
   globalComment+="wins "+(string)wins+"\n";
   globalComment+="losses "+(string)losses+"\n";
   globalComment+="initlot "+(string)initLot+"\n";

   if(STOP_TRADING_AFTER_WIN && (wins>=1 || (!CloseLosingTrades && ClosedProfit)))
     {
      globalComment+="Trade won no more trades !!";
      Comment(globalComment);
      return;
     }

   if(TotalPositions()==0)
     {
      if(losses>=1)
        {
         if(lastOrderType()==DEAL_TYPE_BUY)
           {
            Print("Opening trade #1");
            double price = m_symbol.Ask();
            double sl = price- STOPLOSS*m_adjusted_point;
            double tp = price + TAKEPROFIT*m_adjusted_point;
			
			if( IsFiltersOk(ORDER_TYPE_BUY) )
			{
	            if(m_trade.Buy(lots,m_symbol.Name(),price,sl,tp,TRADE_COMMNET))
	               Print("Buy opened successfully");
	            else
	               Print("Error openning Buy order: Lot:",lots," | Price:",price," | SL:",sl," | TP:",tp);
			}
            Sleep(800);
           }
         if(lastOrderType()==DEAL_TYPE_SELL)
           {
            Print("Opening trade #2");
            double price = m_symbol.Bid();
            double sl = price+ STOPLOSS*m_adjusted_point;
            double tp = price - TAKEPROFIT*m_adjusted_point;

			if( IsFiltersOk(ORDER_TYPE_SELL) )
			{
	            if(m_trade.Sell(lots,m_symbol.Name(),price,sl,tp,TRADE_COMMNET))
	               Print("Sell opened successfully");
	            else
	               Print("Error openning Sell order: Lot:",lots," | Price:",price," | SL:",sl," | TP:",tp);
			}
			
            Sleep(800);
           }
        }
      else
        {
         if(wins<=1 && ENABLE_MA)
           {
            if(trade_mode!=ONLY_SELL && iClose(Symbol(),PERIOD_CURRENT,0)>m_buff_MA1[0])
              {
               Print("Opening trade #3");
               double price = m_symbol.Ask();
               double sl = price- STOPLOSS*m_adjusted_point;
               double tp = price + TAKEPROFIT*m_adjusted_point;

			if( IsFiltersOk(ORDER_TYPE_BUY) )
			{
	               if(m_trade.Buy(lots,m_symbol.Name(),price,sl,tp,TRADE_COMMNET))
	                  Print("Buy opened successfully");
	               else
	                  Print("Error openning Buy order: Lot:",lots," | Price:",price," | SL:",sl," | TP:",tp);
			}
			
               Sleep(800);
              }
            else
               if(trade_mode!=ONLY_BUY && iClose(Symbol(),PERIOD_CURRENT,0)<m_buff_MA1[0])
                 {
                  Print("Opening trade #4");
                  double price = m_symbol.Bid();
                  double sl = price+ STOPLOSS*m_adjusted_point;
                  double tp = price - TAKEPROFIT*m_adjusted_point;

				if( IsFiltersOk(ORDER_TYPE_SELL) )
				{
	                  if(m_trade.Sell(lots,m_symbol.Name(),price,sl,tp,TRADE_COMMNET))
	                     Print("Sell opened successfully");
	                  else
	                     Print("Error openning Sell order: Lot:",lots," | Price:",price," | SL:",sl," | TP:",tp);
				}
				
                  Sleep(800);
                 }
           }
         else
           {
            if((ENABLE_MA && wins>1) || (!ENABLE_MA && wins>=1))
              {
               Comment(globalComment);
               if(lastOrderType()==DEAL_TYPE_SELL)
                 {
                  Print("Opening trade #5");
                  double price = m_symbol.Ask();
                  double sl = price- STOPLOSS*m_adjusted_point;
                  double tp = price + TAKEPROFIT*m_adjusted_point;

				if( IsFiltersOk(ORDER_TYPE_BUY) )
				{
	                  if(m_trade.Buy(lots,m_symbol.Name(),price,sl,tp,TRADE_COMMNET))
	                     Print("Buy opened successfully");
	                  else
	                     Print("Error openning Buy order: Lot:",lots," | Price:",price," | SL:",sl," | TP:",tp);
				}
				
                  Sleep(800);
                 }
               if(lastOrderType()==DEAL_TYPE_BUY)
                 {
                  Print("Opening trade #6");
                  double price = m_symbol.Bid();
                  double sl = price+ STOPLOSS*m_adjusted_point;
                  double tp = price - TAKEPROFIT*m_adjusted_point;

				if( IsFiltersOk(ORDER_TYPE_SELL) )
				{
	                  if(m_trade.Sell(lots,m_symbol.Name(),price,sl,tp,TRADE_COMMNET))
	                     Print("Sell opened successfully");
	                  else
	                     Print("Error openning Sell order: Lot:",lots," | Price:",price," | SL:",sl," | TP:",tp);
				}
                  Sleep(800);
                 }
              }
           }
        }
     }
   Comment(globalComment);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MonitorMartingale()
  {
   color TPColor = clrGreen;
   color SLColor = clrRed;

   bool TradeOn = false;

   double TheProfit=0;
   ulong MostRecentTrade = -1;

   int TheCounter=0;

   double Commisions=0;

   for(int i=0; i<PositionsTotal(); i++)
     {
      if(m_position.SelectByIndex(i) && m_position.Symbol()==Symbol())
        {
         double TheCommisions = GetCommision(m_position.Time(),m_position.Volume(),m_position.PriceOpen())*2;

         TheProfit+=m_position.Profit()+m_position.Swap()+TheCommisions;

         Commisions+=TheCommisions;

         MostRecentTrade = m_position.Ticket();
         TheCounter++;
        }
     }

   if(ProfitAmount>0 && TheProfit>=ProfitAmount && TheCounter>0)
     {
      Print("Profit target reached. Target = ",ProfitAmount," || Profit = ",TheProfit," >>> Closing trades...");

      CloseAll();

      Del("-:SL:-");
      Del("-:TP:-");

      ClosedProfit = true;

      return;
     }

//---

   RemoveClosed();

   for(int i=0; i<PositionsTotal(); i++)
     {
      if(m_position.SelectByIndex(i) && m_position.Symbol()==Symbol() && MostRecentTrade != m_position.Ticket())
        {
         ObjectDelete(0,(string)m_position.Ticket()+"-:SL:-");
         ObjectDelete(0,(string)m_position.Ticket()+"-:TP:-");
        }
     }

//---

   for(int i=0; i<PositionsTotal(); i++)
     {
      if(m_position.SelectByIndex(i) && m_position.Symbol()==Symbol())
        {
         TradeOn = true;

         double TheAsk = SymbolInfoDouble(m_position.Symbol(),SYMBOL_ASK);
         double TheBid = SymbolInfoDouble(m_position.Symbol(),SYMBOL_BID);

         string TheTicket = (string)m_position.Ticket();

         int TheType = m_position.PositionType();

         double TheLots = NormalizeDouble(m_position.Volume()*MARTINGALE_FACTOR_LOOSE,2);

         if(TheLots<SymbolInfoDouble(m_position.Symbol(),SYMBOL_VOLUME_MIN))
            TheLots = SymbolInfoDouble(m_position.Symbol(),SYMBOL_VOLUME_MIN);
         else
            if(TheLots>SymbolInfoDouble(m_position.Symbol(),SYMBOL_VOLUME_MAX))
               TheLots = SymbolInfoDouble(m_position.Symbol(),SYMBOL_VOLUME_MAX);

         bool ModifyFunc = false;

         if(m_position.Comment()==TRADE_COMMNET)
           {
            if(m_position.StopLoss()!=NULL && m_position.StopLoss()!=0)
              {
               CreateLine(TheTicket+"-:SL:-",m_position.StopLoss(),SLColor,TheTicket+"-Stoploss");
               ModifyFunc = true;
              }

            if(ModifyFunc)
               m_trade.PositionModify((ulong)TheTicket,NULL,m_position.TakeProfit());
           }
         else
           {
            if(m_position.StopLoss()!=NULL && m_position.StopLoss()!=0)
              {
               CreateLine(TheTicket+"-:SL:-",m_position.StopLoss(),SLColor,TheTicket+"-Stoploss");
               ModifyFunc = true;
              }

            if(m_position.TakeProfit()!=NULL && m_position.TakeProfit()!=0)
              {
               CreateLine(TheTicket+"-:TP:-",m_position.TakeProfit(),TPColor,TheTicket+"-Takeprofit");
               ModifyFunc = true;
              }

            if(ModifyFunc)
               m_trade.PositionModify((ulong)TheTicket,NULL,NULL);
           }

         if(m_position.Comment()==TRADE_COMMNET && RunningTrade((ulong)TheTicket) &&
            m_position.StopLoss()!=NULL && m_position.StopLoss()!=0 && m_position.TakeProfit()!=NULL && m_position.TakeProfit()!=0)
           {
            m_trade.PositionModify((ulong)TheTicket,NULL,NULL);
           }

         //---

         int Retries = 5;

         if(TheType==POSITION_TYPE_BUY)
           {
            double TheSL = ObjectGetDouble(0,TheTicket+"-:SL:-",OBJPROP_PRICE);
            double TheTP = ObjectGetDouble(0,TheTicket+"-:TP:-",OBJPROP_PRICE);

            if(ObjectFind(0,TheTicket+"-:TP:-")==0 && !RunningTrade((ulong)TheTicket))
               if(TheAsk>=TheTP)
                 {
                  //Buy Trade

                  Print("Buy above TP");

                  for(int q=0; q<Retries; q++)
                    {
                     double price = m_symbol.Ask();
                     double sl = price- STOPLOSS*m_adjusted_point;
                     double tp = price + TAKEPROFIT*m_adjusted_point;

                     if(m_trade.Buy(TheLots,m_symbol.Name(),price,sl,tp,"#"+TheTicket))
                       {
                        ObjectDelete(0,TheTicket+"-:TP:-");
                        ObjectDelete(0,TheTicket+"-:SL:-");
                        break;
                       }
                     else
                        continue;
                    }

                  break;
                 }

            if(ObjectFind(0,TheTicket+"-:SL:-")==0 && !RunningTrade((ulong)TheTicket))
               if(TheBid<=TheSL)
                 {
                  //Sell Trade

                  Print("Sell below SL");

                  for(int q=0; q<Retries; q++)
                    {
                     double price = m_symbol.Bid();
                     double sl = price+ STOPLOSS*m_adjusted_point;
                     double tp = price - TAKEPROFIT*m_adjusted_point;

                     if(m_trade.Sell(TheLots,m_symbol.Name(),price,sl,tp,"#"+TheTicket))
                       {
                        ObjectDelete(0,TheTicket+"-:TP:-");
                        ObjectDelete(0,TheTicket+"-:SL:-");
                        break;
                       }
                     else
                        continue;
                    }

                  break;
                 }
           }

         //---

         if(TheType==POSITION_TYPE_SELL)
           {
            double TheSL = ObjectGetDouble(0,TheTicket+"-:SL:-",OBJPROP_PRICE);
            double TheTP = ObjectGetDouble(0,TheTicket+"-:TP:-",OBJPROP_PRICE);

            if(ObjectFind(0,TheTicket+"-:SL:-")==0 && !RunningTrade((ulong)TheTicket))
               if(TheAsk>=TheSL)
                 {
                  //Buy Trade

                  Print("Buy above SL >> ",TheSL);

                  for(int q=0; q<Retries; q++)
                    {
                     double price = m_symbol.Ask();
                     double sl = price- STOPLOSS*m_adjusted_point;
                     double tp = price + TAKEPROFIT*m_adjusted_point;

                     if(m_trade.Buy(TheLots,m_symbol.Name(),price,sl,tp,"#"+TheTicket))
                       {
                        ObjectDelete(0,TheTicket+"-:TP:-");
                        ObjectDelete(0,TheTicket+"-:SL:-");
                        break;
                       }
                     else
                        continue;
                    }

                  break;
                 }

            if(ObjectFind(0,TheTicket+"-:TP:-")==0 && !RunningTrade((ulong)TheTicket))
               if(TheBid<=TheTP)
                 {
                  //Sell Trade

                  Print("Sell below TP");

                  for(int q=0; q<Retries; q++)
                    {
                     double price = m_symbol.Bid();
                     double sl = price+ STOPLOSS*m_adjusted_point;
                     double tp = price - TAKEPROFIT*m_adjusted_point;

                     if(m_trade.Sell(TheLots,m_symbol.Name(),price,sl,tp,"#"+TheTicket))
                       {
                        ObjectDelete(0,TheTicket+"-:TP:-");
                        ObjectDelete(0,TheTicket+"-:SL:-");
                        break;
                       }
                     else
                        continue;
                    }

                  break;
                 }
           }
        }
     }

//---

   if(!TradeOn)
     {
      Del("-:SL:-");
      Del("-:TP:-");
     }

//---

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetCommision(datetime TheTime, double TheLot, double ThePrice)
  {
   HistorySelect(iTime(_Symbol,PERIOD_D1,1),TimeCurrent());

   ulong ticket = 0;

   for(int i=0; i<HistoryDealsTotal(); i++)
     {
      //--- try to get deals ticket
      if((ticket=HistoryDealGetTicket(i))>0 &&
         (datetime)HistoryDealGetInteger(ticket,DEAL_TIME)==TheTime &&
         HistoryDealGetDouble(ticket,DEAL_VOLUME)==TheLot &&
         HistoryDealGetDouble(ticket,DEAL_PRICE)==ThePrice &&
         HistoryDealGetString(ticket,DEAL_SYMBOL)==Symbol())
        {
         return HistoryDealGetDouble(ticket,DEAL_COMMISSION);
        }
     }

   return 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool RunningTrade(ulong TheTicket)
  {
   for(int i=0; i<PositionsTotal(); i++)
     {
      if(m_position.SelectByIndex(i) && m_position.Symbol()==Symbol() && StringFind(m_position.Comment(),(string)TheTicket)!=-1)
        {
         return true;
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseAllx()
  {
   m_trade.SetAsyncMode(true);

   for(int i=0; i<PositionsTotal(); i++)
     {
      if(m_position.SelectByIndex(i) && m_position.Symbol()==Symbol())
        {
         if(m_trade.PositionClose(m_position.Ticket()))
            i--;
         else
            Print("Error closing trade #"+(string)m_position.Ticket());
        }
     }
  }

#include <Arrays\ArrayLong.mqh>
CArrayLong     m_arr_tickets;// array tickets

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseAll()
  {
//---
   m_trade.SetAsyncMode(true);

   uint              RTOTAL         = 5;
//---
   for(uint retry=0; retry<RTOTAL && !IsStopped(); retry++)
     {
      bool result = true;
      //--- Collect and Close Method (FIFO-Compliant, for US brokers)
      //--- Tickets are processed starting with the oldest one.
      m_arr_tickets.Shutdown();
      for(int i=0; i<PositionsTotal() && !IsStopped(); i++)
        {
         ResetLastError();
         if(!m_position.SelectByIndex(i))
           {
            PrintFormat("> Error: selecting position with index #%d failed. Error Code: %d",i,GetLastError());
            result = false;
            continue;
           }

         //--- build array of position tickets to be processed
         if(m_position.Symbol()==Symbol() && m_position.Magic()==MAGIC_NUMBER && !m_arr_tickets.Add(m_position.Ticket()))
           {
            PrintFormat("> Error: adding position ticket #%I64u failed.",m_position.Ticket());
            result = false;
           }
        }

      //--- now process the list of tickets stored in the array
      for(int i=0; i<m_arr_tickets.Total() && !IsStopped(); i++)
        {
         ResetLastError();
         ulong m_curr_ticket = m_arr_tickets.At(i);
         if(!m_position.SelectByTicket(m_curr_ticket))
           {
            PrintFormat("> Error: selecting position ticket #%I64u failed. Error Code: %d",m_curr_ticket,GetLastError());
            result = false;
            continue;
           }
         //--- check freeze level
         int freeze_level = (int)SymbolInfoInteger(m_position.Symbol(),SYMBOL_TRADE_FREEZE_LEVEL);
         double point = SymbolInfoDouble(m_position.Symbol(),SYMBOL_POINT);
         bool TP_check = (MathAbs(m_position.PriceCurrent() - m_position.TakeProfit()) > freeze_level * point);
         bool SL_check = (MathAbs(m_position.PriceCurrent() - m_position.StopLoss()) > freeze_level * point);
         if(!TP_check || !SL_check)
           {
            PrintFormat("> Error: closing position ticket #%I64u on %s is prohibited. Position TP or SL is too close to activation price [FROZEN].",m_position.Ticket(),m_position.Symbol());
            result = false;
            continue;
           }
         //--- trading object
         m_trade.SetExpertMagicNumber(m_position.Magic());
         m_trade.SetTypeFillingBySymbol(m_position.Symbol());
         //--- close positions
         if(m_trade.PositionClose(m_position.Ticket()) && (m_trade.ResultRetcode()==TRADE_RETCODE_DONE || m_trade.ResultRetcode()==TRADE_RETCODE_PLACED))
           {
            PrintFormat("Position ticket #%I64u on %s to be closed.",m_position.Ticket(),m_position.Symbol());
            PlaySound("expert.wav");
           }
         else
           {
            PrintFormat("> Error: closing position ticket #%I64u on %s failed. Retcode=%u (%s)",m_position.Ticket(),m_position.Symbol(),m_trade.ResultRetcode(),m_trade.ResultComment());
            result = false;
           }
        }

      if(result)
         break;
      Sleep(1000);
      PlaySound("timeout.wav");
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CreateLine(string TheName, double ThePrice, color TheColor,string TheTip)
  {
   bool TheReturn = false;

   if(ObjectFind(0,TheName)==-1)
     {
      if(ObjectCreate(0, TheName, OBJ_HLINE, 0, 0, ThePrice))
        {
         TheReturn = true;
         Print("Created >>> "+TheName," @ ",ThePrice);
        }
      else
         Print("Error creating >>> "+TheName," >> ",GetLastError());

      ObjectSetInteger(0, TheName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, TheName, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, TheName, OBJPROP_BACK, true);
      ObjectSetInteger(0, TheName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, TheName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, TheName, OBJPROP_HIDDEN, false);
     }

   ObjectSetInteger(0, TheName, OBJPROP_COLOR, TheColor);
   ObjectSetDouble(0,TheName,OBJPROP_PRICE,ThePrice);

   ObjectSetString(0,TheName,OBJPROP_TOOLTIP,TheTip);

   return TheReturn;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Del(string r6)
  {
   int t1;

   t1=ObjectsTotal(0);
   while(t1>=0)
     {
      if(StringFind(ObjectName(0,t1),r6,0)!=-1)
        {
         ObjectDelete(0,ObjectName(0,t1));
        }
      t1--;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RemoveClosed()
  {
   int t1;

   t1=ObjectsTotal(0);
   while(t1>=0)
     {
      if(StringFind(ObjectName(0,t1),"-:SL:-",0)!=-1 || StringFind(ObjectName(0,t1),"-:TP:-",0)!=-1)
        {
         string StringDiv[];

         int StringCount = StringSplit(ObjectName(0,t1),StringGetCharacter("-",0),StringDiv);

         if(StringCount>0 && !PositionSelectByTicket((ulong)StringDiv[0]))
           {
            ObjectDelete(0,ObjectName(0,t1));
           }
        }
      t1--;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TotalPositions()
  {
   int count=0;
   for(int i=0; i<PositionsTotal(); i++)
     {
      if(m_position.SelectByIndex(i)  && m_position.Symbol()==Symbol())
         count++;
     }

   return count;
  }

//+------------------------------------------------------------------+
//|         Calculte the lot amount based on risk                    |
//+------------------------------------------------------------------+
double RiskToLot(double risk)
  {
   m_symbol.Name(Symbol());
   long digits=m_symbol.Digits();
   double delta = STOPLOSS*m_adjusted_point;
   double balance = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double pointValue = m_symbol.Point();
   double tickVaue =m_symbol.TickValue();

   if(balance==0)
      return(0);

   double dRiskCapital=risk/100*balance;

   return(risk*iPipMult[digits]*pointValue/(delta*tickVaue*iPipMult[digits]));
  }


//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool TradeAllowedforThisDay()
  {
   MqlDateTime dt;
   datetime time_current=TimeCurrent();
   datetime time_local=TimeLocal();
   TimeToStruct(time_current,dt);
//Alert(dt.day_of_week);
   if((int) dt.day_of_week == 1 && MondayTrade == true)
     {
      return true;
     }

   if((int) dt.day_of_week== 2 && TuesdayTrade == true)
     {
      return true;
     }

   if((int) dt.day_of_week== 3 && WednesdayTrade == true)
     {
      return true;
     }

   if((int) dt.day_of_week== 4 && ThursdayTrade == true)
     {
      return true;
     }

   if((int) dt.day_of_week== 5 && FridayTrade == true)
     {
      return true;
     }
   if((int) dt.day_of_week== 6 && SaturdayTrade == true)
     {
      return true;
     }
   if((int) dt.day_of_week== 7 && SundayTrade == true)
     {
      return true;
     }
   return false;

  }
//+------------------------------------------------------------------+
//|            is the last order was loss                            |
//+------------------------------------------------------------------+
bool isLastOrderLoss()
  {
   double deal_profit=0.0;
   for(int i = (HistoryDealsTotal() - 1); i >= 0; i--)
     {
      ulong ticket = HistoryDealGetTicket(i);
      long deal_magic=HistoryDealGetInteger(ticket,DEAL_MAGIC);
      deal_profit=HistoryDealGetDouble(ticket,DEAL_PROFIT);
      double deal_swap=HistoryDealGetDouble(ticket,DEAL_SWAP);
      double deal_commision=HistoryDealGetDouble(ticket,DEAL_COMMISSION);
      string symbol=HistoryDealGetString(ticket,DEAL_SYMBOL);
      long deal_entry=HistoryDealGetInteger(ticket,DEAL_ENTRY);
      if(symbol==Symbol() && deal_entry==DEAL_ENTRY_OUT && deal_magic== MAGIC_NUMBER)
         break;
     }
   return deal_profit>0;
  }

//+------------------------------------------------------------------+
//|            is the last order was loss                            |
//+------------------------------------------------------------------+
double lastOrderLots()
  {
   double volume=0.01;
   for(int i = (HistoryDealsTotal() - 1); i >= 0; i--)
     {
      ulong ticket = HistoryDealGetTicket(i);
      long deal_magic=HistoryDealGetInteger(ticket,DEAL_MAGIC);
      double deal_swap=HistoryDealGetDouble(ticket,DEAL_SWAP);
      double deal_commision=HistoryDealGetDouble(ticket,DEAL_COMMISSION);
      string symbol=HistoryDealGetString(ticket,DEAL_SYMBOL);
      volume=HistoryDealGetDouble(ticket,DEAL_VOLUME);
      long deal_entry=HistoryDealGetInteger(ticket,DEAL_ENTRY);
      if(symbol==Symbol() && deal_entry==DEAL_ENTRY_OUT && deal_magic== MAGIC_NUMBER)
        {
         break;
        }

     }
   return volume;
  }

//+------------------------------------------------------------------+
//|            is the last order was loss                            |
//+------------------------------------------------------------------+
int lastOrderType()
  {
   int type=-1;

   for(int i = (HistoryDealsTotal() - 1); i >= 0; i--)
     {
      ulong ticket = HistoryDealGetTicket(i);
      long deal_magic=HistoryDealGetInteger(ticket,DEAL_MAGIC);
      double deal_swap=HistoryDealGetDouble(ticket,DEAL_SWAP);
      double deal_commision=HistoryDealGetDouble(ticket,DEAL_COMMISSION);
      string symbol=HistoryDealGetString(ticket,DEAL_SYMBOL);
      type=(int)HistoryDealGetInteger(ticket,DEAL_TYPE);
      long deal_entry=HistoryDealGetInteger(ticket,DEAL_ENTRY);
      if(symbol==Symbol() && deal_entry==DEAL_ENTRY_OUT && deal_magic== MAGIC_NUMBER)
         break;
     }

   return type;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|            is the last order was loss                            |
//+------------------------------------------------------------------+
int  TotalHistoryOrders()
  {
   int  count=0;
   HistorySelect(0,TimeCurrent());
   for(int i = (HistoryDealsTotal() - 1); i >= 0; i--)
     {
      // If the order cannot be selected, throw and log an error.
      ulong ticket = HistoryDealGetTicket(i);
      long deal_magic=HistoryDealGetInteger(ticket,DEAL_MAGIC);
      string symbol=HistoryDealGetString(ticket,DEAL_SYMBOL);
      long deal_entry=HistoryDealGetInteger(ticket,DEAL_ENTRY);
      if(symbol==Symbol() && deal_entry==DEAL_ENTRY_OUT && deal_magic== MAGIC_NUMBER)
         count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
//|            is the last order was loss                            |
//+------------------------------------------------------------------+
bool  CheckIfMagicExists(int magic)
  {
   bool  exists=false;
   HistorySelect(0,TimeCurrent());

   for(int i = (HistoryDealsTotal() - 1); i >= 0; i--)
     {
      // If the order cannot be selected, throw and log an error.
      ulong ticket = HistoryDealGetTicket(i);
      long deal_magic=HistoryDealGetInteger(ticket,DEAL_MAGIC);
      string symbol=HistoryDealGetString(ticket,DEAL_SYMBOL);
      long deal_entry=HistoryDealGetInteger(ticket,DEAL_ENTRY);
      if(symbol==Symbol() && deal_entry==DEAL_ENTRY_OUT && deal_magic== magic)
        {
         Print("Found deal_magic "+(string)deal_magic);
         Print("Found magic "+(string)magic);
         exists=true;
         break;
        }
     }

   return exists;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create the button                                                |
//+------------------------------------------------------------------+
bool ButtonCreate(const long              chart_ID=0,               // chart's ID
                  const string            name="Button",            // button name
                  const int               sub_window=0,             // subwindow index
                  const int               x=0,                      // X coordinate
                  const int               y=0,                      // Y coordinate
                  const int               width=50,                 // button width
                  const int               height=18,                // button height
                  const ENUM_BASE_CORNER  corner=CORNER_LEFT_UPPER, // chart corner for anchoring
                  const string            text="Button",            // text
                  const string            font="Arial",             // font
                  const int               font_size=10,             // font size
                  const color             clr=clrBlack,             // text color
                  const color             back_clr=C'236,233,216',  // background color
                  const color             border_clr=clrNONE,       // border color
                  const bool              state=false,              // pressed/released
                  const bool              back=false,               // in the background
                  const bool              selection=true,          // highlight to move
                  const bool              hidden=false,              // hidden in the object list
                  const long              z_order=0)                // priority for mouse click
  {
//--- reset the error value
   ResetLastError();
//--- create the button
   if(!ObjectCreate(chart_ID,name,OBJ_BUTTON,sub_window,0,0))
     {
      Print(__FUNCTION__,
            ": failed to create the button! Error code = ",GetLastError());
      return(false);
     }
//--- set button coordinates
   ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,y);
//--- set button size
   ObjectSetInteger(chart_ID,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(chart_ID,name,OBJPROP_YSIZE,height);
//--- set the chart's corner, relative to which point coordinates are defined
   ObjectSetInteger(chart_ID,name,OBJPROP_CORNER,corner);
//--- set the text
   ObjectSetString(chart_ID,name,OBJPROP_TEXT,text);
//--- set text font
   ObjectSetString(chart_ID,name,OBJPROP_FONT,font);
//--- set font size
   ObjectSetInteger(chart_ID,name,OBJPROP_FONTSIZE,font_size);
//--- set text color
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- set background color
   ObjectSetInteger(chart_ID,name,OBJPROP_BGCOLOR,back_clr);
//--- set border color
   ObjectSetInteger(chart_ID,name,OBJPROP_BORDER_COLOR,border_clr);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- set button state
   ObjectSetInteger(chart_ID,name,OBJPROP_STATE,state);
//--- enable (true) or disable (false) the mode of moving the button by mouse
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
//--- successful execution
   return(true);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   bool bCanTrade = true;

   bCanTrade =CheckTimeStartEnd();
   if(!bCanTrade)
     {
      Alert("Out of trading time!!");
      return ;
     }
   bCanTrade =TradeAllowedforThisDay();
   if(!bCanTrade)
     {
      Alert("Trading is not allowed today!!");
      return;
     }
//--- Check the event by pressing a mouse button
   if(id==CHARTEVENT_OBJECT_CLICK)
     {
      string clickedChartObject=sparam;
      //Alert("Clicked",sparam);
      if(ENABLE_AUTO_LOT)
        {
         double risk = AccountInfoDouble(ACCOUNT_MARGIN_FREE)*RISK_PCT/100;
         initLot = NormalizeDouble(RiskToLot(risk),2);
         //Print("initLot",initLot);
        }
      else
        {
         initLot= LOTS;
        }
      //Alert("m_adjusted_point "+STOPLOSS*m_adjusted_point);
      //--- If you click on the object with the name buttonID
      if(clickedChartObject=="EA-BUY")
        {
         m_symbol.RefreshRates();
         if(trade_mode==ONLY_SELL)
           {
            Alert("Buy Trades Not allowed");
            return;
           }
         if(TRADE_MOVING_AVG && iClose(Symbol(),PERIOD_CURRENT,0)<m_buff_MA1[0])
           {
            Alert("Price Below Moving Avg Trades Not allowed");
            return;
           }
         //Alert("Buy Clicked");
         double price = m_symbol.Ask();
         double sl = price- STOPLOSS*m_adjusted_point;
         double tp = price + TAKEPROFIT*m_adjusted_point;
         //m_trade.Buy(initLot,m_symbol.Name(),price,sl,tp,TRADE_COMMNET);
         if(m_account.FreeMarginCheck(m_symbol.Name(),ORDER_TYPE_BUY,initLot,price)<0.0)
            printf("We have no money. Free Margin = %f",m_account.FreeMargin());
         else
           {
            //--- open position
            if(m_trade.PositionOpen(m_symbol.Name(),ORDER_TYPE_BUY,initLot,price,sl,tp,TRADE_COMMNET))
               printf("Position by %s to be opened",m_symbol.Name());
            else
              {
               printf("Error opening SELL position by %s : '%s'",m_symbol.Name(),m_trade.ResultComment());
               printf("Open parameters : price=%f,TP=%f",price,tp);
              }
           }
        }

      if(clickedChartObject=="EA-SELL")
        {
         m_symbol.RefreshRates();
         if(trade_mode==ONLY_BUY)
           {
            Alert("Sell Trades Not allowed");
            return;
           }
         if(TRADE_MOVING_AVG && iClose(Symbol(),PERIOD_CURRENT,0)>m_buff_MA1[0])
           {
            Alert("Price Above Moving Avg Trades Not allowed");
            return;
           }
         double price = m_symbol.Ask();
         double sl = price+ STOPLOSS*m_adjusted_point;
         double tp = price - TAKEPROFIT*m_adjusted_point;
         //m_trade.Sell(initLot,m_symbol.Name(),price,sl,tp,TRADE_COMMNET);
         if(m_account.FreeMarginCheck(m_symbol.Name(),ORDER_TYPE_SELL,initLot,price)<0.0)
            printf("We have no money. Free Margin = %f",m_account.FreeMargin());
         else
           {
            //--- open position
            if(m_trade.PositionOpen(m_symbol.Name(),ORDER_TYPE_SELL,initLot,price,sl,tp,TRADE_COMMNET))
               printf("Position by %s to be opened",m_symbol.Name());
            else
              {
               printf("Error opening SELL position by %s : '%s'",m_symbol.Name(),m_trade.ResultComment());
               printf("Open parameters : price=%f,TP=%f",price,tp);
              }
           }
        }

     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|    This will remove all drawings when ea removed from chart      |
//+------------------------------------------------------------------+
void RemoveEADrawings()
  {
   for(int iObj=ObjectsTotal(ChartID())-1; iObj >= 0; iObj--)
     {
      string obname = ObjectName(ChartID(),iObj);
      //if(StringSubstr(obname,0, 2) =="EA")
      ObjectDelete(ChartID(),obname);
     }
   ;
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectDelete(0,"EA-BUY");
   ObjectDelete(0,"EA-SELL");

   Comment("");
//RemoveEADrawings();
  }
//+------------------------------------------------------------------+


bool IsTradeAllowedByNews()
{
	if( MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION) ) return true;

	int numberstr        = StringLen(Symbol());
	string MainCurr      = StringSubstr(Symbol(),0, numberstr/2);
	string ScndCurr      = StringSubstr(Symbol(), numberstr/2);

	if( FilterHigh==true )
	   	if( EventDodge(MainCurr,MinBeforeHighEvent*60,MinAfterHighEvent*60,CALENDAR_IMPORTANCE_HIGH)
		 || EventDodge(ScndCurr,MinBeforeHighEvent*60,MinAfterHighEvent*60,CALENDAR_IMPORTANCE_HIGH) )
			return false;

	if( FilterMed==true )
	   	if( EventDodge(MainCurr,MinBeforeMedEvent*60,MinAfterMedEvent*60,CALENDAR_IMPORTANCE_MODERATE)
		 || EventDodge(ScndCurr,MinBeforeMedEvent*60,MinAfterMedEvent*60,CALENDAR_IMPORTANCE_MODERATE) )
			return false;

	if( FilterLow==true )
	   	if( EventDodge(MainCurr,MinBeforeLowEvent*60,MinAfterLowEvent*60,CALENDAR_IMPORTANCE_LOW)
		 || EventDodge(ScndCurr,MinBeforeLowEvent*60,MinAfterLowEvent*60,CALENDAR_IMPORTANCE_LOW) )
			return false;
			
	return true;
}
  
bool EventDodge(string pCurrency, datetime pTimeBefore, datetime pTimeAfter,ENUM_CALENDAR_EVENT_IMPORTANCE imp)
  {
   MqlCalendarEvent events[];
   bool EventStop    = false;
   int countMain = CalendarEventByCurrency(pCurrency,events);
   ArrayResize(events,countMain);
   datetime times[];
   int counter1 = 0;
   int counter2 = 0;
   MqlCalendarValue Value[];
   int ValueCount = CalendarValueHistory(Value,TimeTradeServer(),TimeTradeServer()+pTimeBefore,NULL,pCurrency);
   ArrayResize(Value,ValueCount);

   for(int i=0; i < countMain; i++)
     {
      int importance = events[i].importance;
      if(importance == imp)
        {
         counter1++;
         ulong  EventId   = events[i].id;
         string EventName = events[i].name;
         for(int j=0; j < ValueCount; j++)
           {
            if(EventId == Value[j].event_id)
              {
               datetime EventTime = Value[j].time;
               ArrayResize(times,counter2+1);
               times[counter2] = EventTime;
               counter2++;
              }
           }
        }
     }
   int Items = ArraySize(times);
   ArraySort(times);
   for(int i=0; i<Items; i++)
     {
      if(times[i] > TimeTradeServer() && times[i] < (TimeTradeServer() + pTimeBefore + PeriodSeconds(PERIOD_M5)) && (TimeTradeServer() < (times[i]+pTimeAfter)))
        {
         EventStop = true;
        }
     }
   return EventStop;
  }


bool IsFiltersOk(ENUM_ORDER_TYPE OT)
{
	bool Is1Ok=true;
	int i;
	double H,L;
	
	if( Filter1 )
	{
		i=iHighest(Symbol(),Period(),MODE_HIGH,Filter1n,1);
		H=iHigh(Symbol(),Period(),i);
		i=iLowest(Symbol(),Period(),MODE_LOW,Filter1n,1);
		L=iLow(Symbol(),Period(),i);
		
		if( OT==ORDER_TYPE_BUY )
		if( SymbolInfoDouble(Symbol(),SYMBOL_ASK)<=H )
		Is1Ok=false;

		if( OT==ORDER_TYPE_SELL )
		if( SymbolInfoDouble(Symbol(),SYMBOL_BID)>=L )
		Is1Ok=false;
	}
	
	
	if( Is1Ok && IsTradeAllowedByNews() ) return true;
	return false;
}

