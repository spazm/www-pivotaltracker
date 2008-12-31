package WWW::PivotalTracker;

use 5.006;

use warnings;
use strict;

use parent 'Exporter';

use Perl6::Parameters;

use aliased 'HTTP::Request'  => '_Request';
use aliased 'LWP::UserAgent' => '_UserAgent';

use Carp qw/
    croak
/;
use URI::Escape qw/
    uri_escape
/;
use XML::Simple qw/
    XMLin
    XMLout
/;

=head1 NAME

WWW::PivotalTracker - Functional interface to Pivotal Tracker L<http://www.pivotaltracker.com/>

=cut

our $VERSION = "0.12";

=head1 SYNOPSIS

This module provides simple methods to interact with the Pivotal Tracker API.

    use WWW::PivotalTracker qw/
        add_story
        all_stories
        delete_story
        project_details
        show_story
        stories_for_filter
    /;

    my $details = project_details("API Token", "Project ID");

    ...

=head1 EXPORT

Nothing is exported by default.  See B<FUNCTIONS> for the exportable functions.

=cut

our @EXPORT_OK = qw/
    add_story
    all_stories
    delete_story
    project_details
    show_story
    stories_for_filter
/;

#This should never contain anything.  It's just here to make sure that :all
#works as expected.
our @EXPORT = ();

our %EXPORT_TAGS = (
    all => [ @EXPORT, @EXPORT_OK, ],
);

=head1 FUNCTIONS

=head2 project_details

Returns a hashref with the project's name, point scale, number of weeks per
iteration, and which day of the week the iterations start on.

    my $proj = project_details($token, $project_id);

    print "Project name: $proj->{'name'}\n"
        . "Point scale: $proj->{'point_scale'}\n"
        . "Weeks per Iteration: $proj->{'iteration_weeks'}\n"
        . "Iteration start day: $proj->{'start_day'}\n";

=cut

sub project_details($token, $project_id) {
    croak("Malformed Project ID: '$project_id'") unless __PACKAGE__->_check_project_id($project_id);

    my $response = __PACKAGE__->_do_request($token, "projects/$project_id", "GET");

    if (!defined $response || lc $response->{'success'} ne 'true') {
        return {
            success => 'false',
            errors  => (defined $response && exists $response->{'errors'} ? $response->{'errors'} : 'Epic fail!'),
        };
    }

    return {
        success         => 'true',
        iteration_weeks => $response->{'project'}->{'iteration_length'}->{'content'},
        name            => $response->{'project'}->{'name'},
        point_scale     => $response->{'project'}->{'point_scale'},
        start_day       => $response->{'project'}->{'week_start_day'},
    };
}

=head2 show_story

Return a hashref with the details of a specific story.

    my $story = show_story($token, $project_id, $story_id);

    # If the story doesn't have a particular attribute, then the hash key's
    # value will be undef. (Ex: description, deadline, labels, notes)
    $story->{'id'}
    $story->{'name'}
    $story->{'description'} # Possibly multi-line string.
    $story->{'estimate'}    # Possible values are results in point_scale
                            # returned by project_details, and -1 if not
                            # estimated, yet.
    $story->{'current_state'}
    $story->{'created_at'}
    $story->{'deadline'}    # undef, unless story type is 'release'
    $story->{'story_type'}  # 'feature', 'bug', 'chore', or 'release'
    $story->{'labels'}      # [ 'foo', 'bar', 'baz', ]
    $story->{'notes'}       # [
                            #     { id => 1, author => 'alice', date => 'Dec 20, 2008', text => 'comment', },
                            #     { id => 2, author => 'bob', date => 'Dec 20, 2008', text => 'commenting on your comment', },
                            # ]
    $story->{'url'}

=cut

sub show_story($token, $project_id, $story_id)
{
    croak("Malformed Project ID: '$project_id'") unless __PACKAGE__->_check_project_id($project_id);
    croak("Malformed Story ID: '$story_id'") unless __PACKAGE__->_check_story_id($story_id);

    my $response = __PACKAGE__->_do_request($token, "projects/$project_id/stories/$story_id", "GET");

    if (!defined $response || lc $response->{'success'} ne 'true') {
        return {
            success => 'false',
            errors  => (defined $response && exists $response->{'errors'} ? $response->{'errors'} : 'Epic fail!'),
        };
    }

    my $story = __PACKAGE__->_sanitize_story_xml($response->{'story'}->[0]);

    return {
        success       => 'true',
        %{$story},
    };
}

