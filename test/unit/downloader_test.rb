require File.expand_path('../../test_helper', __FILE__)

class DownloaderTest < Test::Unit::TestCase
  
  def setup
    @email = 'test@outright.com'
    @password = 'test'
  end

  context "initialize" do
    should "log user in" do
      Amazon::Downloader.any_instance.expects(:login).with(@email, @password)
      Amazon::Downloader.new(@email, @password)
    end
  end

  context "account_balance" do
    setup do
      Mechanize.any_instance.stubs(:get)
      Amazon::Downloader.any_instance.stubs(:login)
      page = stub('Mechanize::Page', :parser => stub('Nokogiri::HTML::Document', :css => [nil, stub('Nokogiri::XML::Element', :text => '$9.01')]))
      Mechanize.any_instance.stubs(:page).returns(page)
      @downloader = Amazon::Downloader.new(@email, @password)
    end
    should "return the user's account balance" do
      assert_equal 9.01, @downloader.account_balance
    end
  end

  context "transactions" do
    setup do
      Amazon::Downloader.any_instance.stubs(:login)
      Amazon::Downloader.any_instance.stubs(:transactions_page)
      Amazon::Downloader.any_instance.stubs(:next_transactions_page)
      Amazon::Downloader.any_instance.stubs(:extract_from_transactions_page).returns(unprocessed_transactions_page).returns(unprocessed_transactions_page).returns([])

      @downloader = Amazon::Downloader.new(@email, @password)
    end
    should "return an array of transaction hashes" do
      assert_equal expected_transactions, @downloader.transactions
    end
  end

  private

  def unprocessed_transactions_page
    [
      ["Aug 14, 2011", "Service Fees", "---", "Subscription", "$0.00", "$0.00", "$-39.99", "$0.00", "$-39.99"],
      ["Jul 15, 2011", "Order Payment", "102-9177512-2257812", "Glass Paperweight", "$1.00", "$0.00", "$-0.82", "$4.49", "$4.67"],
      ["Aug 2, 2011", "Other", "---", "Failed disbursement", "$0.00", "$0.00", "$0.00", "$4.67", "$4.67"]
    ]
  end

  def expected_transactions
    [{"Total product charges"=>0.0,
    "Amazon fees"=>-39.99,
    "Total promotional rebates"=>0.0,
    "Date"=>"Aug 14, 2011",
    "Total"=>-39.99,
    "Order ID"=>"---",
    "Other"=>0.0,
    "Product Details"=>"Subscription",
    "Transaction type"=>"Service Fees"},
   {"Total product charges"=>1.0,
    "Amazon fees"=>-0.82,
    "Total promotional rebates"=>0.0,
    "Date"=>"Jul 15, 2011",
    "Total"=>4.67,
    "Order ID"=>"102-9177512-2257812",
    "Other"=>4.49,
    "Product Details"=>"Glass Paperweight",
    "Transaction type"=>"Order Payment"},
   {"Total product charges"=>0.0,
    "Amazon fees"=>0.0,
    "Total promotional rebates"=>0.0,
    "Date"=>"Aug 2, 2011",
    "Total"=>4.67,
    "Order ID"=>"---",
    "Other"=>4.67,
    "Product Details"=>"Failed disbursement",
    "Transaction type"=>"Other"},
   {"Total product charges"=>0.0,
    "Amazon fees"=>-39.99,
    "Total promotional rebates"=>0.0,
    "Date"=>"Aug 14, 2011",
    "Total"=>-39.99,
    "Order ID"=>"---",
    "Other"=>0.0,
    "Product Details"=>"Subscription",
    "Transaction type"=>"Service Fees"},
   {"Total product charges"=>1.0,
    "Amazon fees"=>-0.82,
    "Total promotional rebates"=>0.0,
    "Date"=>"Jul 15, 2011",
    "Total"=>4.67,
    "Order ID"=>"102-9177512-2257812",
    "Other"=>4.49,
    "Product Details"=>"Glass Paperweight",
    "Transaction type"=>"Order Payment"},
   {"Total product charges"=>0.0,
    "Amazon fees"=>0.0,
    "Total promotional rebates"=>0.0,
    "Date"=>"Aug 2, 2011",
    "Total"=>4.67,
    "Order ID"=>"---",
    "Other"=>4.67,
    "Product Details"=>"Failed disbursement",
    "Transaction type"=>"Other"}]
  end
end
