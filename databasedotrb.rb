require 'readline'
require 'databasedotcom'
require 'yaml'
require 'csv'
require 'date'

module Databasedotrb
	# sObject module
	module SObject;end

	# Databasedotcom Client class
	class Client < Databasedotcom::Client
		def simple_search sosl_expr
			result = http_get "/services/data/v#{self.version}/search", :q => sosl_expr
			JSON.parse result.body
		end
	end

	# Command line interpreter class
	class CLI
		CommandException = Class.new Exception
		DEFAULT_PROMPT = "sfdc:%03d> "

		attr_reader :client

		def initialize yml, options = {}
			@client = Client.new yml
			@options = options
			@@configuration_initialize.each do |c|
				instance_variable_set "@#{c[0]}", c[1]
			end
			yield self if block_given?
		end

		# login
		def login options = {}
			loop do
				username, password = @options[:username] || @client.username, @options[:password] || @client.password
				while username == '' || username.nil?
					print 'username: '
					username = $stdin.gets.chop
				end
				while password == '' || password.nil?
					print 'password: '
					system "stty -echo"
					password = $stdin.gets.chop
					system "stty echo"
					puts
				end
				begin
					@client.authenticate :username => username, :password => password
					begin
						@me = materialize('User').find(@client.user_id)
						name = @me['Name']
					rescue Databasedotcom::SalesForceError
						name = @client.username
					end
					puts "Hello, \"#{name}\""
					puts
					break
				rescue Databasedotcom::SalesForceError => e
					$stderr.puts e.message
				end
				exit unless @options[:username].nil? && @options[:password].nil?
			end
			self
		end

		# command line start
		def start
			@data_history = [nil]
			loop do
				buf = Readline.readline(sprintf(@prompt, @data_history.length), true)
				args = nil
				loop do
					begin
						buf.gsub! /^\s*(.*?)\s*$/, '\1'
						args = CSV.parse_line buf, :col_sep => ' '
						break
					rescue CSV::MalformedCSVError
						Readline::HISTORY.pop
						buf += "\n" + Readline.readline('', false)
					end
				end
				Readline::HISTORY.pop
				next if args.nil? || args.length.zero?
				Readline::HISTORY.push buf
				begin
					root_cmd = args.shift.downcase
					send "command_#{root_cmd}", *args
					buf = ""
				rescue Databasedotcom::SalesForceError, CommandException => e
					if e.message.nil?
						$stderr.puts "Command error: #{buf}"
					else
						$stderr.puts e.message
					end
					$stderr.puts
					buf = ""
				end
			end
		end

	  protected

		class << self
			@@command_help = {}
			# define command's method
			def define_command_method name, help, &block
				@@command_help[name] = help
				define_method "command_#{name}", &block
			end

			@@scommand_help = {"" => "Describe sObject."}
			# define sObject command's method
			def define_scommand_method name, help, &block
				@@scommand_help[name] = help
				define_method "scommand_#{name}", &block
			end

			@@hcommand_help = {"" => "Show data."}
			# define history command's method
			def define_hcommand_method name, help, &block
				@@hcommand_help[name] = help
				define_method "hcommand_#{name}", &block
			end

			@@configuration_help = {}
			@@configuration_initialize = {}
			# define sObject command's method
			def define_configuration name, val, help, &block
				@@configuration_help[name] = help
				@@configuration_initialize[name] = val
				# define configuration get method
				get_method_name = "configuration_#{name}"
				define_method get_method_name do
					instance_variable_get "@#{name}"
				end
				private get_method_name
				# define configuration set method
				set_method_name = "configuration_#{name}="
				if block_given?
					define_method set_method_name do |val|
						self.instance_exec val, &block
					end
				else
					define_method set_method_name do |val|
						instance_variable_set "@#{name}", val
					end
				end
				private set_method_name
			end
		end

	  private

		# all configration
		define_configuration :echo, true, "Echo command result."
		define_configuration :prompt, DEFAULT_PROMPT, "Show command prompt." do |val|
			if val == true
				@prompt = DEFAULT_PROMPT
			elsif val == false
				@prompt = ""
			else
				@prompt = val
			end
		end
		define_configuration :encoding, Encoding.default_external, "Echo command result." do |val|;end
		define_configuration :ca_file, Proc.new{@client.ca_file}, "The CA file configured for this instance, if any." do |val|;end
		define_configuration :client_id, Proc.new{@client.client_id}, "The client id (aka 'Consumer Key') to use for OAuth2 authentication." do |val|;end
		define_configuration :client_secret, Proc.new{@client.client_secret}, "The client secret (aka 'Consumer Secret' to use for OAuth2 authentication." do |val|;end
		define_configuration :debugging, Proc.new{@client.debugging}, "If true, print API debugging information to stdout." do |val|
			@client.debugging = val
		end
		define_configuration :host, Proc.new{@client.host}, "The host to use for OAuth2 authentication." do |val|;end
		define_configuration :instance_url, Proc.new{@client.instance_url}, "The base URL to the authenticated user's SalesForce instance." do |val|;end
		define_configuration :oauth_token, Proc.new{@client.oauth_token}, "The OAuth access token in use by the client." do |val|;end
		define_configuration :org_id, Proc.new{@client.org_id}, "The SalesForce organization id for the authenticated user's Salesforce instance." do |val|;end
		define_configuration :refresh_token, Proc.new{@client.refresh_token}, "The OAuth refresh token in use by the client." do |val|;end
		define_configuration :sobject_module, Proc.new{@client.sobject_module}, "A Module in which to materialize Sobject classes." do |val|;end
		define_configuration :user_id, Proc.new{@client.user_id}, "The SalesForce user id of the authenticated user." do |val|;end
		define_configuration :username, Proc.new{@client.username}, "The SalesForce username." do |val|;end
		define_configuration :verify_mode, Proc.new{@client.verify_mode}, "The SSL verify mode configured for this instance, if any." do |val|;end
		define_configuration :version, Proc.new{@client.version}, "The API version the client is using." do |val|
			raise CommandException.new if val.class != String
			if @client.version != val
				@client.version = val
				@materialized = {}
				@described = {}
			end
		end

		# help command
		define_command_method :"?", "All command line help." do |*args|
			raise CommandException.new unless args.length.zero?
			show_help "Command line help:", "", @@command_help
			show_help "sObject Command line help:", "[sObject]", @@scommand_help
			show_help <<EOS, "[history]", @@hcommand_help
