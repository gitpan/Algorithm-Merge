use Test;
use Algorithm::Merge qw(diff3);
#use Algorithm::Diff qw(diff);
use Data::Dumper;

my $error_message = 'Algorithm::Diff::diff is not symmetric for second and third sequences';

# check sequences of equal length (1 element each)
my @results = (
    [ 'u', '', '', '' ],
    [ 'r', '', '', 'c' ],
    [ 'l', '', 'b', '' ],
    [ 'c', '', 'b', 'c' ],
    [ 'o', 'a', '', '' ],
    [ 'c', 'a', '', 'c' ],
    [ 'c', 'a', 'b', '' ],
    [ 'c', 'a', 'b', 'c' ],
);

foreach $i (0, 1) {
    foreach $j (0, 1) {
        foreach $k (0, 1) {
#my($i, $j, $k) = (1, 1, 0);  # for testing an individual combination
            push @tests, [
                [ $i ? 'a' : '' ],
                [ $j ? 'b' : '' ],
                [ $k ? 'c' : '' ],
                [ $results[$i*4 + $j*2 + $k], ],
            ];
        }
    }
}

# check sequences, some of which are empty/null sequences ( [] in diff3 call, undef in output)
@results = (
    [ ],  # no contents in any of the sequences
    [ 'r', undef, undef, 'c' ],
    [ 'l', undef, 'b', undef ],
    [ 'c', undef, 'b', 'c' ],
    [ 'o', 'a', undef, undef ],
    [ 'r', 'a', undef, 'c' ],  # still a problem
    [ 'l', 'a', 'b', undef ],  # still a problem
    [ 'c', 'a', 'b', 'c' ],
);

foreach $i (0, 1) {
   foreach $j (0, 1) {
        foreach $k (0, 1) {
#my($i, $j, $k) = (1, 1, 0);  # for testing an individual combination
            push @tests, [
                [ ($i ? 'a' : () ) ],
                [ ($j ? 'b' : () ) ],
                [ ($k ? 'c' : () ) ],
                [ $results[$i*4 + $j*2 + $k], ],
            ];
        }
    }
}

plan tests => scalar(@tests);

my $out;

foreach my $t (@tests) {
    if(UNIVERSAL::isa($t, 'CODE')) {
        eval { local $SIG{__DIE__}; $t -> (); };
        warn "$@\n" if $@ && $ENV{DEBUG};
        ok !$@;
    }
    else {
        eval {
            local $SIG{__DIE__};
            local $SIG{__WARN__} = sub { };
            $out = diff3(@{$t}[0, 1, 2]);
        };
        if($@ && $@ =~ m{^$error_message}o) {
            ok 1;
        }
        else {
            my $sout = join(";", map { join(":", map { defined($_) ? "[$_]" : "" } @{$_}) } @{$out});
            my $sexp = join(";", map { join(":", map { defined($_) ? "[$_]" : "" } @{$_}) } @{$t->[3]});

            warn Data::Dumper -> Dump([$out, $t->[3]], [qw(Out Expected Diff)]) if $ENV{DEBUG} && $sout ne $sexp;
            ok $sout eq $sexp;
        }
    }
}

exit 0;
