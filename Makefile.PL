use 5.008;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME => 'Acme::Perlmonkify',
    VERSION_FROM => 'lib/Acme/Perlmonkify.pm',
    PREREQ_PM => {
      'LWP::Simple' => 0,
      'Cache::Cache' => 0,
      'B::Deobfuscate' => 0.10,
      'constant' => 0,
      'B::Deparse' => 0 },
    ABSTRACT_FROM  => 'lib/Acme/Perlmonkify.pm', # retrieve abstract from module
    AUTHOR => 'Joshua ben Jore <jjore@cpan.org>'
);
