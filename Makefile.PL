use inc::Module::Install;

name     'WWW-PivotalTracker';
all_from 'lib/WWW/PivotalTracker.pm';

author   'Jacob Helwig <jhelwig@cpan.org>';
license  'perl';

requires 'Config::Any';
requires 'File::HomeDir';
requires 'Getopt::Long::Descriptive';
requires 'Hash::Merge';
requires 'HTTP::Request';
requires 'LWP::UserAgent';
requires 'parent';
requires 'Perl6::Parameters';
requires 'Pod::Usage';
requires 'XML::Simple';

test_requires 'Test::Class';
test_requires 'Test::Most';

install_script 'script/pivotal_tracker';

WriteAll;
