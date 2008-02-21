#!ruby
module Kambi::Helpers
  # include Kambi::Controllers
  # include Kambi::Models
  # include Kambi::Views
  
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

  # # menu bar
  # def menu target = nil
  #   if target
  #     args = target.is_a?(Symbol) ? [] : [target]
  #     for role, submenu in menu[target].sort_by { |k, v| [:visitor, :user].index k }
  #       ul.menu.send(role) do
  #         submenu.each do |x|
  #           li { x[/\A\w+\z/] ? a(x, :href => R(Controllers.const_get(x), *args)) : x }
  #         end
  #       end unless submenu.empty?
  #     end
  #   else
  #     @menu ||= Hash.new { |h, k| h[k] = { :visitor => [], :user => [] } }
  #   end
  # end
  # 
  # # shortcut for error-aware labels
  # def label_for name, record = nil, attr = name, options = {}
  #   errors = record && !record.body.blank? && !record.valid? && record.errors.on(attr)
  #   label name.to_s, { :for => name }, options.merge(errors ? { :class => :error } : {})
  # end

  # def send_file(path, options = {}) #:doc:
  #   raise MissingFile, "Cannot read file #{path}" unless File.file?(path) and File.readable?(path)
  # 
  #   options[:length]   ||= File.size(path)
  #   options[:filename] ||= File.basename(path) unless options[:url_based_filename]
  #   options[:status] ||= 200
  #   send_file_headers! options
  # 
  #   @performed_render = false
  # 
  #   # if options[:stream]
  #   #   # render :status => options[:status], :text => Proc.new{ |response, output|
  #   #   return :text => Proc.new{ |response, output|
  #   #   #logger.info "Streaming file #{path}" unless logger.nil?
  #   #   len = options[:buffer_size] || 4096
  #   #   File.open(path, 'rb') do |file|
  #   #     while buf = file.read(len)
  #   #       output.write(buf)
  #   #     end
  #   #   end
  #   # }
  #   # else
  #     #logger.info "Sending file #{path}" unless logger.nil?
  #     # File.open(path, 'rb') { |file| render :status => options[:status], :text => file.read }
  #     # File.open(path, 'rb') { |file| return file.read }
  #     
  #    # end
  # end
  # 
  # def send_file_headers!(options)
  #   default_send_file_options = { :type => 'application/octet-stream'.freeze, :disposition => 'attachment'.freeze, :stream => true, :buffer_size => 4096}
  #   options.update(default_send_file_options.merge(options))
  #   [:length, :type, :disposition].each do |arg|
  #     raise ArgumentError, ":#{arg} option required" if options[arg].nil?
  #   end
  # 
  #   disposition = options[:disposition].dup || 'attachment'
  # 
  #   disposition <<= %(; filename="#{options[:filename]}") if options[:filename]
  # 
  #   @headers.update(
  #     'Content-Length'            => options[:length],
  #     'Content-Type'              => options[:type].strip,  # fixes a problem with extra with some browsers
  #     'Content-Disposition'       => disposition,
  #     'Content-Transfer-Encoding' => 'binary'
  #   )
  # 
  #   # Fix a problem with IE 6.0 on opening downloaded files:
  #   # If Cache-Control: no-cache is set (which Rails does by default), 
  #   # IE removes the file it just downloaded from its cache immediately 
  #   # after it displays the "open/save" dialog, which means that if you 
  #   # hit "open" the file isn't there anymore when the application that 
  #   # is called for handling the download is run, so let's workaround that
  #   @headers['Cache-Control'] = 'private' if @headers['Cache-Control'] == 'no-cache'
  # end
        
  
  def turing_image
     ti = Turing::Image.new(:width => 150, :height => 75)
     pat = "tmpf-%s-%s-%s"
     name =  pat % [Process::pid, Time.now.to_f.to_s.tr(".",""), rand(1e8)]
     dir = Dir.getwd + "/static/"
     fn = File.join(dir, name<<'.jpg')
     captcha = rand(1e8).to_s
     ti.generate(fn, captcha)

      # ti = Turing::Image.new(:width => 280, :height => 115)
      # fn = get_tmpname
      # ti.generate(fn, rand(1e8).to_s)
        # send_file fn, :type => "image/jpeg", :disposition => "inline"
       # return :filename => File.basename(fn), :type => "image/jpeg", :disposition => "inline"
      # File.open(fn, 'rb') 
      # src = File.basename(fn)
      
      # options[:length]   ||= File.size(path)
      # options[:filename] ||= File.basename(path) unless options[:url_based_filename]
      # options[:status] ||= 200
 #     options = { :length => File.size(fn), :filename => File.basename(fn), :status => 200}
#      send_file_headers! options
      
      src = {:filename => File.basename(fn), :hushhush => captcha, :type => "image/jpeg", :disposition => "inline"}
  end


  # def get_tmpname
  #     pat = "tmpf-%s-%s-%s"
  #     fn = pat % [Process::pid, Time.now.to_f.to_s.tr(".",""), rand(1e8)]
  #     File.join(Dir::tmpdir, fn)
  # end
  # private :get_tmpname
  
  
end

