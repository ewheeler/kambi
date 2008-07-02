#!ruby

class String
  def trim
    s = self
    s.gsub! /^\s+/, ""
    s.gsub! /\s+$/, ""
    return s
  end
end

# add a new enumerator, similar to each_with_index,
# which yields with a handy css class for styling
module Enumerable
  def each_with_css(singular="n",&block)
    
    # this requires "each" and "length"
    # methods to do anything useful
    raise IndexError\
      unless self.respond_to?(:each)\
             && self.respond_to?(:length)
    
    n   = 0
    len = self.length
    
    # iterate items, and call the block for
    # each with the super-versatile css class
    self.each do |obj|
      n += 1
      
      # always start with "post post-N"
      klass = singular + " " + singular + "-" + n.to_s
      klass << " first" if(n==1)   # first item?
      klass << " last"  if(n==len) # last item?
      klass << " odd"   if(n.odd?) # odd item?
      
      yield obj, klass
    end
  end
end

# OMFG this is a horrid monkey-patch
# TODO: how can this method be made
# available to all controller methods?
class Object
  def require_login(&block)
    if @state && @state.user_id
      @user = Kambi::Models::User.find(@state.user_id)
      yield
    else
      redirect "/sessions/new"
    end
  end
end

module Kambi::Helpers
  require 'net/http'
  require 'uri'
  # include Kambi::Controllers
  # include Kambi::Models
  # include Kambi::Views
  RECAPTCHA_API_SERVER        = 'http://api.recaptcha.net';
  RECAPTCHA_API_SECURE_SERVER = 'https://api-secure.recaptcha.net';
  RECAPTCHA_VERIFY_SERVER     = 'api-verify.recaptcha.net';
  RECAPTCHA_PUBLIC_KEY        = '6Lc6WgIAAAAAAA827S8BoVWFCxqtIpmeve--AU4v' #nothin.gs
  RECAPTCHA_PRIVATE_KEY       = '6Lc6WgIAAAAAANYJJt0gGb_J_JXXtPC1fI06ru7P' #nothin.gs
  
  def font_size_for_tag_cloud( total, lowest, highest, options={} )
   return nil if total.nil? or highest.nil? or lowest.nil?
   #
   # options
   maxf = options.delete( :max_font_size ) || 24
   minf = options.delete( :min_font_size ) || 10
   maxc = options.delete( :max_color ) || [ 0, 0, 0 ]
   minc = options.delete( :min_color ) || [ 156, 156, 156 ]
   hide_sizes = options.delete( :hide_sizes )
   hide_colours = options.delete( :hide_colours )
   #
   # function to work out rgb values
   def rgb_color( a, b, i, x)
    return nil if i <= 1 or x <= 1
    if a > b
     a-(Math.log(i)*(a-b)/Math.log(x)).floor
    else
     (Math.log(i)*(b-a)/Math.log(x)+a).floor
    end
   end
   #
   # work out colours
   c = []
   (0..2).each { |i| c << rgb_color( minc[i], maxc[i], total, highest ) || nil }
   colors = c.compact.empty? ? minc.join(',') : c.join(',')
   #
   # work out the font size
   spread = highest.to_f - lowest.to_f
   spread = 1.to_f if spread <= 0
   fontspread = maxf.to_f - minf.to_f
   fontstep = spread / fontspread
   size = ( minf + ( total.to_f / fontstep ) ).to_i
   size = maxf if size > maxf
   #
   # display the results
   size_txt = "font-size:#{ size.to_s }px;" unless hide_sizes
   color_txt = "color:rgb(#{ colors });" unless hide_colours
   return [ size_txt, color_txt ].join
  end


  def turing_image
     # ti = Turing::Image.new(:width => 150, :height => 75)
     # pat = "tmpf-%s-%s-%s"
     # name =  pat % [Process::pid, Time.now.to_f.to_s.tr(".",""), rand(1e8)]
     # dir = Dir.getwd + "/static/"
     # fn = File.join(dir, name<<'.jpg')
     # captcha = rand(1e8).to_s
     # ti.generate(fn, captcha) 
     # src = {:filename => File.basename(fn), :hushhush => captcha, :type => "image/jpeg", :disposition => "inline"}
  end
  
  
  def recaptcha_tags(options = {})
    # Default options
    key   = options[:public_key] ||= RECAPTCHA_PUBLIC_KEY
    error = options[:error] #||= session[:recaptcha_error]
    uri   = options[:ssl] ? RECAPTCHA_API_SECURE_SERVER : RECAPTCHA_API_SERVER
    out = Markaby::Builder.new 
    if options[:display] 
      out.html do
      	script(:type => "text/javascript"){ out + text!( "var RecaptchaOptions = #{options[:display].to_json};\n")}
	end
    end
    if options[:ajax]
      out.html do
    	div(:id => 'dynamic_recaptcha') {}
     	script(:type => "text/javascript", :src => "#{uri}/js/recaptcha_ajax.js") {}
     	script(:type => "text/javascript") do
        text("Recaptcha.create('#{key}', document.getElementById('dynamic_recaptcha') );")
	end
     end
    else
      out.html do
      	script(:type => "text/javascript", :src => "#{uri}/challenge?k=#{key}&error=#{error}") {}
	end
      unless options[:noscript] == false
        out.html do
		noscript do
           iframe(:src => "#{uri}/noscript?k=#{key}",
                       :height => options[:iframe_height] ||= 300,
                       :width  => options[:iframe_width]  ||= 500,
                       :frameborder => 0) {}; xhtml.br
           textarea(:name => "recaptcha_challenge_field", :rows => 3, :cols => 40) {}
           input(:name => "recaptcha_response_field",
                      :type => "hidden", :value => "manual_challenge")
	end
        end
      end
    end
#    raise ReCaptchaError, "No public key specified." unless key
  return out.to_s
  end # recaptcha_tags
  
  
  def verify_recaptcha(model = nil)
#        return true if SKIP_VERIFY_ENV.include? ENV['RAILS_ENV']
#    raise ReCaptchaError, "No private key specified." unless RECAPTCHA_PRIVATE_KEY
    begin
      recaptcha = Net::HTTP.post_form URI.parse("http://#{RECAPTCHA_VERIFY_SERVER}/verify"), {
        :privatekey => RECAPTCHA_PRIVATE_KEY,
        :challenge  => input.recaptcha_challenge_field,
        :response   => input.recaptcha_response_field
      }
      answer, error = recaptcha.body.split.map { |s| s.chomp }
      unless answer == 'true'
	@h1 = "Oops"
        @msg = "Captcha response is incorrect, please try again."
	@redir = "/posts/" + input.post_id
	return false
      else
        return true
      end
    rescue Exception => e
      raise e.to_s
    end    
  end # verify_recaptcha


end

