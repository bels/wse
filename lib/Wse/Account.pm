package Wse::Account;
use Mojo::Base 'Mojolicious::Controller';

sub register{
    my $self = shift;
    
    my $dbh = $self->app->dbh;
    
    my $query = "select * from get_password_reset_question_list()";
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my $rs = $sth->fetchall_arrayref({});

    $self->stash(password_reset_questions => $rs);
    
    $self->render(
        template => 'register',
		javascripts => [],
		styles => []
    );
}

sub register_submit{
	my $self = shift;
	
	my $rules = {
		username => {
			rules =>['required'],
			error => {
				required => 'Please enter a username.'
			}
		},
		password1 => {
			rules => ['required'],
			error => {
				required => 'Please enter a password.'
			}
		},
		password2 => {
			rules => ['required',{match => 'password1'}],
			error => {
				required => 'Please enter your password again.',
				match => 'Your passwords did not match.'
			}
		},
		email => {
			rules =>['email','required'],
			error => {
				required => 'Please enter an email address.',
				email => 'Please enter a valid email address.'
			}
		}
	};
	$self->validator->rules($rules);
	#create a hash of the post params
	my $post = {};
	my @params = $self->param;
	foreach my $name (@params){
		$post->{$name} = $self->param($name);
	}

	if($self->validator->validate($post)){
        my $dbh = $self->app->dbh;
        my $query = "select * from duplicate_name_check(?)";
		my $sth = $dbh->prepare($query);
		$sth->execute($self->param('username'));
		my $rs = $sth->fetchrow_hashref;
		if(!$rs->{'duplicate_name_check'}){
            srand(time ^ $$ ^ unpack "%L*", `ps axww | gzip`);
            my $random_seed = int(rand(999999));
            $query = "select * from register (?,?,?,?,?,?)";
            $sth = $dbh->prepare($query);
            $sth->execute($self->param('username'),$self->param('password1'),$self->param('password_reset_question'),$self->param('password_reset_answer'),$self->param('email'),$random_seed);
            my $auth_code = $sth->fetchrow_hashref;
            if($dbh->err != 7){
                $query = "select email_server_address from site_configuration";
                $sth = $dbh->prepare($query);
                $sth->execute;
                my $mail_server = $sth->fetchrow_hashref;
                $self->flash(success => 'Successfully Registered');
                my $url = 'http://www.coingamers.com:8080/activate/' . $self->param('username') . '/' . $auth_code->{'register'};
                $self->send_email({email => $self->param('email'), subject => 'WSE account registration', mail_server => $mail_server->{'email_server_address'}, message_body => 'Hello and thank you for creating a WSE account.  Your account information is\n\n------------\n Username: ' . $self->param('username') . '\n Activation code: ' . $auth_code->{'register'} . '\n------------\n\nTo activate your account click: ' . $url});
                $self->redirect_to($self->url_for('login'));
            } else {
                $self->flash(error => 'Registeration failed.');
            }
        } else {
			$self->flash(error => 'That name is already taken.  Please try registering with a different name.');
		}
	}
	
	$self->redirect_to($self->url_for('register'));
}

sub activate{
    my $self = shift;
    
    my ($name,$activation_code) = ($self->param('name'),$self->param('code'));
    my $dbh = $self->app->dbh;
    my $query = "select * from activate(?,?)";
    my $sth = $dbh->prepare($query);
    $sth->execute($name,$activation_code);
    my $rs = $sth->fetchrow_hashref;
    if($rs->{'activate'}){
        $query = "select id from accounts where name = ?";
        $sth = $dbh->prepare($query);
        $sth->execute($self->param('name'));
        my $id = $sth->fetchrow_hashref;
        my $address = $self->get_new_address;
        $query = "select update_account(?,?,?)";
        $sth = $dbh->prepare($query);
        $sth->execute('deposit_address',$address,$id->{'id'});
        $self->flash(success => 'Successfully Activated');
        $self->redirect_to($self->url_for('login'));
    } else {
        $self->flash(error => 'Failed to activate. Maybe already active or you have the wrong activation code.');
        $self->redirect_to($self->url_for('index'));
    }
}

sub login{
	my $self = shift;

    if($self->session->{'logged_in'} == 1){
        $self->redirect_to($self->url_for('profile'));
    } else {
        $self->render(
            template => 'login',
            javascripts => [],
            styles => []
        );
    }
}

