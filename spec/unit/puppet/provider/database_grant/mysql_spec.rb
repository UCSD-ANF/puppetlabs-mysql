require 'puppet'
require 'mocha'
RSpec.configure do |config|
  config.mock_with :mocha
end
provider_class = Puppet::Type.type(:database_grant).provider(:mysql)
describe provider_class do
  before :each do
    @resource = Puppet::Type::Database_grant.new(
      { :privileges => 'all', :provider => 'mysql', :name => 'user@host'}
    )
    @provider = provider_class.new(@resource)
  end
  it 'should query privilegess from the database' do
    provider_class.expects(:mysql) .with('mysql', '-Be', 'describe user').returns <<-EOT
Field	Type	Null	Key	Default	Extra
Host	char(60)	NO	PRI		
User	char(16)	NO	PRI		
Password	char(41)	NO			
Select_priv	enum('N','Y')	NO		N	
Insert_priv	enum('N','Y')	NO		N	
Update_priv	enum('N','Y')	NO		N
EOT
    provider_class.expects(:mysql).with('mysql', '-Be', 'describe db').returns <<-EOT
Field	Type	Null	Key	Default	Extra
Host	char(60)	NO	PRI		
Db	char(64)	NO	PRI		
User	char(16)	NO	PRI		
Select_priv	enum('N','Y')	NO		N	
Insert_priv	enum('N','Y')	NO		N	
Update_priv	enum('N','Y')	NO		N
EOT
    provider_class.user_privs.should == [ 'Select_priv', 'Insert_priv', 'Update_priv' ]
    provider_class.db_privs.should == [ 'Select_priv', 'Insert_priv', 'Update_priv' ]
  end

  it 'should query set priviliges' do
    provider_class.expects(:mysql).with('mysql', '-Be', 'select * from user where user="user" and host="host"').returns <<-EOT
Host	User	Password	Select_priv	Insert_priv	Update_priv
host	user		Y	N	Y
EOT
    @provider.privileges.should == [ 'Select_priv', 'Update_priv' ]
  end

  it 'should recognize when all priviliges are set' do
    provider_class.expects(:mysql).with('mysql', '-Be', 'select * from user where user="user" and host="host"').returns <<-EOT
Host	User	Password	Select_priv	Insert_priv	Update_priv
host	user		Y	Y	Y
EOT
    @provider.all_privs_set?.should == true
  end

  it 'should recognize when all privileges are not set' do
    provider_class.expects(:mysql).with('mysql', '-Be', 'select * from user where user="user" and host="host"').returns <<-EOT
Host	User	Password	Select_priv	Insert_priv	Update_priv
host	user		Y	N	Y
EOT
    @provider.all_privs_set?.should == false
  end

  it 'should be able to set all privileges' do
    provider_class.expects(:mysql).with('mysql', '-NBe', 'SELECT "1" FROM user WHERE user = \'user\' AND host = \'host\'').returns "1\n"
    provider_class.expects(:mysql).with('mysql', '-Be', "update user set Select_priv = 'Y', Insert_priv = 'Y', Update_priv = 'Y' where user=\"user\" and host=\"host\"")
    provider_class.expects(:mysqladmin).with("flush-privileges")
    @provider.privileges=(['all'])
  end

  it 'should be able to set partial privileges' do
    provider_class.expects(:mysql).with('mysql', '-NBe', 'SELECT "1" FROM user WHERE user = \'user\' AND host = \'host\'').returns "1\n"
    provider_class.expects(:mysql).with('mysql', '-Be', "update user set Select_priv = 'Y', Insert_priv = 'N', Update_priv = 'Y' where user=\"user\" and host=\"host\"")
    provider_class.expects(:mysqladmin).with("flush-privileges")
    @provider.privileges=(['Select_priv', 'Update_priv'])
  end

  it 'should be case insensitive' do
    provider_class.expects(:mysql).with('mysql', '-NBe', 'SELECT "1" FROM user WHERE user = \'user\' AND host = \'host\'').returns "1\n"
    provider_class.expects(:mysql).with('mysql', '-Be', "update user set Select_priv = 'Y', Insert_priv = 'Y', Update_priv = 'Y' where user=\"user\" and host=\"host\"")
    provider_class.expects(:mysqladmin).with('flush-privileges')
    @provider.privileges=(['SELECT_PRIV', 'insert_priv', 'UpDaTe_pRiV'])
  end
end