History Command line help:
  [history] is commandline history result data.
  [$ or $n](:[n or n-m](,[n or n-m](,[n or n-m],(...))))
  ex.: $         # before result data
  ex.: $7        # line number 7 result data
  ex.: $7:1,3    # line number 7 result data (1 and 3 row data)
  ex.: $:1-3,5   # before result data (1, 2, 3 and 5 row data)
EOS
		end

		# exit command
		define_command_method :exit, "Exit command line." do |*args|
			raise CommandException.new unless args.length.zero?
			exit
		end

		# set command
		define_command_method :set, <<EOS do |*args|
Set configuration.
  set [config name] (value)
EOS
			raise CommandException.new if args.length > 2
			raise CommandException.new if send("configuration_#{args[0].downcase}").nil?
			send "configuration_#{args[0].downcase}=", args.length == 1 ? true : args[1]
		end

		# no command
		define_command_method :no, <<EOS do |*args|
Unset configuration.
  no [config name]
EOS
			raise CommandException.new if args.length != 1
			raise CommandException.new if send("configuration_#{args[0].downcase}").nil?
			send "configuration_#{args[0].downcase}=", false
		end

		# config command
		define_command_method :config, "Show all configurations." do |*args|
			raise CommandException.new unless args.length.zero?
			res = @@configuration_initialize.map do |c|
				val = instance_variable_get("@#{c[0]}")
				{
					'Key' => c[0].to_s,
					'Value' => val.class == Proc ? self.instance_eval(&val) : val,
					'Description' => @@configuration_help[c[0]],
				}
			end
			show_table res, ['Key', 'Value', 'Description']
		end

		# sobjects command
		define_command_method :sobjects, <<EOS do |*args|
