package Module::MakefilePL::Parse;

use 5.006001;
use strict;
use warnings;

require Exporter;
use Carp;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw( ) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw( );

our $VERSION = '0.02';

sub new {
  my $class  = shift;

  my $script = shift;

  $script =~ s/\s\s+/ /g; # remove extra spaces

  my $self = {
    SCRIPT    => $script,
    INSTALLER => undef,
  };

  if ($script =~ /use\s+ExtUtils::MakeMaker/) {
    $self->{INSTALLER} = qq{ ExtUtils::MakeMaker };
  }
  else {
    croak "Only simple Makefile.PL scripts which use ExtUtils::MakeMaker are supported";
  }
  bless $self, $class;

  $self->{REQUIRED} = $self->_parse;
  unless ($self->required) {
    return;
  }

  return $self;
}

sub required {
  my $self = shift;
  if (ref($self->{REQUIRED}) ne 'HASH') {
    return;
  }
  else {
    return $self->{REQUIRED};
  }
}

sub _parse {
  my $self = shift;

  unless ($self->{INSTALLER} eq qq{ ExtUtils::MakeMaker }) {
    return;
  }
  my $script = $self->{SCRIPT};

  my $key_start = index $script, 'PREREQ_PM';
  if ($key_start < 0) {
    # if no PREREQ_PM, we assume that there are no prereqs
    return { };
  }
  else {
    my $block_start = index $script, '{', $key_start;
    if ($block_start < $key_start) {
      return;
    }
    my $level = 1;
    my $index = $block_start;
    while ($level && (++$index<length($script))) {
      my $ch = substr($script, $index, 1);
      $level++, if ($ch eq '{');
      $level--, if ($ch eq '}');
      if ($level > 1) {
	carp "Warning: embedded hash references or code";
      }
    }
    if ($level) {
      return;
    }
    my $prereq_pm = substr($script, $block_start, ($index-$block_start+1));

    # Surround bareword module names with quotes so that eval works properly

    $prereq_pm =~ s/([\,\s\{])(\w+)(::\w+)+\s*=>/$1 '$2$3' =>/g;

    my $hashref   = eval $prereq_pm;
    return $hashref;
  }
}

1;
__END__

=head1 NAME

Module::MakefilePL::Parse - parse required modules from Makefile.PL

=head1 SYNOPSIS

  use Module::MakefilePL::Parse;

  open $fh, 'Makefile.PL';

  $parser = Module::MakefilePL::Parse->new( join(" ", <$fh>) );

  $info   = $parser->required;

=head1 DESCRIPTION

The purpose of this module is to determine the required modules for
older CPAN distributions which do not have F<META.yml> files but use
F<Makefile.PL> and L<ExtUtils::MakeMaker>.

Presumably newer style F<Makefile.PL> files which use
L<Module::Install> or L<Module::Build> already have F<META.yml> files
in their distributions.

=head2 Methods

=over

=item new

  $parser = new Modile::MakefilePL::Parse( $script );

Parsers a F<Makefile.PL> script and returns an object. Returns
C<undef> if there is a problem.

=item required

  $info = $parser->required;

Returns a hash reference to the C<PREREQ_PM> key in the F<Makefile.PL>
script.

=back

=head1 CAVEATS

This module does evaluate a portion of the code, so there is a
security issue.  However, it only evaluates the definition of the
C<PREREQ_PM> key in calls to C<WriteMakefile>, which should be more
difficult to embed malware in.

Do not run this module on untrusted scripts.

=head1 SEE ALSO

  Module::Info
  Module::Dependency
  Module::Depends
  Module::ScanDeps

=head1 AUTHOR

Robert Rothenberg <rrwo at cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Robert Rothenbeg.  All Rights Reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
