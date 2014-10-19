package Wse::System;
use Mojo::Base 'Mojolicious::Controller';

sub admin{
    my $self = shift;
    
    my $dbh = $self->app->dbh;
    my $query = "select * from accounts where id = ?";
    my $sth = $dbh->prepare($query);
    $sth->execute($self->session->{'id'});
    my $is_admin = $sth->fetchrow_hashref;
    
    if($self->session->{'logged_in'} == 1 && $is_admin->{'administrator'}){
        $dbh = $self->app->dbh;
        $query = "select * from get_unapproved_securities()";
        $sth = $dbh->prepare($query);
        $sth->execute;
        my $unapproved_securities = $sth->fetchall_arrayref({});
        $query = "select * from get_site_config()";
        $sth = $dbh->prepare($query);
        $sth->execute;
        my $site_config = $sth->fetchrow_hashref;
        $self->stash(
            unapproved_securities => $unapproved_securities,
            site_config => $site_config
        );
        $self->render(
            template => 'admin',
            javascripts => ['admin.js'],
            styles => []
        );
    } else {
        $self->redirect_to($self->url_for('login'));
    }
}

1;