module OslMailstore
  module Cookbook
    module Helpers
      def postfixadmin_source
        'https://downloads.sourceforge.net/project/postfixadmin/postfixadmin-3.3.8/PostfixAdmin%203.3.8.tar.gz'
      end

      def postfixadmin_checksum
        '0a99da09a24ebe046075d2706845dc32fe96f2711c22085b29d95c6b6eaf59ed'
      end

      def postfix_queries
        {
          'virtual-alias-maps' => "SELECT goto FROM alias WHERE address='%s' AND active'1'",
          'virtual-alias-domain_maps' => "SELECT goto FROM alias,alias_domain WHERE alias_domain.alias_domain='%d' and alias.address=CONCAT('%u', '@', alias_domain.target_domain AND alias.active=1 AND alias_domain.active='1'",
          'virtual-alias-domain-catchall_maps' => "SELECT goto FROM alias,alias_domain WHERE alias_domain.alias_domain = '%d' and alias.address = CONCAT('@', alias_domain.target_domain) AND alias.active = 1 AND alias_domain.active='1'",
           'virtual-domains-maps' => "SELECT domain FROM domain WHERE domain='%s' AND active = '1'",
          'virtual-mailbox-maps' => "SELECT maildir FROM mailbox WHERE username='%s' AND active='1'",
          'virtual-alias-domain-mailbox-maps' => "SELECT maildir FROM mailbox,alias_domain WHERE alias_domain.alias_domain = '%d' and mailbox.username = CONCAT('%u', '@', alias_domain.target_domain) AND mailbox.active = 1 AND alias_domain.active='1'",
          'relay-domains' => "SELECT domain FROM domain WHERE domain='%s' AND active = '1' AND (transport LIKE 'smtp%%' OR transport LIKE 'relay%%')",
          'transport-maps' => "SELECT REPLACE(transport, 'virtual', ':') AS transport FROM domain WHERE domain='%s' AND active = '1'",
        }
      end

      def dovecot_password_query
        "SELECT username AS user,password FROM mailbox WHERE username='%u' AND active='1'"
      end

      def dovecot_user_query
        "SELECT CONCAT('/var/mail/vmail/', maildir) AS home, 1001 AS uid, 1001 AS gid, CONCAT('*:bytes=', quota) AS quota_rule FROM mailbox WHERE username='%u' AND active='1'"
      end

      def dovecot_iterate_query
        "SELECT username as user FROM mailbox WHERE active='1'"
      end
    end
  end
end

Chef::DSL::Recipe.include ::OslMailstore::Cookbook::Helpers
Chef::Resource.include ::OslMailstore::Cookbook::Helpers
