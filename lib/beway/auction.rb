require 'nokogiri'
require 'open-uri'

require 'pry'

module Beway
  class AuctionParseError < StandardError; end;
  class InvalidUrlError < StandardError; end;

  # Auction
  #
  # Represents an ebay auction.  Can only be instantiated for true auctions
  # (no buy-it-now-only sales) and completed auctions.
  class Auction

    attr_reader :url, :doc, :last_updated

    def initialize url
      @url = url
      refresh_doc
      raise InvalidUrlError unless valid_auction?
    end

    # can we represent this auction?
    def valid_auction?
      return true if complete? or has_bid_button?
      return false
    end

    # has bidding ended yet?
    def complete?
      complete_span = @doc.at_xpath('//span[contains(text(), "Bidding has ended on this item")]')
      return (complete_span.nil?) ? false : true
    end

    # fetch the url again
    def refresh_doc
      @doc = Nokogiri::HTML(open(@url))
      @last_updated = Time.now
    end

    # returns a rounded float
    def current_total_cost
      (cost_to_f(current_bid) + cost_to_f(shipping)).round(2)
    end

    # takes cost/currency string (e.g. "US $9.99"), returns float
    # TODO: no international support
    def cost_to_f(string)
      string.gsub("US","").gsub("$", "").to_f
    end

    # parsing method, returns a string
    def current_bid
      bid_node = @doc.at_xpath('//span[@id="prcIsum_bidPrice"]')

      raise AuctionParseError, "Couldn't find current/starting bid header in document" if bid_node.nil?
      bid_text = node_text(bid_node)
      bid_text = bid_text[/^[^\[]+/].strip if complete?
      return bid_text
    end

    # parsing method, returns a string
    def description
      desc = @doc.at_css('h1')
      raise AuctionParseError, "Couldn't find description in document" if desc.nil?
      desc.children.last
    end

    def shipping
      shipping = @doc.at_xpath('//span[@id="fshippingCost"]/span').text
    end

    # parsing method, returns a string
    def time_left
      return nil if complete?

      time_str = node_text(time_node)
      time_str = time_str[/^[^(]*/].strip
      time_ar = time_str.split

      # time_ar comes to us looking like
      #   ["2d", "05h"] or ["0", "h", "12", "m", "5", "s"]
      # decide which, and roll with it...
      
      if time_ar[0][/^\d+d$/] and time_ar[1][/^\d+h$/]
        # ["2d", "05h"] style
        return time_ar.join(' ')
      elsif time_ar[1] =~ /^days?$/ and time_ar[3] =~ /^hours?$/
        # ["1", "day", "18", "hours"]
        return time_ar.join(' ')
      else
        # assume ["0", "h", "12", "m", "5", "s"] style
        raise AuctionParseError, "Didn't find hour marker where expected" unless time_ar[1] == 'h'
        raise AuctionParseError, "Didn't find minute marker where expected" unless time_ar[3] == 'm'
        raise AuctionParseError, "Didn't find second marker where expected" unless time_ar[5] == 's'
        return [ time_ar[0] + time_ar[1],
                 time_ar[2] + time_ar[3],
                 time_ar[4] + time_ar[5] ].join(' ')
      end
    end

    # parsing method, returns a float
    def min_bid
      return nil if complete?

      min_bid_node = @doc.at_xpath('//div[contains(@class,"bid-note")]')
      raise AuctionParseError, "Couldn't find minimum bid in document" unless min_bid_node
      match_data = min_bid_node.inner_text.match(/Enter ([^)]*) or more/)
      raise AuctionParseError, "Min Bid data not in expected format. Got: #{min_bid_node.inner_text}" if match_data.nil?
      match_data[1]
    end

    # parsing method, returns a Time object
    def end_time
      time_str = @doc.at_xpath('//span[@class="vi-tm-left"]').children.text.strip
      raise AuctionParseError unless time_str
      Time.parse(time_str)
    end

    # parsing method, returns a string
    def auction_number
      canonical_url_node = @doc.at_css('link[@rel = "canonical"]')
      raise AuctionParseError, "Couldn't find canonical URL" unless canonical_url_node
      canonical_url_node.attr('href')[/\d+$/]
    end

    # parsming method, returns boolean
    def has_bid_button?
      place_bid_button = @doc.at_xpath('//form//input[@id = "MaxBidId"]')
      return (place_bid_button.nil?) ? false : true
    end

    private

    # fetch the node containing the end time
    def time_node
      if complete?
        td = @doc.at_xpath("//td[contains(text(),'Ended:')]")
        raise AuctionParseError, "Couldn't find ended header" unless td
        node = td.next_sibling
      else
        node = @doc.at_xpath('//span[@id="vi-cdown_timeLeft"]')
      end

      raise AuctionParseError, "Couldn't find Time node" unless node
      node
    end

    # a string of all text nodes below n, concatenated
    def node_text(n)
      t = ''
      n.traverse { |e| t << ' ' + e.to_s if e.text? }
      t.gsub(/ +/, ' ').strip
    end

  end
end
