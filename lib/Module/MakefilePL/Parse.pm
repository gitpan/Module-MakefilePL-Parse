package Module::MakefilePL::Parse;

use 5.006001;
use strict;
use warnings;

require Exporter;
use Carp;
use Text::Balanced qw( extract_bracketed );

use enum qw(TYPE_MAKEMAKER=1 TYPE_MODULEINSTALL TYPE_MODULEBUILD);

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw( ) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw( );

our $VERSION = '0.11';

our $DEBUG  = 0;

sub new {
  my $class  = shift;

  my $script = shift;

  $script =~ s/\#.*\n/\n/g;             # remove comments (not greedy?)(
  $script =~ s/\s\s+/ /g;               # remove extra spaces

  my $self = {
    SCRIPT    => $script,
    INSTALLER => undef,
  };

  if ($script =~ /use\s+ExtUtils::MakeMaker/) {
    $self->{INSTALLER} = TYPE_MAKEMAKER;
  }
  elsif ($script =~ /use\s+(inc::)?Module::Install/) {
    $self->{INSTALLER} = TYPE_MODULEINSTALL;
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

# Cleanup module names (if surrounded by quotes, etc.) and make sure
# version is a number.

sub _cleanup {
  my $hashref = shift;
  if (ref($hashref) eq 'HASH') {
    foreach my $module (keys %$hashref) {
      my $version = ($hashref->{$module} += 0); # change to number
      if ($module =~ /[\'\"](.+)[\'\"]/) {
	$hashref->{$1} = $version;
	delete $hashref->{$module};
      }
    }
    return $hashref;
  } else {
    return;
  }
}

sub _parse {
  my $self = shift;

  my $script = $self->{SCRIPT};

  # Look for first call to WriteMakefile function. Key should be there.

  if ($self->{INSTALLER} == TYPE_MAKEMAKER) {

    my $key_start = index $script, 'WriteMakefile';
    if ($key_start < 0) {
      return;
    }

    $key_start = index $script, 'PREREQ_PM', $key_start;
    if ($key_start < 0) {
      # if no PREREQ_PM, we assume that there are no prereqs
      return { };
    } else {

      my $block_start = index $script, '{', $key_start;
      if ($block_start < $key_start) {
	return;
      }

      # check that operator between PREREQ_PM and hash reference is valid
      {
	my $op = substr($script, $key_start, $block_start-$key_start);
	unless ($op =~ /^[\'\"]?PREREQ_PM[\'\"]?\s*(=>|\,)\s*$/) {
	  return;
	}
      }

      my $prereq_pm = extract_bracketed(substr($script, $block_start), '{}' );
      unless ($prereq_pm) {
	return;
      }

      # Surround bareword module names with quotes so that eval works properly

      $prereq_pm =~ s/([\,\s\{])(\w+)(::\w+)+\s*(=>|\,|\'?\d)/$1 '$2$3' $4/g;

      $self->{_PREREQ_PM} = $prereq_pm;

      if ($prereq_pm =~ /[\&\$\@\%\*]/) {
	carp "Warning: possible variable references";
      }

      my $hashref;
      eval "\$hashref = $prereq_pm;";
      return _cleanup($hashref);

    }
  }
  elsif ($self->{INSTALLER} == TYPE_MODULEINSTALL) {

    my $hashref    = { };

    my $index      = 0;
    while (($index = index($script, 'requires', $index)) >= 0) {
      my $reqstr;
      my $start    = index($script, '(', $index+1);
      if ($start   > $index) {
	$reqstr = extract_bracketed(substr($script, $start), '()' );
	if ($reqstr) {
	  my ($module, $comma, $version) =
	    split /(,|=>)/, substr($reqstr,1,-1);

	  $hashref->{eval $module} = 
	    ((defined $version) ? (eval $version) : 0);
	}
	else {
	  return;
	}
      }
      else {
	return;
      }
      $index   = $index+1;
    }

    return _cleanup($hashref);
  }
  else {
    return;
  }
}

sub install_type {
  my $self = shift;
  if (@_) {
    carp "Exra arguments ignored";
  }
  if ($self->{INSTALLER} == TYPE_MAKEMAKER) {
    return 'ExtUtils::MakeMaker';
  } elsif ($self->{INSTALLER} == TYPE_MODULEINSTALL) {
    return 'Module::Install';
  } elsif ($self->{INSTALLER} == TYPE_MODULEBUILD) {
    return 'Module::Build';
  } else {
    return;
  }
}


1;
__END__

=head1 NAME

Module::MakefilePL::Parse - parse required modules from Makefile.PL

=head1 SYNOPSIS

  use Module::MakefilePL::Parse;

  open $fh, 'Makefile.PL';

  $parser = Module::MakefilePL::Parse->new( join("", <$fh>) );

  $info   = $parser->required;

=head1 DESCRIPTION

The purpose of this module is to determine the required modules for
older CPAN distributions which do not have F<META.yml> files but use
F<Makefile.PL> and L<ExtUtils::MakeMaker> or L<Module::Install>.

Presumably newer style F<Makefile.PL> files which use L<Module::Install>
or L<Module::Build> already have F<META.yml> files in their distributions.

=head2 Methods

=over

=item new

  $parser = new Modile::MakefilePL::Parse( $script );

Parses a F<Makefile.PL> script and returns an object.  Returns
C<undef> if there is a problem.

=item required

  $info = $parser->required;

Returns a hash reference containing the prerequisite modules.  This is
either the the C<PREREQ_PM> key, or a combination of prerequisites
specified in C<requires> and C<build_requires> calls in the
F<Makefile.PL> script (depending on the L</install_type>).

=item install_type

  $module = $parser->install_type;

Returns the module used for installation.

=back

=head1 CAVEATS

This module does evaluate a portion of the code, so there is a
security issue.  However, it only evaluates the definition of the
C<PREREQ_PM> key in calls to C<WriteMakefile>, which should be more
difficult to embed malware in.

Do not run this module on untrusted scripts.

=head1 SEE ALSO

These other modules will also provide meta-information about CPAN
distributions:

  Module::CoreList
  Module::CPANTS::Generator::Prereq
  Module::Info
  Module::Dependency
  Module::Depends
  Module::PrintUsed
  Module::ScanDeps

Note that C<Module::CPANTS::Generator::Prereq> is similar to this
module, so it is possible that any future work will be merged into
that project than on maintaining this module.

=head1 AUTHOR

Robert Rothenberg <rrwo at cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Robert Rothenbeg.  All Rights Reserved.

The test script F<Module-MakefilePL-Parse.t> contains small snippets
(less than a few lines) based on existing F<Makefile.PL> files from
modules on CPAN.  Those modules are acknowledged in the snippets, and
the copyrights of those modules belong to their respective authors.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