Show all sObjects.
  sobjects       # basic sobject list
  sobjects dev   # developer sobject list
  sobjects all   # all sobject describe
EOS
			desc = @client.describe_sobjects
			if args.length.zero?
				cols = ['name', 'label']
			elsif args.length == 1
				case args.shift.downcase
				when 'dev'
					cols = [
						"name", "label", "keyPrefix", "updateable", "custom", "searchable", 
						"createable", "customSetting", "deletable", "feedEnabled", "mergeable", 
						"queryable", "undeletable", "triggerable"]
				when 'all'
					cols = desc.first.keys
				else
					raise CommandException.new
				end
			end
			show_table desc, cols
		end

		# query command
		define_command_method :query, <<EOS do |*args|
SOQL query.
  query [SOQL query]
  ex.: query "Select * From User Limit 10"
EOS
			raise CommandException.new if args.length != 1
			soql = args.shift.gsub /\n/ , ' '
			raise CommandException.new unless /^\s*select\s+(.*)\s+from\s+([^\s]+)(.*)$/i =~ soql
			select = $1
			select_from = $2
			select_tail = $3
			loop do
				break unless /\(.*?\)/ =~ select
				select.gsub! /\(.*?\)/, ''
			end
			col = select.split /\s*,\s*/
			klass = materialize select_from
			if col == ['*']
				col = []
				soql = "Select #{klass.field_list} From #{select_from} #{select_tail}"
			end
			show_sobjects klass, @client.query(soql), col
		end

		# search command
		define_command_method :search, <<EOS do |*args|
SOSL search.
  search [SOSL query]              # execute sosl query
  search [search string] all       # search all field
  search [search string] name      # search name field
  search [search string] email     # search email field
  search [search string] phone     # search phone field
  search [search string] sidebar   # search sidebar field
EOS
			if args.length == 1
				sosl = args[0]
			elsif args.length == 2
				str = "#{args.shift.gsub /[\{\}]/, '\\\0'}"
				case args.shift.downcase
				when 'all'
					sosl = "FIND {#{str}} IN ALL FIELDS"
				when 'name'
					sosl = "FIND {#{str}} IN NAME FIELDS"
				when 'email'
					sosl = "FIND {#{str}} IN EMAIL FIELDS"
				when 'phone'
					sosl = "FIND {#{str}} IN PHONE FIELDS"
				when 'sidebar'
					sosl = "FIND {#{str}} IN SIDEBAR FIELDS"
				else
					raise CommandException.new
				end
			else
				raise CommandException.new
			end
			res = @client.simple_search(sosl).map do |o|
				{
					'Id' => o['Id'],
					'Type' => o['attributes']['type'],
				}
			end
			show_table res, ['Id', 'Type']
		end

		# export command
		define_command_method :export, <<EOS do |*args|
Export for CSV file (before command result data).
  export               # export csv for stdout
  export [file name]   # export csv for file
EOS
			export_csv @data_history.last, *args
		end

		# insert command
		define_command_method :insert, <<EOS do |*args|
Insert from local CSV file.
  insert [sObject] [file name]
