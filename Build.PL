use Module::Build;

my $build = Module::Build->new
    (
     module_name => 'Module::MakefilePL::Parse',
     license => 'perl',
     requires => {
       'perl'                       => '5.6.1',
       'enum'                       => 1.016,
       'Text::Balanced'             => 0,
     },
     recommends => {
     },
     build_requires => {
       'Test::More'                 => 0,
       'Test::Warn'                 => 0,
     },
     create_makefile_pl => 'traditional',
     dist_author        => 'Robert Rothenberg <rrwo at cpan.org>',
);

$build->create_build_script;
