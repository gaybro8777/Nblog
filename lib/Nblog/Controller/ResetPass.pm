use strict;
use warnings;

package Nblog::Controller::ResetPass;
use Moose;
use MooseX::NonMoose;
use Plack::Response;
use String::Random 'random_regex';

use Email::Sender::Simple qw(sendmail);
use Email::Simple;
use Email::Simple::Creator;

use feature ':5.10'; 

extends 'WebNano::Controller';

sub index_action {
   my ( $self ) = @_;
   my $req = $self->req;
   if( $req->method eq 'POST' ){
       my $user = 
       $self->app->schema->resultset( 'User' )->search({ username =>  $req->param( 'username' ) })->next
       ||
       $self->app->schema->resultset( 'User' )->search({ email => 2005 })->next;
       if( !$user ){
           return $self->render( template => \"User not found" );
       }
       else{
           $user->update({ pass_token => random_regex( '\w{40}' ) });
           $self->send_pass_token( $user );
           return $self->render( template => \"Email sent" );
       }
   }
   return $self->render();
}

sub send_pass_token {
    my( $self, $user ) = @_;
    my $env = $self->env;
    my $my_server = $env->{HTTP_ORIGIN} //
    ( $env->{'psgi.url_scheme'} // 'http' ) . '://' . 
    ( $env->{HTTP_HOST} // 
        $env->{SERVER_NAME} . 
        ( $env->{SERVER_PORT} && $env->{SERVER_PORT} != 80 ? ':' . $env->{SERVER_PORT} : '' )
    );
    my $email = Email::Simple->create(
      header => [
        To      => $user->email,
        From    => 'root@localhost',
        Subject => "Password reset",
      ],
      body => $my_server . $self->self_url . 'reset/' . $user->id . '/' . $user->pass_token ,
    );

    sendmail($email);
}

sub reset_action {
    my ( $self, $id, $token ) = @_;
    my $req = $self->req;
    my $user = 
       $self->app->schema->resultset( 'User' )->find( $id );
    if( !( $user && $user->pass_token eq $token ) ){
        return 'Token invalid';
    }
    else{
        if( $req->method eq 'POST' ){
            $user->pass_token( undef );
            $user->password( $req->param( 'password' ) );
            $user->update();
            return 'Password reset';
        }
        else{
            return '<form method="POST">New password:<input type="text" name="password"><input type="submit"></form>';
        }
    }
}


1;
