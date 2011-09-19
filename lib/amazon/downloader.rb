module Amazon
  class Downloader
    POLITE_GET_TIMER = 1

    attr_accessor :agent

    def initialize(email, password)
      @agent = Mechanize.new
      @time = Time.now
      login(email, password)
    end

    def account_balance
      agent_polite_get("https://sellercentral.amazon.com/gp/payments-account/settlement-summary.html")
      format_money(@agent.page.parser.css('#account_summary_balance_display > td')[1].text)
    end

    def transactions(start_date=nil, end_date=nil)
      transactions_page(start_date, end_date)
      unprocessed_transactions = []
      unprocessed_transactions_page = extract_from_transactions_page
      while next_transactions_page
        unprocessed_transactions.concat(unprocessed_transactions_page)
        unprocessed_transactions_page = extract_from_transactions_page
      end
      unprocessed_transactions.concat(unprocessed_transactions_page)
      process_transactions(unprocessed_transactions)
    end

    protected

    def login(email, password)
      agent_polite_get("https://sellercentral.amazon.com/gp/homepage.html")
      form = @agent.page.forms.first
      form.email = email
      form.password = password
      form.submit
    end

    def transactions_page(start_date = nil, end_date = nil)
      agent_polite_get("https://sellercentral.amazon.com/gp/payments-account/view-transactions.html?ie=UTF8&pageSize=Ten&subview=dateRange&mostRecentLast=0&view=filter")
      form = @agent.page.forms[1]
      form.startDate = format_date(start_date) || form.startDate
      form.endDate = format_date(end_date) || form.endDate
      form.eventType = ''
      form.pageSize = 'Fifty'
      form.submit
    end

    def next_transactions_page 
      @parser = @agent.page.parser
      last_lro = @parser.css('.list-row-odd').last
      next_page_link = last_lro.css('a').last
      if next_page_link && next_page_link.text == "Next"
        @agent.click(next_page_link)
      else
        return false
      end
    end

    def extract_from_transactions_page
      unprocessed_transactions_page = []
      @parser = @agent.page.parser
      @parser.css('.list-row-odd').each_with_index do |lro,i|
        next if i == 0 || i == @parser.css('.list-row-odd').size-1
        transaction = extract_values_from_list_row(lro)
        unprocessed_transactions_page << transaction
      end
      @parser.css('.list-row-even').each do |lre|
        transaction = extract_values_from_list_row(lre)
        unprocessed_transactions_page << transaction
      end
      unprocessed_transactions_page
    end

    def extract_values_from_list_row(lr)
      transaction = lr.css('.data-display-field').map { |dd| dd.text }  
      details_link = lr.css('a').attribute('href').value
      transaction << details_link
      transaction << CGI.parse(details_link)["transaction_id"].first
    end

    def order_details(order_number = '102-9177512-2257812')
      details = {}
      if order_number != '---'
        agent_polite_get("https://sellercentral.amazon.com/gp/orders-v2/details?ie=UTF8&orderID=#{order_number}")
        order_parser = @agent.page.parser
        buyer_name = order_parser.css('td.data-display-field>a').text
        details["Buyer Name"] = buyer_name
      end
      details
    end

    def process_transactions(unprocessed_transactions)
      processed_transactions = unprocessed_transactions.map do |ut|
        {
          "Date" => ut[0],
          "Transaction type" => ut[1],
          "Order ID" => ut[2],
          "Product Details" => ut[3],
          "Total product charges" => format_money(ut[4]),
          "Total promotional rebates" => format_money(ut[5]),
          "Amazon fees" => format_money(ut[6]),
          "Other" => format_money(ut[7]),
          "Total" => format_money(ut[8]),
          "Details Link" => ut[9],
          "Transaction ID" => ut[10],
        }.merge(order_details(ut[2]))
      end
    end

    def format_money(amount)
      amount[1..-1].gsub(',','').to_f
    end

    def format_date(date)
      date.strftime("%D")
    end

    def agent_polite_get(url)
      if (Time.now - @time) < POLITE_GET_TIMER
        sleep (Time.now - @time)
      end
      @agent.get(url)
      @time = Time.now
    end
  end
end
