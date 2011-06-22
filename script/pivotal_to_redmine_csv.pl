#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;
use Text::CSV;

use WWW::PivotalTracker qw(
  all_stories
  show_story
  project_details
);

my $API     = '9c1d6080bcbf14534e0e0756547373b0';
my $PROJECT = 101839;
my $STORY   = 4484473;
$STORY = 4468086;

my $result = GetOptions(
    'api-key|s'    => \$API,
    'project-id|i' => \$PROJECT,
    'story-id|i'   => \$STORY,
);

my $csv = Text::CSV->new( {binary => 1 });
sub _to_csv
{
    my $status = $csv->combine(@_);
    die ( "combine failed: input was " . $csv->error_input ) unless $status;
    $csv->string;
}

my @other_fields = qw(
  tasks          
  notes
  url
  labels
);

my %field_name = (
    accepted_at   => 'due date',
    created_at    => 'start date',
    current_state => 'status',
    deadline      => 'deadline',
    description   => 'description',
    estimate      => 'estimate',
    id            => 'pivotal_id',
    labels        => 'category',
    name          => 'subject',
    owned_by      => 'assigned_to',
    requested_by  => 'author',
    story_type    => 'tracker',
);
my @fields = qw(
  id
  story_type
  name
  description
  requested_by
  owned_by
  estimate
  created_at
  accepted_at
  current_state
  deadline
  labels
);

my %story_map = (
    bug     => 'Bug',
    feature => 'Enhancement',
    todo    => 'Sub-Task',
    release => 'Task',
    chore   => 'Tech Debt',
    ''      => 'Bug',
);

my %user_map = (
    'Margaret Shih'          => 'maggie',
    'none'                   => '',
    ''                       => '',
    'Dimitris Komis'         => 'dkomis',
    'Yannis Roussochatzakis' => 'rousso',
    'Kevin Chang'            => 'kevinx',
);

my %current_state_map = (
    accepted    => 'Closed - Verified',
    delivered   => 'resolved',
    started     => 'accepted',
    unscheduled => '',                 #icebox
    unstarted   => 'new',              #backlog
    ''          => '',
);

my @csv_fields = map { $field_name{ $_ } || $_ } @fields;
{
    my $stories = all_stories($API, $PROJECT)->{stories};
#    my $story   = show_story( $API,$PROJECT, $STORY);
#    $stories = [ $story ];

    print _to_csv( @csv_fields ) , "\n";
    foreach my $story (@$stories) {
        #flatten labels
        $story->{labels} = @{$story->{labels} || ['']}[0];
        #map fields
        $story->{current_state} = $current_state_map{$story->{current_state} || ''};
        $story->{story_type}    = $story_map{$story->{story_type}            || ''};
        $story->{requested_by}  = $user_map{$story->{requested_by}           || ''};
        $story->{owned_by}      = $user_map{$story->{owned_by}               || ''};
        my @data = @$story{@fields};
        print _to_csv(@data), "\n";
    }
}