EOS
				begin
				raise CommandException.new if args.length != 2
				klass_name = args.shift.downcase
				klass = materialize klass_name
				desc = describe(klass_name)['fields']
				create_fields = desc.find_all{|f| f['createable']}
				csv = CSV.read args.shift, :headers => true, :encoding => 'UTF-8'
				idfield = csv.headers.find{|f| f.downcase == 'id'}
				res = []
				csv.each do |r|
					val = {}
					create_fields.each do |f|
						name = f['name']
						v = r[name]
						next if v.length.zero?
						val[name] = convert v, f['type']
					end
					begin
						o = @client.create klass, val
						res << {
							idfield => o.Id,
							'Status' => true,
							'ErrorDescription' => nil,
						}
					rescue Databasedotcom::SalesForceError => e
						res << {
							idfield => nil,
							'Status' => false,
							'ErrorDescription' => e.message,
						}
					end
				end
				show_table res, [idfield, 'Status', 'ErrorDescription']
			rescue CSV::MalformedCSVError
				$stderr.puts 'Invalid csv'
			rescue Errno::ENOENT => e
				raise CommandException.new e.message
			end
		end

		# update command
		define_command_method :update, <<EOS do |*args|
Update from CSV local file.
  update [sObject] [file name]
EOS
			begin
				raise CommandException.new if args.length != 2
				klass_name = args.shift.downcase
				klass = materialize klass_name
				desc = describe(klass_name)['fields']
				update_fields = desc.find_all{|f| f['updateable']}
				csv = CSV.read args.shift, :headers => true
				idfield = csv.headers.find{|f| f.downcase == 'id'}
				unless idfield
					$stderr.puts 'csv file must has include "Id" column.'
					return
				end
				res = []
				csv.each do |r|
					val = {}
					update_fields.each do |f|
						name = f['name']
						v = r[name]
						next if v.nil? || v.length.zero?
						val[name] = convert v, f['type']
					end
					begin
						@client.update klass, r[idfield], val
						res << {
							idfield => r[idfield],
							'Status' => true,
							'ErrorDescription' => nil,
						}
					rescue Databasedotcom::SalesForceError => e
						res << {
							idfield => r[idfield],
							'Status' => false,
							'ErrorDescription' => e.message,
						}
					end
				end
				show_table res, [idfield, 'Status', 'ErrorDescription']
			rescue CSV::MalformedCSVError
				$stderr.puts 'Invalid csv'
			end
		end

		# upsert command
		define_command_method :upsert, <<EOS do |*args|
Upsert from CSV local file.
  upsert [sObject] [ID or External ID field] [file name]
EOS
			begin
				raise CommandException.new if args.length != 3
				klass_name = args.shift.downcase
				klass = materialize klass_name
				desc = describe(klass_name)['fields']
				upsert_fields = desc.find_all{|f| f['updateable']}
				idfield0 = args.shift.downcase
				csv = CSV.read args.shift, :headers => true
				idfield = csv.headers.find{|f| f.downcase == idfield0.downcase}
				unless idfield
					$stderr.puts 'csv file must has include "#{idfield0}" column.'
					return
				end
				res = []
				csv.each do |r|
					val = {}
					upsert_fields.each do |f|
						name = f['name']
						next if name == idfield
						v = r[name]
						next if v.length.zero?
						val[name] = convert v, f['type']
					end
					begin
						o = @client.upsert klass, idfield, r[idfield], val
						res << {
							idfield => r[idfield],
							'Type' => o.class == Net::HTTPCreated ? 'New' : 'Update',
							'Status' => true,
							'ErrorDescription' => nil,
						}
					rescue Databasedotcom::SalesForceError => e
						res << {
							idfield => r[idfield],
							'Type' => nil,
							'Status' => false,
							'ErrorDescription' => e.message,
						}
					end
				end
				show_table res, [idfield, 'Type', 'Status', 'ErrorDescription']
			rescue CSV::MalformedCSVError
				$stderr.puts 'Invalid csv'
			end
		end

		# delete command
		define_command_method :delete, <<EOS do |*args|
Delete from CSV local file.
  delete [sObject] [file name]
