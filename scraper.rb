require 'scraperwiki'
# encoding: ISO-8859-1
require 'nokogiri'
require 'mechanize'
# TODO:
# 1. Fork the ScraperWiki library (if you haven't already) at https://classic.scraperwiki.com/scrapers/mcf/
# 2. Add the forked repo as a git submodule in this repo
# 3. Change the line below to something like require File.dirname(__FILE__) + '/mcf/scraper'
# 4. Remove these instructions
require 'scrapers/mcf'

Mechanize.html_parser = Nokogiri::HTML

BASE_URL = "http://www.azsos.gov"

@br = Mechanize.new { |b|
  b.user_agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/29.0.1547.76 Safari/537.36'
  b.read_timeout = 1200
  b.max_history=0
  b.retry_change_requests = true
  b.verify_mode = OpenSSL::SSL::VERIFY_NONE
}

class String
  def pretty
    self.gsub(/\r|\n|\t|\s+/,' ').strip
  end
end

class Array
  def strip
    self.collect{|a|a.strip}
  end
  def downcase
    self.collect{|a| a.strip.downcase}
  end
end


def scrape(data,action)
  if action == "list"
    records = []
    doc = Nokogiri::HTML(data,nil,'ISO-8859-1').xpath(".//table[@align='center']/tr[position()>1]")
    doc.each{|tr|
      r = {
         "COMPANY_NUMBER" => a_text(tr.xpath("./td[1]")).join("\n").strip,
         "TYPE" => a_text(tr.xpath("./td[2]")).join("\n").strip,
         "COMPANY_NAME" => a_text(tr.xpath("./td[3]")).join("\n").strip,
         "URL" => attributes(tr.xpath("./td[1]/a"),"href"),
         "DOC" => Time.now
      }
      r['URL']=BASE_URL+r['URL'] unless r['URL'] =~ /azcc/i 
      records << r unless r['TYPE'].match(/TRADEMARK|TRADENAME|PENDING CORP./i) or r['COMPANY_NUMBER'].nil? 
    }
    ScraperWiki.save_sqlite(unique_keys=["COMPANY_NUMBER"],records,table_name="swdata",verbose=2) unless records.length<=0
    return doc.length
  end
end

def action(srch)
  begin
    pg = @br.post(BASE_URL + "/scripts/TnT_Search_Engine.dll/ListNames",{'NIR_ID'=>nil,'AGENT'=>nil,'WORDS'=>srch,'SEARCH_TYPE'=>'PW'})
    ret = scrape(pg.body,"list")
    return srch,ret
  end
end

#action("GLOBALMEDIA")

#save_metadata("TRIAL","A")
trail = get_metadata("trail","<non-alpha>")
srch = trail.nil? ? get_metadata("trail","<non-alpha>") : trail.split(">>").last
if srch == "<non-alpha>"
  range = ['@','#','$','%','^','&','*','(',')'].to_a + (0..100).to_a
  offset = get_metadata("start",0)
  range.each_with_index{|srch,idx|
    next if idx < offset
    action(srch)
    save_metadata("OFFSET",idx.next)
    sleep(2)
  }
  save_metadata("trail","A")
  delete_metadata("start")
end

begin
  trail = get_metadata("trail","A").split(">>")
  srch = trail.last
  MAX_T = 500
  begin
    prev,ret = action(srch)
    if ret >= MAX_T
      srch = srch + "A"
      trail << srch
    else
      tmp = ''
      begin tmp = trail.pop end while tmp =='Z' or tmp.split(//).last == 'Z' rescue nil
      if tmp.nil? 
        trail == ["A"]
      else
        srch = (tmp == 'Z')? "A" : tmp.next
        trail << srch
      end
    end
    save_metadata("trail",trail.join(">>"))
    sleep(2)
  end while(true)
  delete_metadata("trail","<non-alpha>")
end
