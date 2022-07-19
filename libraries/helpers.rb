module OslMailstore
  module Cookbook
    module Helpers
      def postfixadmin_source
        'https://downloads.sourceforge.net/project/postfixadmin/postfixadmin-3.3.8/PostfixAdmin%203.3.8.tar.gz'
      end

      def postfixadmin_checksum
        '0a99da09a24ebe046075d2706845dc32fe96f2711c22085b29d95c6b6eaf59ed'
      end
    end
  end
end

Chef::DSL::Recipe.include ::OslMailstore::Cookbook::Helpers
Chef::Resource.include ::OslMailstore::Cookbook::Helpers
