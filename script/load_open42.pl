#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use WWW::PivotalTracker qw(
  all_stories
  show_story
  project_details
  all_iterations
);

my $API     = '9c1d6080bcbf14534e0e0756547373b0';
my $PROJECT = 101839;
my $STORY   = 4468076;

#print Dumper { project_details => project_details( $API, $PROJECT )};
#print Dumper { show_story => show_story( $API, $PROJECT, $STORY )};

if(0){
    my $stories = all_stories($API, $PROJECT)->{stories};
    my $tally;

    foreach my $story (@$stories) {
        foreach my $field qw( owned_by requested_by estimate story_type success )
        {
            $tally->{$field}{ $story->{$field} || 'none'  }++;
        }
        foreach my $field (keys %$story )
        {
            $tally->{fields}{$field}++;
        }
        $tally->{label_count}{ scalar @{ $story->{labels} || [] }}++;
        $tally->{labels}{$_}++ for @{ $story->{labels} };
        print Dumper { story => $story } if scalar @{ $story->{labels} || [] } > 1;
        #$tally->{labels}{ join (',', @{ $story->{labels} || [] } ) }++;
    }
    print Dumper {tally    => $tally};
}
#print Dumper all_iterations( $API, $PROJECT);

foreach my $iteration (@{ all_iterations($API, $PROJECT)->{iterations}}) {
    next unless (@{$iteration->{stories}});
    foreach my $key (qw( number start finish )){
        print "$key: $iteration->{$key}\n" if !ref $iteration->{$key};
    }
    print "\n";
}