=head2 all_stories

Return an arrayref of story hashrefs (see B<show_story> for story hashref details).

=cut

sub all_stories($token, $project_id)
{
    croak("Malformed Project ID: '$project_id'") unless __PACKAGE__->_check_project_id($project_id);

    my $response = __PACKAGE__->_do_request($token, "projects/$project_id/stories", "GET");

    if (!defined $response || lc $response->{'success'} ne 'true') {
        return {
            success => 'false',
            errors  => (defined $response && exists $response->{'errors'} ? $response->{'errors'} : 'Epic fail!'),
        };
    }

    my @stories = map { __PACKAGE__->_sanitize_story_xml($_) } @{$response->{'stories'}->{'story'}};

    return {
        success => 'true',
        stories => [ @stories ],
    };
}

=head2 add_story

Create a new story, given a hashref of the story's details, and return a
story hashref of the same format as B<show_story>.

Possible story details hash keys are:
    created_at
    current_state
    deadline
    description
    estimate
    labels
    name
    requested_by
    story_type

The bare minimum to create a new story are "requested_by", and "name".  New
stories will default to be "feature" stories, unless a "story_type"
("feature", "bug", "chore", or "release") is specified.

To add labels, include a comma separated list as the "labels" value.

    my $story_details = {
        requested_by => "Bob",
        name         => "Users can request stories.",
        labels       => "label 1, label 2, another label",
    };

    my $story_details_2 = {
        requested_by => "Alice",
        name         => "Release #1",
        deadline     => "Dec 31, 2008",
    };

    my $story = add_story($token, $project_id, $story_details);
    my $story_2 = add_story($token, $project_id, $story_details_2);

=cut

sub add_story($token, $project_id, $story_details)
{
    croak("Malformed Project ID: '$project_id'") unless __PACKAGE__->_check_project_id($project_id);

    foreach my $key (keys %$story_details) {
        croak("Unrecognized option: $key")
            unless __PACKAGE__->_is_one_of($key, [qw/
                created_at
                current_state
                deadline
                description
                estimate
                labels
                name
                note
                requested_by
                story_type
            /]);
    }
    croak("'name' is required for a new story") unless exists $story_details->{'name'};
    croak("'requested_by' is required for a new story") unless exists $story_details->{'requested_by'};

    my $content = __PACKAGE__->_make_xml({ story => $story_details });

    my $response = __PACKAGE__->_do_request($token, "projects/$project_id/stories", "POST", $content);

    if (!defined $response || $response->{'success'} ne 'true') {
        return {
            success => 'false',
            errors  => $response->{'errors'},
        };
    }

    my $story = __PACKAGE__->_sanitize_story_xml($response->{'story'}->[0]);

    return {
        success       => 'true',
        %{$story},
    };
}

=head2 delete_story

Delete an existing story.

    my $result = delete_story($token, $project_id, $story_id);

    print $result->{'success'};
    print $result->{'message'};

=cut

sub delete_story($token, $project_id, $story_id)
{
    croak("Malformed Project ID: '$project_id'") unless __PACKAGE__->_check_project_id($project_id);
    croak("Malformed Story ID: '$story_id'") unless __PACKAGE__->_check_story_id($story_id);

    my $response = __PACKAGE__->_do_request($token, "projects/$project_id/stories/$story_id", "DELETE");

    if (!defined $response || $response->{'success'} ne 'true') {
        return {
            success => 'false',
            errors  => $response->{'errors'},
        };
    }

    my $message = $response->{'message'};
    return {
        success => 'true',
        message => $message,
    };
}

=head2 stories_for_filter

Find all stories given search paremeters.

    my $result = stories_for_filter($token, $project_id, $search_filter);

    my @stories;
    if($result->{'success'} eq 'true') {
        print $result->{'message'} . "\n";

        @stories = @{$result->{'stories'}};
    }
    else {
        print $result->{'errors'};
    }

