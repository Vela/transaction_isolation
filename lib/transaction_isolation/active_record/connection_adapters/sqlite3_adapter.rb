if defined?( ActiveRecord::ConnectionAdapters::SQLite3Adapter )

  module TransactionIsolation
    module ActiveRecord
      module ConnectionAdapters # :nodoc:
        module SQLite3Adapter

          def supports_isolation_levels?
            true
          end

          VENDOR_ISOLATION_LEVEL = {
              :read_uncommitted => 'read_uncommitted = 1',
              :read_committed => 'read_uncommitted = 0',
              :repeatable_read => 'read_uncommitted = 0',
              :serializable => 'read_uncommitted = 0'
          }
          
          ANSI_ISOLATION_LEVEL = {
              'read_uncommitted = 1' => :read_uncommitted,
              'read_uncommitted = 0' => :serializable
          }
          
          def current_isolation_level
            ANSI_ISOLATION_LEVEL[current_vendor_isolation_level]
          end

          def current_vendor_isolation_level
            "read_uncommitted = #{select_value( "PRAGMA read_uncommitted" )}"
          end
          
          def isolation_level( level )
            validate_isolation_level( level )

            original_vendor_isolation_level = current_vendor_isolation_level if block_given?
            
            execute "PRAGMA #{VENDOR_ISOLATION_LEVEL[level]}"

            begin
              yield
            ensure
              execute "PRAGMA #{original_vendor_isolation_level}"
            end if block_given?
          end
          
          def translate_exceptiont( exception, message )
            if isolation_conflict?( exception )
              ::ActiveRecord::TransactionIsolationConflict.new( "Transaction isolation conflict detected: #{exception.message}" )
            else
              super(exception, message)
            end
          end
          
          # http://www.sqlite.org/c3ref/c_abort.html
          def isolation_conflict?( exception )
            [ "The database file is locked",
              "A table in the database is locked",
              "Database lock protocol error"].any? do |error_message|
              exception.message =~ /#{Regexp.escape( error_message )}/i
            end
          end
        end
      end
    end
  end

  ActiveRecord::ConnectionAdapters::SQLite3Adapter.send( :include, TransactionIsolation::ActiveRecord::ConnectionAdapters::SQLite3Adapter )

end
