=begin
Copyright (c) 2008-2011 Nicolas Sanguinetti, entp.com, Konstantin Haase

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
=end

module Hardwired
  # = Sinatra::Extension
  #
  # <tt>Sinatra::Extension</tt> is a mixin that provides some syntactic sugar
  # for your extensions. It allows you to call almost any
  # <tt>Sinatra::Base</tt> method directly inside your extension
  # module. This means you can use +get+ to define a route, +before+
  # to define a before filter, +set+ to define a setting and so on.
  #
  # Is important to be aware that this mixin remembers the method calls you
  # make, and then, when your extension is registered, replays them on the
  # Sinatra application that has been extended.  In order to do that, it
  # defines a <tt>registered</tt> method, so, if your extension defines one
  # too, remember to call +super+.
  #
  # == Usage
  #
  # Just require the mixin and extend your extension with it:
  #
  #     require 'sinatra/extension'
  #
  #     module MyExtension
  #       extend Sinatra::Extension
  #
  #       # set some settings for development
  #       configure :development do
  #         set :reload_stuff, true
  #       end
  #
  #       # define a route
  #       get '/' do
  #         'Hello World'
  #       end
  #
  #       # The rest of your extension code goes here...
  #     end
  #
  # You can also create an extension with the +new+ method:
  #
  #     MyExtension = Sinatra::Extension.new do
  #       # Your extension code goes here...
  #     end
  #
  # This is useful when you just want to pass a block to
  # <tt>Sinatra::Base.register</tt>.
  module SinatraExtension
    def self.new(&block)
      ext = Module.new.extend(self)
      ext.class_eval(&block)
      ext
    end

    def settings
      self
    end

    def configure(*args, &block)
      record(:configure, *args) { |c| c.instance_exec(c, &block) }
    end

    def registered(base = nil, &block)
      base ? replay(base) : record(:class_eval, &block)
    end

    private

    def record(method, *args, &block)
      recorded_methods << [method, args, block]
    end

    def replay(object)
      recorded_methods.each { |m, a, b| object.send(m, *a, &b) }
    end

    def recorded_methods
      @recorded_methods ||= []
    end

    def method_missing(method, *args, &block)
      return super unless Sinatra::Base.respond_to? method
      record(method, *args, &block)
      DontCall.new(method)
    end

    class DontCall < BasicObject
      def initialize(method) @method = method end
      def method_missing(*) fail "not supposed to use result of #@method!" end
      def inspect; "#<#{self.class}: #{@method}>" end
    end
  end
end