In the example above C<< @stories >> will be an array of story hashrefs.  See the description of B<show_story> for the details of the hashrefs.

Any multi-word terms in the search filter must be enclosed by double quotes.

    Example:
        requested_by:"Jacob Helwig"

=cut

sub stories_for_filter($token, $project_id, $search_filter)
{
    croak("Malformed Project ID: '$project_id'") unless __PACKAGE__->_check_project_id($project_id);

    my $response = __PACKAGE__->_do_request($token, "projects/$project_id/stories?filter=" . uri_escape($search_filter), "GET");

    if (!defined $response || lc $response->{'success'} ne 'true') {
        return {
            success => 'false',
            errors  => (defined $response && exists $response->{'errors'} ? $response->{'errors'} : 'Epic fail!'),
        };
    }

    my @stories = map { __PACKAGE__->_sanitize_story_xml($_) } @{$response->{'stories'}->{'story'}};

    return {
        success => 'true',
        message => $response->{'message'},
        stories => [ @stories ],
    };
}

sub _check_story_id($class, $story_id)
{
    return $story_id =~ m/^\d+$/ ? 1 : 0;
}

sub _check_project_id($class, $project_id)
{
    return $project_id =~ m/^\d+$/ ? 1 : 0;
}

sub _is_one_of($class, $element, $set)
{
    return((scalar grep { $_ eq $element } @$set) ? 1 : 0);
}

sub _sanitize_story_xml($class, $story)
{
    my $labels = undef;
    my $notes = undef;

    $labels = $story->{'labels'}->{'label'} if exists $story->{'labels'};
    $notes = [
        map +{
            id     => $_->{'id'}->{'content'},
            author => $_->{'author'},
            date   => $_->{'date'},
            text   => $_->{'text'},
        }, @{$story->{'notes'}->{'note'}}
    ] if exists $story->{'notes'};

    return {
        id            => $story->{'id'}->{'content'},
        name          => $story->{'name'},
        description   => $story->{'description'},
        estimate      => $story->{'estimate'}->{'content'},
        current_state => $story->{'current_state'},
        created_at    => $story->{'created_at'},
        deadline      => $story->{'deadline'},
        story_type    => $story->{'story_type'},
        requested_by  => $story->{'requested_by'},
        labels        => $labels,
        notes         => $notes,
        url           => $story->{'url'},
    };
}

sub _do_request($class, $token, $request_url, $request_method; $content)
{
    my $base_url = "https://www.pivotaltracker.com/services/v1/";

    my $request = _Request->new(
        $request_method,
        $base_url . $request_url,
        [
            'X-TrackerToken' => $token,
            'Content-type'   => 'application/xml',
        ],
        $content
    );

    my $response = $class->_post_request($request);

    return XMLin(
        $response,
        ForceArray => [qw/
            error
            iteration
            label
            note
            story
        /],
        GroupTags => {
            errors => 'error',
            labels => 'label',
        },
        KeyAttr => [],
        SuppressEmpty => undef,
    );
}

sub _post_request($class, $request)
{
    my $ua = _UserAgent->new();
    my $response = $ua->request($request);

    croak($response->status_line()) unless ($response->is_success());

    return $response->content();
}

sub _make_xml($class, HASH $data)
{
    return XMLout(
        $data,
        KeepRoot   => 1,
        NoAttr     => 1,
    );
}

=head1 AUTHOR

Jacob Helwig, C<< <jhelwig at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-pivotaltracker at rt.cpan.org>,
or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-PivotalTracker>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::PivotalTracker

You can also look for information at:

=over 4

=item * Mailing list

L<http://lists.technosorcery.net/listinfo.cgi/www-pivotaltracker-technosorcery.net>

C<< <www-pivotaltracker at lists.technosorcery.net> >>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-PivotalTracker>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-PivotalTracker>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-PivotalTracker>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-PivotalTracker/>

=item * Source code

L<git://github.com/jhelwig/www-pivotaltracker.git>

=back

=head1 ACKNOWLEDGEMENTS

Chris Hellmuth

=head1 COPYRIGHT & LICENSE

Copyright 2008 Jacob Helwig.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

# vim: set tabstop=4 shiftwidth=4: 
