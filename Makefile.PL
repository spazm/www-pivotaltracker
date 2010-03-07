use inc::Module::Install;

name     'WWW-PivotalTracker';
all_from 'lib/WWW/PivotalTracker.pm';

author     'Jacob Helwig <jhelwig@cpan.org>';
license    'perl';
repository 'git://github.com/jhelwig/www-pivotaltracker.git';
bugtracker 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-PivotalTracker',
homepage   'http://github.com/jhelwig/www-pivotaltracker',

requires 'aliased';
requires 'Carp';
requires 'Config::Any';
requires 'File::HomeDir';
requires 'Getopt::Long::Descriptive';
requires 'Hash::Merge';
requires 'HTTP::Request';
requires 'LWP::UserAgent';
requires 'parent';
requires 'Perl6::Parameters';
requires 'Pod::Usage';
requires 'URI::Escape';
requires 'XML::Simple';

test_requires 'Sub::Override';
test_requires 'Test::CheckChanges' => '0.14';
test_requires 'Test::Class';
test_requires 'Test::More';
test_requires 'Test::Most';

install_script 'pivotal_tracker';

WriteAll;
