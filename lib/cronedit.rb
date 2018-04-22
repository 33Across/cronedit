# :title:CronEdit - Ruby editior library for cron and crontab - RDoc documentation
# =CronEdit - Ruby editor library for crontab.
# 
# Allows to manipulate crontab from comfortably from ruby code. 
# You can add/modify/remove (aka CRUD) named crontab entries individually with no effect on the rest of your crontab.
# You can define cron entry definitions as standart text definitions <tt>'10 * * * * echo 42'</tt> or using Hash notation <tt>{:minute=>10, :command=>'echo 42'}</tt> (see CronEntry ::DEFAULTS)
# Additionaly you can parse cron text definitions to Hash.
# 
# ==Usage
# 
# Class methods offer quick crontab operations. Three examples:
#       CronEdit::Crontab.Add  'agent1', '5,35 0-23/2 * * * echo agent1'
#       CronEdit::Crontab.Add  'agent2', {:minute=>5, :command=>'echo 42'}
#       CronEdit::Crontab.Remove 'someId'
# 
# or define a batch update and list the current content: 
# 
#       cm = CronEdit:Crontab.new 'user'
#       cm.add 'agent1', '5,35 0-23/2 * * * echo agent1'
#       ...
#       cm.add 'agent2', {:minute=>5, :command=>'echo 42'}
#       cm.commit
#       p cm.list
#       
# see Crontab for all available methods
# ==Author
# Viktor Zigo, http://7inf.com, All rights reserved. You can redistribute it and/or modify it under the same terms as Ruby.
# (parts of the  cron definition parsing code originaly by gotoken@notwork.org)
# ==History
# version: 0.2.0 
#
# ==TODO
# add more commands (clean crontab); lift some methods to class; put tests to separate file; make rake, make gem; implement addAllfrom
# add Utils: getNext execution
module CronEdit
    self::VERSION = '0.2.0' unless defined? self::VERSION
        
    class Crontab
        # Use crontab for user aUser
        def initialize aUser = nil
            @user = aUser
            rollback()
        end

        class <<self
            # Add a new crontab entry definition. See instance add method
            def Add anId, aDef
                cm = Crontab.new
                entry = cm.add anId, aDef
                cm.commit
                entry
            end
        
            # Remove a crontab entry definition identified by anId from current crontab.
            def Remove anId
                cm = Crontab.new
                cm.remove anId
                cm.commit
            end
        
            # List current crontab.
            def List
                Crontab.new.list
            end
        end
    
        # Add a new crontab entry definition. Becomes effective only after commit().
        # * aDef is can be a standart text definition or a Hash definition (see CronEntry::DEFAULTS)
        # * anId is an identification of the entry (for later modification or deletion)
        # returns newly added CronEntry
        def add anId, aDef
            @adds[anId.to_s] = CronEntry.new( aDef )
        end

        # Bulk addition of  crontab entry definitions from stream (String, File, IO)
        def addAllFrom anIO
            #TODO: load file, parse it 
            raise 'Not implemented yet'
        end 
    
        # Remove a crontab entry definition identified by anId. Becomes effective only after commit().
        def remove anId
            @adds.delete anId.to_s
            @removals[anId.to_s]=anId.to_s
        end
    
        # Merges the existing crontab with all modifications and installs the new crontab.
        # returns the merged parsed crontab hash
        def commit
            # merge crontab
            current = list()
            current.delete_if {|id, entry| @removals.include? id}
            merged = current.merge @adds
        
            # install it
            cmd = @user ? "crontab -u #{@user} -" : "crontab -"
            IO.popen(cmd,'w') {|io|
                merged.each {|id, entry|
                    io.puts "# #{id}"
                    io.puts entry
                }
                io.close
            }
            # No idea why but without this any wait crontab reads and writes appears not synchronizes
            sleep 0.01
            #clean changes :)
            rollback()
            merged
        end
    
        # Discards all modifications (since last commit, or creation)
        def rollback
            @adds = {}
            @removals = {}
        end
    
        # Prints out the items to be added and removed
        def review
            puts "To be added: #{@adds.inspect}"
            puts "To be removed: #{@removals.keys.inspect}"
        end
        
        # Read the current crontab and parse it
        # returns a Hash (entry id or index)=>CronEntry
        def list
            cmd = @user ? "crontab -u #{@user} -l" : "crontab -l"
            IO.popen(cmd) {|io|
                return parseCrontab(io)
            }
        end

        # Lists raw content from crontab
        # returns array of text lines
        def listRaw
            cmd = @user ? "crontab -u #{@user} -l" : "crontab -l"
            IO.popen(cmd) {|io|
                    entries = io.readlines
                    return (entries.first =~ /^no/).nil? ? entries : []
            }
        end    

        def parseCrontab anIO
                entries = {}
                idx = 0
                id = nil
                anIO.each_line { |l|
                    l.strip!
                    next if l.empty?
                    return {} unless (l =~ /^no/).nil?
                    if l=~/^#/ 
                        id = l[1, l.size-1].strip
                    else 
                        key = id.nil? ? (idx+=1) : id
                        entries[key.to_s]=l
                        id = nil
                    end
                }
                entries
        end    
    end 


    class CronEntry
        DEFAULTS = {
            :minute => '*',
            :hour => '*',
            :day => '*',
            :month => '*',
            :weekday => '*',
            :command => ''
        }

        class FormatError < StandardError; end
    
        # Hash def, or raw String def
        def initialize aDef = {}
            if aDef.kind_of? Hash  
                wrong = aDef.collect { |k,v| DEFAULTS.include?(k) ? nil : k}.compact
                raise "Wrong definition, invalid constructs #{wrong}" unless wrong.empty?
                @defHash = DEFAULTS.merge aDef
                # TODO: validate values
                @def = to_raw @defHash ;
            else
                @defHash = parseTextDef aDef
                @def = aDef;
            end
        end
        
        def to_s
            @def.freeze
        end
    
        def to_hash
            @defHash.freeze
        end
    
        def []aField
            @defHash[aField]
        end
    
        def to_raw aHash = nil;
            aHash ||= @defHash
            "#{aHash[:minute]}\t#{aHash[:hour]}\t#{aHash[:day]}\t#{aHash[:month]}\t"  +
                "#{aHash[:weekday]}\t#{aHash[:command]}"
        end
    
   private 
    
        # Parses a raw text definition of crontab entry
        # returns hash definition
        # Original author of parsing: gotoken@notwork.org
        def parseTextDef aLine
            hashDef = parse_timedate aLine
            hashDef[:command] = aLine.scan(/(?:\S+\s+){5}(.*)/).shift[-1]
            ##TODO: raise( FormatError.new "Command cannot be empty") if aDef[:command].empty?
            hashDef
        end
    
        # Original author of parsing: gotoken@notwork.org
        def parse_timedate str, aDefHash = {}
            minute, hour, day_of_month, month, day_of_week = 
                str.scan(/^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/).shift
            day_of_week = day_of_week.downcase.gsub(/#{WDAY.join("|")}/){
                WDAY.index($&)
            }
            aDefHash[:minute] = parse_field(minute,       0, 59)
            aDefHash[:hour] =  parse_field(hour,         0, 23)
            aDefHash[:day] =    parse_field(day_of_month, 1, 31)
            aDefHash[:month] =    parse_field(month,        1, 12)
            aDefHash[:weekday] =    parse_field(day_of_week,  0, 6)
            aDefHash
        end

        # Original author of parsing: gotoken@notwork.org
        def parse_field str, first, last
            list = str.split(",")
            list.map!{|r|
                r, every = r.split("/")
                every = every ? every.to_i : 1
                f,l = r.split("-")
                range = if f == "*"
                        first..last
                    elsif l.nil?
                        f.to_i .. f.to_i
                    elsif f.to_i < first
                        raise FormatError.new( "out of range (#{f} for #{first})")
                    elsif last < l.to_i
                        raise FormatError.new( "out of range (#{l} for #{last})")
                    else
                        f.to_i .. l.to_i
                  end
                range.to_a.find_all{|i| (i - first) % every == 0}
            }
            list.flatten!
            list.join ','
        end    

        WDAY = %w(sun mon tue wed thu fri sut)
    end

