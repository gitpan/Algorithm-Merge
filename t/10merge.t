use Test;
use Algorithm::Merge qw(diff3 merge);
use Algorithm::Diff qw(diff);
use Data::Dumper;

my $error_message = 'Algorithm::Diff::diff is not symmetric for second and third sequences';

# test deletion of last member in ancestor
push @tests, [
    [qw(a b c)], # ancestor
    [qw(a b)],   # left
    [qw(a b c)], # right
    [qw(a b)]    # merge
];

# test deletion of first member in ancestor
push @tests, [
    [qw(a b c)], # ancestor
    [qw(  b c)], # left
    [qw(a b c)], # right
    [qw(  b c)]  # merge
];

# test deletion of last member in ancestor and addition of a new last member
push @tests, [
    [qw(a b c)],   # ancestor
    [qw(a b   d)], # left
    [qw(a b c d)], # right
    [qw(a b   d)]  # merge
];

# test deletion of interior member of ancestor and addition of interior member
push @tests, [
    [qw(a b c   e)], # ancestor
    [qw(a b   d e)], # left
    [qw(a b c d e)], # right
    [qw(a b   d e)]  # merge
];

push @tests, [
    [qw(a b c   e f)], # ancestor
    [qw(a b   d e f)], # left
    [qw(a b c d e)],   # right
    [qw(a b   d e)]    # merge
];


push @tests, [
    [qw(a b c   e f   h i   k)], # ancestor
    [qw(a b   d e f g   i j k)], # left
    [qw(a b c d e     h i j k)], # right
    [qw(a b   d e   g   i j k)]  # merge
];

push @tests, [
    [qw(a b c d e f g)], # ancestor
    [qw(a b     e   g)], # left
    [qw(a     d e   g)], # right
    [qw(a       e   g)], # merge
];

# test conflicts
push @tests, [
    [qw(a b c d)], # ancestor
    [qw(l b c d)], # left
    [qw(r b c d)], # right
    [qw(< l | r > b c d)], #merge
    [qw(< r | l > b c d)]
];

push @tests, [
    [qw(a         b c b f b d)],
    [qw(  l       b c b     d)],
    [qw(      r   b c b     d b e)],
    [qw(< l | r > b c b     d b e)],
    [qw(< r | l > b c b     d b e)],
];

push @tests, [
    [qw(a b             b c b f b d)],
    [qw(    l m         b c b     d)],
    [qw(          r s   b c b     d b e)],
    [qw(  < l m | r s > b c b     d b e)],
    [qw(  < r s | l m > b c b     d b e)],
];

push @tests, [
    [qw(a         b c         b f b d)],
    [qw(  l       b   d       b     d)],
    [qw(      r   b       e   b     d b e)],
    [qw(< l | r > b < d | e > b     d b e)],
    [qw(< r | l > b < e | d > b     d b e)], # Algorithm::Diff::diff should fail (see BUG section of man page) on this one
];



plan tests => scalar(@tests) + scalar(grep { !UNIVERSAL::isa($_, 'CODE') } @tests);

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
            $out = merge(@{$t}[0, 1, 2],     
                {
                    CONFLICT => sub ($$) { (
                        q{<}, @{$_[0]}, q{|}, @{$_[1]}, q{>}
                    ) },
                },
            );
        };
        if($@ && $@ =~ m{^$error_message}o) {
            ok 1;
        }
        else {
            my $diff = diff($out, $t -> [3]);

            warn "qw(", join(" ", @{$out}), ") ne qw(", join(" ", @{$t -> [3]}), ")\n" if $ENV{DEBUG} && @{$diff};
            ok !@{$diff}; # ok if there's no difference
        }
    }
}

# make sure the merge is symmetric
foreach my $t (@tests) {
    next if UNIVERSAL::isa($t, 'CODE');
    eval {
        local $SIG{__DIE__};
        local $SIG{__WARN__} = sub { };
        $out = merge(@{$t}[0, 2, 1],
            {
                CONFLICT => sub ($$) { (
                    q{<}, @{$_[0]}, q{|}, @{$_[1]}, q{>}
                ) },
            },
        );
    };

    if($@ && $@ =~ m{^$error_message}o) {
        ok 1;
    }
    else {
        my $diff = diff($out, $t -> [4] || $t -> [3]);

        warn "qw(", join(" ", @{$out}), ") ne qw(", join(" ", @{$t -> [4] || $t -> [3]}), ")\n" if $ENV{DEBUG} && @{$diff};
        ok !@{$diff}; # ok if there's no difference
    }
}


exit 0;

