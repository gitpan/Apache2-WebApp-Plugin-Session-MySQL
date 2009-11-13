#----------------------------------------------------------------------------+
#
#  Apache2::WebApp::Plugin::Session::MySQL - Plugin providing session storage 
#
#  DESCRIPTION
#  Store persistent data in a MySQL database.
#
#  AUTHOR
#  Marc S. Brooks <mbrooks@cpan.org>
#
#  This module is free software; you can redistribute it and/or
#  modify it under the same terms as Perl itself.
#
#----------------------------------------------------------------------------+

package Apache2::WebApp::Plugin::Session::MySQL;

use strict;
use base 'Apache2::WebApp::Plugin';
use Apache::Session::MySQL;
use Apache::Session::Lock::MySQL;
use Params::Validate qw( :all );

our $VERSION = 0.02;

#~~~~~~~~~~~~~~~~~~~~~~~~~~[  OBJECT METHODS  ]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

#----------------------------------------------------------------------------+
# new()
#
# Constructor method used to instantiate a new Session object.

sub new {
    my $class = shift;
    return bless( {}, $class );
}

#----------------------------------------------------------------------------+
# create( \%controller, $name, \%data )
#
# Create a new session within the database.  Return the session_id.

sub create {
    my ( $self, $c, $name, $data_ref )
      = validate_pos( @_,
          { type => OBJECT  },
          { type => HASHREF },
          { type => SCALAR  },
          { type => HASHREF }
          );

    my $dbh = $c->stash('DBH');     # use an existing connection

    # create table if it doesn't exist
    eval {
        $dbh->do(qq{
            CREATE TABLE IF NOT EXISTS sessions (
                id char(32) NOT NULL PRIMARY KEY,
                a_session text
            )
          });
    };

    if ($@) {
        $self->error( $c, 'Database CREATE failed', $dbh->errstr );
    }

    my %session;

    eval {
        tie %session, 'Apache::Session::MySQL', undef, {
            Handle     => $dbh,
            LockHandle => $dbh,
        };
    };

    if ($@) {
        $self->error("Failed to create session: $@");
    }

    foreach my $key (keys %$data_ref) {
        $session{$key} = $data_ref->{$key};     # merge hash key/values
    }

    my $id = $session{_session_id};

    untie %session;

    return $id;
}

#----------------------------------------------------------------------------+
# get( \%controller, $name, $id )
#
# Return session data as a hash reference.

sub get {
    my ( $self, $c, $name, $id )
      = validate_pos( @_,
          { type => OBJECT },
          { type => HASHREF },
          { type => SCALAR },
          { type => SCALAR, optional => 1 }
          );

    my $cookie = $c->plugin('Cookie')->get($name) || $id;

    my $session_id = ($cookie) ? $cookie : 'null';

    my $dbh = $c->stash('DBH');     # use an existing connection

    my %session;

    eval {
        tie %session, 'Apache::Session::MySQL', $session_id, {
            Handle     => $dbh,
            LockHandle => $dbh,
        };
    };

    unless ($@) {
        my %values = %session;

        untie %session;

        return \%values;
    }

    return;
}

#----------------------------------------------------------------------------+
# delete( \%controller, $name )
#
# Delete an existing session.  Remove the referring cookie.

sub delete {
    my ( $self, $c, $name )
      = validate_pos( @_,
          { type => OBJECT  },
          { type => HASHREF },
          { type => SCALAR  }
          );

    my $doc_root = $c->config->{apache_doc_root};

    my $cookie = $c->plugin('Cookie')->get($name);

    my $id = ($cookie) ? $cookie : 'null';

    my $dbh = $c->stash('DBH');     # use an existing connection

    my %session;

    eval {
        tie %session, 'Apache::Session::MySQL', $id, {
            Handle     => $dbh,
            LockHandle => $dbh,
        };
    };

    unless ($@) {
        tied(%session)->delete;

        $c->plugin('Cookie')->delete( $c, $name );
    }

    return;
}

