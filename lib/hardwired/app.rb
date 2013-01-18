Encoding.default_external = 'utf-8' if RUBY_VERSION =~ /^1.9/

#If certain folders are KNOWN to contain only static files, we can speed those up
#use Rack::Static, :urls => ["/public"]
#use Rack::Static, :urls => ["/attachments"], :root "content"

#Register parsers for file types that support automatic header parsing
Hardwired::ContentFormats.register Hardwired::ContentFormats::Markdown, :mdown, :md, :markdown
Hardwired::ContentFormats.register Hardwired::ContentFormats::Haml, :haml
Hardwired::ContentFormats.register Hardwired::ContentFormats::Textile, :textile
Hardwired::ContentFormats.register Hardwired::ContentFormats::Html, :htmf
Hardwired::ContentFormats.register Hardwired::ContentFormats::Slim, :slim

module Hardwired 
	class SiteBase < Sinatra::Base

		attr_accessor :select_menu, :page, :template_stack

		helpers do
			def config
	      Hardwired::Config.config
	    end
		  def index
		  	Hardwired::Index
		  end 
		  def template
		  	template_stack.last
		  end

		  def dev?
		  	Sinatra::Base.development?
		  end 
		end 


		#Enable content_for in templates
		register Sinatra::ContentFor

		#Enable redirect support
		register Hardwired::Aliases

		#Import helper methods
		helpers Hardwired::Helpers

		class << self
			def config_file(path)
	      Hardwired::Config.load(path, self)
	    end 
	   	def dev?
		  	Sinatra::Base.development?
		  end 
		end 


		helpers do

  		def url_for(page)
        File.join(request.base_url, page.is_a?(Template) ? page.path : page)
      end

      #So sinatra render methods can pick up files in /content/ and /content/_layout (although we despise them)
	    def find_template(views, name, engine, &block)
		  	#normal
		    super(views, name, engine, &block)
		    #_layout folder
		    super(Paths.layout_path, name.to_s, engine, &block)
		  end

		  def partial(path, options={})
		  	raise "No name provided to partial(name). Name should exclude extension." if !path
		  	part = Index.find(path, template && template.dir_path)
	  		raise "Failed to located partial '#{path}'" if part.nil?
	  		output = part.render(config,{:layout => false}.merge(options), self )
		  end 

		  def before_render_file(file)
		  	self.page = file
		  end

		  def render_file(path, options={})
	  		file = Index[path] || (options[:anywhere] == true && Index.find(path))
	  		return nil if file.nil? || !file.can_render?
				before_render_file(file)
	  		file.render(config,options,self)
		  end

		end

		set :root, Proc.new {Hardwired::Paths.root_path }
		set :views, Proc.new { Hardwired::Paths.content_path }
		set :haml, { :format => :html5 }

		
		before do
			#Protect against ../ attacks and _layout access
			if request.path =~ /\.\.[\/\\]/ || (!dev? && request.path_info =~ /^\/_layout/mi)
	      not_found
	    end
	    #Redirect incoming urls so they don't have a trailing '/'
	    if request.path_info =~ Regexp.new('./$')
	      redirect to(request.path_info.sub(Regexp.new('/$'), '') + request.query_string)
	    end
	  end


		## Static files rule - As-is serving for non-interpreted extensions and *.static.*
		get '*' do
			path, ext = split_ext
			base_path = Hardwired::Paths.content_path(path)
			local_path = "#{base_path}.#{ext}";
			static_path = "#{base_path}.static.#{ext}"
			interpreted_ext = !Tilt.mappings[ext].empty?
			# We only serve the file if it's .static.* or if it's not an interpreted (Tilt-registered) extension
			pass if interpreted_ext && !File.file?(static_path)
			pass if !interpreted_ext && !File.file?(local_path)
			
			real_path = interpreted_ext ? static_path : local_path

			send_file(real_path, request[:download] ? {:disposition => 'attachment'} : {})
	  end

	  # Special handling for non-static .css and .js requests so they'll match the 'direct evaluation' routes
	  get %r{(.+).(css|js)} do
	  	request.path_info, _ = split_ext
	  	pass
	  end

	  #All interpreted files are in the index, even scss and coffeescript
	  get '*' do
	  	output = render_file(request.path_info)
	  	pass if output.nil?
	  	output 
	  end 

  end

  class Bootstrap < SiteBase

  	get %r{/google([0-9a-z]+).html?} do |code|
      "google-site-verification: google#{code}.html" if config.google_verify.include?(code)
    end

    get '/robots.txt' do
      content_type 'text/plain', :charset => 'utf-8'
      
      output = "# robots.txt\n# See http://en.wikipedia.org/wiki/Robots_exclusion_standard\n" 
      output += "Sitemap: #{url_for('/sitemap.xml')}"
      return output
    end


	  not_found do
	    render_file('404', :anywhere =>true)
	  end

	  error do
	    render_file('500', :anywhere => true)
	  end unless dev?

	end
end