EOS
			begin
				raise CommandException.new if args.length != 2
				klass_name = args.shift.downcase
				klass = materialize klass_name
				desc = describe(klass_name)['fields']
				update_fields = desc.find_all{|f| f['updateable']}.map{|f| f['name']}
				csv = CSV.read args.shift, :headers => true
				idfield = csv.headers.find{|f| f.downcase == 'id'}
				unless idfield
					$stderr.puts 'csv file must has include "Id" column.'
					return
				end
				res = []
				csv.each do |r|
					begin
						@client.delete klass, r[idfield]
						res << {
							idfield => r[idfield],
							'Status' => true,
							'ErrorDescription' => nil,
						}
					rescue Databasedotcom::SalesForceError => e
						res << {
							idfield => r[idfield],
							'Status' => false,
							'ErrorDescription' => e.message,
						}
					end
				end
				show_table res, [idfield, 'Status', 'ErrorDescription']
			rescue CSV::MalformedCSVError
				$stderr.puts 'Invalid csv'
			end
		end

		# next command
		define_command_method :next, "Next page." do |*args|
			data = @data_history.last
			raise CommandException.new if data.nil? || data[:val].class != Databasedotcom::Collection || !data[:val].next_page?
			show_table data[:val].next_page, data[:col]
		end

		# sObject find command
		define_scommand_method :find, <<EOS do |klass, *args|
Find sObject record for ID or External ID.
  [sObject] find [ID]                                     # find ID record
  [sObject] find [External ID field name]/[External ID]   # find External ID record
EOS
			begin
				raise CommandException.new if args.length.zero?
				rid = args.shift
				raise CommandException.new unless show_sobjects_cols klass, klass.find(rid), args
			rescue Databasedotcom::SalesForceError => e
				$stderr.puts e.message
				$stderr.puts
			end
		end

		# sObject all command
		define_scommand_method :all, <<EOS do |klass, *args|
Show all sObject records.
  [sObject] all ([field list])
  ex.: User all "Id,FirstName"
EOS
			raise CommandException.new unless show_sobjects_cols klass, klass.all, args
		end

		# sObject full command
		define_scommand_method :full, "Show all sObject records." do |klass, *args|
			val = tmp = klass.all
			current_page = 1
			while tmp.next_page?
				$stderr.print "\rpage #{current_page}"
				tmp = tmp.next_page
				val += tmp
				current_page += 1
			end
			# val = Databasedotcom::Collection.new(@client, val.length).concat val
			raise CommandException.new unless show_sobjects_cols klass, val, args
		end

		# sObject count command
		define_scommand_method :count, <<EOS do |klass, *args|
Count all sObject records.
  [sObject] count
EOS
			count = klass.all.total_size
			puts "#{count} records"
			puts
		end

		# sObject first command
		define_scommand_method :first, <<EOS do |klass, *args|
Show first sObject record.
  [sObject] first ([field list])
  ex.: User first "Id,FirstName"
EOS
			o = klass.first
			os = o.nil? ? [] : [o]
			raise CommandException.new unless show_sobjects_cols klass, os, args
		end

		# sObject last command
		define_scommand_method :last, <<EOS do |klass, *args|
Show last sObject record.
  [sObject] last ([field list])
  ex.: User last "Id,FirstName"
EOS
			o = klass.last
			os = o.nil? ? [] : [o]
			raise CommandException.new unless show_sobjects_cols klass, os, args
		end

		# sObject query command
		define_scommand_method :query, <<EOS do |klass, *args|
SOQL query by sObject.
  [sObject] query [where expr] ([field list])   # [where expr] is WHERE part of a SOQL query
  ex.: User query "FirstName like 'R%'"
EOS
			raise CommandException.new if args.length.zero?
			where = args.shift
			raise CommandException.new unless show_sobjects_cols klass, klass.query(where), args
		end

		# sObject delete command
		define_scommand_method :delete, <<EOS do |klass, *args|
Delete sObject record for ID or External ID.
  [sObject] delete [ID]                                     # delete ID record
  [sObject] delete [External ID field name]/[External ID]   # delete External ID record
