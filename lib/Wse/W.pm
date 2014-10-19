package Wse::W;
use Mojo::Base 'Mojolicious::Controller';

sub index{
    my $self = shift;

	#session setup
	unless(exists($self->session->{'logged_in'})){
		$self->session(logged_in => 0);
	}

	$self->render(
        template => 'index',
		javascripts => [''],
		styles => ['']
    );
}
1;