end 

if  __FILE__ == $0
    include CronEdit
    

    

    ents = [
        CronEntry.new( "5,35 0-23/2 * * * echo 123" ),
        CronEntry.new,
        CronEntry.new( {:minute=>5, :command=>'echo 42'} ),
    ]
    ents.each { |e| puts e }

    e= CronEntry.new( "5,35 0-23/2 * * * echo 123" )
    puts "Minute: #{e[:minute].inspect}"
    puts "Hour: #{e[:hour].inspect}"
    puts "Day: #{e[:day].inspect}"
    p e.to_s
    p e.to_hash
    p e.to_raw

    begin
        CronEntry.new( {:minuteZ=>5, :command=>'echo 42'} )
        puts "Failure failed"
    rescue         
    end

    begin
        CronEntry.new( "1-85 2 * * * echo 123" )
        puts "Failure failed"
    rescue  CronEntry::FormatError
    end

    crontabTest=%Q{
    5,35 0-23/2 * * * echo 123
    #agent1
    3 * * * * echo agent1


    #agent2
    3 * * * * echo agent2
    #ignored comment
    #agent1
    3 * * * * echo agent3
  }
    puts "Crontab raw:  #{Crontab.new.listRaw.inspect}"
    puts "Crontab:  #{Crontab.new.list.inspect}"
    puts "Crontab test:  #{Crontab.new.parseCrontab(crontabTest).inspect }"

    #rollback test
    cm = Crontab.new
    cm. add 'agent1', '5,35 0-23/2 * * * "echo 123" '
    cm.remove "agent2"
    cm.review
    cm.rollback
    
    #commit test
    cm = Crontab.new
    cm. add "agent1", "5,35 0-23/2 * * * echo agent1" 
    cm. add "agent2", "0 2 * * * echo agent2" 
    cm.commit
    current=cm.list
    puts "New crontab 1:  #{current.inspect}"  
    
    cm = Crontab.new
    cm. add "agent1", '59 * * * * echo "modified agent1"'
    cm.remove "agent2"
    cm.commit
    current=Crontab.List 
    puts "New crontab 2:  #{current.inspect}"
    raise "Assertion" unless current=={'agent1'=> '59 * * * * echo "modified agent1"'}
end
