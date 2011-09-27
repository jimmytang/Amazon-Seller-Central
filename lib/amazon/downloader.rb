class AuthenticationError < StandardError; end;

module Amazon
  class Downloader
    POLITE_GET_TIMER = 1
    POSSIBLE_TRANSACTION_FIELDS = ["Date", "Transaction type", "Order ID", "Product Details", "Total product charges", "Total promotional rebates", "Amazon fees", "Other", "Total"]

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
      processed_transactions = []
      while next_transactions_page
        processed_transactions.concat(process_transactions(extract_from_transactions_page))
      end
      processed_transactions.concat(process_transactions(extract_from_transactions_page))
    end

    protected

    def login(email, password)
      agent_polite_get("https://sellercentral.amazon.com/gp/homepage.html")
      form = @agent.page.forms.first
      form.email = email
      form.password = password
      form.submit
      raise AuthenticationError.new unless @agent.page.parser.css(".messageboxerror").empty?
    end

    def transactions_page(start_date = nil, end_date = nil)
      agent_polite_get("https://sellercentral.amazon.com/gp/payments-account/view-transactions.html?ie=UTF8&pageSize=Ten&subview=dateRange&mostRecentLast=0&view=filter")
      form = @agent.page.forms.select {|f| f.texts.detect {|t| t.name == "startDate"} }.first
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
        transaction = extract_values_from_list_row(lro).concat(extract_transaction_details(lro))
        unprocessed_transactions_page << transaction
      end
      @parser.css('.list-row-even').each do |lre|
        transaction = extract_values_from_list_row(lre).concat(extract_transaction_details(lre))
        unprocessed_transactions_page << transaction
      end
      unprocessed_transactions_page
    end

    def extract_field_names
      @parser = @agent.page.parser
      lrw = @parser.css('.list-row-white').first
      extracted_field_names = lrw.css('.data-display-field').map { |dd| dd.text.strip } 
      POSSIBLE_TRANSACTION_FIELDS.select {|field_name| extracted_field_names.detect {|efn| efn.include?(field_name)} }
    end

    def transaction_detail_fields
      ["Details Link", "Transaction ID"]
    end

    def extract_values_from_list_row(lr)
      transaction = lr.css('.data-display-field').map { |dd| dd.text }  
    end

    def extract_transaction_details(lr)
      details_link = lr.css('a').attribute('href').value
      [details_link, CGI.parse(details_link)["transaction_id"].first]
    end

    def order_details(order_number)
      details = {}
      if order_number != '---'
        agent_polite_get("https://sellercentral.amazon.com/gp/orders-v2/details?ie=UTF8&orderID=#{order_number}")
        order_parser = @agent.page.parser
        buyer_name = order_parser.css('td.data-display-field>a').first.text
        details["Buyer Name"] = buyer_name
        @agent.back
      end
      details
    end

    def process_transactions(unprocessed_transactions)
      field_names = extract_field_names.concat(transaction_detail_fields)
      processed_transactions = []
      unprocessed_transactions.each do |ut|
        processed_transaction = {}
        field_names.each_with_index {|fn, i| processed_transaction[fn] = format_money(ut[i])}
        processed_transaction.merge!(order_details(processed_transaction["Order ID"]))
        processed_transactions << processed_transaction
      end
      processed_transactions
    end

    def format_money(amount)
      amount = amount[1..-1].gsub(',','').to_f if amount && amount[0..0] == '$'
      amount
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