EOS
			raise CommandException.new if args.length.zero?
			args.each do |id|
				begin
					@client.delete klass, id
				rescue Databasedotcom::SalesForceError => e
					$stderr.puts e.message
					$stderr.puts
				end
			end
		end

		define_hcommand_method :export, <<EOS do |data, *args|
Export for CSV file (before command result data).
  [history] export               # export csv for stdout
  [history] export [file name]   # export csv for file
  ex.: $7:1,3 export example.csv
EOS
			export_csv data, *args
		end

		define_hcommand_method :delete, <<EOS do |data, *args|
Delete sObject records.
  [history] delete
  ex.: $7:1,3 delete
EOS
			raise CommandException.new unless args.length.zero?
			res = []
			data[:val].each do |v|
				unless v.class.superclass == Databasedotcom::Sobject::Sobject
					res << {
						'Id' => nil,
						'Status' => false,
						'ErrorDescription' => 'record is not sObject.',
					}
					next
				end
				begin
					@client.delete v.class, v.Id
					res << {
						'Id' => v.Id,
						'Status' => true,
						'ErrorDescription' => nil,
					}
				rescue Databasedotcom::SalesForceError => e
					res << {
						'Id' => v.Id,
						'Status' => false,
						'ErrorDescription' => e.message,
					}
				end
			end
			show_table res, ['Id', 'Status', 'ErrorDescription']
		end

		# materialize sObjects
		def materialize name
			@materialized = {} if @materialized.nil?
			name = name.downcase
			return @materialized[name] unless @materialized[name].nil?
			@materialized[name] = @client.materialize name
		end

		# describe sObjects
		def describe name
			@described = {} if @described.nil?
			name = name.downcase
			return @described[name] unless @described[name].nil?
			@described[name] = @client.describe_sobject name
		end

		# show sObjects table (ex. cols => 'Id,Name')
		def show_sobjects_cols klass, val, cols
			val = [val] if val.class.superclass == Databasedotcom::Sobject::Sobject
			return false if cols.length > 1
			col = cols.length == 0 ? nil : cols[0].split(',')
			show_sobjects klass, val, col
		end

		# show sObjects table (ex. cols => ['Id', 'Name'])
		def show_sobjects klass, val, cols = nil
			if cols.nil? || cols.length.zero?
				cols = klass.attributes
			else
				tmp = []
				cols.each do |c|
					flg = klass.attributes.find_index{|a| a.downcase == c.downcase}
					$stderr.puts "Unknown column: #{c}" if flg.nil?
					tmp << klass.attributes[flg] unless flg.nil?
				end
				cols = tmp
				cols << 'Id' if cols.length.zero?
			end
			show_table val, cols
		end

		# show table
		def show_table val, cols
			if @echo
				encode_args = ['euc-jp', {:undef => :replace, :replace => '??'}]
				col_width = {'#' => (val.length + 1).to_s.length}
				cols.each do |a|
					col_width[a] = val.inject(a.length){|max, v| [max, (v[a].class == String ? v[a].encode(*encode_args).bytesize + 2 : v[a].inspect.bytesize)].max}
				end
				line = "+" + col_width.values.map{|w| " " + "-" * w + " +"}.join

				# print table colmun
				puts line
				print "|", col_width.each_pair.map{|k, v| " " + k.center(v) + " |"}.join, "\n"
				puts line

				# print table data
				val.each_index do |i|
					o = val[i]
					print "| ", (i + 1).to_s.rjust(col_width['#']), " "
					print "|", col_width.select{|c| c != '#'}.each_pair.map{|k, v| " " + (o[k].class == String ? o[k].encode(@encoding).inspect : o[k].inspect) + " " * (v - (o[k].class == String ? o[k].encode(*encode_args).bytesize + 2 : o[k].inspect.bytesize)) + " |"}.join, "\n"
				end
				puts line
				puts "#{val.size} records"
				puts
			end

			# save after data
			@data_history << {:col => cols, :val => val}
		end

		# show help
		def show_help subject, base_cmd, help
			puts subject
			puts
			cmd_max = help.map{|h| h[0].length}.max
			indent = 4 + base_cmd.length + 1 + cmd_max + 5
			help.each do |h|
				print "    ", base_cmd, " ", h[0].to_s.ljust(cmd_max), "   # "
				help_lines = h[1].chomp.lines.to_a
				print help_lines.shift
				help_lines.each do |l|
					print " " * indent, l
				end
				puts
			end
			puts
		end

		# export csv
		def export_csv data, *args
			begin
				raise CommandException.new if data.nil?
				if args.length == 0
					io = $stdout
				elsif args.length == 1
					begin
						io = open args[0], 'w'
					rescue Errno::ENOENT => e
						raise CommandException.new e.message
					end
				else
					raise CommandException.new
				end
				CSV.instance io, :force_quotes => true do |writer|
					writer << data[:col]
					data[:val].each do |v|
						writer << data[:col].map{|c| v[c]}
					end
				end
				puts if io == $stdout
			ensure
				io.close if io != $stdout
			end
		end

		# history command
		def invoke_data_history history, nums, *args
			# history data
			if history == '$'
				data = @data_history.last
			else
				i = history[1..(history.length - 1)].to_i
				data = @data_history[i]
			end
			raise CommandException.new "data index error." if data.nil?
			# data slice
			if nums.nil?
				val = data[:val]
			else
				val = nums.split(/\s*,\s*/).inject([]){|arr, i|
					if /^(\d+)\s*-\s*(\d+)$/ =~ i
						arr += ($1.to_i..$2.to_i).to_a
					else
						arr << i.to_i
					end
					arr
				}.map{|i| data[:val][i - 1]}
				raise CommandException.new "data table index error." if val.include? nil
			end
			# execute
			if args.length == 0
				show_table val, data[:col]
			else
				hcommand = args.shift.downcase
				send "hcommand_#{hcommand}", {:col => data[:col], :val => val}, *args
			end
		end

		# convert csv data to sObject data
		def convert value, type
			case type
			when 'datetime'
				DateTime.parse value
			when 'date'
				Date.parse value
			when 'multipicklist'
				Date.parse value.split ';'
			when 'int'
				value.to_i
			when 'boolean'
				value.downcase == 'true' ? true : value.downcase == 'false' ? false : nil
			else
				value
			end
		end

		# command invoke
		def method_missing name, *args, &block
			# sObject command
			if match = /^command_([_a-z]\w*)$/.match(name.to_s)
				klass = materialize match[1]
				if args.length == 0
					attrs = klass.attributes.map do |a|
						{
							'Label' => klass.label_for(a),
							'Name' => a,
							'Type' => klass.field_type(a),
						}
					end
					show_table attrs, ['Label', 'Name', 'Type']
				else
					scommand = args.shift.downcase
					send "scommand_#{scommand}", klass, *args
				end
			# history data ($123)
			elsif match = /^command_\s*(\$\d*)\s*$/.match(name.to_s)
				invoke_data_history match[1], nil, *args
			# history data (1,3-5)
			elsif match = /^command_\s*((?:[1-9]\d*(?:\s*-\s*[1-9]\d*)?)(?:\s*,\s*[1-9]\d*(?:\s*-\s*[1-9]\d*)?)*)\s*$/.match(name.to_s)
				invoke_data_history '$', match[1], *args
			# history data ($123:1,3-5)
			elsif match = /^command_\s*(\$\d*)\s*:\s*((?:[1-9]\d*(?:\s*-\s*[1-9]\d*)?)(?:\s*,\s*[1-9]\d*(?:\s*-\s*[1-9]\d*)?)*)\s*$/.match(name.to_s)
				invoke_data_history match[1], match[2], *args
			# command error
			elsif /^(command|scommand|hcommand|configuration)_/ =~ name.to_s
				raise CommandException.new
			# method_missing
			else
				super
			end
		end
	end
end