sub auth{
	my $self = shift;
	
	my $username = $self->param('username');
	my $password = $self->param('password');
	my $dbh = $self->app->dbh;
	#check for 3 login failures within ten minutes
	my $query = "select count(*) from bad_login_attempt where login_time BETWEEN now()::timestamp - (interval '10 minutes') AND now()::timestamp AND ip_address = ?";
	my $sth = $dbh->prepare($query);
	$sth->execute($self->tx->remote_address);
	my $bad_attempts = $sth->fetchrow_hashref;
	if($bad_attempts->{'count'} < 3){
	      $query = "select * from authenticate(?,?)";
	      $sth = $dbh->prepare($query);
	      $sth->execute($username,$password);
	      my $rs = $sth->fetchrow_hashref;
	      
	      if($rs->{'authenticate'}){
		      $query = "select * from get_account_overview(?)";
		      $sth = $dbh->prepare($query);
		      $sth->execute($username);
		      $rs = $sth->fetchrow_hashref;
		      $self->session(
			      logged_in => 1,
			      username => $rs->{'name'},
			      last_login => $rs->{'last_login'},
			      joined => $rs->{'joined'},
			      id => $rs->{'id'},
				  deposit_address => $rs->{'deposit_address'}
		      );
		      $self->redirect_to($self->url_for('profile'));
	      } else {
		      $query = "insert into bad_login_attempt (ip_address) values(?)";
		      $sth = $dbh->prepare($query);
		      $sth->execute($self->tx->remote_address);
		      $self->flash(error => 'Wrong username or password.  Please try again.');
		      $self->redirect_to($self->url_for('login'));
	      }
	} else {
	      $self->flash(error => 'You have failed login 3 times. Please wait 10 minutes before trying again. This is to help protect your security.');
	      $self->redirect_to($self->url_for('login'));
	}
	
}

sub logout{
	my $self = shift;
	
    my $dbh = $self->app->dbh;
    my $query = "select * from logout(?)";
    my $sth = $dbh->prepare($query);
    $sth->execute($self->session('name'));
	$self->session(expires => 1);
	$self->redirect_to($self->url_for('index'));
}

sub profile{
	my $self = shift;

    if($self->session->{'logged_in'} == 1){
		$self->check_balance({address => $self->session->{'deposit_address'}, id => $self->session->{'id'}});
        my $dbh = $self->app->dbh;
        my $query = "select * from get_account_overview(?::UUID)";
        my $sth = $dbh->prepare($query);
        $sth->execute($self->session->{'id'});
        my $account_overview = $sth->fetchrow_hashref;
        $query = "select * from get_securities_held(?)";
        $sth = $dbh->prepare($query);
        $sth->execute($self->session->{'id'});
        my $holdings = $sth->fetchall_arrayref({});
        $query = "select * from distribution_schedules";
        $sth = $dbh->prepare($query);
        $sth->execute();
        my $distribution_schedule = $sth->fetchall_arrayref({});
        $query = "select * from security_types";
        $sth = $dbh->prepare($query);
        $sth->execute();
        my $security_types = $sth->fetchall_arrayref({});
        
        
        $self->stash(
            holdings => $holdings,
            account_overview => $account_overview,
            distribution_schedule => $distribution_schedule,
            security_types => $security_types
        );
        $self->render(
            template => 'profile',
            javascripts => ['profile.js'],
            styles => []
        );
    } else {
        $self->redirect_to($self->url_for('login'));
    }
}

sub withdraw{
    my $self = shift;
    
    if($self->session->{'logged_in'} == 1){
		if($self->have_enough_coins($self->param('withdraw_amount'))){
			$self->withdraw_funds({withdraw_address => $self->param('withdraw_address'),withdraw_amount => $self->param('withdraw_amount')});
			$self->redirect_to($self->url_for('profile'));
		} else {
			$self->flash(error => 'You are trying to withdraw more coins than you have.');
			$self->redirect_to($self->url_for('profile'));
		}
    } else {
        $self->redirect_to($self->url_for('login'));
    }
}

sub set_withdraw_address{
	my $self = shift;
	
	if($self->session->{'logged_in'} == 1){
		my $dbh = $self->app->dbh;
		my $query = "update account_profile set withdraw_address = ? where account = ?";
		my $sth = $dbh->prepare($query);
		$sth->execute($self->param('new_withdraw_address'),$self->session->{'id'});
		$self->flash(success => 'Updated your withdraw address');
		$self->redirect_to($self->url_for('profile'));
	} else {
		$self->flash(error => 'You need to login to update your withdraw address');
		$self->redirect_to($self->url_for('login'));
	}
}
1;