#----------------------------------------------------------------------------+
# update( \%controller, $name, \%data );
#
# Update existing session data.

sub update {
    my ( $self, $c, $name, $data_ref )
      = validate_pos( @_,
          { type => OBJECT  },
          { type => HASHREF }
          { type => SCALAR  },
          { type => HASHREF }
          );

    my $cookie = $c->plugin('Cookie')->get($name);

    my $id = ($cookie) ? $cookie : 'null';

    my $dbh = $c->stash('DBH');     # use an existing connection

    my %session;

    eval {
        tie %session, 'Apache::Session::MySQL', $id, {
            Handle     => $dbh,
            LockHandle => $dbh,
        };
    };

    if ($@) {
        $self->error("Failed to create session: $@");
    }

    foreach my $key (keys %$data_ref) {
        $session{$key} = $data_ref->{$key};
    }

    untie %session;

    return;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~[  PRIVATE METHODS  ]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

#----------------------------------------------------------------------------+
# _init(\%params)
#
# Return a reference of $self to the caller.

sub _init {
    my ( $self, $params ) = @_;
    return $self;
}

1;

__END__

=head1 NAME

Apache2::WebApp::Plugin::Session::MySQL - Plugin providing session storage

=head1 SYNOPSIS

  my $obj = $c->plugin('Session')->method( ... );     # Apache2::WebApp::Plugin::Session->method()

    or

  $c->plugin('Session')->method( ... );

=head1 DESCRIPTION

Store persistent data in a MySQL database.

=head1 PREREQUISITES

This package is part of a larger distribution and was NOT intended to be used 
directly.  In order for this plugin to work properly, the following packages
must be installed:

  Apache2::WebApp
  Apache2::WebApp::Plugin::Cookie
  Apache2::WebApp::Plugin::DBI
  Apache2::WebApp::Plugin::Session
  Params::Validate

=head1 INSTALLATION

From source:

  $ tar xfz Apache2-WebApp-Plugin-Session-MySQL-0.X.X.tar.gz
  $ perl MakeFile.PL PREFIX=~/path/to/custom/dir LIB=~/path/to/custom/lib
  $ make
  $ make test     <--- Make sure you do this before contacting me
  $ make install

Perl one liner using CPAN.pm:

  perl -MCPAN -e 'install Apache2::WebApp::Plugin::Session::MySQL'

Use of CPAN.pm in interactive mode:

  $> perl -MCPAN -e shell
  cpan> install Apache2::WebApp::Plugin::Session::MySQL
  cpan> quit

Just like the manual installation of Perl modules, the user may need root access during
this process to insure write permission is allowed within the installation directory.

=head1 REQUIREMENTS

The database table to store session information is auto-generated.  Since this is the
case, the MySQL users must have CREATE privileges.

In case you want to manually create this table, you can run the following SQL
statement on the MySQL command-line:

  CREATE TABLE IF NOT EXISTS sessions (
  id char(32) NOT NULL PRIMARY KEY,
  a_session text;

=head1 CONFIGURATION

Unless it already exists, add the following to your projects I<webapp.conf>

  [session]
  storage_type = mysql

=head1 OBJECT METHODS

Please refer to L<Apache2::WebApp::Session> for method info.

=head1 SEE ALSO

L<Apache2::WebApp>, L<Apache2::WebApp::Plugin>, L<Apache2::WebApp::Plugin::Cookie>,
L<Apache2::WebApp::Plugin::DBI>, L<Apache2::WebApp::Plugin::Session>,
L<Apache::Session>, L<Apache::Session::MySQL>, L<Apache::Session::Lock::MySQL>

=head1 AUTHOR

Marc S. Brooks, E<lt>mbrooks@cpan.orgE<gt> - L<http://mbrooks.info>

=head1 COPYRIGHT

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
