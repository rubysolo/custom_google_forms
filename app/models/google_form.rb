class GoogleForm < ActiveRecord::Base
  before_validation :clean_formkey
  validates_presence_of :slug, :formkey
  validates_uniqueness_of :slug, :formkey
  validate :validate_formkey_is_valid
  
  def fetch_form_page
    uri = URI.parse(google_form_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    if response.is_a?(Net::HTTPSuccess)
      self.title = extract_form_title(response.body)
    end
    response
  end
  
  # If the title is modified, then save the GoogleForm before returning response
  def fetch_form_page!
    response = self.fetch_form_page
    self.save!
    response
  end
  
  def submit(google_form_action, params)
    uri = URI.parse(google_form_action)
    req = Net::HTTP::Post.new("#{uri.path}?#{uri.query}")
    req.form_data = params
    response = Net::HTTP.new(uri.host).start {|h| h.request(req)}
    response
  end
  
  def google_form_url
    "https://spreadsheets.google.com/viewform?formkey=#{formkey}"
  end
  
  def extract_form_title(body)
    doc = Nokogiri::HTML(body)
    doc.xpath("//h1[@class='ss-form-title']").first.text
  end
  
  def clean_formkey
    if formkey =~ /=(.*)$/
      self.formkey = $1
    end
  end
  
  def validate_formkey_is_valid
    case fetch_form_page
    when Net::HTTPSuccess
      true
    else
      errors.add(:formkey, "is not a valid Google Forms key or URL or error connecting to Google")
      false
    end
  end
end
