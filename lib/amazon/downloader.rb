module Amazon
  class Downloader
    attr_accessor :agent

    def initialize(email, password)
      @agent = Mechanize.new
      login(email, password)
    end

    def account_balance
      @agent.get("https://sellercentral.amazon.com/gp/payments-account/settlement-summary.html")
      format_money(@agent.page.parser.css('#account_summary_balance_display > td')[1].text)
    end

    def transactions(start_date=nil, end_date=nil)
      transactions_page(start_date, end_date)
      unprocessed_transactions = []
      unprocessed_transactions_page = extract_from_transactions_page
      while !unprocessed_transactions_page.empty?
        unprocessed_transactions.concat(unprocessed_transactions_page)
        next_transactions_page
        unprocessed_transactions_page = extract_from_transactions_page
      end
      unprocessed_transactions
      process_transactions(unprocessed_transactions)
    end

    protected

    def login(email, password)
      @agent.get("https://sellercentral.amazon.com/gp/homepage.html")
      form = @agent.page.forms.first
      form.email = email
      form.password = password
      form.submit
    end

    def transactions_page(start_date = nil, end_date = nil)
      @agent.get("https://sellercentral.amazon.com/gp/payments-account/view-transactions.html?ie=UTF8&pageSize=Ten&subview=dateRange&mostRecentLast=0&view=filter")
      form = @agent.page.forms[1]
      form.startDate = start_date || '9/1/10' || form.startDate
      form.endDate = end_date || '9/15/11' || form.endDate
      form.eventType = ''
      form.pageSize = 'One'
      form.submit
    end

    def next_transactions_page 
      @parser = @agent.page.parser
      last_lro = @parser.css('.list-row-odd').last
      next_page_link = last_lro.css('a').last
      @agent.click(next_page_link)
    end

    def extract_from_transactions_page
      unprocessed_transactions_page = []
      @parser = @agent.page.parser
      @parser.css('.list-row-odd').each_with_index do |lro,i|
        next if i == 0 || i == @parser.css('.list-row-odd').size-1
        transaction = lro.css('.data-display-field').map { |dd| dd.text }  
        details_link = lro.css('a').attribute('href').value
        transaction << details_link
        transaction << CGI.parse(details_link)["transaction_id"].first

        unprocessed_transactions_page << transaction
      end
      @parser.css('.list-row-even').each do |lre|
        transaction = lre.css('.data-display-field').map { |dd| dd.text }  
        details_link = lre.css('a').attribute('href').value
        transaction << details_link
        transaction << CGI.parse(details_link)["transaction_id"].first
        unprocessed_transactions_page << transaction
      end
      unprocessed_transactions_page
    end

    def order_details(order_number = '102-9177512-2257812')
      if order_number != '---'
        @agent.get("https://sellercentral.amazon.com/gp/orders-v2/details?ie=UTF8&orderID=#{order_number}")
        order_parser = @agent.page.parser
        payee_name = order_parser.css('td.data-display-field>a').text
      end
    end

    def process_transactions(unprocessed_transactions)
      unprocessed_transactions.map do |ut|
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
        }
      end
    end

    def format_money(amount)
      amount[1..-1].gsub(',','').to_f
    end

    def format_date(date)
      return "" if date.nil?
      parsed_date = Date.parse(date)
      "#{parsed_date.year}-#{parsed_date.month}-#{parsed_date.day}"
    end
  end
end
