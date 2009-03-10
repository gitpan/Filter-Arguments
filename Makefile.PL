use 5.008008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Filter::Arguments',
    VERSION_FROM      => 'lib/Filter/Arguments.pm', # finds $VERSION
    PREREQ_PM         => {
        'Template'       => '2.20';
        'Filter::Simple' => '0.82';
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Filter/Arguments.pm', # retrieve abstract from module
       AUTHOR         => 'Dylan Doxey <dylan.doxey@gmail.com>') : ()),
);
