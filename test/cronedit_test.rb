$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'cronedit.rb'
include CronEdit

class CronEdit_test < Test::Unit::TestCase
#  def setup
#  end
#
#  def teardown
#  end

    def test_creation
        e = CronEntry.new( "5,35 0-23/2 * * * echo 123" )
        assert_equal( '5,35 0-23/2 * * * echo 123', e.to_s )
    
        e = CronEntry.new
        assert_equal( "*\t*\t*\t*\t*\t", e.to_s, 'default' )

        e = CronEntry.new( {:minute=>5, :command=>'echo 42'} )
        assert_equal( "5\t*\t*\t*\t*\techo 42", e.to_s )
    
    end
    
    def test_parsing
        e = CronEntry.new( "5,35 0-23/2 * * * echo 123" )
        assert_equal( "5,35", e[:minute])
        assert_equal( "0,2,4,6,8,10,12,14,16,18,20,22", e[:hour])
        assert_equal( "1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31", e[:day])
    end
  def test_wrongformat
        assert_raise(CronEntry::FormatError){
            CronEntry.new( "1-85 2 * * * echo 123" )
        }
  end

    def test_wrongconfog
        assert_raise(RuntimeError){
            CronEntry.new( {:minuteZ=>5, :command=>'echo 42'} )
        }
    end
  
    def test_zip
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
        expected = {"agent1"=>"3 * * * * echo agent3", "agent2"=>"3 * * * * echo agent2", "1"=>"5,35 0-23/2 * * * echo 123"}
        assert_equal( expected, Crontab.new.parseCrontab(crontabTest), 'parsing of crontab file')
    end

    def test_emptycrontab
        assert_equal( [], Crontab.new.listRaw )
        assert_equal( {}, Crontab.new.list )
    end

    def test_rollback
        #rollback test
        assert_equal( {}, Crontab.new.list, 'precondition' )
        cm = Crontab.new
        cm. add 'agent1', '5,35 0-23/2 * * * "echo 123" '
        cm.remove "agent2"
        #cm.review
        cm.rollback
        assert_equal( {}, Crontab.new.list )
    end

    def test_commit
            assert_equal( {}, Crontab.new.list, 'precondition' )
            cm = Crontab.new
            cm. add "agent1", "5,35 0-23/2 * * * echo agent1" 
            cm. add "agent2", "0 2 * * * echo agent2" 
            cm.commit
            current=cm.list
            expected = {"agent1"=>"5,35 0-23/2 * * * echo agent1", "agent2"=>"0 2 * * * echo agent2"}
            assert_equal( expected, current, 'first commit' )
    
            cm = Crontab.new
            cm. add "agent1", '59 * * * * echo "modified agent1"'
            cm.remove "agent2"
            cm.commit
            current = cm.list
            expected = {"agent1"=>"59 * * * * echo \"modified agent1\""}
            assert_equal( expected, current, 'second commit' )
    
            Crontab.Remove "agent1"
            assert_equal( {}, Crontab.List, 'precondition' )
    end

end
